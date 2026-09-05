# Rule Optimizer Lab

Rule Optimizer Lab is a local, read-only learning implementation of an EFRM
rule-optimization workflow. It restores a PostgreSQL dump into an isolated
local database, traces a case to a historical rule version, replays the rule,
builds a labeled dataset and immutable snapshot, tests bounded threshold
candidates, performs holdout validation, and produces an evidence-gated final
reasoning report.

The project does not modify production rules, write to the restored EFRM
database, execute stored metric SQL, or call an external LLM. The current
agent-reasoning layer is deterministic Python.

## Repository layout

| Folder | Contents |
|---|---|
| `src/` | Local database helper, lesson scripts, snapshot reader, and full pipeline orchestrator |
| `tests/` | Unit tests for the rule, replay, snapshot, validation, and orchestration helpers |
| `sql/` | Read-only case overview and lineage queries |
| `docs/lessons/` | Fourteen step-by-step learning lessons |
| `docs/architecture/` | Research, architecture, workflow, and implementation documents |
| `outputs/` | Saved lab reports, pipeline runs, logs, manifests, and partitioned snapshots |
| `output/pdf/` | Generated PDF architecture and handover documents |
| `output/documents/` | Generated Word documents |
| `reference-materials/` | PRD, database-flow reference, schema material, extracts, and rendered reference pages |
| `scripts/` | Source scripts used to generate the Word and PDF artifacts |
| `data/` | Instructions and checksum for the intentionally excluded database dump |

See [PROJECT_MANIFEST.md](PROJECT_MANIFEST.md) for the complete inclusion and
exclusion record. The detailed lab walkthrough is in
[docs/LAB_GUIDE.md](docs/LAB_GUIDE.md).

## Quick start on Windows

Requirements: Python 3.12+, PostgreSQL 18 client/server tools, and PowerShell.

```powershell
git clone https://github.com/abinisha1604-rgb/Rule-Optimizer-Lab.git
Set-Location Rule-Optimizer-Lab
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item config.example.json config.local.json
```

Place the local dump at:

```text
data\Kanji_011_20260903-133238.dump
```

Then initialize and inspect the isolated database:

```powershell
.\.venv\Scripts\python.exe src\local_postgres.py setup
.\.venv\Scripts\python.exe src\step_02_connect.py --check-config
```

Run the full learning pipeline:

```powershell
.\.venv\Scripts\python.exe src\run_full_pipeline.py `
  --case-id 41 `
  --institution KANJI `
  --continue-on-ineligible
```

Case 41 in the supplied dump is confirmed fraud, so the lab-only continuation
flag is required to demonstrate every handoff. With a finalized false-positive
case, omit the flag and let the eligibility gate control the run.

Run the tests:

```powershell
.\.venv\Scripts\python.exe run_tests.py
```

The validated local suite contains 66 tests. The checked-in pipeline output
completed all stages but correctly ended with `INSUFFICIENT_EVIDENCE` because
the dump has no finalized false-positive labels and does not prove the runtime
metric behavior for two events.

## Evidence boundary

The repository demonstrates local feasibility and traceable data handoffs. It
does not establish production readiness, population-level recall, Drools
equivalence, or authorization to deploy a rule change. The dedicated Rule
Health, Rule Decay, and Rule Overlap analytics remain a future lab step.

