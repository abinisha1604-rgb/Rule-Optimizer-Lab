"""Pure tests for the allow-listed metric reconstruction lesson."""

import unittest
from decimal import Decimal

from step_06_metric_replay import (
    calculate_average,
    derive_amount,
    derive_indicator,
    extract_multiplier_reference,
    resolve_multiplier,
)


class MetricReplayTests(unittest.TestCase):
    def test_context_indicator_wins_over_transaction_type(self):
        self.assertEqual(derive_indicator("C", "PURCHASE"), "C")

    def test_transaction_type_fallback_derives_debit(self):
        self.assertEqual(derive_indicator(None, "PURCHASE"), "D")
        self.assertEqual(derive_indicator("", "REFUND"), "C")

    def test_context_amount_wins_and_invalid_amount_is_none(self):
        self.assertEqual(derive_amount("115800.00", Decimal("186500")), Decimal("115800.00"))
        self.assertIsNone(derive_amount("not-a-number", Decimal("10")))

    def test_average_includes_only_debits_and_uses_zero_when_empty(self):
        rows = [
            {"id": 1, "txn_type": "PURCHASE", "context_drcr_amount": "10", "txn_amount": "11"},
            {"id": 2, "txn_type": "REFUND", "context_drcr_amount": "99", "txn_amount": "99"},
            {"id": 3, "txn_type": "PURCHASE", "context_drcr_amount": "20", "txn_amount": "20"},
        ]
        result = calculate_average(rows)
        self.assertEqual(result["debit_count"], 2)
        self.assertEqual(result["sum_amount"], Decimal("30"))
        self.assertEqual(result["average_amount"], Decimal("15"))
        self.assertEqual(calculate_average([rows[1]])["average_amount"], Decimal("0"))

    def test_multiplier_reference_requires_exactly_one_declaration(self):
        ref, error = extract_multiplier_reference([
            {"variable_type": "LIST", "variable": "$LIMIT_AND_COUNT.CUST_AVG_SPEND_MULTIPLIER"}
        ])
        self.assertEqual(ref, "CUST_AVG_SPEND_MULTIPLIER")
        self.assertIsNone(error)
        ref, error = extract_multiplier_reference([])
        self.assertIsNone(ref)
        self.assertEqual(error["status"], "MULTIPLIER_REFERENCE_MISSING")

    def test_multiplier_requires_one_active_numeric_row(self):
        value, info = resolve_multiplier([
            {"ref_id": 348, "ref_code": "CUST_AVG_SPEND_MULTIPLIER", "ref_value": "3", "is_active": "Y"}
        ])
        self.assertEqual(value, Decimal("3"))
        self.assertEqual(info["status"], "MULTIPLIER_RESOLVED")
        value, info = resolve_multiplier([
            {"ref_id": 1, "ref_value": "3", "is_active": "Y"},
            {"ref_id": 2, "ref_value": "4", "is_active": "Y"},
        ])
        self.assertIsNone(value)
        self.assertEqual(info["status"], "MULTIPLIER_CONFIGURATION_AMBIGUOUS")


if __name__ == "__main__":
    unittest.main()
