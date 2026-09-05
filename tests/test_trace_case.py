"""Pure decision tests for rule-reference resolution."""

import unittest

from step_04_trace_case import resolve_rule_reference


def row(**overrides):
    base = {
        "rule_code": "EXAMPLE_RULE",
        "rule_master_id": 7,
        "recorded_version_matches": [{"id": 8, "version_no": 1, "status": "ACTIVE"}],
        "group_mapping_candidates": [{"map_id": 9, "rule_version_id": 8, "execution_order": 1}],
    }
    base.update(overrides)
    return base


class RuleReferenceTests(unittest.TestCase):
    def test_one_version_and_one_group_mapping_is_resolved(self):
        self.assertEqual(resolve_rule_reference(row()), "RULE_REFERENCE_RESOLVED_FOR_TRACE")

    def test_unknown_rule_code_is_not_invented(self):
        self.assertEqual(resolve_rule_reference(row(rule_master_id=None)), "RULE_CODE_NOT_IN_RULE_MASTER")

    def test_missing_version_is_not_guessed(self):
        self.assertEqual(resolve_rule_reference(row(recorded_version_matches=[])), "RECORDED_RULE_VERSION_NOT_FOUND")

    def test_multiple_versions_are_ambiguous(self):
        versions = [
            {"id": 8, "version_no": 1, "status": "ACTIVE"},
            {"id": 10, "version_no": 1, "status": "ACTIVE"},
        ]
        self.assertEqual(resolve_rule_reference(row(recorded_version_matches=versions)), "RECORDED_RULE_VERSION_AMBIGUOUS")

    def test_group_mapping_is_required(self):
        self.assertEqual(resolve_rule_reference(row(group_mapping_candidates=[])), "RULE_GROUP_MAPPING_UNRESOLVED")

    def test_missing_match_row_is_not_a_rule(self):
        self.assertEqual(resolve_rule_reference(row(rule_code=None)), "NO_RULE_MATCH_ROW")


if __name__ == "__main__":
    unittest.main()

