"""Business examples for the first agent step. Tests never connect to a database."""

from datetime import datetime
import unittest

from step_03_case_trigger import check_eligibility, synthetic_case


class CaseTriggerTests(unittest.TestCase):
    def test_closed_false_positive_can_proceed_to_rule_tracing(self):
        result = check_eligibility(synthetic_case(), "KANJI")
        self.assertTrue(result["eligible"])
        self.assertEqual(result["next_step"], "TRACE_CASE_ALERTS")

    def test_approved_false_positive_requires_approval_evidence(self):
        case = synthetic_case()
        case.update(approval_status="APPROVED", approved_at=datetime(2026, 9, 3, 11))
        self.assertTrue(check_eligibility(case, "KANJI")["eligible"])
        case["approved_at"] = None
        self.assertEqual(check_eligibility(case, "KANJI")["reason"], "APPROVAL_TIMESTAMP_MISSING")

    def test_wrong_institution_cannot_trigger(self):
        result = check_eligibility(synthetic_case(), "ANOTHER_INSTITUTION")
        self.assertFalse(result["eligible"])
        self.assertEqual(result["reason"], "INSTITUTION_MISMATCH")

    def test_missing_case_stops_normally(self):
        result = check_eligibility(None, "KANJI")
        self.assertFalse(result["eligible"])
        self.assertEqual(result["reason"], "CASE_NOT_FOUND_IN_INSTITUTION")

    def test_open_or_unapproved_case_does_not_trigger_despite_fp_code(self):
        for updates, reason in (
            ({"status": "IN_PROGRESS"}, "CASE_NOT_CLOSED"),
            ({"approval_status": "PENDING"}, "APPROVAL_NOT_RESOLVED"),
        ):
            with self.subTest(updates=updates):
                case = {**synthetic_case(), **updates}
                result = check_eligibility(case, "KANJI")
                self.assertFalse(result["eligible"])
                self.assertEqual(result["reason"], reason)

    def test_alert_level_fp_does_not_override_final_case_fraud(self):
        case = synthetic_case()
        case.update(decision_code="CONFIRMED_FRAUD", alert_decision_code="FALSE_POSITIVE")
        self.assertFalse(check_eligibility(case, "KANJI")["eligible"])

    def test_missing_or_unmapped_decision_does_not_trigger(self):
        for code in (None, "", "UNMAPPED_CLIENT_CODE", "GENUINE"):
            with self.subTest(code=code):
                case = {**synthetic_case(), "decision_code": code}
                self.assertFalse(check_eligibility(case, "KANJI")["eligible"])

    def test_missing_decision_timestamp_does_not_trigger(self):
        case = {**synthetic_case(), "decision_submitted_at": None}
        self.assertEqual(check_eligibility(case, "KANJI")["reason"], "DECISION_TIMESTAMP_MISSING")


if __name__ == "__main__":
    unittest.main()

