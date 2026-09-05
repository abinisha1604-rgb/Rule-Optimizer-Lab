# Lesson 3: read one exact rule version

The trace found four rules for case 41. Now we read one rule’s stored definition
and learn which historical metrics it needs. This is still evidence collection;
no rule is edited and no metric SQL is executed.

Use the first rule from the trace:

```text
rule_code = CUST_SPEND_2_4X_AVG
recorded version = 1
```

The [Python script](step_05_rule_logic.py) reads:

- `rule_master`: stable rule identity, name, type, and fact;
- `rule_version`: exact version number, status, checksum, structured `logic`,
  and generated `drl_rule`;
- `rule_metric_dependency`: the metric codes declared for the rule;
- `metric_definition`: the metric window and SQL text;
- `rule_required_data`: the transaction variables required by that version.

`rule_version.logic` is structured JSON. `rule_version.drl_rule` is executable
Drools text. They are two representations of the same configured rule, but we
will compare them rather than assume they are equivalent. Metric SQL is returned
as text only. It remains unexecuted until a later, separately approved replay
step.

## 1. Read a compact summary

Run:

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_05_rule_logic.py --rule-code CUST_SPEND_2_4X_AVG --version 1 --summary
```

Look for the rule name, `status`, signal metadata, metric dependency count,
required-data count, and `next_step`. The dependency check reports missing
definitions explicitly. It never substitutes a guessed metric definition.

## 2. Read the full stored definition

```powershell
.\.venv\Scripts\python.exe step_05_rule_logic.py --rule-code CUST_SPEND_2_4X_AVG --version 1
```

The output includes `logic`, `drl_rule`, and every metric’s `sql_statement`.
Do not copy a metric SQL statement into a new query yet. First identify its
parameters, source tables, window cutoff, entity scope, and event-time behavior.
The next lesson will reconstruct one metric on one known transaction.

## 3. What the rule description already tells us

The trace description says this rule requires a debit transaction and compares
the debit amount with a 30-day customer-level average multiplied by
`$LIMIT_AND_COUNT.CUST_AVG_SPEND_MULTIPLIER`. The stored logic and metric
dependency records are the evidence we will use to confirm that description and
find the actual multiplier configuration.

The runtime transaction associated with match 79 was a POS purchase of 186500.00
at `2026-06-30 09:31:00`. That value is context for understanding the firing;
it is not enough to reconstruct the 30-day average. We need the metric’s own
historical SQL and point-in-time cutoff.

## 4. Run the pure checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_rule_logic
```

The four checks cover complete dependencies, missing definitions, missing SQL,
and multiple dependency counting. They run without the database and prove that
the completeness gate does not silently invent metric evidence.

Next follow [Lesson 4: metric replay](LESSON_04_METRIC_REPLAY.md). It resolves
the multiplier from `reference_data` and reconstructs the first allow-listed
metric with a parameterized query; the stored SQL text remains unexecuted.
