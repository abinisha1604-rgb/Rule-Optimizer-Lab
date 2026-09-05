from decimal import Decimal
import unittest

from step_12_candidate_search import (
    candidate_would_fire,
    evaluate_candidate,
    parse_multipliers,
)


class CandidateSearchTests(unittest.TestCase):
    def test_parse_multipliers_is_positive_and_unique(self):
        self.assertEqual(parse_multipliers("2, 3, 2.0"), [Decimal("2"), Decimal("3")])
        with self.assertRaises(ValueError):
            parse_multipliers("2,0")

    def test_no_history_hypothesis_suppresses_empty_history(self):
        event = {
            "history_debit_count": 0,
            "history_average_amount": "0",
            "derived_current_amount": "100",
            "derived_current_indicator": "D",
        }
        self.assertTrue(candidate_would_fire(event, Decimal("3")))
        self.assertFalse(candidate_would_fire(event, Decimal("3"), True))

    def test_candidate_counts_known_outcome_retention_separately(self):
        events = [
            {
                "transaction_master_id": 1,
                "history_debit_count": 2,
                "history_average_amount": "10",
                "derived_current_amount": "40",
                "derived_current_indicator": "D",
                "recorded_rule_match": True,
                "outcome": {"label": "KNOWN_CONFIRMED_FRAUD_CLOSED"},
            },
            {
                "transaction_master_id": 2,
                "history_debit_count": 2,
                "history_average_amount": "20",
                "derived_current_amount": "50",
                "derived_current_indicator": "D",
                "recorded_rule_match": False,
                "outcome": {"label": "KNOWN_CONFIRMED_FRAUD_CLOSED"},
            },
        ]
        result = evaluate_candidate(events, Decimal("2"), "TEST")
        self.assertEqual(result["predicted_fire_count"], 2)
        self.assertEqual(result["known_confirmed_fraud_fired_count"], 2)
        self.assertEqual(result["known_confirmed_fraud_missed_count"], 0)


if __name__ == "__main__":
    unittest.main()
