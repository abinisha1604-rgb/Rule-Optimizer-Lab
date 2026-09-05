# Rule Optimization Agent - Boss-Ready Technical Implementation Matrix

## 1. Important framework status

There are two different meanings of "framework" in this design:

1. **Confirmed existing EFRM technology** - verified from the supplied PRD, DB-flow reference, schema, or user confirmation.
2. **Proposed Rule Optimization Agent technology** - a concrete target architecture that still requires platform/architecture approval.

It would be inaccurate to call the new Agent framework "confirmed" because the Agent does not yet exist and the required EFRM repositories and infrastructure decisions are not currently available.

### 1.1 Confirmed existing technology

| Technology or behavior | Status | Evidence |
|---|---|---|
| PostgreSQL `efrm` schema | Confirmed | PRD, DB-flow reference, and supplied PostgreSQL dump |
| Sample dump produced by PostgreSQL 18.3 | Confirmed for the supplied sample dump only | `reference-materials/ddl_schema.sql` |
| Rule Engine has Spring controllers/services | Confirmed at framework-family level | PRD source reference |
| Exact Java and Spring/Spring Boot versions | Not confirmed | Rule Engine repository/build files are unavailable |
| Drools/DRL rule execution | Confirmed | PRD and DB-flow reference |
| Structured rule logic in `rule_version.logic` as `jsonb` | Confirmed | Supplied schema |
| Generated DRL in `rule_version.drl_rule` | Confirmed | Supplied schema |
| Existing JSON-to-DRL compilation mechanism | Confirmed by product owner | Compiler exposure method is still unknown |
| Metric Definition Custom SQL in `metric_definition.sql_statement` | Confirmed | Supplied schema |
| Transaction and device result/match/alert lineage | Confirmed | Supplied schema and DB-flow reference |
| Admin Service exposes rule configuration/read capabilities | Confirmed at logical service level | DB-flow reference |
| Admin Service web framework and exact version | Not confirmed | Repository/build files are unavailable |
| Message broker, workflow engine, object store and private LLM | Not confirmed | Infrastructure decisions are pending |

### 1.2 Concrete target stack proposed for approval

This is the recommended reference implementation. It is concrete enough to design and estimate, but it must be approved before it is called the final framework.

| Layer | Proposed implementation |
|---|---|
| Optimization control/API service | Java with Spring Boot, Spring Web, Spring Security and Spring JDBC/JPA |
| Durable workflow orchestration | Temporal workflows and workers |
| Trigger transport | Apache Kafka using versioned event schemas; direct REST API remains supported |
| Job, inbox, outbox, audit and evidence metadata | Separate PostgreSQL optimization schema |
| EFRM data access | Read-only service APIs first; approved parameterized SQL against a read replica/analytical store where APIs are insufficient |
| Historical snapshots | Parquet files in institution-isolated S3-compatible object storage, with manifests/checksums in PostgreSQL |
| Statistical analytics | Python worker using Polars, NumPy and SciPy; scikit-learn only for approved statistical/ML methods |
| LLM integration | Spring AI based Model Gateway with provider adapters for local or external LLMs |
| LLM tools | Explicit allow-listed tool methods backed by deterministic SQL/Python services |
| Rule candidate representation | Existing structured JSON rule representation |
| Candidate compilation | Existing JSON-to-DRL compiler behind `RuleCompilerPort` |
| Replay/backtest | Isolated Java/Drools worker using the same compatible Drools/compiler behavior as production |
| Recommendation interface | Spring Boot REST/OpenAPI endpoint plus `RECOMMENDATION_READY` event |
| Optional RAG | Versioned documentation index using pgvector or an approved enterprise search platform; not part of authoritative data retrieval |
| Observability | OpenTelemetry, Spring Boot Actuator/Micrometer, centralized logs, metrics and traces |
| Security | OAuth2/mTLS service identity, secrets manager, institution authorization, encryption, audit and least-privilege credentials |

If Temporal or Kafka is not approved, the same logical workflow can initially use a Spring Boot state machine with PostgreSQL inbox/outbox tables and controlled background workers. That is a deployment alternative, not a change to the business flow.

## 2. What actually constitutes the Agent

The Agent is not one LLM prompt.

```text
Optimization Orchestrator
    + governed data-retrieval components
    + deterministic SQL/Python analysis tools
    + optional LLM reasoning worker
    + candidate generator
    + compiler and isolated Drools replay
    + recommendation/claim validator
    + human governance
```

The top-level Orchestrator is deterministic. It decides which mandatory stage runs next. The LLM is a bounded reasoning component inside that controlled workflow.

## 3. Standard stage hand-off

Every long-running step uses the same enterprise transition pattern:

```text
1. Temporal schedules a stage activity.
2. A worker receives the activity and checks the stage idempotency key.
3. The worker reads the required immutable input artifacts.
4. The worker performs its specific work.
5. The worker stores an immutable output and checksum.
6. The workflow records the new job state.
7. Temporal schedules the next activity.
8. Temporary failures are retried; permanent failures enter an explicit terminal state.
```

Kafka is used for external EFRM events. Temporal is used for internal multi-step workflow control. PostgreSQL stores business state and evidence metadata.

---

## 4. Detailed step-by-step implementation

## Prerequisite 0 - Define the institution policy contract

This is a deployment/configuration prerequisite, not the first runtime action. At runtime, the policy is loaded only after Step 3 has authenticated and authorized the trigger's institution.

**Component**

`Optimization Policy Resolver`, inside the Spring Boot Optimization Control Service.

**Input**

- `institution_id`;
- event/effective timestamp;
- authenticated caller identity;
- requested or configured analysis scope.

**Where the input comes from**

After authentication, the Trigger Gateway supplies the institution and effective time. Institution-specific settings come from a new, versioned Optimization Policy Store.

**Processing technique**

Normal deterministic backend configuration lookup. No statistical model is involved.

**Proposed framework**

- Spring Boot;
- Spring JDBC/JPA;
- PostgreSQL optimization schema;
- local read-through cache only for immutable policy versions.

**Technical implementation**

1. Query the effective-dated policy using `institution_id` and event time.
2. Resolve:
   - false-positive outcome mapping version;
   - `CANDIDATE_AND_TEST` or `RECOMMENDATION_ONLY`;
   - `LLM_ASSISTED` or `DETERMINISTIC_ONLY`;
   - transaction/device source and channel scope;
   - historical windows;
   - trigger batching/cooldown rules;
   - alert-volume limit;
   - candidate permissions;
   - data and LLM provider policy.
3. Serialize the policy as canonical JSON.
4. Calculate a SHA-256 checksum.
5. Attach the immutable policy ID/checksum to the job.

**Output**

`OptimizationPolicySnapshot`.

**Transition**

The schema/configuration exists before deployment. During runtime, Step 3 calls this resolver after authentication. The Orchestrator refuses to start analysis if mandatory policy is missing or invalid. Otherwise, the policy snapshot is passed by reference to every later stage.

**LLM**

No. Policy selection must be exact and auditable.

---

## Step 1 - Finalize the case and create a reliable trigger

**Component**

Existing Case Service plus a new transactional outbox table/publisher.

**Input**

- case ID;
- final investigator decision code;
- immutable case-decision event/action ID where available;
- decision timestamp/hash where the existing model has no version field;
- approval details where required;
- institution ID;
- finalization timestamp.

**Where the input comes from**

The investigator closes the case through the existing Admin Portal/Case Service workflow.

**Processing technique**

Normal backend business validation and one atomic PostgreSQL transaction.

**Confirmed framework**

The Case Service belongs to the existing Admin Service. Its exact application framework is not confirmed from the files available to this project.

**Proposed technical implementation**

1. Existing Case Service validates the case-close workflow.
2. It writes the final case decision.
3. It writes the audit/case event.
4. In the same PostgreSQL transaction, it inserts a `CASE_FINALIZED` row into `integration_outbox`.
5. A publisher reads unsent rows and publishes them to Kafka.

The outbox prevents the case from being committed while the trigger event is accidentally lost.

**Output**

- finalized case record;
- immutable decision identity;
- pending `CASE_FINALIZED` event.

**Transition**

The Outbox Publisher sends the event. If direct API mode is configured, the Case Service calls the Trigger API after committing. A reconciliation poller detects any missed finalized case.

**LLM**

No.

---

## Step 2 - Deliver and normalize the trigger

**Component**

Kafka consumer in `Trigger Gateway`; REST Trigger Controller for API mode; reconciliation worker for recovery.

**Input**

Event or API payload containing:

```json
{
  "event_id": "uuid",
  "event_type": "CASE_FINALIZED",
  "institution_id": "institution",
  "case_id": "case",
  "decision_code": "client-specific-code",
  "case_decision_event_id": "proposed-immutable-id",
  "case_decision_hash": "sha256",
  "finalized_at": "timestamp",
  "correlation_id": "uuid"
}
```

**Processing technique**

Event schema validation and canonical message transformation.

**Proposed framework**

- Spring Boot;
- Spring for Apache Kafka;
- Spring Web REST/OpenAPI;
- a versioned JSON Schema or Avro schema.

**Technical implementation**

All trigger modes are converted into one internal `CaseFinalizedTrigger` model. `case_decision_event_id` is a proposed integration field, not a confirmed current column. If the existing Case Service cannot provide it, the adapter creates a stable decision identity from the authoritative decision/action record, decision timestamp and a canonical content hash. Business processing after this point does not care whether the trigger came from Kafka, REST, or polling.

**Output**

Normalized `CaseFinalizedTrigger`.

**Transition**

Pass to the Trigger Inbox and security/idempotency validation.

**LLM**

No.

---

## Step 3 - Authenticate, authorize and deduplicate

**Component**

`Trigger Gateway` and transactional `Trigger Inbox`.

**Input**

Normalized trigger plus service identity/token/certificate.

**Processing technique**

Security checks, schema checks and unique-key database checks.

**Proposed framework**

- Spring Security OAuth2 Resource Server and/or mTLS;
- PostgreSQL;
- Spring Transaction Management.

**Technical implementation**

1. Authenticate the calling service.
2. Authorize access to the specified institution.
3. Validate event schema and supported event version.
4. Insert the event into `optimization_trigger_inbox`.
5. Enforce uniqueness using:
   - `event_id`;
   - `(institution_id, case_id, case_decision_identity)`.
6. Record correlation and audit data before acknowledging Kafka.
7. Resolve the effective institution policy described in Prerequisite 0.
8. If the case row is not yet visible due to replica lag, retry with exponential backoff.
9. If a new event reopens or corrects a case, notify the Orchestrator immediately so active jobs/recommendations tied to the previous decision identity are cancelled or superseded.

**Output**

Accepted trigger, duplicate result, or security/validation rejection.

**Transition**

Accepted triggers are sent to the Outcome Resolver. Duplicates are acknowledged without creating another job.

**LLM**

No.

---

## Step 4 - Confirm false-positive eligibility

**Component**

`Case Outcome Resolver`.

**Input**

- institution ID;
- case ID;
- immutable case-decision identity;
- event timestamp;
- effective outcome-mapping policy.

**Where the data comes from**

Preferred: existing Case Service read API.

Fallback: approved read-only views or queries over `case_master`, decision/approval tables and related case history.

**Processing technique**

Deterministic record lookup and configuration-based code mapping.

**Proposed framework**

- Spring Boot service adapter;
- REST client or Spring JDBC;
- PostgreSQL read replica.

**Technical implementation**

1. Read the authoritative case record instead of trusting only the event.
2. Confirm the decision is final and not superseded.
3. Confirm approval if the client workflow requires it.
4. Map the institution-specific decision code to canonical `FALSE_POSITIVE`.
5. Apply the rule: final case decision overrides alert-level decisions.

**Output**

`CanonicalCaseOutcome` containing outcome class, mapping version and evidence reference.

**Transition**

- `FALSE_POSITIVE` -> create an optimization job.
- another outcome -> `IGNORED_NOT_FALSE_POSITIVE`.

**LLM**

No. An LLM must not interpret decision codes.

---

## Step 5 - Create and orchestrate the optimization job

**Component**

`Optimization Orchestrator`.

**Input**

Validated false-positive trigger and immutable policy snapshot.

**Processing technique**

Durable workflow/state-machine orchestration.

**Proposed framework**

- Spring Boot control service;
- Temporal Java SDK;
- PostgreSQL job/evidence schema.

**Technical implementation**

Maintain three different records:

1. `optimization_trigger_inbox`: one immutable received/corrected event.
2. `case_analysis_job`: one case-decision identity being traced to rules.
3. `rule_analysis_run`: one shared analysis for an institution/rule/configuration/scope/window, which may be supported by several false-positive cases.

Runtime actions:

1. Create one `case_analysis_job` for the accepted case-decision identity.
2. Store trigger, policy IDs/checksums, current state and audit metadata.
3. Start a Temporal `CaseAnalysisWorkflow`.
4. Configure timeouts, retries and cancellation.
5. Schedule `ResolveCaseLineage`.
6. After final rule attribution/configuration, create or join the correct `rule_analysis_run`.

**Output**

Durable `case_analysis_job` in state `JOB_CREATED`.

**Transition**

Temporal schedules the Case Lineage Resolver activity.

**LLM**

No. The Orchestrator always remains deterministic.

---

## Step 6 - Trace case to alert, result, match and rule

**Component**

`Case Lineage Resolver`.

**Input**

Case ID, institution ID and immutable case-decision identity.

**Where the data comes from**

Existing Case/Admin and Rule Engine read APIs where available, otherwise approved parameterized queries.

For transaction rules:

```text
case_master
  -> case_alert_mapping
  -> transaction_alert
  -> transaction_result
  -> transaction_match
```

For device rules:

```text
case_master
  -> case_alert_mapping
  -> device_alert
  -> device_result
  -> device_match
```

**Processing technique**

Deterministic relational lineage queries.

**Proposed framework**

- Spring Boot activity worker;
- Spring JDBC/jOOQ-style parameterized query repository;
- read-only PostgreSQL credentials.

**Technical implementation**

1. Query by institution and case ID.
2. Preserve `alert_id`, `alert_type` and `alert_source_table`.
3. Follow the proper transaction or device branch.
4. Collect rule code/version references, signal, severity, weight, score and timestamps.
5. Assign an evidence ID to every source row/reference.
6. Mark missing/deleted/unresolvable rule references rather than guessing.
7. Store a content-hashed lineage artifact.

**Output**

`CaseRuleLineage`.

**Transition**

Temporal schedules preliminary contributor discovery. Broken lineage produces `LINEAGE_FAILED` or a limited manual-review recommendation.

**LLM**

No.

---

## Step 7 - Identify potential contributing rules

**Component**

`Preliminary Rule Target Resolver`.

**Input**

Case lineage and the rule references recorded in transaction/device matches.

**Processing technique**

Deterministic target discovery. This step is preliminary because the exact historical decision policy has not yet been resolved.

**Proposed framework**

- Java/Spring Boot domain service;
- version-aware identity resolver;
- unit-tested match/lineage evaluators.

**Technical implementation**

1. List every rule reference recorded in the match rows.
2. Resolve enough identity information to request the exact configuration.
3. Preserve unresolved/deleted identity candidates.
4. Do not yet make the official primary/supporting/coincidental classification.

**Output**

`PotentialRuleTargets`.

**Transition**

Potential targets proceed to configuration resolution. No shared rule-analysis run is created until Step 9 has resolved the exact configuration and completed final attribution.

**LLM**

No.

---

## Step 8 - Prepare provisional rule-analysis identities

**Component**

`Rule Analysis Scope Builder`, controlled by the Orchestrator.

**Input**

Potential rule identity/version references, institution, channel/source scope, case trigger and policy.

**Processing technique**

Typed identity construction only. Durable aggregation is deferred until exact configuration and attribution are available.

**Proposed framework**

- Spring domain value objects;
- typed rule/version identity envelope;
- immutable case-to-potential-rule links.

**Technical implementation**

Prepare a provisional key similar to:

```text
institution
+ rule identity/version
+ source/channel scope
+ policy version
+ analysis window
```

Do not attach the case to a shared run yet. The key is incomplete until the configuration checksum and final attribution are known.

**Output**

`ProvisionalRuleAnalysisIdentity`.

**Transition**

Schedule Effective Configuration Resolution.

**LLM**

No.

---

## Step 9 - Resolve the exact historical and current rule configuration

**Component**

`Effective Configuration Resolver` with `RuleConfigurationPort`.

**Input**

Rule identity/version references, institution, source/channel/fact and event time.

**Where the data comes from**

Preferred: Admin/Rule Configuration Service read API.

Fallback: governed read-only configuration views/read replica.

This data must not come from RAG.

**Processing technique**

Version-aware deterministic configuration resolution.

**Confirmed framework**

- current rule data resides in PostgreSQL;
- Rule Engine is Spring-based and executes Drools/DRL;
- structured JSON and DRL columns are confirmed;
- compiler exposure is not confirmed.

**Proposed framework**

- Spring Boot resolver;
- adapter/ports architecture;
- REST client plus Spring JDBC fallback.

**Technical implementation**

Resolve:

- `rule_master`;
- exact historical `rule_version`;
- current `rule_version`;
- `logic` JSON;
- `drl_rule` and checksum;
- DRL context and required data;
- rule group/version/map;
- source/channel/fact binding;
- decision policies and upgrades;
- source-to-engine field mappings;
- metric definitions, dependencies and Custom SQL;
- compiler/runtime compatibility information.

Because match fields may contain a business version or database record ID, use a typed identity envelope and explicit resolution rules. Store both historical and current configurations with checksums.

After configuration resolution:

1. Reconstruct the historical rule-group, decision-policy and alert-generation path.
2. Perform the official counterfactual attribution: determine whether the alert would still have been created without each matched rule.
3. Classify each target as:
   - `PRIMARY_CONTRIBUTOR`;
   - `SUPPORTING_CONTRIBUTOR`;
   - `COINCIDENTAL_MATCH`;
   - `UNRESOLVED_ATTRIBUTION`.
4. Run a current-version relevance gate:
   - compare the historical rule that caused the trigger with the current active rule;
   - verify that the suspected false-positive behavior still exists in the current rule;
   - never create a candidate by mutating an obsolete/deleted historical version.
5. Build the final shared-run key from:
   - institution;
   - current target rule/configuration checksum;
   - source/channel/fact scope;
   - policy/outcome-mapping version;
   - analysis window.
6. Use a PostgreSQL unique constraint/lock plus a Temporal workflow signal to create or join the correct `rule_analysis_run`.

**Output**

- immutable `EffectiveRuleBundle`;
- final `RuleAttributionResult`;
- `CurrentVersionRelevanceDecision`;
- final `RuleAnalysisScope`.

**Transition**

Valid/relevant bundle with attributable rule -> Historical Snapshot Builder. An issue already fixed in the current version -> evidence-linked no-further-change recommendation. Ambiguous/missing bundle -> `CONFIGURATION_AMBIGUITY`. Unresolved attribution -> human review without an executable candidate.

**LLM**

No. Exact configuration resolution is not a language-model task.

---

## Step 10 - Build the complete historical evaluation snapshot

**Component**

`Historical Snapshot Builder`.

**Input**

Effective rule bundle, institution/source/channel scope, analysis window and approved query-template IDs.

**Where the data comes from**

PostgreSQL analytical replica or governed analytical store.

**Processing technique**

Versioned parameterized SQL, incremental partition extraction and point-in-time joins.

**Proposed framework**

- Python Temporal worker;
- psycopg/SQLAlchemy Core or approved warehouse connector;
- Polars;
- Parquet in S3-compatible object storage;
- PostgreSQL snapshot manifest.

**Technical implementation**

1. Reconstruct historical eligibility from effective group bindings, source/channel/fact routing, required inputs and event-time configuration.
2. Select all events proven eligible for the rule, not only false-positive cases.
3. Include fired and non-fired events.
4. Join request/master/result/match/alert/case outcome data.
5. Keep event-time values and configuration versions.
6. Flag test, duplicate, invalid and late-arriving records.
7. Partition by institution/date/source.
8. Write Parquet partitions.
9. Store row counts, query-template versions, partition hashes and a final snapshot checksum.

If historical eligibility cannot be reconstructed reliably, stop executable candidate analysis with `ELIGIBLE_POPULATION_NOT_RECONSTRUCTABLE` rather than treating the available rows as the full population.

**Output**

Immutable `RuleEvaluationSnapshot` and extraction manifest.

**Transition**

Schedule Metric SQL reconstruction.

**LLM**

No. The LLM does not generate or execute the extraction SQL.

---

## Step 11 - Reconstruct Metric Definition Custom SQL

**Component**

`Metric SQL Executor`.

**Input**

Metric definitions, `sql_statement`, checksums, event/entity/time parameters and snapshot partitions.

**Processing technique**

Restricted read-only SQL sandbox and point-in-time calculation.

**Confirmed framework**

`metric_definition.sql_statement` is present in the supplied PostgreSQL schema. The current product-specific execution controls are not confirmed.

**Proposed framework**

- dedicated PostgreSQL read-only role;
- SQL parser/validator;
- worker-level time and resource limits;
- Python or Java activity wrapper;
- complete query audit.

**Technical implementation**

1. Reject DDL, DML, multiple statements and unapproved schemas/functions.
2. Require every approved metric to declare a typed parameter contract, for example institution, entity and `as_of_time` placeholders.
3. Bind parameters through the database driver; never rewrite arbitrary SQL text to append tenant/time predicates.
4. Enforce tenant protection using security-barrier views and/or PostgreSQL row-level security in addition to the read-only role.
5. Execute with statement timeout and workload limits.
6. Recreate the metric value as it should have existed at the event time.
7. Store the value, metric version, SQL checksum and input lineage.
8. If the SQL has no safe point-in-time parameter contract, return `METRIC_NOT_REPRODUCIBLE`.
9. Record missing or failed calculations.

**Output**

`EventTimeMetricDataset` and metric reproducibility report, or `METRIC_NOT_REPRODUCIBLE`.

**Transition**

Attach metrics to the snapshot and schedule the Data Quality Gate.

**LLM**

No.

---

## Step 12 - Validate data quality and analysis sufficiency

**Component**

`Data Quality and Sufficiency Gate`.

**Input**

Rule bundle, historical snapshot, reconstructed metrics, case lineage and attribution result.

**Processing technique**

Deterministic validation rules and statistical sufficiency checks.

**Proposed framework**

- Python Temporal worker;
- Polars;
- Great Expectations or an internal versioned validation library;
- results persisted in PostgreSQL.

**Technical implementation**

Check:

- tenant/institution consistency;
- duplicate and broken joins;
- missing rule inputs;
- metric calculation failures;
- historical configuration identity;
- enough usable events and time buckets;
- enough finalized outcomes;
- source/channel coverage;
- snapshot leakage from future data;
- current-rule replay prerequisites.
- whether historical bindings and eligible-population membership are reproducible.

Produce separate permissions:

- `analysis_allowed`;
- `llm_reasoning_allowed`;
- `candidate_generation_allowed`;
- `backtest_allowed`.

**Output**

`DataReadinessDecision` and limitations.

**Transition**

Pass -> deterministic analytics. Failure -> evidence-limited recommendation such as `INSUFFICIENT_EVIDENCE` or `ELIGIBLE_POPULATION_NOT_RECONSTRUCTABLE`.

**LLM**

No. The LLM must not decide whether the underlying dataset is valid.

---

## Step 13 - Calculate authoritative rule evidence

**Component**

`Deterministic Analysis Engine`.

**Input**

Validated snapshot, triggering cases, rule definition, outcome mapping and alert-volume policy.

**Processing technique**

SQL aggregation plus deterministic statistical analysis in Python.

**Proposed framework**

- Python Temporal worker;
- Polars for dataframe processing;
- NumPy/SciPy for statistics;
- scikit-learn only for approved models;
- versioned analysis functions and test fixtures.

**Technical implementation**

Calculate:

- rule fire count/rate;
- alert and false-positive count/rate;
- threshold-distance distributions;
- values immediately above/below thresholds;
- source/channel/entity/segment/time concentration;
- repeat alerts;
- overlap with other rules;
- unique rule contribution;
- missing/default input patterns;
- historical versus recent window changes;
- confidence intervals and materiality;
- decay using approved rolling-window, EWMA, CUSUM or change-point methods;
- bounded threshold search points;
- alert-volume impact.

Every result receives:

- evidence ID;
- calculation version;
- input snapshot checksum;
- parameters;
- exact numeric result;
- uncertainty/limitations.

**Output**

Immutable `AnalysisEvidencePackage`.

**Transition**

- `LLM_ASSISTED` -> LLM Reasoning Agent.
- `DETERMINISTIC_ONLY` -> template/policy diagnosis.

**LLM**

No. This is where the trusted numbers are produced.

**Other AI/ML**

Optional statistical/change-detection models may be used, but they must be versioned, reproducible and separately approved. They are not generative AI.

---

## Step 14 - LLM-assisted reasoning and hypothesis generation

**Component**

`LLM Reasoning Agent`, `Model Gateway`, `Prompt Builder`, `Tool Broker` and `LLM Output Validator`.

**Input**

- safe structured rule JSON/AST;
- rule explanation vocabulary;
- attribution result;
- evidence package;
- institution policy and operating mode;
- masked aggregates or approved examples;
- optional RAG-retrieved documentation.

**Processing technique**

LLM structured reasoning plus controlled function/tool calling.

**Proposed framework**

- Spring Boot LLM worker;
- Spring AI for provider abstraction, structured output and tool calling;
- local or external LLM through `LLMProviderPort`;
- JSON Schema validated output;
- optional pgvector documentation index.

**Technical implementation**

1. Prompt Builder removes secrets and unnecessary customer identifiers.
2. It sends rule structure and evidence summaries with evidence IDs.
3. The LLM explains the likely cause and forms hypotheses.
4. If more evidence is required, it requests an allow-listed tool, for example:
   - `compare_time_windows`;
   - `get_threshold_distribution`;
   - `get_rule_overlap`;
   - `calculate_segment_metrics`;
   - `estimate_threshold_sensitivity`.
5. Tool Broker validates the arguments.
6. The deterministic Analytics Engine performs the calculation.
7. The exact tool result is returned to the LLM.
8. The LLM returns `ReasoningResult` as structured JSON.
9. Output Validator checks the schema, evidence IDs, policy and maximum reasoning/candidate attempts.
10. If the LLM times out, is unavailable, fails schema validation or returns unsupported reasoning, the Orchestrator uses the deterministic/template recommendation path when policy permits.

The LLM cannot:

- query the database;
- execute SQL;
- calculate authoritative metrics by itself;
- compile DRL;
- call a production-write API;
- modify a rule;
- invent a missing decision mapping.

**Output**

`ReasoningResult` containing:

- evidence-linked findings;
- probable root causes;
- candidate concepts where permitted;
- recommendation concepts;
- deterministic evidence-strength rating supplied by the Analytics/Data Quality components;
- limitations;
- requested follow-up analyses.

The system must not use a confidence score invented by the LLM. The LLM may describe uncertainty, but the official evidence-strength rating comes from data sufficiency, stability and reproducibility checks.

**Transition**

The Orchestrator validates the result and selects the institution's configured operating mode.

**LLM**

Yes. This is the main LLM step.

**Why use an LLM here**

It is useful for interpreting complex rule logic and connecting several different evidence patterns. It is not trusted for exact arithmetic or production decisions.

---

## Step 15A - Recommendation Only mode

**Component**

`Recommendation Proposal Builder`.

**Input**

Evidence package, deterministic/LLM reasoning result and `RECOMMENDATION_ONLY` policy.

**Processing technique**

Template-driven structured recommendation with optional LLM-generated explanation.

**Proposed framework**

- Spring Boot domain service;
- versioned recommendation JSON schema;
- Spring AI only for explanation text when enabled.

**Technical implementation**

1. Select an allowed recommendation type:
   - no change;
   - threshold review;
   - scenario/condition review;
   - data-quality review;
   - retirement review;
   - insufficient evidence.
2. Attach evidence IDs and limitations.
3. Set:
   - `candidate_generated = false`;
   - `backtest_performed = false`.
4. Do not create rule JSON or DRL.
5. Do not call the compiler or simulator.

**Output**

Non-executable `RecommendationDraft`.

**Transition**

Go directly to recommendation claim validation.

**LLM**

Optional for reasoning and clear English. It has no decision authority.

---

## Step 15B - Candidate + Test mode: generate a candidate

**Component**

`Candidate Generator`.

**Input**

Validated candidate concept, current formal rule JSON, permitted operations and bounds.

**Processing technique**

Deterministic JSON AST mutation and constrained candidate search.

**Proposed framework**

- Java/Spring Boot domain component;
- Jackson JSON tree/JSON Patch;
- JSON Schema validator;
- deterministic search policy.

**Technical implementation**

1. Resolve the exact condition node in `rule_version.logic`.
2. Apply only an allow-listed operation, such as changing a numeric threshold inside a configured bound.
3. Preserve the parent rule/version.
4. Generate an exact JSON diff.
5. Calculate the candidate checksum.
6. Store the candidate only in the Optimization Evidence Store.
7. Never insert it into production `rule_version`.

For numeric threshold optimization, deterministic grid/quantile search should generate a bounded candidate set. Candidates are ranked only after simulation in Step 19. The LLM may suggest the direction or scenario concept, but it should not freely choose unbounded production values.

**Output**

One or more `CandidateArtifact` objects with status `CANDIDATE_FOR_REVIEW`.

**Transition**

Schedule candidate validation and compilation.

**LLM**

Optional for the candidate idea. Formal candidate construction is not performed by the LLM.

---

## Step 16 - Validate and compile the candidate

**Component**

`Candidate Validator` plus `RuleCompilerPort`.

**Input**

Candidate JSON, current/historical rule bundle, compiler compatibility data and institution policy.

**Processing technique**

Static validation followed by deterministic JSON-to-DRL compilation.

**Confirmed framework**

The existing compiler mechanism and Drools/DRL execution are confirmed. The compiler's API/library boundary and exact versions are not confirmed.

**Proposed framework**

- isolated Java/Spring worker;
- existing compiler adapter;
- Drools/KIE libraries matching the production-compatible version;
- container-level CPU/memory/network restrictions.

**Technical implementation**

1. Validate schema, types, fields, operators and dependencies.
2. Validate mutation bounds and scenario constraints.
3. Call one selected `RuleCompilerPort` adapter:
   - shared library;
   - Admin Service API;
   - Rule Engine API;
   - controlled build-service adapter.
4. Generate DRL and checksum.
5. Compile in an isolated Drools/KIE container.
6. Run static, syntax, unit and safety checks.
7. Limit invalid-candidate retries.

**Output**

`CompiledCandidateArtifact` or structured compiler rejection.

**Transition**

Valid candidate -> baseline replay. Invalid candidate -> bounded alternative or no-candidate recommendation.

**LLM**

No. The LLM cannot decide that invalid DRL is acceptable.

---

## Step 17 - Validate historical replay parity and build the current-rule baseline

**Component**

`Isolated Backtest Runner`, `Replay Comparator` and `Current Baseline Runner`.

**Input**

- the historical rule version that was effective for each event;
- the current active rule version that a recommendation would change;
- frozen snapshot;
- event-time metrics;
- mappings, compiler and Drools compatibility data.

**Processing technique**

Deterministic historical replay and event-level comparison.

**Proposed framework**

- isolated Java/Drools Temporal worker;
- partitioned replay jobs;
- Parquet input and output;
- PostgreSQL replay manifest.

**Technical implementation**

The runner performs two separate executions:

### A. Historical parity replay

1. For each event, load the complete effective rule group, selected rule/configuration version and downstream decision/alert policy that were effective at that event time.
2. Recreate facts using the historical mappings and event-time metrics.
3. Feed events in event-time order.
4. Execute the historical rule group in Drools and apply the reconstructed decision/alert policy.
5. Capture matches, signals, scores and decisions.
6. Compare them with recorded `transaction_match`/`device_match` and result data.
7. Calculate parity by rule, event, signal and decision.
8. Record mismatch reasons.

This validates that the replay environment can reproduce the historical system.

### B. Current-rule baseline replay

1. Load the current active rule group and downstream decision/alert policy.
2. Execute that current context over the frozen eligible population.
3. Store the current rule's simulated event-level output.

This produces the correct baseline for comparing a candidate. If the historical and current versions are the same, the stored execution artifacts can be reused where technically valid.

**Output**

- `HistoricalReplayParityResult`;
- `CurrentBaselineSimulationResult`.

**Transition**

- parity above approved tolerance -> current baseline completion and candidate backtest;
- parity below tolerance -> `REPLAY_MISMATCH`, no candidate-performance claim.

**LLM**

No.

**Why this step is necessary**

It proves that the simulator represents historical production behavior and then creates the correct current-rule baseline. Without both parts, a candidate may look better because the simulator is different or because it was compared with an old rule version.

---

## Step 18 - Backtest the candidate

**Component**

`Isolated Backtest Runner`.

**Input**

Compiled candidate and the exact same frozen snapshot used for the current-rule baseline.

**Processing technique**

Deterministic Drools simulation.

**Proposed framework**

Same isolated Java/Drools worker used for baseline replay.

**Technical implementation**

1. Load the same current effective rule group used by the baseline.
2. Replace only the selected current rule with the candidate DRL.
3. Use identical facts, metric values, mappings, event order and policies.
4. Execute the complete rule-group and downstream decision/alert context.
5. Store event-level simulated match/decision/alert results.
6. Prevent all production database writes and rule activation.
7. Use separate development and holdout periods where data volume permits.

If the complete rule-group and downstream alert-decision context cannot be reconstructed, the backtest is limited to rule-match changes. In that situation, the recommendation must not claim alert or case impact.

**Output**

`CandidateSimulationResult`.

**Transition**

Schedule deterministic current-versus-candidate comparison.

**LLM**

No.

---

## Step 19 - Compare and rank candidates

**Component**

`Deterministic Result Comparator`.

**Input**

Current-rule baseline result, candidate result, final outcome mapping, policy and alert-volume limit.

**Processing technique**

Event-level set comparison, SQL/Python metrics and constrained multi-objective ranking.

**Proposed framework**

- Python Temporal worker;
- Polars/NumPy/SciPy;
- versioned ranking policy.

**Technical implementation**

Calculate:

- false-positive alert/case outcome differences;
- overall alert-volume difference;
- mature non-false-positive EFRM outcomes retained/lost under the configured internal outcome mapping;
- unique internally observed coverage retained/lost;
- delayed or missed internal outcomes;
- source/channel/segment effects;
- development and holdout performance;
- confidence and sample limitations;
- known policy violations.

Impact terminology depends on replay capability:

- `FULL_ALERT_PIPELINE_REPLAY`: alert-volume and downstream case-outcome projections may be reported as simulation estimates.
- `MATCH_ONLY_REPLAY`: report only rule-match differences; do not claim alerts or cases were prevented.

These are internal EFRM outcome measures. They must not be described as true fraud recall, fraud prevented or regulatory risk eliminated unless an independent approved truth source is added later.

Use deterministic ranking, such as Pareto filtering:

```text
prefer fewer false positives
subject to alert-volume and retained-useful-detection constraints
```

Do not invent pass/fail rules for optimization constraints that have not yet been supplied.

**Output**

`SimulationEvidencePackage` and deterministic candidate ranking.

**Transition**

Optional LLM interpretation, then recommendation composition.

**LLM**

No for calculations and ranking. Optional for explaining why the numbers matter.

---

## Step 20 - Compose and verify the recommendation

**Component**

`Recommendation Composer`, optional `LLM Explanation Writer`, and `Claim Validator`.

**Input**

Rule/lineage evidence, analysis evidence, reasoning result, candidate diff, simulation result and limitations.

**Processing technique**

Canonical structured JSON creation, evidence binding and optional natural-language generation.

**Proposed framework**

- Spring Boot;
- versioned JSON Schema;
- Spring AI for plain-English explanation;
- deterministic Claim Validator.

**Technical implementation**

1. Build canonical recommendation JSON.
2. Every factual claim references one or more evidence IDs.
3. Every numeric statement is matched to an exact stored value.
4. Verify the recommendation correctly states its mode.
5. Verify simulation claims exist only in Candidate + Test mode.
6. Add `HUMAN_REVIEW_REQUIRED`.
7. Reject or regenerate unsupported LLM wording.
8. Sign/hash the final artifact and store model/prompt/tool versions.
9. Store minimum provenance:
   - trigger/inbox ID;
   - case-analysis job ID and shared rule-analysis run ID;
   - case-decision identity/identities;
   - institution;
   - rule master/version record IDs and business versions;
   - historical/current rule and configuration checksums;
   - source/channel/fact scope;
   - policy and outcome-mapping versions;
   - snapshot ID/hash;
   - final attribution result;
   - optimization and reasoning modes;
   - replay parity and replay-capability level;
   - engine/compiler/model/prompt/tool versions;
   - evidence IDs and limitations;
   - stale/superseded status;
   - audit correlation ID.

The Claim Validator can prove that numbers and source references exist. It cannot prove that arbitrary causal language is true. Causal wording must therefore be presented as an evidence-supported hypothesis unless a separately approved causal method proves it.

**Output**

Immutable, versioned `RuleOptimizationRecommendation`.

**Transition**

Publish `RECOMMENDATION_READY`.

**LLM**

Optional for the human-readable explanation. It cannot change evidence or ranked results.

---

## Step 21 - Publish for human review and perform stale-state check

**Component**

`Recommendation API`, future UI adapter and `Stale State Validator`.

**Input**

Validated recommendation and artifact references.

**Processing technique**

REST/API presentation, institution-scoped authorization and checksum comparison.

**Proposed framework**

- Spring Boot REST/OpenAPI;
- Spring Security;
- PostgreSQL;
- Kafka notification/outbox.

**Technical implementation**

1. Compare current case decision, current rule checksum, binding, metric definitions and policy against the versions used in the job.
2. If changed, mark `STALE` or `SUPERSEDED`.
3. Otherwise expose the recommendation to an authorized reviewer.
4. Publish a notification event without exposing sensitive evidence.

**Output**

Reviewable recommendation or stale/superseded status.

**Transition**

Human review and existing EFRM governance.

**LLM**

No.

---

## Step 22 - Human governance and feedback

**Component**

Existing Rule Governance process plus `Optimization Feedback Store`.

**Input**

Recommendation, candidate/simulation evidence where available, reviewer decision and governance reference.

**Processing technique**

Human approval workflow and deterministic audit recording.

**Confirmed framework**

The Agent is not allowed to change, retire, delete or activate production rules. The exact existing governance API/UI integration is not currently confirmed.

**Proposed technical implementation**

1. Reviewer accepts, rejects, requests more analysis or chooses no action.
2. Existing governed EFRM tooling performs any approved rule action.
3. Store reviewer decision, reason and governance reference.
4. Measure recommendation acceptance and later post-change outcomes.
5. Do not automatically retrain the LLM or change prompts/rules.
6. If a case is reopened/corrected, supersede the old job and start a new job only if the new final outcome remains false positive.

**Output**

Audit record, governance outcome and closed/superseded job.

**Transition**

Workflow becomes `CLOSED`; future false-positive events can start new analysis normally.

**LLM**

No decision authority and no automatic learning.

---

## 5. Where the LLM is and is not used

| Activity | LLM used? | Actual technique |
|---|---:|---|
| Trigger handling | No | Spring backend, Kafka/REST, schema validation |
| Case outcome mapping | No | Config lookup |
| Case-alert-rule lineage | No | Approved SQL/service APIs |
| Rule attribution | No | Deterministic policy/counterfactual logic |
| Rule configuration retrieval | No | Service/API/database version resolution |
| Historical extraction | No | Parameterized SQL |
| Metric Custom SQL | No | Restricted SQL executor |
| Data quality | No | Deterministic validations |
| Exact metrics and decay | No | SQL, Python and statistics |
| Explain likely causes | Yes, optional | LLM reasoning over evidence |
| Ask for extra calculation | Yes, optional | LLM requests an allow-listed tool; Python/SQL executes it |
| Candidate idea | Yes, optional | LLM proposes a bounded concept |
| Candidate JSON | Not authoritative | Deterministic JSON AST generator |
| DRL compilation | No | Existing compiler and Drools/KIE |
| Baseline/candidate execution | No | Isolated Drools |
| Simulation numbers/ranking | No | Deterministic Python/SQL |
| Recommendation wording | Yes, optional | LLM explanation checked by Claim Validator |
| Production rule change | Never | Human governance only |

## 6. What to tell management in one sentence

> The proposed reference implementation is a deterministic Spring/Temporal workflow that uses governed PostgreSQL data and Python analytics to establish facts, optionally uses an LLM to reason over those facts, uses the existing compiler and isolated Drools runtime to test candidates, and always sends an evidence-linked recommendation to a human instead of modifying production rules.

## 7. Framework decisions still requiring confirmation

Before implementation starts, the owning teams must confirm:

1. Existing Case/Admin Service API and application framework.
2. Exact Java, Spring and Drools versions used by the Rule Engine.
3. How the JSON-to-DRL compiler is exposed.
4. Whether Kafka already exists or another enterprise broker must be used.
5. Whether Temporal can be deployed or a PostgreSQL state-machine fallback is required.
6. Available read replica/analytical storage and object storage.
7. Approved secrets manager, OAuth/mTLS and observability platforms.
8. Approved local/external LLM providers and data-egress rules.
9. Final optimization constraints beyond the currently known alert-volume limit.
