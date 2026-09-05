# Rule Optimization Agent - Research and Technical Plan

> **Superseded architecture note:** This initial research document has been replaced as the authoritative design by
> `RULE_OPTIMIZATION_AGENT_ENTERPRISE_ARCHITECTURE.md`, which incorporates the PostgreSQL dump evidence and
> enterprise production requirements. This file remains as background research only.

## 1. Executive decision

Build the capability first as a **human-in-the-loop rule analytics and backtesting service**, not as an autonomous rule-changing agent.

The service will:

1. select one institution, source/channel/fact, rule, and rule version;
2. reconstruct the effective rule and the population it evaluated;
3. join rule firings to alerts, cases, investigator decisions, and later confirmed outcomes;
4. calculate rule-health and data-quality metrics over time;
5. detect statistically credible deterioration;
6. generate bounded threshold or scenario candidates;
7. replay current and candidate logic on the same historical population;
8. quantify benefit, cost, uncertainty, and possible risk leakage;
9. produce four versioned, evidence-linked outputs for human approval.

An LLM may explain evidence and draft a readable recommendation. It must not calculate authoritative metrics, execute unbounded SQL, invent labels, edit production `rule_version` rows, or activate a rule.

## 2. Evidence status

### Confirmed from the supplied documents

- The platform uses a shared PostgreSQL `efrm` schema.
- The Rule Engine handles transaction and device events and uses Drools/DRL.
- Runtime flow is:
  `request -> normalize/map -> resolve active group/version -> metrics -> Drools -> result/match/alert -> async RAMS/case hooks`.
- Stable rule identity is `rule_master`; executable/versioned logic is `rule_version`.
- Rule activation context is determined through rule groups, group versions, mappings, and `rule_group_source_binding`.
- `transaction_match` / `device_match` contain fired rule signals.
- `transaction_result` / `device_result` contain overall result fields such as score, decision, severity, matched count, and processing time.
- `transaction_alert` / `device_alert` are operational alerts, not final truth labels.
- Investigation-level alert outcomes live in `case_alert_mapping`; final case outcomes live in `case_master`.
- Original detection results must not be rewritten after human review.
- Admin Service exposes rule configuration/read APIs; Rule Engine consumes effective configuration.
- The agent must use service APIs for state changes and must not directly modify production DRL/rule versions.
- `rule_definition`, `rule_history`, `rule_test`, `rule_group`, and `inst_rule_group` are legacy/review tables. Their active use is unconfirmed.
- Institution scoping is mandatory.

### Confirmed limitation

The provided workspace contains no application source, migrations, API definitions, tests, or database dump. The PRD names six repositories and several development databases, but they are not present here. Therefore actual columns, foreign keys, endpoint paths, label semantics, Drools integration, and historical completeness are not yet verified.

### Proposed, pending validation

Everything below involving exact metric definitions, label mappings, windows, thresholds, candidate bounds, and service technology is a design proposal until the questions in section 15 are answered and the repositories/schema are inspected.

## 3. Beginner fundamentals

### Rule, signal, alert, case, and outcome are different

- A **rule** is deterministic logic, for example `amount > 100000 AND country_risk = HIGH`.
- A **rule firing/signal** means the condition was true for an evaluated event.
- An **alert** is a reviewable operational object. It is not automatically a true positive.
- An **alert-level decision** is an investigator's conclusion about one mapped alert.
- A **case outcome** is the final conclusion for the investigation container, possibly covering several alerts and rules.
- A **confirmed outcome** is the best available label, such as confirmed fraud, suspicious activity, filed STR/SAR, chargeback, recovery, or another client-approved result.

The agent must preserve these levels. Treating every alert as fraud, or every closed case as non-fraud, would make optimization invalid.

### What “good rule performance” means

A good rule finds useful risk while controlling operational cost and avoiding unacceptable missed risk. No single metric represents this trade-off.

Rule health therefore needs four dimensions:

1. **Detection value** - useful/confirmed outcomes captured.
2. **Operational efficiency** - alert volume, false-positive burden, review effort.
3. **Risk coverage** - known bad outcomes missed or insufficiently covered.
4. **Stability and reliability** - metric drift, latency, error rate, data completeness, and performance consistency.

### Why backtesting is necessary

Changing a threshold alters which historical events would fire. A fair test evaluates the current and candidate rule:

- on the same immutable event population;
- with the information that was available at event time;
- using the correct historical rule configuration and metric windows;
- without leaking later investigator outcomes into rule inputs;
- with delayed labels handled explicitly.

## 4. Required analytical dataset

Create a read-only, point-in-time-correct **Rule Evaluation Mart**. One base row represents one event that was eligible for evaluation, not only events that alerted.

Minimum logical fields:

| Group | Required fields |
|---|---|
| Scope | `institution_id`, source system, channel, fact/entity type |
| Event identity | internal request/event ID, client `source_txn_id` where applicable |
| Time | event time, ingestion time, processing time, decision time, label maturity time |
| Rule identity | `rule_master` ID, `rule_version` ID, group version/binding ID |
| Inputs | normalized fields used by the rule, with event-time values |
| Metrics | `aggregated_metric` values and metric-definition version used at event time |
| Rule execution | eligible flag, fired flag, rule score/severity, match ID |
| Overall execution | result score, decision, total matched count, processing duration, error/status |
| Alert | alert ID, created flag, status |
| Investigation | case ID, mapping status, alert-level decision and time |
| Outcome | final case decision and time; approved business outcome labels if available |
| Cost | review minutes, SLA/queue time, action/recovery/loss values if approved and available |
| Lineage | extraction run, source tables/IDs, data-quality flags |

Likely source lineage:

```text
rule_master -> rule_version
            -> rule_group_version_map -> rule_group_version
            -> rule_group_source_binding
            -> rule_metric_dependency -> metric_definition -> aggregated_metric

transaction_request -> transaction_master -> transaction_result
                                      \-> transaction_match -> transaction_alert
                                                              \-> case_alert_mapping -> case_master

device_request -> device_master -> device_result
                              \-> device_match -> device_alert
                                                        \-> case_alert_mapping -> case_master
```

Critical requirement: obtain the **non-fired denominator**. `transaction_match` alone only contains hits. Health rates and backtests require all eligible transactions/device events.

## 5. Label strategy

Define a client-approved label taxonomy before measuring precision or recall.

Recommended hierarchy:

1. `CONFIRMED_POSITIVE`: approved decisions that truly validate the risk.
2. `CONFIRMED_NEGATIVE`: approved decisions that clearly reject the signal.
3. `INCONCLUSIVE`: insufficient evidence, monitoring, duplicate, or ambiguous outcomes.
4. `UNREVIEWED`: no completed investigation.
5. `IMMATURE`: outcome may arrive later; label horizon has not elapsed.

Never silently map status names. Maintain a versioned `outcome_label_mapping` approved per institution.

Use only mature and eligible labels for supervised metrics. Report coverage:

`label_coverage = mature_labeled_events / eligible_mature_events`

Also report median and percentile label delay. A rule can appear to decay simply because recent alerts have not finished investigation.

## 6. Rule-health metrics

Calculate metrics per rule/version and slice them by institution, source, channel, customer/product segment, geography, and time bucket where volume permits.

### Volume and selectivity

- Eligible population: `N`
- Fired events: `TP + FP` after labels mature
- Fire rate: `fired / eligible`
- Alert rate: `alerts / eligible`
- Alerts per day/week
- Unique entities alerted
- Repeat-alert rate
- Concentration: share of alerts from top entities/accounts

### Detection value

Where reliable labels exist:

- Precision / positive predictive value: `TP / (TP + FP)`
- Recall / sensitivity: `TP / (TP + FN)`
- False-positive rate: `FP / (FP + TN)`
- False-negative rate: `FN / (FN + TP)`
- F-beta score, with beta chosen by compliance/risk owners
- Confirmed-positive capture value and loss/recovery-weighted recall, if financial values are valid

Because financial-crime positives are rare, precision-recall analysis is generally more informative than accuracy.

### Operational burden

- Alerts per investigator/day
- Median and p90 handling time
- Queue and SLA breach contribution
- Cases created vs merged
- Duplicate/repeat alert burden
- Cost per confirmed positive
- Total review cost estimate

### Stability and technical health

- Processing latency p50/p95/p99
- Execution errors/timeouts
- Missing required-field rate
- Missing metric rate
- Rule version/config changes
- Fire-rate and precision variability
- Population/input distribution drift

### Proposed composite health score

Do not begin with a composite score. Show the metric panel first. After stakeholder agreement, a transparent score can be added:

```text
health =
  w1 * detection_value
  - w2 * operational_burden
  - w3 * leakage_risk
  - w4 * instability
  - w5 * data_quality_penalty
```

Weights and normalization must be institution-approved, versioned, and shown in every report. A red/amber/green status should be driven by explicit policy gates, not an LLM opinion.

## 7. Rule decay detection

### Definition

Rule decay is a persistent, statistically and operationally meaningful deterioration in one or more agreed health metrics, after accounting for label delay, volume, seasonality, population mix, rule/config changes, and data-quality changes.

### Proposed comparison windows

Use event time and complete calendar buckets.

- Recent window: last 4 complete weeks.
- Reference window: preceding 12 complete weeks.
- Long baseline: trailing 6-12 months for seasonality, when available.
- Minimum volume and positive-label counts must be defined before scoring.

These are starting values, not universal defaults. High-volume rules may use daily buckets; low-volume rules may require monthly/quarterly windows.

### Detection sequence

1. Validate data quality and label maturity.
2. Split at rule-version/configuration changes; never mix versions without showing them.
3. Compare recent vs reference point estimates.
4. Add confidence intervals, preferably bootstrap intervals for ratios.
5. Monitor gradual shifts with EWMA; monitor persistent small shifts with CUSUM.
6. Test population drift for important inputs using suitable distance/tests.
7. require persistence, for example two consecutive evaluation runs, unless a critical risk gate fires.
8. classify cause:
   - performance decay;
   - volume/operational drift;
   - population drift;
   - data-quality/configuration incident;
   - inconclusive due to insufficient labels.

### Proposed decay policy

Flag `REVIEW_REQUIRED` only when:

- the minimum sample/label criteria are met;
- absolute and relative deterioration exceed business materiality limits;
- uncertainty does not reasonably include no material change;
- the signal persists; and
- no known data/config incident fully explains it.

Do not use statistical significance alone. Large datasets can make negligible changes statistically significant.

## 8. Threshold optimization

Threshold optimization is appropriate only when a rule exposes a numeric or ordinal parameter that can be safely replayed.

### Candidate generation

- Read the current version and identify tunable parameters through a parser/structured rule representation.
- Define a stakeholder-approved search range and step size.
- Include the current value as the control.
- Reject candidates that violate syntax, required-data, policy, or hard risk constraints.
- Evaluate each candidate on a development time window.
- Select a small Pareto frontier rather than one magic optimum.
- Validate final candidates on a later untouched holdout window.

### Objective

Use a constrained objective, for example:

```text
minimize estimated review cost
subject to:
  confirmed-positive recall >= agreed floor
  critical-risk capture >= current rule
  alerts/day <= operational capacity
  segment leakage <= approved limits
```

If labels are weak, do not claim precision/recall optimization. Limit the output to volume sensitivity, case-outcome yield, and uncertainty.

## 9. Scenario recommendation

Scenario changes are broader than thresholds. Examples include adding a segment condition, velocity window, exclusion, or conjunction with another signal.

Start with bounded templates:

- threshold increase/decrease;
- add/remove approved categorical filter;
- segment-specific threshold;
- combine with an existing metric;
- suppress repeat firing for an approved cool-down period;
- split one heterogeneous rule into two governed scenarios.

Candidates should be generated from observed error cohorts:

- common patterns among false positives;
- common patterns among known missed positives;
- segments with abnormal yield or burden;
- data fields whose absence causes unreliable behavior.

An LLM may translate those patterns into a draft scenario description, but a deterministic validator must produce the actual executable candidate representation.

## 10. Risk leakage

### Definition

Risk leakage is confirmed or strongly evidenced risky activity that the current rule did not alert on, alerted too late, or covered inadequately.

### Measurement hierarchy

1. **Direct leakage**: confirmed-positive events eligible for the rule but not fired.
2. **Portfolio leakage**: confirmed-positive entities/cases not covered by this rule, optionally considering coverage from other rules.
3. **Delayed leakage**: rule fired only after the approved timeliness limit.
4. **Segment leakage**: materially worse miss/capture rate in a protected or risk-relevant segment.
5. **Potential leakage**: suspicious cohorts without confirmed labels; report separately and never call them false negatives.

Core measures:

- missed positive count and value;
- false-negative rate;
- loss/value-weighted missed rate;
- missed critical cases;
- time-to-detection;
- leakage by source/channel/segment;
- overlap/unique coverage relative to other active rules.

Risk leakage cannot be credibly measured from generated alerts alone. It needs independent outcomes such as confirmed case decisions, fraud/chargeback data, STR/SAR disposition, losses/recoveries, or another approved truth source.

## 11. Historical backtesting

### Replay modes

1. **Exact deterministic replay** - preferred: execute current/candidate DRL using event-time input and metric state.
2. **Analytical replay** - acceptable for simple parsed thresholds: evaluate a validated expression over frozen features.
3. **Counterfactual estimate** - last resort when event-time features cannot be reconstructed; label clearly as an estimate.

### Fair comparison

- Use the same eligible event population.
- Preserve event order for velocity/aggregation rules.
- Reconstruct metrics using only data available before each event.
- Pin rule/group/metric/policy versions.
- Separate development and holdout periods.
- Deduplicate by institution plus client event identity.
- Exclude or separately report corrupted/late/missing events.
- Bootstrap confidence intervals.
- Break down results by time and important segments.

### Simulation result fields

| Measure | Current | Candidate | Delta | Confidence/notes |
|---|---:|---:|---:|---|
| eligible events | | | | |
| fired/alerts | | | | |
| confirmed positives captured | | | | |
| precision | | | | |
| recall | | | | |
| missed positives/value | | | | |
| estimated review hours/cost | | | | |
| critical/segment constraints | | | | |
| latency/errors | | | | |

## 12. Proposed architecture

```text
Admin Portal / Scheduler / Authorized API caller
                   |
           Optimization Orchestrator
                   |
       +-----------+------------+
       |                        |
Effective Config Resolver   Dataset Builder
       |                        |
Admin read APIs / DB views  Read replica / governed views
       |                        |
       +-----------> Versioned analysis snapshot
                              |
          +-------------------+------------------+
          |                   |                  |
    Health Engine       Decay Engine      Candidate Generator
          |                   |                  |
          +-------------------+------------------+
                              |
                     Backtest / Replay Runner
                              |
                  Metrics + uncertainty + lineage
                              |
                   Report/Explanation Generator
                              |
            Recommendation Store + approval workflow
                              |
                 Human review; no auto-activation
```

### Components

1. **Optimization API/orchestrator**
   - validates scope and authorization;
   - creates a job;
   - coordinates stages and status;
   - supports cancellation/retry.

2. **Effective Configuration Resolver**
   - returns exact rule, group, binding, metrics, decision policy, and versions for a requested point in time;
   - should become a first-class read API.

3. **Dataset Builder**
   - uses governed read views or a replica;
   - materializes an immutable, versioned snapshot;
   - runs schema, count, referential, timestamp, and label checks.

4. **Deterministic Analytics Engine**
   - SQL/Python calculations;
   - stores formulas, parameters, metric versions, and confidence intervals.

5. **Candidate Generator and Validator**
   - initially supports numeric threshold parameters;
   - enforces allow-listed templates and bounds;
   - compiles/validates candidates without production activation.

6. **Isolated Backtest Runner**
   - reuses the production Rule Engine/Drools logic where feasible;
   - operates on snapshots in a non-production environment;
   - records artifacts, logs, versions, and resource limits.

7. **Recommendation/Report Service**
   - assembles four outputs from structured results;
   - optional LLM writes plain-language explanations from a restricted evidence package;
   - every claim links to metric IDs, snapshot ID, and source lineage.

8. **Governance and audit**
   - role-based access, tenant isolation, immutable job history;
   - model/prompt version when an LLM is used;
   - approval/rejection/comments;
   - candidate promotion remains the existing rule-governance process.

## 13. Inputs and outputs

### Job input

Prefer IDs and policy references, not a giant prompt:

```json
{
  "institution_id": "required",
  "rule_master_id": "required",
  "rule_version_id": "optional; otherwise resolve effective version",
  "source_system_id": "required",
  "channel": "required when binding uses it",
  "fact_type": "required",
  "analysis_end_date": "required",
  "reference_window": "approved policy ID",
  "recent_window": "approved policy ID",
  "label_policy_id": "required",
  "optimization_policy_id": "required",
  "candidate_types": ["THRESHOLD"],
  "requested_by": "authenticated user context"
}
```

The system then retrieves rule/configuration and historical data through controlled tools. Users should not paste raw transaction or customer data into an LLM prompt.

### Four required outputs

1. **Optimization Report**
   - scope/configuration;
   - data sufficiency;
   - health dashboard;
   - decay evidence and cause classification;
   - problems and recommendation;
   - uncertainty, limitations, and lineage.

2. **Candidate Rule**
   - parent rule/version;
   - structured diff and readable explanation;
   - proposed DRL only after deterministic generation/validation;
   - assumptions, parameter bounds, expected effect;
   - status `PROPOSED`, never automatically active.

3. **Risk Leakage Report**
   - label definition and coverage;
   - direct, delayed, portfolio, and segment leakage;
   - example cohorts with masked identifiers;
   - uncertainty and missing truth sources.

4. **Simulation Results**
   - snapshot and replay versions;
   - current-vs-candidate table;
   - time/segment breakdowns;
   - confidence intervals;
   - constraint pass/fail;
   - reproducibility artifacts.

## 14. Technologies

Use existing platform technologies wherever possible after repository inspection.

Proposed additions:

| Need | Proposed technology |
|---|---|
| System of record | Existing PostgreSQL `efrm`; analytics read replica or governed views |
| Transformations | SQL plus Python; dbt is optional if already accepted |
| Analytics | Python, pandas/polars, NumPy, SciPy, scikit-learn |
| Statistical monitoring | bootstrap intervals, EWMA, CUSUM; optional Evidently for drift reporting |
| Rule replay | Existing Rule Engine and Drools in an isolated backtest mode |
| Jobs | Existing worker/queue framework if present; do not add a new broker before inspection |
| Artifacts | Existing object storage if present; otherwise versioned database metadata plus approved storage |
| API | Match existing service framework after code inspection |
| Reporting | JSON as canonical output; portal/PDF/HTML derived from JSON |
| LLM | Optional explanation layer with structured input/output, no raw DB access, and strict citations |
| Observability | Existing logging/metrics/tracing stack; job/run IDs and data-lineage IDs |

## 15. Implementation plan

### Phase 0 - Discovery and decisions

Deliver:

- repository/service map;
- actual schema and column dictionary;
- effective-configuration resolver map;
- outcome/label decision matrix;
- data availability and quality profile;
- agreed metric, decay, leakage, and optimization policies;
- threat model and access model.

Exit criteria: the team can trace one real rule from version/binding through eligible events, matches, alerts, case mappings, and approved outcomes.

### Phase 1 - Read-only Rule Health MVP

Scope:

- one institution;
- transaction rules only;
- one source/channel;
- descriptive metrics and data-quality checks;
- no candidate generation and no LLM dependency.

Exit criteria: analysts reconcile a sample of reports to DB/API evidence.

### Phase 2 - Decay detection

- version-aware time series;
- recent/reference comparison;
- confidence intervals;
- EWMA/CUSUM;
- label-maturity correction;
- persistence/materiality gates;
- review workflow.

Exit criteria: test on seeded synthetic decay and stable-control scenarios, with known false-alarm behavior.

### Phase 3 - Threshold backtesting

- parse/identify an allow-listed numeric threshold;
- event-time snapshot;
- current and grid candidates;
- holdout evaluation;
- Pareto candidates and risk/capacity constraints;
- reproducible simulation output.

Exit criteria: replay of current rule matches recorded historical behavior within an agreed tolerance.

### Phase 4 - Risk leakage

- integrate approved independent truth sources;
- direct/delayed/segment leakage;
- cross-rule overlap and unique coverage;
- value-weighting where validated.

Exit criteria: compliance/risk owners approve the definitions and sample findings.

### Phase 5 - Scenario recommendations and explanation agent

- bounded scenario templates;
- cohort discovery;
- deterministic candidate validation;
- LLM-generated narrative from structured evidence only;
- prompt/model evaluation for factuality and citation completeness.

Exit criteria: every narrative claim is supported by stored structured evidence; unsupported claims fail validation.

### Phase 6 - Production hardening

- RBAC, tenant isolation, masking, retention;
- load/performance testing;
- scheduler and operational dashboards;
- audit and approval flow;
- disaster recovery;
- model-risk/change-management documentation;
- UAT and controlled rollout.

## 16. Testing strategy

- Unit tests for every metric and label mapping.
- Golden datasets with hand-calculated confusion matrices.
- Synthetic stable, abrupt-decay, gradual-decay, seasonality, and label-delay scenarios.
- Point-in-time leakage tests.
- Replay parity tests against recorded production execution.
- Tenant-isolation and authorization tests.
- Candidate syntax/compile/timeout tests.
- Backtest reproducibility tests.
- Shadow runs before user-visible recommendations.
- Human review measuring recommendation acceptance, rejection reasons, and realized post-change effect.

## 17. Questions that must be answered before final architecture approval

1. Where are the six repositories named in the PRD, especially the Rule Engine, Admin Service, and Admin Portal repositories? Can they be added to this workspace or shared read-only?
2. Can we obtain schema-only DDL/migrations and sanitized sample rows for the relevant tables?
3. Which database/environment and institution is the first pilot?
4. Are we optimizing transaction rules only, device rules too, or both?
5. What exact values in `case_alert_mapping` and `case_master` mean confirmed positive, confirmed negative, duplicate, inconclusive, and still under review for that institution?
6. Is there an independent truth source such as fraud confirmation, chargebacks, STR/SAR outcomes, losses, recovery, or customer complaints? Without it, recall and true risk leakage cannot be measured reliably.
7. Do we store all non-alerted/eligible events and their event-time normalized inputs, or only rule hits/results?
8. Are event-time values of `aggregated_metric` reproducible and tied to metric/rule versions?
9. How are thresholds represented in DRL today? Are rules also available in a structured AST/JSON form?
10. Is there an existing rule test/simulation API and isolated Drools runner? Which of the legacy `rule_test`/`rule_history` paths are still active?
11. What is the expected label-maturity horizon: days, weeks, or months?
12. What has higher priority: missed-risk reduction, alert-volume reduction, investigator capacity, loss value, or a constrained balance?
13. Which recall/capture constraints must never be reduced, especially for critical scenarios?
14. What backtest duration and seasonal cycles are required for the pilot?
15. Who may request an analysis, approve a candidate, and promote it through the existing rule-governance workflow?
16. What data may be sent to an LLM, and must the LLM be private/on-premises?

## 18. Recommended immediate next step

Do not code the agent yet. Run a two-part discovery workshop:

1. **Technical trace:** select one production-like transaction rule and trace configuration, inputs, execution, match, alert, case, and outcome end to end.
2. **Business truth workshop:** agree the label taxonomy, materiality, capacity, critical-risk constraints, and what “better” means.

The output of those workshops is the signed data contract and metric policy used by Phase 1.

## 19. Research basis

- NIST EWMA guidance: https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc324.htm
- NIST CUSUM guidance: https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc323.htm
- scikit-learn precision-recall guidance: https://scikit-learn.org/stable/modules/generated/sklearn.metrics.precision_recall_curve.html
- Evidently drift-method reference: https://docs-old.evidentlyai.com/reference/data-drift-algorithm
