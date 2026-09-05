# Lesson 7: test runtime metric semantics

The baseline diagnosis found nine mismatches where the replay had no prior
debit history. The stored metric SQL uses `COALESCE(AVG(...), 0)`, while the
rule's DRL checks that the metric is non-null. Because the dump does not store
the in-memory metric map supplied to Drools, we keep both interpretations
explicit and compare them against the recorded rule-match rows.

## Run the experiment

Run this from the lab folder. It reads the saved baseline JSON only; PostgreSQL
and TablePlus do not need to be restarted or changed.

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_09_runtime_semantics.py --baseline "outputs\baseline_cust_spend_v1.json" --summary --output "outputs\runtime_semantics_cust_spend_v1.json"
```

The two interpretations are:

1. `SQL_ZERO_FALLBACK_FROM_BASELINE`: use the replay already calculated from
   the stored SQL, where an empty average becomes zero.
2. `EXPERIMENTAL_NO_HISTORY_MEANS_METRIC_ABSENT`: suppress a fire when no prior
   debit exists, because the non-null guard may fail when the metric is absent.

For this dump the comparison is:

| Interpretation | Predicted fires | Agreements | Mismatches |
|---|---:|---:|---:|
| SQL zero fallback | 12 | 27/38 | 11 |
| No history means absent (experiment) | 3 | 36/38 | 2 |

The remaining mismatch IDs are **123** and **133**. Both have non-empty history,
so the empty-history hypothesis cannot explain them. The catalog shows a group
binding for their channels, but that does not prove the runtime selected the
group or populated the metric. The JSON report records this distinction and
sets `runtime_behavior_proven` to `false`.

## Checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_runtime_semantics
```

Do not change the multiplier, relabel events, or remove mismatches to improve a
score. The next step is to inspect the persisted transaction shape, source
channel, group configuration, and any available engine evidence for events 123
and 133. Only after that should we decide whether a bounded candidate search is
meaningful.

## Inspect the remaining mismatches

The runtime-selection inspection compares events 123 and 133 with the catalog
and persisted result rows. It also accepts a matched event such as 119 as a
reference. The report reads only selected columns and payload shapes; it does
not copy full request/response payloads or execute the metric SQL.

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_10_runtime_selection.py --baseline "outputs\baseline_cust_spend_v1.json" --institution KANJI --source-system CARD_TRANSACTION --event-id 119 --event-id 123 --event-id 133 --summary --output "outputs\runtime_selection_119_123_133.json"
```

The observed result is:

| Event | Channel | Target group observed in matches | Target rule match | Metric key persisted | Final decision |
|---:|---|---|---|---|---|
| 119 | POS | Yes (`CUSTOMER_RULES`) | Yes | No | BLOCK |
| 123 | ATM | No; ATM group only | No | No | REVIEW |
| 133 | POS | Yes (`CUSTOMER_RULES`) | No | No | REVIEW |

This narrows the uncertainty without resolving it. Event 123 may be affected by
channel/group selection. Event 133 reached the target group, so its remaining
question is metric availability or another runtime input difference. The
persisted dump cannot prove which one. Do not tune the multiplier or call either
event a false positive.

The inspection checks can be rerun with:

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_runtime_semantics test_runtime_selection
```
