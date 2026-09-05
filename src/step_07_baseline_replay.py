"""Lesson 5: replay one unchanged rule over the local event population.

This lesson includes every transaction in the selected local scope, including
events with no recorded match. It uses the allow-listed metric calculation from
``step_06_metric_replay`` and compares the result with ``transaction_match``.
It does not execute stored metric SQL, change the database, or label outcomes.
"""

import argparse
from collections import Counter, defaultdict
from datetime import timedelta
from pathlib import Path
from decimal import Decimal
import json
import sys

import psycopg
from psycopg.rows import dict_row

from local_postgres import CONFIG, PASSWORD_FILE
from step_06_metric_replay import (
    MAX_HISTORY_ROWS,
    MULTIPLIER_QUERY,
    REQUIRED_DATA_QUERY,
    RULE_QUERY,
    calculate_average,
    derive_amount,
    derive_indicator,
    extract_multiplier_reference,
    resolve_multiplier,
)


EVENT_QUERY = """
SELECT tm.id AS transaction_master_id,
       tm.institution_id, tm.source_system, tm.channel, tm.txn_type,
       tm.txn_sub_type, tm.customer_id, tm.txn_amount, tm.txn_timestamp,
       tm.source_txn_id,
       tm.rule_engine_context #>> '{transaction,drCrAmount}' AS context_drcr_amount,
       tm.rule_engine_context #>> '{transaction,drCrIndicator}' AS context_drcr_indicator,
       r.id AS transaction_result_id,
       r.final_decision,
       r.overall_score,
       r.matched_rule_count
FROM efrm.transaction_master AS tm
LEFT JOIN efrm.transaction_result AS r
  ON r.transaction_master_id = tm.id
WHERE tm.institution_id = %s
  AND tm.source_system = %s
ORDER BY tm.txn_timestamp, tm.id, r.id
"""


HISTORY_POPULATION_QUERY = """
SELECT id, institution_id, source_system, customer_id, source_txn_id,
       txn_type, txn_amount, txn_timestamp,
       rule_engine_context #>> '{transaction,drCrAmount}' AS context_drcr_amount,
       rule_engine_context #>> '{transaction,drCrIndicator}' AS context_drcr_indicator
FROM efrm.transaction_master
WHERE institution_id = %s
  AND source_system = %s
ORDER BY txn_timestamp, id
"""


RECORDED_MATCH_QUERY = """
SELECT r.transaction_master_id, r.id AS transaction_result_id,
       x.id AS transaction_match_id, x.rule_code, x.rule_version,
       x.signal_code
FROM efrm.transaction_result AS r
JOIN efrm.transaction_match AS x
  ON x.transaction_result_id = r.id
JOIN efrm.transaction_master AS tm
  ON tm.id = r.transaction_master_id
WHERE tm.institution_id = %s
  AND tm.source_system = %s
  AND x.rule_code = %s
  AND x.rule_version = %s
ORDER BY r.transaction_master_id, x.id
"""


def group_event_rows(rows):
    """Collapse result joins to one event and retain duplicate-result diagnostics."""
    grouped = defaultdict(list)
    for row in rows:
        grouped[row["transaction_master_id"]].append(dict(row))
    events = []
    duplicate_result_event_ids = []
    for event_id, candidates in grouped.items():
        base = dict(candidates[0])
        result_rows = [row for row in candidates if row["transaction_result_id"] is not None]
        if len(result_rows) > 1:
            duplicate_result_event_ids.append(event_id)
        base["result_ids"] = [row["transaction_result_id"] for row in result_rows]
        base["result_decisions"] = sorted({
            row["final_decision"] for row in result_rows if row["final_decision"] is not None
        })
        base["result_scores"] = sorted({
            row["overall_score"] for row in result_rows if row["overall_score"] is not None
        })
        events.append(base)
    events.sort(key=lambda row: (row["txn_timestamp"] is None,
                                 row["txn_timestamp"], row["transaction_master_id"]))
    return events, duplicate_result_event_ids


def evaluate_event(event, history_population, multiplier, window_days,
                   recorded_match, recorded_rows):
    """Evaluate the simple rule using only point-in-time history for this event."""
    event_id = event["transaction_master_id"]
    if event["txn_timestamp"] is None:
        return {
            "transaction_master_id": event_id,
            "status": "SKIPPED_MISSING_TIMESTAMP",
            "rule_would_fire": False,
            "recorded_rule_match": recorded_match,
            "comparison": None,
        }
    if event.get("customer_id") is None:
        return {
            "transaction_master_id": event_id,
            "status": "SKIPPED_MISSING_CUSTOMER",
            "rule_would_fire": False,
            "recorded_rule_match": recorded_match,
            "comparison": None,
        }

    start_at = event["txn_timestamp"] - timedelta(days=window_days)
    candidates = [
        row for row in history_population
        if row.get("institution_id") == event.get("institution_id")
        and row.get("source_system") == event.get("source_system")
        and row.get("customer_id") == event.get("customer_id")
        and row.get("txn_timestamp") is not None
        and start_at <= row["txn_timestamp"] < event["txn_timestamp"]
        and str(row.get("source_txn_id") or "") != str(event.get("source_txn_id") or "")
    ]
    metric = calculate_average(candidates)
    current_indicator = derive_indicator(
        event.get("context_drcr_indicator"), event.get("txn_type")
    )
    current_amount = derive_amount(
        event.get("context_drcr_amount"), event.get("txn_amount")
    )
    threshold = metric["average_amount"] * multiplier
    would_fire = (
        current_indicator == "D"
        and current_amount is not None
        and current_amount >= threshold
    )
    if current_indicator != "D":
        reason = "CURRENT_TRANSACTION_IS_NOT_DEBIT"
    elif current_amount is None:
        reason = "CURRENT_AMOUNT_IS_MISSING_OR_NOT_NUMERIC"
    elif current_amount >= threshold:
        reason = "CURRENT_AMOUNT_MEETS_AVERAGE_TIMES_MULTIPLIER"
    else:
        reason = "CURRENT_AMOUNT_BELOW_AVERAGE_TIMES_MULTIPLIER"
    result_available = bool(event.get("result_ids"))
    comparison = would_fire == recorded_match if result_available else None
    return {
        "transaction_master_id": event_id,
        "transaction_result_ids": event.get("result_ids", []),
        "timestamp": event["txn_timestamp"],
        "channel": event.get("channel"),
        "txn_type": event.get("txn_type"),
        "customer_id": event.get("customer_id"),
        "stored_txn_amount": event.get("txn_amount"),
        "derived_current_amount": current_amount,
        "derived_current_indicator": current_indicator,
        "window_start_inclusive": start_at,
        "window_end_exclusive": event["txn_timestamp"],
        "history_candidate_count": metric["candidate_row_count"],
        "history_debit_count": metric["debit_count"],
        "history_debit_ids": [item["id"] for item in metric["included"]],
        "history_sum_amount": metric["sum_amount"],
        "history_average_amount": metric["average_amount"],
        "multiplier": multiplier,
        "threshold_amount": threshold,
        "rule_would_fire": would_fire,
        "reason": reason,
        "invalid_history_amount_rows": metric["invalid_amount_rows"],
        "recorded_rule_match": recorded_match,
        "recorded_match_rows": recorded_rows,
        "comparison": comparison,
        "status": "EVALUATED",
    }


def summarize_events(events):
    """Count baseline outcomes without treating unknown results as negatives."""
    status_counts = Counter(event.get("status") for event in events)
    predicted_count = sum(1 for event in events if event.get("rule_would_fire"))
    recorded_count = sum(1 for event in events if event.get("recorded_rule_match") is True)
    compared = [event for event in events if event.get("comparison") is not None]
    agreements = sum(1 for event in compared if event["comparison"] is True)
    mismatches = [event for event in compared if event["comparison"] is False]
    return {
        "status": "BASELINE_REPLAY_COMPLETE",
        "population_count": len(events),
        "evaluated_count": status_counts.get("EVALUATED", 0),
        "skipped_count": len(events) - status_counts.get("EVALUATED", 0),
        "predicted_fire_count": predicted_count,
        "recorded_rule_match_count": recorded_count,
        "comparisons_available": len(compared),
        "agreement_count": agreements,
        "mismatch_count": len(mismatches),
        "mismatch_event_ids": [event["transaction_master_id"] for event in mismatches],
        "no_result_count": sum(1 for event in events if not event.get("transaction_result_ids")),
        "empty_history_count": sum(
            1 for event in events
            if event.get("status") == "EVALUATED" and event.get("history_debit_count") == 0
        ),
        "status_counts": dict(status_counts),
        "recorded_decision_counts": dict(Counter(
            decision
            for event in events
            for decision in event.get("result_decisions", [])
        )),
        "next_step": "INSPECT_BASELINE_MISMATCHES"
        if mismatches else "ATTACH_OUTCOME_LABELS",
    }


def load_rule_context(conn, rule_code, version_no):
    rows = [dict(row) for row in conn.execute(RULE_QUERY, (rule_code, version_no)).fetchall()]
    if not rows:
        return None, {
            "status": "RULE_VERSION_NOT_FOUND",
            "requested_rule_code": rule_code,
            "requested_version_no": version_no,
        }
    dependencies = [row for row in rows if row.get("metric_code")]
    if len(dependencies) != 1:
        return None, {
            "status": "UNSUPPORTED_METRIC_DEPENDENCIES",
            "dependency_count": len(dependencies),
        }
    dependency = dependencies[0]
    if (dependency["metric_code"], dependency["entity_type"], dependency["window_size"]) != (
        "AVG_DEBIT_30DAY", "CUSTOMER", "30DAY"
    ):
        return None, {
            "status": "METRIC_NOT_SUPPORTED_BY_THIS_LESSON",
            "dependency": dependency,
        }
    required = [dict(row) for row in conn.execute(
        REQUIRED_DATA_QUERY, (dependency["rule_version_id"],)
    ).fetchall()]
    reference, reference_error = extract_multiplier_reference(required)
    if reference_error:
        return None, {"status": reference_error["status"], "details": reference_error}
    multiplier_rows = conn.execute(MULTIPLIER_QUERY, (reference,)).fetchall()
    multiplier, multiplier_info = resolve_multiplier(multiplier_rows)
    if multiplier is None:
        return None, {"status": multiplier_info["status"], "details": multiplier_info}
    return {
        "rule": {
            "rule_master_id": dependency["rule_master_id"],
            "rule_version_id": dependency["rule_version_id"],
            "rule_code": dependency["rule_code"],
            "version_no": dependency["version_no"],
            "status": dependency["rule_status"],
        },
        "metric": {
            "code": dependency["metric_code"],
            "entity_type": dependency["entity_type"],
            "window_type": dependency["window_type"],
            "window_size": dependency["window_size"],
            "stored_sql_present": bool(dependency["sql_statement"]),
        },
        "multiplier": multiplier,
        "multiplier_info": multiplier_info,
    }, None


def run_baseline(rule_code, version_no, institution_id, source_system):
    password = PASSWORD_FILE.read_text(encoding="utf-8").strip()
    with psycopg.connect(
        **CONFIG, password=password, connect_timeout=5, row_factory=dict_row,
        options="-c default_transaction_read_only=on -c statement_timeout=30000",
    ) as conn:
        context, error = load_rule_context(conn, rule_code, version_no)
        if error:
            return {"source": "LOCAL_DATABASE", **error}
        event_rows = conn.execute(EVENT_QUERY, (institution_id, source_system)).fetchall()
        history_rows = [dict(row) for row in conn.execute(
            HISTORY_POPULATION_QUERY, (institution_id, source_system)
        ).fetchall()]
        match_rows = conn.execute(
            RECORDED_MATCH_QUERY,
            (institution_id, source_system, rule_code, version_no),
        ).fetchall()

    events, duplicate_result_event_ids = group_event_rows(event_rows)
    recorded_by_event = defaultdict(list)
    for row in match_rows:
        recorded_by_event[row["transaction_master_id"]].append(dict(row))
    evaluated = []
    multiplier = context["multiplier"]
    for event in events:
        result_available = bool(event.get("result_ids"))
        recorded_rows = recorded_by_event.get(event["transaction_master_id"], [])
        recorded_match = bool(recorded_rows) if result_available else None
        result = evaluate_event(
            event, history_rows, multiplier, 30, recorded_match, recorded_rows
        )
        result["result_decisions"] = event.get("result_decisions", [])
        result["result_scores"] = event.get("result_scores", [])
        evaluated.append(result)
    summary = summarize_events(evaluated)
    return {
        "source": "LOCAL_DATABASE",
        "status": summary["status"],
        "requested_rule_code": rule_code,
        "requested_version_no": version_no,
        "scope": {
            "institution_id": institution_id,
            "source_system": source_system,
        },
        "rule": context["rule"],
        "metric": context["metric"],
        "multiplier": context["multiplier_info"],
        "summary": summary,
        "checks": {
            "stored_metric_sql_execution": "NOT_RUN",
            "replay_query": "ALLOWLISTED_IN_MEMORY_FILTER_PLUS_PARAMETERIZED_SCOPE_READ",
            "history_row_limit": MAX_HISTORY_ROWS,
            "duplicate_result_event_ids": duplicate_result_event_ids,
        },
        "events": evaluated,
    }


def compact_report(full):
    if full.get("status") != "BASELINE_REPLAY_COMPLETE":
        return full
    report = {key: full[key] for key in (
        "source", "status", "requested_rule_code", "requested_version_no",
        "scope", "rule", "metric", "multiplier", "summary", "checks",
    )}
    sample = []
    for event in full.get("events", [])[:10]:
        item = dict(event)
        for key in ("customer_id", "recorded_match_rows", "history_debit_ids"):
            item.pop(key, None)
        sample.append(item)
    report["sample_events"] = sample
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rule-code", required=True)
    parser.add_argument("--version", type=int, default=1)
    parser.add_argument("--institution", default="KANJI")
    parser.add_argument("--source-system", default="CARD_TRANSACTION")
    parser.add_argument("--summary", action="store_true", help="Print summary and ten sample events")
    parser.add_argument("--output", type=Path, help="Also save the full JSON report to this path")
    args = parser.parse_args()
    full = run_baseline(args.rule_code, args.version, args.institution, args.source_system)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(full, default=str, indent=2) + "\n", encoding="utf-8")
        print(f"Full baseline report saved: {args.output}")
    report = compact_report(full) if args.summary else full
    print(json.dumps(report, default=str, indent=2))
    return 0 if full.get("status") == "BASELINE_REPLAY_COMPLETE" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except psycopg.Error as exc:
        print(f"Database read failed ({type(exc).__name__}). Check that the lab is running.", file=sys.stderr)
        raise SystemExit(1)
    except (OSError, ValueError) as exc:
        print(f"Baseline replay setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
