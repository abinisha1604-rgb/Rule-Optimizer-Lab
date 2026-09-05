# Lesson 1: should this case start the optimizer?

The database is connected. Now we build one small part of the agent: its first
decision. The output is either **eligible to trace rules** or **stop for this case**,
with a reason. We do not change thresholds or run an LLM in this lesson.

The overall path we are working towards is:

```text
case outcome → eligibility → alert/rule trace → historical data
             → baseline replay → candidate test → recommendation
```

## 1. Look at the real input in TablePlus

Open an SQL editor for `efrm_optimizer_lab` and run:

```sql
SELECT case_id, institution_id, status, decision_code,
       approval_status, decision_submitted_at, approved_at
FROM efrm.case_master
WHERE institution_id = 'KANJI'
ORDER BY case_id;
```

Things to notice in this dump:

- Case `41`: `CLOSED`, `CONFIRMED_FRAUD`, approval `NOT_REQUIRED`.
- Case `1`: `IN_PROGRESS`, no final decision.
- No case has final decision `FALSE_POSITIVE`.

The outcome of an individual alert is a different field in a different table.
We read the **final case decision** here; a screening alert marked FP does not
turn a transaction case into FP.

## 2. Read the small Python function

Open `step_03_case_trigger.py`. Read `check_eligibility()` first. It accepts a
Python dictionary representing the case and returns a dictionary explaining the
decision. Because it does not access the database itself, we can test it with
small examples and see exactly why it returned each result.

For this first lab exercise, our policy is:

1. The case exists and belongs to the requested institution.
2. Its status is `CLOSED`.
3. Approval is `NOT_REQUIRED` or `APPROVED`.
4. The case has a final decision code and submission timestamp.
5. If approved, the approval timestamp is present.
6. Its final decision code is exactly `FALSE_POSITIVE`.

The `CLOSED` requirement is a simplifying lab assumption. Other EFRM statuses
such as `ACTION_PENDING` or `ACTION_FAILED` may still hold finalized decisions;
we have not yet established their finalization semantics. This function is the
first teaching version. Its output names the policy so that assumption is visible.

`GENUINE` and unrecognized codes are skipped under this narrow trigger policy.
They are not being classified as fraud. Label mapping for historical analysis
will be a separate step.

## 3. Run the real database example

In PowerShell:

```powershell
cd C:\Users\Abi\OneDrive\Documents\project\rule_optimizer_lab
.\.venv\Scripts\python.exe step_03_case_trigger.py --institution KANJI --case-id 41
```

Expected decision:

```json
{
  "eligible": false,
  "reason": "FINAL_DECISION_IS_NOT_FALSE_POSITIVE",
  "next_step": "STOP_FOR_THIS_CASE"
}
```

Now try case `1`. Expected reason: `CASE_NOT_CLOSED`.

Read `read_case()` next: `psycopg.connect()` opens the read-only DB connection,
`execute()` runs SQL, and `fetchone()` returns a single row as a dictionary.
The `%s` placeholders receive `institution_id` and `case_id` as parameters.

## 4. Exercise the positive path

```powershell
.\.venv\Scripts\python.exe step_03_case_trigger.py --demo
```

Expected: `eligible: true`, reason `ELIGIBLE_FALSE_POSITIVE_CASE`, next step
`TRACE_CASE_ALERTS`. The report explicitly says `SYNTHETIC_DEMO_NOT_DATABASE_EVIDENCE`.
The synthetic ID is `SYNTHETIC_FP_001`. Nothing is inserted into EFRM, and this
example provides no evidence that a real rule should be changed.

`TRACE_CASE_ALERTS` describes the next function we will implement. This script
does not yet call that function or create an optimization job.

## 5. Run the checks

```powershell
.\.venv\Scripts\python.exe -m unittest -v test_case_trigger
```

The tests cover accepted FP examples, an open case despite an FP code, pending
approval, missing timestamps, wrong institution, missing cases, unknown codes,
and an alert-level FP that must not override a final fraud case decision.
They run without a database connection. The real DB commands above test the
SQL-to-Python path separately. A normal skip returns exit code 0; a database
connection failure returns exit code 1.

Next lesson: trace a real transaction case through `case_alert_mapping`,
`transaction_alert`, `transaction_result`, and `transaction_match` to its rules.
We can learn that trace independently of whether the example case qualifies
for optimization. We will inspect the actual version references before joining
them to `rule_version`.
