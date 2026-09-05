import unittest

from step_14_agent_reasoning import recommendation_gate


class AgentReasoningTests(unittest.TestCase):
    def test_missing_false_positive_labels_block_recommendation(self):
        gate = recommendation_gate(
            {"selection": {"known_false_positive_count": 0}},
            {"checks": {
                "holdout_labels_used_for_selection": False,
                "selection_labels_time_filtered": True,
            }},
            {"checks": {"runtime_behavior_proven": False}},
        )
        self.assertEqual(gate["status"], "BLOCKED")
        self.assertIn("NO_FINALIZED_FALSE_POSITIVE_LABELS", gate["blockers"])
        self.assertIn("RUNTIME_METRIC_BEHAVIOR_UNPROVEN", gate["blockers"])

    def test_gate_requires_holdout_and_time_filter_checks(self):
        gate = recommendation_gate(
            {"selection": {"known_false_positive_count": 1}},
            {"checks": {
                "holdout_labels_used_for_selection": True,
                "selection_labels_time_filtered": False,
            }},
            {"checks": {"runtime_behavior_proven": True}},
        )
        self.assertEqual(gate["status"], "BLOCKED")
        self.assertIn("HOLDOUT_LABEL_USAGE_CHECK_FAILED", gate["blockers"])
        self.assertIn("SELECTION_LABEL_TIME_FILTER_CHECK_FAILED", gate["blockers"])

    def test_gate_can_pass_only_when_all_required_evidence_checks_pass(self):
        gate = recommendation_gate(
            {"selection": {"known_false_positive_count": 1}},
            {"checks": {
                "holdout_labels_used_for_selection": False,
                "selection_labels_time_filtered": True,
            }},
            {"checks": {"runtime_behavior_proven": True}},
        )
        self.assertEqual(gate["status"], "READY_FOR_EXPLICIT_POLICY_REVIEW")
        self.assertIsNone(gate["selected_candidate"])


if __name__ == "__main__":
    unittest.main()
