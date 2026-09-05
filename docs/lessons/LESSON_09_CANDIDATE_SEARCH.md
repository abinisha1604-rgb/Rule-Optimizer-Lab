# Lesson 9: run a bounded candidate search

Now that the replay population has explicit unknown outcomes, we can test the
core optimizer idea on a small parameter set. This is a comparison exercise,
not a deployment recommendation. It reads the partitioned snapshot and tries a
few multipliers for the rule, reporting both exact rule-match agreement and
retention of known confirmed-fraud events.

## Run it

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_12_candidate_search.py --snapshot "outputs\snapshots\snapshot_CUST_SPEND_2_4X_AVG_v1_c56f68d5c0c8" --multipliers "2,2.5,3,3.5,4" --current-multiplier 3 --summary --output "outputs\candidate_search_cust_spend_v1_snapshot.json"
```

The script evaluates both interpretations carried forward from Lesson 7:

- SQL zero fallback: an empty average is zero.
- No history means absent: empty history cannot fire the rule.

For every candidate it records predicted fires, exact-match agreements,
remaining mismatches, empty-history fires, and known confirmed-fraud retention.
Unknown cases are never counted as legitimate negatives. The current dump has
three closed confirmed-fraud events and zero closed false-positive events, so
the report must end with
`INSUFFICIENT_OUTCOME_EVIDENCE_FOR_RECOMMENDATION`.

With the supplied data, multiplier `2` fires on more events and retains two of
the three known confirmed-fraud events; multipliers `2.5` through `4` retain
only event 119. Those counts show how the experiment behaves, but they cannot
show false-positive improvement without finalized false-positive labels and a
time-split holdout.

## Checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_candidate_search
```

No candidate is written to PostgreSQL. The next stage is validation design:
choose an earlier selection period and a later holdout period, then require
false-positive labels and known-positive retention before considering a
recommendation.
