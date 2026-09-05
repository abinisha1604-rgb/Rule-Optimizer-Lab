"""Lesson 8: build a historical replay dataset with separate outcome labels.

The baseline replay already contains every event in the selected scope. This
lesson attaches case evidence from the local database while keeping rule-match
status and human case outcome separate. A non-match is not called legitimate,
and an open/action-failed case is not treated as a final label. All database
work is read-only; stored metric SQL is never executed.
"""

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import sys

import psycopg
from psycopg.rows import dict_row

from local_postgres import CONFIG, PASSWORD_FILE


CASE_EVIDENCE_QUERY = """
SELECT tm.id AS transaction_master_id,
       ta.id AS transaction_alert_id,
       cam.case_id,
       cam.status AS mapping_status,
       cam.decision_code AS mapping_decision_code,
       cm.status AS case_status,
       cm.decision_code AS case_decision_code,
       cm.approval_status,
       cm.decision_submitted_at,
       cm.approved_at
FROM efrm.transaction_master AS tm
LEFT JOIN efrm.transaction_result AS tr
  ON tr.transaction_master_id = tm.id
LEFT JOIN efrm.transaction_alert AS ta
  ON ta.transaction_result_id = tr.id
LEFT JOIN efrm.case_alert_mapping AS cam
  ON cam.alert_source_table = 'transaction_alert'
 AND cam.alert_id = ta.id
LEFT JOIN efrm.case_master AS cm
  ON cm.case_id = cam.case_id
WHERE tm.institution_id = %s
  AND tm.source_system = %s
  AND tm.id = ANY(%s)
ORDER BY tm.id, ta.id, cam.id
"""


def rule_match_label(value):
    """Describe exact rule-match evidence without assigning an outcome."""
    if value is True:
        return "MATCHED_RULE_VERSION"
    if value is False:
        return "NO_MATCHED_RULE_VERSION"
    return "UNKNOWN_RESULT"


def classify_case_outcome(case_rows):
    """Classify supervision conservatively from linked case state.

    A closed case with a decision is usable as a known outcome for this lab.
    Decision codes on an open or action-failed case remain visible but are not
    promoted to a final training label.
    """
    rows = [row for row in (case_rows or []) if row.get("case_id") is not None]
    if not rows:
        return {
            "label": "UNKNOWN_NO_CASE_LINK",
            "supervision": "UNKNOWN",
            "case_ids": [],
            "decision_codes": [],
            "case_statuses": [],
        }
    case_ids = sorted({row.get("case_id") for row in rows})
    decision_codes = sorted({
        row.get("case_decision_code")
        for row in rows if row.get("case_decision_code")
    })
    statuses = sorted({row.get("case_status") for row in rows if row.get("case_status")})
    closed_decisions = [
        row for row in rows
        if row.get("case_status") == "CLOSED" and row.get("case_decision_code")
    ]
    if closed_decisions:
        if any(row.get("case_decision_code") == "FALSE_POSITIVE" for row in closed_decisions):
            label = "KNOWN_FALSE_POSITIVE_CLOSED"
        elif any(row.get("case_decision_code") == "CONFIRMED_FRAUD" for row in closed_decisions):
            label = "KNOWN_CONFIRMED_FRAUD_CLOSED"
        else:
            label = "KNOWN_OTHER_DECISION_CLOSED"
        supervision = "KNOWN"
    elif decision_codes:
        label = "UNKNOWN_DECISION_PRESENT_CASE_NOT_CLOSED"
        supervision = "UNKNOWN"
    else:
        label = "UNKNOWN_CASE_NOT_DECIDED"
        supervision = "UNKNOWN"
    return {
        "label": label,
        "supervision": supervision,
        "case_ids": case_ids,
        "decision_codes": decision_codes,
        "case_statuses": statuses,
    }


def build_dataset_rows(events, case_rows_by_event):
    """Attach case evidence to saved baseline events without relabeling them."""
    dataset = []
    for event in events:
        event_id = event.get("transaction_master_id")
        outcome = classify_case_outcome(case_rows_by_event.get(event_id, []))
        dataset.append({
            "transaction_master_id": event_id,
            "timestamp": event.get("timestamp"),
            "channel": event.get("channel"),
            "txn_type": event.get("txn_type"),
            "customer_id": event.get("customer_id"),
            "history_debit_count": event.get("history_debit_count"),
            "history_average_amount": event.get("history_average_amount"),
            "threshold_amount": event.get("threshold_amount"),
            "derived_current_amount": event.get("derived_current_amount"),
            "derived_current_indicator": event.get("derived_current_indicator"),
            "replay_reason": event.get("reason"),
            "rule_would_fire": event.get("rule_would_fire"),
            "recorded_rule_match": event.get("recorded_rule_match"),
            "rule_match_label": rule_match_label(event.get("recorded_rule_match")),
            "comparison": event.get("comparison"),
            "final_decision": event.get("result_decisions", [None])[0]
            if event.get("result_decisions") else None,
            "result_decisions": event.get("result_decisions", []),
            "result_scores": event.get("result_scores", []),
            "outcome": outcome,
            "case_evidence": [
                {key: row.get(key) for key in (
                    "transaction_alert_id", "case_id", "mapping_status",
                    "mapping_decision_code", "case_status", "case_decision_code",
                    "approval_status", "decision_submitted_at", "approved_at",
                )}
                for row in case_rows_by_event.get(event_id, [])
            ],
        })
    return dataset


def run_dataset(baseline_path, institution_id, source_system):
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
    scope = baseline.get("scope") or {}
    if scope.get("institution_id") != institution_id or scope.get("source_system") != source_system:
        return {
            "source": "LOCAL_FILE",
            "status": "BASELINE_SCOPE_MISMATCH",
            "baseline_scope": scope,
            "requested_scope": {"institution_id": institution_id, "source_system": source_system},
        }
    events = baseline.get("events") or []
    event_ids = [event.get("transaction_master_id") for event in events]
    if any(event_id is None for event_id in event_ids):
        return {"source": "LOCAL_FILE", "status": "EVENT_ID_MISSING"}
    if len(event_ids) != len(set(event_ids)):
        return {"source": "LOCAL_FILE", "status": "DUPLICATE_EVENT_IDS"}

    password = PASSWORD_FILE.read_text(encoding="utf-8").strip()
    with psycopg.connect(
        **CONFIG,
        password=password,
        connect_timeout=5,
        row_factory=dict_row,
        options="-c default_transaction_read_only=on -c statement_timeout=30000",
    ) as conn:
        identity = conn.execute(
            "SELECT current_database() AS current_database, "
            "current_user AS current_user, "
            "current_setting('transaction_read_only') AS transaction_read_only"
        ).fetchone()
        evidence_rows = [dict(row) for row in conn.execute(
            CASE_EVIDENCE_QUERY, (institution_id, source_system, event_ids)
        ).fetchall()]

    case_rows_by_event = defaultdict(list)
    for row in evidence_rows:
        if row.get("case_id") is not None:
            case_rows_by_event[row["transaction_master_id"]].append(row)
    dataset = build_dataset_rows(events, case_rows_by_event)
    outcome_counts = Counter(row["outcome"]["label"] for row in dataset)
    rule_match_counts = Counter(row["rule_match_label"] for row in dataset)
    known = [row for row in dataset if row["outcome"]["supervision"] == "KNOWN"]
    return {
        "source": "LOCAL_DATABASE_AND_SAVED_BASELINE",
        "status": "HISTORICAL_DATASET_COMPLETE",
        "baseline_file": str(baseline_path),
        "scope": {"institution_id": institution_id, "source_system": source_system},
        "rule": baseline.get("rule"),
        "summary": {
            "population_count": len(dataset),
            "unique_event_ids": len({row["transaction_master_id"] for row in dataset}),
            "rule_match_label_counts": dict(rule_match_counts),
            "outcome_label_counts": dict(outcome_counts),
            "known_outcome_count": len(known),
            "unknown_outcome_count": len(dataset) - len(known),
            "known_false_positive_count": sum(
                row["outcome"]["label"] == "KNOWN_FALSE_POSITIVE_CLOSED" for row in dataset
            ),
            "known_confirmed_fraud_count": sum(
                row["outcome"]["label"] == "KNOWN_CONFIRMED_FRAUD_CLOSED" for row in dataset
            ),
            "next_step": "BOUND_CANDIDATE_SEARCH_WITH_UNKNOWN_LABELS_PRESERVED",
        },
        "checks": {
            "database": identity["current_database"],
            "database_user": identity["current_user"],
            "transaction_read_only": identity["transaction_read_only"],
            "database_writes": "NONE",
            "stored_metric_sql_execution": "NOT_RUN",
            "no_match_is_legitimate_label": False,
            "nonclosed_case_decision_is_known_outcome": False,
        },
        "label_definitions": {
            "KNOWN_FALSE_POSITIVE_CLOSED": "Closed case with final FALSE_POSITIVE decision.",
            "KNOWN_CONFIRMED_FRAUD_CLOSED": "Closed case with final CONFIRMED_FRAUD decision.",
            "KNOWN_OTHER_DECISION_CLOSED": "Closed case with another final decision.",
            "UNKNOWN_DECISION_PRESENT_CASE_NOT_CLOSED": "Decision exists, but case is not closed.",
            "UNKNOWN_CASE_NOT_DECIDED": "Linked case has no submitted decision.",
            "UNKNOWN_NO_CASE_LINK": "No transaction-alert-to-case link was found.",
        },
        "events": dataset,
    }


def compact_report(full):
    if full.get("status") != "HISTORICAL_DATASET_COMPLETE":
        return full
    return {key: full[key] for key in (
        "source", "status", "baseline_file", "scope", "rule", "summary", "checks", "label_definitions",
    )}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=Path("outputs/baseline_cust_spend_v1.json"))
    parser.add_argument("--institution", default="KANJI")
    parser.add_argument("--source-system", default="CARD_TRANSACTION")
    parser.add_argument("--summary", action="store_true", help="Omit row-by-row dataset")
    parser.add_argument("--output", type=Path, help="Also save the full dataset JSON")
    args = parser.parse_args()
    full = run_dataset(args.baseline, args.institution, args.source_system)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(full, default=str, indent=2) + "\n", encoding="utf-8")
        print(f"Full historical dataset saved: {args.output}")
    report = compact_report(full) if args.summary else full
    print(json.dumps(report, default=str, indent=2))
    return 0 if full.get("status") == "HISTORICAL_DATASET_COMPLETE" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except psycopg.Error as exc:
        print(f"Database read failed ({type(exc).__name__}). Check that the lab is running.", file=sys.stderr)
        raise SystemExit(1)
    except (OSError, ValueError) as exc:
        print(f"Historical dataset setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
