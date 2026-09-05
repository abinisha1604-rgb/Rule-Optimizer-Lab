from datetime import datetime
from decimal import Decimal
import unittest

from step_13_holdout_validation import (
    choose_cutoff,
    decision_available_at,
    label_visible_at_cutoff,
    partition_events,
)


class HoldoutValidationTests(unittest.TestCase):
    def test_cutoff_creates_two_ordered_partitions(self):
        events = [
            {"transaction_master_id": 1, "timestamp": "2026-01-01 00:00:00"},
            {"transaction_master_id": 2, "timestamp": "2026-01-02 00:00:00"},
            {"transaction_master_id": 3, "timestamp": "2026-01-03 00:00:00"},
        ]
        cutoff = choose_cutoff(events, 0.67)
        selection, holdout = partition_events(events, cutoff)
        self.assertEqual([row["transaction_master_id"] for row in selection], [1, 2])
        self.assertEqual([row["transaction_master_id"] for row in holdout], [3])

    def test_label_submitted_after_cutoff_is_hidden(self):
        event = {
            "outcome": {"label": "KNOWN_CONFIRMED_FRAUD_CLOSED", "supervision": "KNOWN"},
            "case_evidence": [{
                "case_status": "CLOSED",
                "case_decision_code": "CONFIRMED_FRAUD",
                "decision_submitted_at": "2026-02-01 00:00:00",
            }],
        }
        cutoff = datetime(2026, 1, 31)
        self.assertGreater(decision_available_at(event), cutoff)
        hidden = label_visible_at_cutoff(event, cutoff)
        self.assertEqual(hidden["outcome"]["supervision"], "UNKNOWN")

    def test_label_submitted_before_cutoff_remains_visible(self):
        event = {
            "outcome": {"label": "KNOWN_CONFIRMED_FRAUD_CLOSED", "supervision": "KNOWN"},
            "case_evidence": [{
                "case_status": "CLOSED",
                "case_decision_code": "CONFIRMED_FRAUD",
                "decision_submitted_at": "2026-01-02 00:00:00",
            }],
        }
        visible = label_visible_at_cutoff(event, datetime(2026, 1, 31))
        self.assertEqual(visible["outcome"]["supervision"], "KNOWN")


if __name__ == "__main__":
    unittest.main()
