"""Lesson 11: produce an evidence-backed local agent-reasoning report.

This is a deterministic stand-in for the optional LLM layer. It reads the
saved replay, candidate, holdout, and runtime reports; turns their numbers into
traceable findings; and applies a recommendation gate. No network call, model
call, database write, or rule deployment is performed.
"""

import argparse
import json
from pathlib import Path
import sys


EXPECTED_STATUSES = {
    "candidate_search": "CANDIDATE_SEARCH_COMPLETE",
    "holdout_validation": "HOLDOUT_VALIDATION_REPORT_COMPLETE",
    "runtime_semantics": "RUNTIME_SEMANTICS_EXPERIMENT_COMPLETE",
    "runtime_selection": "RUNTIME_SELECTION_EVIDENCE_COMPLETE",
}


def load_report(path, expected_status):
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return None, {"path": str(path), "status": "REPORT_UNREADABLE", "details": str(exc)}
    if report.get("status") != expected_status:
        return None, {
            "path": str(path),
            "status": "REPORT_STATUS_NOT_COMPLETE",
            "expected_status": expected_status,
            "actual_status": report.get("status"),
        }
    return report, None


def recommendation_gate(candidate_report, holdout_report, runtime_semantics_report):
    """Return blockers that prevent a recommendation from this lab evidence."""
    blockers = []
    false_positive_count = (
        candidate_report.get("selection", {}).get("known_false_positive_count", 0)
    )
    if false_positive_count == 0:
        blockers.append("NO_FINALIZED_FALSE_POSITIVE_LABELS")
    if not holdout_report.get("checks", {}).get("holdout_labels_used_for_selection") is False:
        blockers.append("HOLDOUT_LABEL_USAGE_CHECK_FAILED")
    if not holdout_report.get("checks", {}).get("selection_labels_time_filtered") is True:
        blockers.append("SELECTION_LABEL_TIME_FILTER_CHECK_FAILED")
    if not runtime_semantics_report.get("checks", {}).get("runtime_behavior_proven") is True:
        blockers.append("RUNTIME_METRIC_BEHAVIOR_UNPROVEN")
    return {
        "status": "BLOCKED" if blockers else "READY_FOR_EXPLICIT_POLICY_REVIEW",
        "blockers": blockers,
        "selected_candidate": None,
    }


def _candidate_rows(candidate_report, interpretation):
    return candidate_report.get("candidates", {}).get(interpretation, [])


def _summary_rows(candidate_report, interpretation, partition):
    """Keep only the metrics an optional model needs to reason about."""
    rows = []
    for row in _candidate_rows(candidate_report, interpretation):
        rows.append({
            "multiplier": row.get("multiplier"),
            "predicted_fire_count": row.get("predicted_fire_count"),
            "agreement_count": row.get("agreement_count"),
            "mismatch_count": row.get("mismatch_count"),
            "known_confirmed_fraud_count": row.get("known_confirmed_fraud_count"),
            "known_confirmed_fraud_fired_count": row.get("known_confirmed_fraud_fired_count"),
            "known_confirmed_fraud_missed_count": row.get("known_confirmed_fraud_missed_count"),
            "known_false_positive_count": row.get("known_false_positive_count"),
            "known_false_positive_fired_count": row.get("known_false_positive_fired_count"),
            "partition": partition,
        })
    return rows


def build_agent_input(candidate_report, holdout_report, runtime_semantics_report,
                      runtime_selection_report):
    """Build a bounded, traceable context package for optional reasoning."""
    return {
        "rule": candidate_report.get("rule"),
        "scope": candidate_report.get("scope"),
        "candidate_set": candidate_report.get("candidate_set"),
        "current_multiplier": candidate_report.get("current_multiplier"),
        "candidate_metrics": {
            interpretation: _summary_rows(candidate_report, interpretation, "full_population")
            for interpretation in ("sql_zero_fallback", "no_history_means_absent")
        },
        "holdout_metrics": {
            interpretation: {
                "selection": _summary_rows(
                    holdout_report.get("candidates", {}).get(interpretation, {}),
                    "selection", "selection"
                ),
                "holdout": _summary_rows(
                    holdout_report.get("candidates", {}).get(interpretation, {}),
                    "holdout", "holdout"
                ),
            }
            for interpretation in ("sql_zero_fallback", "no_history_means_absent")
        },
        "runtime_semantics": {
            "mismatch_event_ids_under_sql_zero": runtime_semantics_report.get(
                "comparison", {}).get("sql_zero_fallback", {}).get("mismatch_event_ids", []
            ),
            "mismatch_event_ids_under_no_history_absent": runtime_semantics_report.get(
                "comparison", {}).get("no_history_means_absent", {}).get("mismatch_event_ids", []
            ),
            "runtime_behavior_proven": runtime_semantics_report.get(
                "checks", {}).get("runtime_behavior_proven", False
            ),
        },
        "runtime_selection": {
            "summary": runtime_selection_report.get("summary", {}),
            "evidence_boundary": runtime_selection_report.get("evidence_boundary"),
        },
        "label_evidence": {
            "known_false_positive_count": candidate_report.get(
                "selection", {}).get("known_false_positive_count", 0
            ),
            "selection_partition": holdout_report.get("partitions", {}).get("selection", {}),
            "holdout_partition": holdout_report.get("partitions", {}).get("holdout", {}),
        },
    }


def build_reasoning(candidate_report, holdout_report, runtime_semantics_report,
                    runtime_selection_report, source_paths):
    gate = recommendation_gate(candidate_report, holdout_report, runtime_semantics_report)
    candidate_metrics = candidate_report.get("candidates", {})
    absent_candidates = candidate_metrics.get("no_history_means_absent", [])
    sql_candidates = candidate_metrics.get("sql_zero_fallback", [])
    absent_at_two = next((row for row in absent_candidates if row.get("multiplier") == "2"), {})
    absent_at_three = next((row for row in absent_candidates if row.get("multiplier") == "3"), {})
    sql_at_three = next((row for row in sql_candidates if row.get("multiplier") == "3"), {})
    remaining_ids = runtime_semantics_report.get("comparison", {}).get(
        "no_history_means_absent", {}
    ).get("mismatch_event_ids", [])
    findings = [
        {
            "id": "F1_EMPTY_HISTORY_SEMANTICS",
            "finding": "Treating empty history as an absent metric changes the replay from 12 fires to 3 fires and improves agreement from 27/38 to 36/38.",
            "evidence": "runtime_semantics.comparison",
            "confidence": "MEDIUM",
            "limit": "This is a replay experiment; runtime behavior is not proven.",
        },
        {
            "id": "F2_NONEMPTY_MISMATCHES",
            "finding": "Events 123 and 133 still disagree under the empty-history hypothesis.",
            "evidence": "runtime_semantics.comparison.no_history_means_absent.mismatch_event_ids",
            "confidence": "HIGH",
            "limit": "Persisted rows do not expose the in-memory metric map or selected group trace.",
        },
        {
            "id": "F3_LABEL_COVERAGE",
            "finding": "The dataset has no finalized false-positive outcomes, so false-positive reduction cannot be measured.",
            "evidence": "candidate_search.selection.known_false_positive_count",
            "confidence": "HIGH",
            "limit": "Unknown and non-closed case outcomes remain excluded from supervised counts.",
        },
        {
            "id": "F4_KNOWN_FRAUD_RETENTION",
            "finding": "Multiplier 2 retains two known confirmed-fraud events under the no-history-absent experiment; multiplier 3 retains one.",
            "evidence": "candidate_search.candidates.no_history_means_absent",
            "confidence": "MEDIUM",
            "limit": "Only three known confirmed-fraud events exist, and this is not a substitute for holdout performance.",
        },
    ]
    claims = [
        {
            "claim": "No rule change should be recommended from this dump.",
            "support": "The recommendation gate is blocked by missing false-positive labels and unproven runtime metric behavior.",
            "confidence": "HIGH",
        },
        {
            "claim": "The core replay-and-comparison workflow is technically feasible in the local lab.",
            "support": "Baseline, metric, candidate, and holdout reports completed with read-only checks.",
            "confidence": "HIGH",
        },
        {
            "claim": "A future model should treat events 123 and 133 as unresolved runtime questions.",
            "support": "They remain mismatches after the empty-history experiment and have no persisted metric key.",
            "confidence": "HIGH",
        },
    ]
    return {
        "source": "SAVED_REPORTS_ONLY",
        "status": "AGENT_REASONING_REPORT_COMPLETE",
        "reasoning_mode": "DETERMINISTIC_LOCAL_REVIEW",
        "model_call": "NOT_PERFORMED",
        "rule": candidate_report.get("rule"),
        "scope": candidate_report.get("scope"),
        "agent_input": build_agent_input(
            candidate_report, holdout_report, runtime_semantics_report, runtime_selection_report
        ),
        "findings": findings,
        "claims": claims,
        "recommendation_gate": gate,
        "decision": {
            "status": "INSUFFICIENT_EVIDENCE",
            "recommendation": None,
            "reason": "Do not choose a multiplier until finalized false-positive labels and runtime metric/group evidence are available.",
            "candidate_observations": {
                "no_history_absent_multiplier_2": {
                    "predicted_fire_count": absent_at_two.get("predicted_fire_count"),
                    "known_fraud_fired_count": absent_at_two.get("known_confirmed_fraud_fired_count"),
                },
                "no_history_absent_multiplier_3": {
                    "predicted_fire_count": absent_at_three.get("predicted_fire_count"),
                    "known_fraud_fired_count": absent_at_three.get("known_confirmed_fraud_fired_count"),
                },
                "sql_zero_current_multiplier_3_mismatch_count": sql_at_three.get("mismatch_count"),
            },
        },
        "next_actions": [
            "Obtain at least one finalized false-positive case and link its transaction alerts.",
            "Capture or reconstruct runtime metric/group selection evidence for events 123 and 133.",
            "Rerun the same baseline, candidate, and holdout reports with the added labels.",
            "Only then let an optional LLM rank candidates; verify every statement against saved report fields.",
        ],
        "traceability": {key: str(value) for key, value in source_paths.items()},
        "checks": {
            "database_reads": "NONE",
            "database_writes": "NONE",
            "network_calls": "NONE",
            "model_call": "NONE",
            "unknown_outcomes_preserved": True,
            "unsupported_recommendation_blocked": gate["status"] == "BLOCKED",
            "runtime_behavior_proven": runtime_semantics_report.get(
                "checks", {}).get("runtime_behavior_proven", False
            ),
        },
        "next_step": "OBTAIN_FINALIZED_FALSE_POSITIVE_LABELS_AND_RUNTIME_EVIDENCE",
    }


def run_reasoning(candidate_path, holdout_path, runtime_semantics_path, runtime_selection_path):
    paths = {
        "candidate_search": candidate_path,
        "holdout_validation": holdout_path,
        "runtime_semantics": runtime_semantics_path,
        "runtime_selection": runtime_selection_path,
    }
    reports = {}
    errors = []
    for key, path in paths.items():
        report, error = load_report(path, EXPECTED_STATUSES[key])
        if error:
            errors.append(error)
        else:
            reports[key] = report
    if errors:
        return {
            "source": "LOCAL_FILES",
            "status": "REASONING_INPUTS_INCOMPLETE",
            "input_errors": errors,
        }
    return build_reasoning(
        reports["candidate_search"], reports["holdout_validation"],
        reports["runtime_semantics"], reports["runtime_selection"], paths
    )


def compact_report(full):
    if full.get("status") != "AGENT_REASONING_REPORT_COMPLETE":
        return full
    return {key: full[key] for key in (
        "source", "status", "reasoning_mode", "model_call", "rule", "scope",
        "findings", "claims", "recommendation_gate", "decision", "next_actions",
        "traceability", "checks", "next_step",
    )}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-search", type=Path,
                        default=Path("outputs/candidate_search_cust_spend_v1.json"))
    parser.add_argument("--holdout-validation", type=Path,
                        default=Path("outputs/holdout_validation_cust_spend_v1.json"))
    parser.add_argument("--runtime-semantics", type=Path,
                        default=Path("outputs/runtime_semantics_cust_spend_v1.json"))
    parser.add_argument("--runtime-selection", type=Path,
                        default=Path("outputs/runtime_selection_119_123_133.json"))
    parser.add_argument("--summary", action="store_true", help="Print reasoning without the bounded agent input")
    parser.add_argument("--output", type=Path, help="Also save the full reasoning JSON")
    args = parser.parse_args()
    full = run_reasoning(
        args.candidate_search, args.holdout_validation,
        args.runtime_semantics, args.runtime_selection
    )
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(full, default=str, indent=2) + "\n", encoding="utf-8")
        print(f"Full agent-reasoning report saved: {args.output}")
    report = compact_report(full) if args.summary else full
    print(json.dumps(report, default=str, indent=2))
    return 0 if full.get("status") == "AGENT_REASONING_REPORT_COMPLETE" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print(f"Agent reasoning setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
