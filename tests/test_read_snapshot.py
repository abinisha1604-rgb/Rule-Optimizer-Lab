import json
from pathlib import Path
import tempfile
import unittest

from step_16_read_snapshot import load_snapshot_dataset, read_snapshot_directory


def make_snapshot(root, events=None, expected_events=None):
    events = events or [{
        "transaction_master_id": 10,
        "event_timestamp": "2026-01-02 03:04:05",
        "event_date": "2026-01-02",
        "institution_id": "KANJI",
        "source_system": "CARD_TRANSACTION",
        "channel": "POS",
        "normalized_context": {
            "txn_type": "PURCHASE",
            "customer_id": "C1",
            "current_amount": "100",
            "current_indicator": "D",
        },
        "metric_replay": {
            "history_debit_count": 1,
            "history_average_amount": "10",
            "threshold_amount": "30",
            "replay_reason": "CURRENT_TRANSACTION_IS_NOT_DEBIT",
            "rule_would_fire": True,
        },
        "rule_match": {
            "recorded_rule_match": False,
            "label": "NO_MATCHED_RULE_VERSION",
            "comparison": False,
        },
        "outcome": {"label": "UNKNOWN_NO_CASE_LINK", "supervision": "UNKNOWN"},
        "case_evidence": [],
        "recorded_result": {
            "final_decision": "REVIEW",
            "result_decisions": ["REVIEW"],
            "result_scores": [10],
        },
    }]
    snapshot_dir = Path(root) / "snapshot_test"
    partition_dir = snapshot_dir / "partitions" / "institution=KANJI" / "source_system=CARD_TRANSACTION" / "channel=POS" / "event_date=2026-01-02"
    partition_dir.mkdir(parents=True)
    manifest = {
        "snapshot_id": "snapshot_test",
        "row_counts": {
            "materialized_events": len(events) if expected_events is None else expected_events,
            "partitions": 1,
        },
        "immutable": True,
    }
    (snapshot_dir / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    snapshot = {
        "status": "HISTORICAL_SNAPSHOT_COMPLETE",
        "snapshot_id": "snapshot_test",
        "content": {
            "scope": {"institution_id": "KANJI", "source_system": "CARD_TRANSACTION"},
            "rule": {"rule_code": "TEST", "version_no": 1},
        },
    }
    (snapshot_dir / "snapshot.json").write_text(json.dumps(snapshot), encoding="utf-8")
    payload = {
        "snapshot_id": "snapshot_test",
        "partition_key": "institution=KANJI/source_system=CARD_TRANSACTION/channel=POS/event_date=2026-01-02",
        "events": events,
    }
    (partition_dir / "events.json").write_text(json.dumps(payload), encoding="utf-8")
    return snapshot_dir


class ReadSnapshotTests(unittest.TestCase):
    def test_reads_manifest_then_counts_partition_events(self):
        with tempfile.TemporaryDirectory() as temp:
            snapshot_dir = make_snapshot(temp)
            result = read_snapshot_directory(snapshot_dir)
        self.assertEqual(result["status"], "SNAPSHOT_READ_COMPLETE")
        self.assertTrue(result["checks"]["manifest_opened_first"])
        self.assertEqual(result["summary"]["transactions_loaded"], 1)
        self.assertEqual(result["summary"]["partition_files_read"], 1)

    def test_loader_returns_earlier_flat_event_shape(self):
        with tempfile.TemporaryDirectory() as temp:
            snapshot_dir = make_snapshot(temp)
            dataset = load_snapshot_dataset(snapshot_dir)
        event = dataset["events"][0]
        self.assertEqual(dataset["source"], "LOCAL_SNAPSHOT_DIRECTORY")
        self.assertEqual(event["derived_current_amount"], "100")
        self.assertEqual(event["history_average_amount"], "10")
        self.assertEqual(event["rule_match_label"], "NO_MATCHED_RULE_VERSION")

    def test_manifest_count_mismatch_is_reported(self):
        with tempfile.TemporaryDirectory() as temp:
            snapshot_dir = make_snapshot(temp, expected_events=2)
            result = read_snapshot_directory(snapshot_dir)
        self.assertEqual(result["status"], "SNAPSHOT_READ_COUNT_MISMATCH")
        self.assertFalse(result["summary"]["count_matches_manifest"])

    def test_duplicate_event_ids_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            first = {
                "transaction_master_id": 10,
                "event_timestamp": "2026-01-02 03:04:05",
                "event_date": "2026-01-02",
                "institution_id": "KANJI",
                "source_system": "CARD_TRANSACTION",
                "channel": "POS",
                "normalized_context": {},
                "metric_replay": {},
                "rule_match": {},
                "outcome": {},
                "case_evidence": [],
                "recorded_result": {},
            }
            snapshot_dir = make_snapshot(temp, events=[first, dict(first)])
            # Replace the single partition with two duplicate rows.
            events_path = next((snapshot_dir / "partitions").rglob("events.json"))
            payload = json.loads(events_path.read_text(encoding="utf-8"))
            payload["events"] = [first, dict(first)]
            events_path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaises(ValueError):
                read_snapshot_directory(snapshot_dir)


if __name__ == "__main__":
    unittest.main()
