"""Tests for dependency gates; SQL strings are treated as data, never run."""

import unittest

from step_05_rule_logic import summarize_metric_dependencies


def metric(code="M_OK", definition_id=1, sql="SELECT 1"):
    return {"metric_code": code, "metric_definition_id": definition_id, "sql_statement": sql}


class RuleLogicTests(unittest.TestCase):
    def test_complete_dependency_set_can_be_reconstructed(self):
        result = summarize_metric_dependencies([metric()])
        self.assertTrue(result["all_dependencies_resolved"])
        self.assertEqual(result["metric_sql_execution"], "NOT_RUN_IN_THIS_LESSON")

    def test_missing_definition_is_explicit(self):
        result = summarize_metric_dependencies([metric("M_UNKNOWN", None, None)])
        self.assertEqual(result["missing_metric_definitions"], ["M_UNKNOWN"])
        self.assertFalse(result["all_dependencies_resolved"])

    def test_missing_sql_is_explicit(self):
        result = summarize_metric_dependencies([metric("M_NO_SQL", 2, None)])
        self.assertEqual(result["missing_sql_definitions"], ["M_NO_SQL"])
        self.assertFalse(result["all_dependencies_resolved"])

    def test_multiple_dependencies_are_counted(self):
        result = summarize_metric_dependencies([metric("M1"), metric("M2")])
        self.assertEqual(result["dependency_count"], 2)


if __name__ == "__main__":
    unittest.main()

