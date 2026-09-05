# Lesson 12: build a local historical snapshot

The architecture calls this component the **Historical Snapshot Builder**. In
the earlier lessons, `step_11_historical_dataset.py` created the labeled event
population. This lesson packages that population into an immutable local
artifact so we can inspect the snapshot shape and its manifest.

The lab builder reads the saved JSON dataset only. It normalizes each event,
partitions rows by institution, source system, channel, and event date, and
writes a content hash plus a manifest. It records that ingestion time,
encryption, and production retention are unavailable in this learning copy.
It does not connect to PostgreSQL, execute stored metric SQL, call a model, or
write any database row.

## Run it

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_15_snapshot_builder.py `
  --dataset "outputs\historical_dataset_cust_spend_v1.json" `
  --output-dir "outputs\snapshots" `
  --summary
```

The command prints a snapshot directory such as:

```text
outputs\snapshots\snapshot_CUST_SPEND_2_4X_AVG_v1_<source-hash>\
```

Inside it are:

- `snapshot.json`: normalized event rows and the partition index;
- `manifest.json`: source hash, row counts, time bounds, exclusions,
  configuration hashes, and the snapshot content hash;
- `partitions\...\events.json`: one file for each institution/source/channel/date
  partition.

Re-running the same command is safe: an identical snapshot is left unchanged.
If the same snapshot ID has a different content hash, the builder refuses to
overwrite it. This is an educational immutability check, not a production
storage or encryption implementation.

## Checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_snapshot_builder
```

Open `manifest.json` first when reviewing a snapshot. It tells us exactly what
was included and what the local lab could not prove.
