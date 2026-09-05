"""Lesson 4: replay one allow-listed historical metric for one transaction.

This is a learning exercise.  It reads one rule, resolves its multiplier from
``reference_data``, and reconstructs ``AVG_DEBIT_30DAY`` with a parameterized
query written for this lesson.  It deliberately does not execute SQL stored in
``metric_definition.sql_statement`` and it never writes to the database.
"""

import argparse
from collections import Counter
from datetime import timedelta
from decimal import Decimal, InvalidOperation
import json
import sys

import psycopg
from psycopg.rows import dict_row

from local_postgres import CONFIG, PASSWORD_FILE


SUPPORTED_METRIC = "AVG_DEBIT_30DAY"
SUPPORTED_ENTITY = "CUSTOMER"
SUPPORTED_WINDOW = "30DAY"
MULTIPLIER_PREFIX = "$LIMIT_AND_COUNT."
MAX_HISTORY_ROWS = 10000


TARGET_QUERY = """
SELECT id, institution_id, source_system, channel, txn_type, txn_sub_type,
       customer_id, txn_amount, txn_timestamp, source_txn_id,
       rule_engine_context #>> '{transaction,drCrAmount}' AS context_drcr_amount,
       rule_engine_context #>> '{transaction,drCrIndicator}' AS context_drcr_indicator
FROM efrm.transaction_master
WHERE id = %s
  AND institution_id = %s
"""


HISTORY_QUERY = """
SELECT id, source_txn_id, txn_type, txn_timestamp, txn_amount,
       rule_engine_context #>> '{transaction,drCrAmount}' AS context_drcr_amount,
       rule_engine_context #>> '{transaction,drCrIndicator}' AS context_drcr_indicator
FROM efrm.transaction_master
WHERE institution_id = %s
  AND source_system = %s
  AND customer_id = %s
  AND txn_timestamp >= %s
  AND txn_timestamp < %s
  AND COALESCE(source_txn_id, '') <> %s
ORDER BY txn_timestamp, id
LIMIT %s
"""


RULE_QUERY = """
SELECT rm.id AS rule_master_id,
       rm.rule_code,
       rv.id AS rule_version_id,
       rv.version_no,
       rv.status AS rule_status,
       rmd.metric_code,
       rmd.entity_type,
       rmd.metric_role,
       md.id AS metric_definition_id,
       md.metric_name,
       md.window_type,
       md.window_size,
       md.sql_statement
FROM efrm.rule_master AS rm
JOIN efrm.rule_version AS rv
  ON rv.rule_master_id = rm.id
LEFT JOIN efrm.rule_metric_dependency AS rmd
  ON rmd.rule_id = rm.id
LEFT JOIN efrm.metric_definition AS md
  ON md.metric_code = rmd.metric_code
WHERE rm.rule_code = %s
  AND rv.version_no = %s
ORDER BY rmd.id
"""


REQUIRED_DATA_QUERY = """
SELECT variable_type, variable, entity_type
FROM efrm.rule_required_data
WHERE rule_version_id = %s
ORDER BY id
"""


MULTIPLIER_QUERY = """
SELECT ref_id, ref_type, ref_code, ref_value, ref_sub_code,
       ref_description, is_active, rule_drl_context
FROM efrm.reference_data
WHERE ref_type = 'LIMIT_AND_COUNT'
  AND ref_code = %s
ORDER BY ref_id
"""


RECORDED_MATCH_QUERY = """
SELECT x.rule_code, x.rule_version, x.signal_code,
       r.final_decision, r.overall_score
FROM efrm.transaction_result AS r
LEFT JOIN efrm.transaction_match AS x
  ON x.transaction_result_id = r.id
WHERE r.transaction_master_id = %s
ORDER BY x.id
"""


def nonempty_text(value):
    """Return a context string unless it is SQL's empty-string fallback."""
    if value is None:
        return None
    text = str(value)
    return text if text != "" else None


def derive_indicator(context_indicator, txn_type):
    """Mirror the stored SQL's indicator precedence and fallback values."""
    context_value = nonempty_text(context_indicator)
    if context_value is not None:
        return context_value
    fallback = {
        "WITHDRAWAL", "PURCHASE", "CASH", "DEBIT", "P2P", "P2M", "TRANSFER",
    }
    credit = {"REFUND", "REVERSAL", "CREDIT", "DEPOSIT"}
    normalized = str(txn_type or "").upper()
    if normalized in fallback:
        return "D"
    if normalized in credit:
        return "C"
    return None


def derive_amount(context_amount, fallback_amount):
    """Use drCrAmount when present, otherwise the table's txn_amount."""
    raw = nonempty_text(context_amount)
    if raw is None:
        raw = fallback_amount
    if raw is None:
        return None
    try:
        return Decimal(str(raw))
    except (InvalidOperation, ValueError):
        return None


def calculate_average(rows):
    """Average valid debit amounts, with the metric's COALESCE(..., 0) rule."""
    included = []
    invalid_amount_rows = []
    for row in rows:
        indicator = derive_indicator(row.get("context_drcr_indicator"), row.get("txn_type"))
        amount = derive_amount(row.get("context_drcr_amount"), row.get("txn_amount"))
        if indicator != "D":
            continue
        if amount is None:
            invalid_amount_rows.append(row.get("id"))
            continue
        included.append({
            "id": row.get("id"),
            "source_txn_id": row.get("source_txn_id"),
            "txn_type": row.get("txn_type"),
            "txn_timestamp": row.get("txn_timestamp"),
            "amount": amount,
            "indicator": indicator,
        })
    total = sum((item["amount"] for item in included), Decimal("0"))
    average = total / Decimal(len(included)) if included else Decimal("0")
    return {
        "included": included,
        "invalid_amount_rows": invalid_amount_rows,
        "candidate_row_count": len(rows),
        "debit_count": len(included),
        "sum_amount": total,
        "average_amount": average,
    }


def extract_multiplier_reference(required_data):
    """Find exactly one LIMIT_AND_COUNT reference declared by the rule version."""
    references = [
        item["variable"][len(MULTIPLIER_PREFIX):]
        for item in required_data
        if item.get("variable_type") in {"LIST", "MAP"}
        and isinstance(item.get("variable"), str)
        and item["variable"].startswith(MULTIPLIER_PREFIX)
    ]
    if len(references) != 1:
        return None, {
            "status": "MULTIPLIER_REFERENCE_AMBIGUOUS"
            if len(references) > 1 else "MULTIPLIER_REFERENCE_MISSING",
            "references": references,
        }
    return references[0], None


def resolve_multiplier(rows):
    """Require one active reference row and parse its numeric value exactly."""
    active = [row for row in rows if row.get("is_active") == "Y"]
    if len(active) != 1:
        return None, {
            "status": "MULTIPLIER_CONFIGURATION_AMBIGUOUS"
            if len(active) > 1 else "MULTIPLIER_CONFIGURATION_MISSING",
            "active_row_count": len(active),
            "candidate_row_count": len(rows),
        }
    try:
        value = Decimal(str(active[0]["ref_value"]))
    except (InvalidOperation, ValueError, TypeError):
        return None, {
            "status": "MULTIPLIER_CONFIGURATION_NOT_NUMERIC",
            "ref_id": active[0].get("ref_id"),
        }
    return value, {
        "status": "MULTIPLIER_RESOLVED",
        "ref_id": active[0].get("ref_id"),
        "ref_code": active[0].get("ref_code"),
        "ref_sub_code": active[0].get("ref_sub_code"),
        "ref_value": str(value),
    }


def _serialize_metric(metric):
    """Convert Decimal values while keeping the full report JSON-friendly."""
    result = dict(metric)
    for key in ("sum_amount", "average_amount"):
        if key in result and isinstance(result[key], Decimal):
            result[key] = str(result[key])
    for item in result.get("included", []):
        if isinstance(item.get("amount"), Decimal):
            item["amount"] = str(item["amount"])
    return result


def replay_metric(rule_code, version_no, transaction_master_id, institution_id):
    password = PASSWORD_FILE.read_text(encoding="utf-8").strip()
    with psycopg.connect(
        **CONFIG, password=password, connect_timeout=5, row_factory=dict_row,
        options="-c default_transaction_read_only=on -c statement_timeout=30000",
    ) as conn:
        rule_rows = conn.execute(RULE_QUERY, (rule_code, version_no)).fetchall()
        if not rule_rows:
            return {
                "source": "LOCAL_DATABASE",
                "status": "RULE_VERSION_NOT_FOUND",
                "requested_rule_code": rule_code,
                "requested_version_no": version_no,
            }
        rule_version_id = rule_rows[0]["rule_version_id"]
        required_data = conn.execute(REQUIRED_DATA_QUERY, (rule_version_id,)).fetchall()
        target = conn.execute(TARGET_QUERY, (transaction_master_id, institution_id)).fetchone()
        if target is None:
            return {
                "source": "LOCAL_DATABASE",
                "status": "TRANSACTION_NOT_FOUND_IN_INSTITUTION",
                "requested_rule_code": rule_code,
                "requested_version_no": version_no,
                "requested_transaction_master_id": transaction_master_id,
                "requested_institution": institution_id,
            }

        dependency_rows = [dict(row) for row in rule_rows if row["metric_code"]]
        if len(dependency_rows) != 1:
            return {
                "source": "LOCAL_DATABASE",
                "status": "UNSUPPORTED_METRIC_DEPENDENCIES",
                "requested_rule_code": rule_code,
                "requested_version_no": version_no,
                "dependency_count": len(dependency_rows),
            }
        dependency = dependency_rows[0]
        if (dependency["metric_code"], dependency["entity_type"], dependency["window_size"]) != (
            SUPPORTED_METRIC, SUPPORTED_ENTITY, SUPPORTED_WINDOW
        ):
            return {
                "source": "LOCAL_DATABASE",
                "status": "METRIC_NOT_SUPPORTED_BY_THIS_LESSON",
                "requested_rule_code": rule_code,
                "requested_version_no": version_no,
                "dependency": dependency,
            }

        multiplier_ref, reference_error = extract_multiplier_reference(required_data)
        if reference_error:
            return {
                "source": "LOCAL_DATABASE",
                "status": reference_error["status"],
                "requested_rule_code": rule_code,
                "requested_version_no": version_no,
                "required_data": [dict(item) for item in required_data],
                "details": reference_error,
            }
        multiplier_rows = conn.execute(MULTIPLIER_QUERY, (multiplier_ref,)).fetchall()
        multiplier, multiplier_info = resolve_multiplier(multiplier_rows)
        if multiplier is None:
            return {
                "source": "LOCAL_DATABASE",
                "status": multiplier_info["status"],
                "requested_rule_code": rule_code,
                "requested_version_no": version_no,
                "multiplier_reference": multiplier_ref,
                "details": multiplier_info,
            }

        window_days = int(str(dependency["window_size"]).upper().removesuffix("DAY"))
        start_at = target["txn_timestamp"] - timedelta(days=window_days)
        history_rows = conn.execute(
            HISTORY_QUERY,
            (
                target["institution_id"], target["source_system"], target["customer_id"],
                start_at, target["txn_timestamp"], target["source_txn_id"], MAX_HISTORY_ROWS,
            ),
        ).fetchall()
        recorded_rows = conn.execute(
            RECORDED_MATCH_QUERY, (transaction_master_id,)
        ).fetchall()

    metric = calculate_average([dict(row) for row in history_rows])
    current_indicator = derive_indicator(
        target["context_drcr_indicator"], target["txn_type"]
    )
    current_amount = derive_amount(target["context_drcr_amount"], target["txn_amount"])
    threshold = metric["average_amount"] * multiplier
    would_fire = (
        current_indicator == "D"
        and current_amount is not None
        and current_amount >= threshold
    )
    if current_indicator != "D":
        decision_reason = "CURRENT_TRANSACTION_IS_NOT_DEBIT"
    elif current_amount is None:
        decision_reason = "CURRENT_AMOUNT_IS_MISSING_OR_NOT_NUMERIC"
    elif current_amount >= threshold:
        decision_reason = "CURRENT_AMOUNT_MEETS_AVERAGE_TIMES_MULTIPLIER"
    else:
        decision_reason = "CURRENT_AMOUNT_BELOW_AVERAGE_TIMES_MULTIPLIER"

    recorded_rule_rows = [
        dict(row) for row in recorded_rows
        if row.get("rule_code") == rule_code and row.get("rule_version") == version_no
    ]
    recorded_rule_match = bool(recorded_rule_rows)
    report = {
        "source": "LOCAL_DATABASE",
        "status": "METRIC_REPLAY_COMPLETE",
        "requested_rule_code": rule_code,
        "requested_version_no": version_no,
        "requested_transaction_master_id": transaction_master_id,
        "rule": {
            "rule_master_id": dependency["rule_master_id"],
            "rule_version_id": dependency["rule_version_id"],
            "rule_code": dependency["rule_code"],
            "version_no": dependency["version_no"],
            "rule_status": dependency["rule_status"],
            "metric_sql_stored": bool(dependency["sql_statement"]),
        },
        "target": {
            "transaction_master_id": target["id"],
            "institution_id": target["institution_id"],
            "source_system": target["source_system"],
            "channel": target["channel"],
            "txn_type": target["txn_type"],
            "txn_sub_type": target["txn_sub_type"],
            "customer_id": target["customer_id"],
            "txn_timestamp": target["txn_timestamp"],
            "source_txn_id": target["source_txn_id"],
            "stored_txn_amount": target["txn_amount"],
            "derived_current_amount": current_amount,
            "derived_current_indicator": current_indicator,
        },
        "metric": {
            "code": dependency["metric_code"],
            "entity_type": dependency["entity_type"],
            "window_type": dependency["window_type"],
            "window_size": dependency["window_size"],
            "window_start_inclusive": start_at,
            "window_end_exclusive": target["txn_timestamp"],
            **_serialize_metric(metric),
        },
        "multiplier": multiplier_info,
        "evaluation": {
            "threshold_amount": threshold,
            "rule_would_fire": would_fire,
            "reason": decision_reason,
        },
        "recorded": {
            "transaction_result_decision": recorded_rows[0]["final_decision"] if recorded_rows else None,
            "recorded_rule_match": recorded_rule_match,
            "recorded_rule_match_count": len(recorded_rule_rows),
            "recorded_rule_rows": recorded_rule_rows,
            "replay_matches_recorded_rule_match": would_fire == recorded_rule_match,
        },
        "checks": {
            "stored_metric_sql_execution": "NOT_RUN",
            "replay_query": "ALLOWLISTED_PARAMETERIZED_AVG_DEBIT_30DAY",
            "history_row_limit": MAX_HISTORY_ROWS,
            "invalid_history_amount_rows": metric["invalid_amount_rows"],
        },
        "next_step": "REPLAY_MORE_EVENTS",
    }
    return report


def compact_report(full):
    """Remove row-level history while preserving the calculation evidence."""
    if full.get("status") != "METRIC_REPLAY_COMPLETE":
        return full
    report = dict(full)
    report["target"] = dict(full["target"])
    report["target"].pop("customer_id", None)
    report["target"].pop("source_txn_id", None)
    report["metric"] = dict(full["metric"])
    report["metric"].pop("included", None)
    report["recorded"] = dict(full["recorded"])
    report["recorded"].pop("recorded_rule_rows", None)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rule-code", required=True)
    parser.add_argument("--version", type=int, default=1)
    parser.add_argument("--transaction-master-id", type=int, required=True)
    parser.add_argument("--institution", default="KANJI")
    parser.add_argument("--summary", action="store_true", help="Omit customer/source IDs and row-level history")
    args = parser.parse_args()
    report = replay_metric(
        args.rule_code, args.version, args.transaction_master_id, args.institution
    )
    if args.summary:
        report = compact_report(report)
    print(json.dumps(report, default=str, indent=2))
    return 0 if report.get("status") == "METRIC_REPLAY_COMPLETE" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except psycopg.Error as exc:
        print(f"Database read failed ({type(exc).__name__}). Check that the lab is running.", file=sys.stderr)
        raise SystemExit(1)
    except (OSError, ValueError) as exc:
        print(f"Metric replay setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
