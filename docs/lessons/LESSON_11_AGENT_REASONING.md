# Lesson 11: add an evidence-backed agent layer

The final high-level stage is an optional reasoning layer. In this lab it is a
deterministic local reviewer, so we can test the contract without an API key or
network access. It reads the saved candidate, holdout, and runtime reports,
turns their fields into traceable findings, and blocks a recommendation when
the evidence gates are not satisfied.

## Run it

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_14_agent_reasoning.py --candidate-search "outputs\candidate_search_cust_spend_v1.json" --holdout-validation "outputs\holdout_validation_cust_spend_v1.json" --runtime-semantics "outputs\runtime_semantics_cust_spend_v1.json" --runtime-selection "outputs\runtime_selection_119_123_133.json" --summary --output "outputs\agent_reasoning_cust_spend_v1.json"
```

The report has three useful parts:

- `findings` convert counts into statements with an evidence path and a limit.
- `claims` show what an optional model could say and how each statement is
  supported.
- `recommendation_gate` prevents a multiplier recommendation until there is a
  finalized false-positive label, time-safe holdout evidence, and proven
  runtime metric behavior.

For this dump the result is `INSUFFICIENT_EVIDENCE`. The model call is marked
`NOT_PERFORMED`, the recommendation is `null`, and the next actions are saved in
the report. Unknown outcomes and the unresolved events 123 and 133 stay
visible.

## Checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_agent_reasoning
```

If you later add an LLM adapter, pass only the bounded `agent_input` section to
it. Validate its returned claims against the saved evidence paths and accept
only candidates that pass the same gate. This local stage never edits rules,
changes reference data, or connects to production.
