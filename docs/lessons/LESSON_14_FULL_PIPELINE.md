# Lesson 14: run the local pipeline end to end

`run_full_pipeline.py` is a small learning harness that wires the completed
lessons together. It reads one case from the local lab database, traces and
replays its rule, creates the labeled dataset, packages a snapshot, runs the
snapshot-based candidate and holdout analyses, and gives the saved reports to
the deterministic reasoning layer.

Every child process runs with the same local read-only configuration. The
orchestrator does not deploy a rule, update PostgreSQL, execute stored metric
SQL, call a network service, or call an LLM. It stores the reports and child
process logs under one run directory so each handoff can be inspected.

## Run it

From the lab folder:

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe run_full_pipeline.py `
  --case-id 41 `
  --institution KANJI `
  --continue-on-ineligible
```

Case 41 is a closed confirmed-fraud case in this dump, so the eligibility
lesson correctly marks it ineligible for false-positive optimization. The
`--continue-on-ineligible` flag is an explicit lab-only request to inspect the
rest of the wiring with that case. Omit the flag when the eligibility gate
should stop the run safely.

The orchestrator selects the first resolved rule in the case trace. To make a
different selection explicit, add `--rule-code RULE_CODE --version VERSION`.
The multiplier experiment can be adjusted with `--multipliers` and
`--current-multiplier`.

## What it runs

The visible requested stages are Eligibility, Rule Trace, Baseline Replay,
Labeled Historical Dataset, Snapshot Builder, Candidate Search, Holdout
Validation, and Agent Reasoning. Two small support checks are included because
the current reasoning contract consumes their reports: runtime semantics and
runtime selection. A snapshot-read check also verifies the manifest and all
partition files before the two analytics scripts consume them.

For a run named `demo_case41c`, inspect:

```text
outputs\pipeline_runs\demo_case41c\pipeline_summary.json
outputs\pipeline_runs\demo_case41c\01_eligibility.json
...
outputs\pipeline_runs\demo_case41c\11_agent_reasoning.json
outputs\pipeline_runs\demo_case41c\logs\
```

The immutable snapshot itself is recorded in the summary and lives under
`outputs\snapshots\`. Keeping it in that shared folder avoids Windows path
length problems caused by the descriptive partition names.

The end-to-end status can be `PIPELINE_COMPLETE` even when the final reasoning
decision is `INSUFFICIENT_EVIDENCE`: the first means every local handoff ran,
while the second means the evidence gate correctly refused a production rule
recommendation. The current dump has no finalized false-positive labels and
does not prove runtime metric behavior, so that blocked decision is expected.

## Checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_run_full_pipeline
```

The helper tests do not need PostgreSQL. For a complete local verification,
run the command above while the lab instance is running and inspect the final
`pipeline_summary.json`.
