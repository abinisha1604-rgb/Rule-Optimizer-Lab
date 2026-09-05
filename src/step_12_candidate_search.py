"""Lesson 9: evaluate a small, bounded threshold candidate set.

This is a feasibility experiment over a partitioned historical snapshot. It
tests candidate multipliers under both the SQL-zero replay and the explicit
no-history-means-absent hypothesis. It does not tune the database, label
unknown outcomes, or select a production recommendation. A recommendation is
blocked when the snapshot has no finalized false-positive outcomes.
"""

import argparse
from decimal import Decimal, InvalidOperation
import json
from pathlib import Path
import sys

from step_16_read_snapshot import load_snapshot_dataset


DEFAULT_MULTIPLIERS = ("2", "2.5", "3", "3.5", "4")


def parse_multipliers(text):
    """Parse positive decimal candidates and reject ambiguous input."""
    values = []
    for raw in (part.strip() for part in text.split(",")):
        if not raw:
            raise ValueError("candidate multipliers cannot contain an empty item")
        try:
            value = Decimal(raw)
        except InvalidOperation as exc:
            raise ValueError(f"invalid multiplier: {raw}") from exc
        if not value.is_finite() or value <= 0:
            raise ValueError(f"multiplier must be a positive finite number: {raw}")
        if value not in values:
            values.append(value)
    if not values:
        raise ValueError("at least one candidate multiplier is required")
    return values


def as_decimal(value):
    if value is None:
        return None
    try:
        result = Decimal(str(value))
    except InvalidOperation:
        return None
    return result if result.is_finite() else None


def candidate_would_fire(event, multiplier, no_history_means_absent=False):
    """Apply only the rule's threshold condition to one saved event."""
    if no_history_means_absent and event.get("history_debit_count") == 0:
        return False
    if event.get("derived_current_indicator") != "D":
        return False
    current = as_decimal(event.get("derived_current_amount"))
    average = as_decimal(event.get("history_average_amount"))
    if current is None or average is None:
        return False
    return current >= average * multiplier


def evaluate_candidate(events, multiplier, interpretation, no_history_means_absent=False):
    predicted_ids = []
    compared = []
    for event in events:
        predicted = candidate_would_fire(event, multiplier, no_history_means_absent)
        if predicted:
            predicted_ids.append(event.get("transaction_master_id"))
        recorded = event.get("recorded_rule_match")
        if recorded is not None:
            compared.append((predicted, recorded, event.get("transaction_master_id")))

    mismatches = [event_id for predicted, recorded, event_id in compared if predicted != recorded]
    known_fraud = [
        event for event in events
        if (event.get("outcome") or {}).get("label") == "KNOWN_CONFIRMED_FRAUD_CLOSED"
    ]
    known_fp = [
        event for event in events
        if (event.get("outcome") or {}).get("label") == "KNOWN_FALSE_POSITIVE_CLOSED"
    ]
    fraud_ids_fired = [
        event.get("transaction_master_id") for event in known_fraud
        if candidate_would_fire(event, multiplier, no_history_means_absent)
    ]
    fp_ids_fired = [
        event.get("transaction_master_id") for event in known_fp
        if candidate_would_fire(event, multiplier, no_history_means_absent)
    ]
    return {
        "interpretation": interpretation,
        "multiplier": str(multiplier),
        "predicted_fire_count": len(predicted_ids),
        "predicted_fire_event_ids": predicted_ids,
        "empty_history_predicted_fire_count": sum(
            1 for event in events
            if event.get("history_debit_count") == 0
            and candidate_would_fire(event, multiplier, no_history_means_absent)
        ),
        "recorded_rule_match_count": sum(event.get("recorded_rule_match") is True for event in events),
        "comparisons_available": len(compared),
        "agreement_count": sum(predicted == recorded for predicted, recorded, _ in compared),
        "mismatch_count": len(mismatches),
        "mismatch_event_ids": mismatches,
        "known_confirmed_fraud_count": len(known_fraud),
        "known_confirmed_fraud_fired_count": len(fraud_ids_fired),
        "known_confirmed_fraud_missed_count": len(known_fraud) - len(fraud_ids_fired),
        "known_confirmed_fraud_fired_event_ids": fraud_ids_fired,
        "known_false_positive_count": len(known_fp),
        "known_false_positive_fired_count": len(fp_ids_fired),
        "known_false_positive_fired_event_ids": fp_ids_fired,
    }


def run_search(snapshot_dir, multipliers, current_multiplier=Decimal("3")):
    try:
        dataset = load_snapshot_dataset(snapshot_dir)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return {"source": "LOCAL_SNAPSHOT_DIRECTORY", "status": "SNAPSHOT_UNREADABLE", "details": str(exc)}
    events = dataset.get("events") or []
    candidates = {
        "sql_zero_fallback": [
            evaluate_candidate(events, value, "SQL_ZERO_FALLBACK_FROM_BASELINE")
            for value in multipliers
        ],
        "no_history_means_absent": [
            evaluate_candidate(
                events, value, "EXPERIMENTAL_NO_HISTORY_MEANS_METRIC_ABSENT", True
            )
            for value in multipliers
        ],
    }
    known_fp_count = sum(
        (event.get("outcome") or {}).get("label") == "KNOWN_FALSE_POSITIVE_CLOSED"
        for event in events
    )
    return {
        "source": "SAVED_SNAPSHOT_ONLY",
        "status": "CANDIDATE_SEARCH_COMPLETE",
        "snapshot_directory": str(snapshot_dir),
        "snapshot_id": dataset.get("snapshot_id"),
        "scope": dataset.get("scope"),
        "rule": dataset.get("rule"),
        "candidate_set": [str(value) for value in multipliers],
        "current_multiplier": str(current_multiplier),
        "candidates": candidates,
        "selection": {
            "status": "INSUFFICIENT_OUTCOME_EVIDENCE_FOR_RECOMMENDATION"
            if known_fp_count == 0 else "CANDIDATES_READY_FOR_HOLDOUT_VALIDATION",
            "known_false_positive_count": known_fp_count,
            "reason": (
                "No finalized false-positive case exists in this dump; candidate differences "
                "are replay effects, not an optimizer recommendation."
                if known_fp_count == 0 else
                "A candidate still requires time-split validation and known-positive retention checks."
            ),
        },
        "checks": {
            "database_reads": "NONE",
            "database_writes": "NONE",
            "stored_metric_sql_execution": "NOT_RUN",
            "unknown_outcomes_preserved": True,
            "candidate_set_bounded": len(multipliers) <= 20,
            "runtime_behavior_proven": False,
        },
        "next_step": "STOP_FOR_LABEL_REVIEW_OR_RUN_HOLDOUT_DESIGN",
    }


def compact_report(full):
    if full.get("status") != "CANDIDATE_SEARCH_COMPLETE":
        return full
    return {key: full[key] for key in (
        "source", "status", "snapshot_directory", "snapshot_id", "scope", "rule", "candidate_set",
        "current_multiplier", "candidates", "selection", "checks", "next_step",
    )}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--snapshot", type=Path, required=True,
                        help="Path to one partitioned snapshot directory")
    parser.add_argument("--multipliers", default=",".join(DEFAULT_MULTIPLIERS),
                        help="Comma-separated positive decimal candidates (maximum 20)")
    parser.add_argument("--current-multiplier", default="3")
    parser.add_argument("--summary", action="store_true", help="Print compact candidate summaries")
    parser.add_argument("--output", type=Path, help="Also save the full candidate JSON")
    args = parser.parse_args()
    try:
        multipliers = parse_multipliers(args.multipliers)
        current_multiplier = parse_multipliers(args.current_multiplier)[0]
    except ValueError as exc:
        parser.error(str(exc))
    if len(multipliers) > 20:
        parser.error("candidate set is limited to 20 values in this learning lab")
    full = run_search(args.snapshot, multipliers, current_multiplier)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(full, default=str, indent=2) + "\n", encoding="utf-8")
        print(f"Full candidate-search report saved: {args.output}")
    report = compact_report(full) if args.summary else full
    print(json.dumps(report, default=str, indent=2))
    return 0 if full.get("status") == "CANDIDATE_SEARCH_COMPLETE" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print(f"Candidate search setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
