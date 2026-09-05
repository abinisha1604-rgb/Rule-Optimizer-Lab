import json
from pathlib import Path
import tempfile
import unittest

from step_15_snapshot_builder import (
    build_snapshot,
    canonical_sha256,
    normalize_event,
    partition_key,
    write_snapshot,
)


class SnapshotBuilderTests(unittest.TestCase):
    def setUp(self):
        self.dataset = {
            "status": "HISTORICAL_DATASET_COMPLETE",
            "scope": {"institution_id": "KANJI", "source_system": "CARD_TRANSACTION"},
            "rule": {"rule_code": "CUST_SPEND_2_4X_AVG", "version_no": 1},
            "events": [
                {
                    "transaction_master_id": 2,
                    "timestamp": "2026-07-02 12:00:00",
                    "channel": "POS",
                    "txn_type": "PURCHASE",
                    "customer_id": "C2",
                    "derived_current_amount": "100",
                    "derived_current_indicator": "D",
                    "history_debit_count": 1,
                    "history_average_amount": "10",
                    "threshold_amount": "30",
                    "rule_would_fire": True,
                    "recorded_rule_match": True,
                    "rule_match_label": "MATCHED_RULE_VERSION",
                    "comparison": True,
                    "outcome": {"label": "UNKNOWN_NO_CASE_LINK", "supervision": "UNKNOWN"},
                    "case_evidence": [],
                    "final_decision": "BLOCK",
                    "result_decisions": ["BLOCK"],
                    "result_scores": [100],
                },
                {
                    "transaction_master_id": 1,
                    "timestamp": "2026-07-01 12:00:00",
                    "channel": "ATM",
                    "txn_type": "WITHDRAWAL",
                    "customer_id": "C1",
                    "derived_current_amount": "20",
                    "derived_current_indicator": "D",
                    "history_debit_count": 0,
                    "history_average_amount": "0",
                    "threshold_amount": "0",
                    "rule_would_fire": False,
                    "recorded_rule_match": False,
                    "rule_match_label": "NO_MATCHED_RULE_VERSION",
                    "comparison": True,
                    "outcome": {"label": "UNKNOWN_NO_CASE_LINK", "supervision": "UNKNOWN"},
                    "case_evidence": [],
                    "final_decision": "ALLOW",
                    "result_decisions": ["ALLOW"],
                    "result_scores": [0],
                },
            ],
        }

    def test_canonical_hash_ignores_dictionary_order(self):
        self.assertEqual(
            canonical_sha256({"a": 1, "b": 2}),
            canonical_sha256({"b": 2, "a": 1}),
        )

    def test_partition_key_contains_scope_and_event_date(self):
        key = partition_key(self.dataset["scope"], self.dataset["events"][0])
        self.assertEqual(
            key,
            "institution=KANJI/source_system=CARD_TRANSACTION/"
            "channel=POS/event_date=2026-07-02",
        )

    def test_normalized_row_keeps_rule_and_outcome_evidence(self):
        row = normalize_event(self.dataset["scope"], self.dataset["events"][0])
        self.assertEqual(row["transaction_master_id"], 2)
        self.assertEqual(row["metric_replay"]["history_average_amount"], "10")
        self.assertEqual(row["outcome"]["supervision"], "UNKNOWN")

    def test_build_snapshot_materializes_and_partitions_all_valid_events(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "dataset.json"
            source.write_text(json.dumps(self.dataset), encoding="utf-8")
            result = build_snapshot(self.dataset, source)
        self.assertEqual(result["summary"]["materialized_events"], 2)
        self.assertEqual(result["summary"]["excluded_events"], 0)
        self.assertEqual(result["summary"]["partition_count"], 2)
        self.assertTrue(result["manifest"]["immutable"])
        self.assertEqual(result["manifest"]["row_counts"]["input_events"], 2)

    def test_invalid_event_is_recorded_as_exclusion(self):
        invalid = {
            **self.dataset,
            "events": [dict(self.dataset["events"][0], timestamp="bad")],
        }
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "dataset.json"
            source.write_text(json.dumps(invalid), encoding="utf-8")
            result = build_snapshot(invalid, source)
        self.assertEqual(result["summary"]["materialized_events"], 0)
        self.assertEqual(result["summary"]["excluded_events"], 1)
        self.assertIn("invalid", result["manifest"]["exclusions"][0]["reason"])

    def test_write_is_idempotent_and_refuses_hash_collision(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "dataset.json"
            source.write_text(json.dumps(self.dataset), encoding="utf-8")
            result = build_snapshot(self.dataset, source)
            output_dir = Path(temp) / "snapshots"
            first = write_snapshot(result, output_dir)
            second = write_snapshot(result, output_dir)
            self.assertFalse(first["already_exists"])
            self.assertTrue(second["already_exists"])
            manifest = json.loads(first["manifest_path"].read_text(encoding="utf-8"))
            manifest["snapshot_content_hash"] = "different"
            first["manifest_path"].write_text(json.dumps(manifest), encoding="utf-8")
            with self.assertRaises(FileExistsError):
                write_snapshot(result, output_dir)


if __name__ == "__main__":
    unittest.main()
