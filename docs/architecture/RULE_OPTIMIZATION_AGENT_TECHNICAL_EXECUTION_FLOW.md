# Rule Optimization Agent - Technical Execution Flow

## 1. Control model

The top-level controller is a deterministic `Optimization Orchestrator`. It guarantees that every mandatory security, lineage, validation, and audit step runs in the correct order.

The `LLM Reasoning Agent` operates inside a bounded reasoning stage. It may inspect approved evidence, request additional approved calculations, form hypotheses, suggest changes, and explain results. It cannot bypass the Orchestrator, query the database directly, compile rules, run arbitrary code, or change production configuration.

## 2. Main components

| Component | Responsibility |
|---|---|
| Case Service | Finalizes the case and records the final decision |
| Transactional Outbox Publisher / API Client / Poller | Delivers the case-finalized trigger |
| Trigger Gateway | Authenticates, deduplicates, and normalizes triggers |
| Outcome Resolver | Maps the institution-specific decision to `FALSE_POSITIVE` or another outcome class |
| Optimization Orchestrator | Owns the job state machine and starts each permitted stage |
| Evidence Store | Stores immutable job, snapshot, metrics, artifacts, evidence, and audit records |
| Case Lineage Resolver | Traces case to alerts, results, matches, and rule references |
| Rule Attribution Engine | Identifies primary/supporting/coincidental rule contributions |
| Effective Configuration Resolver | Retrieves the exact historical rule/group/policy/metric configuration |
| Historical Snapshot Builder | Builds the complete relevant historical event population |
| Metric SQL Executor | Reconstructs approved Custom-SQL metrics as of each event time |
| Data Quality Gate | Tests lineage, completeness, sufficiency, and replay readiness |
| Analytics Toolbox | Runs exact Python/SQL statistics and cohort calculations |
| LLM Reasoning Agent | Interprets evidence, requests approved follow-up analyses, forms hypotheses, and explains recommendations |
| Candidate Generator | Converts an approved hypothesis into bounded formal rule JSON |
| Rule Compiler Adapter | Calls the existing JSON-to-DRL compiler |
| Isolated Backtest Runner | Replays current/candidate rules without production write access |
| Result Comparator | Calculates authoritative current-versus-candidate differences |
| Recommendation Composer and Validator | Produces and validates the evidence-linked output |
| Recommendation API / Future UI | Presents the recommendation and collects human action |
| Existing Rule Governance | Performs any approved production change |

## 3. Job state machine

```text
TRIGGER_RECEIVED
  -> OUTCOME_VALIDATED
  -> JOB_CREATED
  -> LINEAGE_RESOLVED
  -> RULES_ATTRIBUTED
  -> CONFIG_RESOLVED
  -> SNAPSHOT_READY
  -> DATA_VALIDATED
  -> EVIDENCE_CALCULATED
  -> LLM_REASONING_COMPLETED (or deterministic reasoning)
  -> MODE_BRANCH
      -> CANDIDATE_VALIDATED -> BASELINE_REPLAYED -> CANDIDATE_TESTED
      -> RECOMMENDATION_ONLY
  -> RECOMMENDATION_VALIDATED
  -> HUMAN_REVIEW
  -> CLOSED
```

Terminal exception states:

```text
IGNORED_NOT_FALSE_POSITIVE
INSUFFICIENT_EVIDENCE
LINEAGE_FAILED
CONFIGURATION_AMBIGUITY
METRIC_REPRODUCTION_FAILED
REPLAY_MISMATCH
POLICY_VIOLATION
FAILED
```

## 4. Step-by-step execution

### Step 0 - Resolve tenant capability configuration

Component: `Optimization Orchestrator` and `Policy Resolver`

Input:

- institution ID;
- effective date;
- authenticated caller/service identity.

Processing:

- load `optimization_mode`: `CANDIDATE_AND_TEST` or `RECOMMENDATION_ONLY`;
- load `reasoning_mode`: `LLM_ASSISTED` or `DETERMINISTIC_ONLY`;
- load allowed sources/channels, historical window, alert-volume limit, LLM provider policy, and data-access policy;
- verify required capabilities are enabled.

Output:

- immutable policy snapshot and hash.

Transition:

- policy is attached to all later tasks;
- missing/invalid policy stops the job.

LLM: No.

### Step 1 - Finalize the case

Component: `Case Service`

Input:

- investigator decision;
- approval decision where required;
- case ID and institution.

Processing:

- validate the final case-decision workflow;
- make the final case decision authoritative;
- update `case_master`;
- close unresolved case-alert mappings as required by existing EFRM behavior;
- write audit and case events;
- in event mode, insert `CASE_FINALIZED` into the transactional outbox in the same transaction.

Output:

- finalized case record;
- case audit/event records;
- optional pending outbox event.

Transition:

- outbox publisher emits the event, Case Service calls the API, or reconciliation poller discovers the finalized row.

LLM: No.

### Step 2 - Deliver the trigger

Components:

- `Outbox Publisher + Event Broker`, or
- `Case Service API Client`, or
- `Reconciliation Poller`.

Input:

- case ID;
- institution ID;
- decision code/version;
- finalized timestamp;
- event/idempotency/correlation ID.

Processing:

- event: publish/consume asynchronously;
- API: send authenticated HTTP request and receive `202 Accepted`;
- polling: query after the durable `(decision_finalized_at, case_id)` checkpoint.

Output:

- normalized `CaseFinalizedTrigger`.

Transition:

- send trigger to `Trigger Gateway`.

LLM: No.

### Step 3 - Authenticate and deduplicate

Component: `Trigger Gateway`

Input:

- normalized trigger;
- service identity/signature/token.

Processing:

- authenticate source;
- authorize institution;
- validate schema and required identifiers;
- atomically insert the event into a transactional inbox/processed-event ledger before acknowledging delivery;
- check idempotency by event ID and `(institution_id, case_id, decision_version)`;
- reject stale or duplicate triggers;
- record receipt and correlation ID.

If the event arrives before the read API/replica contains the committed case version, classify this as replica lag and retry with backoff rather than failing permanently.

Output:

- accepted trigger or duplicate/rejection result.

Transition:

- accepted trigger is sent to `Outcome Resolver`.

LLM: No.

### Step 4 - Confirm false-positive eligibility

Component: `Outcome Resolver`

Input:

- case ID;
- institution;
- final decision code and timestamp.

Processing:

- read the final case from Case Service/read API;
- confirm it is finalized and not superseded;
- load the effective institution outcome mapping;
- map the decision code to a canonical outcome class;
- apply final-case-decision precedence over alert-level decisions.

Output:

- `FALSE_POSITIVE` or another canonical outcome class;
- mapping version and evidence reference.

Transition:

- non-false-positive: mark `IGNORED_NOT_FALSE_POSITIVE`;
- false-positive: request the Orchestrator to create a job.

LLM: No.

### Step 5 - Create the optimization job

Component: `Optimization Orchestrator`

Input:

- accepted false-positive trigger;
- policy snapshot.

Processing:

- generate job ID;
- enforce a unique idempotency key;
- determine whether this case joins an existing open rule-analysis batch;
- store job scope, trigger evidence, state, retry counters, and audit metadata;
- enqueue the lineage-resolution task.

Output:

- durable `optimization_job`;
- `ResolveCaseLineage` task.

Transition:

- worker queue/API invokes `Case Lineage Resolver`.

LLM: No.

### Step 6 - Trace case to rules

Component: `Case Lineage Resolver`

Input:

- case ID;
- institution ID;
- finalization version.

Processing:

- read `case_master`;
- read `case_alert_mapping`;
- for transaction alerts, follow `transaction_alert -> transaction_result -> transaction_match`;
- for device alerts, follow `device_alert -> device_result -> device_match`;
- collect rule code, rule/group version values, signal, severity, weight, score, and timestamps;
- preserve source-table identity;
- flag missing/deleted/unresolvable references.

Output:

- immutable `CaseRuleLineage` object.

Transition:

- persist lineage evidence;
- emit `LINEAGE_RESOLVED`;
- invoke `Rule Attribution Engine`.

LLM: No.

### Step 7 - Attribute rule contribution

Component: `Rule Attribution Engine`

Input:

- case/alert/result/match lineage;
- decision policy and alert-generation policy.

Processing:

- identify which rules fired;
- determine which signal(s) crossed the alert/decision condition;
- assess whether another rule independently caused the alert;
- classify each match as `PRIMARY_CONTRIBUTOR`, `SUPPORTING_CONTRIBUTOR`, `COINCIDENTAL_MATCH`, or `UNRESOLVED_ATTRIBUTION`;
- keep unresolved cases for manual review.

Output:

- selected rule-analysis targets;
- attribution evidence and limitations.

Transition:

- no attributable rule: produce `RULE_REVIEW_RECOMMENDED`/lineage limitation;
- selected rules: create one sub-job per institution/rule version/scope or attach to an existing batch;
- invoke `Effective Configuration Resolver`.

LLM: No for the authoritative classification. An LLM may later explain it.

### Step 8 - Resolve exact historical configuration

Component: `Effective Configuration Resolver`

Input:

- institution;
- rule code/version references;
- source/channel/fact;
- event/as-of time.

Processing:

- resolve `rule_master` and exact `rule_version`;
- retrieve structured logic, DRL, checksum, required data, and DRL context;
- resolve group version/map/source binding;
- retrieve decision policy and upgrades;
- retrieve source/engine attribute mappings;
- retrieve metric dependencies and Metric Definition Custom SQL;
- handle typed business-version versus record-ID fields;
- use preserved historical snapshots when a rule was deleted;
- hash the complete bundle.

Output:

- immutable `EffectiveRuleBundle`.

Transition:

- ambiguous/missing configuration stops the rule sub-job;
- valid bundle invokes `Historical Snapshot Builder`.

LLM: No.

### Step 9 - Build the full historical population

Component: `Historical Snapshot Builder`

Input:

- effective rule bundle;
- institution/source/channel;
- configured historical window;
- approved query-template IDs.

Processing:

- query the read replica/analytical store using parameterized, reviewed SQL;
- retrieve all eligible events, not only false-positive alerts;
- join request/master/result/match/alert/case outcome data;
- include events where the selected rule did not fire;
- remove or flag test/duplicate/late/invalid records;
- partition and content-hash the snapshot.

Output:

- immutable `RuleEvaluationSnapshot`;
- extraction manifest and row-quality counts.

Transition:

- invoke `Metric SQL Executor` for required derived metrics;
- then invoke `Data Quality Gate`.

LLM: No.

### Step 10 - Reconstruct event-time metrics

Component: `Metric SQL Executor`

Input:

- metric definitions and SQL checksums;
- event/entity/institution/time parameters;
- snapshot partitions.

Processing:

- validate read-only Custom SQL;
- apply institution and point-in-time parameters;
- enforce schema allow-list, timeout, row/resource limits, and audit;
- compute metrics as they would have existed at each event time;
- store metric value and complete lineage.

Output:

- event-time metric dataset;
- failures/missingness report.

Transition:

- attach metrics to snapshot;
- invoke `Data Quality Gate`.

LLM: No.

### Step 11 - Validate data and evidence

Component: `Data Quality Gate`

Input:

- rule bundle;
- historical snapshot;
- event-time metrics;
- attribution evidence;
- configured sufficiency rules.

Processing:

- validate tenant consistency and joins;
- verify required rule inputs/metrics;
- check historical version lineage;
- verify snapshot completeness and test-data separation;
- count usable events, false-positive cases, other mature outcomes, and time buckets;
- decide whether analysis, candidate creation, and replay have enough evidence.

Output:

- `DataReadinessDecision`;
- allowed next capabilities and limitations.

Transition:

- failure: create an insufficient-evidence recommendation;
- success: enqueue deterministic analytics tasks.

LLM: No.

### Step 12 - Calculate authoritative evidence

Component: `Analytics Toolbox`

Input:

- validated snapshot;
- triggering false-positive cases;
- rule definition;
- policy and alert-volume limits.

Processing:

- calculate fire/alert/case rates;
- calculate false-positive counts/rates under the institution outcome mapping;
- examine values around thresholds;
- analyze channel/entity/segment/time concentration;
- calculate repeat alerts and rule overlap;
- measure unique detection contribution;
- identify missing/default-input and technical issues;
- produce cohorts and exact evidence, not conclusions.

Output:

- immutable `AnalysisEvidencePackage` containing metrics, cohorts, distributions, evidence IDs, and limitations.

Transition:

- if `LLM_ASSISTED`, call `LLM Reasoning Agent`;
- if `DETERMINISTIC_ONLY`, call a rules/templates-based diagnosis engine.

LLM: No.

### Step 13 - Reason about the problem

Component: `LLM Reasoning Agent` (optional) or deterministic diagnosis engine.

Input:

- safe structured rule representation;
- calculated evidence package;
- attribution evidence;
- allowed tools/actions;
- client operating mode;
- masked/aggregated data only;
- optional approved RAG documentation.

Processing in LLM-assisted mode:

- explain what the rule does;
- form one or more evidence-linked hypotheses for false positives;
- call approved tools for additional calculations when needed;
- rank possible interventions;
- return structured findings, confidence, evidence IDs, requested candidate concepts, and limitations.

The LLM cannot query SQL, see credentials, change metrics, call production-write tools, or claim unsupported facts.

Output:

- validated `ReasoningResult`.

Transition:

- Orchestrator validates tool/evidence references;
- branch on `optimization_mode`.

LLM: Yes only in `LLM_ASSISTED`.

### Step 14A - Recommendation Only branch

Components:

- `Recommendation Composer`;
- optional `LLM Reasoning Agent`;
- `Recommendation Validator`.

Input:

- evidence package;
- reasoning result;
- `optimization_mode = RECOMMENDATION_ONLY`.

Processing:

- do not create executable rule JSON/DRL;
- do not call compiler;
- do not call candidate backtest;
- describe the issue and suggested human action;
- distinguish measured evidence from hypothesis;
- state that no executable simulation was performed;
- validate every number and claim against evidence IDs.

Output:

- recommendation status such as `RULE_REVIEW_RECOMMENDED`, `NO_CHANGE_RECOMMENDED`, `RETIREMENT_REVIEW_RECOMMENDED`, or `INSUFFICIENT_EVIDENCE`.

Transition:

- persist recommendation;
- publish `RECOMMENDATION_READY`;
- notify Recommendation API/UI.

LLM: Optional for reasoning/explanation.

### Step 14B - Candidate + Test: create the candidate

Component: `Candidate Generator`

Input:

- validated reasoning result/candidate concept;
- formal current rule JSON;
- allowed fields/operators/bounds;
- policy snapshot.

Processing:

- convert the concept into bounded structured rule JSON;
- preserve parent rule/version;
- calculate a structured diff;
- store it only in the Optimization Evidence Store/job artifact area;
- never insert it into production `rule_version`.

Output:

- `CandidateArtifact` with `CANDIDATE_FOR_REVIEW`.

Transition:

- invoke `Candidate Validator` and `Rule Compiler Adapter`.

LLM: The concept may come from the LLM; artifact construction is deterministic.

### Step 15 - Validate and compile candidate

Components:

- `Candidate Validator`;
- `Rule Compiler Adapter`;
- existing JSON-to-DRL compiler.

Input:

- candidate JSON;
- current rule bundle;
- compiler version;
- policy constraints.

Processing:

- validate JSON schema, types, fields, operators, required data, and metrics;
- apply complexity and policy limits;
- call existing compiler;
- compile DRL in isolation;
- generate checksum;
- run syntax/unit/safety tests.

Output:

- valid compiled candidate or rejection details.

Transition:

- rejection returns to LLM/diagnosis for a bounded alternative or produces no-change/review output;
- success invokes baseline replay.

LLM: No.

### Step 16 - Validate baseline replay parity

Component: `Isolated Backtest Runner`

Input:

- original historical rule artifact;
- validated historical snapshot;
- compiler/Drools/mapping/metric versions.

Processing:

- execute the current rule over historical events in event order;
- produce simulated matches/decisions;
- compare with stored historical matches/decisions;
- calculate parity and mismatch reasons.

Output:

- `ReplayParityResult`.

Transition:

- below tolerance: stop with `REPLAY_MISMATCH`;
- acceptable: enqueue candidate backtest over the same snapshot.

LLM: No.

### Step 17 - Backtest the candidate

Component: `Isolated Backtest Runner`

Input:

- compiled candidate;
- same historical snapshot used for the baseline;
- fixed policies, metrics, compiler, and runtime.

Processing:

- execute the candidate;
- store event-level simulated matches, decisions, and alert flags;
- enforce resource limits and no production writes.

Candidate development and final validation should use different time periods where data volume permits. Candidate ideas are selected on the development period and evaluated once on the untouched holdout period to reduce overfitting.

Output:

- immutable `CandidateSimulationResult`.

Transition:

- invoke `Result Comparator`.

LLM: No.

### Step 18 - Compare current and candidate

Component: `Result Comparator`

Input:

- baseline/current simulation;
- candidate simulation;
- final case outcome mapping;
- alert-volume policy.

Processing:

- calculate alerts and false positives prevented;
- calculate alert-volume change;
- calculate internally useful detections retained/lost;
- calculate unique coverage, delayed/missed detection, channel/segment effects, and uncertainty;
- evaluate known constraints;
- do not invent pass/fail for constraints that remain undefined.

Output:

- authoritative `SimulationEvidencePackage`.

Transition:

- call LLM Reasoning Agent to interpret results when enabled;
- then invoke Recommendation Composer.

LLM: No for calculations; optional after calculation for interpretation.

### Step 19 - Compose and validate recommendation

Components:

- optional `LLM Reasoning Agent`;
- `Recommendation Composer`;
- `Recommendation Validator`.

Input:

- rule and attribution evidence;
- analysis evidence;
- reasoning result;
- candidate diff and simulation evidence when available;
- required disclaimers and limitations.

Processing:

- LLM writes a plain-language explanation when enabled;
- Composer produces canonical structured JSON;
- Validator verifies every number, candidate/backtest claim, evidence ID, operating-mode statement, and human-review requirement;
- reject or regenerate unsupported wording.

Output:

- immutable, versioned recommendation.

Transition:

- store recommendation and audit;
- publish `RECOMMENDATION_READY`;
- expose through Recommendation API/future UI.

LLM: Optional and bounded.

### Step 20 - Human review and governance handoff

Components:

- `Recommendation API / Future UI`;
- human reviewer;
- existing EFRM rule-governance system.

Input:

- recommendation, evidence, limitations, candidate/simulation artifacts if mode permits.

Processing:

- reviewer accepts, rejects, asks for more analysis, or marks no action;
- immediately before presentation/acceptance, compare the current case-decision version, rule checksum, binding, metric definitions, and policy version with the versions used by the job;
- mark the recommendation `STALE` or `SUPERSEDED` and require re-analysis if authoritative inputs changed;
- any rule change/retirement is created and approved through existing governance;
- Optimization Agent never activates or modifies a production rule.

Output:

- human decision and audit record;
- optional governance reference.

Transition:

- close job or start a new bounded analysis requested by the reviewer.

LLM: No decision authority.

### Step 21 - Capture feedback

Component: `Optimization Orchestrator / Feedback Store`

Input:

- reviewer decision;
- rejection reason;
- governance outcome;
- later observed false-positive triggers.

Processing:

- store feedback for quality monitoring;
- measure acceptance and post-change outcomes;
- do not automatically retrain or change prompts/rules without governance.

Output:

- feedback/audit record and future evaluation data.

Transition:

- job becomes `CLOSED`;
- later false-positive events may start new jobs normally.

LLM: No automatic learning or modification.

## 5. Case correction and failure handling

If a case is reopened or its final decision is corrected:

1. Case Service emits a new versioned event.
2. Trigger Gateway records it in the inbox.
3. Orchestrator cancels or supersedes jobs tied to the old decision version.
4. Existing recommendations become `SUPERSEDED`.
5. A new analysis begins only if the corrected final outcome is still false positive.

For every asynchronous stage:

```text
worker receives command
  -> checks stage idempotency key
  -> executes or resumes from checkpoint
  -> stores immutable output
  -> atomically updates job state and writes next-stage outbox command
  -> acknowledges current message
```

Failure classes:

| Class | Handling |
|---|---|
| Transient upstream/replica/network failure | Retry with backoff |
| Permanent validation/policy failure | Stop with explicit terminal state |
| Worker timeout | Resume from checkpoint or retry bounded times |
| Repeated technical failure | Dead-letter/manual operations review |
| User cancellation | Stop new stages and safely terminate workers |
| LLM failure | Fall back to deterministic/template recommendation when policy permits |
| Excessive LLM/candidate loop | Stop at configured attempt limit |
