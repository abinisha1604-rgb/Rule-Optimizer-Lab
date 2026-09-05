"""Lesson 6: explain baseline mismatches before changing replay semantics.

The baseline intentionally used the stored metric SQL's zero fallback. This
lesson classifies disagreements and checks catalog evidence for rule-group
bindings and persisted metric context. It does not decide which explanation is
true when the runtime evidence is absent.
"""

import argparse
from collections import Counter
import json
from pathlib import Path
import sys

import psycopg
from psycopg.rows import dict_row

from local_postgres import CONFIG, PASSWORD_FILE


GROUP_QUERY = """
SELECT rgvm.rule_group_version_id,
       rgvm.rule_version_id,
       rgm.group_code,
       rgm.group_name,
       rgv.status AS group_status
FROM efrm.rule_group_version_map AS rgvm
JOIN efrm.rule_group_version AS rgv
  ON rgv.id = rgvm.rule_group_version_id
JOIN efrm.rule_group_master AS rgm
  ON rgm.id = rgv.rule_group_master_id
WHERE rgvm.rule_version_id = %s
ORDER BY rgvm.rule_group_version_id
"""


BINDING_QUERY = """
SELECT b.channel,
       b.rule_group_version_id,
       b.priority,
       b.status AS binding_status,
       rgv.status AS group_status,
       rgm.group_code,
       rgm.group_name
FROM efrm.rule_group_source_binding AS b
JOIN efrm.rule_group_version AS rgv
  ON rgv.id = b.rule_group_version_id
JOIN efrm.rule_group_master AS rgm
  ON rgm.id = rgv.rule_group_master_id
WHERE b.institution_id = %s
  AND b.source_system = %s
  AND b.status = 'ACTIVE'
  AND rgv.status = 'ACTIVE'
ORDER BY b.channel, b.priority, b.id
"""


CONTEXT_QUERY = """
SELECT id,
       channel,
       rule_engine_context ? 'metrics' AS metric_key_present,
       rule_engine_context #>> '{transaction,drCrIndicator}' AS context_drcr_indicator,
       rule_engine_context #>> '{transaction,drCrAmount}' AS context_drcr_amount
FROM efrm.transaction_master
WHERE institution_id = %s
  AND source_system = %s
  AND id = ANY(%s)
ORDER BY id
"""


def classify_mismatch(event):
    """Give a narrow data explanation without claiming runtime causality."""
    if event.get("comparison") is not False:
        return None
    if event.get("history_debit_count") == 0 and event.get("history_average_amount") in ("0", 0, 0.0):
        return "EMPTY_HISTORY_ZERO_FALLBACK"
    if event.get("history_debit_count", 0) > 0:
        return "NONEMPTY_HISTORY_UNRECORDED"
    return "OTHER_REPLAY_MISMATCH"


def binding_evidence(groups, bindings_by_channel, channel):
    """Return configured group IDs for a channel and whether the rule group is among them."""
    configured = bindings_by_channel.get(channel, [])
    group_ids = {group["rule_group_version_id"] for group in groups}
    bound_ids = [row["rule_group_version_id"] for row in configured]
    return {
        "configured_binding_count": len(configured),
        "configured_group_version_ids": bound_ids,
        "rule_group_version_ids_for_rule": sorted(group_ids),
        "rule_group_binding_exists_for_channel": bool(group_ids.intersection(bound_ids)),
    }


def diagnose(baseline_path, institution_id, source_system):
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
    mismatch_events = [event for event in events if event.get("comparison") is False]
    rule_version_id = (baseline.get("rule") or {}).get("rule_version_id")
    if rule_version_id is None:
        return {"source": "LOCAL_FILE", "status": "RULE_VERSION_ID_MISSING"}
    mismatch_ids = [event.get("transaction_master_id") for event in mismatch_events]

    password = PASSWORD_FILE.read_text(encoding="utf-8").strip()
    with psycopg.connect(
        **CONFIG, password=password, connect_timeout=5, row_factory=dict_row,
        options="-c default_transaction_read_only=on -c statement_timeout=30000",
    ) as conn:
        groups = [dict(row) for row in conn.execute(GROUP_QUERY, (rule_version_id,)).fetchall()]
        bindings = [dict(row) for row in conn.execute(
            BINDING_QUERY, (institution_id, source_system)
        ).fetchall()]
        context_rows = [dict(row) for row in conn.execute(
            CONTEXT_QUERY, (institution_id, source_system, mismatch_ids)
        ).fetchall()] if mismatch_ids else []

    bindings_by_channel = {}
    for row in bindings:
        bindings_by_channel.setdefault(row["channel"], []).append(row)
    context_by_id = {row["id"]: row for row in context_rows}
    diagnosed = []
    for event in mismatch_events:
        event_id = event.get("transaction_master_id")
        context = context_by_id.get(event_id, {})
        item = {
            "transaction_master_id": event_id,
            "timestamp": event.get("timestamp"),
            "channel": event.get("channel"),
            "classification": classify_mismatch(event),
            "history_debit_count": event.get("history_debit_count"),
            "history_average_amount": event.get("history_average_amount"),
            "threshold_amount": event.get("threshold_amount"),
            "derived_current_amount": event.get("derived_current_amount"),
            "rule_would_fire_under_replay": event.get("rule_would_fire"),
            "recorded_rule_match": event.get("recorded_rule_match"),
            "context_metric_key_present": context.get("metric_key_present"),
            "context_drcr_indicator": context.get("context_drcr_indicator"),
            "context_drcr_amount_present": context.get("context_drcr_amount") is not None,
            "binding": binding_evidence(groups, bindings_by_channel, event.get("channel")),
        }
        diagnosed.append(item)

    classification_counts = Counter(item["classification"] for item in diagnosed)
    metric_presence_counts = Counter(str(item["context_metric_key_present"]) for item in diagnosed)
    binding_counts = Counter(str(item["binding"]["rule_group_binding_exists_for_channel"]) for item in diagnosed)
    return {
        "source": "LOCAL_DATABASE_AND_SAVED_BASELINE",
        "status": "BASELINE_DIAGNOSTIC_COMPLETE",
        "baseline_file": str(baseline_path),
        "rule": baseline.get("rule"),
        "scope": {"institution_id": institution_id, "source_system": source_system},
        "summary": {
            "mismatch_count": len(diagnosed),
            "classification_counts": dict(classification_counts),
            "metric_context_presence_counts": dict(metric_presence_counts),
            "rule_group_binding_exists_counts": dict(binding_counts),
            "rule_group_versions_for_rule": groups,
            "next_step": "INSPECT_RUNTIME_METRIC_AND_GROUP_SELECTION",
        },
        "checks": {
            "stored_metric_sql_execution": "NOT_RUN",
            "database_writes": "NONE",
            "note": "Catalog bindings show configured applicability, not which group the runtime selected for a no-match event.",
        },
        "mismatches": diagnosed,
    }


def compact_report(full):
    if full.get("status") != "BASELINE_DIAGNOSTIC_COMPLETE":
        return full
    report = {key: full[key] for key in ("source", "status", "rule", "scope", "summary", "checks")}
    report["mismatches"] = []
    for item in full.get("mismatches", []):
        compact = dict(item)
        compact.pop("context_drcr_indicator", None)
        compact.pop("derived_current_amount", None)
        report["mismatches"].append(compact)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=Path("outputs/baseline_cust_spend_v1.json"))
    parser.add_argument("--institution", default="KANJI")
    parser.add_argument("--source-system", default="CARD_TRANSACTION")
    parser.add_argument("--summary", action="store_true", help="Omit detailed amount/context fields")
    parser.add_argument("--output", type=Path, help="Also save the full diagnostic JSON")
    args = parser.parse_args()
    full = diagnose(args.baseline, args.institution, args.source_system)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(full, default=str, indent=2) + "\n", encoding="utf-8")
        print(f"Full diagnostic report saved: {args.output}")
    report = compact_report(full) if args.summary else full
    print(json.dumps(report, default=str, indent=2))
    return 0 if full.get("status") == "BASELINE_DIAGNOSTIC_COMPLETE" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except psycopg.Error as exc:
        print(f"Database read failed ({type(exc).__name__}). Check that the lab is running.", file=sys.stderr)
        raise SystemExit(1)
    except (OSError, ValueError) as exc:
        print(f"Baseline diagnostic setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
