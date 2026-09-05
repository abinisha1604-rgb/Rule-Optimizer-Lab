"""Lesson 7 experiment: compare two interpretations of an empty metric.

The database does not persist the runtime metric map, so this experiment keeps
the uncertainty explicit. It reads the saved baseline JSON only and compares
the existing SQL-zero interpretation with a hypothesis that no debit history
means the metric is absent and the rule cannot fire. It does not change the
database or claim either hypothesis is the production runtime behavior.
"""

import argparse
from collections import Counter
import json
from pathlib import Path
import sys


def no_history_metric_is_missing(event):
    """Apply the experimental hypothesis: no debit history means no metric."""
    if event.get("history_debit_count") == 0:
        return False
    return bool(event.get("rule_would_fire"))


def compare_interpretation(events, name, evaluator):
    """Compare one predicted-fire interpretation with recorded matches."""
    rows = []
    for event in events:
        predicted = bool(evaluator(event))
        recorded = event.get("recorded_rule_match")
        comparison = predicted == recorded if recorded is not None else None
        rows.append({
            "transaction_master_id": event.get("transaction_master_id"),
            "predicted_fire": predicted,
            "recorded_rule_match": recorded,
            "comparison": comparison,
            "history_debit_count": event.get("history_debit_count"),
            "original_replay_fire": event.get("rule_would_fire"),
        })
    compared = [row for row in rows if row["comparison"] is not None]
    mismatches = [row for row in compared if row["comparison"] is False]
    return {
        "interpretation": name,
        "population_count": len(rows),
        "predicted_fire_count": sum(row["predicted_fire"] for row in rows),
        "recorded_rule_match_count": sum(row["recorded_rule_match"] is True for row in rows),
        "comparisons_available": len(compared),
        "agreement_count": sum(row["comparison"] is True for row in compared),
        "mismatch_count": len(mismatches),
        "mismatch_event_ids": [row["transaction_master_id"] for row in mismatches],
        "rows": rows,
    }


def run_experiment(baseline_path):
    try:
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return {"source": "LOCAL_FILE", "status": "BASELINE_FILE_UNREADABLE", "details": str(exc)}
    if baseline.get("status") != "BASELINE_REPLAY_COMPLETE":
        return {
            "source": "LOCAL_FILE",
            "status": "BASELINE_STATUS_NOT_COMPLETE",
            "baseline_status": baseline.get("status"),
        }
    events = baseline.get("events") or []
    sql_zero = compare_interpretation(
        events, "SQL_ZERO_FALLBACK_FROM_BASELINE", lambda event: event.get("rule_would_fire")
    )
    no_history = compare_interpretation(
        events, "EXPERIMENTAL_NO_HISTORY_MEANS_METRIC_ABSENT", no_history_metric_is_missing
    )
    return {
        "source": "SAVED_BASELINE_ONLY",
        "status": "RUNTIME_SEMANTICS_EXPERIMENT_COMPLETE",
        "baseline_file": str(baseline_path),
        "rule": baseline.get("rule"),
        "scope": baseline.get("scope"),
        "hypotheses": [
            {
                "name": sql_zero["interpretation"],
                "meaning": "Use the stored metric text's COALESCE(AVG(...), 0) result.",
                "evidence": "Direct replay semantics only; runtime metric presence is not persisted.",
            },
            {
                "name": no_history["interpretation"],
                "meaning": "Do not fire when no prior debit exists because the metric is considered absent.",
                "evidence": "A testable hypothesis motivated by the DRL non-null metric guard, not proof of runtime behavior.",
            },
        ],
        "comparison": {
            "sql_zero_fallback": {key: value for key, value in sql_zero.items() if key != "rows"},
            "no_history_means_absent": {key: value for key, value in no_history.items() if key != "rows"},
        },
        "checks": {
            "database_reads": "NONE",
            "database_writes": "NONE",
            "stored_metric_sql_execution": "NOT_RUN",
            "runtime_behavior_proven": False,
        },
        "next_step": "INSPECT_NONEMPTY_MISMATCHES_123_AND_133",
        "events_by_interpretation": {
            "sql_zero_fallback": sql_zero["rows"],
            "no_history_means_absent": no_history["rows"],
        },
    }


def compact_report(full):
    if full.get("status") != "RUNTIME_SEMANTICS_EXPERIMENT_COMPLETE":
        return full
    report = {key: full[key] for key in (
        "source", "status", "baseline_file", "rule", "scope", "hypotheses",
        "comparison", "checks", "next_step",
    )}
    report["comparison_note"] = (
        "The second interpretation is an experiment. It improves agreement in this dump, "
        "but is not accepted as runtime truth without engine evidence."
    )
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=Path("outputs/baseline_cust_spend_v1.json"))
    parser.add_argument("--summary", action="store_true", help="Omit per-event interpretation rows")
    parser.add_argument("--output", type=Path, help="Also save the full experiment JSON")
    args = parser.parse_args()
    full = run_experiment(args.baseline)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(full, default=str, indent=2) + "\n", encoding="utf-8")
        print(f"Full semantics experiment saved: {args.output}")
    report = compact_report(full) if args.summary else full
    print(json.dumps(report, default=str, indent=2))
    return 0 if full.get("status") == "RUNTIME_SEMANTICS_EXPERIMENT_COMPLETE" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print(f"Runtime semantics experiment setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
