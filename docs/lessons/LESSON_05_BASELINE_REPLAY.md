# Lesson 5: replay the unchanged rule over all events

The single-event checks agreed with the recorded match. Now we test the same
rule against every `KANJI` transaction in the selected source system. This
population includes events that did not record this rule, which is necessary
for a baseline. It still does not attach a fraud/legitimate label and it does
not modify the database.

## Run it

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_07_baseline_replay.py `
  --rule-code CUST_SPEND_2_4X_AVG `
  --version 1 `
  --institution KANJI `
  --source-system CARD_TRANSACTION `
  --summary `
  --output outputs\baseline_cust_spend_v1.json
```

The saved JSON contains every event. The screen output keeps ten sample events
and the counts. `--output` is optional; it is useful because later steps can
read the exact baseline rather than recalculate it by hand.

## What the counts mean

The current dump produces this learning result:

| Count | Value | Meaning |
|---|---:|---|
| Population | 38 | All `KANJI` / `CARD_TRANSACTION` transaction masters |
| Evaluated | 38 | None was missing the timestamp or customer key |
| Replay fires | 12 | The metric SQL's `COALESCE(AVG(...), 0)` semantics plus the rule condition |
| Recorded matches | 1 | Only transaction 119 has this exact rule/version in `transaction_match` |
| Comparisons | 38 | Every event has a transaction result in this dump |
| Agreements | 27 | Replay and recorded match are the same |
| Mismatches | 11 | Replay says fire, but the recorded match is absent |

The mismatches are diagnostic evidence, not false-positive labels. Most have no
earlier debit history, so the stored metric text returns zero and any debit
amount passes the `>= 0` comparison. Two events with history (123 and 133) also
need investigation. The DRL separately requires
`metrics["CUSTOMER.AVG_DEBIT_30DAY"] != null`, and the dump does not persist a
`metrics` object inside `transaction_master.rule_engine_context`. Therefore we
cannot yet tell whether the runtime treats an empty metric as zero, as absent,
or excludes a rule group for some events. We must resolve that before candidate
threshold testing.

## Inspect the mismatches in TablePlus

This query shows the event-time inputs and recorded result without changing
anything:

```sql
SELECT tm.id,
       tm.channel,
       tm.txn_timestamp,
       tm.customer_id,
       tm.txn_type,
       tm.txn_amount,
       tm.rule_engine_context #>> '{transaction,drCrAmount}' AS context_drcr_amount,
       tm.rule_engine_context #>> '{transaction,drCrIndicator}' AS context_drcr_indicator,
       r.final_decision,
       r.matched_rule_count
FROM efrm.transaction_master AS tm
LEFT JOIN efrm.transaction_result AS r
  ON r.transaction_master_id = tm.id
WHERE tm.institution_id = 'KANJI'
  AND tm.source_system = 'CARD_TRANSACTION'
  AND tm.id IN (1, 2, 3, 4, 125, 117, 121, 128, 123, 131, 133)
ORDER BY tm.txn_timestamp, tm.id;
```

The next lesson will classify these mismatches as data/metric/applicability
questions. It will not silently change the replay to make the counts look
better.

Run the pure tests with:

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_baseline_replay
```
