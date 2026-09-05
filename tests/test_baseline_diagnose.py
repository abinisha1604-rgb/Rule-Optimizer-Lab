"""Pure tests for mismatch classification and binding evidence."""

import unittest

from step_08_baseline_diagnose import binding_evidence, classify_mismatch


class BaselineDiagnosticTests(unittest.TestCase):
    def test_empty_history_zero_fallback_is_classified(self):
        event = {
            "comparison": False,
            "history_debit_count": 0,
            "history_average_amount": "0",
        }
        self.assertEqual(classify_mismatch(event), "EMPTY_HISTORY_ZERO_FALLBACK")

    def test_nonempty_history_is_kept_as_unresolved_runtime_question(self):
        event = {
            "comparison": False,
            "history_debit_count": 2,
            "history_average_amount": "6500",
        }
        self.assertEqual(classify_mismatch(event), "NONEMPTY_HISTORY_UNRECORDED")

    def test_agreement_is_not_a_mismatch(self):
        self.assertIsNone(classify_mismatch({"comparison": True, "history_debit_count": 0, "history_average_amount": "0"}))

    def test_binding_evidence_checks_rule_group_ids(self):
        result = binding_evidence(
            [{"rule_group_version_id": 1}],
            {"POS": [{"rule_group_version_id": 1}, {"rule_group_version_id": 8}]},
            "POS",
        )
        self.assertTrue(result["rule_group_binding_exists_for_channel"])
        self.assertEqual(result["configured_binding_count"], 2)

    def test_binding_evidence_reports_unbound_channel(self):
        result = binding_evidence(
            [{"rule_group_version_id": 1}],
            {"ATM": [{"rule_group_version_id": 2}]},
            "ATM",
        )
        self.assertFalse(result["rule_group_binding_exists_for_channel"])


if __name__ == "__main__":
    unittest.main()
