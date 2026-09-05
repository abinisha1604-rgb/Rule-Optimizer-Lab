# Lesson 4: reconstruct one metric safely

The rule definition told us that `CUST_SPEND_2_4X_AVG` needs:

```text
current debit amount >= AVG_DEBIT_30DAY * CUST_AVG_SPEND_MULTIPLIER
```

This lesson turns those declarations into one point-in-time calculation for a
known transaction. It is still a read-only learning exercise. The code does
not execute the SQL text stored in `metric_definition.sql_statement`; it uses a
small parameterized query written specifically for `AVG_DEBIT_30DAY`.

## 1. Run the replay for the recorded match

From PowerShell:

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_06_metric_replay.py `
  --rule-code CUST_SPEND_2_4X_AVG `
  --version 1 `
  --transaction-master-id 119 `
  --institution KANJI
```

The backtick means “continue this PowerShell command on the next line.” You
can also paste it as one line.

The important fields are:

| Output | Meaning |
|---|---|
| `derived_current_amount` | `drCrAmount` from the transaction context; this is 115800.00, even though the table's `txn_amount` is 186500.00 |
| `included` | Earlier transactions in the same institution, source system, customer, and 30-day window |
| `average_amount` | Average of earlier debit amounts; 6200 and 8400 produce 7300 |
| `multiplier.ref_value` | The active `reference_data` value; this dump stores 3 (`3X`) |
| `threshold_amount` | 7300 × 3 = 21900 |
| `rule_would_fire` | The deterministic result of the rule condition |
| `recorded_rule_match` | Whether `transaction_match` recorded this exact rule/version |
| `replay_matches_recorded_rule_match` | A useful baseline consistency check |

For this event, both the replay and the recorded match are `true`.

## 2. Run a nearby non-fire

Transaction 120 is six minutes later and uses the same customer:

```powershell
.\.venv\Scripts\python.exe step_06_metric_replay.py --rule-code CUST_SPEND_2_4X_AVG --version 1 --transaction-master-id 120 --institution KANJI --summary
```

The replay sees the earlier three debit amounts (6200, 8400, and 115800),
whose average is 43466.666..., so the threshold is 130400. The current
context amount is 108600, therefore `rule_would_fire` is `false`. There is no
recorded match for this rule/version, so the baseline check is also `true`.

`--summary` removes customer/source identifiers and the row-by-row history.
Omit it when learning from the complete calculation.

## 3. See the multiplier in TablePlus (optional)

Open a SQL query for the `efrm_optimizer_lab` connection and run:

```sql
SELECT ref_id, ref_type, ref_code, ref_value, ref_sub_code,
       is_active, rule_drl_context
FROM efrm.reference_data
WHERE ref_type = 'LIMIT_AND_COUNT'
  AND ref_code = 'CUST_AVG_SPEND_MULTIPLIER';
```

This is configuration evidence only. Do not edit the row.

## What this proves

We can resolve a rule's declared dependency, resolve its configured constant,
apply the event-time window, derive the same amount/indicator precedence used
by the stored SQL, and compare a replay result with an actual rule-match row.
It does not yet prove that every rule can be replayed or that any event is a
false positive. Case 41 is recorded as confirmed fraud; it is being used here
only as a traceable rule event.

The next step is to replay this allow-listed calculation over every relevant
transaction event and record where the data is missing or the recorded match
does not agree. Only after that baseline is understood should we attach outcome
labels or try candidate thresholds.

Run the pure tests with:

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_metric_replay
```
