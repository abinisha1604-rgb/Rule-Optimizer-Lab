# Lesson 10: validate candidates with a holdout

Candidate search is useful for learning how the rule changes, but a candidate
should only be considered after a time ordered validation. This step splits the
partitioned snapshot into an earlier selection period and a later holdout period. It
also prevents label leakage: a closed case outcome submitted after the split is
not visible during selection.

## Run it

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_13_holdout_validation.py --snapshot "outputs\snapshots\snapshot_CUST_SPEND_2_4X_AVG_v1_c56f68d5c0c8" --multipliers "2,2.5,3,3.5,4" --current-multiplier 3 --summary --output "outputs\holdout_validation_cust_spend_v1_snapshot.json"
```

The default split uses the first 70% of timestamped events for selection and
the remaining 30% for holdout. You can make the boundary explicit, for example:

```powershell
.\.venv\Scripts\python.exe step_13_holdout_validation.py --snapshot "outputs\snapshots\snapshot_CUST_SPEND_2_4X_AVG_v1_c56f68d5c0c8" --cutoff "2026-06-30 10:00:00" --summary
```

Every multiplier is evaluated on both periods under the two metric
interpretations from Lesson 7. The report shows predicted fires, exact rule
match agreement, known confirmed-fraud retention, and false-positive counts.
The holdout is never used to select a candidate.

For this dump the selection status remains
`INSUFFICIENT_OUTCOME_EVIDENCE_FOR_RECOMMENDATION`: there are no finalized
false-positive labels. The report is therefore a validation harness, not a
recommendation. Unknown cases remain unknown and no rule or database row is
changed.

## Checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_holdout_validation
```

Once a real finalized false-positive case is available, rerun this step with
the same rule version and scope. Then examine the selection/holdout tradeoff
before allowing any optional agent reasoning.
