"""Pure tests for the empty-metric semantics experiment."""

import unittest

from step_09_runtime_semantics import compare_interpretation, no_history_metric_is_missing


class RuntimeSemanticsTests(unittest.TestCase):
    def test_empty_history_hypothesis_suppresses_only_empty_history_fire(self):
        self.assertFalse(no_history_metric_is_missing({"history_debit_count": 0, "rule_would_fire": True}))
        self.assertTrue(no_history_metric_is_missing({"history_debit_count": 2, "rule_would_fire": True}))
        self.assertFalse(no_history_metric_is_missing({"history_debit_count": 2, "rule_would_fire": False}))

    def test_comparison_preserves_unknown_recorded_match(self):
        result = compare_interpretation(
            [{"transaction_master_id": 1, "rule_would_fire": True, "recorded_rule_match": None, "history_debit_count": 0}],
            "TEST",
            lambda event: event["rule_would_fire"],
        )
        self.assertEqual(result["predicted_fire_count"], 1)
        self.assertEqual(result["recorded_rule_match_count"], 0)
        self.assertEqual(result["comparisons_available"], 0)
        self.assertEqual(result["mismatch_count"], 0)

    def test_experimental_hypothesis_removes_empty_history_mismatch(self):
        events = [
            {"transaction_master_id": 1, "rule_would_fire": True, "recorded_rule_match": False, "history_debit_count": 0},
            {"transaction_master_id": 2, "rule_would_fire": True, "recorded_rule_match": True, "history_debit_count": 2},
        ]
        result = compare_interpretation(events, "NO_HISTORY", no_history_metric_is_missing)
        self.assertEqual(result["predicted_fire_count"], 1)
        self.assertEqual(result["agreement_count"], 2)
        self.assertEqual(result["mismatch_count"], 0)


if __name__ == "__main__":
    unittest.main()
