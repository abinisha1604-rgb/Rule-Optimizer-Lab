"""Pure tests for population replay and unknown-outcome handling."""

import unittest
from datetime import datetime
from decimal import Decimal

from step_07_baseline_replay import evaluate_event, summarize_events


def event(event_id=10, amount="100", txn_type="PURCHASE", result_id=99):
    return {
        "transaction_master_id": event_id,
        "institution_id": "KANJI",
        "source_system": "CARD_TRANSACTION",
        "channel": "POS",
        "txn_type": txn_type,
        "customer_id": "C1",
        "txn_amount": Decimal(amount),
        "txn_timestamp": datetime(2026, 6, 30, 12, 0),
        "source_txn_id": f"S{event_id}",
        "context_drcr_amount": None,
        "context_drcr_indicator": None,
        "result_ids": [result_id] if result_id is not None else [],
    }


def history():
    return [
        {
            "id": 1, "institution_id": "KANJI", "source_system": "CARD_TRANSACTION",
            "customer_id": "C1", "source_txn_id": "H1", "txn_type": "PURCHASE",
            "txn_amount": Decimal("10"), "txn_timestamp": datetime(2026, 6, 29),
            "context_drcr_amount": None, "context_drcr_indicator": None,
        },
        {
            "id": 2, "institution_id": "KANJI", "source_system": "CARD_TRANSACTION",
            "customer_id": "C1", "source_txn_id": "H2", "txn_type": "PURCHASE",
            "txn_amount": Decimal("20"), "txn_timestamp": datetime(2026, 6, 29, 1),
            "context_drcr_amount": None, "context_drcr_indicator": None,
        },
    ]


class BaselineReplayTests(unittest.TestCase):
    def test_fire_and_recorded_match_agree(self):
        result = evaluate_event(event(), history(), Decimal("3"), 30, True, [{"transaction_match_id": 1}])
        self.assertEqual(result["history_average_amount"], Decimal("15"))
        self.assertEqual(result["threshold_amount"], Decimal("45"))
        self.assertTrue(result["rule_would_fire"])
        self.assertTrue(result["comparison"])

    def test_non_debit_does_not_fire(self):
        result = evaluate_event(event(amount="100", txn_type="REFUND"), history(), Decimal("3"), 30, False, [])
        self.assertFalse(result["rule_would_fire"])
        self.assertEqual(result["reason"], "CURRENT_TRANSACTION_IS_NOT_DEBIT")
        self.assertTrue(result["comparison"])

    def test_event_without_result_stays_unknown(self):
        result = evaluate_event(event(event_id=11, result_id=None), history(), Decimal("3"), 30, None, [])
        self.assertTrue(result["rule_would_fire"])
        self.assertIsNone(result["recorded_rule_match"])
        self.assertIsNone(result["comparison"])

    def test_summary_does_not_count_unknown_as_recorded_negative(self):
        rows = [
            {"status": "EVALUATED", "rule_would_fire": True, "recorded_rule_match": True, "comparison": True},
            {"status": "EVALUATED", "rule_would_fire": False, "recorded_rule_match": False, "comparison": True},
            {"status": "EVALUATED", "rule_would_fire": True, "recorded_rule_match": None, "comparison": None},
        ]
        summary = summarize_events(rows)
        self.assertEqual(summary["population_count"], 3)
        self.assertEqual(summary["predicted_fire_count"], 2)
        self.assertEqual(summary["recorded_rule_match_count"], 1)
        self.assertEqual(summary["comparisons_available"], 2)
        self.assertEqual(summary["mismatch_count"], 0)


if __name__ == "__main__":
    unittest.main()
