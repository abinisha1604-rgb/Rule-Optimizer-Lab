"""Lesson 10: validate candidates with a time-ordered holdout.

This report separates a selection period from a later holdout period. Candidate
metrics are calculated independently for each period, while labels are visible
to selection only when their closed-case decision was submitted by the cutoff.
The lab refuses to select a recommendation when no finalized false-positive
outcomes are available. It reads a partitioned snapshot only and never writes
to the database.
"""

import argparse
from datetime import datetime, timezone
from decimal import Decimal
import json
from pathlib import Path
import sys

from step_12_candidate_search import (
    candidate_would_fire,
    evaluate_candidate,
    parse_multipliers,
)
from step_16_read_snapshot import load_snapshot_dataset


def parse_timestamp(value):
    """Parse the dump's naive timestamps and ISO timestamps consistently."""
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    parsed = datetime.fromisoformat(text)
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
    return parsed


def choose_cutoff(events, fraction=0.7):
    """Choose a deterministic timestamp boundary when the caller omits one."""
    if not events:
        raise ValueError("dataset contains no events")
    if not 0 < fraction < 1:
        raise ValueError("selection fraction must be between 0 and 1")
    ordered = sorted(
        (event for event in events if parse_timestamp(event.get("timestamp")) is not None),
        key=lambda event: (parse_timestamp(event.get("timestamp")), event.get("transaction_master_id")),
    )
    if len(ordered) < 2:
        raise ValueError("at least two timestamped events are required for a holdout")
    index = max(1, min(len(ordered) - 1, int(len(ordered) * fraction)))
    return parse_timestamp(ordered[index]["timestamp"])


def decision_available_at(event):
    """Return the earliest closed-case decision submission time, if present."""
    times = []
    for evidence in event.get("case_evidence") or []:
        if evidence.get("case_status") != "CLOSED":
            continue
        if not evidence.get("case_decision_code"):
            continue
        parsed = parse_timestamp(evidence.get("decision_submitted_at"))
        if parsed is not None:
            times.append(parsed)
    return min(times) if times else None


def label_visible_at_cutoff(event, cutoff):
    """Copy an event while hiding a known label submitted after the cutoff."""
    outcome = event.get("outcome") or {}
    if outcome.get("supervision") != "KNOWN":
        return dict(event)
    available_at = decision_available_at(event)
    if available_at is None or available_at > cutoff:
        hidden = dict(event)
        hidden["outcome"] = {
            **outcome,
            "label": "UNKNOWN_LABEL_NOT_AVAILABLE_AT_SELECTION_CUTOFF",
            "supervision": "UNKNOWN",
        }
        return hidden
    return dict(event)


def partition_events(events, cutoff):
    """Return chronological selection and holdout partitions."""
    selection = []
    holdout = []
    for event in events:
        timestamp = parse_timestamp(event.get("timestamp"))
        if timestamp is None:
            continue
        (selection if timestamp < cutoff else holdout).append(event)
    key = lambda event: (parse_timestamp(event.get("timestamp")), event.get("transaction_master_id"))
    selection.sort(key=key)
    holdout.sort(key=key)
    return selection, holdout


def partition_summary(events, cutoff=None):
    timestamps = [parse_timestamp(event.get("timestamp")) for event in events]
    timestamps = [value for value in timestamps if value is not None]
    known = [event for event in events if (event.get("outcome") or {}).get("supervision") == "KNOWN"]
    return {
        "event_count": len(events),
        "first_timestamp": min(timestamps).isoformat(sep=" ") if timestamps else None,
        "last_timestamp": max(timestamps).isoformat(sep=" ") if timestamps else None,
        "known_outcome_count": len(known),
        "known_false_positive_count": sum(
            (event.get("outcome") or {}).get("label") == "KNOWN_FALSE_POSITIVE_CLOSED"
            for event in events
        ),
        "known_confirmed_fraud_count": sum(
            (event.get("outcome") or {}).get("label") == "KNOWN_CONFIRMED_FRAUD_CLOSED"
            for event in events
        ),
        "cutoff_exclusive": cutoff.isoformat(sep=" ") if cutoff else None,
    }


def evaluate_partitions(selection, holdout, multipliers):
    """Evaluate every candidate on both partitions under both metric hypotheses."""
    interpretations = {
        "sql_zero_fallback": ("SQL_ZERO_FALLBACK_FROM_BASELINE", False),
        "no_history_means_absent": ("EXPERIMENTAL_NO_HISTORY_MEANS_METRIC_ABSENT", True),
    }
    result = {}
    for key, (name, no_history_means_absent) in interpretations.items():
        result[key] = {
            "selection": [
                evaluate_candidate(selection, value, name, no_history_means_absent)
                for value in multipliers
            ],
            "holdout": [
                evaluate_candidate(holdout, value, name, no_history_means_absent)
                for value in multipliers
            ],
        }
    return result


def run_validation(snapshot_dir, multipliers, current_multiplier=Decimal("3"), cutoff_text=None,
                   selection_fraction=0.7):
    try:
        dataset = load_snapshot_dataset(snapshot_dir)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return {"source": "LOCAL_SNAPSHOT_DIRECTORY", "status": "SNAPSHOT_UNREADABLE", "details": str(exc)}
    events = dataset.get("events") or []
    try:
        cutoff = parse_timestamp(cutoff_text) if cutoff_text else choose_cutoff(events, selection_fraction)
    except (TypeError, ValueError) as exc:
        return {"source": "LOCAL_FILE", "status": "CUTOFF_INVALID", "details": str(exc)}
    selection, holdout = partition_events(events, cutoff)
    if not selection or not holdout:
        return {
            "source": "LOCAL_FILE",
            "status": "HOLDOUT_PARTITION_EMPTY",
            "cutoff": cutoff.isoformat(sep=" "),
            "selection_count": len(selection),
            "holdout_count": len(holdout),
        }

    # Only selection-period labels that were actually available by the cutoff
    # may influence a candidate choice. Holdout labels are never used to choose.
    selection_visible = [label_visible_at_cutoff(event, cutoff) for event in selection]
    candidate_results = evaluate_partitions(selection_visible, holdout, multipliers)
    selection_fp_count = sum(
        (event.get("outcome") or {}).get("label") == "KNOWN_FALSE_POSITIVE_CLOSED"
        for event in selection_visible
    )
    return {
        "source": "SAVED_SNAPSHOT_ONLY",
        "status": "HOLDOUT_VALIDATION_REPORT_COMPLETE",
        "snapshot_directory": str(snapshot_dir),
        "snapshot_id": dataset.get("snapshot_id"),
        "scope": dataset.get("scope"),
        "rule": dataset.get("rule"),
        "candidate_set": [str(value) for value in multipliers],
        "current_multiplier": str(current_multiplier),
        "cutoff": {
            "timestamp": cutoff.isoformat(sep=" "),
            "selection_rule": "event timestamp < cutoff",
            "holdout_rule": "event timestamp >= cutoff",
            "selection_fraction_requested": selection_fraction,
        },
        "partitions": {
            "selection": partition_summary(selection_visible, cutoff),
            "holdout": partition_summary(holdout, cutoff),
        },
        "candidates": candidate_results,
        "selection": {
            "status": "INSUFFICIENT_OUTCOME_EVIDENCE_FOR_RECOMMENDATION"
            if selection_fp_count == 0 else "REQUIRES_EXPLICIT_SELECTION_POLICY",
            "known_false_positive_count_available_at_cutoff": selection_fp_count,
            "selected_candidate": None,
            "reason": (
                "No finalized false-positive label is available in the selection period; "
                "holdout numbers are descriptive and cannot justify a recommendation."
                if selection_fp_count == 0 else
                "Candidate choice still requires an explicit false-positive reduction and known-positive retention policy."
            ),
        },
        "checks": {
            "database_reads": "NONE",
            "database_writes": "NONE",
            "stored_metric_sql_execution": "NOT_RUN",
            "unknown_outcomes_preserved": True,
            "holdout_labels_used_for_selection": False,
            "selection_labels_time_filtered": True,
            "runtime_behavior_proven": False,
        },
        "next_step": "OBTAIN_FINALIZED_FALSE_POSITIVE_LABELS_AND_RERUN",
    }


def compact_report(full):
    if full.get("status") != "HOLDOUT_VALIDATION_REPORT_COMPLETE":
        return full
    return {key: full[key] for key in (
        "source", "status", "snapshot_directory", "snapshot_id", "scope", "rule", "candidate_set", "current_multiplier",
        "cutoff", "partitions", "candidates", "selection", "checks", "next_step",
    )}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, required=True,
                        help="Path to one partitioned snapshot directory")
    parser.add_argument("--multipliers", default="2,2.5,3,3.5,4")
    parser.add_argument("--current-multiplier", default="3")
    parser.add_argument("--cutoff", help="Optional ISO timestamp; default is a 70%% chronological split")
    parser.add_argument("--selection-fraction", type=float, default=0.7)
    parser.add_argument("--summary", action="store_true", help="Print compact validation report")
    parser.add_argument("--output", type=Path, help="Also save the full validation JSON")
    args = parser.parse_args()
    try:
        multipliers = parse_multipliers(args.multipliers)
        current_multiplier = parse_multipliers(args.current_multiplier)[0]
    except ValueError as exc:
        parser.error(str(exc))
    if len(multipliers) > 20:
        parser.error("candidate set is limited to 20 values in this learning lab")
    full = run_validation(
        args.snapshot, multipliers, current_multiplier, args.cutoff, args.selection_fraction
    )
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(full, default=str, indent=2) + "\n", encoding="utf-8")
        print(f"Full holdout-validation report saved: {args.output}")
    report = compact_report(full) if args.summary else full
    print(json.dumps(report, default=str, indent=2))
    return 0 if full.get("status") == "HOLDOUT_VALIDATION_REPORT_COMPLETE" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print(f"Holdout validation setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
