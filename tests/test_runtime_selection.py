import unittest

from step_10_runtime_selection import compact_request, context_shape


class RuntimeSelectionTests(unittest.TestCase):
    def test_context_shape_exposes_metric_and_transaction_keys(self):
        shape = context_shape({
            "transaction": {"drCrAmount": "47000", "drCrIndicator": "D"},
            "metrics": {"AVG_DEBIT_30DAY": "5000"},
        })
        self.assertTrue(shape["metric_key_present"])
        self.assertEqual(shape["metric_keys"], ["AVG_DEBIT_30DAY"])
        self.assertEqual(shape["context_drcr_indicator"], "D")

    def test_context_shape_keeps_missing_metric_explicit(self):
        shape = context_shape({"transaction": {"drCrAmount": "47000"}})
        self.assertFalse(shape["metric_key_present"])
        self.assertEqual(shape["metric_keys"], [])

    def test_request_compaction_does_not_copy_payload(self):
        compact = compact_request({
            "transaction_request_row_id": 4,
            "request_id": "REQ-4",
            "channel": "ATM",
            "api_name": "screen",
            "fact": "TRANSACTION",
            "is_test": False,
            "http_status": 200,
            "processing_time_ms": 8,
            "request_payload": {"transaction": {"secret": "omit"}},
            "response_payload": {"decision": "REVIEW"},
        })
        self.assertEqual(compact["request_payload_shape"], ["transaction"])
        self.assertNotIn("secret", compact)


if __name__ == "__main__":
    unittest.main()
