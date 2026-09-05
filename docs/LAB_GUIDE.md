# Rule optimizer: local learning lab

> Repository layout note: this guide was written while the lesson scripts lived
> in one flat lab folder. In this organized repository, run Python files with
> the `src\` prefix from the repository root, and find the lesson documents in
> `docs\lessons\`. Generated reports still live under `outputs\`.

We will build and test one small stage at a time using a separate local copy of
the latest EFRM dump. The starting scope is one institution, one finalized
false-positive case, and one transaction rule. Device rules come after that path works.

Use Python scripts, SQL queries, and saved JSON/CSV results. A manual command can
stand in for the case-finalized event. A JSON file can hold our settings. We can
add the LLM reasoning step after deterministic calculations and replay work.

## The exercises

For every stage: explain the idea, inspect the input, write a small function,
run it, inspect the output, and check a failure case where it matters.

| Stage | What we will code | How we will check it |
|---|---|---|
| 1. Local database | Inspect the dump, restore a separate database, connect Python, inventory tables | Connection identifies `efrm_optimizer_lab`; expected `efrm` tables and counts are visible |
| 2. Trigger and outcome | Manually supply institution and case ID; map actual decision codes | A finalized FP case proceeds; non-FP, open, or unmapped cases stop |
| 3. Case-to-rule trace | Case → source-aware alert mapping → transaction alert/result → matches → rule/version | Inspect source IDs in SQL; account for multiple matches and ambiguous version links |
| 4. Rule inputs | Read one rule's JSON/DRL, relevant group/configuration, and metric definitions | Explain each condition and reproduce its input on one known event |
| 5. Metric reconstruction | Resolve configuration and calculate one allow-listed metric at the event-time cutoff | Compare a fire and a non-fire with the recorded rule-match rows |
| 6. Baseline replay | Evaluate the unchanged rule over the local event population, including non-fired events | Compare predicted firings with recorded firings |
| 7. Baseline diagnosis | Classify mismatches and inspect runtime/group evidence | Keep empty metrics, applicability, and unknown runtime behavior explicit |
| 8. Historical dataset | Extract the full eligible population and attach labels separately | Check event uniqueness, scope, missing values, outcome coverage, and timestamps |
| 9. Candidate search | Try a small bounded set of changes to one threshold/condition | Compare on the same events; preserve unknown labels and count known positives lost |
| 10. Validation and report | Select on an earlier period, validate on a later period, save recommendation or insufficient-evidence result | Check held-out FP change, known-positive retention, sample size, and multi-rule effects |
| 11. Agent reasoning | Supply computed evidence to an optional LLM; validate a structured hypothesis; feed permitted candidates back into replay | Verify every stated metric against saved calculations; reject unsupported candidates |

The environment check, isolated database setup, database inventory, initial
case-overview SQL, and the local lesson scripts through the end-to-end harness
are implemented. We still inspect each saved output one stage at a time so the
learning evidence remains understandable.

Start the agent exercises with [Lesson 1: case trigger](LESSON_01_CASE_TRIGGER.md).
The code is `step_03_case_trigger.py`; its tests are in `test_case_trigger.py`.
Then follow [Lesson 2: case lineage](LESSON_02_CASE_LINEAGE.md), starting with
the case-to-alert join in `sql/02_case_alerts.sql`.
The complete transaction trace is `step_04_trace_case.py`.
Then follow [Lesson 3: rule logic](LESSON_03_RULE_LOGIC.md) with
`step_05_rule_logic.py`.
Then follow [Lesson 4: metric replay](LESSON_04_METRIC_REPLAY.md) with
`step_06_metric_replay.py`.
Then follow [Lesson 5: baseline replay](LESSON_05_BASELINE_REPLAY.md) with
`step_07_baseline_replay.py`.
Then follow [Lesson 6: baseline diagnosis](LESSON_06_BASELINE_DIAGNOSIS.md) with
`step_08_baseline_diagnose.py`.
The runtime-semantics subexperiment in [Lesson 7: runtime semantics](LESSON_07_RUNTIME_SEMANTICS.md)
uses the saved baseline to compare empty-metric interpretations without touching
the database. Its `step_10_runtime_selection.py` follow-up compares the two
remaining mismatches with a matched event and persisted group/result evidence.
The historical dataset in [Lesson 8: historical dataset](LESSON_08_HISTORICAL_DATASET.md)
then attaches case evidence while preserving unknown outcomes.
The bounded threshold experiment in [Lesson 9: candidate search](LESSON_09_CANDIDATE_SEARCH.md)
reads the partitioned snapshot and tests a few multipliers without changing the database.
The time-split harness in [Lesson 10: holdout validation](LESSON_10_HOLDOUT_VALIDATION.md)
checks candidate behavior on a later period and refuses a recommendation when
false-positive labels are unavailable.
The optional reasoning contract in [Lesson 11: agent reasoning](LESSON_11_AGENT_REASONING.md)
turns saved evidence into traceable findings and blocks unsupported decisions.
The architecture follow-up in [Lesson 12: snapshot builder](LESSON_12_SNAPSHOT_BUILDER.md)
packages that historical dataset into a local immutable snapshot, manifest, and
date partition files. It is an educational artifact builder; it does not read
from the database or execute stored metric SQL.
The snapshot ingestion check in [Lesson 13: read snapshot](LESSON_13_READ_SNAPSHOT.md)
opens the manifest first and makes Candidate Search and Holdout Validation read
their event rows from the partition files.
The end-to-end harness in [Lesson 14: full pipeline](LESSON_14_FULL_PIPELINE.md)
runs the lessons in sequence, records every handoff under one run directory, and
keeps the local evidence gate visible at the end.

The old reference dump and architecture are useful maps; their row counts and
data-quality findings are not findings about the latest dump.

## First exercise: understand the setup

`efrm_optimizer_lab` is the new **database name**. `efrm` is the **schema inside
that database**. Our Python connection selects the database; SQL reads tables
such as `efrm.case_master` inside it.

Python 3.12 and PostgreSQL 18 were found on this computer. The existing PostgreSQL
service on port 5432 requires its own password. This lab uses the installed
PostgreSQL binaries to run a **separate instance on port 55432** with its own
database files and generated credentials.

| Connection setting | Lab value |
|---|---|
| Host | `127.0.0.1` |
| Port | `55432` |
| Database | `efrm_optimizer_lab` |
| Schema | `efrm` |
| Username | `lab_owner` |
| Password | Generated locally in `.local-postgres/password.txt`; scripts read it automatically |

`local_postgres.py setup` initializes the instance with password authentication,
starts it on the loopback address, creates the database, restores the custom
archive in one transaction, and runs `step_02_connect.py`. It does not register a
Windows service. Use `start` after a reboot and `stop` when finished.

The lab uses UTF-8, C locale, and UTC session time. Timestamps stored without a
timezone still need their source-timezone meaning established before temporal replay.

Open PowerShell and run:

```powershell
Set-Location 'C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab'
.\.venv\Scripts\python.exe step_01_environment.py
```

If setting up a fresh checkout, first create the environment:

```powershell
python -m venv .venv
```

Read `step_01_environment.py`: it locates the installed tools and checks their
versions. Supplying a dump path also checks its format and, for an archive,
uses `pg_restore --list` to inspect metadata. It does not restore anything.

```powershell
.\.venv\Scripts\python.exe step_01_environment.py --dump '.\data\Kanji_011_20260903-133238.dump'
```

Expected: tool versions, recognized dump format, and archive metadata where
available. A table-data entry does not guarantee the table contains rows.

The supplied dump was copied from WhatsApp storage to the ignored `data` folder.
It is a 313,790,898-byte PostgreSQL custom archive produced by PostgreSQL 18.3,
with 206 EFRM table-data entries. PostgreSQL 18.4 tools successfully read its
table of contents and schema. Its `dblink` and `pg_trgm` extensions are available locally.

```powershell
.\.venv\Scripts\python.exe local_postgres.py setup
.\.venv\Scripts\python.exe local_postgres.py status
```

Setup refuses to overwrite an existing database that does not have a successful
restore receipt for this exact dump. If the same dump was already restored, it
skips the import and reruns the inventory. The receipt records the dump's SHA-256
in `.local-postgres/restore_receipt.json`; restore details are in `outputs/restore.log`.

Archive dumps use `pg_restore`; plain SQL dumps use `psql`. This lab setup script
supports the supplied custom archive. See the official
[pg_restore reference](https://www.postgresql.org/docs/18/app-pgrestore.html)
and [psql reference](https://www.postgresql.org/docs/18/app-psql.html).

## Second script: Python → PostgreSQL → SQL → result

The virtual environment and database dependency (Psycopg 3.3.5) are prepared.
Setup writes the local connection config. After setup, rerun the inventory with:

```powershell
.\.venv\Scripts\python.exe step_02_connect.py --check-config
.\.venv\Scripts\python.exe step_02_connect.py
```

The script reads the generated lab password from its local file. Other configured
local connections prompt for a password without displaying it.
The connection is deliberately limited to `127.0.0.1 / efrm_optimizer_lab`, and
queries run inside a read-only, repeatable-read transaction.

Read the script in this order:

1. `load_config()` selects the local database.
2. `psycopg.connect()` opens a database connection.
3. `conn.execute(...).fetchone()` runs SQL and reads one result row.
4. The `information_schema.columns` query discovers actual table columns.
5. `SELECT count(*)` counts each relevant table.
6. `outputs/db_inventory.json` records the schema and counts for our next lesson.

The column query uses `%s` parameters for values. Table names use
`sql.Identifier`; Python string interpolation is not how we insert SQL values.
See [Psycopg basic usage](https://www.psycopg.org/psycopg3/docs/basic/usage.html).

Passing this exercise proves connectivity and table availability. It does not
yet prove that labels, rule history, or event-time metrics are sufficient.
The inventory counts all institutions in this local copy. Later analytical
queries will explicitly select one institution and the applicable source/channel.

## First SQL exercise: inspect the available cases

```powershell
.\.venv\Scripts\python.exe local_postgres.py overview
```

Read `sql/01_case_overview.sql` alongside its output. It contains five read-only
queries: cases per institution, cases per status/decision/approval combination,
case-alert mappings grouped by source, the decision catalog, and alert-level
decision counts. `GROUP BY` groups rows and `COUNT(*)` counts rows in each group.
The mapping queries join to the parent case with `c.case_id = m.case_id`.
The output is also saved to `outputs/case_overview.txt`.

This overview shows which cases are available. A code resembling “false positive”
is still not enough to start optimization: next we validate the finalization and
approval semantics and inspect each case's source-aware alert lineage.

## Start and stop the lab

Run these commands from this folder:

```powershell
.\.venv\Scripts\python.exe local_postgres.py stop
.\.venv\Scripts\python.exe local_postgres.py start
```

`stop` cleanly closes lab connections and shuts down only the cluster in this
folder. `start` brings the same data back. Neither operation imports the dump again.
The local cluster files, generated password, dump, and output files are ignored by Git.

## What makes the later validation meaningful

- A false-positive case selects a rule to investigate. Candidate evaluation uses
  all events that were eligible for that rule, including events that did not fire.
- Unreviewed/inconclusive events remain unknown; we do not label them legitimate.
- Later investigation outcomes may label earlier events. They must not become
  inputs to the historical rule. Custom SQL metrics must respect event-time cutoffs.
- We must resolve the historical rule/version and explain baseline replay
  mismatches. A Python translation of a simple rule is an initial logic experiment;
  Drools equivalence requires an actual engine/compiler check later.
- Fewer firings from one rule do not necessarily mean fewer alerts or cases when
  other rules also fire. We will distinguish those counts in the report.
- Small or biased samples can establish functional feasibility. They cannot
  establish reliable fraud-detection improvement or population recall.

## Current status

- Environment check passed: Python 3.12.3 and PostgreSQL client tools 18.4.
- Isolated virtual environment created; Psycopg 3.3.5 installed; dependency check passed.
- Latest dump inspected and copied into the lab; custom archive and required extensions verified.
- Separate lab server running on `127.0.0.1:55432`; custom-archive restore completed successfully.
- Python connected and inventoried all 20 expected/supporting tables; none are missing.
- Read-only enforcement verified: PostgreSQL rejected a zero-row UPDATE with SQLSTATE `25006`.
- Case overview SQL ran successfully against the restored database.
- First eligibility lesson: eight automated tests passed; real cases 41 and 1
  skipped as expected, a wrong-institution lookup returned no case, and the
  in-memory synthetic FP example was accepted for the next rule-tracing step.
- Case lineage lesson: six automated reference checks passed; case 41 traced to
  two transaction alerts, two results, and four rule matches, with all four
  references resolved to one rule version and one group mapping.
- Rule-logic lesson: the reader and dependency gate are implemented; metric SQL
  is collected as text only and is not executed by this lesson.
- The first rule read returned `CUST_SPEND_2_4X_AVG` version 1 as active
  (`rule_version_id` 3), with one resolved custom metric dependency
  (`AVG_DEBIT_30DAY`, customer rolling 30-day) and four required inputs.
- Metric-replay lesson: the multiplier was resolved from `reference_data`
  (`CUST_AVG_SPEND_MULTIPLIER = 3`); transaction 119 replayed to a 7300 average,
  21900 threshold, and a recorded rule-match agreement. Transaction 120
  replayed to a non-fire with the same agreement. The stored metric SQL remains
  unexecuted.
- Baseline-replay lesson: all 38 `KANJI` / `CARD_TRANSACTION` events were
  evaluated. The SQL-equivalent replay predicted 12 fires while one exact rule
  match was recorded; 27 comparisons agreed and 11 require diagnostic review.
  Most disagreements are empty-history cases where the stored `COALESCE` gives
  a zero average; two have history and need an applicability/runtime-metric
  explanation. No mismatch is treated as an outcome label.
- Baseline-diagnosis lesson: nine mismatches are empty-history zero-fallback
  cases and two have non-empty history. None persists a `metrics` key, while all
  eleven channels have a configured binding for the rule's group. The dump does
  not show whether the runtime treated a missing metric as null or zero, so both
  semantics remain explicit for the next experiment.
- Runtime-semantics experiment: the saved baseline was compared under the
  stored SQL `COALESCE(..., 0)` interpretation and an experimental
  “no history means metric absent” interpretation. The latter gives 36/38
  agreements and leaves only events 123 and 133 for runtime-selection
  investigation; it is not accepted as proof of engine behavior.
- Runtime-selection inspection: event 123 has only ATM-group matches, while
  event 133 reached the `CUSTOMER_RULES` group and matched other rules. Neither
  persisted the target metric key; event 119 remains the matched POS reference.
  Channel/group selection and metric availability are still unresolved, so
  candidate tuning has not started.
- Historical-dataset lesson: all 38 baseline events were retained; exact
  rule-match evidence is separate from case outcomes. The three closed
  `CONFIRMED_FRAUD` events are known outcomes, action-failed/open cases remain
  unknown, and no finalized false-positive case is available in this dump.
- Candidate-search lesson: multipliers `2`, `2.5`, `3`, `3.5`, and `4` are
  compared under both empty-metric interpretations. The report preserves
  unknown outcomes and known-fraud retention, but returns insufficient evidence
  for a recommendation because there are zero finalized false-positive cases.
- Holdout-validation lesson: the candidate set is evaluated on a chronological
  selection/holdout split with decision-submission time filtering. The current
  dump still returns insufficient evidence, and no candidate is selected or
  written anywhere.
- Agent-reasoning lesson: a deterministic local reviewer consumes the saved
  reports, records evidence-backed claims, and blocks recommendation because
  false-positive labels and runtime metric evidence are still missing. No model
  or network call is made.
- Full-pipeline harness: `run_full_pipeline.py` completed Eligibility, Rule
  Trace, Baseline Replay, runtime support checks, Historical Dataset, Snapshot
  Builder, snapshot-read validation, Candidate Search, Holdout Validation, and
  Agent Reasoning in one read-only run. The current run ends with
  `INSUFFICIENT_EVIDENCE`, as expected from the existing evidence gates.

### Latest dump observations, 2026-09-03

| Table | Rows |
|---|---:|
| `case_master` | 21 |
| `case_alert_mapping` | 45 |
| `transaction_request` / `transaction_master` / `transaction_result` | 38 each |
| `transaction_match` | 38 |
| `transaction_alert` | 20 |
| `rule_master` / `rule_version` | 71 each |
| `metric_definition` | 52 |
| `aggregated_metric` | 0 |

All 21 cases belong to `KANJI`. The decision catalog includes `FALSE_POSITIVE`
and `GENUINE`, but no case currently has either final decision. Two screening
alert mappings have `FALSE_POSITIVE` decisions; these do not establish a finalized
false-positive transaction case. The transaction mappings have three
`CONFIRMED_FRAUD` decisions and six unmapped decisions.

The first eligibility lesson exercises the FP trigger using a clearly labeled
in-memory synthetic fixture. Next we can inspect transaction-case lineage from
this real sample.
Do not reinterpret screening decisions or missing decisions as transaction FP labels.
This sample supports functional learning; it cannot establish reliable optimizer
benefit. Empty `aggregated_metric` means we must inspect the custom SQL metric
definitions and source history before deciding which rules can be replayed.
