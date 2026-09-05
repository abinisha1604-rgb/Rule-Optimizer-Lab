# FRM Product DB Flow Reference

**Document purpose:** Give engineering, product, implementation, and agentic-automation teams a clear operating map of how the FRM product works through its services and database tables.

**Scope:** Admin Service, Admin Portal, Screening Service, AMC Service, Rule Engine Service, ML Engine Service, shared PostgreSQL `efrm` schema, workers, runtime state, configuration state, audit/history state, and cross-service flows.

**Important boundary:** This is a product-context and DB-lineage document. It explains how the product works and why the tables exist. It is not a replacement for API documentation, migration review, or client-specific SOP sign-off.

---

## 1. Product Flow At A Glance

The platform is designed around a controlled path from source activity to investigation, risk scoring, and audit.

```text
Client/source system event
  -> Screening / AMC / Rule Engine / ML evaluation
  -> result, match, alert, and/or inference records
  -> RAMS risk event ingestion where enabled
  -> entity risk aggregate/profile/history update
  -> case creation or alert linking where configured
  -> investigator review and alert-level decisions
  -> final case outcome decision
  -> configured case actions and audit trail
  -> evidence, timeline, compliance readiness, and reporting
```

The database is not only a storage layer. It is also the product's policy and governance backbone. Configuration tables decide which services are enabled, how events are scored, how cases are prioritized, which decisions are available, which actions are initiated, how rules are loaded, how screening is scored, and how ML models are governed.

---

## 2. Service Ownership Map

| Service | Main responsibility | Primary DB responsibility |
|---|---|---|
| Admin Service | Case management, RAMS risk rating, Link Analysis, user/security administration, configuration APIs, audit/evidence, review/read models | Owns case, risk, link-analysis, security/admin, audit/evidence tables; reads source result/alert tables |
| Admin Portal | User interface for analysts, admins, compliance users, supervisors, and operations | Does not own DB state; displays and submits through service APIs |
| Screening Service | Watchlist/list-source ingestion, fuzzy/entity screening, screening results, matches and alerts | Owns screening runtime/config/list tables |
| AMC Service | Adverse media request, search/extraction/analysis, adverse scoring, results, matches, alerts | Owns adverse media request/result/match/alert and adverse policy tables |
| Rule Engine Service | Transaction/device rule execution, Drools rules, metrics, source mappings, decisions, transaction/device alerts | Owns rule config, transaction/device request/result/match/alert, metric tables |
| ML Engine Service | ML feature configuration, model registry, training, inference, feedback, explainability | Owns ML feature/model/job/inference/feedback tables |

Many tables are visible in more than one repository because services share the `efrm` schema. Ownership should be understood by **runtime responsibility**, not merely by ORM presence.

---

## 3. Table State Types

| Type | Meaning | Examples |
|---|---|---|
| Configuration/governance | User or implementation-controlled policy that changes runtime behavior | `case_decision_master`, `risk_rating_weight_config`, `screening_field_config`, `rule_group_source_binding` |
| Runtime input/result | Source requests, engine results, alerts, matches, and event records | `transaction_request`, `screening_result`, `adverse_match`, `device_alert` |
| Derived/aggregate | Calculated state derived from runtime events | `entity_risk_profile`, `entity_risk_aggregate`, `aggregated_metric`, `entity_graph_clusters` |
| Audit/history | Immutable or append-oriented trace of what happened | `audit_trail`, `case_events`, `entity_risk_history`, `security_audit_log` |
| Worker/queue state | Background processing, retry, batch, queue, checkpoint records | `case_action_execution_queue`, `risk_recalculation_job`, `ruleengine_bulk_job`, `entity_graph_refresh_checkpoint` |
| Security/session state | Login, token, session, credential and password lifecycle | `user_credential`, `refresh_token`, `login_attempt`, `account_lockout` |
| Legacy/review | Older or compatibility tables that should be handled carefully | `inst_rule_group`, `rule_definition`, `rule_history`, `rule_test`, `rule_group` |

---

## 4. Cross-Service Database Principles

1. **Institution scoping is mandatory.** Most business and config records are scoped by `institution_id`. Dedicated client DBs may still use one institution, but shared/UAT DBs must never rely on that assumption.
2. **Alert identity is source-aware.** A case alert is identified by `alert_id`, `alert_type`, and `alert_source_table`. Screening and adverse alerts can share the same numeric ID.
3. **Human decision is separate from machine result.** Original source results remain unchanged. Alert-level and case-level decisions add human investigation context.
4. **Risk rating is event-driven.** Writing `risk_event_log` is not enough unless the processing flow updates aggregate/profile/history records.
5. **Configuration must be versioned or parent-scoped where available.** Case, screening, risk, rule, and ML configs are designed as master/child aggregates.
6. **Audit and timeline answer different questions.** `case_events` explain the business chronology of a case. `audit_trail` explains technical user/system actions and values changed.
7. **Workers are part of the product flow.** Starting APIs alone does not process all queues. Case actions, link-analysis refresh, ML jobs, and bulk jobs need their respective worker paths.

---

## 5. End-To-End Product Flow

### 5.1 Source Event Intake

Transaction and device events usually enter the Rule Engine. Screening events enter the Screening Service. Adverse-media checks enter the AMC Service directly or through screening-triggered chaining. ML inference can be called directly or through configured operational flows.

Key intake tables:

| Table | Why it exists |
|---|---|
| `transaction_request` | Stores raw transaction request payload, source system context, request status and timing |
| `transaction_master` | Stores canonical transaction identity and important transaction/entity/card/customer fields; client source transaction identity is represented by `source_txn_id` |
| `device_request` | Stores raw device request payload and request context |
| `device_master` | Stores canonical device/session/network identity; current idempotency uses `request_id` |
| `screening_request` | Stores submitted screening request payload and normalized screening context |
| `adverse_request` | Stores adverse-media request context, entity details, processing status and timestamps |
| `ml_inference_result` | Stores ML inference request/result details, model version, score, decision and timing |

### 5.2 Detection And Scoring

Each service evaluates the request using its own policy/configuration:

| Service | Evaluation logic | Core config tables |
|---|---|---|
| Rule Engine | Loads active rule group, resolves metrics, executes DRL, evaluates decision policy | `rule_master`, `rule_version`, `rule_group_master`, `rule_group_version`, `rule_group_version_map`, `rule_group_source_binding`, `metric_definition`, `rule_metric_dependency`, `rule_decision_policy`, `rule_decision_upgrade` |
| Screening | Retrieves list candidates, applies fuzzy/identifier/configured scoring, risk band and decision thresholds | `screening_config_master`, `screening_field_config`, `screening_group_config`, `screening_decision_threshold`, `screening_risk_band`, `screening_source_config`, `screening_identifier_config` |
| AMC | Searches/extracts/analyzes adverse media and applies configured category/severity/source/recency scoring | `adverse_config_master`, `adverse_integration_config`, `adverse_category_weight`, `adverse_severity_score`, `adverse_source_weight`, `adverse_country_risk`, `adverse_recency_factor`, `adverse_risk_band` |
| ML Engine | Resolves feature set/model version, transforms features, runs model and maps anomaly score | `ml_feature_set`, `ml_feature_set_version`, `ml_feature_definition`, `ml_model_registry`, `ml_model_version`, `ml_score_blending_policy` |

### 5.3 Results, Matches And Alerts

Evaluation outputs are stored as result, match and alert rows.

| Result family | Result table | Match table | Alert table | Purpose |
|---|---|---|---|---|
| Transaction | `transaction_result` | `transaction_match` | `transaction_alert` | Stores final transaction score/decision, individual rule hits/signals, and reviewable transaction alert |
| Device | `device_result` | `device_match` | `device_alert` | Stores device score/decision, device rule hits, and reviewable device alert |
| Screening | `screening_result` | `screening_match` | `screening_alert` | Stores watchlist screening decision, matched list entities/evidence, and reviewable screening alert |
| Adverse media | `adverse_result` | `adverse_match` | `adverse_alert` | Stores adverse-media decision, article/media evidence, and reviewable adverse alert |
| ML | `ml_inference_result` | local SHAP/explainability rows | usually consumed downstream | Stores model inference score, risk band, decision and explanation |

### 5.4 Risk Rating

Eligible source results are sent to RAMS as risk events. The risk engine maps events to domains, applies decision impacts and decay/override rules, updates aggregate scores, and persists final profile/history.

```text
source result or case decision
  -> risk_event_log
  -> risk_rating_* config lookup
  -> entity_risk_aggregate
  -> entity_risk_profile
  -> entity_risk_history and factor breakdown
```

### 5.5 Case Creation And Investigation

Alerts can create a new case or be linked to an existing open case for the same institution/entity context. The case aggregates multiple alert types.

```text
screening/adverse/transaction/device alert
  -> case scoring config
  -> existing open case lookup
  -> case_master
  -> case_alert_mapping
  -> assignment/SLA
  -> investigation tabs
  -> alert-level decisions
  -> final case decision
  -> action queue/log
  -> closed case and source alert closure
```

### 5.6 Audit, Evidence And Timeline

Business chronology and technical audit are intentionally separate:

| Need | Table | Explanation |
|---|---|---|
| Business case story | `case_events` | Case created, assigned, alert linked, decision submitted, evidence uploaded, action initiated, case closed |
| Technical audit | `audit_trail` | Who changed what table/record, old/new values, IP, actor, module, timestamp |
| Evidence | `case_evidence` | Files, metadata, hash, versions, custody and ownership |
| Action dispatch audit | `case_action_execution_queue`, `case_action_execution_log` | What action was queued/sent/failed/manual-resolved and with which endpoint snapshot |

---

## 6. Admin Service DB Flow

### 6.1 Platform, User, Profile And Security Administration

The Admin Service is the authority for login, profile access, capabilities, menus, password/security policy, service clients, tokens, sessions and audit.

Flow:

```text
user login
  -> user_master / user_credential validation
  -> profile_master
  -> profile_capability / menu access
  -> refresh_token and user_session
  -> audit/security audit
  -> frontend receives permitted menus and capabilities
```

Tables:

| Table | Type | What it stores and why it exists |
|---|---|---|
| `institution` | Configuration | Tenant/client identity, currency/country defaults, status and tenant metadata |
| `institution_type` | Configuration/review | Institution classification catalog; currently more bootstrap-oriented than runtime-critical |
| `product_master` | Configuration | Product catalog root used by menu/profile access |
| `menu_master` | Configuration | Menu/card hierarchy and route/action metadata used for profile menu assignment |
| `profile_master` | Configuration | User role/profile definition, status, profile metadata, menu/API access and approval fields |
| `security_capability` | Configuration | Atomic permission/capability catalog for fine-grained authorization |
| `profile_capability` | Configuration | Grants capabilities to profiles |
| `capability_endpoint_map` | Configuration/security | Maps capabilities to protected backend routes/methods |
| `user_master` | Identity config/state | User account, profile, institution, status and lifecycle fields |
| `user_credential` | Security state | Password hash/credential metadata separated from user profile data |
| `user_password_history` | Security state | Historical password hashes for reuse prevention |
| `password_policy_rule` | Configuration | Password complexity, expiry, lockout and history policy |
| `common_password_list` | Security config | Hash/list of prohibited common passwords |
| `security_check` | Configuration | Profile security-control bundle such as IP/device/session/captcha/rate limits |
| `service_client` | Security config | Machine-to-machine client identity, scopes and token policy |
| `service_token_jti` | Security state | Service-token replay/revocation tracking |
| `refresh_token` | Security state | Browser refresh token lifecycle and revocation |
| `user_session` | Security state | Active/expired user sessions and device/session context |
| `login_attempt` | Security audit/state | Login attempts for monitoring and lockout logic |
| `account_lockout` | Security state | Active/historical account lockouts |
| `password_reset_token` | Security state | Password reset token lifecycle |
| `password_expiry_notice` | Security state | Password-expiry notification tracking |
| `security_notification` | Security state | Security notification records |
| `security_audit_log` | Audit | Security-specific append-oriented audit trail |
| `audit_trail` | Audit | General technical audit for mutable operations across modules |

### 6.2 Shared Catalogs And Reference Data

Shared catalogs support dropdowns, validation, source metadata, rule builder choices and cross-module controlled values.

| Table | Type | What it stores and why it exists |
|---|---|---|
| `reference_data` | Configuration/catalog | Reusable code/value catalog used by case, screening, rule, assignment and general UI options |
| `operator_value` | Configuration/catalog | Rule-builder operators and compatible data types |
| `notification_template` | Configuration | Message templates used by notifications, assignment, SLA and security events |
| `notification_queue` | Worker/state | Notification delivery queue/status |
| `source_system_master` | Configuration | Source system/fact/channel/institution metadata consumed by rule and payload mapping |
| `source_attribute_def` | Configuration | Source payload field definitions and mapping metadata |
| `engine_attribute_def` | Configuration | Canonical engine attributes exposed to rule builder/execution |
| `engine_flink_map` | Configuration | Maps engine/source attributes to stream/Flink/event fields |
| `facts_definition` | Configuration | Valid fact/context types for rule execution |
| `efrm_service_config` | Configuration | Per-institution service enablement, execution mode and RAMS domain mapping |

### 6.3 Case Management

Case Management is the investigation layer. It receives alerts from screening, adverse, transaction or device flows. It creates or merges a case, maps source alerts, computes priority, assigns owner, tracks SLA, records evidence, supports alert-level decisions and final case-level outcomes/actions.

Flow:

```text
source alert
  -> case scoring config
  -> case_master created or existing open case selected
  -> case_alert_mapping row per source alert
  -> case_assignment and case_sla_tracker
  -> investigator reviews case
  -> alert-level decisions close individual mappings only
  -> final case close validates case_decision_master
  -> mapped actions from case_decision_action_mapping
  -> case_action_execution_queue/log
  -> source alert rows closed
  -> case_events and audit_trail
```

Configuration tables:

| Table | Type | What it configures |
|---|---|---|
| `case_config_master` | Configuration root | Version/root for case scoring and auto-assignment policy |
| `case_priority_master` | Configuration | Score ranges mapped to case priority codes |
| `alert_category_master` | Configuration | Alert-category scoring weights |
| `alert_count_boost_config` | Configuration | Score boosts based on number of alerts in a case/entity context |
| `category_correlation_config` | Configuration | Boosts for cases containing multiple risk categories |
| `critical_override_rules` | Configuration | Rules that force/escalate priority when critical conditions are met |
| `assignment_config` | Configuration | Investigator/supervisor assignment profiles, workloads and auto-assignment behavior |
| `sla_policy` | Configuration | SLA targets by priority/service/status context |
| `sla_escalation` | Configuration | Escalation rules when SLA thresholds are crossed |
| `case_decision_master` | Configuration | Client SOP outcomes shown during case or alert decision selection; mandatory fields and approval/risk update behavior |
| `case_action_master` | Configuration | Reusable internal or external actions such as block card, notify, reverse, create recovery |
| `case_decision_action_mapping` | Configuration | Ordered action list mapped to each decision, including mandatory/optional action control |
| `integration_endpoint_config` | Configuration | HTTP/webhook endpoint, method, auth, payload/header templates, timeout and retry config for external actions |

Runtime and audit tables:

| Table | Type | What it stores and why it exists |
|---|---|---|
| `case_master` | Runtime | Case header, entity, score, priority, status, assignment, final decision and closure metadata |
| `case_alert_mapping` | Runtime | Source-alert-to-case bridge; includes source table, alert ID, mapping status and alert-level decision |
| `case_score_breakdown` | Derived/audit | Snapshot of scoring components used to calculate case score |
| `case_scoring_trace` | Audit/explainability | Trace of scoring logic and config application for case score |
| `case_assignment` | Runtime/history | Assignment records, assignee, assigned_by and assignment timing |
| `case_sla_tracker` | Runtime | SLA milestone tracking, due dates, breached flags and completion state |
| `case_events` | Audit/timeline | Business case timeline events displayed in Timeline & Evidence |
| `case_evidence` | Runtime/audit | Evidence file metadata, hashes, custody/version metadata and storage path |
| `case_recovery` | Runtime | Recovery/loss tracking linked to a case |
| `case_action_execution_queue` | Worker/queue | Action dispatch queue with payload/config snapshot, idempotency key, retry/manual resolution state |
| `case_action_execution_log` | Audit | Immutable-ish action execution attempts and responses |

Source alert tables updated by case closure:

| Source table | Meaning |
|---|---|
| `screening_alert` | Screening alert status is closed when unresolved mapping is closed by final case decision |
| `adverse_alert` | Adverse alert status is closed in the same way |
| `transaction_alert` | Transaction alert status is closed when linked case closes |
| `device_alert` | Device alert status is closed when linked case closes |

### 6.4 RAMS / Risk Rating

RAMS creates a unified entity risk profile from screening, adverse, transaction, device, case and optional ML signals.

Flow:

```text
source event or case decision
  -> risk_event_log
  -> active risk_rating_config
  -> event type/domain mapping
  -> decision impact and decay
  -> service/domain weights and overrides
  -> entity_risk_aggregate
  -> entity_risk_profile
  -> entity_risk_history and factor breakdown
```

Configuration tables:

| Table | Type | What it configures |
|---|---|---|
| `risk_rating_config` | Configuration root | Versioned RAMS policy per institution |
| `risk_rating_weight_config` | Configuration | Domain weights in final entity score |
| `risk_rating_service_weight_config` | Configuration | Contribution of each source service/event source within a domain |
| `risk_rating_tier_config` | Configuration | Final score boundaries and risk tier labels |
| `risk_rating_event_type_config` | Configuration | Which source/event pairs are admitted into RAMS and which risk domain they belong to |
| `risk_rating_decision_impact_config` | Configuration | Decision-specific increase/decrease/suppress/override behavior |
| `risk_rating_decay_policy_config` | Configuration | How older risk events decay over time |
| `risk_rating_override_policy` | Configuration | Final/global override rules under configured conditions |
| `risk_rating_relationship_risk_config` | Configuration | Relationship-risk propagation percentage, depth, cap and threshold |
| `risk_rating_domain_override_config` | Configuration | Domain-specific override rules |
| `efrm_service_config` | Configuration | Service enablement and service-to-risk-domain mapping |

Runtime and derived tables:

| Table | Type | What it stores and why it exists |
|---|---|---|
| `risk_event_log` | Runtime/input | Canonical risk events from screening, adverse, transaction, device, case decision or ML |
| `entity_risk_aggregate` | Derived | Domain scores, counts and latest event timestamps before final profile calculation |
| `entity_risk_profile` | Derived | Latest final entity risk score, tier, status, domain scores and explanation |
| `entity_risk_history` | Audit/history | Historical changes in final score/tier/domain state |
| `entity_risk_factor_breakdown` | Explainability | Factor-level contribution linked to a risk event |
| `risk_recalculation_job` | Worker/queue | Recalculation request/status for bulk or scoped RAMS reprocessing |

### 6.5 Link Analysis

Link Analysis builds entity graphs and clusters from configured dimensions such as device ID, IP address, account, beneficiary, merchant and other relationship facts.

Flow:

```text
source runtime data
  -> graph dimension config
  -> refresh worker/API
  -> entity_graph_nodes and entity_graph_edges
  -> cluster detection/scoring
  -> entity_graph_clusters and cluster nodes
  -> graph evidence and checkpoint
  -> portal cluster/case graph views
```

Tables:

| Table | Type | What it stores and why it exists |
|---|---|---|
| `graph_dimension_config` | Configuration | Which graph dimensions are enabled, source fields and scoring behavior |
| `graph_dimension_subtype_config` | Configuration | Subtypes/categories within graph dimensions |
| `entity_graph_view_config` | Configuration | View presets and graph display behavior |
| `entity_graph_refresh_config` | Configuration | Refresh cadence, batch size, lookback and enabled state |
| `entity_graph_refresh_checkpoint` | Worker/state | Last refresh status, cursor, timestamp, error and checkpoint state |
| `entity_graph_nodes` | Derived | Graph nodes representing entities, accounts, devices, IPs, merchants, etc. |
| `entity_graph_edges` | Derived | Relationships between graph nodes with relation type and score/evidence |
| `entity_graph_clusters` | Derived | Detected clusters/network groups and risk scoring |
| `entity_graph_cluster_nodes` | Derived | Membership of nodes in each cluster |
| `entity_graph_evidence` | Audit/explainability | Evidence explaining why a graph edge/cluster exists |

### 6.6 Entity Master And Relationship Data

Entity Master is the central representation of customers, merchants, accounts, and related parties seen across product flows.

Tables:

| Table | Type | What it stores and why it exists |
|---|---|---|
| `entity_master` | Runtime/master data | Institution-scoped entity identity, entity type, name, risk fields and metadata |
| `entity_relation_map` | Runtime/relationship | Entity-to-entity relationships such as customer-account, merchant-customer, director-company |
| `entity_device_map` | Runtime/relationship | Links entities to observed devices/fingerprints |
| `list_entity` | Runtime/reference list | Watchlist entity record, also read in screening views and sometimes adminservice |
| `list_entity_alias` | Runtime/reference list | Aliases for list entities |
| `list_normalized_address` | Runtime/reference list | Normalized addresses for list entities |

### 6.7 Rule Governance Tables Exposed Through Admin Service

Admin Service exposes many rule configuration/read APIs, while Rule Engine consumes the effective configuration.

| Table | Type | What it stores and why it exists |
|---|---|---|
| `rule_master` | Configuration | Stable logical rule identity and metadata |
| `rule_version` | Configuration/version | Executable DRL/version/status and rule score/severity metadata |
| `rule_master_tag` | Configuration | Tags/classification for search and organization |
| `rule_required_data` | Derived/config support | Facts/metrics/reference inputs required by a rule |
| `rule_group_master` | Configuration | Logical group/bundle identity |
| `rule_group_version` | Configuration/version | Versioned execution group |
| `rule_group_version_map` | Configuration | Ordered rule-version membership in a group |
| `rule_group_source_binding` | Configuration | Active binding of group version to institution/source/channel/fact |
| `rule_decision_policy` | Configuration | Maps score/severity/signals to final decision behavior |
| `rule_decision_upgrade` | Configuration | Escalation/upgrade rules between decisions |
| `metric_definition` | Configuration | Metric SQL/window/aggregation definitions |
| `rule_metric_dependency` | Configuration/derived | Rule-to-metric dependency mapping |
| `rule_drl_context` | Configuration/system | DRL context declarations/global helpers |
| `rule_artifact` | Runtime/audit | Generated/compiled rule artifacts and metadata |
| `aggregated_metric` | Derived/runtime | Calculated metric values consumed by rule execution |

Legacy/review tables:

| Table | Why it exists |
|---|---|
| `rule_definition` | Older rule definition structure retained for compatibility/review |
| `rule_history` | Older rule history/governance records |
| `rule_test` | Older rule test records |
| `rule_group` | Older rule grouping path |
| `inst_rule_group` | Older institution-to-rule-group mapping |

### 6.8 Source Result Review Tables In Admin Service

Admin Service reads source outputs for review screens, case creation, risk drilldowns and link analysis.

| Table | Type | What it stores |
|---|---|---|
| `transaction_request` | Runtime input | Transaction source request |
| `transaction_master` | Runtime input/master | Canonical transaction identity and fields |
| `transaction_result` | Runtime result | Transaction score, decision and result metadata |
| `transaction_match` | Runtime evidence | Transaction rule/signal matches |
| `transaction_alert` | Runtime alert | Transaction alert status and case linkage status |
| `device_request` | Runtime input | Device source request |
| `device_master` | Runtime input/master | Device identity, request ID, location/IP/session fields |
| `device_result` | Runtime result | Device score, decision and result metadata |
| `device_match` | Runtime evidence | Device rule/signal matches |
| `device_alert` | Runtime alert | Device alert status and case linkage status |
| `screening_request` | Runtime input | Screening request |
| `screening_result` | Runtime result | Screening score/decision/risk band |
| `screening_match` | Runtime evidence | Watchlist hit evidence |
| `screening_alert` | Runtime alert | Screening alert status and case linkage status |
| `adverse_request` | Runtime input | Adverse-media request |
| `adverse_result` | Runtime result | Adverse media decision/score |
| `adverse_match` | Runtime evidence | Adverse article/source evidence |
| `adverse_alert` | Runtime alert | Adverse alert status and case linkage status |

### 6.9 Bulk And File Tables

| Table | Type | What it stores and why it exists |
|---|---|---|
| `bulk_file_upload` | Runtime/file | Uploaded file metadata used by bulk operations |
| `bulk_job` | Worker/state | Generic bulk job status and counters |
| `bulk_file` | Runtime/file | Screening/bulk file metadata where present |
| `screening_bulk_job` | Worker/state | Screening bulk job header |
| `screening_bulk_job_item` | Worker/state | Per-row screening bulk item status/result |
| `screening_bulk_job_summary` | Derived | Screening bulk counts/summary |
| `ruleengine_bulk_job` | Worker/state | Rule engine bulk/replay job header |
| `ruleengine_bulk_job_item` | Worker/state | Per-row transaction/device bulk execution item |
| `ruleengine_bulk_job_summary` | Derived | Rule engine bulk counts/summary |

---

## 7. Screening Service DB Flow

### 7.1 Source Download And List Ingestion

Flow:

```text
source_config and source_column_mapping
  -> ingestion job
  -> list_version
  -> list_entity / aliases / normalized address
  -> active list data for screening candidate retrieval
```

Tables:

| Table | Type | What it stores and why it exists |
|---|---|---|
| `source_config` | Configuration | Source download/provider settings, file format, schedule/frequency, active flags and source behavior |
| `source_column_mapping` | Configuration | Maps incoming source file columns to normalized list entity fields |
| `list_source` | Configuration/catalog | Watchlist/source registry such as sanctions, PEP, adverse-like sources |
| `list_version` | Runtime/version | Version/checksum/ingestion metadata for source loads |
| `list_entity` | Runtime/reference list | Normalized watchlist/person/company/entity row used for candidate matching |
| `list_entity_alias` | Runtime/reference list | Aliases/alternate names for list entities |
| `list_normalized_address` | Runtime/reference list | Normalized address values for candidate evidence |
| `bulk_job` | Worker/state | Ingestion/bulk processing job state |
| `audit_trail` | Audit | Ingestion/config actions where recorded |

### 7.2 Screening Configuration

The screening score is DB-configured. The service reads the active master and its children.

| Table | Type | What it configures |
|---|---|---|
| `screening_config_master` | Configuration root | Versioned screening policy for institution/module |
| `screening_field_config` | Configuration | Field weights, matching type, minimum score, mandatory behavior |
| `screening_group_config` | Configuration | Grouping of fields and group-level score behavior |
| `screening_decision_threshold` | Configuration | Score range to decision/action/risk band and alert/case flags |
| `screening_risk_band` | Configuration | Score range to risk band label |
| `screening_source_config` | Configuration | List source contribution/priority/weight |
| `screening_identifier_config` | Configuration | Identifier matching and override/boost behavior |
| `screening_entity` | Configuration | Dynamic entity types such as CUSTOMER, ORGANIZATION, MERCHANT |
| `screening_entity_field` | Configuration | Dynamic input fields shown/validated for an entity type |
| `screening_entity_relation` | Configuration | Related-party fields/relationships for entity screening |
| `whitelist_entry` | Configuration/runtime | Suppression/whitelist entries that reduce or suppress known false positives |
| `reference_data` | Configuration/catalog | Dropdown values such as countries, IDs, channel, source system |

### 7.3 Screening Runtime

Flow:

```text
screening API request
  -> validation and normalization
  -> candidate retrieval from list_entity/list_entity_alias
  -> fuzzy/identifier scoring
  -> screening_request
  -> screening_result
  -> screening_match
  -> screening_alert if reviewable
  -> optional RAMS event and case hook
```

Runtime tables:

| Table | Type | What it stores |
|---|---|---|
| `screening_request` | Runtime input | Request payload and screening context |
| `screening_result` | Runtime result | Final screening score, decision, band, entity context, match count |
| `screening_match` | Runtime evidence | Hit-level evidence, matched list entity and scores |
| `screening_alert` | Runtime alert | Review queue item for screening result |
| `entity_master` | Runtime/master | Entity sync/master row created or referenced from screening |
| `entity_relation_map` | Runtime/relationship | Related parties captured from entity screening |
| `entity_device_map` | Runtime/relationship | Device relation data where screening/entity flows contribute |
| `screening_bulk_job` | Worker/state | Bulk screening job header |
| `screening_bulk_job_item` | Worker/state | Individual bulk row result |
| `screening_bulk_job_summary` | Derived | Job summary counts |

---

## 8. AMC Service DB Flow

AMC is the adverse media compliance pipeline. It may be called directly or from screening.

Flow:

```text
adverse-media request
  -> adverse_request
  -> active adverse config lookup
  -> provider search and extraction
  -> analysis and decision scoring
  -> adverse_result
  -> adverse_match
  -> adverse_alert
  -> optional RAMS event and case hook
```

Configuration tables:

| Table | Type | What it configures |
|---|---|---|
| `adverse_config_master` | Configuration root | Active adverse-media policy per institution |
| `adverse_integration_config` | Configuration | Provider/search integration, endpoint, timeout, auth reference, lookback/depth/result limits |
| `adverse_category_weight` | Configuration | Category weights for fraud, sanctions, legal, regulatory and reputational signals |
| `adverse_severity_score` | Configuration | Severity-to-score mapping |
| `adverse_source_weight` | Configuration | Source reliability/trust weighting |
| `adverse_country_risk` | Configuration | Jurisdiction/country risk modifiers |
| `adverse_recency_factor` | Configuration | Article age/recency score adjustment |
| `adverse_risk_band` | Configuration | Final adverse score to risk band |

Runtime tables:

| Table | Type | What it stores |
|---|---|---|
| `adverse_request` | Runtime input | Request ID, entity identity, status, payload and timestamps |
| `adverse_result` | Runtime result | Adverse final score, risk flag, decision and summary |
| `adverse_match` | Runtime evidence | Article/source matches, snippets, category evidence and confidence |
| `adverse_alert` | Runtime alert | Reviewable adverse-media alert |

---

## 9. Rule Engine Service DB Flow

The Rule Engine evaluates transaction and device events using configured rule versions, group bindings, metrics and decision policies.

### 9.1 Rule Configuration Flow

```text
rule_master
  -> rule_version
  -> rule_required_data and rule_metric_dependency
  -> rule_group_master
  -> rule_group_version
  -> rule_group_version_map
  -> rule_group_source_binding
  -> runtime execution
```

Configuration tables:

| Table | Type | What it configures |
|---|---|---|
| `facts_definition` | Configuration | Valid fact types/contexts |
| `source_system_master` | Configuration | Source system, institution, fact and channel binding data |
| `source_attribute_def` | Configuration | Source payload field definitions |
| `engine_attribute_def` | Configuration | Canonical fields used by DRL/context |
| `engine_flink_map` | Configuration | Mapping between source/engine fields and stream/event fields |
| `rule_master` | Configuration | Logical rule identity |
| `rule_version` | Configuration/version | DRL content, version status, score/severity metadata |
| `rule_master_tag` | Configuration | Rule labels/search metadata |
| `rule_required_data` | Derived/config support | Required input facts/metrics/references for a rule |
| `rule_drl_context` | Configuration/system | DRL context/globals |
| `rule_group_master` | Configuration | Rule group identity |
| `rule_group_version` | Configuration/version | Versioned executable rule group |
| `rule_group_version_map` | Configuration | Rules and execution order inside group version |
| `rule_group_source_binding` | Configuration | Which group applies for institution/source/channel/fact |
| `rule_decision_policy` | Configuration | Score/severity/signal-to-decision policy |
| `rule_decision_upgrade` | Configuration | Decision escalation policy |
| `metric_definition` | Configuration | Metric SQL/window/aggregation definitions |
| `rule_metric_dependency` | Configuration | Metrics required by specific rules |
| `reference_data` | Configuration/catalog | Controlled values used in rule UI and DRL contexts |
| `operator` or `operator_value` | Configuration/catalog | Operators available to rule authoring/execution |

### 9.2 Transaction Execution Flow

```text
transaction request
  -> duplicate check using institution_id + source_txn_id
  -> payload transform
  -> active rule/group load
  -> metric resolution
  -> Drools execution
  -> transaction_request / transaction_master / transaction_result
  -> transaction_match
  -> transaction_alert
  -> async aggregate, RAMS and case hooks
```

Tables:

| Table | Type | What it stores |
|---|---|---|
| `transaction_request` | Runtime input | Raw request and execution status |
| `transaction_master` | Runtime/master | Canonical transaction details and source transaction identity |
| `transaction_result` | Runtime result | Final score, decision, matched count, severity and processing time |
| `transaction_match` | Runtime evidence | Rule/signal hits that explain the transaction result |
| `transaction_alert` | Runtime alert | Alert generated for review/case creation |
| `aggregated_metric` | Derived | Metric values computed for future rule decisions |

### 9.3 Device Execution Flow

```text
device request
  -> duplicate check using institution_id + device_master.request_id
  -> payload transform
  -> rule/group load
  -> Drools execution
  -> device_request / device_master / device_result
  -> device_match
  -> device_alert
  -> async aggregate, RAMS and case hooks
```

Tables:

| Table | Type | What it stores |
|---|---|---|
| `device_request` | Runtime input | Raw request and execution status |
| `device_master` | Runtime/master | Device ID, request ID, IP/location/session and entity linkage |
| `device_result` | Runtime result | Final score, decision and result metadata |
| `device_match` | Runtime evidence | Rule/signal hits for device evaluation |
| `device_alert` | Runtime alert | Device alert generated for review/case creation |
| `entity_master` | Runtime/master | Created/updated entity context for transaction/device clients |
| `entity_relation_map` | Runtime/relationship | Entity relationships inferred/updated from transaction/device context |

### 9.4 Bulk Rule Engine Flow

| Table | Type | What it stores |
|---|---|---|
| `bulk_file_upload` | Runtime/file | Uploaded bulk file metadata |
| `ruleengine_bulk_job` | Worker/state | Bulk execution/replay job header |
| `ruleengine_bulk_job_item` | Worker/state | Per-record execution status/output |
| `ruleengine_bulk_job_summary` | Derived | Counts and summary for bulk job |

---

## 10. ML Engine Service DB Flow

The ML Engine manages features, models, training, inference, explainability and feedback.

### 10.1 ML Configuration And Governance

```text
ml_feature_set
  -> ml_feature_definition
  -> ml_feature_set_version
  -> ml_model_registry
  -> ml_model_version
  -> governance/champion status
  -> training and inference
```

Tables:

| Table | Type | What it stores and why it exists |
|---|---|---|
| `ml_feature_set` | Configuration | Logical group of ML features |
| `ml_feature_set_version` | Configuration/version | Version snapshot and activation state of a feature set |
| `ml_feature_definition` | Configuration | Feature name, datatype, source, transformation and required/default behavior |
| `ml_feature_definition_metadata` | Configuration/metadata | Extra feature metadata and documentation |
| `ml_model_registry` | Configuration | Logical model family/business purpose |
| `ml_model_version` | Configuration/version | Algorithm, artifact path, status, champion flag, training metadata |
| `ml_model_governance` | Governance/audit | Approval/review/rollout/governance actions for model versions |
| `ml_score_blending_policy` | Configuration | How ML score blends with or influences business decisioning |
| `ml_training_dataset_profile` | Governance/audit | Dataset profile, quality and training data lineage |
| `ml_model_simulation_sample` | Configuration/test data | Stored simulation inputs for model evaluation |
| `ml_model_explainability_profile` | Configuration/metadata | Model explainability profile/settings |

### 10.2 Training Flow

```text
training request
  -> ml_model_job
  -> feature-set/version lookup
  -> data extraction and feature engineering
  -> model artifact generated
  -> ml_model_version updated
  -> performance/drift/profile rows
```

Tables:

| Table | Type | What it stores |
|---|---|---|
| `ml_model_job` | Worker/state | Training or model job request, status, timings and errors |
| `ml_model_performance_daily` | Derived/monitoring | Daily performance metrics |
| `ml_model_runtime_metrics` | Derived/monitoring | Runtime latency/count/error metrics |
| `ml_model_drift_summary` | Derived/monitoring | Model/data drift summary |
| `ml_model_feature_drift` | Derived/monitoring | Per-feature drift values |
| `audit_trail` | Audit | ML configuration/governance actions where recorded |

### 10.3 Inference And Feedback Flow

```text
inference request
  -> active/champion model version
  -> feature transformation
  -> anomaly/inference score
  -> ml_inference_result
  -> explainability rows
  -> feedback if analyst labels/reviews
```

Tables:

| Table | Type | What it stores |
|---|---|---|
| `ml_inference_result` | Runtime result | Inference payload/result, model version, score, risk band, decision and timing |
| `ml_inference_shap_local` | Explainability | Local SHAP/explanation values per inference |
| `ml_model_shap_global` | Explainability | Global model feature importance/explainability |
| `ml_feedback` | Runtime/audit | Analyst/user feedback, labels and comments |

---

## 11. Admin Portal Flow

The Admin Portal has no tables of its own. It is the controlled UI over the service APIs.

Core UI-to-service relationships:

| Portal area | Main backend |
|---|---|
| Login, profile, menu, capability | Admin Service `/urm` and auth/security APIs |
| Screening queue/manual/entity/data source | Screening Service and selected Admin Service read/config APIs |
| Transaction and device manual execution | Rule Engine Service GUI/manual APIs |
| Case queue/detail/decision/timeline/evidence | Admin Service `/cases` APIs |
| RAMS/risk profile | Admin Service `/risk-rating` APIs |
| Link Analysis | Admin Service Link Analysis v2 APIs |
| ML pages | ML Engine APIs |
| AMC/adverse pages | AMC Service APIs |
| Rule authoring/config | Admin Service config APIs plus Rule Engine runtime/manual APIs |

Frontend visibility is governed by menus/capabilities, but backend authorization remains the source of truth.

---

## 12. Agentic Automation Context

Agentic automation should treat the FRM database as a governed financial-crime system, not a generic warehouse.

### 12.1 What An Agent Can Safely Read

Agents can usually read:

| Data group | Useful purpose |
|---|---|
| Configuration roots and child rows | Understand active policy and explain decisions |
| Result/match/alert rows | Explain why an alert exists |
| Case timeline and evidence metadata | Summarize investigation history |
| Audit records | Explain who changed what and when |
| Risk event/profile/history | Explain risk movement over time |
| Link-analysis graph/evidence | Explain connected-risk patterns |

### 12.2 What An Agent Must Not Blindly Modify

Agents should not directly modify:

| Data group | Why |
|---|---|
| `case_master.status` | Must go through decision/closure service |
| `case_decision_master` and action mappings | Client SOP and approval-sensitive |
| `risk_rating_*_config` | Can materially change customer risk scores |
| `rule_version` or DRL content | Production detection logic |
| `screening_*_config` | Watchlist decision/scoring policy |
| `user_credential`, token/session tables | Security-critical |
| Source result rows | Historical detection evidence should remain intact |
| `audit_trail` and `security_audit_log` | Audit integrity requires append-only behavior |

### 12.3 Recommended Agentic Capabilities

| Capability | Data needed | Correct behavior |
|---|---|---|
| Investigation assistant | Case, mappings, source results, matches, risk profile, link analysis, evidence | Summarize facts, suggest next review steps, never close a case directly |
| Case decision assistant | Decision config, mandatory fields, alerts, evidence, risk history | Suggest eligible outcomes and missing required information |
| Risk explanation assistant | Risk events, config, aggregate/profile/history, factors | Explain why risk changed and which events contributed |
| Link-analysis assistant | Graph nodes/edges/clusters/evidence | Explain relationships and suspicious patterns |
| Configuration reviewer | Config masters/children, active versions, audit | Detect gaps, overlaps, inactive dependencies and unsafe changes |
| UAT data checker | Config tables, runtime table counts, statuses | Validate test readiness without inserting fake operational records |

### 12.4 Agentic Safety Rules

1. Use service APIs for state changes, not direct SQL.
2. Read effective configuration before explaining a decision.
3. Preserve source result history.
4. Separate machine signal, human alert decision, and final case decision.
5. Distinguish dispatch success from bank-side business completion.
6. Never infer institution context; use authenticated context or explicit institution.
7. Treat missing config as a product/configuration issue, not as empty business truth.
8. All generated recommendations should cite the data tables or API objects used.

---

## 13. Complete Table Catalogue By Domain

This section lists the known product tables discovered from service models and migrations. Some tables may be owned by one service and read by another.

### 13.1 Platform, Security, Profile, Menu

| Table | Purpose |
|---|---|
| `institution` | Institution/tenant root |
| `institution_type` | Institution type catalog |
| `product_master` | Product catalog |
| `menu_master` | Portal menu/card catalog |
| `profile_master` | Profile/role definition |
| `security_capability` | Capability catalog |
| `profile_capability` | Profile capability assignment |
| `capability_endpoint_map` | Endpoint-to-capability authorization mapping |
| `user_master` | User account/profile/institution state |
| `user_credential` | Credential/password hash state |
| `user_password_history` | Password history |
| `password_policy_rule` | Password policy |
| `common_password_list` | Common-password restriction list |
| `security_check` | Profile security-control config |
| `service_client` | Service-to-service client configuration |
| `service_token_jti` | Service-token replay/revocation state |
| `refresh_token` | Refresh token state |
| `user_session` | User session state |
| `login_attempt` | Login-attempt state |
| `account_lockout` | Account lockout state |
| `password_reset_token` | Password reset state |
| `password_expiry_notice` | Expiry notice state |
| `security_notification` | Security notification state |
| `security_audit_log` | Security audit |
| `audit_trail` | General technical audit |
| `chatbot_audit_log` | Assistant/chatbot audit-support table found in schema reconciliation scripts; review active usage before automating around it |

### 13.2 Shared Catalog, Source And Notification

| Table | Purpose |
|---|---|
| `reference_data` | Shared reference/dropdown/code catalog |
| `operator_value` | Rule operator catalog |
| `operator` | Rule Engine operator catalog variant |
| `notification_template` | Notification template config |
| `notification_queue` | Notification queue |
| `source_system_master` | Source system/fact/channel config |
| `source_attribute_def` | Source attribute definitions |
| `engine_attribute_def` | Engine/canonical attribute definitions |
| `engine_flink_map` | Source/engine stream mapping |
| `facts_definition` | Fact/context type definitions |
| `efrm_service_config` | Service enablement, mode and risk-domain mapping |
| `attribute_definition` | Legacy/source attribute-definition table present in seed data and older migrations; newer paths use `source_attribute_def` and `engine_attribute_def` |

### 13.3 Screening And Watchlist

| Table | Purpose |
|---|---|
| `source_config` | Screening source ingestion config |
| `source_column_mapping` | Source file column mapping |
| `list_source` | List source registry |
| `list_version` | List ingestion version/checksum |
| `list_entity` | Watchlist/list entity |
| `list_entity_alias` | List entity aliases |
| `list_normalized_address` | Normalized list addresses |
| `screening_config_master` | Screening scoring config root |
| `screening_field_config` | Field-level screening scoring config |
| `screening_group_config` | Group-level screening scoring config |
| `screening_decision_threshold` | Screening decision thresholds |
| `screening_risk_band` | Screening risk-band boundaries |
| `screening_source_config` | Source contribution config |
| `screening_identifier_config` | Identifier matching config |
| `screening_entity` | Dynamic screening entity type |
| `screening_entity_field` | Dynamic screening field config |
| `screening_entity_relation` | Dynamic related-entity config |
| `screening_request` | Screening request |
| `screening_result` | Screening result |
| `screening_match` | Screening match/hit evidence |
| `screening_alert` | Screening alert |
| `whitelist_entry` | Screening whitelist/suppression |
| `screening_bulk_job` | Screening bulk job |
| `screening_bulk_job_item` | Screening bulk job row |
| `screening_bulk_job_summary` | Screening bulk summary |

### 13.4 Adverse Media / AMC

| Table | Purpose |
|---|---|
| `adverse_config_master` | Adverse policy root |
| `adverse_integration_config` | Adverse provider/integration config |
| `adverse_category_weight` | Adverse category weights |
| `adverse_severity_score` | Adverse severity scores |
| `adverse_source_weight` | Adverse source reliability weights |
| `adverse_country_risk` | Adverse country risk modifiers |
| `adverse_recency_factor` | Adverse recency modifiers |
| `adverse_risk_band` | Adverse risk-band thresholds |
| `adverse_request` | Adverse request |
| `adverse_result` | Adverse result |
| `adverse_match` | Adverse article/media match evidence |
| `adverse_alert` | Adverse alert |

### 13.5 Rule Engine, Transaction And Device

| Table | Purpose |
|---|---|
| `entity_definition` | Rule engine entity/fact definition |
| `metric_definition` | Metric definition |
| `rule_metric_dependency` | Rule-to-metric dependency |
| `aggregated_metric` | Calculated metric values |
| `rule_master` | Rule identity |
| `rule_version` | Rule version/DRL |
| `rule_master_tag` | Rule tags |
| `rule_required_data` | Rule required inputs |
| `rule_drl_context` | DRL context declarations |
| `rule_group_master` | Rule group identity |
| `rule_group_version` | Rule group version |
| `rule_group_version_map` | Rules in group version |
| `rule_group_source_binding` | Source/channel/fact to rule group binding |
| `rule_decision_policy` | Rule decision policy |
| `rule_decision_upgrade` | Rule decision upgrade/escalation |
| `rule_artifact` | Generated/compiled rule artifact |
| `transaction_request` | Transaction request |
| `transaction_master` | Transaction master/canonical identity |
| `transaction_result` | Transaction rule result |
| `transaction_match` | Transaction rule match/signal |
| `transaction_alert` | Transaction alert |
| `device_request` | Device request |
| `device_master` | Device master/canonical identity |
| `device_result` | Device rule result |
| `device_match` | Device rule match/signal |
| `device_alert` | Device alert |
| `ruleengine_bulk_job` | Rule engine bulk job |
| `ruleengine_bulk_job_item` | Rule engine bulk row |
| `ruleengine_bulk_job_summary` | Rule engine bulk summary |
| `sample_entity` | Sample/test entity table found in rule engine SQL; review before relying on it |
| `ruleengine_result` | Legacy/pre-rename rule-engine result table; modern transaction flow uses `transaction_result`, but compatibility migrations and fallback code may still reference it |
| `rule_definition` | Legacy rule definition |
| `rule_history` | Legacy rule history |
| `rule_test` | Legacy rule test |
| `rule_group` | Legacy rule group |
| `inst_rule_group` | Legacy institution rule group mapping |

### 13.6 Case Management

| Table | Purpose |
|---|---|
| `case_config_master` | Case scoring policy root |
| `case_priority_master` | Case priority ranges |
| `alert_category_master` | Alert category weights |
| `alert_count_boost_config` | Alert count boost config |
| `category_correlation_config` | Category correlation scoring config |
| `critical_override_rules` | Critical priority override config |
| `assignment_config` | Assignment policy |
| `sla_policy` | SLA policy |
| `sla_escalation` | SLA escalation config |
| `case_decision_master` | Case/alert decision config |
| `case_action_master` | Case action catalog |
| `case_decision_action_mapping` | Decision-to-action mapping |
| `integration_endpoint_config` | External action endpoint config |
| `case_master` | Case header/runtime state |
| `case_alert_mapping` | Case-to-alert mapping and alert-level decision |
| `case_score_breakdown` | Case score component snapshot |
| `case_scoring_trace` | Case scoring explainability trace |
| `case_assignment` | Case assignment history |
| `case_sla_tracker` | Case SLA tracking |
| `case_events` | Business timeline |
| `case_evidence` | Evidence files/custody |
| `case_recovery` | Recovery/loss tracking |
| `case_action_execution_queue` | Action dispatch queue |
| `case_action_execution_log` | Action dispatch log |

### 13.7 RAMS / Risk Rating

| Table | Purpose |
|---|---|
| `risk_rating_config` | RAMS policy root |
| `risk_rating_weight_config` | Domain weights |
| `risk_rating_service_weight_config` | Service/source weights |
| `risk_rating_tier_config` | Risk tier thresholds |
| `risk_rating_event_type_config` | Event admission/domain mapping |
| `risk_rating_decision_impact_config` | Decision impact rules |
| `risk_rating_decay_policy_config` | Decay policy |
| `risk_rating_override_policy` | Override policy |
| `risk_rating_relationship_risk_config` | Relationship propagation config |
| `risk_rating_domain_override_config` | Domain override config |
| `risk_event_log` | Risk event input |
| `entity_risk_aggregate` | Domain aggregate state |
| `entity_risk_profile` | Latest entity risk profile |
| `entity_risk_history` | Risk history |
| `entity_risk_factor_breakdown` | Risk factor breakdown |
| `risk_recalculation_job` | Risk recalculation queue |

### 13.8 Link Analysis

| Table | Purpose |
|---|---|
| `graph_dimension_config` | Link-analysis dimension config |
| `graph_dimension_subtype_config` | Dimension subtype config |
| `entity_graph_view_config` | Graph view config |
| `entity_graph_refresh_config` | Refresh config |
| `entity_graph_refresh_checkpoint` | Refresh checkpoint/state |
| `entity_graph_nodes` | Graph nodes |
| `entity_graph_edges` | Graph edges |
| `entity_graph_clusters` | Graph clusters |
| `entity_graph_cluster_nodes` | Cluster node membership |
| `entity_graph_evidence` | Graph evidence |

### 13.9 Entity Master And Relationships

| Table | Purpose |
|---|---|
| `entity_master` | Canonical entity/customer/merchant/account identity |
| `entity_relation_map` | Entity relationships |
| `entity_device_map` | Entity-device relationships |

### 13.10 ML Engine

| Table | Purpose |
|---|---|
| `ml_feature_set` | ML feature set |
| `ml_feature_set_version` | Feature set version |
| `ml_feature_definition` | Feature definition |
| `ml_feature_definition_metadata` | Feature metadata |
| `ml_model_registry` | Model registry |
| `ml_model_version` | Model version/artifact/governance state |
| `ml_model_governance` | Model governance records |
| `ml_score_blending_policy` | ML score blending policy |
| `ml_training_dataset_profile` | Training dataset profile |
| `ml_model_job` | Training/model job |
| `ml_inference_result` | Inference result |
| `ml_inference_shap_local` | Local inference explainability |
| `ml_model_shap_global` | Global model explainability |
| `ml_feedback` | Analyst/model feedback |
| `ml_model_performance_daily` | Model performance metrics |
| `ml_model_runtime_metrics` | Runtime metrics |
| `ml_model_drift_summary` | Drift summary |
| `ml_model_feature_drift` | Feature drift |
| `ml_model_simulation_sample` | Simulation sample data |
| `ml_model_explainability_profile` | Explainability profile |

### 13.11 Generic Bulk/File State

| Table | Purpose |
|---|---|
| `bulk_file_upload` | Uploaded file metadata |
| `bulk_file` | Bulk file metadata where present |
| `bulk_job` | Generic bulk job |

---

## 14. How To Read A Case From DB End To End

For a case-focused agentic automation or engineer investigation:

1. Start at `case_master` by `case_id`.
2. Read `case_alert_mapping` to know which source alerts are attached and whether any alert-level decisions exist.
3. For each mapping, use `alert_source_table` to read exactly one source alert table.
4. From the source alert, trace back to the source result/match/request tables.
5. Read `case_events` for business chronology.
6. Read `case_evidence` for evidence and custody.
7. Read `case_assignment` and `case_sla_tracker` for ownership and deadlines.
8. Read `case_decision_master` for the meaning and mandatory behavior of the final decision.
9. Read `case_action_execution_queue` and `case_action_execution_log` for action dispatch state.
10. Read `risk_event_log`, `entity_risk_profile`, `entity_risk_history` and factor breakdown to understand risk impact.
11. Read `audit_trail` for technical user/system changes.

Do not infer that a source alert is closed unless both `case_alert_mapping` and the source alert table agree, or a reconciliation process has explicitly handled historical inconsistencies.

---

## 15. How To Read Risk From DB End To End

For a risk-focused agentic automation:

1. Start with `entity_risk_profile` for the latest final risk.
2. Read `entity_risk_aggregate` for domain-level active scores.
3. Read `entity_risk_history` for movement over time.
4. Read `risk_event_log` for the input events that created risk.
5. Read `entity_risk_factor_breakdown` for factor-level explanation.
6. Read active `risk_rating_config` and all child config tables to explain how the score was calculated.
7. If case decisions changed risk, trace `risk_event_log.reference_table='case_master'` and the related `case_master.decision_code`.
8. Never rewrite original transaction/screening/device/adverse events to reflect human review. Add the human decision signal separately.

---

## 16. How To Read A Rule Result From DB End To End

1. Start at `transaction_result` or `device_result`.
2. Read the corresponding request/master table for source identity and payload.
3. Read `transaction_match` or `device_match` for fired signals/rules.
4. Read `rule_version` for the rule logic/version used.
5. Read `rule_master` for stable rule identity.
6. Read `rule_group_source_binding` and group/version mapping to understand why those rules were active.
7. Read `metric_definition`, `rule_metric_dependency`, and `aggregated_metric` if a rule depended on metrics.
8. Read `rule_decision_policy` and `rule_decision_upgrade` to explain the final decision.
9. Check downstream `risk_event_log` and `case_alert_mapping` to see whether it affected risk or case flow.

---

## 17. How To Read Screening Or AMC From DB End To End

Screening:

```text
screening_request
  -> screening_result
  -> screening_match
  -> list_entity / list_entity_alias / list_version / list_source
  -> screening_alert
  -> risk_event_log and case_alert_mapping if integrated
```

AMC:

```text
adverse_request
  -> adverse_result
  -> adverse_match
  -> adverse_alert
  -> risk_event_log and case_alert_mapping if integrated
```

For both flows, always read the effective configuration used by the service before explaining why a decision happened.

---

## 18. Known Review Boundaries

| Area | Boundary |
|---|---|
| Client SOP data | Case decisions/actions/mappings differ per institution and should not be blindly cloned |
| ML/Agentic UI | Some portal screens may be POC/demo while backend maturity differs by feature |
| Legacy rule tables | Some older rule governance tables remain for compatibility; confirm active runtime usage before automation |
| Bank-side action completion | V1 tracks dispatch/delivery, not confirmed business completion unless callback support is implemented |
| Direct DB writes | Use service APIs for state changes wherever possible |
| Security tables | Do not expose raw secrets, hashes or token data to ordinary automation |

---

## 19. Recommended Next Documents For Agentic Automation

1. **Effective Configuration Resolver Map:** For each module, define the exact query/API to find the active configuration.
2. **Agent Tool Contract:** Define allowed read APIs, allowed write APIs, forbidden direct table writes, and approval gates.
3. **Case Investigation Knowledge Graph:** Define how to combine case, alerts, risk, evidence and link analysis into a safe retrieval context.
4. **Audit And Explainability Standard:** Define the minimum table references an agent must cite when producing a recommendation.
5. **Client Profile Appendix:** Define which services and risk domains are enabled for each client database.
