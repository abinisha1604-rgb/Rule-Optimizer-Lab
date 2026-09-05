# Project manifest

This repository is an organized publication copy of the Rule Optimizer local
learning project.

## Included

- All 16 lesson source scripts plus `local_postgres.py` and
  `run_full_pipeline.py`.
- All 15 test modules and the repository test runner.
- Both read-only SQL files.
- All 14 lesson documents and five architecture/research Markdown documents.
- All saved lab outputs: baseline reports, diagnostics, historical datasets,
  candidate and holdout reports, agent-reasoning reports, pipeline runs, logs,
  snapshot manifests, and partition files.
- Five generated Word documents and two generated PDF documents.
- Document and PDF generation scripts.
- Reference PRD, schema, database-flow notes, dump extracts, and rendered
  reference pages.
- Example local connection configuration and dependency files.

## Intentionally excluded

These files are not appropriate for source control and are reproducible or
machine-specific:

- `.venv/`: local Python virtual environment.
- `.local-postgres/`: local PostgreSQL cluster, generated password, and runtime
  state.
- `config.local.json`: machine-local connection selection.
- `__pycache__/` and `*.pyc`: generated Python bytecode.
- `tmp/`: intermediate document-rendering and QA artifacts.
- `Kanji_011_20260903-133238.dump`: 313,790,898-byte database archive, which is
  too large for normal GitHub storage and may contain sensitive database data.

The excluded dump can be verified after it is obtained through an approved
data-transfer channel:

```text
Filename: Kanji_011_20260903-133238.dump
SHA-256: 731FDE9BE138AFC42AC3E41B64823DE18CAD1F5750BF0E509DA1BB0F86B774FC
```

The repository is intended to remain private while it contains database-derived
outputs and reference materials.

