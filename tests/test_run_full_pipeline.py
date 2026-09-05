"""Small, database-free checks for the local pipeline orchestrator."""

import unittest

from run_full_pipeline import (
    _json_from_output,
    _report_status,
    choose_runtime_event_ids,
    select_rule,
)


class FullPipelineHelperTests(unittest.TestCase):
    def test_json_parser_keeps_root_report_when_nested_status_exists(self):
        output = (
            'prefix from the child process\n'
            '{"source":"LOCAL_DATABASE",'
            '"case":{"status":"CLOSED"},'
            '"decision":{"eligible":false}}\n'
        )
        report = _json_from_output(output)
        self.assertEqual(report["source"], "LOCAL_DATABASE")
        self.assertIn("decision", report)

    def test_report_status_supports_nested_trace_summary(self):
        self.assertEqual(
            _report_status({"summary": {"status": "TRACE_COMPLETE"}}),
            "TRACE_COMPLETE",
        )

    def test_select_rule_is_deterministic_and_supports_explicit_filter(self):
        trace = {
            "transaction_alerts": [
                {"rule_matches": [
                    {"rule_code": "RULE_A", "recorded_rule_version": 1,
                     "signal_code": "A", "rule_master_id": 10,
                     "resolution_status": "RULE_REFERENCE_RESOLVED_FOR_TRACE"},
                    {"rule_code": "RULE_A", "recorded_rule_version": 1,
                     "signal_code": "A", "rule_master_id": 10,
                     "resolution_status": "RULE_REFERENCE_RESOLVED_FOR_TRACE"},
                    {"rule_code": "RULE_B", "recorded_rule_version": 2,
                     "signal_code": "B", "rule_master_id": 11,
                     "resolution_status": "RULE_REFERENCE_RESOLVED_FOR_TRACE"},
                ]}
            ]
        }
        first = select_rule(trace)
        self.assertEqual((first["rule_code"], first["version"]), ("RULE_A", 1))
        explicit = select_rule(trace, "RULE_B", 2)
        self.assertEqual((explicit["rule_code"], explicit["version"]), ("RULE_B", 2))
        self.assertEqual(len(first["available_trace_rules"]), 2)

    def test_runtime_event_selection_prefers_match_and_nonempty_mismatches(self):
        baseline = {
            "summary": {"mismatch_event_ids": [123, 124, 133]},
            "events": [
                {"transaction_master_id": 119, "recorded_rule_match": True,
                 "history_debit_count": 2},
                {"transaction_master_id": 123, "recorded_rule_match": False,
                 "history_debit_count": 2},
                {"transaction_master_id": 124, "recorded_rule_match": False,
                 "history_debit_count": 0},
                {"transaction_master_id": 133, "recorded_rule_match": False,
                 "history_debit_count": 1},
            ],
        }
        self.assertEqual(choose_runtime_event_ids(baseline), [119, 123, 133])


if __name__ == "__main__":
    unittest.main()
