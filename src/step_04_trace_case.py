"""Lesson 2: trace one case's transaction alerts to recorded rule matches.

The trace is diagnostic evidence. It never starts a job, changes EFRM, or
decides that a rule caused an alert. All reads use the local lab connection.
"""

import argparse
from collections import Counter
import json
import sys

import psycopg
from psycopg.rows import dict_row

from local_postgres import CONFIG, PASSWORD_FILE


CASE_QUERY = """
SELECT case_id, institution_id, status, decision_code, approval_status,
       decision_submitted_at
FROM efrm.case_master
WHERE institution_id = %s AND case_id = %s
"""

# The source-table predicate is intentional. case_alert_mapping is polymorphic:
# alert_id=40 means a transaction alert only when its source says so.
TRACE_QUERY = """
SELECT
    m.id AS mapping_id,
    m.alert_id AS mapped_alert_id,
    m.alert_type,
    m.alert_source_table,
    m.decision_code AS alert_decision_code,
    m.status AS mapping_status,
    a.id AS transaction_alert_id,
    a.transaction_result_id,
    r.id AS transaction_result_id,
    r.final_decision AS transaction_final_decision,
    r.matched_rule_count,
    r.raw_score,
    r.overall_score,
    r.execution_time_ms,
    r.is_alert_generated,
    r.is_case_generated,
    t.id AS transaction_master_id,
    t.institution_id AS transaction_institution_id,
    t.source_system,
    t.channel,
    t.txn_type,
    t.txn_sub_type,
    t.txn_timestamp,
    t.txn_amount,
    t.txn_currency,
    x.id AS match_id,
    x.rule_code,
    x.signal_code,
    x.signal_severity,
    x.severity_rank,
    x.signal_weight,
    x.rule_version AS recorded_rule_version,
    x.rule_group_version AS recorded_group_version,
    rm.id AS rule_master_id,
    rm.name AS rule_name,
    rm.rule_type,
    rm.fact,
    rm.description AS rule_description,
    version_refs.version_candidates,
    version_refs.recorded_version_matches,
    group_refs.group_mapping_candidates
FROM efrm.case_alert_mapping AS m
LEFT JOIN efrm.transaction_alert AS a
    ON a.id = m.alert_id
LEFT JOIN efrm.transaction_result AS r
    ON r.id = a.transaction_result_id
LEFT JOIN efrm.transaction_master AS t
    ON t.id = r.transaction_master_id
LEFT JOIN efrm.transaction_match AS x
    ON x.transaction_result_id = r.id
   AND t.institution_id = %s
LEFT JOIN efrm.rule_master AS rm
    ON rm.rule_code = x.rule_code
LEFT JOIN LATERAL (
    SELECT
        COALESCE(jsonb_agg(
            jsonb_build_object('id', rv.id, 'version_no', rv.version_no,
                               'status', rv.status)
            ORDER BY rv.version_no, rv.id
        ), '[]'::jsonb) AS version_candidates,
        COALESCE(jsonb_agg(
            jsonb_build_object('id', rv.id, 'version_no', rv.version_no,
                               'status', rv.status)
            ORDER BY rv.version_no, rv.id
        ) FILTER (WHERE rv.version_no = x.rule_version), '[]'::jsonb)
        AS recorded_version_matches
    FROM efrm.rule_version AS rv
    WHERE rv.rule_master_id = rm.id
) AS version_refs ON TRUE
LEFT JOIN LATERAL (
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'map_id', rgvm.id,
            'rule_version_id', rgvm.rule_version_id,
            'execution_order', rgvm.execution_order
        ) ORDER BY rgvm.execution_order, rgvm.id
    ), '[]'::jsonb) AS group_mapping_candidates
    FROM efrm.rule_group_version_map AS rgvm
    WHERE rgvm.rule_group_version_id = x.rule_group_version
      AND rgvm.rule_version_id IN (
          SELECT rv2.id
          FROM efrm.rule_version AS rv2
          WHERE rv2.rule_master_id = rm.id
            AND rv2.version_no = x.rule_version
      )
) AS group_refs ON TRUE
WHERE m.case_id = %s
  AND m.alert_type = 'TRANSACTION'
  AND m.alert_source_table = 'transaction_alert'
ORDER BY m.id, x.id
"""


def resolve_rule_reference(row):
    """Classify catalog/version/group evidence without guessing a reference."""
    if not row.get("rule_code"):
        return "NO_RULE_MATCH_ROW"
    if not row.get("rule_master_id"):
        return "RULE_CODE_NOT_IN_RULE_MASTER"
    versions = row.get("recorded_version_matches") or []
    group_maps = row.get("group_mapping_candidates") or []
    if not versions:
        return "RECORDED_RULE_VERSION_NOT_FOUND"
    if len(versions) > 1:
        return "RECORDED_RULE_VERSION_AMBIGUOUS"
    if len(group_maps) != 1:
        return "RULE_GROUP_MAPPING_UNRESOLVED"
    return "RULE_REFERENCE_RESOLVED_FOR_TRACE"


def trace_case(institution_id, case_id):
    password = PASSWORD_FILE.read_text(encoding="utf-8").strip()
    with psycopg.connect(
        **CONFIG, password=password, connect_timeout=5, row_factory=dict_row,
        options="-c default_transaction_read_only=on -c statement_timeout=30000",
    ) as conn:
        case = conn.execute(CASE_QUERY, (institution_id, case_id)).fetchone()
        if case is None:
            return {
                "source": "LOCAL_DATABASE",
                "requested_institution": institution_id,
                "requested_case_id": case_id,
                "case": None,
                "transaction_alerts": [],
                "summary": {"status": "CASE_NOT_FOUND_IN_INSTITUTION"},
            }
        rows = conn.execute(TRACE_QUERY, (institution_id, case_id)).fetchall()

    alerts = {}
    matches = []
    for row in rows:
        alert_key = (row["mapping_id"], row["mapped_alert_id"])
        alert = alerts.setdefault(alert_key, {
            "mapping_id": row["mapping_id"],
            "alert_id": row["mapped_alert_id"],
            "alert_type": row["alert_type"],
            "alert_source_table": row["alert_source_table"],
            "alert_decision_code": row["alert_decision_code"],
            "mapping_status": row["mapping_status"],
            "transaction_alert_id": row["transaction_alert_id"],
            "transaction_result_id": row["transaction_result_id"],
            "transaction_result": {
                "final_decision": row["transaction_final_decision"],
                "matched_rule_count": row["matched_rule_count"],
                "raw_score": row["raw_score"],
                "overall_score": row["overall_score"],
                "execution_time_ms": row["execution_time_ms"],
                "is_alert_generated": row["is_alert_generated"],
                "is_case_generated": row["is_case_generated"],
            },
            "transaction": {
                "master_id": row["transaction_master_id"],
                "institution_id": row["transaction_institution_id"],
                "source_system": row["source_system"],
                "channel": row["channel"],
                "txn_type": row["txn_type"],
                "txn_sub_type": row["txn_sub_type"],
                "txn_timestamp": row["txn_timestamp"],
                "txn_amount": row["txn_amount"],
                "txn_currency": row["txn_currency"],
            },
            "rule_matches": [],
        })
        if row["match_id"] is None:
            continue
        match = {
            "match_id": row["match_id"],
            "rule_code": row["rule_code"],
            "signal_code": row["signal_code"],
            "signal_severity": row["signal_severity"],
            "severity_rank": row["severity_rank"],
            "signal_weight": row["signal_weight"],
            "recorded_rule_version": row["recorded_rule_version"],
            "recorded_group_version": row["recorded_group_version"],
            "rule_master_id": row["rule_master_id"],
            "rule_name": row["rule_name"],
            "rule_type": row["rule_type"],
            "fact": row["fact"],
            "rule_description": row["rule_description"],
            "version_candidates": row["version_candidates"] or [],
            "recorded_version_matches": row["recorded_version_matches"] or [],
            "group_mapping_candidates": row["group_mapping_candidates"] or [],
        }
        match["resolution_status"] = resolve_rule_reference(row)
        alert["rule_matches"].append(match)
        matches.append(match)

    resolution_counts = Counter(match["resolution_status"] for match in matches)
    transaction_ids = {
        alert["transaction"]["master_id"]
        for alert in alerts.values() if alert["transaction"]["master_id"] is not None
    }
    scope_issues = [
        alert["transaction"]["master_id"]
        for alert in alerts.values()
        if alert["transaction"]["master_id"] is not None
        and alert["transaction"]["institution_id"] != institution_id
    ]
    summary = {
        "status": "TRACE_COMPLETE",
        "transaction_alert_count": len(alerts),
        "transaction_result_count": len({
            alert["transaction_result_id"] for alert in alerts.values()
            if alert["transaction_result_id"] is not None
        }),
        "transaction_master_count": len(transaction_ids),
        "rule_match_count": len(matches),
        "resolution_counts": dict(resolution_counts),
        "institution_scope_issues": scope_issues,
        "next_step": (
            "READ_RESOLVED_RULE_LOGIC"
            if matches and not scope_issues and all(
                match["resolution_status"] == "RULE_REFERENCE_RESOLVED_FOR_TRACE"
                for match in matches
            ) else "INSPECT_LINEAGE_ISSUES"
        ),
    }
    return {
        "source": "LOCAL_DATABASE",
        "requested_institution": institution_id,
        "requested_case_id": case_id,
        "case": case,
        "transaction_alerts": list(alerts.values()),
        "summary": summary,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--institution", default="KANJI")
    parser.add_argument("--case-id", type=int, required=True)
    parser.add_argument("--summary", action="store_true", help="Print only the trace summary")
    args = parser.parse_args()
    report = trace_case(args.institution, args.case_id)
    output = report["summary"] if args.summary else report
    print(json.dumps(output, default=str, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except psycopg.Error as exc:
        print(f"Database read failed ({type(exc).__name__}). Check that the lab is running.", file=sys.stderr)
        raise SystemExit(1)
    except OSError as exc:
        print(f"Local setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
