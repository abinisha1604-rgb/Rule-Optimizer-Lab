# Lesson 6: diagnose baseline mismatches

The baseline replay is deliberately conservative about its conclusion. It
found 11 events where the hand-written metric replay says the rule fires but
the database has no matching `transaction_match` row. Before changing code, we
separate what the dump proves from what it cannot prove.

## Run the diagnostic

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_08_baseline_diagnose.py `
  --baseline outputs\baseline_cust_spend_v1.json `
  --institution KANJI `
  --source-system CARD_TRANSACTION `
  --summary `
  --output outputs\baseline_cust_spend_v1_diagnostic.json
```

The current dump produces:

| Diagnostic | Result |
|---|---:|
| Mismatches | 11 |
| Empty-history / zero-fallback cases | 9 |
| Non-empty-history but unrecorded cases | 2 (events 123 and 133) |
| Mismatches with a persisted `metrics` key | 0 |
| Mismatches whose channel has a configured binding for the rule group | 11 |

The binding result means the catalog says the rule's `CUSTOMER_RULES` group is
configured for those channels. It does not prove that the runtime selected that
group for an event with no match. Similarly, the missing `metrics` key in
`transaction_master.rule_engine_context` does not prove that the runtime never
calculated the metric; that value may exist only in the in-memory rule context.

The two non-empty-history mismatches are especially useful. The replay computes
thresholds of 15,000 (event 123) and 19,500 (event 133), but neither has a
recorded match. Possible explanations include runtime metric availability,
group-selection behavior, or a difference between the persisted transaction
shape and the DTO supplied to Drools. The dump alone cannot choose among them.

## What we do not do yet

Do not change the multiplier, mark these events as false positives, or filter
them out to improve the agreement count. Those would hide the exact uncertainty
we need to learn from. Do not execute the stored metric SQL blindly. The replay
and diagnostic remain read-only.

The next step is a small runtime-semantics experiment: compare the current
SQL-zero interpretation with an explicit “metric absent means no fire”
interpretation, and keep both results in the report. This lets us test whether
the rule idea is feasible without pretending that the dump contains runtime
metric logs.

Run the pure checks with:

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_baseline_diagnose
```
