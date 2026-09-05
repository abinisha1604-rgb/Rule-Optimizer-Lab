# Lesson 2: follow a case to its transaction rules

Lesson 1 checked whether a case may start analysis. This lesson builds the
lineage needed to know which rule to analyze:

```text
case → alert mapping → transaction alert → result → transaction event
     → rule match → rule master → recorded rule version + group mapping
```

The code is [step_04_trace_case.py](step_04_trace_case.py). It is read-only and
does not start an optimization job. It keeps source-table identity because
`case_alert_mapping.alert_id` is polymorphic: an alert ID by itself is not enough.

## 1. View the case links in TablePlus

Run `sql/02_case_alerts.sql` first if you have not done so. Case 41 has six
mappings. The two rows whose source is `transaction_alert` have alert IDs 40 and
41. The other four rows belong to screening, device, or adverse-media services.

## 2. Run the complete transaction trace

From PowerShell:

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_04_trace_case.py --institution KANJI --case-id 41
```

Use `--summary` on the first run if you want a short result. Without it, the
output also includes every transaction field and rule-match detail.

```powershell
.\.venv\Scripts\python.exe step_04_trace_case.py --institution KANJI --case-id 41 --summary
```

The script first reads the case, then uses a parameterized query restricted to
the requested institution and the transaction alert source. It follows each
transaction alert to its result, event, and match rows. The output groups rule
matches beneath their alert and includes a summary at the end.

For this dump, expect:

- `transaction_alert_count`: 2 (alerts 40 and 41);
- `transaction_result_count`: 2 (results 119 and 120);
- `rule_match_count`: 4 (two matches per result);
- rule codes for case 41: `CUST_SPEND_2_4X_AVG`,
  `CUST_STRUCTURED_AMOUNT_PATTERN`, `CUST_HIGH_UTILIZATION_SPIKE`, and
  `CUST_DEBIT_CUST_CREDIT_7D`;
- `resolution_status` of `RULE_REFERENCE_RESOLVED_FOR_TRACE` for each match in
  this sample.

The `case.decision_code` remains `CONFIRMED_FRAUD`; this trace is for lineage
learning. It does not make case 41 an optimization trigger.

## 3. Understand the version fields

Each match stores `recorded_rule_version` and `recorded_group_version`. These
are runtime references. The catalog has a rule-master ID, a version row primary
key, and a human version number. The script reports all catalog candidates and
only marks the reference resolved when exactly one version-number candidate and
one group mapping are present.

This matters because a value of `recorded_rule_version = 1` is a version number
in this runtime sample, while the `rule_version.id` primary key can be 3, 5, or
9. Joining `rule_version.id = recorded_rule_version` would silently select the
wrong logic. Unknown rule codes and missing group mappings remain explicit
lineage issues.

## 4. Run the pure checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_trace_case
```

The six checks cover a resolved reference, an unknown rule code, a missing
version, ambiguous versions, a missing group mapping, and a missing match row.
They run without the database. The real command above tests the SQL joins and
the actual restored sample.

Next we will read the resolved rule's `logic` JSON and DRL text, then identify
which transaction fields and metric definitions its conditions require.
