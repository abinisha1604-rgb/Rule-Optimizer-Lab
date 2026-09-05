# Lesson 13: read the snapshot partitions

This lesson makes the architectural handoff explicit. A downstream reader opens
`manifest.json` first, then loads each `partitions\...\events.json` file. It
counts the rows and checks that the total agrees with the manifest. The reader
does not read the flat historical-dataset file, connect to PostgreSQL, execute
stored metric SQL, or change any data.

## Run it

Use the snapshot directory printed by Lesson 12:

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_16_read_snapshot.py `
  "outputs\snapshots\snapshot_CUST_SPEND_2_4X_AVG_v1_c56f68d5c0c8" `
  --summary
```

The important fields are:

```text
manifest_opened_first: true
partition_files_read: 11
transactions_loaded: 38
manifest_expected_transactions: 38
count_matches_manifest: true
```

## Checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_read_snapshot
```

The reader also exposes `load_snapshot_dataset(...)`. Candidate Search and
Holdout Validation use that function so their event rows come from the
partition files while keeping the earlier replay calculations unchanged.
