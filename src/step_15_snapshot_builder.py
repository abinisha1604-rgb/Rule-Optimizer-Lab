"""Lesson 12: build a small immutable historical snapshot.

This is a local learning version of the architecture's Historical Snapshot
Builder. It packages the saved historical-dataset JSON into normalized event
rows, partition indexes, and a manifest with hashes and data-quality counts.
It never connects to PostgreSQL, executes stored metric SQL, calls a model, or
writes outside the requested output directory.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile


SCHEMA_VERSION = "LOCAL_HISTORICAL_SNAPSHOT_V1"
SNAPSHOT_STATUS = "HISTORICAL_SNAPSHOT_COMPLETE"
UNKNOWN = "UNKNOWN"


def canonical_json(value):
    """Return stable JSON bytes for content hashing."""
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        default=str,
    ).encode("utf-8")


def canonical_sha256(value):
    """Hash a JSON-compatible value independently of dictionary insertion order."""
    return hashlib.sha256(canonical_json(value)).hexdigest()


def file_sha256(path):
    """Return the SHA-256 digest of a source file."""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_timestamp(value):
    """Parse a dump timestamp and normalize aware values to UTC."""
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is not None:
        parsed = parsed.astimezone(timezone.utc).replace(tzinfo=None)
    return parsed


def _safe_part(value):
    """Make a value safe for a readable partition path."""
    text = str(value).strip() if value is not None else ""
    text = text or UNKNOWN
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", text)


def partition_key(scope, event):
    """Return the architecture-style institution/source/channel/date key."""
    timestamp = parse_timestamp(event.get("timestamp"))
    event_date = timestamp.date().isoformat() if timestamp else UNKNOWN
    institution = scope.get("institution_id") or UNKNOWN
    source_system = scope.get("source_system") or UNKNOWN
    channel = event.get("channel") or UNKNOWN
    return (
        f"institution={_safe_part(institution)}/"
        f"source_system={_safe_part(source_system)}/"
        f"channel={_safe_part(channel)}/"
        f"event_date={_safe_part(event_date)}"
    )


def normalize_event(scope, event):
    """Keep the replay evidence in a stable, explicit snapshot row."""
    timestamp = parse_timestamp(event.get("timestamp"))
    if timestamp is None:
        raise ValueError("event timestamp is missing or invalid")
    event_id = event.get("transaction_master_id")
    if event_id is None:
        raise ValueError("transaction_master_id is missing")
    return {
        "transaction_master_id": event_id,
        "institution_id": scope.get("institution_id"),
        "source_system": scope.get("source_system"),
        "channel": event.get("channel") or UNKNOWN,
        "event_date": timestamp.date().isoformat(),
        "event_timestamp": timestamp.isoformat(sep=" "),
        "normalized_context": {
            "txn_type": event.get("txn_type"),
            "customer_id": event.get("customer_id"),
            "current_amount": event.get("derived_current_amount"),
            "current_indicator": event.get("derived_current_indicator"),
        },
        "metric_replay": {
            "history_debit_count": event.get("history_debit_count"),
            "history_average_amount": event.get("history_average_amount"),
            "threshold_amount": event.get("threshold_amount"),
            "replay_reason": event.get("replay_reason"),
            "rule_would_fire": event.get("rule_would_fire"),
        },
        "rule_match": {
            "recorded_rule_match": event.get("recorded_rule_match"),
            "label": event.get("rule_match_label"),
            "comparison": event.get("comparison"),
        },
        "outcome": event.get("outcome") or {},
        "case_evidence": event.get("case_evidence") or [],
        "recorded_result": {
            "final_decision": event.get("final_decision"),
            "result_decisions": event.get("result_decisions") or [],
            "result_scores": event.get("result_scores") or [],
        },
    }


def build_snapshot(dataset, source_path):
    """Build snapshot content and manifest data without writing files."""
    if dataset.get("status") != "HISTORICAL_DATASET_COMPLETE":
        raise ValueError("input dataset is not a completed historical dataset")
    scope = dict(dataset.get("scope") or {})
    rule = dict(dataset.get("rule") or {})
    source_hash = file_sha256(source_path)
    rows = []
    exclusions = []
    partitions = {}
    timestamps = []
    for index, event in enumerate(dataset.get("events") or []):
        try:
            row = normalize_event(scope, event)
        except ValueError as exc:
            exclusions.append({"input_index": index, "reason": str(exc)})
            continue
        rows.append(row)
        timestamps.append(parse_timestamp(event.get("timestamp")))
        key = partition_key(scope, event)
        partitions.setdefault(key, []).append(row)

    partition_index = []
    for key in sorted(partitions):
        partition_rows = partitions[key]
        relative_path = f"partitions/{key}/events.json"
        partition_index.append({
            "partition_key": key,
            "relative_path": relative_path,
            "event_count": len(partition_rows),
            "event_ids": [row["transaction_master_id"] for row in partition_rows],
        })

    content = {
        "schema_version": SCHEMA_VERSION,
        "source": "LOCAL_SAVED_HISTORICAL_DATASET",
        "scope": scope,
        "rule": rule,
        "events": rows,
        "partition_index": partition_index,
    }
    content_hash = canonical_sha256(content)
    snapshot_id = (
        f"snapshot_{_safe_part(rule.get('rule_code') or 'unknown_rule')}"
        f"_v{_safe_part(rule.get('version_no') or 'unknown')}"
        f"_{source_hash[:12]}"
    )
    event_times = [value for value in timestamps if value is not None]
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "snapshot_id": snapshot_id,
        "snapshot_content_hash": content_hash,
        "source_files": [{
            "path": str(source_path),
            "sha256": source_hash,
            "status": "READ_ONLY_SOURCE",
        }],
        "source_high_water_marks": {
            "event_timestamp_min": min(event_times).isoformat(sep=" ") if event_times else None,
            "event_timestamp_max": max(event_times).isoformat(sep=" ") if event_times else None,
            "ingestion_timestamp": "NOT_AVAILABLE_IN_LOCAL_DATASET",
        },
        "row_counts": {
            "input_events": len(dataset.get("events") or []),
            "materialized_events": len(rows),
            "excluded_events": len(exclusions),
            "partitions": len(partitions),
        },
        "partition_counts": {
            key: len(partitions[key]) for key in sorted(partitions)
        },
        "exclusions": exclusions,
        "configuration_hashes": {
            "scope": canonical_sha256(scope),
            "rule": canonical_sha256(rule),
        },
        "extraction_query_hash": "NOT_APPLICABLE_SAVED_JSON_INPUT",
        "encryption_key_reference": "NOT_APPLICABLE_LOCAL_LAB",
        "retention_classification": "LOCAL_LAB_ONLY",
        "database_writes": "NONE",
        "stored_metric_sql_execution": "NOT_RUN",
        "immutable": True,
    }
    snapshot = {
        "status": SNAPSHOT_STATUS,
        "snapshot_id": snapshot_id,
        "content_hash": content_hash,
        "content": content,
    }
    return {
        "snapshot": snapshot,
        "manifest": manifest,
        "partitions": partitions,
        "summary": {
            "input_events": len(dataset.get("events") or []),
            "materialized_events": len(rows),
            "excluded_events": len(exclusions),
            "partition_count": len(partitions),
            "event_timestamp_min": manifest["source_high_water_marks"]["event_timestamp_min"],
            "event_timestamp_max": manifest["source_high_water_marks"]["event_timestamp_max"],
        },
    }


def write_snapshot(result, output_dir):
    """Write an immutable snapshot directory, refusing hash collisions."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    snapshot_id = result["snapshot"]["snapshot_id"]
    snapshot_dir = output_dir / snapshot_id
    manifest_path = snapshot_dir / "manifest.json"
    if snapshot_dir.exists():
        if not manifest_path.exists():
            raise FileExistsError(f"snapshot directory already exists without a manifest: {snapshot_dir}")
        existing = json.loads(manifest_path.read_text(encoding="utf-8"))
        if existing.get("snapshot_content_hash") == result["manifest"]["snapshot_content_hash"]:
            return {
                "snapshot_dir": snapshot_dir,
                "snapshot_path": snapshot_dir / "snapshot.json",
                "manifest_path": manifest_path,
                "already_exists": True,
            }
        raise FileExistsError("immutable snapshot ID exists with a different content hash")

    temp_dir = Path(tempfile.mkdtemp(prefix=f".{snapshot_id}.", dir=output_dir))
    try:
        (temp_dir / "partitions").mkdir(parents=True, exist_ok=True)
        (temp_dir / "snapshot.json").write_text(
            json.dumps(result["snapshot"], ensure_ascii=False, sort_keys=True, indent=2, default=str) + "\n",
            encoding="utf-8",
        )
        (temp_dir / "manifest.json").write_text(
            json.dumps(result["manifest"], ensure_ascii=False, sort_keys=True, indent=2, default=str) + "\n",
            encoding="utf-8",
        )
        for key, rows in result["partitions"].items():
            path = temp_dir / "partitions" / key / "events.json"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(
                json.dumps({
                    "snapshot_id": snapshot_id,
                    "partition_key": key,
                    "events": rows,
                }, ensure_ascii=False, sort_keys=True, indent=2, default=str) + "\n",
                encoding="utf-8",
            )
        temp_dir.replace(snapshot_dir)
    except Exception:
        # Keep the output directory clean if a local write fails halfway through.
        for child in sorted(temp_dir.rglob("*"), reverse=True):
            if child.is_file() or child.is_symlink():
                child.unlink()
            elif child.is_dir():
                child.rmdir()
        temp_dir.rmdir()
        raise
    return {
        "snapshot_dir": snapshot_dir,
        "snapshot_path": snapshot_dir / "snapshot.json",
        "manifest_path": manifest_path,
        "already_exists": False,
    }


def compact_report(result, written):
    """Return the small report printed by --summary."""
    return {
        "source": "LOCAL_SAVED_DATASET_ONLY",
        "status": SNAPSHOT_STATUS,
        "snapshot_id": result["snapshot"]["snapshot_id"],
        "snapshot_directory": str(written["snapshot_dir"]),
        "snapshot_file": str(written["snapshot_path"]),
        "manifest_file": str(written["manifest_path"]),
        "summary": result["summary"],
        "checks": {
            "source_sha256_present": bool(result["manifest"]["source_files"][0]["sha256"]),
            "snapshot_content_hash_present": bool(result["snapshot"]["content_hash"]),
            "immutable": result["manifest"]["immutable"],
            "database_writes": "NONE",
            "stored_metric_sql_execution": "NOT_RUN",
            "already_exists": written["already_exists"],
        },
        "next_step": "INSPECT_SNAPSHOT_AND_MANIFEST",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, default=Path("outputs/historical_dataset_cust_spend_v1.json"))
    parser.add_argument("--output-dir", type=Path, default=Path("outputs/snapshots"))
    parser.add_argument("--summary", action="store_true", help="Print the compact manifest summary")
    args = parser.parse_args()

    try:
        dataset = json.loads(args.dataset.read_text(encoding="utf-8"))
        result = build_snapshot(dataset, args.dataset)
        written = write_snapshot(result, args.output_dir)
        report = compact_report(result, written) if args.summary else {
            **result["snapshot"],
            "manifest": result["manifest"],
            "summary": result["summary"],
            "written": {key: str(value) for key, value in written.items()},
        }
        print(json.dumps(report, ensure_ascii=False, indent=2, default=str))
        return 0
    except (OSError, ValueError, json.JSONDecodeError, FileExistsError) as exc:
        print(f"Snapshot build failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
