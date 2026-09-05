"""Lesson 7: inspect the runtime-selection evidence for remaining mismatches.

The baseline and semantics experiments tell us which events still disagree,
but the dump does not contain Drools' in-memory metric map or selected group
trace. This lesson reads the persisted transaction, request, result, match,
alert, and group-catalog rows for the two non-empty-history mismatches. It
reports evidence and uncertainty; it never executes stored metric SQL or writes
to PostgreSQL.
"""

import argparse
from collections import Counter
import json
from pathlib import Path
import sys

import psycopg
from psycopg.rows import dict_row

from local_postgres import CONFIG, PASSWORD_FILE


TRANSACTION_QUERY = """
SELECT tm.id AS transaction_master_id,
       tm.transaction_request_id,
       tm.transaction_id,
       tm.source_txn_id,
       tm.institution_id,
       tm.source_system,
       tm.channel,
       tm.txn_type,
       tm.txn_sub_type,
       tm.customer_id,
       tm.account_id,
       tm.card_id,
       tm.txn_amount,
       tm.txn_currency,
       tm.txn_timestamp,
       tm.rule_engine_context,
       r.id AS transaction_result_id,
       r.final_decision,
       r.highest_severity,
       r.highest_severity_rank,
       r.matched_rule_count,
       r.overall_score,
       r.is_alert_generated,
       r.is_case_generated
FROM efrm.transaction_master AS tm
LEFT JOIN efrm.transaction_result AS r
  ON r.transaction_master_id = tm.id
WHERE tm.institution_id = %s
  AND tm.source_system = %s
  AND tm.id = ANY(%s)
ORDER BY tm.id, r.id
"""


REQUEST_QUERY = """
SELECT tm.id AS transaction_master_id,
       q.id AS transaction_request_row_id,
       q.request_id,
       q.channel,
       q.api_name,
       q.fact,
       q.is_test,
       q.request_payload,
       q.response_payload,
       q.http_status,
       q.processing_time_ms
FROM efrm.transaction_master AS tm
LEFT JOIN efrm.transaction_request AS q
  ON q.id = tm.transaction_request_id
WHERE tm.institution_id = %s
  AND tm.source_system = %s
  AND tm.id = ANY(%s)
ORDER BY tm.id, q.id
"""


MATCH_QUERY = """
SELECT r.transaction_master_id,
       r.id AS transaction_result_id,
       x.id AS transaction_match_id,
       x.rule_group_version,
       x.rule_code,
       x.rule_version,
       x.signal_code,
       x.signal_severity,
       x.severity_rank,
       x.signal_weight
FROM efrm.transaction_result AS r
LEFT JOIN efrm.transaction_match AS x
  ON x.transaction_result_id = r.id
WHERE r.transaction_master_id = ANY(%s)
ORDER BY r.transaction_master_id, r.id, x.id
"""


ALERT_QUERY = """
SELECT r.transaction_master_id,
       a.id AS transaction_alert_id,
       a.alert_code,
       a.alert_category,
       a.alert_severity,
       a.decision,
       a.status,
       a.severity_rank,
       a.user_action
FROM efrm.transaction_result AS r
LEFT JOIN efrm.transaction_alert AS a
  ON a.transaction_result_id = r.id
WHERE r.transaction_master_id = ANY(%s)
ORDER BY r.transaction_master_id, r.id, a.id
"""


GROUP_QUERY = """
SELECT rgvm.rule_group_version_id,
       rgvm.rule_version_id,
       rgvm.execution_order,
       rgvm.is_mandatory,
       rgv.rule_group_master_id,
       rgv.version_no AS group_version_no,
       rgv.status AS group_status,
       rgm.group_code,
       rgm.group_name,
       rgm.group_type,
       rgm.execution_mode
FROM efrm.rule_group_version_map AS rgvm
JOIN efrm.rule_group_version AS rgv
  ON rgv.id = rgvm.rule_group_version_id
JOIN efrm.rule_group_master AS rgm
  ON rgm.id = rgv.rule_group_master_id
WHERE rgvm.rule_version_id = %s
ORDER BY rgvm.execution_order, rgvm.rule_group_version_id
"""


BINDING_QUERY = """
SELECT b.id AS binding_id,
       b.channel,
       b.rule_group_version_id,
       b.policy_code,
       b.priority,
       b.status AS binding_status,
       rgv.status AS group_status,
       rgm.group_code,
       rgm.group_name,
       rgv.version_no AS group_version_no
FROM efrm.rule_group_source_binding AS b
JOIN efrm.rule_group_version AS rgv
  ON rgv.id = b.rule_group_version_id
JOIN efrm.rule_group_master AS rgm
  ON rgm.id = rgv.rule_group_master_id
WHERE b.institution_id = %s
  AND b.source_system = %s
  AND b.channel = ANY(%s)
ORDER BY b.channel, b.priority, b.id
"""


METRIC_QUERY = """
SELECT id, metric_code, metric_name, entity_type, channel, window_type,
       window_size, data_type, aggregation_type, context_code, is_active,
       sql_statement
FROM efrm.metric_definition
WHERE metric_code = %s
ORDER BY id
"""


def parse_json(value):
    """Return a JSON object when a driver returns text or JSONB."""
    if value is None:
        return None
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, str):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return {"_unparsed_text": True}
    return {"_unexpected_type": type(value).__name__}


def context_shape(value):
    """Summarize context keys without copying the potentially large payload."""
    context = parse_json(value)
    if not isinstance(context, dict):
        return {
            "present": context is not None,
            "top_level_keys": [],
            "transaction_keys": [],
            "metric_keys": [],
            "metric_key_present": False,
        }
    transaction = context.get("transaction")
    metrics = context.get("metrics")
    return {
        "present": True,
        "top_level_keys": sorted(str(key) for key in context),
        "transaction_keys": sorted(str(key) for key in transaction) if isinstance(transaction, dict) else [],
        "metric_keys": sorted(str(key) for key in metrics) if isinstance(metrics, dict) else [],
        "metric_key_present": "metrics" in context,
        "metric_value_is_object": isinstance(metrics, dict),
        "context_drcr_amount": transaction.get("drCrAmount") if isinstance(transaction, dict) else None,
        "context_drcr_indicator": transaction.get("drCrIndicator") if isinstance(transaction, dict) else None,
    }


def compact_request(row):
    """Keep request evidence to shape and routing fields, not full payloads."""
    if not row:
        return None
    request = parse_json(row.get("request_payload"))
    response = parse_json(row.get("response_payload"))
    return {
        "transaction_request_row_id": row.get("transaction_request_row_id"),
        "request_id": row.get("request_id"),
        "channel": row.get("channel"),
        "api_name": row.get("api_name"),
        "fact": row.get("fact"),
        "is_test": row.get("is_test"),
        "http_status": row.get("http_status"),
        "processing_time_ms": row.get("processing_time_ms"),
        "request_payload_shape": sorted(request) if isinstance(request, dict) else type(request).__name__,
        "response_payload_shape": sorted(response) if isinstance(response, dict) else type(response).__name__,
    }


def group_rows(rows):
    grouped = {}
    for row in rows:
        grouped.setdefault(row["transaction_master_id"], []).append(dict(row))
    return grouped


def inspect_runtime_selection(baseline_path, institution_id, source_system, event_ids):
    """Read persisted evidence for selected baseline mismatch IDs."""
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
    baseline_by_id = {
        event.get("transaction_master_id"): event
        for event in baseline.get("events", [])
        if event.get("transaction_master_id") in event_ids
    }
    missing_baseline_ids = [event_id for event_id in event_ids if event_id not in baseline_by_id]
    rule = baseline.get("rule") or {}
    metric_code = (baseline.get("metric") or {}).get("code", "AVG_DEBIT_30DAY")
    rule_version_id = rule.get("rule_version_id")
    if rule_version_id is None:
        return {"source": "LOCAL_FILE", "status": "RULE_VERSION_ID_MISSING"}

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
        transaction_rows = [dict(row) for row in conn.execute(
            TRANSACTION_QUERY, (institution_id, source_system, event_ids)
        ).fetchall()]
        request_rows = [dict(row) for row in conn.execute(
            REQUEST_QUERY, (institution_id, source_system, event_ids)
        ).fetchall()]
        match_rows = [dict(row) for row in conn.execute(MATCH_QUERY, (event_ids,)).fetchall()]
        alert_rows = [dict(row) for row in conn.execute(ALERT_QUERY, (event_ids,)).fetchall()]
        group_catalog = [dict(row) for row in conn.execute(GROUP_QUERY, (rule_version_id,)).fetchall()]
        channels = sorted({row.get("channel") for row in transaction_rows if row.get("channel")})
        binding_rows = [dict(row) for row in conn.execute(
            BINDING_QUERY, (institution_id, source_system, channels)
        ).fetchall()] if channels else []
        metric_rows = [dict(row) for row in conn.execute(
            METRIC_QUERY, (metric_code,)
        ).fetchall()]

    transactions = group_rows(transaction_rows)
    requests = group_rows(request_rows)
    matches = group_rows(match_rows)
    alerts = group_rows(alert_rows)
    bindings_by_channel = {}
    for row in binding_rows:
        bindings_by_channel.setdefault(row["channel"], []).append(row)
    baseline_mismatch = [
        event for event in baseline.get("events", [])
        if event.get("transaction_master_id") in event_ids and event.get("comparison") is False
    ]
    reports = []
    target_rule_code = rule.get("rule_code")
    target_version_no = rule.get("version_no")
    catalog_group_ids = {row["rule_group_version_id"] for row in group_catalog}
    for event_id in event_ids:
        tx_candidates = transactions.get(event_id, [])
        tx = tx_candidates[0] if tx_candidates else {}
        tx_matches = [row for row in matches.get(event_id, []) if row.get("transaction_match_id") is not None]
        target_matches = [
            row for row in tx_matches
            if row.get("rule_code") == target_rule_code and row.get("rule_version") == target_version_no
        ]
        channel = tx.get("channel")
        configured = bindings_by_channel.get(channel, [])
        reports.append({
            "transaction_master_id": event_id,
            "baseline": baseline_by_id.get(event_id),
            "transaction": {
                key: tx.get(key)
                for key in (
                    "transaction_master_id", "transaction_request_id", "transaction_id",
                    "source_txn_id", "institution_id", "source_system", "channel",
                    "txn_type", "txn_sub_type", "customer_id", "account_id", "card_id",
                    "txn_amount", "txn_currency", "txn_timestamp",
                )
            },
            "context": context_shape(tx.get("rule_engine_context")),
            "request": compact_request((requests.get(event_id) or [None])[0]),
            "result_rows": [
                {key: row.get(key) for key in (
                    "transaction_result_id", "final_decision", "highest_severity",
                    "highest_severity_rank", "matched_rule_count", "overall_score",
                    "is_alert_generated", "is_case_generated",
                )}
                for row in tx_candidates if row.get("transaction_result_id") is not None
            ],
            "all_match_rows": tx_matches,
            "target_rule_match_rows": target_matches,
            "alert_rows": [
                {key: row.get(key) for key in (
                    "transaction_alert_id", "alert_code", "alert_category",
                    "alert_severity", "decision", "status", "severity_rank", "user_action",
                )}
                for row in alerts.get(event_id, []) if row.get("transaction_alert_id") is not None
            ],
            "group_evidence": {
                "target_rule_group_version_ids": sorted(catalog_group_ids),
                "observed_group_version_ids_in_matches": sorted({
                    row["rule_group_version"] for row in tx_matches
                    if row.get("rule_group_version") is not None
                }),
                "configured_bindings_for_channel": configured,
                "target_rule_group_binding_exists_for_channel": bool(
                    catalog_group_ids.intersection({row["rule_group_version_id"] for row in configured})
                ),
            },
            "evidence_interpretation": (
                "TARGET_RULE_MATCH_PERSISTED"
                if target_matches else
                "NO_TARGET_RULE_MATCH_PERSISTED;_RUNTIME_METRIC_AND_GROUP_SELECTION_UNKNOWN"
            ),
        })

    return {
        "source": "LOCAL_DATABASE_AND_SAVED_BASELINE",
        "status": "RUNTIME_SELECTION_EVIDENCE_COMPLETE",
        "baseline_file": str(baseline_path),
        "scope": {"institution_id": institution_id, "source_system": source_system},
        "rule": rule,
        "metric_definition_catalog": [
            {key: row.get(key) for key in (
                "id", "metric_code", "metric_name", "entity_type", "channel", "window_type",
                "window_size", "data_type", "aggregation_type", "context_code", "is_active",
                "sql_statement",
            )}
            for row in metric_rows
        ],
        "group_catalog_for_rule": group_catalog,
        "targets": reports,
        "checks": {
            "database": identity["current_database"],
            "database_user": identity["current_user"],
            "transaction_read_only": identity["transaction_read_only"],
            "database_writes": "NONE",
            "stored_metric_sql_execution": "NOT_RUN",
            "full_request_response_payloads": "NOT_COPIED",
            "missing_requested_baseline_ids": missing_baseline_ids,
        },
        "summary": {
            "requested_event_count": len(event_ids),
            "events_found": len(reports),
            "target_rule_match_count": sum(1 for item in reports if item["target_rule_match_rows"]),
            "events_with_metric_context_key": sum(
                1 for item in reports if item["context"]["metric_key_present"]
            ),
            "events_with_observed_group_match": sum(
                1 for item in reports if item["group_evidence"]["observed_group_version_ids_in_matches"]
            ),
            "events_with_configured_target_binding": sum(
                1 for item in reports
                if item["group_evidence"]["target_rule_group_binding_exists_for_channel"]
            ),
            "decision_counts": dict(Counter(
                row.get("final_decision")
                for item in reports
                for row in item["result_rows"]
                if row.get("final_decision") is not None
            )),
            "next_step": "COMPARE_EVENT_123_AND_133_WITH_A_MATCHED_EVENT",
        },
        "evidence_boundary": (
            "Persisted rows show outcomes, matches, request shapes, and catalog bindings. "
            "They do not prove which rule group the engine selected or whether the metric "
            "was absent, null, or calculated only in memory."
        ),
    }


def compact_report(full):
    if full.get("status") != "RUNTIME_SELECTION_EVIDENCE_COMPLETE":
        return full
    report = {key: full[key] for key in (
        "source", "status", "baseline_file", "scope", "rule", "summary", "checks", "evidence_boundary",
    )}
    report["metric_definition_catalog"] = [
        {key: row.get(key) for key in row if key != "sql_statement"}
        for row in full.get("metric_definition_catalog", [])
    ]
    report["group_catalog_for_rule"] = full.get("group_catalog_for_rule", [])
    report["targets"] = []
    for target in full.get("targets", []):
        report["targets"].append({
            "transaction_master_id": target["transaction_master_id"],
            "baseline": {
                key: target.get("baseline", {}).get(key)
                for key in (
                    "channel", "history_debit_count", "history_average_amount", "threshold_amount",
                    "derived_current_amount", "rule_would_fire", "recorded_rule_match", "comparison",
                )
            },
            "transaction": target["transaction"],
            "context": target["context"],
            "request": target["request"],
            "result_rows": target["result_rows"],
            "all_match_rows": target["all_match_rows"],
            "target_rule_match_rows": target["target_rule_match_rows"],
            "alert_rows": target["alert_rows"],
            "group_evidence": {
                key: target["group_evidence"][key]
                for key in (
                    "target_rule_group_version_ids", "observed_group_version_ids_in_matches",
                    "configured_bindings_for_channel", "target_rule_group_binding_exists_for_channel",
                )
            },
            "evidence_interpretation": target["evidence_interpretation"],
        })
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=Path("outputs/baseline_cust_spend_v1.json"))
    parser.add_argument("--institution", default="KANJI")
    parser.add_argument("--source-system", default="CARD_TRANSACTION")
    parser.add_argument("--event-id", type=int, action="append", dest="event_ids",
                        help="Event ID to inspect; may be supplied more than once (default: 123 and 133)")
    parser.add_argument("--summary", action="store_true", help="Omit stored metric SQL text")
    parser.add_argument("--output", type=Path, help="Also save the full evidence JSON")
    args = parser.parse_args()
    event_ids = args.event_ids or [123, 133]
    full = inspect_runtime_selection(args.baseline, args.institution, args.source_system, event_ids)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(full, default=str, indent=2) + "\n", encoding="utf-8")
        print(f"Full runtime-selection report saved: {args.output}")
    report = compact_report(full) if args.summary else full
    print(json.dumps(report, default=str, indent=2))
    return 0 if full.get("status") == "RUNTIME_SELECTION_EVIDENCE_COMPLETE" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except psycopg.Error as exc:
        print(f"Database read failed ({type(exc).__name__}). Check that the lab is running.", file=sys.stderr)
        raise SystemExit(1)
    except (OSError, ValueError) as exc:
        print(f"Runtime-selection inspection setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
