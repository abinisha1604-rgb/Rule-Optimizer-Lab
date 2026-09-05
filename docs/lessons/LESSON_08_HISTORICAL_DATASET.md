# Lesson 8: build a labeled historical dataset

Baseline replay gives us a complete event population, but a rule match is not
the same thing as a fraud or false-positive outcome. This lesson joins
transaction alerts to cases and stores the two kinds of evidence separately:

- `rule_match_label` says whether this exact rule/version was recorded.
- `outcome.label` says what the linked case evidence supports.

Closed cases with a submitted decision are the only `KNOWN` outcomes in this
small lab. Open, action-failed, undecided, and unlinked events remain
`UNKNOWN`, even when a decision code is present on a non-closed case.

## Run it

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_11_historical_dataset.py --baseline "outputs\baseline_cust_spend_v1.json" --institution KANJI --source-system CARD_TRANSACTION --summary --output "outputs\historical_dataset_cust_spend_v1.json"
```

The current dump contains 38 events. The exact counts are printed by the
command and saved in the JSON summary. The expected shape is:

- one exact rule match (transaction 119);
- three closed confirmed-fraud outcomes (transactions 119, 120, and 144);
- two non-closed cases with a decision code (transactions 123 and 124), kept
  unknown for outcome modeling;
- no finalized false-positive case in this scope.

The last point is why this dataset cannot estimate false-positive reduction yet.
It is still useful for testing feature extraction, replay consistency, and
known-positive retention. A rule non-match remains an unknown outcome, not a
legitimate label.

## Checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_historical_dataset
```

The generated report is read-only evidence. It does not execute stored metric
SQL or change the database. The next stage can try a small candidate set while
preserving these unknown labels and counting how many known confirmed-fraud
events each candidate would stop firing on.
