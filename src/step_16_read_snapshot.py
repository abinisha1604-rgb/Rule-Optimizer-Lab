"""Lesson 12: read a partitioned historical snapshot.

This small reader is the first snapshot-driven ingestion step. It opens the
manifest first, reads the partition ``events.json`` files, validates event
identity, and returns the same flat event shape used by the earlier replay
lessons. It is read-only: no database connection, SQL execution, or file
mutation is performed.
"""

import argparse
import json
from pathlib import Path
import sys


READ_STATUS = "SNAPSHOT_READ_COMPLETE"


def _read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"could not read JSON file {path}: {exc}") from exc


def _flatten_event(row):
    """Convert one normalized snapshot row to the replay event shape."""
    if not isinstance(row, dict):
        raise ValueError("partition event is not a JSON object")
    event_id = row.get("transaction_master_id")
    if event_id is None:
        raise ValueError("partition event has no transaction_master_id")
    context = row.get("normalized_context") or {}
    metric = row.get("metric_replay") or {}
    rule_match = row.get("rule_match") or {}
    recorded = row.get("recorded_result") or {}
    return {
        "transaction_master_id": event_id,
        "timestamp": row.get("event_timestamp"),
        "event_date": row.get("event_date"),
        "institution_id": row.get("institution_id"),
        "source_system": row.get("source_system"),
        "channel": row.get("channel"),
        "txn_type": context.get("txn_type"),
        "customer_id": context.get("customer_id"),
        "history_debit_count": metric.get("history_debit_count"),
        "history_average_amount": metric.get("history_average_amount"),
        "threshold_amount": metric.get("threshold_amount"),
        "derived_current_amount": context.get("current_amount"),
        "derived_current_indicator": context.get("current_indicator"),
        "replay_reason": metric.get("replay_reason"),
        "rule_would_fire": metric.get("rule_would_fire"),
        "recorded_rule_match": rule_match.get("recorded_rule_match"),
        "rule_match_label": rule_match.get("label"),
        "comparison": rule_match.get("comparison"),
        "outcome": row.get("outcome") or {},
        "case_evidence": row.get("case_evidence") or [],
        "final_decision": recorded.get("final_decision"),
        "result_decisions": recorded.get("result_decisions") or [],
        "result_scores": recorded.get("result_scores") or [],
    }


def _load_snapshot_metadata(snapshot_dir, manifest):
    """Read only snapshot metadata after the manifest has been opened."""
    snapshot_path = snapshot_dir / "snapshot.json"
    snapshot = _read_json(snapshot_path)
    if snapshot.get("status") != "HISTORICAL_SNAPSHOT_COMPLETE":
        raise ValueError("snapshot.json does not contain a completed snapshot")
    if snapshot.get("snapshot_id") != manifest.get("snapshot_id"):
        raise ValueError("snapshot ID differs between manifest.json and snapshot.json")
    content = snapshot.get("content") or {}
    return content.get("scope") or {}, content.get("rule") or {}


def read_snapshot_directory(snapshot_dir):
    """Read manifest and all partition files from one snapshot directory."""
    snapshot_dir = Path(snapshot_dir)
    if not snapshot_dir.is_dir():
        raise ValueError(f"snapshot directory does not exist: {snapshot_dir}")

    # The manifest is deliberately read before any partition data.
    manifest_path = snapshot_dir / "manifest.json"
    manifest = _read_json(manifest_path)
    snapshot_id = manifest.get("snapshot_id")
    if not snapshot_id:
        raise ValueError("manifest.json has no snapshot_id")

    scope, rule = _load_snapshot_metadata(snapshot_dir, manifest)
    partitions_dir = snapshot_dir / "partitions"
    if not partitions_dir.is_dir():
        raise ValueError(f"snapshot has no partitions directory: {partitions_dir}")
    partition_files = sorted(partitions_dir.rglob("events.json"))
    if not partition_files:
        raise ValueError("snapshot contains no partitions/events.json files")

    events = []
    partition_counts = {}
    seen_ids = set()
    for path in partition_files:
        payload = _read_json(path)
        if payload.get("snapshot_id") != snapshot_id:
            raise ValueError(f"snapshot ID mismatch in partition file: {path}")
        rows = payload.get("events")
        if not isinstance(rows, list):
            raise ValueError(f"partition file has no events list: {path}")
        partition_key = payload.get("partition_key") or path.parent.relative_to(partitions_dir).as_posix()
        loaded_rows = []
        for row in rows:
            event = _flatten_event(row)
            if event["transaction_master_id"] in seen_ids:
                raise ValueError(
                    f"duplicate transaction_master_id across snapshot partitions: "
                    f"{event['transaction_master_id']}"
                )
            seen_ids.add(event["transaction_master_id"])
            loaded_rows.append(event)
            events.append(event)
        partition_counts[partition_key] = len(loaded_rows)

    expected_events = (manifest.get("row_counts") or {}).get("materialized_events")
    count_matches_manifest = expected_events is None or expected_events == len(events)
    expected_partitions = (manifest.get("row_counts") or {}).get("partitions")
    partition_count_matches_manifest = (
        expected_partitions is None or expected_partitions == len(partition_files)
    )
    status = READ_STATUS if count_matches_manifest and partition_count_matches_manifest else "SNAPSHOT_READ_COUNT_MISMATCH"
    return {
        "status": status,
        "snapshot_directory": str(snapshot_dir),
        "snapshot_id": snapshot_id,
        "manifest": manifest,
        "scope": scope,
        "rule": rule,
        "events": events,
        "partition_files": [str(path) for path in partition_files],
        "partition_counts": partition_counts,
        "summary": {
            "partition_files_read": len(partition_files),
            "transactions_loaded": len(events),
            "manifest_expected_transactions": expected_events,
            "manifest_expected_partitions": expected_partitions,
            "duplicate_transaction_ids": 0,
            "count_matches_manifest": count_matches_manifest,
            "partition_count_matches_manifest": partition_count_matches_manifest,
        },
        "checks": {
            "manifest_opened_first": True,
            "database_reads": "NONE",
            "database_writes": "NONE",
            "stored_metric_sql_execution": "NOT_RUN",
        },
    }


def load_snapshot_dataset(snapshot_dir):
    """Return a historical-dataset-shaped object loaded only from partitions."""
    result = read_snapshot_directory(snapshot_dir)
    if result["status"] != READ_STATUS:
        raise ValueError("snapshot counts do not match the manifest")
    return {
        "status": "HISTORICAL_DATASET_COMPLETE",
        "source": "LOCAL_SNAPSHOT_DIRECTORY",
        "snapshot_directory": result["snapshot_directory"],
        "snapshot_id": result["snapshot_id"],
        "scope": result["scope"],
        "rule": result["rule"],
        "events": result["events"],
    }


def compact_report(result):
    """Return the visible report printed by the command-line reader."""
    return {
        "source": "LOCAL_SNAPSHOT_DIRECTORY",
        "status": result["status"],
        "snapshot_directory": result["snapshot_directory"],
        "snapshot_id": result["snapshot_id"],
        "summary": result["summary"],
        "checks": result["checks"],
        "next_step": "USE_SNAPSHOT_AS_ANALYTICS_INPUT",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot_dir", type=Path, help="Path to one snapshot directory")
    parser.add_argument("--summary", action="store_true", help="Print the compact load summary")
    args = parser.parse_args()
    try:
        result = read_snapshot_directory(args.snapshot_dir)
        print(json.dumps(compact_report(result) if args.summary else result, indent=2, default=str))
        return 0 if result["status"] == READ_STATUS else 1
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Snapshot read failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
