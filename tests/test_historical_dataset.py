import unittest

from step_11_historical_dataset import classify_case_outcome, rule_match_label


class HistoricalDatasetTests(unittest.TestCase):
    def test_no_case_link_stays_unknown(self):
        result = classify_case_outcome([])
        self.assertEqual(result["label"], "UNKNOWN_NO_CASE_LINK")
        self.assertEqual(result["supervision"], "UNKNOWN")

    def test_closed_confirmed_fraud_is_known(self):
        result = classify_case_outcome([{
            "case_id": 41,
            "case_status": "CLOSED",
            "case_decision_code": "CONFIRMED_FRAUD",
        }])
        self.assertEqual(result["label"], "KNOWN_CONFIRMED_FRAUD_CLOSED")
        self.assertEqual(result["supervision"], "KNOWN")

    def test_nonclosed_decision_is_not_promoted_to_known(self):
        result = classify_case_outcome([{
            "case_id": 42,
            "case_status": "ACTION_FAILED",
            "case_decision_code": "CONFIRMED_FRAUD",
        }])
        self.assertEqual(result["label"], "UNKNOWN_DECISION_PRESENT_CASE_NOT_CLOSED")
        self.assertEqual(result["supervision"], "UNKNOWN")

    def test_rule_match_label_is_separate_from_outcome(self):
        self.assertEqual(rule_match_label(True), "MATCHED_RULE_VERSION")
        self.assertEqual(rule_match_label(False), "NO_MATCHED_RULE_VERSION")
        self.assertEqual(rule_match_label(None), "UNKNOWN_RESULT")


if __name__ == "__main__":
    unittest.main()
