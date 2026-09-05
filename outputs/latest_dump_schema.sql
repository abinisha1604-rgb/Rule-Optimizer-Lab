--
-- PostgreSQL database dump
--

\restrict e6WUlNwa2sgZmYE4DudVHurJ7Lk7e89zRqZXpbpLy0Y4Wnc4zT0ADlcBe9F9F7A

-- Dumped from database version 18.3 (Homebrew)
-- Dumped by pg_dump version 18.3 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: efrm; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA efrm;


--
-- Name: dblink; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA public;


--
-- Name: EXTENSION dblink; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION dblink IS 'connect to other PostgreSQL databases from within a database';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: guard_security_audit_log(); Type: FUNCTION; Schema: efrm; Owner: -
--

CREATE FUNCTION efrm.guard_security_audit_log() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                IF upper(session_user) <> 'EFRM_SECURITY_ARCHIVE' THEN
                    RAISE EXCEPTION 'security_audit_log is append-only';
                END IF;
                IF TG_OP = 'DELETE' THEN
                    RETURN OLD;
                END IF;
                RETURN NEW;
            END;
            $$;


--
-- Name: reject_ml_audit_mutation(); Type: FUNCTION; Schema: efrm; Owner: -
--

CREATE FUNCTION efrm.reject_ml_audit_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'ml_audit_event is append-only';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_lockout; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.account_lockout (
    lockout_id character varying(64) NOT NULL,
    user_id character varying(128) NOT NULL,
    security_check_id character varying(32) NOT NULL,
    locked_at timestamp with time zone NOT NULL,
    unlock_at timestamp with time zone,
    lock_reason character varying(128) NOT NULL,
    failed_attempt_count integer NOT NULL,
    locked_by character varying(64),
    unlocked_at timestamp with time zone,
    unlocked_by character varying(64),
    is_active character varying(1) NOT NULL
);


--
-- Name: adverse_alert_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_alert_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_alert; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_alert (
    id bigint DEFAULT nextval('efrm.adverse_alert_seq'::regclass) NOT NULL,
    request_id uuid NOT NULL,
    result_id bigint NOT NULL,
    risk_band character varying(16) NOT NULL,
    overall_risk_score integer NOT NULL,
    highest_media_source character varying(64),
    status character varying(32) NOT NULL,
    case_id character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    comments text
);


--
-- Name: adverse_category_weight_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_category_weight_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_category_weight; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_category_weight (
    id bigint DEFAULT nextval('efrm.adverse_category_weight_seq'::regclass) NOT NULL,
    config_master_id bigint NOT NULL,
    risk_category character varying(100) NOT NULL,
    weight numeric(5,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: adverse_config_master_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_config_master_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_config_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_config_master (
    id bigint DEFAULT nextval('efrm.adverse_config_master_seq'::regclass) NOT NULL,
    config_name character varying(100) NOT NULL,
    config_version character varying(50) NOT NULL,
    description text,
    alert_threshold_score integer DEFAULT 85,
    medium_threshold_score integer DEFAULT 60,
    low_threshold_score integer DEFAULT 30,
    scoring_formula text,
    is_active character varying(10) DEFAULT 'DRAFT'::character varying,
    approved_by character varying(100),
    approved_at timestamp without time zone,
    created_by character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: adverse_country_risk_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_country_risk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_country_risk; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_country_risk (
    id bigint DEFAULT nextval('efrm.adverse_country_risk_seq'::regclass) NOT NULL,
    config_master_id bigint NOT NULL,
    country character varying(100),
    jurisdiction_weight numeric(5,2) DEFAULT 1.00,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: adverse_integration_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_integration_config (
    id bigint NOT NULL,
    config_master_id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    is_chaining_enabled character varying(1) DEFAULT 'N'::character varying NOT NULL,
    provider_code character varying(64) DEFAULT 'INTERNAL_AMC'::character varying NOT NULL,
    base_url text NOT NULL,
    submit_path character varying(256) DEFAULT '/adverse-media'::character varying NOT NULL,
    http_method character varying(16) DEFAULT 'POST'::character varying NOT NULL,
    auth_type character varying(32) DEFAULT 'NONE'::character varying NOT NULL,
    auth_header_name character varying(128),
    auth_secret_ref text,
    headers_template jsonb,
    trigger_rules jsonb DEFAULT '{}'::jsonb NOT NULL,
    timeout_seconds integer DEFAULT 5 NOT NULL,
    retry_count integer DEFAULT 1 NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    search_provider character varying(32) DEFAULT 'tavily'::character varying NOT NULL,
    llm_provider character varying(32) DEFAULT 'groq'::character varying NOT NULL,
    runtime_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    CONSTRAINT adverse_integration_config_active_chk CHECK (((is_active)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT adverse_integration_config_auth_chk CHECK (((auth_type)::text = ANY ((ARRAY['NONE'::character varying, 'API_KEY'::character varying, 'BEARER_TOKEN'::character varying])::text[]))),
    CONSTRAINT adverse_integration_config_enabled_chk CHECK (((is_chaining_enabled)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT adverse_integration_config_llm_provider_chk CHECK (((llm_provider)::text = ANY ((ARRAY['local'::character varying, 'bedrock'::character varying, 'groq'::character varying, 'gemini'::character varying])::text[]))),
    CONSTRAINT adverse_integration_config_method_chk CHECK (((http_method)::text = 'POST'::text)),
    CONSTRAINT adverse_integration_config_search_provider_chk CHECK (((search_provider)::text = ANY ((ARRAY['tavily'::character varying, 'brave'::character varying, 'gdelt'::character varying])::text[])))
);


--
-- Name: adverse_integration_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_integration_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_integration_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.adverse_integration_config_id_seq OWNED BY efrm.adverse_integration_config.id;


--
-- Name: adverse_match_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_match_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_match; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_match (
    id bigint DEFAULT nextval('efrm.adverse_match_seq'::regclass) NOT NULL,
    result_id bigint NOT NULL,
    alert_id bigint,
    article_hash character varying(128) NOT NULL,
    headline text NOT NULL,
    summary text,
    source character varying(255) NOT NULL,
    source_url text NOT NULL,
    published_date timestamp with time zone,
    language character varying(20) NOT NULL,
    sentiment character varying(20) NOT NULL,
    confidence_score numeric(5,4) NOT NULL,
    risk_categories jsonb NOT NULL,
    severity character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: adverse_recency_factor_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_recency_factor_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_recency_factor; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_recency_factor (
    id bigint DEFAULT nextval('efrm.adverse_recency_factor_seq'::regclass) NOT NULL,
    config_master_id bigint NOT NULL,
    max_days integer NOT NULL,
    multiplier numeric(5,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: adverse_request_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_request_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_request; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_request (
    id bigint DEFAULT nextval('efrm.adverse_request_seq'::regclass) NOT NULL,
    request_id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity_id character varying(128),
    entity_type character varying(20) NOT NULL,
    full_name character varying(500) NOT NULL,
    screening_depth character varying(20) DEFAULT 'STANDARD'::character varying,
    lookback_period_days integer DEFAULT 365,
    request_payload jsonb NOT NULL,
    request_status character varying(16) DEFAULT 'PENDING'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by character varying(64),
    screening_request_id uuid
);


--
-- Name: adverse_result_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_result_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_result; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_result (
    id bigint DEFAULT nextval('efrm.adverse_result_seq'::regclass) NOT NULL,
    request_id uuid NOT NULL,
    risk_flag character varying(20) NOT NULL,
    risk_score integer NOT NULL,
    overall_assessment text,
    negative_categories jsonb,
    model_explainability jsonb,
    llm_provider character varying(50),
    search_provider character varying(50),
    model_version character varying(100),
    scoring_version character varying(50),
    decision_timestamp timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT adverse_result_risk_score_check CHECK (((risk_score >= 0) AND (risk_score <= 100)))
);


--
-- Name: adverse_risk_band_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_risk_band_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_risk_band; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_risk_band (
    id bigint DEFAULT nextval('efrm.adverse_risk_band_seq'::regclass) NOT NULL,
    config_master_id bigint NOT NULL,
    band_code character varying(20) NOT NULL,
    band_name character varying(50) NOT NULL,
    min_score integer NOT NULL,
    max_score integer NOT NULL,
    priority_order integer NOT NULL,
    requires_alert character varying(1) DEFAULT 'N'::character varying,
    requires_case character varying(1) DEFAULT 'N'::character varying,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: adverse_severity_score_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_severity_score_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_severity_score; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_severity_score (
    id bigint DEFAULT nextval('efrm.adverse_severity_score_seq'::regclass) NOT NULL,
    config_master_id bigint NOT NULL,
    severity character varying(20) NOT NULL,
    base_score integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: adverse_source_weight_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.adverse_source_weight_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverse_source_weight; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.adverse_source_weight (
    id bigint DEFAULT nextval('efrm.adverse_source_weight_seq'::regclass) NOT NULL,
    config_master_id bigint NOT NULL,
    source_name character varying(255),
    credibility_score numeric(5,2) DEFAULT 1.00,
    is_high_trust character varying(1) DEFAULT 'N'::character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: aggregated_metric_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.aggregated_metric_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: aggregated_metric; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.aggregated_metric (
    id integer DEFAULT nextval('efrm.aggregated_metric_seq'::regclass) NOT NULL,
    institution_id character varying(64) NOT NULL,
    entity_type character varying(32) NOT NULL,
    entity_id character varying(64) NOT NULL,
    metric_code character varying(64) NOT NULL,
    metric_value numeric(20,6) NOT NULL,
    source_system character varying(32),
    channel character varying(32),
    computed_at timestamp without time zone NOT NULL,
    valid_till timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: alembic_version; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.alembic_version (
    version_num character varying(32) NOT NULL
);


--
-- Name: alert_category_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.alert_category_master (
    id integer NOT NULL,
    config_master_id integer NOT NULL,
    category_code character varying(20),
    description character varying(100),
    weight numeric(5,4) NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    CONSTRAINT chk_alert_category_master_is_active CHECK (((is_active)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: alert_category_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.alert_category_master_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: alert_category_master_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.alert_category_master_id_seq OWNED BY efrm.alert_category_master.id;


--
-- Name: alert_count_boost_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.alert_count_boost_config (
    id integer NOT NULL,
    config_master_id integer NOT NULL,
    min_alert_count integer,
    max_alert_count integer,
    boost_factor numeric(5,2),
    description character varying(100),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    CONSTRAINT chk_alert_count_boost_config_is_active CHECK (((is_active)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: alert_count_boost_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.alert_count_boost_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: alert_count_boost_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.alert_count_boost_config_id_seq OWNED BY efrm.alert_count_boost_config.id;


--
-- Name: assignment_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.assignment_config (
    config_id bigint NOT NULL,
    action_type character varying(50) NOT NULL,
    alert_type character varying(50) NOT NULL,
    priority character varying(10) NOT NULL,
    assign_role_code character varying(50) NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    notify character varying(1) DEFAULT 'N'::character varying NOT NULL,
    notification_template character varying(50),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN assignment_config.action_type; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.assignment_config.action_type IS 'CASE_CREATE, STR, CTR';


--
-- Name: COLUMN assignment_config.alert_type; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.assignment_config.alert_type IS 'SCREENING, RULE_ENGINE';


--
-- Name: COLUMN assignment_config.priority; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.assignment_config.priority IS 'P1, P2, P3';


--
-- Name: COLUMN assignment_config.assign_role_code; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.assignment_config.assign_role_code IS 'RISK_ANALYST';


--
-- Name: COLUMN assignment_config.is_active; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.assignment_config.is_active IS 'Whether the configuration is active';


--
-- Name: COLUMN assignment_config.notify; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.assignment_config.notify IS 'Notification flag: Y/N';


--
-- Name: COLUMN assignment_config.notification_template; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.assignment_config.notification_template IS 'Notification template identifier';


--
-- Name: audit_trail; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.audit_trail (
    id integer NOT NULL,
    user_name character varying(128) NOT NULL,
    module_name character varying(128) NOT NULL,
    action_type character varying(128) NOT NULL,
    action_context character varying(128),
    table_name character varying(128) NOT NULL,
    entity_id character varying(128),
    ip_address character varying(128),
    old_value text NOT NULL,
    new_value text NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: audit_trail_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.audit_trail_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bulk_file_upload; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.bulk_file_upload (
    id integer NOT NULL,
    file_id character varying(64) NOT NULL,
    file_name character varying(256) NOT NULL,
    content_type character varying(64) NOT NULL,
    file_size bigint NOT NULL,
    checksum character varying(128),
    storage_type character varying(16) NOT NULL,
    storage_path character varying(512) NOT NULL,
    module character varying(32) NOT NULL,
    status character varying(16) NOT NULL,
    uploaded_by character varying(64) NOT NULL,
    uploaded_at timestamp without time zone DEFAULT now() NOT NULL,
    error_message character varying(512),
    institution_id character varying(64)
);


--
-- Name: bulk_file_upload_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.bulk_file_upload_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bulk_file_upload_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.bulk_file_upload_id_seq OWNED BY efrm.bulk_file_upload.id;


--
-- Name: bulk_job_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.bulk_job_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bulk_job; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.bulk_job (
    id bigint DEFAULT nextval('efrm.bulk_job_seq'::regclass) NOT NULL,
    job_id uuid NOT NULL,
    job_type character varying(32) NOT NULL,
    source_code character varying(64),
    criteria jsonb,
    status character varying(32) DEFAULT 'PENDING'::character varying NOT NULL,
    total_records bigint DEFAULT 0,
    total_entities bigint DEFAULT 0,
    processed_records bigint DEFAULT 0,
    processed_entities bigint DEFAULT 0,
    failed_records bigint DEFAULT 0,
    file_path character varying(512),
    created_by character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    error_message text,
    error_reason text,
    list_version_id bigint,
    file_checksum character varying(128),
    current_phase character varying(32),
    last_completed_row_no bigint,
    batch_size bigint,
    last_heartbeat_at timestamp without time zone,
    started_at timestamp without time zone
);


--
-- Name: capability_endpoint_map; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.capability_endpoint_map (
    mapping_id character varying(64) NOT NULL,
    capability_code character varying(128) NOT NULL,
    service_code character varying(32) NOT NULL,
    http_method character varying(8) NOT NULL,
    path_pattern character varying(256) NOT NULL,
    status character varying(16) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    CONSTRAINT chk_cemap_method CHECK (((http_method)::text = ANY ((ARRAY['GET'::character varying, 'HEAD'::character varying, 'POST'::character varying, 'PUT'::character varying, 'PATCH'::character varying, 'DELETE'::character varying])::text[]))),
    CONSTRAINT chk_cemap_service CHECK (((service_code)::text = ANY ((ARRAY['ADMIN'::character varying, 'RULE_ENGINE'::character varying, 'SCREENING'::character varying, 'AMC'::character varying, 'ML_ENGINE'::character varying])::text[]))),
    CONSTRAINT chk_cemap_status CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'INACTIVE'::character varying])::text[])))
);


--
-- Name: case_action_execution_log; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_action_execution_log (
    log_id bigint NOT NULL,
    execution_id bigint NOT NULL,
    case_id integer NOT NULL,
    action_code character varying(64) NOT NULL,
    request_payload jsonb,
    response_payload jsonb,
    status character varying(32) NOT NULL,
    error_message text,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    executed_by character varying(64),
    http_status integer,
    external_reference_id character varying(128)
);


--
-- Name: case_action_execution_log_log_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_action_execution_log_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_action_execution_log_log_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_action_execution_log_log_id_seq OWNED BY efrm.case_action_execution_log.log_id;


--
-- Name: case_action_execution_queue; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_action_execution_queue (
    execution_id bigint NOT NULL,
    case_id integer NOT NULL,
    decision_code character varying(64) NOT NULL,
    action_code character varying(64) NOT NULL,
    sequence_no integer NOT NULL,
    is_mandatory character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    target_system character varying(64),
    execution_status character varying(32) DEFAULT 'PENDING'::character varying NOT NULL,
    business_status character varying(32) DEFAULT 'NOT_APPLICABLE'::character varying NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    max_retry_count integer DEFAULT 0 NOT NULL,
    next_retry_at timestamp without time zone,
    request_payload jsonb,
    response_payload jsonb,
    endpoint_url text,
    http_method character varying(10),
    headers_snapshot jsonb,
    payload_template_snapshot jsonb,
    auth_type character varying(32),
    timeout_seconds integer,
    success_status_codes character varying(200),
    idempotency_key character varying(256) NOT NULL,
    external_reference_id character varying(128),
    error_message text,
    manual_resolution_status character varying(32),
    manual_resolution_remarks text,
    manual_resolved_by character varying(64),
    manual_resolved_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    dispatched_at timestamp without time zone
);


--
-- Name: case_action_execution_queue_execution_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_action_execution_queue_execution_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_action_execution_queue_execution_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_action_execution_queue_execution_id_seq OWNED BY efrm.case_action_execution_queue.execution_id;


--
-- Name: case_action_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_action_master (
    action_id bigint NOT NULL,
    action_code character varying(64) NOT NULL,
    action_name character varying(128) NOT NULL,
    action_type character varying(32) DEFAULT 'WEBHOOK'::character varying NOT NULL,
    target_system character varying(64),
    execution_mode character varying(32) DEFAULT 'ASYNC'::character varying NOT NULL,
    requires_approval character varying(1) DEFAULT 'N'::character varying NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    config_master_id integer NOT NULL,
    max_retry_count integer DEFAULT 3 NOT NULL
);


--
-- Name: case_action_master_action_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_action_master_action_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_action_master_action_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_action_master_action_id_seq OWNED BY efrm.case_action_master.action_id;


--
-- Name: case_alert_mapping; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_alert_mapping (
    id integer NOT NULL,
    case_id integer NOT NULL,
    alert_id bigint NOT NULL,
    alert_type character varying(20) NOT NULL,
    alert_source_table character varying(50) NOT NULL,
    alert_score integer NOT NULL,
    normalized_score numeric(5,4) NOT NULL,
    is_primary_flag character varying(1) DEFAULT 'N'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    status character varying(32) DEFAULT 'OPEN'::character varying NOT NULL,
    disposition_code character varying(64),
    disposition_details text,
    decision_code character varying(64),
    decision_payload jsonb,
    decision_remarks text,
    decision_submitted_by character varying(64),
    decision_submitted_at timestamp without time zone
);


--
-- Name: case_alert_mapping_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_alert_mapping_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_alert_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_alert_mapping_id_seq OWNED BY efrm.case_alert_mapping.id;


--
-- Name: case_assignment; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_assignment (
    assignment_id integer NOT NULL,
    case_id integer,
    assigned_to character varying(64) NOT NULL,
    assigned_at timestamp without time zone NOT NULL,
    assignment_reason text NOT NULL,
    prev_assignee character varying(64) NOT NULL
);


--
-- Name: case_assignment_assignment_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_assignment_assignment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_assignment_assignment_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_assignment_assignment_id_seq OWNED BY efrm.case_assignment.assignment_id;


--
-- Name: case_assignment_config_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_assignment_config_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_assignment_config_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_assignment_config_config_id_seq OWNED BY efrm.assignment_config.config_id;


--
-- Name: case_config_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_config_master (
    id integer NOT NULL,
    institution_id character varying(12) NOT NULL,
    config_name character varying(128) NOT NULL,
    config_version integer NOT NULL,
    description character varying(200),
    effective_from timestamp without time zone,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(64),
    approved_at timestamp without time zone,
    approved_by character varying(64),
    auto_assignment character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    CONSTRAINT chk_case_config_master_is_active CHECK (((is_active)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: case_config_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_config_master_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_config_master_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_config_master_id_seq OWNED BY efrm.case_config_master.id;


--
-- Name: case_decision_action_mapping; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_decision_action_mapping (
    mapping_id bigint NOT NULL,
    decision_code character varying(64) NOT NULL,
    action_code character varying(64) NOT NULL,
    sequence_no integer DEFAULT 1 NOT NULL,
    is_mandatory character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    config_master_id integer NOT NULL
);


--
-- Name: case_decision_action_mapping_mapping_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_decision_action_mapping_mapping_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_decision_action_mapping_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_decision_action_mapping_mapping_id_seq OWNED BY efrm.case_decision_action_mapping.mapping_id;


--
-- Name: case_decision_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_decision_master (
    decision_id bigint NOT NULL,
    decision_code character varying(64) NOT NULL,
    decision_name character varying(128) NOT NULL,
    alert_type character varying(20) DEFAULT 'ANY'::character varying NOT NULL,
    service_code character varying(64) DEFAULT 'ANY'::character varying NOT NULL,
    entity_type character varying(64) DEFAULT 'ANY'::character varying NOT NULL,
    requires_loss_amount character varying(1) DEFAULT 'N'::character varying NOT NULL,
    requires_recovery character varying(1) DEFAULT 'N'::character varying NOT NULL,
    requires_remarks character varying(1) DEFAULT 'N'::character varying NOT NULL,
    requires_evidence character varying(1) DEFAULT 'N'::character varying NOT NULL,
    requires_approval character varying(1) DEFAULT 'N'::character varying NOT NULL,
    display_order integer DEFAULT 100 NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    config_master_id integer NOT NULL,
    updates_customer_risk character varying(1) DEFAULT 'N'::character varying NOT NULL,
    risk_event_score integer DEFAULT 0 NOT NULL,
    CONSTRAINT chk_case_decision_updates_customer_risk CHECK (((updates_customer_risk)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[])))
);


--
-- Name: case_decision_master_decision_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_decision_master_decision_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_decision_master_decision_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_decision_master_decision_id_seq OWNED BY efrm.case_decision_master.decision_id;


--
-- Name: case_events; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_events (
    event_id integer NOT NULL,
    case_id integer,
    event_type character varying(64),
    event_description text,
    actor_id character varying(64),
    payload jsonb,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: case_events_event_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_events_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_events_event_id_seq OWNED BY efrm.case_events.event_id;


--
-- Name: case_evidence; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_evidence (
    evidence_id integer NOT NULL,
    case_id integer,
    file_path text NOT NULL,
    file_type character varying(128) NOT NULL,
    hash_value character varying(256) NOT NULL,
    uploaded_by character varying(64) NOT NULL,
    uploaded_at timestamp without time zone NOT NULL,
    version integer NOT NULL,
    chain_of_custody jsonb NOT NULL
);


--
-- Name: case_evidence_evidence_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_evidence_evidence_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_evidence_evidence_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_evidence_evidence_id_seq OWNED BY efrm.case_evidence.evidence_id;


--
-- Name: case_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_master (
    case_id integer NOT NULL,
    entity_type character varying(64) NOT NULL,
    entity_id character varying(64) NOT NULL,
    risk_score integer NOT NULL,
    priority character varying(8),
    status character varying(32) DEFAULT 'OPEN'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    assigned_to character varying(64),
    sla_due_at timestamp without time zone,
    disposition_code character varying(64),
    disposition_details text,
    closure_reason text,
    is_str_recommended character varying(1) DEFAULT 'N'::character varying NOT NULL,
    is_ctr_recommended character varying(1) DEFAULT 'N'::character varying NOT NULL,
    sla_id bigint,
    sla_response_due_at timestamp without time zone,
    sla_resolution_due_at timestamp without time zone,
    sla_status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    alert_count integer DEFAULT 0 NOT NULL,
    category_count integer DEFAULT 0 NOT NULL,
    max_alert_score integer,
    scoring_version character varying(10),
    is_override_case character varying(1) DEFAULT 'N'::character varying NOT NULL,
    override_reason character varying(100),
    entity_name character varying(256),
    institution_id character varying(64) DEFAULT 'DEFAULT'::character varying,
    decision_code character varying(64),
    decision_payload jsonb,
    decision_remarks text,
    decision_submitted_by character varying(64),
    decision_submitted_at timestamp without time zone,
    approval_status character varying(32),
    approved_by character varying(64),
    approved_at timestamp without time zone,
    CONSTRAINT chk_case_master_is_ctr CHECK (((is_ctr_recommended)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_case_master_is_override_case CHECK (((is_override_case)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_case_master_is_str CHECK (((is_str_recommended)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: COLUMN case_master.sla_id; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_master.sla_id IS 'Reference to SLA policy';


--
-- Name: COLUMN case_master.sla_response_due_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_master.sla_response_due_at IS 'SLA response due date';


--
-- Name: COLUMN case_master.sla_resolution_due_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_master.sla_resolution_due_at IS 'SLA resolution due date';


--
-- Name: COLUMN case_master.sla_status; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_master.sla_status IS 'SLA status: OPEN, RESPONDED, RESOLVED, BREACHED';


--
-- Name: case_priority_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_priority_master (
    id integer NOT NULL,
    config_master_id integer NOT NULL,
    priority_code character varying(20),
    description character varying(100),
    min_score integer,
    max_score integer,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    CONSTRAINT chk_case_priority_master_is_active CHECK (((is_active)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: case_priority_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_priority_master_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_priority_master_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_priority_master_id_seq OWNED BY efrm.case_priority_master.id;


--
-- Name: case_recovery; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_recovery (
    recovery_id integer NOT NULL,
    case_id integer,
    initial_loss_amount numeric(18,2),
    provisional_credit numeric(18,2),
    recovered_amount numeric(18,2),
    writeoff_amount numeric(18,2),
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: case_recovery_recovery_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_recovery_recovery_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_recovery_recovery_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_recovery_recovery_id_seq OWNED BY efrm.case_recovery.recovery_id;


--
-- Name: case_score_breakdown; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_score_breakdown (
    id integer NOT NULL,
    case_id integer NOT NULL,
    screening_score integer,
    transaction_score integer,
    device_score integer,
    screening_weight_applied numeric(5,4),
    transaction_weight_applied numeric(5,4),
    device_weight_applied numeric(5,4),
    max_alert_score integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: case_score_breakdown_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_score_breakdown_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_score_breakdown_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_score_breakdown_id_seq OWNED BY efrm.case_score_breakdown.id;


--
-- Name: case_scoring_trace; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_scoring_trace (
    id integer NOT NULL,
    case_id integer NOT NULL,
    base_score numeric(10,4),
    boost_factor numeric(10,4),
    correlation_boost numeric(10,4),
    final_score numeric(10,4),
    priority_assigned character varying(20),
    override_flag character varying(1) DEFAULT 'N'::character varying NOT NULL,
    override_reason character varying(100),
    scoring_version character varying(10),
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: case_scoring_trace_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_scoring_trace_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_scoring_trace_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_scoring_trace_id_seq OWNED BY efrm.case_scoring_trace.id;


--
-- Name: case_sla_tracker; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.case_sla_tracker (
    tracker_id bigint NOT NULL,
    case_id bigint NOT NULL,
    sla_stage character varying(20) NOT NULL,
    due_at timestamp without time zone NOT NULL,
    achieved_at timestamp without time zone,
    breached character varying(1) DEFAULT 'N'::character varying NOT NULL,
    breached_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN case_sla_tracker.case_id; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_sla_tracker.case_id IS 'Reference to case';


--
-- Name: COLUMN case_sla_tracker.sla_stage; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_sla_tracker.sla_stage IS 'SLA stage: RESPONSE / RESOLUTION';


--
-- Name: COLUMN case_sla_tracker.due_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_sla_tracker.due_at IS 'SLA due date for this stage';


--
-- Name: COLUMN case_sla_tracker.achieved_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_sla_tracker.achieved_at IS 'Timestamp when SLA was achieved';


--
-- Name: COLUMN case_sla_tracker.breached; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_sla_tracker.breached IS 'Whether SLA was breached: Y/N';


--
-- Name: COLUMN case_sla_tracker.breached_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_sla_tracker.breached_at IS 'Timestamp when SLA was breached';


--
-- Name: COLUMN case_sla_tracker.created_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.case_sla_tracker.created_at IS 'Timestamp when tracker was created';


--
-- Name: case_sla_tracker_tracker_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.case_sla_tracker_tracker_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: case_sla_tracker_tracker_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.case_sla_tracker_tracker_id_seq OWNED BY efrm.case_sla_tracker.tracker_id;


--
-- Name: cases_case_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.cases_case_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cases_case_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.cases_case_id_seq OWNED BY efrm.case_master.case_id;


--
-- Name: category_correlation_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.category_correlation_config (
    id integer NOT NULL,
    config_master_id integer NOT NULL,
    category_count integer,
    correlation_boost numeric(5,2),
    description character varying(100),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    CONSTRAINT chk_category_correlation_config_is_active CHECK (((is_active)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: category_correlation_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.category_correlation_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: category_correlation_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.category_correlation_config_id_seq OWNED BY efrm.category_correlation_config.id;


--
-- Name: chatbot_audit_log; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.chatbot_audit_log (
    id integer NOT NULL,
    user_id character varying(50),
    session_id character varying(100),
    user_prompt text NOT NULL,
    bot_response text NOT NULL,
    intent_type character varying(50),
    sources_used json,
    created_at timestamp without time zone
);


--
-- Name: chatbot_audit_log_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.chatbot_audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chatbot_audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.chatbot_audit_log_id_seq OWNED BY efrm.chatbot_audit_log.id;


--
-- Name: common_password_list; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.common_password_list (
    entry_id character varying(64) NOT NULL,
    password_hash character varying(128) NOT NULL,
    source character varying(64),
    loaded_at timestamp with time zone NOT NULL
);


--
-- Name: critical_override_rules; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.critical_override_rules (
    id integer NOT NULL,
    config_master_id integer NOT NULL,
    rule_code character varying(50),
    description character varying(200),
    alert_type character varying(20),
    threshold_score integer,
    forced_case_score integer,
    forced_priority character varying(20),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    CONSTRAINT chk_critical_override_rules_is_active CHECK (((is_active)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: critical_override_rules_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.critical_override_rules_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: critical_override_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.critical_override_rules_id_seq OWNED BY efrm.critical_override_rules.id;


--
-- Name: dashboard_assignment; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.dashboard_assignment (
    id integer NOT NULL,
    institution_id character varying(12) NOT NULL,
    profile_id character varying(32),
    resource_code character varying(64) NOT NULL,
    scope_type character varying(16) NOT NULL,
    scope_key character varying(160) NOT NULL,
    variant_id integer NOT NULL,
    assignment_version integer NOT NULL,
    config_schema_version integer DEFAULT 1 NOT NULL,
    configuration jsonb NOT NULL,
    approval_status character varying(16) DEFAULT 'DRAFT'::character varying NOT NULL,
    is_active character varying(1) DEFAULT 'N'::character varying NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    change_reason text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by character varying(64) NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    updated_by character varying(64) NOT NULL,
    approved_at timestamp with time zone,
    approved_by character varying(64),
    CONSTRAINT ck_dash_assign_active CHECK (((is_active)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_dash_assign_approval CHECK (((approval_status)::text = ANY ((ARRAY['DRAFT'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[]))),
    CONSTRAINT ck_dash_assign_effective CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to > effective_from))),
    CONSTRAINT ck_dash_assign_profile CHECK (((((scope_type)::text = 'PROFILE'::text) AND (profile_id IS NOT NULL)) OR (((scope_type)::text = 'INSTITUTION'::text) AND (profile_id IS NULL)))),
    CONSTRAINT ck_dash_assign_scope CHECK (((scope_type)::text = ANY ((ARRAY['PROFILE'::character varying, 'INSTITUTION'::character varying])::text[]))),
    CONSTRAINT ck_dash_assign_versions CHECK (((assignment_version > 0) AND (config_schema_version > 0)))
);


--
-- Name: dashboard_assignment_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

ALTER TABLE efrm.dashboard_assignment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME efrm.dashboard_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: dashboard_export_audit; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.dashboard_export_audit (
    export_id character varying(36) NOT NULL,
    institution_id character varying(12) NOT NULL,
    profile_id character varying(32) NOT NULL,
    user_id character varying(128) NOT NULL,
    resource_code character varying(64) NOT NULL,
    variant_code character varying(64) NOT NULL,
    assignment_version integer,
    export_format character varying(8) NOT NULL,
    normalized_filters jsonb NOT NULL,
    data_as_of timestamp with time zone NOT NULL,
    request_id character varying(128),
    status character varying(16) DEFAULT 'REQUESTED'::character varying NOT NULL,
    byte_count integer,
    content_sha256 character varying(64),
    failure_code character varying(64),
    requested_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    CONSTRAINT ck_dash_export_format CHECK (((export_format)::text = ANY ((ARRAY['PDF'::character varying, 'XLSX'::character varying])::text[]))),
    CONSTRAINT ck_dash_export_status CHECK (((status)::text = ANY ((ARRAY['REQUESTED'::character varying, 'COMPLETED'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: dashboard_variant_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.dashboard_variant_master (
    id integer NOT NULL,
    resource_code character varying(64) NOT NULL,
    variant_code character varying(64) NOT NULL,
    handler_key character varying(128) NOT NULL,
    component_key character varying(128) NOT NULL,
    display_name character varying(160) NOT NULL,
    contract_version character varying(32) NOT NULL,
    config_schema_version integer DEFAULT 1 NOT NULL,
    default_refresh_seconds integer NOT NULL,
    is_product_default character varying(1) DEFAULT 'N'::character varying NOT NULL,
    approval_status character varying(16) DEFAULT 'DRAFT'::character varying NOT NULL,
    is_active character varying(1) DEFAULT 'N'::character varying NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    created_by character varying(64) NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    updated_by character varying(64) NOT NULL,
    approved_at timestamp with time zone,
    approved_by character varying(64),
    CONSTRAINT ck_dash_variant_active CHECK (((is_active)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_dash_variant_approval CHECK (((approval_status)::text = ANY ((ARRAY['DRAFT'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[]))),
    CONSTRAINT ck_dash_variant_default CHECK (((is_product_default)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_dash_variant_effective CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to > effective_from))),
    CONSTRAINT ck_dash_variant_refresh CHECK (((default_refresh_seconds >= 0) AND (default_refresh_seconds <= 86400))),
    CONSTRAINT ck_dash_variant_schema_ver CHECK ((config_schema_version > 0))
);


--
-- Name: dashboard_variant_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

ALTER TABLE efrm.dashboard_variant_master ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME efrm.dashboard_variant_master_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: device_alert; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.device_alert (
    id integer NOT NULL,
    device_result_id integer NOT NULL,
    alert_code character varying(64) NOT NULL,
    alert_category character varying(16) NOT NULL,
    alert_severity character varying(16) NOT NULL,
    severity_rank integer NOT NULL,
    decision character varying(16) NOT NULL,
    customer_id character varying(64),
    device_id character varying(64),
    alert_payload jsonb NOT NULL,
    status character varying(16) DEFAULT 'OPEN'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    user_action character varying(20)
);


--
-- Name: device_alert_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.device_alert_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: device_alert_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.device_alert_id_seq OWNED BY efrm.device_alert.id;


--
-- Name: device_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.device_master (
    id integer NOT NULL,
    device_id character varying(64) NOT NULL,
    institution_id character varying(64) NOT NULL,
    source_system character varying(32) NOT NULL,
    channel character varying(32) NOT NULL,
    customer_id character varying(64),
    account_id character varying(64),
    card_bin character varying(16),
    rule_engine_context jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    device_request_id integer NOT NULL,
    ip_address character varying(128),
    request_id character varying(64),
    event_type character varying(32),
    location_country character varying(128),
    location_city character varying(128),
    location_latitude double precision,
    location_longitude double precision
);


--
-- Name: device_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.device_master_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: device_master_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.device_master_id_seq OWNED BY efrm.device_master.id;


--
-- Name: device_match; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.device_match (
    id integer NOT NULL,
    device_result_id integer NOT NULL,
    rule_group_version integer NOT NULL,
    rule_code character varying(64) NOT NULL,
    rule_version integer NOT NULL,
    signal_code character varying(64) NOT NULL,
    signal_severity character varying(16) NOT NULL,
    severity_rank integer NOT NULL,
    signal_weight integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: device_match_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.device_match_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: device_match_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.device_match_id_seq OWNED BY efrm.device_match.id;


--
-- Name: device_request; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.device_request (
    id integer NOT NULL,
    api_name character varying(64) NOT NULL,
    channel character varying(32) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    fact character varying(64),
    http_status integer,
    institution_id character varying(64) NOT NULL,
    is_test character varying(1) DEFAULT 'N'::character varying NOT NULL,
    processing_time_ms integer,
    request_id character varying(64) NOT NULL,
    request_payload jsonb NOT NULL,
    response_payload jsonb,
    source_system character varying(32) NOT NULL
);


--
-- Name: device_request_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.device_request_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: device_request_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.device_request_id_seq OWNED BY efrm.device_request.id;


--
-- Name: device_result; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.device_result (
    id integer NOT NULL,
    entity_id character varying(128) NOT NULL,
    device_master_id integer NOT NULL,
    raw_score integer,
    overall_score integer,
    highest_severity character varying(16),
    highest_severity_rank integer,
    matched_rule_count integer,
    final_decision character varying(16) NOT NULL,
    decision_strategy character varying(32),
    decision_policy_code character varying(64),
    execution_time_ms integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    executed_rule_count integer,
    skipped_rule_count integer,
    skipped_rule_reason jsonb,
    is_alert_generated character varying(1) DEFAULT 'N'::character varying,
    is_case_generated character varying(1) DEFAULT 'N'::character varying
);


--
-- Name: device_result_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.device_result_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: device_result_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.device_result_id_seq OWNED BY efrm.device_result.id;


--
-- Name: efrm_service_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.efrm_service_config (
    id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    service_name character varying(50) NOT NULL,
    risk_domain character varying(50) NOT NULL,
    description text,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    mode character varying(10) NOT NULL,
    CONSTRAINT chk_efrm_service_config_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_service_name CHECK (((service_name)::text = ANY (ARRAY[('SCREENING'::character varying)::text, ('TRANSACTION'::character varying)::text, ('DEVICE'::character varying)::text, ('CASE'::character varying)::text, ('ADVERSE_MEDIA'::character varying)::text, ('ML_TRANSACTION'::character varying)::text, ('ML_DEVICE'::character varying)::text]))),
    CONSTRAINT efrm_service_config_mode_check CHECK (((mode)::text = ANY ((ARRAY['SYNC'::character varying, 'ASYNC'::character varying, 'BOTH'::character varying])::text[])))
);


--
-- Name: efrm_service_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.efrm_service_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: efrm_service_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.efrm_service_config_id_seq OWNED BY efrm.efrm_service_config.id;


--
-- Name: engine_attribute_def; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.engine_attribute_def (
    id integer NOT NULL,
    key_type character varying(1) NOT NULL,
    key character varying(64) NOT NULL,
    label character varying(128) NOT NULL,
    data_type character varying(16) NOT NULL,
    enum_source character varying(64),
    unit character varying(32),
    condition character varying(1),
    description character varying(64),
    context_code character varying(64) DEFAULT 'DEFAULT'::character varying NOT NULL
);


--
-- Name: engine_attribute_def_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.engine_attribute_def_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: engine_attribute_def_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.engine_attribute_def_id_seq OWNED BY efrm.engine_attribute_def.id;


--
-- Name: engine_flink_map_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.engine_flink_map_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: engine_flink_map; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.engine_flink_map (
    id integer DEFAULT nextval('efrm.engine_flink_map_seq'::regclass) NOT NULL,
    context_code character varying(64) DEFAULT 'DEFAULT'::character varying NOT NULL,
    rule_engine_key character varying(128),
    key_type character varying(1) NOT NULL,
    flink_event_key character varying(128) NOT NULL,
    label character varying(128) NOT NULL,
    data_type character varying(16) NOT NULL,
    description character varying(128),
    example_value character varying(128),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL
);


--
-- Name: entity_definition_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_definition_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_definition; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_definition (
    id integer DEFAULT nextval('efrm.entity_definition_seq'::regclass) NOT NULL,
    entity_type character varying(32) NOT NULL,
    rule_engine_key character varying(64) NOT NULL,
    entity_name character varying(128) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    context_code character varying(64) DEFAULT 'DEFAULT'::character varying NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL
);


--
-- Name: entity_device_map; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_device_map (
    entity_device_id bigint NOT NULL,
    entity_id bigint NOT NULL,
    device_fingerprint jsonb,
    channel character varying(30),
    source_system character varying(50),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    device_id character varying(200) NOT NULL
);


--
-- Name: COLUMN entity_device_map.entity_id; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_device_map.entity_id IS 'Reference to entity master';


--
-- Name: COLUMN entity_device_map.device_fingerprint; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_device_map.device_fingerprint IS 'Stable hash from mobile SDK / web SDK';


--
-- Name: COLUMN entity_device_map.channel; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_device_map.channel IS 'Channel: LOGIN, ONBOARDING, TRANSACTION';


--
-- Name: COLUMN entity_device_map.source_system; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_device_map.source_system IS 'Source system: MOBILE_APP, WEB_PORTAL, SDK';


--
-- Name: COLUMN entity_device_map.is_active; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_device_map.is_active IS 'Whether the device mapping is active: Y/N';


--
-- Name: COLUMN entity_device_map.created_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_device_map.created_at IS 'Creation timestamp';


--
-- Name: COLUMN entity_device_map.updated_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_device_map.updated_at IS 'Last update timestamp';


--
-- Name: entity_device_map_entity_device_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_device_map_entity_device_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_device_map_entity_device_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_device_map_entity_device_id_seq OWNED BY efrm.entity_device_map.entity_device_id;


--
-- Name: entity_graph_cluster_nodes; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_graph_cluster_nodes (
    id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    cluster_id bigint NOT NULL,
    node_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: entity_graph_cluster_nodes_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_graph_cluster_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_graph_cluster_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_graph_cluster_nodes_id_seq OWNED BY efrm.entity_graph_cluster_nodes.id;


--
-- Name: entity_graph_clusters; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_graph_clusters (
    cluster_id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    cluster_key character varying(128) NOT NULL,
    cluster_risk_score integer DEFAULT 0 NOT NULL,
    node_count integer DEFAULT 0 NOT NULL,
    edge_count integer DEFAULT 0 NOT NULL,
    high_risk_node_count integer DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    last_refreshed_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_entity_graph_clusters_status CHECK (((status)::text = ANY (ARRAY[('ACTIVE'::character varying)::text, ('STALE'::character varying)::text, ('ARCHIVED'::character varying)::text])))
);


--
-- Name: entity_graph_clusters_cluster_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_graph_clusters_cluster_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_graph_clusters_cluster_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_graph_clusters_cluster_id_seq OWNED BY efrm.entity_graph_clusters.cluster_id;


--
-- Name: entity_graph_edges; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_graph_edges (
    edge_id integer NOT NULL,
    source_node integer,
    target_node integer,
    relationship_type character varying(64) NOT NULL,
    strength_score integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    institution_id character varying(64),
    dimension_code character varying(64),
    confidence_score integer,
    occurrence_count integer DEFAULT 1 NOT NULL,
    evidence_count integer DEFAULT 0 NOT NULL,
    last_evidence_id bigint,
    valid_from timestamp with time zone,
    valid_to timestamp with time zone,
    decay_policy character varying(50),
    metadata jsonb,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: entity_graph_edges_edge_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_graph_edges_edge_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_graph_edges_edge_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_graph_edges_edge_id_seq OWNED BY efrm.entity_graph_edges.edge_id;


--
-- Name: entity_graph_evidence; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_graph_evidence (
    id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    edge_id integer NOT NULL,
    source_table character varying(100) NOT NULL,
    source_id character varying(128) NOT NULL,
    event_id integer,
    transaction_id character varying(64),
    case_id integer,
    rule_code character varying(64),
    risk_score integer,
    event_time timestamp with time zone,
    evidence_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: entity_graph_evidence_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_graph_evidence_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_graph_evidence_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_graph_evidence_id_seq OWNED BY efrm.entity_graph_evidence.id;


--
-- Name: entity_graph_nodes; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_graph_nodes (
    node_id integer NOT NULL,
    node_type character varying(32) NOT NULL,
    value character varying(256) NOT NULL,
    risk_score integer NOT NULL,
    meta_data jsonb NOT NULL,
    institution_id character varying(64),
    dimension_code character varying(64),
    hash_value character varying(128),
    masked_value character varying(256),
    encrypted_value text,
    label character varying(300),
    first_seen_at timestamp with time zone,
    last_seen_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: entity_graph_nodes_node_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_graph_nodes_node_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_graph_nodes_node_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_graph_nodes_node_id_seq OWNED BY efrm.entity_graph_nodes.node_id;


--
-- Name: entity_graph_refresh_checkpoint; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_graph_refresh_checkpoint (
    id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    source_table character varying(100) NOT NULL,
    dimension_code character varying(64) NOT NULL,
    last_processed_id bigint,
    last_processed_at timestamp with time zone,
    status character varying(20) DEFAULT 'SUCCESS'::character varying NOT NULL,
    error_message text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_entity_graph_refresh_checkpoint_status CHECK (((status)::text = ANY (ARRAY[('SUCCESS'::character varying)::text, ('FAILED'::character varying)::text, ('RUNNING'::character varying)::text])))
);


--
-- Name: entity_graph_refresh_checkpoint_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_graph_refresh_checkpoint_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_graph_refresh_checkpoint_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_graph_refresh_checkpoint_id_seq OWNED BY efrm.entity_graph_refresh_checkpoint.id;


--
-- Name: entity_graph_refresh_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_graph_refresh_config (
    id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    refresh_type character varying(50) NOT NULL,
    source_table character varying(100) NOT NULL,
    dimension_code character varying(64) NOT NULL,
    refresh_mode character varying(30) NOT NULL,
    refresh_interval_minutes integer NOT NULL,
    lookback_minutes integer,
    batch_size integer NOT NULL,
    enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    last_run_at timestamp with time zone,
    next_run_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_entity_graph_refresh_enabled CHECK (((enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_entity_graph_refresh_mode CHECK (((refresh_mode)::text = ANY (ARRAY[('INCREMENTAL'::character varying)::text, ('FULL'::character varying)::text]))),
    CONSTRAINT chk_entity_graph_refresh_type CHECK (((refresh_type)::text = ANY (ARRAY[('EDGE_REFRESH'::character varying)::text, ('CLUSTER_REFRESH'::character varying)::text, ('RECONCILIATION'::character varying)::text])))
);


--
-- Name: entity_graph_refresh_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_graph_refresh_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_graph_refresh_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_graph_refresh_config_id_seq OWNED BY efrm.entity_graph_refresh_config.id;


--
-- Name: entity_graph_view_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_graph_view_config (
    id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    view_type character varying(30) NOT NULL,
    default_layer_depth integer DEFAULT 2 NOT NULL,
    max_layer_depth integer DEFAULT 5 NOT NULL,
    max_nodes integer DEFAULT 500 NOT NULL,
    max_edges integer DEFAULT 1000 NOT NULL,
    enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_entity_graph_view_depth CHECK (((default_layer_depth >= 1) AND (max_layer_depth >= default_layer_depth))),
    CONSTRAINT chk_entity_graph_view_enabled CHECK (((enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_entity_graph_view_limits CHECK (((max_nodes > 0) AND (max_edges > 0))),
    CONSTRAINT chk_entity_graph_view_type CHECK (((view_type)::text = ANY (ARRAY[('CASE'::character varying)::text, ('GLOBAL'::character varying)::text])))
);


--
-- Name: entity_graph_view_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_graph_view_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_graph_view_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_graph_view_config_id_seq OWNED BY efrm.entity_graph_view_config.id;


--
-- Name: entity_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_master (
    entity_id bigint NOT NULL,
    entity_type character varying(50) NOT NULL,
    entity_group character varying(20),
    institution_id character varying(50) NOT NULL,
    source_system character varying(50) NOT NULL,
    channel character varying(50) NOT NULL,
    external_entity_id character varying(100) NOT NULL,
    name character varying(300) NOT NULL,
    normalized_name character varying(300),
    date_of_birth date,
    gender character varying(20),
    registration_number character varying(100),
    incorporation_date date,
    country character varying(2),
    address text,
    email character varying(200),
    phone_no character varying(30),
    metadata jsonb,
    last_screened_at timestamp without time zone,
    screening_status character varying(20),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(50),
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by character varying(50),
    risk_rating character varying(20) DEFAULT 'LOW'::character varying,
    last_device_location jsonb,
    last_transaction_details jsonb,
    CONSTRAINT ck_entity_group CHECK (((entity_group)::text = ANY (ARRAY[('PERSON'::character varying)::text, ('NON_PERSON'::character varying)::text])))
);


--
-- Name: COLUMN entity_master.entity_id; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.entity_id IS 'Entity primary key';


--
-- Name: COLUMN entity_master.entity_type; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.entity_type IS 'INDIVIDUAL, ORGANIZATION';


--
-- Name: COLUMN entity_master.entity_group; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.entity_group IS 'PERSON, NON_PERSON';


--
-- Name: COLUMN entity_master.institution_id; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.institution_id IS 'Institution identifier';


--
-- Name: COLUMN entity_master.source_system; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.source_system IS 'Source system name';


--
-- Name: COLUMN entity_master.channel; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.channel IS 'Channel identifier';


--
-- Name: COLUMN entity_master.external_entity_id; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.external_entity_id IS 'External entity identifier';


--
-- Name: COLUMN entity_master.name; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.name IS 'Entity name';


--
-- Name: COLUMN entity_master.normalized_name; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.normalized_name IS 'Normalized name for matching';


--
-- Name: COLUMN entity_master.date_of_birth; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.date_of_birth IS 'Date of birth (for individuals)';


--
-- Name: COLUMN entity_master.gender; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.gender IS 'Gender (for individuals)';


--
-- Name: COLUMN entity_master.registration_number; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.registration_number IS 'Registration number (for organizations)';


--
-- Name: COLUMN entity_master.incorporation_date; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.incorporation_date IS 'Incorporation date (for organizations)';


--
-- Name: COLUMN entity_master.country; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.country IS 'Country code (ISO 2-letter)';


--
-- Name: COLUMN entity_master.address; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.address IS 'Address';


--
-- Name: COLUMN entity_master.email; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.email IS 'Email address';


--
-- Name: COLUMN entity_master.phone_no; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.phone_no IS 'Phone number';


--
-- Name: COLUMN entity_master.metadata; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.metadata IS 'Flexible JSON metadata for entity attributes';


--
-- Name: COLUMN entity_master.last_screened_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.last_screened_at IS 'Last screening timestamp';


--
-- Name: COLUMN entity_master.screening_status; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.screening_status IS 'Screening status';


--
-- Name: COLUMN entity_master.is_active; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.is_active IS 'Whether the entity is active: Y/N';


--
-- Name: COLUMN entity_master.created_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.created_at IS 'Creation timestamp';


--
-- Name: COLUMN entity_master.created_by; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.created_by IS 'User who created the entity';


--
-- Name: COLUMN entity_master.updated_at; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.updated_at IS 'Last update timestamp';


--
-- Name: COLUMN entity_master.updated_by; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.updated_by IS 'User who last updated the entity';


--
-- Name: COLUMN entity_master.last_device_location; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.last_device_location IS 'Last known device location / context (JSON)';


--
-- Name: COLUMN entity_master.last_transaction_details; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_master.last_transaction_details IS 'Last transaction snapshot / details (JSON)';


--
-- Name: entity_master_entity_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_master_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_master_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_master_entity_id_seq OWNED BY efrm.entity_master.entity_id;


--
-- Name: entity_relation_map; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_relation_map (
    entity_relation_id bigint NOT NULL,
    entity_id bigint NOT NULL,
    relation_type character varying(50) NOT NULL,
    external_relation_id character varying(100),
    sub_type character varying(50),
    status character varying(30) DEFAULT 'ACTIVE'::character varying,
    opened_date date,
    closed_date date,
    risk_rating character varying(20) DEFAULT 'LOW'::character varying,
    relation_metadata json,
    institution_id character varying(50) NOT NULL,
    source_system character varying(50) NOT NULL,
    channel character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(50),
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by character varying(50)
);


--
-- Name: COLUMN entity_relation_map.entity_id; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.entity_relation_map.entity_id IS 'Reference to entity master';


--
-- Name: entity_relation_map_entity_relation_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_relation_map_entity_relation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_relation_map_entity_relation_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_relation_map_entity_relation_id_seq OWNED BY efrm.entity_relation_map.entity_relation_id;


--
-- Name: entity_risk_aggregate; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_risk_aggregate (
    institution_id character varying(64) NOT NULL,
    entity_id character varying(128) NOT NULL,
    txn_7d_score integer DEFAULT 0,
    txn_30d_score integer DEFAULT 0,
    txn_90d_score integer DEFAULT 0,
    device_30d_score integer DEFAULT 0,
    last_recalculated timestamp with time zone DEFAULT now() NOT NULL,
    screening_score integer DEFAULT 0,
    transaction_score integer DEFAULT 0,
    device_score integer DEFAULT 0,
    case_score integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    latest_screening_date timestamp with time zone,
    latest_transaction_date timestamp with time zone,
    latest_device_date timestamp with time zone,
    latest_case_date timestamp with time zone,
    screening_event_count integer DEFAULT 0,
    transaction_event_count integer DEFAULT 0,
    device_event_count integer DEFAULT 0,
    case_event_count integer DEFAULT 0,
    adverse_media_score integer DEFAULT 0,
    adverse_media_event_count integer DEFAULT 0,
    latest_adverse_media_date timestamp with time zone
);


--
-- Name: entity_risk_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_risk_config (
    id integer NOT NULL,
    config_key character varying(100) NOT NULL,
    config_value numeric(5,2) NOT NULL,
    description text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: entity_risk_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_risk_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_risk_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_risk_config_id_seq OWNED BY efrm.entity_risk_config.id;


--
-- Name: entity_risk_factor_breakdown; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_risk_factor_breakdown (
    id integer NOT NULL,
    institution_id character varying(64) NOT NULL,
    entity_id character varying(128) NOT NULL,
    source_type character varying(50) NOT NULL,
    factor_name character varying(200) NOT NULL,
    category character varying(50) NOT NULL,
    factor_score integer NOT NULL,
    weight numeric(6,4) NOT NULL,
    contribution integer NOT NULL,
    reference_id character varying(100) NOT NULL,
    model_version character varying(50),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    event_id integer,
    risk_domain character varying(50),
    factor_category character varying(50),
    CONSTRAINT entity_risk_factor_score_check CHECK (((factor_score >= 0) AND (factor_score <= 1000)))
);


--
-- Name: entity_risk_factor_breakdown_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_risk_factor_breakdown_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_risk_factor_breakdown_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_risk_factor_breakdown_id_seq OWNED BY efrm.entity_risk_factor_breakdown.id;


--
-- Name: entity_risk_history; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_risk_history (
    id integer NOT NULL,
    institution_id character varying(64) NOT NULL,
    entity_id character varying(128) NOT NULL,
    event_source character varying(50),
    change_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    event_type character varying(100),
    identity_domain_score integer,
    financial_domain_score integer,
    device_domain_score integer,
    investigation_domain_score integer,
    final_score integer,
    risk_tier character varying(20)
);


--
-- Name: entity_risk_history_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_risk_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_risk_history_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_risk_history_id_seq OWNED BY efrm.entity_risk_history.id;


--
-- Name: entity_risk_profile; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.entity_risk_profile (
    id integer NOT NULL,
    institution_id character varying(64) NOT NULL,
    entity_id character varying(128) NOT NULL,
    identity_domain_score integer DEFAULT 0,
    financial_domain_score integer DEFAULT 0,
    device_domain_score integer DEFAULT 0,
    investigation_domain_score integer DEFAULT 0,
    final_score integer NOT NULL,
    risk_tier character varying(20) NOT NULL,
    trend character varying(20),
    model_version character varying(50),
    last_event_source character varying(50),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_updated timestamp with time zone DEFAULT now() NOT NULL,
    risk_status character varying(30),
    peak_score integer DEFAULT 0,
    peak_score_date timestamp with time zone,
    last_escalation_date timestamp with time zone,
    last_review_date timestamp with time zone,
    risk_explanation jsonb,
    CONSTRAINT entity_risk_profile_score_check CHECK (((final_score >= 0) AND (final_score <= 1000)))
);


--
-- Name: entity_risk_profile_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.entity_risk_profile_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: entity_risk_profile_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.entity_risk_profile_id_seq OWNED BY efrm.entity_risk_profile.id;


--
-- Name: enum_value; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.enum_value (
    id integer NOT NULL,
    facts character varying(64) NOT NULL,
    enum_key character varying(64) NOT NULL,
    value character varying(128) NOT NULL,
    label character varying(128) NOT NULL
);


--
-- Name: enum_value_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.enum_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: enum_value_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.enum_value_id_seq OWNED BY efrm.enum_value.id;


--
-- Name: facts_definition; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.facts_definition (
    id integer NOT NULL,
    source_system_id integer NOT NULL,
    facts character varying(64) NOT NULL,
    context_code character varying(64) DEFAULT 'DEFAULT'::character varying NOT NULL,
    description character varying(64) NOT NULL
);


--
-- Name: facts_definition_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.facts_definition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facts_definition_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.facts_definition_id_seq OWNED BY efrm.facts_definition.id;


--
-- Name: graph_dimension_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.graph_dimension_config (
    id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    entity_type character varying(64) NOT NULL,
    node_type character varying(64) NOT NULL,
    source_table character varying(100) NOT NULL,
    source_column character varying(100),
    json_path character varying(300),
    relationship_type character varying(100) NOT NULL,
    confidence_weight integer DEFAULT 50 NOT NULL,
    decay_policy character varying(50) DEFAULT 'NONE'::character varying NOT NULL,
    lookback_days integer,
    min_shared_count integer DEFAULT 2 NOT NULL,
    max_expansion_count integer DEFAULT 100 NOT NULL,
    masking_policy character varying(50) DEFAULT 'NONE'::character varying NOT NULL,
    enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_graph_dimension_confidence CHECK (((confidence_weight >= 0) AND (confidence_weight <= 100))),
    CONSTRAINT chk_graph_dimension_config_enabled CHECK (((enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_graph_dimension_source CHECK (((source_column IS NOT NULL) OR (json_path IS NOT NULL)))
);


--
-- Name: graph_dimension_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.graph_dimension_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: graph_dimension_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.graph_dimension_config_id_seq OWNED BY efrm.graph_dimension_config.id;


--
-- Name: graph_dimension_subtype_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.graph_dimension_subtype_config (
    id bigint NOT NULL,
    institution_id character varying(64) NOT NULL,
    entity_type character varying(64) NOT NULL,
    source_table character varying(100) NOT NULL,
    subtype_column character varying(100) NOT NULL,
    subtype_value character varying(100) NOT NULL,
    subtype_label character varying(200),
    enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_graph_dimension_subtype_enabled CHECK (((enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: graph_dimension_subtype_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.graph_dimension_subtype_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: graph_dimension_subtype_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.graph_dimension_subtype_config_id_seq OWNED BY efrm.graph_dimension_subtype_config.id;


--
-- Name: institution; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.institution (
    institution_id character varying(12) NOT NULL,
    institution_code character varying(12) NOT NULL,
    institution_name character varying(45) NOT NULL,
    institution_type character varying(3) NOT NULL,
    base_currency_code character varying(3) NOT NULL,
    alpha_currency_code character varying(3) NOT NULL,
    alpha_2_country_code character varying(2) NOT NULL,
    alpha_3_country_code character varying(3) NOT NULL,
    country_code character varying(3) NOT NULL,
    logo_url character varying(255),
    support_email character varying(100),
    support_phone character varying(20),
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    status character varying(1) NOT NULL
);


--
-- Name: institution_type; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.institution_type (
    id integer NOT NULL,
    institution_type character varying(12) NOT NULL,
    description character varying(45) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL
);


--
-- Name: institution_type_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.institution_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: institution_type_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.institution_type_id_seq OWNED BY efrm.institution_type.id;


--
-- Name: integration_endpoint_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.integration_endpoint_config (
    endpoint_config_id bigint NOT NULL,
    institution_id character varying(64) DEFAULT 'DEFAULT'::character varying NOT NULL,
    action_code character varying(64) NOT NULL,
    target_system character varying(64) NOT NULL,
    http_method character varying(10) DEFAULT 'POST'::character varying NOT NULL,
    endpoint_url text NOT NULL,
    headers_template jsonb,
    payload_template jsonb,
    auth_type character varying(32),
    success_status_codes character varying(200) DEFAULT '200,201,202'::character varying NOT NULL,
    timeout_seconds integer DEFAULT 30 NOT NULL,
    retry_count integer DEFAULT 3 NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: integration_endpoint_config_endpoint_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.integration_endpoint_config_endpoint_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: integration_endpoint_config_endpoint_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.integration_endpoint_config_endpoint_config_id_seq OWNED BY efrm.integration_endpoint_config.endpoint_config_id;


--
-- Name: list_entity; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.list_entity (
    id bigint NOT NULL,
    list_version_id bigint NOT NULL,
    external_id text,
    name text NOT NULL,
    entity_type character varying(32),
    date_of_birth text,
    country text,
    raw_data jsonb,
    normalized_name text,
    phonetic_key character varying(256),
    created_at timestamp without time zone NOT NULL,
    identifiers text,
    dataset text,
    address text,
    name_arabic text,
    normalized_name_arabic text,
    transliterated_name text,
    script_type character varying(8)
);


--
-- Name: list_entity_alias; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.list_entity_alias (
    id bigint NOT NULL,
    list_entity_id bigint NOT NULL,
    alias_name text NOT NULL,
    normalized_alias text,
    phonetic_key character varying(256),
    created_at timestamp without time zone NOT NULL,
    alias_arabic text,
    transliterated_alias text
);


--
-- Name: list_entity_alias_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.list_entity_alias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_entity_alias_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.list_entity_alias_id_seq OWNED BY efrm.list_entity_alias.id;


--
-- Name: list_entity_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.list_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.list_entity_id_seq OWNED BY efrm.list_entity.id;


--
-- Name: list_normalized_address; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.list_normalized_address (
    id bigint NOT NULL,
    list_entity_id bigint NOT NULL,
    normalized_address text NOT NULL,
    address_tokens text[],
    postal_code text,
    city text,
    country text,
    house_number text,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: list_normalized_address_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.list_normalized_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_normalized_address_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.list_normalized_address_id_seq OWNED BY efrm.list_normalized_address.id;


--
-- Name: list_source; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.list_source (
    id bigint NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(256) NOT NULL,
    source_type character varying(32) NOT NULL,
    fetch_mode character varying(32) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL
);


--
-- Name: list_source_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.list_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_source_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.list_source_id_seq OWNED BY efrm.list_source.id;


--
-- Name: list_version; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.list_version (
    id bigint NOT NULL,
    list_source_id bigint NOT NULL,
    version_tag character varying(128) NOT NULL,
    loaded_at timestamp without time zone NOT NULL,
    record_count bigint NOT NULL,
    checksum character varying(128),
    status character varying(32) NOT NULL,
    error_message text,
    source_config_id bigint,
    source_code character varying(64)
);


--
-- Name: list_version_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.list_version_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_version_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.list_version_id_seq OWNED BY efrm.list_version.id;


--
-- Name: login_attempt; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.login_attempt (
    attempt_id character varying(64) NOT NULL,
    user_id character varying(128),
    attempted_username_hash character varying(128),
    security_check_id character varying(32),
    ip_address character varying(45) NOT NULL,
    attempt_at timestamp with time zone NOT NULL,
    outcome character varying(16) NOT NULL,
    failure_reason character varying(128),
    device_fingerprint character varying(128),
    user_agent character varying(512),
    is_suspicious character varying(1) NOT NULL
);


--
-- Name: menu_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.menu_master (
    menu_id character varying(128) NOT NULL,
    menu_name character varying(128) NOT NULL,
    menu_description character varying(128) NOT NULL,
    product_id character varying(12) NOT NULL,
    parent_id character varying(128),
    treeid integer NOT NULL,
    visibility character varying(1) NOT NULL,
    mak_chk_enabled character varying(1) NOT NULL,
    menu_action character varying(128) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL
);


--
-- Name: metric_definition_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.metric_definition_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metric_definition; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.metric_definition (
    id integer DEFAULT nextval('efrm.metric_definition_seq'::regclass) NOT NULL,
    metric_code character varying(64) NOT NULL,
    metric_name character varying(128) NOT NULL,
    entity_type character varying(32) NOT NULL,
    direction character varying(16),
    channel character varying(32),
    window_type character varying(16) NOT NULL,
    window_size character varying(16) NOT NULL,
    data_type character varying(16) NOT NULL,
    description character varying(256),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    aggregation_type character varying(16) DEFAULT 'SUM'::character varying NOT NULL,
    context_code character varying(64) DEFAULT 'DEFAULT'::character varying NOT NULL,
    sql_statement text,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: ml_audit_event_audit_event_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_audit_event_audit_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_audit_event; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_audit_event (
    audit_event_id bigint DEFAULT nextval('efrm.ml_audit_event_audit_event_id_seq'::regclass) NOT NULL,
    institution_id character varying(100) NOT NULL,
    aggregate_type character varying(50) NOT NULL,
    aggregate_id character varying(100) NOT NULL,
    event_type character varying(100) NOT NULL,
    event_data jsonb NOT NULL,
    actor_id character varying(100) NOT NULL,
    correlation_id character varying(100),
    previous_hash character varying(64),
    event_hash character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: ml_data_generation_record_generation_record_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_data_generation_record_generation_record_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_data_generation_record; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_data_generation_record (
    generation_record_id bigint DEFAULT nextval('efrm.ml_data_generation_record_generation_record_id_seq'::regclass) NOT NULL,
    generation_run_id bigint NOT NULL,
    entity_type character varying(80) NOT NULL,
    entity_id character varying(120) NOT NULL,
    payload_hash character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: TABLE ml_data_generation_record; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON TABLE efrm.ml_data_generation_record IS 'Generated entity ownership map used for scoped reset and provenance.';


--
-- Name: ml_data_generation_run_generation_run_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_data_generation_run_generation_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_data_generation_run; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_data_generation_run (
    generation_run_id bigint DEFAULT nextval('efrm.ml_data_generation_run_generation_run_id_seq'::regclass) NOT NULL,
    run_code character varying(64) NOT NULL,
    institution_id character varying(100) NOT NULL,
    scenario_pack_version character varying(30) NOT NULL,
    random_seed integer NOT NULL,
    status character varying(30) NOT NULL,
    requested_manifest jsonb NOT NULL,
    applied_manifest jsonb,
    created_by character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    completed_at timestamp with time zone,
    error_message text,
    CONSTRAINT ml_data_generation_run_status_check CHECK (((status)::text = ANY ((ARRAY['PLANNED'::character varying, 'RUNNING'::character varying, 'COMPLETED'::character varying, 'FAILED'::character varying, 'RESET'::character varying])::text[])))
);


--
-- Name: TABLE ml_data_generation_run; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON TABLE efrm.ml_data_generation_run IS 'Non-production reference-data generation execution and manifest.';


--
-- Name: ml_deployment_allocation_deployment_allocation_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_deployment_allocation_deployment_allocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_deployment_allocation; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_deployment_allocation (
    deployment_allocation_id bigint DEFAULT nextval('efrm.ml_deployment_allocation_deployment_allocation_id_seq'::regclass) NOT NULL,
    deployment_plan_id bigint NOT NULL,
    routing_key_value character varying(255) NOT NULL,
    routing_bucket integer NOT NULL,
    model_version_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ml_deployment_allocation_routing_bucket_check CHECK (((routing_bucket >= 0) AND (routing_bucket <= 9999)))
);


--
-- Name: ml_deployment_event_deployment_event_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_deployment_event_deployment_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_deployment_event; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_deployment_event (
    deployment_event_id bigint DEFAULT nextval('efrm.ml_deployment_event_deployment_event_id_seq'::regclass) NOT NULL,
    deployment_plan_id bigint NOT NULL,
    event_type character varying(50) NOT NULL,
    from_status character varying(30),
    to_status character varying(30),
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    actor_id character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: ml_deployment_plan_deployment_plan_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_deployment_plan_deployment_plan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_deployment_plan; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_deployment_plan (
    deployment_plan_id bigint DEFAULT nextval('efrm.ml_deployment_plan_deployment_plan_id_seq'::regclass) NOT NULL,
    model_id bigint NOT NULL,
    target_model_version_id bigint NOT NULL,
    baseline_model_version_id bigint,
    strategy character varying(30) NOT NULL,
    status character varying(30) DEFAULT 'DRAFT'::character varying NOT NULL,
    routing_key character varying(50) DEFAULT 'transaction_id'::character varying NOT NULL,
    current_percentage integer DEFAULT 0 NOT NULL,
    guardrails jsonb DEFAULT '{}'::jsonb NOT NULL,
    change_reason text NOT NULL,
    row_revision integer DEFAULT 1 NOT NULL,
    created_by character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    approved_by character varying(100),
    approved_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    rolled_back_by character varying(100),
    rolled_back_at timestamp with time zone,
    CONSTRAINT ck_ml_deployment_distinct_versions CHECK ((target_model_version_id <> baseline_model_version_id)),
    CONSTRAINT ck_ml_deployment_plan_baseline_strategy CHECK (((upper((strategy)::text) = 'SHADOW'::text) OR (baseline_model_version_id IS NOT NULL))),
    CONSTRAINT ml_deployment_plan_current_percentage_check CHECK (((current_percentage >= 0) AND (current_percentage <= 100))),
    CONSTRAINT ml_deployment_plan_row_revision_check CHECK ((row_revision > 0)),
    CONSTRAINT ml_deployment_plan_status_check CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'APPROVED'::character varying, 'RUNNING'::character varying, 'PAUSED'::character varying, 'COMPLETED'::character varying, 'ROLLED_BACK'::character varying, 'REJECTED'::character varying, 'FAILED'::character varying])::text[]))),
    CONSTRAINT ml_deployment_plan_strategy_check CHECK (((strategy)::text = ANY ((ARRAY['SHADOW'::character varying, 'CANARY'::character varying, 'A_B'::character varying, 'BLUE_GREEN'::character varying])::text[])))
);


--
-- Name: ml_deployment_stage_deployment_stage_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_deployment_stage_deployment_stage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_deployment_stage; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_deployment_stage (
    deployment_stage_id bigint DEFAULT nextval('efrm.ml_deployment_stage_deployment_stage_id_seq'::regclass) NOT NULL,
    deployment_plan_id bigint NOT NULL,
    stage_order integer NOT NULL,
    traffic_percentage integer NOT NULL,
    minimum_observations integer DEFAULT 100 NOT NULL,
    minimum_duration_minutes integer DEFAULT 15 NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    CONSTRAINT ml_deployment_stage_minimum_duration_minutes_check CHECK ((minimum_duration_minutes >= 0)),
    CONSTRAINT ml_deployment_stage_minimum_observations_check CHECK ((minimum_observations >= 0)),
    CONSTRAINT ml_deployment_stage_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACTIVE'::character varying, 'COMPLETED'::character varying, 'SKIPPED'::character varying, 'FAILED'::character varying])::text[]))),
    CONSTRAINT ml_deployment_stage_traffic_percentage_check CHECK (((traffic_percentage >= 0) AND (traffic_percentage <= 100)))
);


--
-- Name: ml_feature_definition; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_feature_definition (
    feature_id integer NOT NULL,
    feature_set_version_id integer NOT NULL,
    feature_name character varying(100) NOT NULL,
    feature_type character varying(20) NOT NULL,
    source_type character varying(30) NOT NULL,
    source_field character varying(100) NOT NULL,
    transformation character varying(50),
    default_value character varying(50),
    required character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    display_name character varying(150),
    feature_group character varying(50),
    description text,
    is_active boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    feature_order integer NOT NULL,
    CONSTRAINT ck_ml_feature_definition_order_positive CHECK ((feature_order > 0))
);


--
-- Name: ml_feature_definition_feature_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_feature_definition_feature_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_feature_definition_feature_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_feature_definition_feature_id_seq OWNED BY efrm.ml_feature_definition.feature_id;


--
-- Name: ml_feature_definition_metadata; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_feature_definition_metadata (
    feature_metadata_id integer NOT NULL,
    feature_id integer NOT NULL,
    source_aliases jsonb,
    transform_params jsonb,
    null_strategy character varying(30) DEFAULT 'default_value'::character varying,
    null_fill_value character varying(50),
    cast_type character varying(20),
    feature_order integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    computation_type character varying(30),
    computation_config jsonb,
    required_input_fields jsonb,
    formula_description text
);


--
-- Name: ml_feature_definition_metadata_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_feature_definition_metadata_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_feature_definition_metadata_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_feature_definition_metadata_seq OWNED BY efrm.ml_feature_definition_metadata.feature_metadata_id;


--
-- Name: ml_feature_set; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_feature_set (
    feature_set_id integer NOT NULL,
    feature_set_code character varying(50) NOT NULL,
    feature_set_name character varying(100) NOT NULL,
    domain character varying(50) NOT NULL,
    description text,
    status character varying(20) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_by character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ml_feature_set_feature_set_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_feature_set_feature_set_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_feature_set_feature_set_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_feature_set_feature_set_id_seq OWNED BY efrm.ml_feature_set.feature_set_id;


--
-- Name: ml_feature_set_version; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_feature_set_version (
    feature_set_version_id integer NOT NULL,
    feature_set_id integer NOT NULL,
    version character varying(20) NOT NULL,
    change_summary text,
    created_by character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    status character varying(20) DEFAULT 'DRAFT'::character varying NOT NULL,
    validation_status character varying(20) DEFAULT 'NOT_VALIDATED'::character varying NOT NULL,
    validation_report jsonb,
    validated_by character varying(64),
    validated_at timestamp with time zone,
    row_revision integer DEFAULT 1 NOT NULL,
    retired_by character varying(64),
    retired_at timestamp with time zone,
    CONSTRAINT ck_ml_feature_set_version_row_revision CHECK ((row_revision > 0)),
    CONSTRAINT ck_ml_feature_set_version_status CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'VALIDATING'::character varying, 'ACTIVE'::character varying, 'REJECTED'::character varying, 'RETIRED'::character varying])::text[]))),
    CONSTRAINT ck_ml_feature_set_version_validation_status CHECK (((validation_status)::text = ANY ((ARRAY['NOT_VALIDATED'::character varying, 'VALID'::character varying, 'INVALID'::character varying])::text[])))
);


--
-- Name: ml_feature_set_version_feature_set_version_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_feature_set_version_feature_set_version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_feature_set_version_feature_set_version_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_feature_set_version_feature_set_version_id_seq OWNED BY efrm.ml_feature_set_version.feature_set_version_id;


--
-- Name: ml_feedback; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_feedback (
    feedback_id integer NOT NULL,
    inference_id integer NOT NULL,
    feedback_type character varying(30),
    notes text,
    submitted_by character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ml_feedback_feedback_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_feedback_feedback_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_feedback_feedback_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_feedback_feedback_id_seq OWNED BY efrm.ml_feedback.feedback_id;


--
-- Name: ml_inference_result; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_inference_result (
    inference_id integer NOT NULL,
    transaction_id character varying(100) NOT NULL,
    model_version_id integer NOT NULL,
    anomaly_score numeric(6,4),
    risk_band character varying(20),
    ml_engine_decision character varying(20),
    decision_time_ms integer,
    status character varying(30) DEFAULT 'pending'::character varying,
    case_id character varying(50),
    reviewed_by character varying(100),
    reviewed_at timestamp with time zone,
    notes text,
    top_features jsonb,
    explainability jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    institution_id character varying(50),
    source_system character varying(50),
    channel character varying(50),
    payload_snapshot jsonb,
    is_live character varying(1) DEFAULT 'Y'::character varying,
    raw_model_score numeric(12,8),
    feature_vector jsonb,
    CONSTRAINT ck_ml_inference_result_decision CHECK (((ml_engine_decision IS NULL) OR ((ml_engine_decision)::text = ANY ((ARRAY['ALLOW'::character varying, 'REVIEW'::character varying, 'BLOCK'::character varying])::text[])))),
    CONSTRAINT ck_ml_inference_result_risk_band CHECK (((risk_band IS NULL) OR ((risk_band)::text = ANY ((ARRAY['LOW'::character varying, 'MEDIUM'::character varying, 'HIGH'::character varying, 'CRITICAL'::character varying])::text[])))),
    CONSTRAINT ck_ml_inference_result_status CHECK (((status IS NULL) OR ((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACCEPTED'::character varying, 'RUNNING'::character varying, 'COMPLETED'::character varying, 'FAILED'::character varying, 'SKIPPED'::character varying])::text[]))))
);


--
-- Name: COLUMN ml_inference_result.raw_model_score; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.ml_inference_result.raw_model_score IS 'Raw estimator score before normalized anomaly-score mapping.';


--
-- Name: COLUMN ml_inference_result.feature_vector; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.ml_inference_result.feature_vector IS 'Exact ordered feature names and numeric values supplied to the model.';


--
-- Name: ml_inference_result_inference_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_inference_result_inference_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_inference_result_inference_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_inference_result_inference_id_seq OWNED BY efrm.ml_inference_result.inference_id;


--
-- Name: ml_inference_review_review_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_inference_review_review_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_inference_review; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_inference_review (
    review_id bigint DEFAULT nextval('efrm.ml_inference_review_review_id_seq'::regclass) NOT NULL,
    inference_id bigint NOT NULL,
    review_action character varying(30) NOT NULL,
    case_id character varying(100),
    notes text,
    reviewed_by character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_ml_inference_review_action CHECK (((review_action)::text = ANY ((ARRAY['TRUE_POSITIVE'::character varying, 'TRUE_NEGATIVE'::character varying, 'FALSE_POSITIVE'::character varying, 'FALSE_NEGATIVE'::character varying, 'LINK_CASE'::character varying, 'NOTE'::character varying])::text[])))
);


--
-- Name: ml_inference_shap_local; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_inference_shap_local (
    inference_shap_local_id integer NOT NULL,
    inference_id integer NOT NULL,
    model_version_id integer NOT NULL,
    feature_name character varying(100) NOT NULL,
    shap_value numeric(10,6),
    abs_shap_value numeric(10,6),
    importance_rank integer NOT NULL,
    is_top5 character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ml_inference_shap_local_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_inference_shap_local_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_inference_shap_local_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_inference_shap_local_seq OWNED BY efrm.ml_inference_shap_local.inference_shap_local_id;


--
-- Name: ml_job_dead_letter; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_job_dead_letter (
    dead_letter_id bigint NOT NULL,
    model_job_id bigint,
    external_job_key character varying(255),
    job_type character varying(100) NOT NULL,
    payload_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    error_message text NOT NULL,
    attempt_count integer NOT NULL,
    failed_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resolved_by character varying(255),
    resolved_at timestamp with time zone,
    resolution_notes text
);


--
-- Name: ml_job_dead_letter_dead_letter_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_job_dead_letter_dead_letter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_job_dead_letter_dead_letter_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_job_dead_letter_dead_letter_id_seq OWNED BY efrm.ml_job_dead_letter.dead_letter_id;


--
-- Name: ml_job_execution_state; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_job_execution_state (
    model_job_id bigint NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 3 NOT NULL,
    available_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    lease_owner character varying(255),
    lease_expires_at timestamp with time zone,
    last_error text,
    completed_at timestamp with time zone,
    dead_lettered_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ml_job_execution_state_attempt_count_check CHECK ((attempt_count >= 0)),
    CONSTRAINT ml_job_execution_state_max_attempts_check CHECK (((max_attempts >= 1) AND (max_attempts <= 20)))
);


--
-- Name: ml_model_drift_summary; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_drift_summary (
    model_drift_summary_id integer NOT NULL,
    model_version_id integer NOT NULL,
    overall_psi numeric(6,4),
    psi_threshold numeric(6,4),
    concept_drift numeric(6,4),
    prediction_drift numeric(6,4),
    status character varying(20),
    baseline_period character varying(50),
    current_period character varying(50),
    last_calculated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ml_model_drift_summary_model_drift_summary_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_model_drift_summary_model_drift_summary_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_model_drift_summary_model_drift_summary_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_model_drift_summary_model_drift_summary_id_seq OWNED BY efrm.ml_model_drift_summary.model_drift_summary_id;


--
-- Name: ml_model_explainability_profile; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_explainability_profile (
    explainability_profile_id bigint CONSTRAINT ml_model_explainability_prof_explainability_profile_id_not_null NOT NULL,
    model_version_id bigint NOT NULL,
    feature_set_version_id bigint NOT NULL,
    method character varying(50) NOT NULL,
    background_artifact_path character varying(1000) CONSTRAINT ml_model_explainability_profi_background_artifact_path_not_null NOT NULL,
    background_checksum character varying(64) NOT NULL,
    background_row_count integer NOT NULL,
    score_quantiles jsonb NOT NULL,
    created_by character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_ml_model_explainability_background_rows CHECK ((background_row_count > 0)),
    CONSTRAINT ck_ml_model_explainability_method CHECK (((method)::text = 'SHAP_PERMUTATION'::text)),
    CONSTRAINT ck_ml_model_explainability_quantiles_object CHECK ((jsonb_typeof(score_quantiles) = 'object'::text))
);


--
-- Name: ml_model_explainability_profile_explainability_profile_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

ALTER TABLE efrm.ml_model_explainability_profile ALTER COLUMN explainability_profile_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME efrm.ml_model_explainability_profile_explainability_profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ml_model_feature_drift; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_feature_drift (
    model_feature_drift_id integer NOT NULL,
    model_version_id integer NOT NULL,
    feature_name character varying(100),
    psi numeric(6,4),
    psi_threshold numeric(6,4),
    ks_statistic numeric(6,4),
    status character varying(20),
    baseline_stats jsonb,
    current_stats jsonb,
    last_stable_date timestamp with time zone
);


--
-- Name: ml_model_feature_drift_model_feature_drift_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_model_feature_drift_model_feature_drift_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_model_feature_drift_model_feature_drift_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_model_feature_drift_model_feature_drift_id_seq OWNED BY efrm.ml_model_feature_drift.model_feature_drift_id;


--
-- Name: ml_model_governance; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_governance (
    model_governance_id integer NOT NULL,
    model_version_id integer NOT NULL,
    model_owner character varying(100),
    model_owner_email character varying(100),
    reviewer character varying(100),
    reviewer_email character varying(100),
    model_risk_tier character varying(20),
    model_risk_score integer,
    regulatory_framework jsonb,
    approval_document_id character varying(100),
    review_frequency character varying(20),
    last_reviewed_at timestamp with time zone,
    next_review_date timestamp with time zone,
    expiration_date timestamp with time zone,
    compliance_status jsonb,
    overall_compliance_score numeric(5,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ml_model_governance_model_governance_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_model_governance_model_governance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_model_governance_model_governance_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_model_governance_model_governance_id_seq OWNED BY efrm.ml_model_governance.model_governance_id;


--
-- Name: ml_model_job; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_job (
    model_job_id integer NOT NULL,
    model_version_id integer NOT NULL,
    job_type character varying(50) NOT NULL,
    job_status character varying(50) NOT NULL,
    total_records bigint DEFAULT 0,
    processed_records bigint DEFAULT 0,
    failed_records bigint DEFAULT 0,
    file_path character varying(512),
    created_by character varying(64),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    error_message text,
    error_reason text,
    job_result jsonb
);


--
-- Name: ml_model_job_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_model_job_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_model_job_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_model_job_seq OWNED BY efrm.ml_model_job.model_job_id;


--
-- Name: ml_model_performance_daily; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_performance_daily (
    model_performance_daily_id integer NOT NULL,
    model_version_id integer NOT NULL,
    metric_date date NOT NULL,
    true_positive integer,
    true_negative integer,
    false_positive integer,
    false_negative integer,
    "precision" numeric(6,4),
    recall numeric(6,4),
    f1_score numeric(6,4),
    roc_auc numeric(6,4),
    false_positive_rate numeric(6,4),
    latency_p95_ms numeric(8,2),
    throughput integer
);


--
-- Name: ml_model_performance_daily_model_performance_daily_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_model_performance_daily_model_performance_daily_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_model_performance_daily_model_performance_daily_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_model_performance_daily_model_performance_daily_id_seq OWNED BY efrm.ml_model_performance_daily.model_performance_daily_id;


--
-- Name: ml_model_registry; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_registry (
    model_id integer NOT NULL,
    institution_id character varying(50) NOT NULL,
    group_name character varying(100) NOT NULL,
    source_system character varying(50) NOT NULL,
    channel character varying(50) NOT NULL,
    model_purpose character varying(50) NOT NULL,
    model_type character varying(50) NOT NULL,
    status character varying(20) NOT NULL,
    created_by character varying(64) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ml_model_registry_model_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_model_registry_model_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_model_registry_model_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_model_registry_model_id_seq OWNED BY efrm.ml_model_registry.model_id;


--
-- Name: ml_model_runtime_metrics; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_runtime_metrics (
    model_runtime_metrics_id integer NOT NULL,
    model_version_id integer NOT NULL,
    window_start timestamp with time zone NOT NULL,
    window_end timestamp with time zone NOT NULL,
    prediction_count integer,
    anomaly_count integer,
    latency_avg_ms numeric(8,2),
    latency_p95_ms numeric(8,2),
    latency_p99_ms numeric(8,2),
    throughput_tps numeric(8,2),
    error_rate numeric(6,4),
    uptime_percentage numeric(5,2)
);


--
-- Name: ml_model_runtime_metrics_model_runtime_metrics_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_model_runtime_metrics_model_runtime_metrics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_model_runtime_metrics_model_runtime_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_model_runtime_metrics_model_runtime_metrics_id_seq OWNED BY efrm.ml_model_runtime_metrics.model_runtime_metrics_id;


--
-- Name: ml_model_shap_global; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_shap_global (
    model_shap_global_id integer NOT NULL,
    model_version_id integer NOT NULL,
    feature_name character varying(100),
    feature_type character varying(20),
    mean_shap numeric(8,6),
    mean_abs_shap numeric(8,6),
    importance_rank integer,
    interaction_data jsonb,
    last_calculated_at timestamp with time zone
);


--
-- Name: ml_model_shap_global_model_shap_global_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_model_shap_global_model_shap_global_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_model_shap_global_model_shap_global_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_model_shap_global_model_shap_global_id_seq OWNED BY efrm.ml_model_shap_global.model_shap_global_id;


--
-- Name: ml_model_simulation_sample; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_simulation_sample (
    simulation_sample_id bigint NOT NULL,
    model_version_id bigint NOT NULL,
    sample_code character varying(50) NOT NULL,
    sample_name character varying(255) NOT NULL,
    input_payload jsonb NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    source_dataset_ref text,
    source_row_hash character varying(64) NOT NULL,
    created_by character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_ml_model_simulation_sample_payload_object CHECK ((jsonb_typeof(input_payload) = 'object'::text))
);


--
-- Name: ml_model_simulation_sample_simulation_sample_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

ALTER TABLE efrm.ml_model_simulation_sample ALTER COLUMN simulation_sample_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME efrm.ml_model_simulation_sample_simulation_sample_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ml_model_version; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_model_version (
    model_version_id integer NOT NULL,
    model_id integer NOT NULL,
    feature_set_version_id integer,
    version character varying(20) NOT NULL,
    is_production boolean DEFAULT false,
    is_champion boolean DEFAULT false,
    artifact_path character varying(500) NOT NULL,
    artifact_checksum character varying(128),
    deployment_mode character varying(20),
    training_data_range character varying(100),
    training_duration_hours numeric(6,2),
    feature_count integer,
    training_samples integer,
    validation_samples integer,
    test_samples integer,
    approval_status character varying(30),
    approved_by character varying(100),
    approval_date timestamp with time zone,
    rollback_version character varying(20),
    rollout_percentage integer DEFAULT 100,
    deployed_at timestamp with time zone DEFAULT now() NOT NULL,
    scaler_artifact_path character varying(500),
    algorithm_name character varying(50),
    hyperparameters jsonb,
    training_metrics jsonb,
    registered_by character varying(100) NOT NULL,
    registered_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    submitted_by character varying(100),
    submitted_at timestamp with time zone,
    review_comment text,
    row_revision integer DEFAULT 1 NOT NULL,
    CONSTRAINT ck_ml_model_version_artifact_checksum_format CHECK (((artifact_checksum IS NULL) OR ((artifact_checksum)::text ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT ck_ml_production_artifact_checksum_required CHECK (((NOT (is_production OR is_champion)) OR (artifact_checksum IS NOT NULL)))
);


--
-- Name: ml_model_version_model_version_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_model_version_model_version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_model_version_model_version_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_model_version_model_version_id_seq OWNED BY efrm.ml_model_version.model_version_id;


--
-- Name: ml_monitoring_alert_alert_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_monitoring_alert_alert_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_monitoring_alert; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_monitoring_alert (
    alert_id bigint DEFAULT nextval('efrm.ml_monitoring_alert_alert_id_seq'::regclass) NOT NULL,
    model_version_id bigint NOT NULL,
    alert_type character varying(50) NOT NULL,
    severity character varying(20) NOT NULL,
    status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    metric_name character varying(100) NOT NULL,
    observed_value numeric(18,8),
    threshold_value numeric(18,8),
    details jsonb,
    detected_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    acknowledged_by character varying(100),
    acknowledged_at timestamp with time zone,
    resolved_by character varying(100),
    resolved_at timestamp with time zone,
    CONSTRAINT ml_monitoring_alert_severity_check CHECK (((severity)::text = ANY ((ARRAY['INFO'::character varying, 'LOW'::character varying, 'MEDIUM'::character varying, 'HIGH'::character varying, 'CRITICAL'::character varying])::text[]))),
    CONSTRAINT ml_monitoring_alert_status_check CHECK (((status)::text = ANY ((ARRAY['OPEN'::character varying, 'ACKNOWLEDGED'::character varying, 'RESOLVED'::character varying])::text[])))
);


--
-- Name: ml_schema_migration; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_schema_migration (
    migration_name character varying(255) NOT NULL,
    migration_checksum character varying(64) NOT NULL,
    applied_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    applied_by character varying(255) NOT NULL
);


--
-- Name: ml_score_blending_policy; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_score_blending_policy (
    policy_id integer NOT NULL,
    institution_id character varying(100) NOT NULL,
    rule_weight numeric(4,3) NOT NULL,
    ml_weight numeric(4,3) NOT NULL,
    is_active boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: ml_score_blending_policy_policy_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_score_blending_policy_policy_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_score_blending_policy_policy_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_score_blending_policy_policy_id_seq OWNED BY efrm.ml_score_blending_policy.policy_id;


--
-- Name: ml_shadow_execution_shadow_execution_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_shadow_execution_shadow_execution_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_shadow_execution; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_shadow_execution (
    shadow_execution_id bigint DEFAULT nextval('efrm.ml_shadow_execution_shadow_execution_id_seq'::regclass) NOT NULL,
    deployment_plan_id bigint NOT NULL,
    model_version_id bigint NOT NULL,
    inference_id integer,
    institution_id character varying(100) NOT NULL,
    source_system character varying(100),
    channel character varying(100),
    source_event_hash character varying(64) NOT NULL,
    occurred_at timestamp with time zone,
    payload_snapshot jsonb NOT NULL,
    mapped_payload jsonb,
    status character varying(30) DEFAULT 'PENDING'::character varying NOT NULL,
    sample_bucket integer NOT NULL,
    feature_coverage_pct numeric(5,2),
    missing_features jsonb DEFAULT '[]'::jsonb NOT NULL,
    skip_reason character varying(100),
    attempt_count integer DEFAULT 0 NOT NULL,
    available_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    lease_owner character varying(100),
    lease_expires_at timestamp with time zone,
    result_snapshot jsonb,
    error_message text,
    accepted_by character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    CONSTRAINT ck_ml_shadow_execution_bucket CHECK (((sample_bucket >= 0) AND (sample_bucket <= 9999))),
    CONSTRAINT ck_ml_shadow_execution_coverage CHECK (((feature_coverage_pct IS NULL) OR ((feature_coverage_pct >= (0)::numeric) AND (feature_coverage_pct <= (100)::numeric)))),
    CONSTRAINT ck_ml_shadow_execution_status CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'RUNNING'::character varying, 'SCORED'::character varying, 'SKIPPED'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: ml_simulation_result_simulation_result_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_simulation_result_simulation_result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_simulation_result; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_simulation_result (
    simulation_result_id bigint DEFAULT nextval('efrm.ml_simulation_result_simulation_result_id_seq'::regclass) NOT NULL,
    simulation_run_id bigint NOT NULL,
    simulation_id character varying(64) NOT NULL,
    row_number integer NOT NULL,
    status character varying(30) NOT NULL,
    input_payload jsonb NOT NULL,
    output_payload jsonb,
    error_message text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ml_simulation_result_row_number_check CHECK ((row_number > 0)),
    CONSTRAINT ml_simulation_result_status_check CHECK (((status)::text = ANY ((ARRAY['COMPLETED'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: TABLE ml_simulation_result; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON TABLE efrm.ml_simulation_result IS 'Immutable per-row model simulation input and output payload.';


--
-- Name: ml_simulation_run_simulation_run_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_simulation_run_simulation_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_simulation_run; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_simulation_run (
    simulation_run_id bigint DEFAULT nextval('efrm.ml_simulation_run_simulation_run_id_seq'::regclass) NOT NULL,
    run_code character varying(64) NOT NULL,
    institution_id character varying(100) NOT NULL,
    model_version_id bigint NOT NULL,
    run_type character varying(20) NOT NULL,
    status character varying(30) NOT NULL,
    source_file_name character varying(255),
    total_records integer DEFAULT 0 NOT NULL,
    processed_records integer DEFAULT 0 NOT NULL,
    success_records integer DEFAULT 0 NOT NULL,
    failed_records integer DEFAULT 0 NOT NULL,
    avg_risk_score numeric(10,4),
    avg_anomaly_score numeric(10,6),
    high_risk_count integer DEFAULT 0 NOT NULL,
    medium_risk_count integer DEFAULT 0 NOT NULL,
    low_risk_count integer DEFAULT 0 NOT NULL,
    dominant_decision character varying(30),
    execution_time_ms integer,
    request_metadata jsonb,
    created_by character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    error_message text,
    CONSTRAINT ml_simulation_run_failed_records_check CHECK ((failed_records >= 0)),
    CONSTRAINT ml_simulation_run_processed_records_check CHECK ((processed_records >= 0)),
    CONSTRAINT ml_simulation_run_run_type_check CHECK (((run_type)::text = ANY ((ARRAY['SINGLE'::character varying, 'BATCH'::character varying])::text[]))),
    CONSTRAINT ml_simulation_run_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'RUNNING'::character varying, 'COMPLETED'::character varying, 'PARTIAL'::character varying, 'FAILED'::character varying])::text[]))),
    CONSTRAINT ml_simulation_run_success_records_check CHECK ((success_records >= 0)),
    CONSTRAINT ml_simulation_run_total_records_check CHECK ((total_records >= 0))
);


--
-- Name: TABLE ml_simulation_run; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON TABLE efrm.ml_simulation_run IS 'Tenant-scoped single and batch model simulation history.';


--
-- Name: ml_training_dataset_dataset_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_training_dataset_dataset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_training_dataset; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_training_dataset (
    dataset_id bigint DEFAULT nextval('efrm.ml_training_dataset_dataset_id_seq'::regclass) NOT NULL,
    dataset_code character varying(64) NOT NULL,
    institution_id character varying(100) NOT NULL,
    model_version_id bigint NOT NULL,
    feature_set_version_id bigint NOT NULL,
    original_file_name character varying(255) NOT NULL,
    storage_path character varying(1024) NOT NULL,
    content_type character varying(100),
    file_size_bytes bigint NOT NULL,
    file_checksum character varying(64) NOT NULL,
    status character varying(30) DEFAULT 'UPLOADED'::character varying NOT NULL,
    row_count bigint,
    column_count integer,
    validation_report jsonb,
    uploaded_by character varying(100) NOT NULL,
    uploaded_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    validated_by character varying(100),
    validated_at timestamp with time zone,
    row_revision integer DEFAULT 1 NOT NULL,
    CONSTRAINT ml_training_dataset_file_size_bytes_check CHECK ((file_size_bytes > 0)),
    CONSTRAINT ml_training_dataset_row_revision_check CHECK ((row_revision > 0)),
    CONSTRAINT ml_training_dataset_status_check CHECK (((status)::text = ANY ((ARRAY['UPLOADED'::character varying, 'VALIDATING'::character varying, 'VALID'::character varying, 'VALID_WITH_WARNINGS'::character varying, 'INVALID'::character varying, 'QUARANTINED'::character varying])::text[])))
);


--
-- Name: ml_training_dataset_profile; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_training_dataset_profile (
    model_training_dataset_profile_id integer CONSTRAINT ml_training_dataset_profile_model_training_dataset_pro_not_null NOT NULL,
    model_version_id integer NOT NULL,
    file_id character varying(100) NOT NULL,
    file_name character varying(255) NOT NULL,
    file_path character varying(1024) NOT NULL,
    total_rows integer,
    anomaly_ratio numeric(6,4),
    feature_stats jsonb,
    null_percentage numeric(5,2),
    duplicate_percentage numeric(5,2),
    outlier_percentage numeric(5,2),
    data_quality_score numeric(5,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ml_training_dataset_profile_model_training_dataset_profile__seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ml_training_dataset_profile_model_training_dataset_profile__seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ml_training_dataset_profile_model_training_dataset_profile__seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ml_training_dataset_profile_model_training_dataset_profile__seq OWNED BY efrm.ml_training_dataset_profile.model_training_dataset_profile_id;


--
-- Name: ml_worker_heartbeat; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ml_worker_heartbeat (
    worker_id character varying(255) NOT NULL,
    worker_type character varying(100) NOT NULL,
    state character varying(50) NOT NULL,
    current_job_id bigint,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    started_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    last_seen_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: notification_queue; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.notification_queue (
    notification_id bigint NOT NULL,
    event_code character varying(50),
    channel character varying(20),
    user_id character varying(50),
    message text,
    status character varying(20),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN notification_queue.event_code; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.notification_queue.event_code IS 'Event code';


--
-- Name: COLUMN notification_queue.channel; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.notification_queue.channel IS 'Channel: UI, EMAIL';


--
-- Name: COLUMN notification_queue.user_id; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.notification_queue.user_id IS 'User ID to notify';


--
-- Name: COLUMN notification_queue.message; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.notification_queue.message IS 'Final notification message';


--
-- Name: COLUMN notification_queue.status; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.notification_queue.status IS 'Status: PENDING, SENT, FAILED';


--
-- Name: notification_queue_notification_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.notification_queue_notification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_queue_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.notification_queue_notification_id_seq OWNED BY efrm.notification_queue.notification_id;


--
-- Name: notification_template; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.notification_template (
    template_id bigint NOT NULL,
    event_code character varying(50),
    channel character varying(20),
    template_body text,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN notification_template.event_code; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.notification_template.event_code IS 'Event code: CASE_ASSIGNED, etc.';


--
-- Name: COLUMN notification_template.channel; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.notification_template.channel IS 'Channel: UI, EMAIL';


--
-- Name: COLUMN notification_template.template_body; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.notification_template.template_body IS 'Template body with variables like {case_id}';


--
-- Name: COLUMN notification_template.is_active; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.notification_template.is_active IS 'Whether the template is active: Y/N';


--
-- Name: notification_template_template_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.notification_template_template_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_template_template_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.notification_template_template_id_seq OWNED BY efrm.notification_template.template_id;


--
-- Name: operator_value; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.operator_value (
    id integer NOT NULL,
    key character varying(16) NOT NULL,
    label character varying(32) NOT NULL,
    types_allowed character varying(64) NOT NULL
);


--
-- Name: operator_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.operator_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: operator_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.operator_id_seq OWNED BY efrm.operator_value.id;


--
-- Name: password_expiry_notice; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.password_expiry_notice (
    notice_id character varying(64) NOT NULL,
    user_id character varying(128) NOT NULL,
    credential_id character varying(64) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    warned_at timestamp with time zone,
    forced_reset_at timestamp with time zone,
    status character varying(16) NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: password_policy_rule; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.password_policy_rule (
    rule_id character varying(32) NOT NULL,
    rule_name character varying(128) NOT NULL,
    role_code character varying(128),
    min_length integer NOT NULL,
    max_length integer,
    require_uppercase character varying(1),
    require_lowercase character varying(1),
    require_number character varying(1),
    require_special_char character varying(1),
    allowed_special_chars character varying(255),
    disallow_whitespace character varying(1),
    disallow_username character varying(1),
    disallow_common_passwords character varying(1),
    disallow_repetitive_chars character varying(1),
    disallow_sequential_chars character varying(1),
    password_expiry_days integer,
    password_history_count integer,
    password_lock_threshold integer,
    lock_duration_minutes integer,
    notify_user_on_failed_attempt character varying(1),
    is_active character varying(1) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    CONSTRAINT chk_max_gte_min_len CHECK ((max_length >= min_length))
);


--
-- Name: password_reset_token; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.password_reset_token (
    token_id character varying(64) NOT NULL,
    user_id character varying(128) NOT NULL,
    token_hash character varying(128) NOT NULL,
    channel character varying(16) NOT NULL,
    masked_recipient character varying(64) NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone,
    request_ip character varying(45),
    used_ip character varying(45),
    invalidated_at timestamp with time zone,
    invalidated_reason character varying(64),
    created_at timestamp with time zone NOT NULL
);


--
-- Name: product_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.product_master (
    product_id character varying(12) NOT NULL,
    product_name character varying(128) NOT NULL,
    product_desc character varying(128) NOT NULL,
    product_flag character varying(1) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL
);


--
-- Name: profile_capability; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.profile_capability (
    profile_id character varying(32) NOT NULL,
    capability_code character varying(128) NOT NULL,
    assigned_by character varying(128) NOT NULL,
    assigned_at timestamp with time zone NOT NULL,
    change_reason character varying(512) NOT NULL
);


--
-- Name: profile_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.profile_master (
    profile_id character varying(32) NOT NULL,
    profile_name character varying(128) NOT NULL,
    profile_type character varying(64) NOT NULL,
    description character varying(128),
    security_check_id character varying(32) NOT NULL,
    password_policy_rule_id character varying(32) NOT NULL,
    profile_status character varying(12) NOT NULL,
    product_access character varying(128) NOT NULL,
    menu_access text NOT NULL,
    api_allowed text NOT NULL,
    remarks character varying(128),
    added_by character varying(128) NOT NULL,
    added_date timestamp with time zone NOT NULL,
    approved_date timestamp with time zone,
    approved_by character varying(128),
    deleted_by character varying(128),
    deleted_date timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    profile_tag character varying(12) DEFAULT 'ADMIN'::character varying NOT NULL,
    authorization_version integer DEFAULT 1 NOT NULL
);


--
-- Name: reference_data; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.reference_data (
    ref_id bigint NOT NULL,
    ref_type character varying(50) NOT NULL,
    ref_code character varying(50) NOT NULL,
    ref_value character varying(200) NOT NULL,
    ref_description character varying(500),
    display_order integer,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(50),
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_by character varying(50),
    ref_sub_code character varying(200) DEFAULT 'NA'::character varying NOT NULL,
    rule_drl_context character varying(200) DEFAULT 'NA'::character varying NOT NULL
);


--
-- Name: reference_data_ref_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.reference_data_ref_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reference_data_ref_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.reference_data_ref_id_seq OWNED BY efrm.reference_data.ref_id;


--
-- Name: refresh_token; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.refresh_token (
    token_id character varying(64) NOT NULL,
    user_id character varying(128) NOT NULL,
    session_id character varying(64) NOT NULL,
    token_hash character varying(128) NOT NULL,
    parent_token_id character varying(64),
    replaced_by_token_id character varying(64),
    issued_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    rotated_at timestamp with time zone,
    revoked_at timestamp with time zone,
    revoked_reason character varying(64),
    ip_address character varying(45),
    user_agent character varying(512),
    device_fingerprint character varying(128),
    created_at timestamp with time zone NOT NULL
);


--
-- Name: report_assignment; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.report_assignment (
    id integer NOT NULL,
    institution_id character varying(12) NOT NULL,
    profile_id character varying(32),
    report_code character varying(32) NOT NULL,
    scope_type character varying(16) NOT NULL,
    scope_key character varying(160) NOT NULL,
    variant_id integer NOT NULL,
    assignment_version integer NOT NULL,
    config_schema_version integer DEFAULT 1 NOT NULL,
    configuration jsonb NOT NULL,
    approval_status character varying(16) DEFAULT 'DRAFT'::character varying NOT NULL,
    is_active character varying(1) DEFAULT 'N'::character varying NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    change_reason text NOT NULL,
    created_at timestamp with time zone NOT NULL,
    created_by character varying(64) NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    updated_by character varying(64) NOT NULL,
    approved_at timestamp with time zone,
    approved_by character varying(64),
    CONSTRAINT ck_rep_asn_active CHECK (((is_active)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_rep_asn_approval CHECK (((approval_status)::text = ANY ((ARRAY['DRAFT'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[]))),
    CONSTRAINT ck_rep_asn_checker CHECK ((((approval_status)::text <> 'APPROVED'::text) OR ((approved_at IS NOT NULL) AND (approved_by IS NOT NULL) AND ((approved_by)::text <> (created_by)::text)))),
    CONSTRAINT ck_rep_asn_effective CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to > effective_from))),
    CONSTRAINT ck_rep_asn_profile CHECK (((((scope_type)::text = 'PROFILE'::text) AND (profile_id IS NOT NULL)) OR (((scope_type)::text = 'INSTITUTION'::text) AND (profile_id IS NULL)))),
    CONSTRAINT ck_rep_asn_publish CHECK ((((is_active)::text = 'N'::text) OR ((approval_status)::text = 'APPROVED'::text))),
    CONSTRAINT ck_rep_asn_scope CHECK (((scope_type)::text = ANY ((ARRAY['PROFILE'::character varying, 'INSTITUTION'::character varying])::text[]))),
    CONSTRAINT ck_rep_asn_scope_key CHECK (((((scope_type)::text = 'INSTITUTION'::text) AND ((scope_key)::text = (((institution_id)::text || ':'::text) || 'INSTITUTION'::text))) OR (((scope_type)::text = 'PROFILE'::text) AND ((scope_key)::text = (((((institution_id)::text || ':'::text) || 'PROFILE'::text) || ':'::text) || (profile_id)::text))))),
    CONSTRAINT ck_rep_asn_versions CHECK (((assignment_version > 0) AND (config_schema_version > 0)))
);


--
-- Name: report_assignment_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

ALTER TABLE efrm.report_assignment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME efrm.report_assignment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: report_export_audit; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.report_export_audit (
    export_id character varying(36) NOT NULL,
    institution_id character varying(64) NOT NULL,
    profile_id character varying(32) NOT NULL,
    user_id character varying(128) NOT NULL,
    session_id character varying(128),
    report_code character varying(32) NOT NULL,
    schema_version character varying(16) NOT NULL,
    export_format character varying(8) DEFAULT 'XLSX'::character varying NOT NULL,
    report_date date NOT NULL,
    report_state character varying(16) NOT NULL,
    report_timezone character varying(64) NOT NULL,
    period_start_utc timestamp with time zone NOT NULL,
    period_end_utc timestamp with time zone NOT NULL,
    filter_evidence jsonb NOT NULL,
    row_count bigint,
    source_record_count bigint,
    data_as_of timestamp with time zone NOT NULL,
    request_id character varying(128),
    status character varying(16) DEFAULT 'REQUESTED'::character varying NOT NULL,
    byte_count bigint,
    content_sha256 character varying(64),
    failure_code character varying(64),
    requested_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone,
    variant_code character varying(64),
    config_schema_version integer,
    assignment_version integer,
    configuration_hash character varying(64),
    CONSTRAINT ck_rep_export_runtime CHECK ((((variant_code IS NULL) AND (config_schema_version IS NULL) AND (assignment_version IS NULL) AND (configuration_hash IS NULL)) OR ((variant_code IS NOT NULL) AND (config_schema_version > 0) AND ((assignment_version IS NULL) OR (assignment_version > 0)) AND (configuration_hash IS NOT NULL) AND (length((configuration_hash)::text) = 64)))),
    CONSTRAINT ck_report_export_counts CHECK ((((row_count IS NULL) OR (row_count >= 0)) AND ((source_record_count IS NULL) OR (source_record_count >= 0)) AND ((byte_count IS NULL) OR (byte_count > 0)) AND ((row_count IS NULL) OR (source_record_count IS NULL) OR (source_record_count <= row_count)))),
    CONSTRAINT ck_report_export_format CHECK (((export_format)::text = 'XLSX'::text)),
    CONSTRAINT ck_report_export_state CHECK (((report_state)::text = ANY ((ARRAY['CLOSED'::character varying, 'IN_PROGRESS'::character varying])::text[]))),
    CONSTRAINT ck_report_export_status CHECK (((status)::text = ANY ((ARRAY['REQUESTED'::character varying, 'COMPLETED'::character varying, 'FAILED'::character varying])::text[]))),
    CONSTRAINT ck_report_export_terminal CHECK (((((status)::text = 'REQUESTED'::text) AND (completed_at IS NULL) AND (content_sha256 IS NULL) AND (byte_count IS NULL) AND (failure_code IS NULL)) OR (((status)::text = 'COMPLETED'::text) AND (completed_at IS NOT NULL) AND (row_count IS NOT NULL) AND (source_record_count IS NOT NULL) AND (byte_count IS NOT NULL) AND (content_sha256 IS NOT NULL) AND (length((content_sha256)::text) = 64) AND (failure_code IS NULL)) OR (((status)::text = 'FAILED'::text) AND (completed_at IS NOT NULL) AND (failure_code IS NOT NULL) AND (content_sha256 IS NULL) AND (byte_count IS NULL))))
);


--
-- Name: report_variant_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.report_variant_master (
    id integer NOT NULL,
    report_code character varying(32) NOT NULL,
    variant_code character varying(64) NOT NULL,
    handler_key character varying(128) NOT NULL,
    component_key character varying(128) NOT NULL,
    display_name character varying(160) NOT NULL,
    contract_version character varying(32) NOT NULL,
    config_schema_version integer DEFAULT 1 NOT NULL,
    default_report_lag_days integer DEFAULT 1 NOT NULL,
    is_product_default character varying(1) DEFAULT 'N'::character varying NOT NULL,
    approval_status character varying(16) DEFAULT 'DRAFT'::character varying NOT NULL,
    is_active character varying(1) DEFAULT 'N'::character varying NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    created_by character varying(64) NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    updated_by character varying(64) NOT NULL,
    approved_at timestamp with time zone,
    approved_by character varying(64),
    CONSTRAINT ck_rep_var_active CHECK (((is_active)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_rep_var_approval CHECK (((approval_status)::text = ANY ((ARRAY['DRAFT'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[]))),
    CONSTRAINT ck_rep_var_checker CHECK ((((approval_status)::text <> 'APPROVED'::text) OR ((approved_at IS NOT NULL) AND (approved_by IS NOT NULL) AND ((approved_by)::text <> (created_by)::text)))),
    CONSTRAINT ck_rep_var_default CHECK (((is_product_default)::text = ANY ((ARRAY['Y'::character varying, 'N'::character varying])::text[]))),
    CONSTRAINT ck_rep_var_effective CHECK (((effective_to IS NULL) OR (effective_from IS NULL) OR (effective_to > effective_from))),
    CONSTRAINT ck_rep_var_lag CHECK (((default_report_lag_days >= 0) AND (default_report_lag_days <= 31))),
    CONSTRAINT ck_rep_var_publish CHECK ((((is_active)::text = 'N'::text) OR ((approval_status)::text = 'APPROVED'::text))),
    CONSTRAINT ck_rep_var_schema CHECK ((config_schema_version > 0))
);


--
-- Name: report_variant_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

ALTER TABLE efrm.report_variant_master ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME efrm.report_variant_master_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: risk_event_log; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_event_log (
    id integer NOT NULL,
    institution_id character varying(64) NOT NULL,
    entity_id character varying(128) NOT NULL,
    event_source character varying(50) NOT NULL,
    score integer NOT NULL,
    decision character varying(50),
    reference_id character varying(100),
    event_timestamp timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    event_type character varying(100),
    reference_table character varying(100),
    processing_status character varying(20) DEFAULT 'RECEIVED'::character varying,
    processing_started_at timestamp with time zone,
    processing_completed_at timestamp with time zone,
    error_message text,
    CONSTRAINT risk_event_log_score_check CHECK (((score >= 0) AND (score <= 1000)))
);


--
-- Name: risk_event_log_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_event_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_event_log_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_event_log_id_seq OWNED BY efrm.risk_event_log.id;


--
-- Name: risk_rating_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_config (
    id integer NOT NULL,
    institution_id character varying(64) NOT NULL,
    config_version integer NOT NULL,
    description character varying(200),
    effective_from timestamp without time zone,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by character varying(64),
    approved_at timestamp without time zone,
    approved_by character varying(64),
    CONSTRAINT chk_risk_rating_config_is_active CHECK (((is_active)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: risk_rating_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_config_id_seq OWNED BY efrm.risk_rating_config.id;


--
-- Name: risk_rating_decay_policy_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_decay_policy_config (
    id bigint NOT NULL,
    config_master_id integer NOT NULL,
    risk_domain character varying(50) NOT NULL,
    decay_days integer NOT NULL,
    decay_method character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: risk_rating_decay_policy_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_decay_policy_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_decay_policy_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_decay_policy_config_id_seq OWNED BY efrm.risk_rating_decay_policy_config.id;


--
-- Name: risk_rating_decision_impact_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_decision_impact_config (
    id bigint NOT NULL,
    config_master_id integer NOT NULL,
    source_type character varying(50) NOT NULL,
    decision_code character varying(100) NOT NULL,
    impact_type character varying(20) NOT NULL,
    impact_factor numeric(10,4) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: risk_rating_decision_impact_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_decision_impact_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_decision_impact_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_decision_impact_config_id_seq OWNED BY efrm.risk_rating_decision_impact_config.id;


--
-- Name: risk_rating_domain_override_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_domain_override_config (
    id bigint NOT NULL,
    config_master_id integer NOT NULL,
    risk_domain character varying(50) NOT NULL,
    threshold_score integer NOT NULL,
    minimum_tier character varying(20) NOT NULL,
    enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_risk_rating_domain_override_enabled CHECK (((enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: risk_rating_domain_override_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_domain_override_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_domain_override_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_domain_override_config_id_seq OWNED BY efrm.risk_rating_domain_override_config.id;


--
-- Name: risk_rating_event_type_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_event_type_config (
    id bigint NOT NULL,
    config_master_id integer NOT NULL,
    event_type character varying(100) NOT NULL,
    source_type character varying(50) NOT NULL,
    contributes_to_risk character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_risk_rating_event_type_contributes CHECK (((contributes_to_risk)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: risk_rating_event_type_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_event_type_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_event_type_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_event_type_config_id_seq OWNED BY efrm.risk_rating_event_type_config.id;


--
-- Name: risk_rating_override_policy; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_override_policy (
    id bigint NOT NULL,
    config_master_id integer NOT NULL,
    policy_code character varying(100) NOT NULL,
    source_type character varying(50) NOT NULL,
    trigger_type character varying(50) NOT NULL,
    trigger_value character varying(200) NOT NULL,
    override_type character varying(50) NOT NULL,
    override_value character varying(100) NOT NULL,
    priority integer DEFAULT 100 NOT NULL,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    effective_from timestamp with time zone DEFAULT now(),
    effective_to timestamp with time zone,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_risk_rating_override_policy_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: risk_rating_override_policy_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_override_policy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_override_policy_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_override_policy_id_seq OWNED BY efrm.risk_rating_override_policy.id;


--
-- Name: risk_rating_relationship_risk_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_relationship_risk_config (
    id bigint NOT NULL,
    config_master_id integer NOT NULL,
    relationship_type character varying(100) NOT NULL,
    risk_propagation_percentage numeric(10,4) CONSTRAINT risk_rating_relationship_ri_risk_propagation_percentag_not_null NOT NULL,
    maximum_propagated_score integer,
    minimum_source_risk_score integer DEFAULT 0,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_risk_rating_relationship_risk_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: risk_rating_relationship_risk_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_relationship_risk_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_relationship_risk_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_relationship_risk_config_id_seq OWNED BY efrm.risk_rating_relationship_risk_config.id;


--
-- Name: risk_rating_service_weight_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_service_weight_config (
    id bigint NOT NULL,
    config_master_id integer NOT NULL,
    service_name character varying(50) NOT NULL,
    risk_domain character varying(50) NOT NULL,
    weight_factor numeric(10,4) NOT NULL,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_risk_rating_service_weight_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: risk_rating_service_weight_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_service_weight_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_service_weight_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_service_weight_config_id_seq OWNED BY efrm.risk_rating_service_weight_config.id;


--
-- Name: risk_rating_tier_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_tier_config (
    id bigint NOT NULL,
    config_master_id integer NOT NULL,
    tier_name character varying(20) NOT NULL,
    min_score integer NOT NULL,
    max_score integer NOT NULL,
    display_order integer NOT NULL,
    color_code character varying(20),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: risk_rating_tier_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_tier_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_tier_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_tier_config_id_seq OWNED BY efrm.risk_rating_tier_config.id;


--
-- Name: risk_rating_weight_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_rating_weight_config (
    id bigint NOT NULL,
    config_master_id integer NOT NULL,
    risk_domain character varying(50) NOT NULL,
    weight_factor numeric(10,4) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: risk_rating_weight_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_rating_weight_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_rating_weight_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_rating_weight_config_id_seq OWNED BY efrm.risk_rating_weight_config.id;


--
-- Name: risk_recalculation_job; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.risk_recalculation_job (
    id integer NOT NULL,
    scope_type character varying(20) NOT NULL,
    institution_id character varying(64),
    config_id integer,
    entity_id character varying(128),
    total_entities integer DEFAULT 0 NOT NULL,
    processed_entities integer DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    error_message text,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_risk_recalculation_job_scope_type CHECK (((scope_type)::text = ANY (ARRAY[('ENTITY'::character varying)::text, ('INSTITUTION'::character varying)::text, ('CONFIG'::character varying)::text])))
);


--
-- Name: risk_recalculation_job_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.risk_recalculation_job_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: risk_recalculation_job_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.risk_recalculation_job_id_seq OWNED BY efrm.risk_recalculation_job.id;


--
-- Name: rule_decision_policy; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_decision_policy (
    id integer NOT NULL,
    policy_code character varying(64) NOT NULL,
    policy_description character varying(256) NOT NULL,
    signal_severity character varying(16) NOT NULL,
    severity_rank integer NOT NULL,
    min_score integer NOT NULL,
    max_score integer,
    min_rule_count integer DEFAULT 1 NOT NULL,
    decision character varying(16) NOT NULL,
    override_flag character varying(1) DEFAULT 'N'::character varying NOT NULL,
    priority integer DEFAULT 1 NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_by character varying(64) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    alert_required character varying(1) DEFAULT 'N'::character varying NOT NULL,
    case_required character varying(1) DEFAULT 'N'::character varying NOT NULL
);


--
-- Name: rule_decision_policy_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_decision_policy_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_decision_policy_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.rule_decision_policy_id_seq OWNED BY efrm.rule_decision_policy.id;


--
-- Name: rule_decision_upgrade; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_decision_upgrade (
    id integer NOT NULL,
    policy_code character varying(64) NOT NULL,
    source_severity character varying(16) NOT NULL,
    source_severity_rank integer NOT NULL,
    min_rule_count integer NOT NULL,
    target_severity character varying(16) NOT NULL,
    target_severity_rank integer NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    description character varying(256),
    created_by character varying(64) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: rule_drl_context; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_drl_context (
    id integer NOT NULL,
    context_code character varying(64) NOT NULL,
    package_name character varying(256) NOT NULL,
    imports text NOT NULL,
    description character varying(256),
    is_active boolean DEFAULT true NOT NULL,
    created_by character varying(64) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    fact character varying(64) DEFAULT 'ruleengine'::character varying NOT NULL
);


--
-- Name: rule_drl_context_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_drl_context_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_drl_context_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.rule_drl_context_id_seq OWNED BY efrm.rule_drl_context.id;


--
-- Name: rule_group_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_group_master (
    id integer NOT NULL,
    group_code character varying(64) NOT NULL,
    group_name character varying(128),
    group_type character varying(32),
    description character varying(256),
    created_by character varying(64) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    execution_mode character varying(16) DEFAULT 'SYNC'::character varying NOT NULL
);


--
-- Name: rule_group_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_group_master_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_group_master_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.rule_group_master_id_seq OWNED BY efrm.rule_group_master.id;


--
-- Name: rule_group_source_binding; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_group_source_binding (
    id integer NOT NULL,
    institution_id character varying(64) NOT NULL,
    source_system character varying(32) NOT NULL,
    channel character varying(32) NOT NULL,
    rule_group_version_id integer NOT NULL,
    policy_code character varying(64) NOT NULL,
    priority integer DEFAULT 1 NOT NULL,
    status character varying(16) DEFAULT 'ACTIVE'::character varying NOT NULL,
    created_by character varying(64) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: rule_group_source_binding_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_group_source_binding_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_group_source_binding_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.rule_group_source_binding_id_seq OWNED BY efrm.rule_group_source_binding.id;


--
-- Name: rule_group_version; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_group_version (
    id integer NOT NULL,
    rule_group_master_id integer NOT NULL,
    version_no integer NOT NULL,
    status character varying(16) DEFAULT 'DRAFT'::character varying NOT NULL,
    change_reason character varying(256),
    created_by character varying(64) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    approved_by character varying(64),
    approved_at timestamp without time zone
);


--
-- Name: rule_group_version_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_group_version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_group_version_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.rule_group_version_id_seq OWNED BY efrm.rule_group_version.id;


--
-- Name: rule_group_version_map; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_group_version_map (
    id integer NOT NULL,
    rule_group_version_id integer NOT NULL,
    rule_version_id integer NOT NULL,
    execution_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    is_mandatory character varying(1) DEFAULT 'Y'::character varying NOT NULL
);


--
-- Name: rule_group_version_map_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_group_version_map_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_group_version_map_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.rule_group_version_map_id_seq OWNED BY efrm.rule_group_version_map.id;


--
-- Name: rule_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_master (
    id integer NOT NULL,
    rule_code character varying(64) NOT NULL,
    name character varying(256) NOT NULL,
    rule_type character varying(64) NOT NULL,
    fact character varying(64) NOT NULL,
    description text,
    created_by character varying(64) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: rule_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_master_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_master_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.rule_master_id_seq OWNED BY efrm.rule_master.id;


--
-- Name: rule_master_tag; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_master_tag (
    id integer NOT NULL,
    rule_id integer NOT NULL,
    tag_code character varying(64) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(64) DEFAULT 'SYSTEM'::character varying
);


--
-- Name: rule_master_tag_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_master_tag_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_master_tag_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.rule_master_tag_id_seq OWNED BY efrm.rule_master_tag.id;


--
-- Name: rule_metric_dependency_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_metric_dependency_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_metric_dependency; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_metric_dependency (
    id integer DEFAULT nextval('efrm.rule_metric_dependency_seq'::regclass) NOT NULL,
    rule_id integer NOT NULL,
    metric_code character varying(64) NOT NULL,
    entity_type character varying(32) NOT NULL,
    metric_role character varying(16) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: rule_required_data_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_required_data_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_required_data; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_required_data (
    id integer DEFAULT nextval('efrm.rule_required_data_seq'::regclass) NOT NULL,
    rule_version_id integer NOT NULL,
    variable_type character varying(16) NOT NULL,
    variable character varying(128) NOT NULL,
    entity_type character varying(32),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: rule_version; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_version (
    id integer NOT NULL,
    rule_master_id integer NOT NULL,
    version_no integer NOT NULL,
    logic jsonb,
    drl_context_id integer NOT NULL,
    drl_rule text,
    status character varying(16) DEFAULT 'DRAFT'::character varying NOT NULL,
    checksum character varying(128) NOT NULL,
    test_count integer DEFAULT 0 NOT NULL,
    change_reason character varying(256),
    signal_code character varying(64),
    signal_weight integer,
    created_by character varying(64) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    approved_by character varying(64),
    approved_at timestamp without time zone,
    primary_entity character varying(32) DEFAULT 'CUSTOMER'::character varying NOT NULL,
    signal_category character varying(16) DEFAULT 'FRAUD'::character varying NOT NULL,
    signal_severity character varying(16) DEFAULT 'HIGH'::character varying NOT NULL,
    severity_rank integer DEFAULT 2 NOT NULL
);


--
-- Name: rule_version_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.rule_version_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_version_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.rule_version_id_seq OWNED BY efrm.rule_version.id;


--
-- Name: rule_version_old; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_version_old (
    id integer,
    rule_master_id integer,
    version_no integer,
    logic jsonb,
    drl_context_id integer,
    drl_rule text,
    status character varying(16),
    checksum character varying(128),
    test_count integer,
    change_reason character varying(256),
    signal_code character varying(64),
    signal_type character varying(16),
    signal_weight integer,
    created_by character varying(64),
    created_at timestamp without time zone,
    approved_by character varying(64),
    approved_at timestamp without time zone,
    primary_entity character varying(32)
);


--
-- Name: rule_version_old1; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.rule_version_old1 (
    id integer,
    rule_master_id integer,
    version_no integer,
    logic jsonb,
    drl_context_id integer,
    drl_rule text,
    status character varying(16),
    checksum character varying(128),
    test_count integer,
    change_reason character varying(256),
    signal_code character varying(64),
    signal_weight integer,
    created_by character varying(64),
    created_at timestamp without time zone,
    approved_by character varying(64),
    approved_at timestamp without time zone,
    primary_entity character varying(32),
    signal_category character varying(16),
    signal_severity character varying(16)
);


--
-- Name: ruleengine_alert_old; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ruleengine_alert_old (
    id integer,
    ruleengine_result_id integer,
    alert_code character varying(64),
    alert_type character varying(16),
    severity character varying(16),
    decision character varying(16),
    customer_id character varying(64),
    transaction_id character varying(64),
    alert_payload jsonb,
    status character varying(16),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    comments text
);


--
-- Name: ruleengine_bulk_job; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ruleengine_bulk_job (
    id integer NOT NULL,
    job_id character varying(64) NOT NULL,
    fact character varying(64) NOT NULL,
    file_name character varying(256) NOT NULL,
    file_path character varying(512) NOT NULL,
    institution_id character varying(64) NOT NULL,
    source_system character varying(64) NOT NULL,
    channel character varying(64) NOT NULL,
    job_type character varying(16) NOT NULL,
    status character varying(16) NOT NULL,
    total_records integer DEFAULT 0,
    processed_records integer DEFAULT 0,
    success_records integer DEFAULT 0,
    failed_records integer DEFAULT 0,
    started_at timestamp without time zone,
    completed_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(64) NOT NULL,
    error_message character varying(1024),
    is_test character varying(1) DEFAULT 'N'::character varying NOT NULL
);


--
-- Name: ruleengine_bulk_job_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ruleengine_bulk_job_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ruleengine_bulk_job_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ruleengine_bulk_job_id_seq OWNED BY efrm.ruleengine_bulk_job.id;


--
-- Name: ruleengine_bulk_job_item; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ruleengine_bulk_job_item (
    id integer NOT NULL,
    bulk_job_id integer NOT NULL,
    record_no integer NOT NULL,
    request_payload jsonb NOT NULL,
    execution_id integer,
    status character varying(16) NOT NULL,
    error_message character varying(1024),
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: ruleengine_bulk_job_item_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ruleengine_bulk_job_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ruleengine_bulk_job_item_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ruleengine_bulk_job_item_id_seq OWNED BY efrm.ruleengine_bulk_job_item.id;


--
-- Name: ruleengine_bulk_job_summary; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ruleengine_bulk_job_summary (
    id integer NOT NULL,
    bulk_job_id integer NOT NULL,
    total_records integer NOT NULL,
    processed_records integer NOT NULL,
    success_records integer NOT NULL,
    failed_records integer NOT NULL,
    allow_count integer DEFAULT 0,
    block_count integer DEFAULT 0,
    stepup_count integer DEFAULT 0,
    risk_signal_count integer DEFAULT 0,
    aml_signal_count integer DEFAULT 0,
    info_signal_count integer DEFAULT 0,
    avg_processing_time_ms integer,
    max_processing_time_ms integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    high_risk_count integer DEFAULT 0,
    medium_risk_count integer DEFAULT 0,
    low_risk_count integer DEFAULT 0
);


--
-- Name: ruleengine_bulk_job_summary_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ruleengine_bulk_job_summary_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ruleengine_bulk_job_summary_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ruleengine_bulk_job_summary_id_seq OWNED BY efrm.ruleengine_bulk_job_summary.id;


--
-- Name: ruleengine_decision_upgrade_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.ruleengine_decision_upgrade_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ruleengine_decision_upgrade_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.ruleengine_decision_upgrade_id_seq OWNED BY efrm.rule_decision_upgrade.id;


--
-- Name: ruleengine_match_old; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.ruleengine_match_old (
    id integer,
    ruleengine_result_id integer,
    rule_group_version integer,
    rule_code character varying(64),
    rule_version integer,
    signal_code character varying(64),
    signal_type character varying(16),
    signal_weight integer,
    created_at timestamp without time zone
);


--
-- Name: screening_alert; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_alert (
    id bigint NOT NULL,
    alert_id character varying(64) NOT NULL,
    request_id uuid NOT NULL,
    result_id bigint NOT NULL,
    entity_id character varying(128),
    entity_type character varying(32),
    risk_band character varying(16) NOT NULL,
    overall_risk_score integer NOT NULL,
    highest_list_source character varying(64),
    status character varying(32) NOT NULL,
    case_id character varying(64),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    comments text,
    user_action character varying(20)
);


--
-- Name: screening_alert_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_alert_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_alert_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_alert_id_seq OWNED BY efrm.screening_alert.id;


--
-- Name: screening_bulk_job; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_bulk_job (
    id integer NOT NULL,
    job_id character varying(64) NOT NULL,
    fact character varying(64) NOT NULL,
    file_name character varying(256) NOT NULL,
    file_path character varying(512) NOT NULL,
    institution_id character varying(64) NOT NULL,
    source_system character varying(64) NOT NULL,
    channel character varying(64) NOT NULL,
    job_type character varying(16) NOT NULL,
    status character varying(16) NOT NULL,
    total_records integer DEFAULT 0,
    processed_records integer DEFAULT 0,
    success_records integer DEFAULT 0,
    failed_records integer DEFAULT 0,
    started_at timestamp without time zone,
    completed_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(64) NOT NULL,
    error_message character varying(1024)
);


--
-- Name: screening_bulk_job_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_bulk_job_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_bulk_job_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_bulk_job_id_seq OWNED BY efrm.screening_bulk_job.id;


--
-- Name: screening_bulk_job_item; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_bulk_job_item (
    id integer NOT NULL,
    bulk_job_id integer NOT NULL,
    record_no integer NOT NULL,
    request_payload jsonb NOT NULL,
    execution_id integer,
    status character varying(16) NOT NULL,
    error_message character varying(1024),
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: screening_bulk_job_item_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_bulk_job_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_bulk_job_item_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_bulk_job_item_id_seq OWNED BY efrm.screening_bulk_job_item.id;


--
-- Name: screening_bulk_job_summary; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_bulk_job_summary (
    id integer NOT NULL,
    bulk_job_id integer NOT NULL,
    total_records integer NOT NULL,
    processed_records integer NOT NULL,
    success_records integer NOT NULL,
    failed_records integer NOT NULL,
    allow_count integer DEFAULT 0,
    block_count integer DEFAULT 0,
    stepup_count integer DEFAULT 0,
    high_risk_count integer DEFAULT 0,
    medium_risk_count integer DEFAULT 0,
    low_risk_count integer DEFAULT 0,
    avg_processing_time_ms integer,
    max_processing_time_ms integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: screening_bulk_job_summary_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_bulk_job_summary_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_bulk_job_summary_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_bulk_job_summary_id_seq OWNED BY efrm.screening_bulk_job_summary.id;


--
-- Name: screening_config_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_config_master (
    id bigint NOT NULL,
    institution_id character varying(12) NOT NULL,
    config_name character varying(128) NOT NULL,
    config_version integer NOT NULL,
    module_type character varying(32) NOT NULL,
    risk_contributor_threshold numeric(6,4) DEFAULT 0.75 NOT NULL,
    risk_score_scale_factor numeric(10,2) DEFAULT '1000'::numeric,
    status character varying(16) DEFAULT 'DRAFT'::character varying NOT NULL,
    effective_from timestamp with time zone,
    effective_to timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by character varying(64),
    approved_at timestamp with time zone,
    approved_by character varying(64)
);


--
-- Name: screening_config_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_config_master_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_config_master_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_config_master_id_seq OWNED BY efrm.screening_config_master.id;


--
-- Name: screening_config_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_config_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_decision_threshold; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_decision_threshold (
    id bigint NOT NULL,
    config_master_id bigint NOT NULL,
    decision_code character varying(32) NOT NULL,
    min_score numeric(6,4) NOT NULL,
    max_score numeric(6,4) NOT NULL,
    priority integer NOT NULL,
    action_code character varying(32) NOT NULL,
    risk_band_code character varying(32),
    create_case_flag character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    trigger_str_flag character varying(1) DEFAULT 'N'::character varying NOT NULL,
    freeze_account_flag character varying(1) DEFAULT 'N'::character varying NOT NULL,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    create_alert_flag character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    CONSTRAINT chk_action_code CHECK (((action_code)::text = ANY (ARRAY[('ESCALATE'::character varying)::text, ('REVIEW'::character varying)::text, ('CLEAR'::character varying)::text, ('AUTO_CLOSE'::character varying)::text]))),
    CONSTRAINT chk_create_alert_flag CHECK (((create_alert_flag)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_create_case_flag CHECK (((create_case_flag)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_decision_code CHECK (((decision_code)::text = ANY (ARRAY[('MATCH'::character varying)::text, ('POSSIBLE_MATCH'::character varying)::text, ('CLEAR'::character varying)::text]))),
    CONSTRAINT chk_decision_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_freeze_account_flag CHECK (((freeze_account_flag)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_trigger_str_flag CHECK (((trigger_str_flag)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: screening_decision_threshold_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_decision_threshold_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_decision_threshold_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_decision_threshold_id_seq OWNED BY efrm.screening_decision_threshold.id;


--
-- Name: screening_entity; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_entity (
    id bigint NOT NULL,
    entity_type character varying(128) NOT NULL,
    entity_group character varying(32) NOT NULL,
    description character varying(512),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    created_by character varying(64),
    updated_by character varying(64),
    is_primary character varying(1) DEFAULT 'N'::character varying NOT NULL
);


--
-- Name: COLUMN screening_entity.is_primary; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.screening_entity.is_primary IS 'Whether this is the primary entity type: Y/N';


--
-- Name: screening_entity_field; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_entity_field (
    field_id bigint NOT NULL,
    entity_type character varying(30) NOT NULL,
    field_name character varying(50) NOT NULL,
    field_label character varying(100) NOT NULL,
    data_type character varying(20) NOT NULL,
    is_mandatory character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    description character varying(300),
    max_length integer,
    reference_data character varying(50),
    display_order integer,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    created_by character varying(50),
    updated_at timestamp without time zone NOT NULL,
    updated_by character varying(50),
    entity_relation character varying(64) DEFAULT 'CUSTOMER'::character varying NOT NULL
);


--
-- Name: screening_entity_field_field_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_entity_field_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_entity_field_field_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_entity_field_field_id_seq OWNED BY efrm.screening_entity_field.field_id;


--
-- Name: screening_entity_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_entity_id_seq OWNED BY efrm.screening_entity.id;


--
-- Name: screening_entity_relation; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_entity_relation (
    relation_id bigint NOT NULL,
    entity_type character varying(128) NOT NULL,
    entity_relation character varying(64) NOT NULL,
    description character varying(512),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    created_by character varying(64),
    updated_by character varying(64),
    is_primary character varying(1) DEFAULT 'N'::character varying NOT NULL,
    related_entity character varying(128)
);


--
-- Name: screening_entity_relation_relation_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_entity_relation_relation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_entity_relation_relation_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_entity_relation_relation_id_seq OWNED BY efrm.screening_entity_relation.relation_id;


--
-- Name: screening_field_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_field_config (
    id bigint NOT NULL,
    config_master_id bigint NOT NULL,
    field_name character varying(64) NOT NULL,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    is_mandatory character varying(1) DEFAULT 'N'::character varying NOT NULL,
    is_primary character varying(1) DEFAULT 'N'::character varying NOT NULL,
    match_type character varying(32) NOT NULL,
    weight numeric(6,4) NOT NULL,
    minimum_match_score numeric(6,4),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_is_mandatory CHECK (((is_mandatory)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_is_primary CHECK (((is_primary)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_match_type CHECK (((match_type)::text = ANY (ARRAY[('FUZZY'::character varying)::text, ('EXACT'::character varying)::text, ('PARTIAL'::character varying)::text, ('PHONETIC'::character varying)::text])))
);


--
-- Name: screening_field_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_field_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_field_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_field_config_id_seq OWNED BY efrm.screening_field_config.id;


--
-- Name: screening_group_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_group_config (
    id bigint NOT NULL,
    config_master_id bigint NOT NULL,
    group_name character varying(32) NOT NULL,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    weight numeric(6,4) NOT NULL,
    aggregation_type character varying(32) DEFAULT 'WEIGHTED_SUM'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_aggregation_type CHECK (((aggregation_type)::text = ANY (ARRAY[('WEIGHTED_SUM'::character varying)::text, ('MAX'::character varying)::text, ('MIN'::character varying)::text, ('AVERAGE'::character varying)::text]))),
    CONSTRAINT chk_group_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_group_name CHECK (((group_name)::text = ANY (ARRAY[('PRIMARY'::character varying)::text, ('SECONDARY'::character varying)::text])))
);


--
-- Name: screening_group_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_group_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_group_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_group_config_id_seq OWNED BY efrm.screening_group_config.id;


--
-- Name: screening_identifier_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_identifier_config (
    id bigint NOT NULL,
    config_master_id bigint NOT NULL,
    id_type character varying(64) NOT NULL,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    match_type character varying(32) DEFAULT 'EXACT'::character varying NOT NULL,
    minimum_match_score numeric(6,4) DEFAULT 1.0000,
    override_score numeric(6,4),
    immediate_decision character varying(32),
    stop_further_processing_flag character varying(1) DEFAULT 'Y'::character varying CONSTRAINT screening_identifier_config_stop_further_processing_fl_not_null NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_identifier_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_identifier_match_type CHECK (((match_type)::text = ANY (ARRAY[('EXACT'::character varying)::text, ('PARTIAL'::character varying)::text]))),
    CONSTRAINT chk_immediate_decision CHECK (((immediate_decision)::text = ANY (ARRAY[('ESCALATE'::character varying)::text, ('REVIEW'::character varying)::text, ('CLEAR'::character varying)::text, ('MATCH'::character varying)::text]))),
    CONSTRAINT chk_stop_further_processing_flag CHECK (((stop_further_processing_flag)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: screening_identifier_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_identifier_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_identifier_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_identifier_config_id_seq OWNED BY efrm.screening_identifier_config.id;


--
-- Name: screening_match; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_match (
    id bigint NOT NULL,
    result_id bigint NOT NULL,
    list_source_code character varying(64) NOT NULL,
    match_score numeric(4,2) NOT NULL,
    matched_fields character varying(256),
    field_scores jsonb,
    risk_contribution integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    suppressed character varying(1) DEFAULT 'N'::character varying NOT NULL,
    source_data jsonb
);


--
-- Name: screening_match_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_match_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_match_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_match_id_seq OWNED BY efrm.screening_match.id;


--
-- Name: screening_request; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_request (
    id bigint NOT NULL,
    request_id uuid NOT NULL,
    entity_id character varying(128),
    entity_type character varying(32) NOT NULL,
    channel character varying(32) NOT NULL,
    source_system character varying(64) NOT NULL,
    payload jsonb NOT NULL,
    requested_by character varying(64),
    correlation_id character varying(128),
    created_at timestamp without time zone NOT NULL,
    client_request_id character varying(128),
    institution_id character varying(64)
);


--
-- Name: screening_request_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_request_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_request_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_request_id_seq OWNED BY efrm.screening_request.id;


--
-- Name: screening_result; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_result (
    id bigint NOT NULL,
    request_id uuid NOT NULL,
    overall_risk_score integer NOT NULL,
    risk_band character varying(16) NOT NULL,
    decision character varying(32) NOT NULL,
    list_version_snapshot jsonb NOT NULL,
    created_at timestamp without time zone NOT NULL,
    request_type character varying(32),
    entity_id character varying(128),
    is_alert_generated character varying(1) DEFAULT 'N'::character varying,
    is_case_generated character varying(1) DEFAULT 'N'::character varying,
    request_item_index integer,
    request_item_relation character varying(64),
    request_item_payload jsonb
);


--
-- Name: COLUMN screening_result.request_type; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.screening_result.request_type IS 'Request type: NAME, ENTITY, TRANSACTION';


--
-- Name: screening_result_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_result_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_result_id_seq OWNED BY efrm.screening_result.id;


--
-- Name: screening_risk_band; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_risk_band (
    id bigint NOT NULL,
    config_master_id bigint NOT NULL,
    band_code character varying(32) NOT NULL,
    min_score numeric(10,2) NOT NULL,
    max_score numeric(10,2) NOT NULL,
    priority integer NOT NULL,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_band_code CHECK (((band_code)::text = ANY (ARRAY[('HIGH'::character varying)::text, ('MEDIUM'::character varying)::text, ('LOW'::character varying)::text]))),
    CONSTRAINT chk_risk_band_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_score_range CHECK (((min_score >= (0)::numeric) AND (max_score >= min_score)))
);


--
-- Name: screening_risk_band_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_risk_band_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_risk_band_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_risk_band_id_seq OWNED BY efrm.screening_risk_band.id;


--
-- Name: screening_source_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.screening_source_config (
    id bigint NOT NULL,
    config_master_id bigint NOT NULL,
    list_source_code character varying(64) NOT NULL,
    is_enabled character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    calculation_type character varying(32) DEFAULT 'MULTIPLIER_PLUS_BONUS'::character varying NOT NULL,
    base_multiplier numeric(10,4),
    bonus_score numeric(10,4),
    max_contribution numeric(10,4),
    priority integer NOT NULL,
    force_match_flag character varying(1) DEFAULT 'N'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_calculation_type CHECK (((calculation_type)::text = ANY (ARRAY[('MULTIPLIER'::character varying)::text, ('FIXED'::character varying)::text, ('MULTIPLIER_PLUS_BONUS'::character varying)::text]))),
    CONSTRAINT chk_force_match_flag CHECK (((force_match_flag)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text]))),
    CONSTRAINT chk_source_is_enabled CHECK (((is_enabled)::text = ANY (ARRAY[('Y'::character varying)::text, ('N'::character varying)::text])))
);


--
-- Name: screening_source_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.screening_source_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: screening_source_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.screening_source_config_id_seq OWNED BY efrm.screening_source_config.id;


--
-- Name: security_audit_log; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.security_audit_log (
    audit_id character varying(64) NOT NULL,
    event_time timestamp with time zone NOT NULL,
    institution_id character varying(12),
    source_service character varying(64) NOT NULL,
    auth_source character varying(32) NOT NULL,
    event_type character varying(64) NOT NULL,
    outcome character varying(16) NOT NULL,
    reason_code character varying(64),
    actor_type character varying(16) NOT NULL,
    actor_id character varying(128),
    user_id character varying(128),
    role_code character varying(64),
    session_id character varying(64),
    token_reference_id character varying(64),
    request_id character varying(64),
    correlation_id character varying(64),
    resource character varying(128),
    action character varying(64),
    endpoint character varying(256),
    http_method character varying(12),
    http_status integer,
    ip_address character varying(45),
    user_agent character varying(512),
    device_fingerprint character varying(128),
    masked_context text,
    checksum_algorithm character varying(32) NOT NULL,
    checksum_key_id character varying(64) NOT NULL,
    integrity_version integer NOT NULL,
    checksum character varying(64) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    retention_until timestamp with time zone NOT NULL,
    pii_masked_at timestamp with time zone
);


--
-- Name: security_capability; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.security_capability (
    capability_code character varying(128) NOT NULL,
    product_id character varying(32) NOT NULL,
    module_code character varying(64) NOT NULL,
    resource_code character varying(64) NOT NULL,
    menu_id character varying(64),
    action_code character varying(32) NOT NULL,
    display_name character varying(128) NOT NULL,
    description character varying(512),
    risk_level character varying(16) NOT NULL,
    status character varying(16) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    CONSTRAINT chk_scap_action CHECK (((action_code)::text = ANY ((ARRAY['VIEW'::character varying, 'CREATE'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying, 'EXECUTE'::character varying, 'APPROVE'::character varying, 'REJECT'::character varying, 'DECIDE'::character varying, 'ASSIGN'::character varying, 'CLOSE'::character varying, 'UPLOAD'::character varying, 'EXPORT'::character varying, 'CONFIGURE'::character varying, 'MANAGE'::character varying])::text[]))),
    CONSTRAINT chk_scap_risk CHECK (((risk_level)::text = ANY ((ARRAY['LOW'::character varying, 'MEDIUM'::character varying, 'HIGH'::character varying, 'CRITICAL'::character varying])::text[]))),
    CONSTRAINT chk_scap_status CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'INACTIVE'::character varying])::text[])))
);


--
-- Name: security_check; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.security_check (
    security_check_id character varying(32) NOT NULL,
    security_check_name character varying(128) NOT NULL,
    security_check_description character varying(128) NOT NULL,
    session_expiry_check character varying(1),
    ipaddress_check character varying(1),
    login_expiry_check character varying(1),
    password_attempt_count_check character varying(1),
    password_expiry_check character varying(1),
    password_repeatable_check character varying(1),
    captcha_check character varying(1),
    device_fingerprint_check character varying(1),
    geolocation_check character varying(1),
    parallel_session_limit_check character varying(1),
    time_based_access_check character varying(1),
    browser_validation_check character varying(1),
    anti_phishing_code_check character varying(1),
    fraud_scoring_check character varying(1),
    authorization_matrix_check character varying(1),
    rate_limiting_check character varying(1),
    session_timeout_minutes integer,
    login_expiry_hours integer,
    password_expiry_days integer,
    password_history_count integer,
    max_password_attempts integer,
    lock_duration_minutes integer,
    max_concurrent_sessions integer,
    rate_limit_per_minute integer,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL
);


--
-- Name: security_notification; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.security_notification (
    notification_id character varying(64) NOT NULL,
    user_id character varying(128) NOT NULL,
    event_type character varying(64) NOT NULL,
    channel character varying(16) NOT NULL,
    recipient character varying(128) NOT NULL,
    message_template character varying(64) NOT NULL,
    status character varying(16) NOT NULL,
    sent_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL
);


--
-- Name: service_client; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.service_client (
    client_id character varying(64) NOT NULL,
    client_name character varying(128) NOT NULL,
    status character varying(16) NOT NULL,
    auth_method character varying(32) NOT NULL,
    secret_hash character varying(256),
    public_key_ref character varying(256),
    allowed_scopes text NOT NULL,
    token_ttl_seconds integer NOT NULL,
    last_rotated_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL
);


--
-- Name: service_token_jti; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.service_token_jti (
    jti character varying(64) NOT NULL,
    client_id character varying(64) NOT NULL,
    issued_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    revoked_at timestamp with time zone,
    status character varying(16) NOT NULL
);


--
-- Name: sla_escalation; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.sla_escalation (
    escalation_id bigint NOT NULL,
    sla_id bigint NOT NULL,
    escalation_level integer NOT NULL,
    escalation_after_minutes integer NOT NULL,
    escalate_to_role character varying(50) NOT NULL,
    notify character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    notification_template character varying(50),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL
);


--
-- Name: COLUMN sla_escalation.sla_id; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_escalation.sla_id IS 'Reference to SLA policy';


--
-- Name: COLUMN sla_escalation.escalation_level; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_escalation.escalation_level IS 'Escalation level: 1, 2, 3';


--
-- Name: COLUMN sla_escalation.escalation_after_minutes; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_escalation.escalation_after_minutes IS 'Escalate after this many minutes (e.g., +30 mins)';


--
-- Name: COLUMN sla_escalation.escalate_to_role; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_escalation.escalate_to_role IS 'Role to escalate to: SUPERVISOR, COMPLIANCE_HEAD';


--
-- Name: COLUMN sla_escalation.notify; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_escalation.notify IS 'Notification flag: Y/N';


--
-- Name: COLUMN sla_escalation.notification_template; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_escalation.notification_template IS 'Notification template identifier';


--
-- Name: COLUMN sla_escalation.is_active; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_escalation.is_active IS 'Whether the escalation rule is active: Y/N';


--
-- Name: sla_escalation_escalation_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.sla_escalation_escalation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sla_escalation_escalation_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.sla_escalation_escalation_id_seq OWNED BY efrm.sla_escalation.escalation_id;


--
-- Name: sla_policy; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.sla_policy (
    sla_id bigint NOT NULL,
    action_type character varying(50) NOT NULL,
    alert_type character varying(50) NOT NULL,
    priority character varying(10) NOT NULL,
    sla_name character varying(100) NOT NULL,
    response_time_minutes integer NOT NULL,
    resolution_time_minutes integer NOT NULL,
    business_hours_only character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    escalation_required character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN sla_policy.action_type; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_policy.action_type IS 'CASE_CREATE, STR_CTR, REPORT';


--
-- Name: COLUMN sla_policy.alert_type; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_policy.alert_type IS 'screening_result, rule_engine_result';


--
-- Name: COLUMN sla_policy.priority; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_policy.priority IS 'P1, P2, P3';


--
-- Name: COLUMN sla_policy.sla_name; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_policy.sla_name IS 'Name of the SLA policy';


--
-- Name: COLUMN sla_policy.response_time_minutes; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_policy.response_time_minutes IS 'First action SLA in minutes';


--
-- Name: COLUMN sla_policy.resolution_time_minutes; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_policy.resolution_time_minutes IS 'Case closure SLA in minutes';


--
-- Name: COLUMN sla_policy.business_hours_only; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_policy.business_hours_only IS 'Whether SLA applies only during business hours: Y/N';


--
-- Name: COLUMN sla_policy.escalation_required; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_policy.escalation_required IS 'Whether escalation is required: Y/N';


--
-- Name: COLUMN sla_policy.is_active; Type: COMMENT; Schema: efrm; Owner: -
--

COMMENT ON COLUMN efrm.sla_policy.is_active IS 'Whether the SLA policy is active: Y/N';


--
-- Name: sla_policy_sla_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.sla_policy_sla_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sla_policy_sla_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.sla_policy_sla_id_seq OWNED BY efrm.sla_policy.sla_id;


--
-- Name: source_attribute_def; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.source_attribute_def (
    id integer NOT NULL,
    facts character varying(64) NOT NULL,
    key character varying(128) NOT NULL,
    label character varying(128) NOT NULL,
    data_type character varying(16) NOT NULL,
    enum_source character varying(64),
    unit character varying(32),
    condition character varying(1),
    description character varying(128),
    rule_engine_key character varying(64),
    transform_type character varying(32),
    rule_engine_key_type character varying(1) NOT NULL,
    display_order integer,
    example_value character varying(128)
);


--
-- Name: source_attribute_def_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.source_attribute_def_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_attribute_def_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.source_attribute_def_id_seq OWNED BY efrm.source_attribute_def.id;


--
-- Name: source_column_mapping; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.source_column_mapping (
    mapping_id bigint NOT NULL,
    source_code character varying(50) NOT NULL,
    file_column_name character varying(100) NOT NULL,
    target_field character varying(50) NOT NULL,
    entity_type character varying(20),
    transform_rule character varying(50),
    is_required character varying(1) DEFAULT 'N'::character varying NOT NULL,
    default_value character varying(200),
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    modified_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT source_column_mapping_entity_type_check CHECK (((entity_type)::text = ANY (ARRAY[('ENTITY'::character varying)::text, ('ALIAS'::character varying)::text])))
);


--
-- Name: source_column_mapping_mapping_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.source_column_mapping_mapping_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_column_mapping_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.source_column_mapping_mapping_id_seq OWNED BY efrm.source_column_mapping.mapping_id;


--
-- Name: source_config; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.source_config (
    id bigint NOT NULL,
    list_source_id bigint NOT NULL,
    code character varying(64) NOT NULL,
    description character varying(512),
    download_url text NOT NULL,
    file_name character varying(128),
    file_format character varying(32) NOT NULL,
    compression character varying(16) NOT NULL,
    auth_type character varying(32) NOT NULL,
    auth_token text,
    http_headers jsonb,
    extra_params jsonb,
    last_success_at timestamp without time zone,
    last_error_at timestamp without time zone,
    last_error_msg text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    frequency character varying(32)
);


--
-- Name: source_config_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.source_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_config_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.source_config_id_seq OWNED BY efrm.source_config.id;


--
-- Name: source_system_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.source_system_master (
    source_system_id integer NOT NULL,
    institution_id character varying(64) NOT NULL,
    institution_name character varying(128),
    source_system_code character varying(32) NOT NULL,
    source_system_name character varying(128) NOT NULL,
    source_system_type character varying(32) NOT NULL,
    source_sub_type character varying(32),
    message_standard character varying(32),
    message_variant character varying(32),
    payload_format character varying(16),
    encoding_type character varying(16),
    is_real_time character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    max_tps integer,
    avg_latency_ms integer,
    supports_reversal character varying(1) DEFAULT 'N'::character varying NOT NULL,
    supports_partial_reversal character varying(1) DEFAULT 'N'::character varying NOT NULL,
    supports_batch character varying(1) DEFAULT 'N'::character varying NOT NULL,
    default_channel character varying(32),
    supported_channels character varying(128),
    supported_txn_types character varying(256),
    supported_instruments character varying(128),
    default_country character varying(2),
    default_currency character varying(3),
    supports_multi_currency character varying(1) DEFAULT 'N'::character varying NOT NULL,
    supports_cross_border character varying(1) DEFAULT 'N'::character varying NOT NULL,
    frm_enabled character varying(1) DEFAULT 'N'::character varying NOT NULL,
    aml_enabled character varying(1) DEFAULT 'N'::character varying NOT NULL,
    sanctions_enabled character varying(1) DEFAULT 'N'::character varying NOT NULL,
    velocity_supported character varying(1) DEFAULT 'N'::character varying NOT NULL,
    device_data_supported character varying(1) DEFAULT 'N'::character varying NOT NULL,
    risk_scoring_profile character varying(32),
    regulatory_scope character varying(128),
    supports_reserved_json character varying(1) DEFAULT 'N'::character varying NOT NULL,
    max_reserved_fields integer DEFAULT 50,
    pii_classification character varying(32),
    data_retention_days integer,
    heartbeat_required character varying(1) DEFAULT 'N'::character varying NOT NULL,
    heartbeat_interval_sec integer,
    failure_threshold integer,
    auto_disable_on_failure character varying(1) DEFAULT 'N'::character varying NOT NULL,
    config_json jsonb,
    description text,
    is_active character varying(1) DEFAULT 'Y'::character varying NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    owner_team character varying(64),
    approval_status character varying(16) DEFAULT 'APPROVED'::character varying NOT NULL,
    approved_by character varying(64),
    approved_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: source_system_master_source_system_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.source_system_master_source_system_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_system_master_source_system_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.source_system_master_source_system_id_seq OWNED BY efrm.source_system_master.source_system_id;


--
-- Name: transaction_alert; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.transaction_alert (
    id integer NOT NULL,
    transaction_result_id integer NOT NULL,
    alert_code character varying(64) NOT NULL,
    alert_category character varying(16) NOT NULL,
    alert_severity character varying(16) NOT NULL,
    decision character varying(16) NOT NULL,
    customer_id character varying(64),
    transaction_id character varying(64),
    alert_payload jsonb NOT NULL,
    status character varying(16) DEFAULT 'OPEN'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    severity_rank integer DEFAULT 1 NOT NULL,
    user_action character varying(20)
);


--
-- Name: transaction_alert_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.transaction_alert_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_alert_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.transaction_alert_seq OWNED BY efrm.transaction_alert.id;


--
-- Name: transaction_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.transaction_master (
    id integer NOT NULL,
    transaction_request_id integer NOT NULL,
    transaction_id character varying(64) NOT NULL,
    source_txn_id character varying(64),
    rrn character varying(64),
    correlation_id character varying(64),
    institution_id character varying(64) NOT NULL,
    source_system character varying(32) NOT NULL,
    channel character varying(32) NOT NULL,
    txn_type character varying(32),
    txn_sub_type character varying(32),
    customer_id character varying(64),
    account_id character varying(64),
    card_id character varying(16),
    txn_amount numeric(18,2),
    txn_currency character varying(8),
    txn_timestamp timestamp without time zone,
    rule_engine_context jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    txn_country character varying(8),
    network_id character varying(16),
    is_international character varying(1)
);


--
-- Name: transaction_master_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.transaction_master_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_master_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.transaction_master_id_seq OWNED BY efrm.transaction_master.id;


--
-- Name: transaction_match; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.transaction_match (
    id integer NOT NULL,
    transaction_result_id integer NOT NULL,
    rule_group_version integer NOT NULL,
    rule_code character varying(64) NOT NULL,
    rule_version integer NOT NULL,
    signal_code character varying(64) NOT NULL,
    signal_severity character varying(16) NOT NULL,
    severity_rank integer NOT NULL,
    signal_weight integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: transaction_match_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.transaction_match_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_match_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.transaction_match_seq OWNED BY efrm.transaction_match.id;


--
-- Name: transaction_request; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.transaction_request (
    id integer NOT NULL,
    request_id character varying(64) NOT NULL,
    institution_id character varying(64) NOT NULL,
    source_system character varying(32) NOT NULL,
    channel character varying(32) NOT NULL,
    api_name character varying(64) NOT NULL,
    request_payload jsonb NOT NULL,
    response_payload jsonb,
    http_status integer,
    processing_time_ms integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    fact character varying(64),
    is_test character varying(1) DEFAULT 'N'::character varying NOT NULL
);


--
-- Name: transaction_request_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.transaction_request_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_request_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.transaction_request_seq OWNED BY efrm.transaction_request.id;


--
-- Name: transaction_result; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.transaction_result (
    id integer NOT NULL,
    transaction_master_id integer NOT NULL,
    raw_score integer,
    highest_severity character varying(16),
    highest_severity_rank integer,
    matched_rule_count integer,
    final_decision character varying(16) NOT NULL,
    decision_strategy character varying(32),
    decision_policy_code character varying(64),
    execution_time_ms integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    overall_score integer,
    entity_id character varying(128) NOT NULL,
    is_alert_generated character varying(1) DEFAULT 'N'::character varying,
    is_case_generated character varying(1) DEFAULT 'N'::character varying
);


--
-- Name: transaction_result_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.transaction_result_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: transaction_result_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.transaction_result_seq OWNED BY efrm.transaction_result.id;


--
-- Name: user_credential; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.user_credential (
    credential_id character varying(64) NOT NULL,
    user_id character varying(128) NOT NULL,
    credential_type character varying(32) NOT NULL,
    password_hash character varying(256) NOT NULL,
    hash_algorithm character varying(32) NOT NULL,
    is_active character varying(1) NOT NULL,
    credential_expires_at timestamp with time zone,
    must_change_on_login character varying(1) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL
);


--
-- Name: user_master; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.user_master (
    user_name character varying(128) NOT NULL,
    user_password character varying(128) NOT NULL,
    user_type character varying(20) NOT NULL,
    profile_id character varying(32) NOT NULL,
    institution_id character varying(12) NOT NULL,
    first_name character varying(128) NOT NULL,
    middle_name character varying(128),
    last_name character varying(128) NOT NULL,
    email_id character varying(128) NOT NULL,
    user_status character varying(12) NOT NULL,
    user_reference_id character varying(128) NOT NULL,
    description character varying(128),
    branch_code character varying(128),
    ip_address character varying(128),
    password_retry_count integer,
    expiry_date timestamp with time zone NOT NULL,
    login_status character varying(1) NOT NULL,
    first_time character varying(1) NOT NULL,
    password_expiry_date timestamp with time zone,
    password_expiry_flag character varying(1) NOT NULL,
    password_repeat_count integer,
    forgot_password_flag character varying(1) NOT NULL,
    last_login timestamp with time zone NOT NULL,
    added_user_name character varying(128) NOT NULL,
    added_date timestamp with time zone NOT NULL,
    approved_user_name character varying(128) NOT NULL,
    approved_date timestamp with time zone NOT NULL,
    unblocked_user_name character varying(128),
    unblocked_date timestamp with time zone,
    password_reset_user_name character varying(128),
    password_reset_date timestamp with time zone,
    deleted_user_name character varying(128),
    deleted_date timestamp with time zone,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL
);


--
-- Name: user_password_history; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.user_password_history (
    id integer NOT NULL,
    user_name character varying(128) NOT NULL,
    password_hash character varying(255) NOT NULL,
    changed_at timestamp with time zone NOT NULL,
    is_current character varying(1) NOT NULL,
    is_expired character varying(1) NOT NULL,
    source character varying(128),
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL
);


--
-- Name: user_password_history_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.user_password_history_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_session; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.user_session (
    session_id character varying(64) NOT NULL,
    user_id character varying(128) NOT NULL,
    security_check_id character varying(32) NOT NULL,
    ip_address character varying(45) NOT NULL,
    device_fingerprint character varying(128),
    user_agent character varying(512),
    token_hash character varying(128) NOT NULL,
    current_access_jti character varying(64) NOT NULL,
    status character varying(16) NOT NULL,
    session_scope character varying(32) NOT NULL,
    auth_source character varying(32) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    last_activity_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    absolute_expires_at timestamp with time zone NOT NULL,
    terminated_at timestamp with time zone,
    termination_reason character varying(64),
    CONSTRAINT chk_usess_scope CHECK (((session_scope)::text = ANY ((ARRAY['FULL'::character varying, 'PASSWORD_CHANGE'::character varying])::text[]))),
    CONSTRAINT chk_usess_status CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'EXPIRED'::character varying, 'LOGGED_OUT'::character varying, 'REVOKED'::character varying])::text[])))
);


--
-- Name: whitelist_entry; Type: TABLE; Schema: efrm; Owner: -
--

CREATE TABLE efrm.whitelist_entry (
    id bigint NOT NULL,
    entity_id character varying(128) NOT NULL,
    entity_type character varying(32) NOT NULL,
    list_source_code character varying(64) NOT NULL,
    list_entity_id bigint,
    reason_code character varying(64) NOT NULL,
    comments text,
    created_by character varying(64) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    valid_until timestamp without time zone
);


--
-- Name: whitelist_entry_id_seq; Type: SEQUENCE; Schema: efrm; Owner: -
--

CREATE SEQUENCE efrm.whitelist_entry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: whitelist_entry_id_seq; Type: SEQUENCE OWNED BY; Schema: efrm; Owner: -
--

ALTER SEQUENCE efrm.whitelist_entry_id_seq OWNED BY efrm.whitelist_entry.id;


--
-- Name: adverse_integration_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_integration_config ALTER COLUMN id SET DEFAULT nextval('efrm.adverse_integration_config_id_seq'::regclass);


--
-- Name: alert_category_master id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.alert_category_master ALTER COLUMN id SET DEFAULT nextval('efrm.alert_category_master_id_seq'::regclass);


--
-- Name: alert_count_boost_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.alert_count_boost_config ALTER COLUMN id SET DEFAULT nextval('efrm.alert_count_boost_config_id_seq'::regclass);


--
-- Name: assignment_config config_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.assignment_config ALTER COLUMN config_id SET DEFAULT nextval('efrm.case_assignment_config_config_id_seq'::regclass);


--
-- Name: bulk_file_upload id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.bulk_file_upload ALTER COLUMN id SET DEFAULT nextval('efrm.bulk_file_upload_id_seq'::regclass);


--
-- Name: case_action_execution_log log_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_execution_log ALTER COLUMN log_id SET DEFAULT nextval('efrm.case_action_execution_log_log_id_seq'::regclass);


--
-- Name: case_action_execution_queue execution_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_execution_queue ALTER COLUMN execution_id SET DEFAULT nextval('efrm.case_action_execution_queue_execution_id_seq'::regclass);


--
-- Name: case_action_master action_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_master ALTER COLUMN action_id SET DEFAULT nextval('efrm.case_action_master_action_id_seq'::regclass);


--
-- Name: case_alert_mapping id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_alert_mapping ALTER COLUMN id SET DEFAULT nextval('efrm.case_alert_mapping_id_seq'::regclass);


--
-- Name: case_assignment assignment_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_assignment ALTER COLUMN assignment_id SET DEFAULT nextval('efrm.case_assignment_assignment_id_seq'::regclass);


--
-- Name: case_config_master id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_config_master ALTER COLUMN id SET DEFAULT nextval('efrm.case_config_master_id_seq'::regclass);


--
-- Name: case_decision_action_mapping mapping_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_decision_action_mapping ALTER COLUMN mapping_id SET DEFAULT nextval('efrm.case_decision_action_mapping_mapping_id_seq'::regclass);


--
-- Name: case_decision_master decision_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_decision_master ALTER COLUMN decision_id SET DEFAULT nextval('efrm.case_decision_master_decision_id_seq'::regclass);


--
-- Name: case_events event_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_events ALTER COLUMN event_id SET DEFAULT nextval('efrm.case_events_event_id_seq'::regclass);


--
-- Name: case_evidence evidence_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_evidence ALTER COLUMN evidence_id SET DEFAULT nextval('efrm.case_evidence_evidence_id_seq'::regclass);


--
-- Name: case_master case_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_master ALTER COLUMN case_id SET DEFAULT nextval('efrm.cases_case_id_seq'::regclass);


--
-- Name: case_priority_master id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_priority_master ALTER COLUMN id SET DEFAULT nextval('efrm.case_priority_master_id_seq'::regclass);


--
-- Name: case_recovery recovery_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_recovery ALTER COLUMN recovery_id SET DEFAULT nextval('efrm.case_recovery_recovery_id_seq'::regclass);


--
-- Name: case_score_breakdown id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_score_breakdown ALTER COLUMN id SET DEFAULT nextval('efrm.case_score_breakdown_id_seq'::regclass);


--
-- Name: case_scoring_trace id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_scoring_trace ALTER COLUMN id SET DEFAULT nextval('efrm.case_scoring_trace_id_seq'::regclass);


--
-- Name: case_sla_tracker tracker_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_sla_tracker ALTER COLUMN tracker_id SET DEFAULT nextval('efrm.case_sla_tracker_tracker_id_seq'::regclass);


--
-- Name: category_correlation_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.category_correlation_config ALTER COLUMN id SET DEFAULT nextval('efrm.category_correlation_config_id_seq'::regclass);


--
-- Name: chatbot_audit_log id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.chatbot_audit_log ALTER COLUMN id SET DEFAULT nextval('efrm.chatbot_audit_log_id_seq'::regclass);


--
-- Name: critical_override_rules id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.critical_override_rules ALTER COLUMN id SET DEFAULT nextval('efrm.critical_override_rules_id_seq'::regclass);


--
-- Name: device_alert id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_alert ALTER COLUMN id SET DEFAULT nextval('efrm.device_alert_id_seq'::regclass);


--
-- Name: device_master id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_master ALTER COLUMN id SET DEFAULT nextval('efrm.device_master_id_seq'::regclass);


--
-- Name: device_match id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_match ALTER COLUMN id SET DEFAULT nextval('efrm.device_match_id_seq'::regclass);


--
-- Name: device_request id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_request ALTER COLUMN id SET DEFAULT nextval('efrm.device_request_id_seq'::regclass);


--
-- Name: device_result id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_result ALTER COLUMN id SET DEFAULT nextval('efrm.device_result_id_seq'::regclass);


--
-- Name: efrm_service_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.efrm_service_config ALTER COLUMN id SET DEFAULT nextval('efrm.efrm_service_config_id_seq'::regclass);


--
-- Name: engine_attribute_def id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.engine_attribute_def ALTER COLUMN id SET DEFAULT nextval('efrm.engine_attribute_def_id_seq'::regclass);


--
-- Name: entity_device_map entity_device_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_device_map ALTER COLUMN entity_device_id SET DEFAULT nextval('efrm.entity_device_map_entity_device_id_seq'::regclass);


--
-- Name: entity_graph_cluster_nodes id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_cluster_nodes ALTER COLUMN id SET DEFAULT nextval('efrm.entity_graph_cluster_nodes_id_seq'::regclass);


--
-- Name: entity_graph_clusters cluster_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_clusters ALTER COLUMN cluster_id SET DEFAULT nextval('efrm.entity_graph_clusters_cluster_id_seq'::regclass);


--
-- Name: entity_graph_edges edge_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_edges ALTER COLUMN edge_id SET DEFAULT nextval('efrm.entity_graph_edges_edge_id_seq'::regclass);


--
-- Name: entity_graph_evidence id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_evidence ALTER COLUMN id SET DEFAULT nextval('efrm.entity_graph_evidence_id_seq'::regclass);


--
-- Name: entity_graph_nodes node_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_nodes ALTER COLUMN node_id SET DEFAULT nextval('efrm.entity_graph_nodes_node_id_seq'::regclass);


--
-- Name: entity_graph_refresh_checkpoint id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_refresh_checkpoint ALTER COLUMN id SET DEFAULT nextval('efrm.entity_graph_refresh_checkpoint_id_seq'::regclass);


--
-- Name: entity_graph_refresh_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_refresh_config ALTER COLUMN id SET DEFAULT nextval('efrm.entity_graph_refresh_config_id_seq'::regclass);


--
-- Name: entity_graph_view_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_view_config ALTER COLUMN id SET DEFAULT nextval('efrm.entity_graph_view_config_id_seq'::regclass);


--
-- Name: entity_master entity_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_master ALTER COLUMN entity_id SET DEFAULT nextval('efrm.entity_master_entity_id_seq'::regclass);


--
-- Name: entity_relation_map entity_relation_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_relation_map ALTER COLUMN entity_relation_id SET DEFAULT nextval('efrm.entity_relation_map_entity_relation_id_seq'::regclass);


--
-- Name: entity_risk_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_config ALTER COLUMN id SET DEFAULT nextval('efrm.entity_risk_config_id_seq'::regclass);


--
-- Name: entity_risk_factor_breakdown id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_factor_breakdown ALTER COLUMN id SET DEFAULT nextval('efrm.entity_risk_factor_breakdown_id_seq'::regclass);


--
-- Name: entity_risk_history id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_history ALTER COLUMN id SET DEFAULT nextval('efrm.entity_risk_history_id_seq'::regclass);


--
-- Name: entity_risk_profile id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_profile ALTER COLUMN id SET DEFAULT nextval('efrm.entity_risk_profile_id_seq'::regclass);


--
-- Name: enum_value id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.enum_value ALTER COLUMN id SET DEFAULT nextval('efrm.enum_value_id_seq'::regclass);


--
-- Name: facts_definition id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.facts_definition ALTER COLUMN id SET DEFAULT nextval('efrm.facts_definition_id_seq'::regclass);


--
-- Name: graph_dimension_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.graph_dimension_config ALTER COLUMN id SET DEFAULT nextval('efrm.graph_dimension_config_id_seq'::regclass);


--
-- Name: graph_dimension_subtype_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.graph_dimension_subtype_config ALTER COLUMN id SET DEFAULT nextval('efrm.graph_dimension_subtype_config_id_seq'::regclass);


--
-- Name: institution_type id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.institution_type ALTER COLUMN id SET DEFAULT nextval('efrm.institution_type_id_seq'::regclass);


--
-- Name: integration_endpoint_config endpoint_config_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.integration_endpoint_config ALTER COLUMN endpoint_config_id SET DEFAULT nextval('efrm.integration_endpoint_config_endpoint_config_id_seq'::regclass);


--
-- Name: list_entity id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_entity ALTER COLUMN id SET DEFAULT nextval('efrm.list_entity_id_seq'::regclass);


--
-- Name: list_entity_alias id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_entity_alias ALTER COLUMN id SET DEFAULT nextval('efrm.list_entity_alias_id_seq'::regclass);


--
-- Name: list_normalized_address id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_normalized_address ALTER COLUMN id SET DEFAULT nextval('efrm.list_normalized_address_id_seq'::regclass);


--
-- Name: list_source id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_source ALTER COLUMN id SET DEFAULT nextval('efrm.list_source_id_seq'::regclass);


--
-- Name: list_version id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_version ALTER COLUMN id SET DEFAULT nextval('efrm.list_version_id_seq'::regclass);


--
-- Name: ml_feature_definition feature_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_definition ALTER COLUMN feature_id SET DEFAULT nextval('efrm.ml_feature_definition_feature_id_seq'::regclass);


--
-- Name: ml_feature_definition_metadata feature_metadata_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_definition_metadata ALTER COLUMN feature_metadata_id SET DEFAULT nextval('efrm.ml_feature_definition_metadata_seq'::regclass);


--
-- Name: ml_feature_set feature_set_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_set ALTER COLUMN feature_set_id SET DEFAULT nextval('efrm.ml_feature_set_feature_set_id_seq'::regclass);


--
-- Name: ml_feature_set_version feature_set_version_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_set_version ALTER COLUMN feature_set_version_id SET DEFAULT nextval('efrm.ml_feature_set_version_feature_set_version_id_seq'::regclass);


--
-- Name: ml_feedback feedback_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feedback ALTER COLUMN feedback_id SET DEFAULT nextval('efrm.ml_feedback_feedback_id_seq'::regclass);


--
-- Name: ml_inference_result inference_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_result ALTER COLUMN inference_id SET DEFAULT nextval('efrm.ml_inference_result_inference_id_seq'::regclass);


--
-- Name: ml_inference_shap_local inference_shap_local_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_shap_local ALTER COLUMN inference_shap_local_id SET DEFAULT nextval('efrm.ml_inference_shap_local_seq'::regclass);


--
-- Name: ml_job_dead_letter dead_letter_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_job_dead_letter ALTER COLUMN dead_letter_id SET DEFAULT nextval('efrm.ml_job_dead_letter_dead_letter_id_seq'::regclass);


--
-- Name: ml_model_drift_summary model_drift_summary_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_drift_summary ALTER COLUMN model_drift_summary_id SET DEFAULT nextval('efrm.ml_model_drift_summary_model_drift_summary_id_seq'::regclass);


--
-- Name: ml_model_feature_drift model_feature_drift_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_feature_drift ALTER COLUMN model_feature_drift_id SET DEFAULT nextval('efrm.ml_model_feature_drift_model_feature_drift_id_seq'::regclass);


--
-- Name: ml_model_governance model_governance_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_governance ALTER COLUMN model_governance_id SET DEFAULT nextval('efrm.ml_model_governance_model_governance_id_seq'::regclass);


--
-- Name: ml_model_job model_job_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_job ALTER COLUMN model_job_id SET DEFAULT nextval('efrm.ml_model_job_seq'::regclass);


--
-- Name: ml_model_performance_daily model_performance_daily_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_performance_daily ALTER COLUMN model_performance_daily_id SET DEFAULT nextval('efrm.ml_model_performance_daily_model_performance_daily_id_seq'::regclass);


--
-- Name: ml_model_registry model_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_registry ALTER COLUMN model_id SET DEFAULT nextval('efrm.ml_model_registry_model_id_seq'::regclass);


--
-- Name: ml_model_runtime_metrics model_runtime_metrics_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_runtime_metrics ALTER COLUMN model_runtime_metrics_id SET DEFAULT nextval('efrm.ml_model_runtime_metrics_model_runtime_metrics_id_seq'::regclass);


--
-- Name: ml_model_shap_global model_shap_global_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_shap_global ALTER COLUMN model_shap_global_id SET DEFAULT nextval('efrm.ml_model_shap_global_model_shap_global_id_seq'::regclass);


--
-- Name: ml_model_version model_version_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_version ALTER COLUMN model_version_id SET DEFAULT nextval('efrm.ml_model_version_model_version_id_seq'::regclass);


--
-- Name: ml_score_blending_policy policy_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_score_blending_policy ALTER COLUMN policy_id SET DEFAULT nextval('efrm.ml_score_blending_policy_policy_id_seq'::regclass);


--
-- Name: ml_training_dataset_profile model_training_dataset_profile_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_training_dataset_profile ALTER COLUMN model_training_dataset_profile_id SET DEFAULT nextval('efrm.ml_training_dataset_profile_model_training_dataset_profile__seq'::regclass);


--
-- Name: notification_queue notification_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.notification_queue ALTER COLUMN notification_id SET DEFAULT nextval('efrm.notification_queue_notification_id_seq'::regclass);


--
-- Name: notification_template template_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.notification_template ALTER COLUMN template_id SET DEFAULT nextval('efrm.notification_template_template_id_seq'::regclass);


--
-- Name: operator_value id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.operator_value ALTER COLUMN id SET DEFAULT nextval('efrm.operator_id_seq'::regclass);


--
-- Name: reference_data ref_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.reference_data ALTER COLUMN ref_id SET DEFAULT nextval('efrm.reference_data_ref_id_seq'::regclass);


--
-- Name: risk_event_log id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_event_log ALTER COLUMN id SET DEFAULT nextval('efrm.risk_event_log_id_seq'::regclass);


--
-- Name: risk_rating_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_config ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_config_id_seq'::regclass);


--
-- Name: risk_rating_decay_policy_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_decay_policy_config ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_decay_policy_config_id_seq'::regclass);


--
-- Name: risk_rating_decision_impact_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_decision_impact_config ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_decision_impact_config_id_seq'::regclass);


--
-- Name: risk_rating_domain_override_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_domain_override_config ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_domain_override_config_id_seq'::regclass);


--
-- Name: risk_rating_event_type_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_event_type_config ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_event_type_config_id_seq'::regclass);


--
-- Name: risk_rating_override_policy id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_override_policy ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_override_policy_id_seq'::regclass);


--
-- Name: risk_rating_relationship_risk_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_relationship_risk_config ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_relationship_risk_config_id_seq'::regclass);


--
-- Name: risk_rating_service_weight_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_service_weight_config ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_service_weight_config_id_seq'::regclass);


--
-- Name: risk_rating_tier_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_tier_config ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_tier_config_id_seq'::regclass);


--
-- Name: risk_rating_weight_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_weight_config ALTER COLUMN id SET DEFAULT nextval('efrm.risk_rating_weight_config_id_seq'::regclass);


--
-- Name: risk_recalculation_job id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_recalculation_job ALTER COLUMN id SET DEFAULT nextval('efrm.risk_recalculation_job_id_seq'::regclass);


--
-- Name: rule_decision_policy id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_decision_policy ALTER COLUMN id SET DEFAULT nextval('efrm.rule_decision_policy_id_seq'::regclass);


--
-- Name: rule_decision_upgrade id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_decision_upgrade ALTER COLUMN id SET DEFAULT nextval('efrm.ruleengine_decision_upgrade_id_seq'::regclass);


--
-- Name: rule_drl_context id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_drl_context ALTER COLUMN id SET DEFAULT nextval('efrm.rule_drl_context_id_seq'::regclass);


--
-- Name: rule_group_master id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_master ALTER COLUMN id SET DEFAULT nextval('efrm.rule_group_master_id_seq'::regclass);


--
-- Name: rule_group_source_binding id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_source_binding ALTER COLUMN id SET DEFAULT nextval('efrm.rule_group_source_binding_id_seq'::regclass);


--
-- Name: rule_group_version id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_version ALTER COLUMN id SET DEFAULT nextval('efrm.rule_group_version_id_seq'::regclass);


--
-- Name: rule_group_version_map id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_version_map ALTER COLUMN id SET DEFAULT nextval('efrm.rule_group_version_map_id_seq'::regclass);


--
-- Name: rule_master id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_master ALTER COLUMN id SET DEFAULT nextval('efrm.rule_master_id_seq'::regclass);


--
-- Name: rule_master_tag id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_master_tag ALTER COLUMN id SET DEFAULT nextval('efrm.rule_master_tag_id_seq'::regclass);


--
-- Name: rule_version id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_version ALTER COLUMN id SET DEFAULT nextval('efrm.rule_version_id_seq'::regclass);


--
-- Name: ruleengine_bulk_job id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job ALTER COLUMN id SET DEFAULT nextval('efrm.ruleengine_bulk_job_id_seq'::regclass);


--
-- Name: ruleengine_bulk_job_item id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job_item ALTER COLUMN id SET DEFAULT nextval('efrm.ruleengine_bulk_job_item_id_seq'::regclass);


--
-- Name: ruleengine_bulk_job_summary id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job_summary ALTER COLUMN id SET DEFAULT nextval('efrm.ruleengine_bulk_job_summary_id_seq'::regclass);


--
-- Name: screening_alert id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_alert ALTER COLUMN id SET DEFAULT nextval('efrm.screening_alert_id_seq'::regclass);


--
-- Name: screening_bulk_job id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job ALTER COLUMN id SET DEFAULT nextval('efrm.screening_bulk_job_id_seq'::regclass);


--
-- Name: screening_bulk_job_item id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job_item ALTER COLUMN id SET DEFAULT nextval('efrm.screening_bulk_job_item_id_seq'::regclass);


--
-- Name: screening_bulk_job_summary id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job_summary ALTER COLUMN id SET DEFAULT nextval('efrm.screening_bulk_job_summary_id_seq'::regclass);


--
-- Name: screening_config_master id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_config_master ALTER COLUMN id SET DEFAULT nextval('efrm.screening_config_master_id_seq'::regclass);


--
-- Name: screening_decision_threshold id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_decision_threshold ALTER COLUMN id SET DEFAULT nextval('efrm.screening_decision_threshold_id_seq'::regclass);


--
-- Name: screening_entity id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_entity ALTER COLUMN id SET DEFAULT nextval('efrm.screening_entity_id_seq'::regclass);


--
-- Name: screening_entity_field field_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_entity_field ALTER COLUMN field_id SET DEFAULT nextval('efrm.screening_entity_field_field_id_seq'::regclass);


--
-- Name: screening_entity_relation relation_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_entity_relation ALTER COLUMN relation_id SET DEFAULT nextval('efrm.screening_entity_relation_relation_id_seq'::regclass);


--
-- Name: screening_field_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_field_config ALTER COLUMN id SET DEFAULT nextval('efrm.screening_field_config_id_seq'::regclass);


--
-- Name: screening_group_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_group_config ALTER COLUMN id SET DEFAULT nextval('efrm.screening_group_config_id_seq'::regclass);


--
-- Name: screening_identifier_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_identifier_config ALTER COLUMN id SET DEFAULT nextval('efrm.screening_identifier_config_id_seq'::regclass);


--
-- Name: screening_match id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_match ALTER COLUMN id SET DEFAULT nextval('efrm.screening_match_id_seq'::regclass);


--
-- Name: screening_request id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_request ALTER COLUMN id SET DEFAULT nextval('efrm.screening_request_id_seq'::regclass);


--
-- Name: screening_result id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_result ALTER COLUMN id SET DEFAULT nextval('efrm.screening_result_id_seq'::regclass);


--
-- Name: screening_risk_band id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_risk_band ALTER COLUMN id SET DEFAULT nextval('efrm.screening_risk_band_id_seq'::regclass);


--
-- Name: screening_source_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_source_config ALTER COLUMN id SET DEFAULT nextval('efrm.screening_source_config_id_seq'::regclass);


--
-- Name: sla_escalation escalation_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.sla_escalation ALTER COLUMN escalation_id SET DEFAULT nextval('efrm.sla_escalation_escalation_id_seq'::regclass);


--
-- Name: sla_policy sla_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.sla_policy ALTER COLUMN sla_id SET DEFAULT nextval('efrm.sla_policy_sla_id_seq'::regclass);


--
-- Name: source_attribute_def id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_attribute_def ALTER COLUMN id SET DEFAULT nextval('efrm.source_attribute_def_id_seq'::regclass);


--
-- Name: source_column_mapping mapping_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_column_mapping ALTER COLUMN mapping_id SET DEFAULT nextval('efrm.source_column_mapping_mapping_id_seq'::regclass);


--
-- Name: source_config id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_config ALTER COLUMN id SET DEFAULT nextval('efrm.source_config_id_seq'::regclass);


--
-- Name: source_system_master source_system_id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_system_master ALTER COLUMN source_system_id SET DEFAULT nextval('efrm.source_system_master_source_system_id_seq'::regclass);


--
-- Name: transaction_alert id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_alert ALTER COLUMN id SET DEFAULT nextval('efrm.transaction_alert_seq'::regclass);


--
-- Name: transaction_master id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_master ALTER COLUMN id SET DEFAULT nextval('efrm.transaction_master_id_seq'::regclass);


--
-- Name: transaction_match id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_match ALTER COLUMN id SET DEFAULT nextval('efrm.transaction_match_seq'::regclass);


--
-- Name: transaction_request id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_request ALTER COLUMN id SET DEFAULT nextval('efrm.transaction_request_seq'::regclass);


--
-- Name: transaction_result id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_result ALTER COLUMN id SET DEFAULT nextval('efrm.transaction_result_seq'::regclass);


--
-- Name: whitelist_entry id; Type: DEFAULT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.whitelist_entry ALTER COLUMN id SET DEFAULT nextval('efrm.whitelist_entry_id_seq'::regclass);


--
-- Name: account_lockout account_lockout_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.account_lockout
    ADD CONSTRAINT account_lockout_pkey PRIMARY KEY (lockout_id);


--
-- Name: adverse_alert adverse_alert_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_alert
    ADD CONSTRAINT adverse_alert_pkey PRIMARY KEY (id);


--
-- Name: adverse_alert adverse_alert_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_alert
    ADD CONSTRAINT adverse_alert_unique UNIQUE (request_id, result_id);


--
-- Name: adverse_category_weight adverse_category_weight_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_category_weight
    ADD CONSTRAINT adverse_category_weight_pkey PRIMARY KEY (id);


--
-- Name: adverse_config_master adverse_config_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_config_master
    ADD CONSTRAINT adverse_config_master_pkey PRIMARY KEY (id);


--
-- Name: adverse_config_master adverse_config_master_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_config_master
    ADD CONSTRAINT adverse_config_master_unique UNIQUE (config_name, config_version);


--
-- Name: adverse_country_risk adverse_country_risk_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_country_risk
    ADD CONSTRAINT adverse_country_risk_pkey PRIMARY KEY (id);


--
-- Name: adverse_integration_config adverse_integration_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_integration_config
    ADD CONSTRAINT adverse_integration_config_pkey PRIMARY KEY (id);


--
-- Name: adverse_integration_config adverse_integration_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_integration_config
    ADD CONSTRAINT adverse_integration_config_unique UNIQUE (config_master_id, institution_id, provider_code);


--
-- Name: adverse_match adverse_match_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_match
    ADD CONSTRAINT adverse_match_pkey PRIMARY KEY (id);


--
-- Name: adverse_recency_factor adverse_recency_factor_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_recency_factor
    ADD CONSTRAINT adverse_recency_factor_pkey PRIMARY KEY (id);


--
-- Name: adverse_request adverse_request_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_request
    ADD CONSTRAINT adverse_request_pkey PRIMARY KEY (id);


--
-- Name: adverse_request adverse_request_request_id_key; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_request
    ADD CONSTRAINT adverse_request_request_id_key UNIQUE (request_id);


--
-- Name: adverse_result adverse_result_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_result
    ADD CONSTRAINT adverse_result_pkey PRIMARY KEY (id);


--
-- Name: adverse_risk_band adverse_risk_band_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_risk_band
    ADD CONSTRAINT adverse_risk_band_pkey PRIMARY KEY (id);


--
-- Name: adverse_severity_score adverse_severity_score_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_severity_score
    ADD CONSTRAINT adverse_severity_score_pkey PRIMARY KEY (id);


--
-- Name: adverse_source_weight adverse_source_weight_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_source_weight
    ADD CONSTRAINT adverse_source_weight_pkey PRIMARY KEY (id);


--
-- Name: aggregated_metric aggregated_metric_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.aggregated_metric
    ADD CONSTRAINT aggregated_metric_pkey PRIMARY KEY (id);


--
-- Name: aggregated_metric aggregated_metric_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.aggregated_metric
    ADD CONSTRAINT aggregated_metric_unique UNIQUE (institution_id, entity_type, entity_id, metric_code);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: alert_category_master alert_category_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.alert_category_master
    ADD CONSTRAINT alert_category_master_pkey PRIMARY KEY (id);


--
-- Name: alert_category_master alert_category_master_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.alert_category_master
    ADD CONSTRAINT alert_category_master_unique UNIQUE (category_code);


--
-- Name: alert_count_boost_config alert_count_boost_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.alert_count_boost_config
    ADD CONSTRAINT alert_count_boost_config_pkey PRIMARY KEY (id);


--
-- Name: alert_count_boost_config alert_count_boost_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.alert_count_boost_config
    ADD CONSTRAINT alert_count_boost_config_unique UNIQUE (min_alert_count, max_alert_count);


--
-- Name: audit_trail audit_trail_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.audit_trail
    ADD CONSTRAINT audit_trail_pkey PRIMARY KEY (id);


--
-- Name: bulk_file_upload bulk_file_upload_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.bulk_file_upload
    ADD CONSTRAINT bulk_file_upload_pkey PRIMARY KEY (id);


--
-- Name: bulk_file_upload bulk_file_upload_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.bulk_file_upload
    ADD CONSTRAINT bulk_file_upload_unique UNIQUE (file_id);


--
-- Name: bulk_job bulk_job_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.bulk_job
    ADD CONSTRAINT bulk_job_pkey PRIMARY KEY (id);


--
-- Name: bulk_job bulk_job_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.bulk_job
    ADD CONSTRAINT bulk_job_unique UNIQUE (job_id);


--
-- Name: capability_endpoint_map capability_endpoint_map_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.capability_endpoint_map
    ADD CONSTRAINT capability_endpoint_map_pkey PRIMARY KEY (mapping_id);


--
-- Name: case_action_execution_log case_action_execution_log_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_execution_log
    ADD CONSTRAINT case_action_execution_log_pkey PRIMARY KEY (log_id);


--
-- Name: case_action_execution_queue case_action_execution_queue_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_execution_queue
    ADD CONSTRAINT case_action_execution_queue_pkey PRIMARY KEY (execution_id);


--
-- Name: case_action_master case_action_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_master
    ADD CONSTRAINT case_action_master_pkey PRIMARY KEY (action_id);


--
-- Name: case_alert_mapping case_alert_mapping_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_alert_mapping
    ADD CONSTRAINT case_alert_mapping_pkey PRIMARY KEY (id);


--
-- Name: case_alert_mapping case_alert_mapping_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_alert_mapping
    ADD CONSTRAINT case_alert_mapping_unique UNIQUE (case_id, alert_id, alert_type, alert_source_table);


--
-- Name: assignment_config case_assignment_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.assignment_config
    ADD CONSTRAINT case_assignment_config_pkey PRIMARY KEY (config_id);


--
-- Name: case_assignment case_assignment_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_assignment
    ADD CONSTRAINT case_assignment_pkey PRIMARY KEY (assignment_id);


--
-- Name: case_config_master case_config_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_config_master
    ADD CONSTRAINT case_config_master_pkey PRIMARY KEY (id);


--
-- Name: case_config_master case_config_master_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_config_master
    ADD CONSTRAINT case_config_master_unique UNIQUE (institution_id, config_name, config_version);


--
-- Name: case_decision_action_mapping case_decision_action_mapping_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_decision_action_mapping
    ADD CONSTRAINT case_decision_action_mapping_pkey PRIMARY KEY (mapping_id);


--
-- Name: case_decision_master case_decision_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_decision_master
    ADD CONSTRAINT case_decision_master_pkey PRIMARY KEY (decision_id);


--
-- Name: case_events case_events_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_events
    ADD CONSTRAINT case_events_pkey PRIMARY KEY (event_id);


--
-- Name: case_evidence case_evidence_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_evidence
    ADD CONSTRAINT case_evidence_pkey PRIMARY KEY (evidence_id);


--
-- Name: case_priority_master case_priority_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_priority_master
    ADD CONSTRAINT case_priority_master_pkey PRIMARY KEY (id);


--
-- Name: case_priority_master case_priority_master_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_priority_master
    ADD CONSTRAINT case_priority_master_unique UNIQUE (priority_code);


--
-- Name: case_recovery case_recovery_case_id_key; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_recovery
    ADD CONSTRAINT case_recovery_case_id_key UNIQUE (case_id);


--
-- Name: case_recovery case_recovery_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_recovery
    ADD CONSTRAINT case_recovery_pkey PRIMARY KEY (recovery_id);


--
-- Name: case_score_breakdown case_score_breakdown_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_score_breakdown
    ADD CONSTRAINT case_score_breakdown_pkey PRIMARY KEY (id);


--
-- Name: case_score_breakdown case_score_breakdown_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_score_breakdown
    ADD CONSTRAINT case_score_breakdown_unique UNIQUE (case_id);


--
-- Name: case_scoring_trace case_scoring_trace_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_scoring_trace
    ADD CONSTRAINT case_scoring_trace_pkey PRIMARY KEY (id);


--
-- Name: case_scoring_trace case_scoring_trace_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_scoring_trace
    ADD CONSTRAINT case_scoring_trace_unique UNIQUE (case_id);


--
-- Name: case_sla_tracker case_sla_tracker_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_sla_tracker
    ADD CONSTRAINT case_sla_tracker_pkey PRIMARY KEY (tracker_id);


--
-- Name: case_master cases_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_master
    ADD CONSTRAINT cases_pkey PRIMARY KEY (case_id);


--
-- Name: category_correlation_config category_correlation_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.category_correlation_config
    ADD CONSTRAINT category_correlation_config_pkey PRIMARY KEY (id);


--
-- Name: category_correlation_config category_correlation_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.category_correlation_config
    ADD CONSTRAINT category_correlation_config_unique UNIQUE (category_count);


--
-- Name: chatbot_audit_log chatbot_audit_log_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.chatbot_audit_log
    ADD CONSTRAINT chatbot_audit_log_pkey PRIMARY KEY (id);


--
-- Name: common_password_list common_password_list_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.common_password_list
    ADD CONSTRAINT common_password_list_pkey PRIMARY KEY (entry_id);


--
-- Name: critical_override_rules critical_override_rules_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.critical_override_rules
    ADD CONSTRAINT critical_override_rules_pkey PRIMARY KEY (id);


--
-- Name: critical_override_rules critical_override_rules_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.critical_override_rules
    ADD CONSTRAINT critical_override_rules_unique UNIQUE (rule_code);


--
-- Name: dashboard_assignment dashboard_assignment_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.dashboard_assignment
    ADD CONSTRAINT dashboard_assignment_pkey PRIMARY KEY (id);


--
-- Name: dashboard_export_audit dashboard_export_audit_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.dashboard_export_audit
    ADD CONSTRAINT dashboard_export_audit_pkey PRIMARY KEY (export_id);


--
-- Name: dashboard_variant_master dashboard_variant_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.dashboard_variant_master
    ADD CONSTRAINT dashboard_variant_master_pkey PRIMARY KEY (id);


--
-- Name: device_alert device_alert_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_alert
    ADD CONSTRAINT device_alert_pkey PRIMARY KEY (id);


--
-- Name: device_alert device_alert_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_alert
    ADD CONSTRAINT device_alert_unique UNIQUE (device_result_id, alert_code);


--
-- Name: device_master device_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_master
    ADD CONSTRAINT device_master_pkey PRIMARY KEY (id);


--
-- Name: device_match device_match_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_match
    ADD CONSTRAINT device_match_pkey PRIMARY KEY (id);


--
-- Name: device_match device_match_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_match
    ADD CONSTRAINT device_match_unique UNIQUE (device_result_id, rule_group_version, rule_code, rule_version, signal_code);


--
-- Name: device_request device_request_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_request
    ADD CONSTRAINT device_request_pkey PRIMARY KEY (id);


--
-- Name: device_request device_request_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_request
    ADD CONSTRAINT device_request_unique UNIQUE (request_id);


--
-- Name: device_result device_result_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_result
    ADD CONSTRAINT device_result_pkey PRIMARY KEY (id);


--
-- Name: efrm_service_config efrm_service_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.efrm_service_config
    ADD CONSTRAINT efrm_service_config_pkey PRIMARY KEY (id);


--
-- Name: engine_attribute_def engine_attribute_def_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.engine_attribute_def
    ADD CONSTRAINT engine_attribute_def_pkey PRIMARY KEY (id);


--
-- Name: engine_attribute_def engine_attribute_def_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.engine_attribute_def
    ADD CONSTRAINT engine_attribute_def_unique UNIQUE (key, context_code);


--
-- Name: engine_flink_map engine_flink_map_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.engine_flink_map
    ADD CONSTRAINT engine_flink_map_pkey PRIMARY KEY (id);


--
-- Name: engine_flink_map engine_flink_map_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.engine_flink_map
    ADD CONSTRAINT engine_flink_map_unique UNIQUE (context_code, rule_engine_key, flink_event_key);


--
-- Name: entity_definition entity_definition_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_definition
    ADD CONSTRAINT entity_definition_pkey PRIMARY KEY (id);


--
-- Name: entity_definition entity_definition_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_definition
    ADD CONSTRAINT entity_definition_unique UNIQUE (entity_type, rule_engine_key);


--
-- Name: entity_device_map entity_device_map_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_device_map
    ADD CONSTRAINT entity_device_map_pkey PRIMARY KEY (entity_device_id);


--
-- Name: entity_graph_cluster_nodes entity_graph_cluster_nodes_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_cluster_nodes
    ADD CONSTRAINT entity_graph_cluster_nodes_pkey PRIMARY KEY (id);


--
-- Name: entity_graph_clusters entity_graph_clusters_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_clusters
    ADD CONSTRAINT entity_graph_clusters_pkey PRIMARY KEY (cluster_id);


--
-- Name: entity_graph_edges entity_graph_edges_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_edges
    ADD CONSTRAINT entity_graph_edges_pkey PRIMARY KEY (edge_id);


--
-- Name: entity_graph_evidence entity_graph_evidence_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_evidence
    ADD CONSTRAINT entity_graph_evidence_pkey PRIMARY KEY (id);


--
-- Name: entity_graph_nodes entity_graph_nodes_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_nodes
    ADD CONSTRAINT entity_graph_nodes_pkey PRIMARY KEY (node_id);


--
-- Name: entity_graph_refresh_checkpoint entity_graph_refresh_checkpoint_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_refresh_checkpoint
    ADD CONSTRAINT entity_graph_refresh_checkpoint_pkey PRIMARY KEY (id);


--
-- Name: entity_graph_refresh_config entity_graph_refresh_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_refresh_config
    ADD CONSTRAINT entity_graph_refresh_config_pkey PRIMARY KEY (id);


--
-- Name: entity_graph_view_config entity_graph_view_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_view_config
    ADD CONSTRAINT entity_graph_view_config_pkey PRIMARY KEY (id);


--
-- Name: entity_master entity_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_master
    ADD CONSTRAINT entity_master_pkey PRIMARY KEY (entity_id);


--
-- Name: entity_relation_map entity_relation_map_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_relation_map
    ADD CONSTRAINT entity_relation_map_pkey PRIMARY KEY (entity_relation_id);


--
-- Name: entity_risk_aggregate entity_risk_aggregate_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_aggregate
    ADD CONSTRAINT entity_risk_aggregate_pkey PRIMARY KEY (institution_id, entity_id);


--
-- Name: entity_risk_config entity_risk_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_config
    ADD CONSTRAINT entity_risk_config_pkey PRIMARY KEY (id);


--
-- Name: entity_risk_config entity_risk_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_config
    ADD CONSTRAINT entity_risk_config_unique UNIQUE (config_key);


--
-- Name: entity_risk_factor_breakdown entity_risk_factor_breakdown_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_factor_breakdown
    ADD CONSTRAINT entity_risk_factor_breakdown_pkey PRIMARY KEY (id);


--
-- Name: entity_risk_factor_breakdown entity_risk_factor_breakdown_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_factor_breakdown
    ADD CONSTRAINT entity_risk_factor_breakdown_unique UNIQUE (institution_id, entity_id, source_type, factor_name, category, reference_id);


--
-- Name: entity_risk_history entity_risk_history_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_history
    ADD CONSTRAINT entity_risk_history_pkey PRIMARY KEY (id);


--
-- Name: entity_risk_history entity_risk_history_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_history
    ADD CONSTRAINT entity_risk_history_unique UNIQUE (institution_id, entity_id, event_source, created_at);


--
-- Name: entity_risk_profile entity_risk_profile_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_profile
    ADD CONSTRAINT entity_risk_profile_pkey PRIMARY KEY (id);


--
-- Name: entity_risk_profile entity_risk_profile_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_risk_profile
    ADD CONSTRAINT entity_risk_profile_unique UNIQUE (institution_id, entity_id);


--
-- Name: enum_value enum_value_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.enum_value
    ADD CONSTRAINT enum_value_pkey PRIMARY KEY (id);


--
-- Name: enum_value enum_value_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.enum_value
    ADD CONSTRAINT enum_value_unique UNIQUE (enum_key, value);


--
-- Name: facts_definition facts_definition_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.facts_definition
    ADD CONSTRAINT facts_definition_pkey PRIMARY KEY (id);


--
-- Name: facts_definition facts_definition_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.facts_definition
    ADD CONSTRAINT facts_definition_unique UNIQUE (source_system_id, facts);


--
-- Name: graph_dimension_config graph_dimension_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.graph_dimension_config
    ADD CONSTRAINT graph_dimension_config_pkey PRIMARY KEY (id);


--
-- Name: graph_dimension_subtype_config graph_dimension_subtype_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.graph_dimension_subtype_config
    ADD CONSTRAINT graph_dimension_subtype_config_pkey PRIMARY KEY (id);


--
-- Name: institution institution_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.institution
    ADD CONSTRAINT institution_pkey PRIMARY KEY (institution_id);


--
-- Name: institution_type institution_type_institution_type_key; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.institution_type
    ADD CONSTRAINT institution_type_institution_type_key UNIQUE (institution_type);


--
-- Name: institution_type institution_type_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.institution_type
    ADD CONSTRAINT institution_type_pkey PRIMARY KEY (id);


--
-- Name: integration_endpoint_config integration_endpoint_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.integration_endpoint_config
    ADD CONSTRAINT integration_endpoint_config_pkey PRIMARY KEY (endpoint_config_id);


--
-- Name: list_entity_alias list_entity_alias_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_entity_alias
    ADD CONSTRAINT list_entity_alias_pkey PRIMARY KEY (id);


--
-- Name: list_entity list_entity_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_entity
    ADD CONSTRAINT list_entity_pkey PRIMARY KEY (id);


--
-- Name: list_normalized_address list_normalized_address_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_normalized_address
    ADD CONSTRAINT list_normalized_address_pkey PRIMARY KEY (id);


--
-- Name: list_source list_source_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_source
    ADD CONSTRAINT list_source_pkey PRIMARY KEY (id);


--
-- Name: list_source list_source_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_source
    ADD CONSTRAINT list_source_unique UNIQUE (code);


--
-- Name: list_version list_version_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_version
    ADD CONSTRAINT list_version_pkey PRIMARY KEY (id);


--
-- Name: login_attempt login_attempt_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.login_attempt
    ADD CONSTRAINT login_attempt_pkey PRIMARY KEY (attempt_id);


--
-- Name: menu_master menu_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.menu_master
    ADD CONSTRAINT menu_master_pkey PRIMARY KEY (menu_id);


--
-- Name: metric_definition metric_definition_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.metric_definition
    ADD CONSTRAINT metric_definition_pkey PRIMARY KEY (id);


--
-- Name: metric_definition metric_definition_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.metric_definition
    ADD CONSTRAINT metric_definition_unique UNIQUE (metric_code);


--
-- Name: ml_audit_event ml_audit_event_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_audit_event
    ADD CONSTRAINT ml_audit_event_pkey PRIMARY KEY (audit_event_id);


--
-- Name: ml_data_generation_record ml_data_generation_record_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_data_generation_record
    ADD CONSTRAINT ml_data_generation_record_pkey PRIMARY KEY (generation_record_id);


--
-- Name: ml_data_generation_run ml_data_generation_run_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_data_generation_run
    ADD CONSTRAINT ml_data_generation_run_pkey PRIMARY KEY (generation_run_id);


--
-- Name: ml_deployment_allocation ml_deployment_allocation_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_allocation
    ADD CONSTRAINT ml_deployment_allocation_pkey PRIMARY KEY (deployment_allocation_id);


--
-- Name: ml_deployment_event ml_deployment_event_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_event
    ADD CONSTRAINT ml_deployment_event_pkey PRIMARY KEY (deployment_event_id);


--
-- Name: ml_deployment_plan ml_deployment_plan_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_plan
    ADD CONSTRAINT ml_deployment_plan_pkey PRIMARY KEY (deployment_plan_id);


--
-- Name: ml_deployment_stage ml_deployment_stage_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_stage
    ADD CONSTRAINT ml_deployment_stage_pkey PRIMARY KEY (deployment_stage_id);


--
-- Name: ml_feature_definition_metadata ml_feature_definition_metadata_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_definition_metadata
    ADD CONSTRAINT ml_feature_definition_metadata_pkey PRIMARY KEY (feature_metadata_id);


--
-- Name: ml_feature_definition_metadata ml_feature_definition_metadata_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_definition_metadata
    ADD CONSTRAINT ml_feature_definition_metadata_unique UNIQUE (feature_id);


--
-- Name: ml_feature_definition ml_feature_definition_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_definition
    ADD CONSTRAINT ml_feature_definition_pkey PRIMARY KEY (feature_id);


--
-- Name: ml_feature_definition ml_feature_definition_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_definition
    ADD CONSTRAINT ml_feature_definition_unique UNIQUE (feature_set_version_id, feature_name);


--
-- Name: ml_feature_set ml_feature_set_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_set
    ADD CONSTRAINT ml_feature_set_pkey PRIMARY KEY (feature_set_id);


--
-- Name: ml_feature_set ml_feature_set_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_set
    ADD CONSTRAINT ml_feature_set_unique UNIQUE (feature_set_code);


--
-- Name: ml_feature_set_version ml_feature_set_version_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_set_version
    ADD CONSTRAINT ml_feature_set_version_pkey PRIMARY KEY (feature_set_version_id);


--
-- Name: ml_feature_set_version ml_feature_set_version_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_set_version
    ADD CONSTRAINT ml_feature_set_version_unique UNIQUE (feature_set_id, version);


--
-- Name: ml_feedback ml_feedback_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feedback
    ADD CONSTRAINT ml_feedback_pkey PRIMARY KEY (feedback_id);


--
-- Name: ml_feedback ml_feedback_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feedback
    ADD CONSTRAINT ml_feedback_unique UNIQUE (inference_id, feedback_type);


--
-- Name: ml_inference_result ml_inference_result_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_result
    ADD CONSTRAINT ml_inference_result_pkey PRIMARY KEY (inference_id);


--
-- Name: ml_inference_result ml_inference_result_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_result
    ADD CONSTRAINT ml_inference_result_unique UNIQUE (transaction_id, model_version_id);


--
-- Name: ml_inference_review ml_inference_review_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_review
    ADD CONSTRAINT ml_inference_review_pkey PRIMARY KEY (review_id);


--
-- Name: ml_inference_shap_local ml_inference_shap_local_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_shap_local
    ADD CONSTRAINT ml_inference_shap_local_pkey PRIMARY KEY (inference_shap_local_id);


--
-- Name: ml_inference_shap_local ml_inference_shap_local_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_shap_local
    ADD CONSTRAINT ml_inference_shap_local_unique UNIQUE (inference_id, feature_name);


--
-- Name: ml_job_dead_letter ml_job_dead_letter_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_job_dead_letter
    ADD CONSTRAINT ml_job_dead_letter_pkey PRIMARY KEY (dead_letter_id);


--
-- Name: ml_job_execution_state ml_job_execution_state_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_job_execution_state
    ADD CONSTRAINT ml_job_execution_state_pkey PRIMARY KEY (model_job_id);


--
-- Name: ml_model_drift_summary ml_model_drift_summary_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_drift_summary
    ADD CONSTRAINT ml_model_drift_summary_pkey PRIMARY KEY (model_drift_summary_id);


--
-- Name: ml_model_drift_summary ml_model_drift_summary_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_drift_summary
    ADD CONSTRAINT ml_model_drift_summary_unique UNIQUE (model_version_id);


--
-- Name: ml_model_explainability_profile ml_model_explainability_profile_model_version_id_key; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_explainability_profile
    ADD CONSTRAINT ml_model_explainability_profile_model_version_id_key UNIQUE (model_version_id);


--
-- Name: ml_model_explainability_profile ml_model_explainability_profile_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_explainability_profile
    ADD CONSTRAINT ml_model_explainability_profile_pkey PRIMARY KEY (explainability_profile_id);


--
-- Name: ml_model_feature_drift ml_model_feature_drift_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_feature_drift
    ADD CONSTRAINT ml_model_feature_drift_pkey PRIMARY KEY (model_feature_drift_id);


--
-- Name: ml_model_feature_drift ml_model_feature_drift_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_feature_drift
    ADD CONSTRAINT ml_model_feature_drift_unique UNIQUE (model_version_id, feature_name);


--
-- Name: ml_model_governance ml_model_governance_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_governance
    ADD CONSTRAINT ml_model_governance_pkey PRIMARY KEY (model_governance_id);


--
-- Name: ml_model_governance ml_model_governance_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_governance
    ADD CONSTRAINT ml_model_governance_unique UNIQUE (model_version_id);


--
-- Name: ml_model_job ml_model_job_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_job
    ADD CONSTRAINT ml_model_job_pkey PRIMARY KEY (model_job_id);


--
-- Name: ml_model_performance_daily ml_model_performance_daily_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_performance_daily
    ADD CONSTRAINT ml_model_performance_daily_pkey PRIMARY KEY (model_performance_daily_id);


--
-- Name: ml_model_performance_daily ml_model_performance_daily_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_performance_daily
    ADD CONSTRAINT ml_model_performance_daily_unique UNIQUE (model_version_id, metric_date);


--
-- Name: ml_model_registry ml_model_registry_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_registry
    ADD CONSTRAINT ml_model_registry_pkey PRIMARY KEY (model_id);


--
-- Name: ml_model_registry ml_model_registry_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_registry
    ADD CONSTRAINT ml_model_registry_unique UNIQUE (institution_id, source_system, channel, model_purpose);


--
-- Name: ml_model_runtime_metrics ml_model_runtime_metrics_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_runtime_metrics
    ADD CONSTRAINT ml_model_runtime_metrics_pkey PRIMARY KEY (model_runtime_metrics_id);


--
-- Name: ml_model_runtime_metrics ml_model_runtime_metrics_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_runtime_metrics
    ADD CONSTRAINT ml_model_runtime_metrics_unique UNIQUE (model_version_id, window_start);


--
-- Name: ml_model_shap_global ml_model_shap_global_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_shap_global
    ADD CONSTRAINT ml_model_shap_global_pkey PRIMARY KEY (model_shap_global_id);


--
-- Name: ml_model_shap_global ml_model_shap_global_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_shap_global
    ADD CONSTRAINT ml_model_shap_global_unique UNIQUE (model_version_id, feature_name);


--
-- Name: ml_model_simulation_sample ml_model_simulation_sample_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_simulation_sample
    ADD CONSTRAINT ml_model_simulation_sample_pkey PRIMARY KEY (simulation_sample_id);


--
-- Name: ml_model_version ml_model_version_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_version
    ADD CONSTRAINT ml_model_version_pkey PRIMARY KEY (model_version_id);


--
-- Name: ml_model_version ml_model_version_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_version
    ADD CONSTRAINT ml_model_version_unique UNIQUE (model_id, version);


--
-- Name: ml_monitoring_alert ml_monitoring_alert_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_monitoring_alert
    ADD CONSTRAINT ml_monitoring_alert_pkey PRIMARY KEY (alert_id);


--
-- Name: ml_schema_migration ml_schema_migration_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_schema_migration
    ADD CONSTRAINT ml_schema_migration_pkey PRIMARY KEY (migration_name);


--
-- Name: ml_score_blending_policy ml_score_blending_policy_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_score_blending_policy
    ADD CONSTRAINT ml_score_blending_policy_pkey PRIMARY KEY (policy_id);


--
-- Name: ml_shadow_execution ml_shadow_execution_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_shadow_execution
    ADD CONSTRAINT ml_shadow_execution_pkey PRIMARY KEY (shadow_execution_id);


--
-- Name: ml_simulation_result ml_simulation_result_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_simulation_result
    ADD CONSTRAINT ml_simulation_result_pkey PRIMARY KEY (simulation_result_id);


--
-- Name: ml_simulation_run ml_simulation_run_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_simulation_run
    ADD CONSTRAINT ml_simulation_run_pkey PRIMARY KEY (simulation_run_id);


--
-- Name: ml_training_dataset ml_training_dataset_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_training_dataset
    ADD CONSTRAINT ml_training_dataset_pkey PRIMARY KEY (dataset_id);


--
-- Name: ml_training_dataset_profile ml_training_dataset_profile_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_training_dataset_profile
    ADD CONSTRAINT ml_training_dataset_profile_pkey PRIMARY KEY (model_training_dataset_profile_id);


--
-- Name: ml_training_dataset_profile ml_training_dataset_profile_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_training_dataset_profile
    ADD CONSTRAINT ml_training_dataset_profile_unique UNIQUE (model_version_id, file_id);


--
-- Name: ml_worker_heartbeat ml_worker_heartbeat_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_worker_heartbeat
    ADD CONSTRAINT ml_worker_heartbeat_pkey PRIMARY KEY (worker_id);


--
-- Name: notification_queue notification_queue_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.notification_queue
    ADD CONSTRAINT notification_queue_pkey PRIMARY KEY (notification_id);


--
-- Name: notification_template notification_template_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.notification_template
    ADD CONSTRAINT notification_template_pkey PRIMARY KEY (template_id);


--
-- Name: operator_value operator_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.operator_value
    ADD CONSTRAINT operator_pkey PRIMARY KEY (id);


--
-- Name: operator_value operator_value_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.operator_value
    ADD CONSTRAINT operator_value_unique UNIQUE (key);


--
-- Name: password_expiry_notice password_expiry_notice_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.password_expiry_notice
    ADD CONSTRAINT password_expiry_notice_pkey PRIMARY KEY (notice_id);


--
-- Name: password_policy_rule password_policy_rule_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.password_policy_rule
    ADD CONSTRAINT password_policy_rule_pkey PRIMARY KEY (rule_id);


--
-- Name: password_reset_token password_reset_token_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.password_reset_token
    ADD CONSTRAINT password_reset_token_pkey PRIMARY KEY (token_id);


--
-- Name: product_master product_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.product_master
    ADD CONSTRAINT product_master_pkey PRIMARY KEY (product_id);


--
-- Name: profile_capability profile_capability_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.profile_capability
    ADD CONSTRAINT profile_capability_pkey PRIMARY KEY (profile_id, capability_code);


--
-- Name: profile_master profile_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.profile_master
    ADD CONSTRAINT profile_master_pkey PRIMARY KEY (profile_id);


--
-- Name: reference_data reference_data_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.reference_data
    ADD CONSTRAINT reference_data_pkey PRIMARY KEY (ref_id);


--
-- Name: reference_data reference_data_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.reference_data
    ADD CONSTRAINT reference_data_unique UNIQUE (ref_type, ref_code, ref_value);


--
-- Name: refresh_token refresh_token_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.refresh_token
    ADD CONSTRAINT refresh_token_pkey PRIMARY KEY (token_id);


--
-- Name: report_assignment report_assignment_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.report_assignment
    ADD CONSTRAINT report_assignment_pkey PRIMARY KEY (id);


--
-- Name: report_export_audit report_export_audit_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.report_export_audit
    ADD CONSTRAINT report_export_audit_pkey PRIMARY KEY (export_id);


--
-- Name: report_variant_master report_variant_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.report_variant_master
    ADD CONSTRAINT report_variant_master_pkey PRIMARY KEY (id);


--
-- Name: risk_event_log risk_event_log_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_event_log
    ADD CONSTRAINT risk_event_log_pkey PRIMARY KEY (id);


--
-- Name: risk_event_log risk_event_log_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_event_log
    ADD CONSTRAINT risk_event_log_unique UNIQUE (institution_id, entity_id, event_source, reference_id);


--
-- Name: risk_rating_config risk_rating_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_config
    ADD CONSTRAINT risk_rating_config_pkey PRIMARY KEY (id);


--
-- Name: risk_rating_config risk_rating_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_config
    ADD CONSTRAINT risk_rating_config_unique UNIQUE (institution_id, config_version);


--
-- Name: risk_rating_decay_policy_config risk_rating_decay_policy_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_decay_policy_config
    ADD CONSTRAINT risk_rating_decay_policy_config_pkey PRIMARY KEY (id);


--
-- Name: risk_rating_decision_impact_config risk_rating_decision_impact_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_decision_impact_config
    ADD CONSTRAINT risk_rating_decision_impact_config_pkey PRIMARY KEY (id);


--
-- Name: risk_rating_domain_override_config risk_rating_domain_override_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_domain_override_config
    ADD CONSTRAINT risk_rating_domain_override_config_pkey PRIMARY KEY (id);


--
-- Name: risk_rating_event_type_config risk_rating_event_type_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_event_type_config
    ADD CONSTRAINT risk_rating_event_type_config_pkey PRIMARY KEY (id);


--
-- Name: risk_rating_override_policy risk_rating_override_policy_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_override_policy
    ADD CONSTRAINT risk_rating_override_policy_pkey PRIMARY KEY (id);


--
-- Name: risk_rating_relationship_risk_config risk_rating_relationship_risk_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_relationship_risk_config
    ADD CONSTRAINT risk_rating_relationship_risk_config_pkey PRIMARY KEY (id);


--
-- Name: risk_rating_service_weight_config risk_rating_service_weight_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_service_weight_config
    ADD CONSTRAINT risk_rating_service_weight_config_pkey PRIMARY KEY (id);


--
-- Name: risk_rating_tier_config risk_rating_tier_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_tier_config
    ADD CONSTRAINT risk_rating_tier_config_pkey PRIMARY KEY (id);


--
-- Name: risk_rating_weight_config risk_rating_weight_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_weight_config
    ADD CONSTRAINT risk_rating_weight_config_pkey PRIMARY KEY (id);


--
-- Name: risk_recalculation_job risk_recalculation_job_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_recalculation_job
    ADD CONSTRAINT risk_recalculation_job_pkey PRIMARY KEY (id);


--
-- Name: rule_decision_policy rule_decision_policy_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_decision_policy
    ADD CONSTRAINT rule_decision_policy_pkey PRIMARY KEY (id);


--
-- Name: rule_decision_policy rule_decision_policy_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_decision_policy
    ADD CONSTRAINT rule_decision_policy_unique UNIQUE (policy_code, signal_severity, min_score, max_score, min_rule_count);


--
-- Name: rule_decision_upgrade rule_decision_upgrade_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_decision_upgrade
    ADD CONSTRAINT rule_decision_upgrade_pkey PRIMARY KEY (id);


--
-- Name: rule_decision_upgrade rule_decision_upgrade_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_decision_upgrade
    ADD CONSTRAINT rule_decision_upgrade_unique UNIQUE (policy_code, source_severity, min_rule_count);


--
-- Name: rule_drl_context rule_drl_context_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_drl_context
    ADD CONSTRAINT rule_drl_context_pkey PRIMARY KEY (id);


--
-- Name: rule_drl_context rule_drl_context_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_drl_context
    ADD CONSTRAINT rule_drl_context_unique UNIQUE (context_code);


--
-- Name: rule_group_master rule_group_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_master
    ADD CONSTRAINT rule_group_master_pkey PRIMARY KEY (id);


--
-- Name: rule_group_master rule_group_master_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_master
    ADD CONSTRAINT rule_group_master_unique UNIQUE (group_code);


--
-- Name: rule_group_source_binding rule_group_source_binding_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_source_binding
    ADD CONSTRAINT rule_group_source_binding_pkey PRIMARY KEY (id);


--
-- Name: rule_group_source_binding rule_group_source_binding_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_source_binding
    ADD CONSTRAINT rule_group_source_binding_unique UNIQUE (institution_id, source_system, channel, rule_group_version_id);


--
-- Name: rule_group_version_map rule_group_version_map_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_version_map
    ADD CONSTRAINT rule_group_version_map_pkey PRIMARY KEY (id);


--
-- Name: rule_group_version_map rule_group_version_map_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_version_map
    ADD CONSTRAINT rule_group_version_map_unique UNIQUE (rule_group_version_id, rule_version_id);


--
-- Name: rule_group_version rule_group_version_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_version
    ADD CONSTRAINT rule_group_version_pkey PRIMARY KEY (id);


--
-- Name: rule_group_version rule_group_version_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_version
    ADD CONSTRAINT rule_group_version_unique UNIQUE (rule_group_master_id, version_no);


--
-- Name: rule_master rule_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_master
    ADD CONSTRAINT rule_master_pkey PRIMARY KEY (id);


--
-- Name: rule_master_tag rule_master_tag_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_master_tag
    ADD CONSTRAINT rule_master_tag_pkey PRIMARY KEY (id);


--
-- Name: rule_master_tag rule_master_tag_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_master_tag
    ADD CONSTRAINT rule_master_tag_unique UNIQUE (rule_id, tag_code);


--
-- Name: rule_master rule_master_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_master
    ADD CONSTRAINT rule_master_unique UNIQUE (rule_code);


--
-- Name: rule_metric_dependency rule_metric_dependency_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_metric_dependency
    ADD CONSTRAINT rule_metric_dependency_pkey PRIMARY KEY (id);


--
-- Name: rule_metric_dependency rule_metric_dependency_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_metric_dependency
    ADD CONSTRAINT rule_metric_dependency_unique UNIQUE (rule_id, metric_code);


--
-- Name: rule_required_data rule_required_data_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_required_data
    ADD CONSTRAINT rule_required_data_pkey PRIMARY KEY (id);


--
-- Name: rule_version rule_version_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_version
    ADD CONSTRAINT rule_version_pkey PRIMARY KEY (id);


--
-- Name: rule_version rule_version_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_version
    ADD CONSTRAINT rule_version_unique UNIQUE (rule_master_id, version_no);


--
-- Name: transaction_alert ruleengine_alert_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_alert
    ADD CONSTRAINT ruleengine_alert_pkey PRIMARY KEY (id);


--
-- Name: transaction_alert ruleengine_alert_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_alert
    ADD CONSTRAINT ruleengine_alert_unique UNIQUE (transaction_result_id, alert_code);


--
-- Name: ruleengine_bulk_job_item ruleengine_bulk_job_item_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job_item
    ADD CONSTRAINT ruleengine_bulk_job_item_pkey PRIMARY KEY (id);


--
-- Name: ruleengine_bulk_job ruleengine_bulk_job_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job
    ADD CONSTRAINT ruleengine_bulk_job_pkey PRIMARY KEY (id);


--
-- Name: ruleengine_bulk_job_summary ruleengine_bulk_job_summary_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job_summary
    ADD CONSTRAINT ruleengine_bulk_job_summary_pkey PRIMARY KEY (id);


--
-- Name: ruleengine_bulk_job_summary ruleengine_bulk_job_summary_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job_summary
    ADD CONSTRAINT ruleengine_bulk_job_summary_unique UNIQUE (bulk_job_id);


--
-- Name: ruleengine_bulk_job ruleengine_bulk_job_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job
    ADD CONSTRAINT ruleengine_bulk_job_unique UNIQUE (job_id);


--
-- Name: transaction_match ruleengine_match_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_match
    ADD CONSTRAINT ruleengine_match_pkey PRIMARY KEY (id);


--
-- Name: transaction_match ruleengine_match_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_match
    ADD CONSTRAINT ruleengine_match_unique UNIQUE (transaction_result_id, rule_group_version, rule_code, rule_version, signal_code);


--
-- Name: transaction_request ruleengine_request_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_request
    ADD CONSTRAINT ruleengine_request_pkey PRIMARY KEY (id);


--
-- Name: transaction_request ruleengine_request_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_request
    ADD CONSTRAINT ruleengine_request_unique UNIQUE (request_id);


--
-- Name: transaction_result ruleengine_result_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_result
    ADD CONSTRAINT ruleengine_result_pkey PRIMARY KEY (id);


--
-- Name: screening_alert screening_alert_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_alert
    ADD CONSTRAINT screening_alert_pkey PRIMARY KEY (id);


--
-- Name: screening_alert screening_alert_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_alert
    ADD CONSTRAINT screening_alert_unique UNIQUE (alert_id);


--
-- Name: screening_bulk_job_item screening_bulk_job_item_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job_item
    ADD CONSTRAINT screening_bulk_job_item_pkey PRIMARY KEY (id);


--
-- Name: screening_bulk_job screening_bulk_job_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job
    ADD CONSTRAINT screening_bulk_job_pkey PRIMARY KEY (id);


--
-- Name: screening_bulk_job_summary screening_bulk_job_summary_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job_summary
    ADD CONSTRAINT screening_bulk_job_summary_pkey PRIMARY KEY (id);


--
-- Name: screening_bulk_job_summary screening_bulk_job_summary_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job_summary
    ADD CONSTRAINT screening_bulk_job_summary_unique UNIQUE (bulk_job_id);


--
-- Name: screening_bulk_job screening_bulk_job_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job
    ADD CONSTRAINT screening_bulk_job_unique UNIQUE (job_id);


--
-- Name: screening_config_master screening_config_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_config_master
    ADD CONSTRAINT screening_config_master_pkey PRIMARY KEY (id);


--
-- Name: screening_config_master screening_config_master_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_config_master
    ADD CONSTRAINT screening_config_master_unique UNIQUE (institution_id, config_name, config_version);


--
-- Name: screening_decision_threshold screening_decision_threshold_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_decision_threshold
    ADD CONSTRAINT screening_decision_threshold_pkey PRIMARY KEY (id);


--
-- Name: screening_decision_threshold screening_decision_threshold_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_decision_threshold
    ADD CONSTRAINT screening_decision_threshold_unique UNIQUE (config_master_id, decision_code);


--
-- Name: screening_entity screening_entity_entity_type_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_entity
    ADD CONSTRAINT screening_entity_entity_type_unique UNIQUE (entity_type);


--
-- Name: screening_entity_field screening_entity_field_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_entity_field
    ADD CONSTRAINT screening_entity_field_pkey PRIMARY KEY (field_id);


--
-- Name: screening_entity_field screening_entity_field_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_entity_field
    ADD CONSTRAINT screening_entity_field_unique UNIQUE (entity_type, entity_relation, field_name);


--
-- Name: screening_entity screening_entity_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_entity
    ADD CONSTRAINT screening_entity_pkey PRIMARY KEY (id);


--
-- Name: screening_entity_relation screening_entity_relation_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_entity_relation
    ADD CONSTRAINT screening_entity_relation_pkey PRIMARY KEY (relation_id);


--
-- Name: screening_field_config screening_field_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_field_config
    ADD CONSTRAINT screening_field_config_pkey PRIMARY KEY (id);


--
-- Name: screening_field_config screening_field_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_field_config
    ADD CONSTRAINT screening_field_config_unique UNIQUE (config_master_id, field_name);


--
-- Name: screening_group_config screening_group_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_group_config
    ADD CONSTRAINT screening_group_config_pkey PRIMARY KEY (id);


--
-- Name: screening_group_config screening_group_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_group_config
    ADD CONSTRAINT screening_group_config_unique UNIQUE (config_master_id, group_name);


--
-- Name: screening_identifier_config screening_identifier_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_identifier_config
    ADD CONSTRAINT screening_identifier_config_pkey PRIMARY KEY (id);


--
-- Name: screening_identifier_config screening_identifier_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_identifier_config
    ADD CONSTRAINT screening_identifier_config_unique UNIQUE (config_master_id, id_type);


--
-- Name: screening_match screening_match_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_match
    ADD CONSTRAINT screening_match_pkey PRIMARY KEY (id);


--
-- Name: screening_request screening_request_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_request
    ADD CONSTRAINT screening_request_pkey PRIMARY KEY (id);


--
-- Name: screening_request screening_request_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_request
    ADD CONSTRAINT screening_request_unique UNIQUE (request_id);


--
-- Name: screening_result screening_result_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_result
    ADD CONSTRAINT screening_result_pkey PRIMARY KEY (id);


--
-- Name: screening_risk_band screening_risk_band_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_risk_band
    ADD CONSTRAINT screening_risk_band_pkey PRIMARY KEY (id);


--
-- Name: screening_risk_band screening_risk_band_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_risk_band
    ADD CONSTRAINT screening_risk_band_unique UNIQUE (config_master_id, band_code);


--
-- Name: screening_source_config screening_source_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_source_config
    ADD CONSTRAINT screening_source_config_pkey PRIMARY KEY (id);


--
-- Name: screening_source_config screening_source_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_source_config
    ADD CONSTRAINT screening_source_config_unique UNIQUE (config_master_id, list_source_code);


--
-- Name: security_audit_log security_audit_log_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.security_audit_log
    ADD CONSTRAINT security_audit_log_pkey PRIMARY KEY (audit_id);


--
-- Name: security_capability security_capability_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.security_capability
    ADD CONSTRAINT security_capability_pkey PRIMARY KEY (capability_code);


--
-- Name: security_check security_check_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.security_check
    ADD CONSTRAINT security_check_pkey PRIMARY KEY (security_check_id);


--
-- Name: security_notification security_notification_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.security_notification
    ADD CONSTRAINT security_notification_pkey PRIMARY KEY (notification_id);


--
-- Name: service_client service_client_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.service_client
    ADD CONSTRAINT service_client_pkey PRIMARY KEY (client_id);


--
-- Name: service_token_jti service_token_jti_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.service_token_jti
    ADD CONSTRAINT service_token_jti_pkey PRIMARY KEY (jti);


--
-- Name: sla_escalation sla_escalation_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.sla_escalation
    ADD CONSTRAINT sla_escalation_pkey PRIMARY KEY (escalation_id);


--
-- Name: sla_policy sla_policy_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.sla_policy
    ADD CONSTRAINT sla_policy_pkey PRIMARY KEY (sla_id);


--
-- Name: source_attribute_def source_attribute_def_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_attribute_def
    ADD CONSTRAINT source_attribute_def_pkey PRIMARY KEY (id);


--
-- Name: source_attribute_def source_attribute_def_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_attribute_def
    ADD CONSTRAINT source_attribute_def_unique UNIQUE (facts, key);


--
-- Name: source_column_mapping source_column_mapping_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_column_mapping
    ADD CONSTRAINT source_column_mapping_pkey PRIMARY KEY (mapping_id);


--
-- Name: source_column_mapping source_column_mapping_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_column_mapping
    ADD CONSTRAINT source_column_mapping_unique UNIQUE (source_code, file_column_name, target_field, entity_type);


--
-- Name: source_config source_config_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_config
    ADD CONSTRAINT source_config_pkey PRIMARY KEY (id);


--
-- Name: source_config source_config_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_config
    ADD CONSTRAINT source_config_unique UNIQUE (code);


--
-- Name: source_system_master source_system_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_system_master
    ADD CONSTRAINT source_system_master_pkey PRIMARY KEY (source_system_id);


--
-- Name: transaction_master transaction_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_master
    ADD CONSTRAINT transaction_master_pkey PRIMARY KEY (id);


--
-- Name: transaction_master transaction_master_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_master
    ADD CONSTRAINT transaction_master_unique UNIQUE (transaction_id);


--
-- Name: capability_endpoint_map uk_cemap_route; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.capability_endpoint_map
    ADD CONSTRAINT uk_cemap_route UNIQUE (service_code, http_method, path_pattern);


--
-- Name: common_password_list uk_cpwd_hash; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.common_password_list
    ADD CONSTRAINT uk_cpwd_hash UNIQUE (password_hash);


--
-- Name: efrm_service_config uk_efrm_service_config; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.efrm_service_config
    ADD CONSTRAINT uk_efrm_service_config UNIQUE (institution_id, service_name);


--
-- Name: entity_graph_cluster_nodes uk_entity_graph_cluster_nodes; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_cluster_nodes
    ADD CONSTRAINT uk_entity_graph_cluster_nodes UNIQUE (cluster_id, node_id);


--
-- Name: entity_graph_clusters uk_entity_graph_clusters; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_clusters
    ADD CONSTRAINT uk_entity_graph_clusters UNIQUE (institution_id, cluster_key);


--
-- Name: entity_graph_refresh_checkpoint uk_entity_graph_refresh_checkpoint; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_refresh_checkpoint
    ADD CONSTRAINT uk_entity_graph_refresh_checkpoint UNIQUE (institution_id, source_table, dimension_code);


--
-- Name: entity_graph_refresh_config uk_entity_graph_refresh_config; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_refresh_config
    ADD CONSTRAINT uk_entity_graph_refresh_config UNIQUE (institution_id, refresh_type, source_table, dimension_code);


--
-- Name: entity_graph_view_config uk_entity_graph_view_config; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_view_config
    ADD CONSTRAINT uk_entity_graph_view_config UNIQUE (institution_id, view_type);


--
-- Name: graph_dimension_subtype_config uk_graph_dimension_subtype_config; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.graph_dimension_subtype_config
    ADD CONSTRAINT uk_graph_dimension_subtype_config UNIQUE (institution_id, entity_type, source_table, subtype_column, subtype_value);


--
-- Name: password_reset_token uk_prst_hash; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.password_reset_token
    ADD CONSTRAINT uk_prst_hash UNIQUE (token_hash);


--
-- Name: refresh_token uk_rft_hash; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.refresh_token
    ADD CONSTRAINT uk_rft_hash UNIQUE (token_hash);


--
-- Name: risk_rating_decay_policy_config uk_risk_rating_decay_policy; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_decay_policy_config
    ADD CONSTRAINT uk_risk_rating_decay_policy UNIQUE (config_master_id, risk_domain);


--
-- Name: risk_rating_decision_impact_config uk_risk_rating_decision_impact; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_decision_impact_config
    ADD CONSTRAINT uk_risk_rating_decision_impact UNIQUE (config_master_id, source_type, decision_code);


--
-- Name: risk_rating_domain_override_config uk_risk_rating_domain_override; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_domain_override_config
    ADD CONSTRAINT uk_risk_rating_domain_override UNIQUE (config_master_id, risk_domain, threshold_score);


--
-- Name: risk_rating_event_type_config uk_risk_rating_event_type; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_event_type_config
    ADD CONSTRAINT uk_risk_rating_event_type UNIQUE (config_master_id, event_type);


--
-- Name: risk_rating_override_policy uk_risk_rating_override_policy; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_override_policy
    ADD CONSTRAINT uk_risk_rating_override_policy UNIQUE (config_master_id, policy_code);


--
-- Name: risk_rating_relationship_risk_config uk_risk_rating_relationship_risk; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_relationship_risk_config
    ADD CONSTRAINT uk_risk_rating_relationship_risk UNIQUE (config_master_id, relationship_type);


--
-- Name: risk_rating_tier_config uk_risk_rating_risk_tier; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_tier_config
    ADD CONSTRAINT uk_risk_rating_risk_tier UNIQUE (config_master_id, tier_name);


--
-- Name: risk_rating_service_weight_config uk_risk_rating_service_weight; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_service_weight_config
    ADD CONSTRAINT uk_risk_rating_service_weight UNIQUE (config_master_id, service_name);


--
-- Name: risk_rating_weight_config uk_risk_rating_weight; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_weight_config
    ADD CONSTRAINT uk_risk_rating_weight UNIQUE (config_master_id, risk_domain);


--
-- Name: user_session uk_usess_jti; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_session
    ADD CONSTRAINT uk_usess_jti UNIQUE (current_access_jti);


--
-- Name: user_session uk_usess_token; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_session
    ADD CONSTRAINT uk_usess_token UNIQUE (token_hash);


--
-- Name: adverse_result uq_adv_result_id_request; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_result
    ADD CONSTRAINT uq_adv_result_id_request UNIQUE (id, request_id);


--
-- Name: adverse_match uq_adverse_match_result_article_hash; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_match
    ADD CONSTRAINT uq_adverse_match_result_article_hash UNIQUE (result_id, article_hash);


--
-- Name: case_action_master uq_case_action_code; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_master
    ADD CONSTRAINT uq_case_action_code UNIQUE (config_master_id, action_code);


--
-- Name: case_action_execution_queue uq_case_action_idempotency_key; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_execution_queue
    ADD CONSTRAINT uq_case_action_idempotency_key UNIQUE (idempotency_key);


--
-- Name: case_decision_action_mapping uq_case_decision_action_mapping; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_decision_action_mapping
    ADD CONSTRAINT uq_case_decision_action_mapping UNIQUE (config_master_id, decision_code, action_code, sequence_no);


--
-- Name: case_decision_master uq_case_decision_scope; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_decision_master
    ADD CONSTRAINT uq_case_decision_scope UNIQUE (config_master_id, decision_code, alert_type, service_code, entity_type);


--
-- Name: dashboard_assignment uq_dash_assign_version; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.dashboard_assignment
    ADD CONSTRAINT uq_dash_assign_version UNIQUE (resource_code, scope_key, assignment_version);


--
-- Name: dashboard_variant_master uq_dash_variant_res_code; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.dashboard_variant_master
    ADD CONSTRAINT uq_dash_variant_res_code UNIQUE (resource_code, variant_code);


--
-- Name: entity_device_map uq_entity_device; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_device_map
    ADD CONSTRAINT uq_entity_device UNIQUE (entity_id, device_id);


--
-- Name: entity_master uq_entity_institution_external; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_master
    ADD CONSTRAINT uq_entity_institution_external UNIQUE (institution_id, external_entity_id);


--
-- Name: entity_relation_map uq_entity_relation; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_relation_map
    ADD CONSTRAINT uq_entity_relation UNIQUE (institution_id, entity_id, relation_type, external_relation_id);


--
-- Name: integration_endpoint_config uq_integration_endpoint_action_target; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.integration_endpoint_config
    ADD CONSTRAINT uq_integration_endpoint_action_target UNIQUE (institution_id, action_code, target_system);


--
-- Name: ml_data_generation_record uq_ml_data_generation_record_entity; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_data_generation_record
    ADD CONSTRAINT uq_ml_data_generation_record_entity UNIQUE (generation_run_id, entity_type, entity_id);


--
-- Name: ml_data_generation_run uq_ml_data_generation_run_code; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_data_generation_run
    ADD CONSTRAINT uq_ml_data_generation_run_code UNIQUE (institution_id, run_code);


--
-- Name: ml_deployment_allocation uq_ml_deployment_allocation_routing_key; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_allocation
    ADD CONSTRAINT uq_ml_deployment_allocation_routing_key UNIQUE (deployment_plan_id, routing_key_value);


--
-- Name: ml_deployment_stage uq_ml_deployment_stage_order; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_stage
    ADD CONSTRAINT uq_ml_deployment_stage_order UNIQUE (deployment_plan_id, stage_order);


--
-- Name: ml_feature_definition uq_ml_feature_definition_order; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_definition
    ADD CONSTRAINT uq_ml_feature_definition_order UNIQUE (feature_set_version_id, feature_order);


--
-- Name: ml_model_simulation_sample uq_ml_model_simulation_sample_code; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_simulation_sample
    ADD CONSTRAINT uq_ml_model_simulation_sample_code UNIQUE (model_version_id, sample_code);


--
-- Name: ml_simulation_result uq_ml_simulation_result_row; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_simulation_result
    ADD CONSTRAINT uq_ml_simulation_result_row UNIQUE (simulation_run_id, row_number);


--
-- Name: ml_simulation_result uq_ml_simulation_result_simulation_id; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_simulation_result
    ADD CONSTRAINT uq_ml_simulation_result_simulation_id UNIQUE (simulation_id);


--
-- Name: ml_simulation_run uq_ml_simulation_run_code; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_simulation_run
    ADD CONSTRAINT uq_ml_simulation_run_code UNIQUE (institution_id, run_code);


--
-- Name: ml_training_dataset uq_ml_training_dataset_code; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_training_dataset
    ADD CONSTRAINT uq_ml_training_dataset_code UNIQUE (institution_id, dataset_code);


--
-- Name: report_assignment uq_rep_assign_version; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.report_assignment
    ADD CONSTRAINT uq_rep_assign_version UNIQUE (report_code, scope_key, assignment_version);


--
-- Name: report_variant_master uq_rep_variant_code; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.report_variant_master
    ADD CONSTRAINT uq_rep_variant_code UNIQUE (report_code, variant_code);


--
-- Name: screening_result uq_scr_result_id_request; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_result
    ADD CONSTRAINT uq_scr_result_id_request UNIQUE (id, request_id);


--
-- Name: screening_entity_relation uq_screening_entity_relation; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_entity_relation
    ADD CONSTRAINT uq_screening_entity_relation UNIQUE (entity_type, entity_relation);


--
-- Name: source_system_master uq_source_system_institution_code; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_system_master
    ADD CONSTRAINT uq_source_system_institution_code UNIQUE (institution_id, source_system_code);


--
-- Name: user_credential user_credential_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_credential
    ADD CONSTRAINT user_credential_pkey PRIMARY KEY (credential_id);


--
-- Name: user_master user_master_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_master
    ADD CONSTRAINT user_master_pkey PRIMARY KEY (user_name);


--
-- Name: user_password_history user_password_history_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_password_history
    ADD CONSTRAINT user_password_history_pkey PRIMARY KEY (id);


--
-- Name: user_session user_session_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_session
    ADD CONSTRAINT user_session_pkey PRIMARY KEY (session_id);


--
-- Name: whitelist_entry whitelist_entry_pkey; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.whitelist_entry
    ADD CONSTRAINT whitelist_entry_pkey PRIMARY KEY (id);


--
-- Name: whitelist_entry whitelist_entry_unique; Type: CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.whitelist_entry
    ADD CONSTRAINT whitelist_entry_unique UNIQUE (entity_id, entity_type, list_source_code);


--
-- Name: audit_trail_action_type_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX audit_trail_action_type_idx ON efrm.audit_trail USING btree (action_type);


--
-- Name: audit_trail_created_at_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX audit_trail_created_at_idx ON efrm.audit_trail USING btree (created_at);


--
-- Name: audit_trail_table_name_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX audit_trail_table_name_idx ON efrm.audit_trail USING btree (table_name);


--
-- Name: audit_trail_user_name_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX audit_trail_user_name_idx ON efrm.audit_trail USING btree (user_name);


--
-- Name: case_sla_tracker_case_id_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX case_sla_tracker_case_id_idx ON efrm.case_sla_tracker USING btree (case_id);


--
-- Name: device_master_institution_request_id_uq; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX device_master_institution_request_id_uq ON efrm.device_master USING btree (institution_id, request_id) WHERE ((request_id IS NOT NULL) AND (btrim((request_id)::text) <> ''::text));


--
-- Name: entity_device_map_entity_id_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX entity_device_map_entity_id_idx ON efrm.entity_device_map USING btree (entity_id);


--
-- Name: entity_relation_map_entity_id_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX entity_relation_map_entity_id_idx ON efrm.entity_relation_map USING btree (entity_id);


--
-- Name: idx_adverse_alert_request_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_alert_request_id ON efrm.adverse_alert USING btree (risk_band);


--
-- Name: idx_adverse_alert_result_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_alert_result_id ON efrm.adverse_alert USING btree (status);


--
-- Name: idx_adverse_alert_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_alert_status ON efrm.adverse_alert USING btree (status);


--
-- Name: idx_adverse_integration_config_institution_provider_active; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_integration_config_institution_provider_active ON efrm.adverse_integration_config USING btree (institution_id, provider_code, is_active);


--
-- Name: idx_adverse_integration_config_master; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_integration_config_master ON efrm.adverse_integration_config USING btree (config_master_id);


--
-- Name: idx_adverse_integration_inst_provider_active; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_integration_inst_provider_active ON efrm.adverse_integration_config USING btree (institution_id, provider_code, is_active);


--
-- Name: idx_adverse_match_url; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_match_url ON efrm.adverse_match USING btree (source_url);


--
-- Name: idx_adverse_request_created_at; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_request_created_at ON efrm.adverse_request USING btree (created_at);


--
-- Name: idx_adverse_request_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_request_entity_id ON efrm.adverse_request USING btree (entity_id);


--
-- Name: idx_adverse_request_entity_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_request_entity_type ON efrm.adverse_request USING btree (entity_type);


--
-- Name: idx_adverse_result_risk_score; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_adverse_result_risk_score ON efrm.adverse_result USING btree (risk_score);


--
-- Name: idx_bulk_job_last_heartbeat_at; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_bulk_job_last_heartbeat_at ON efrm.bulk_job USING btree (last_heartbeat_at);


--
-- Name: idx_bulk_job_source_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_bulk_job_source_status ON efrm.bulk_job USING btree (source_code, status);


--
-- Name: idx_bulk_job_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_bulk_job_status ON efrm.bulk_job USING btree (status);


--
-- Name: idx_cemap_cap_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_cemap_cap_status ON efrm.capability_endpoint_map USING btree (capability_code, status);


--
-- Name: idx_cemap_service_path; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_cemap_service_path ON efrm.capability_endpoint_map USING btree (service_code, path_pattern, status);


--
-- Name: idx_entity_graph_cluster_nodes_cluster; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_cluster_nodes_cluster ON efrm.entity_graph_cluster_nodes USING btree (institution_id, cluster_id);


--
-- Name: idx_entity_graph_cluster_nodes_node; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_cluster_nodes_node ON efrm.entity_graph_cluster_nodes USING btree (institution_id, node_id);


--
-- Name: idx_entity_graph_clusters_risk; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_clusters_risk ON efrm.entity_graph_clusters USING btree (institution_id, cluster_risk_score DESC);


--
-- Name: idx_entity_graph_clusters_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_clusters_status ON efrm.entity_graph_clusters USING btree (institution_id, status);


--
-- Name: idx_entity_graph_edges_confidence; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_edges_confidence ON efrm.entity_graph_edges USING btree (institution_id, confidence_score);


--
-- Name: idx_entity_graph_edges_dimension; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_edges_dimension ON efrm.entity_graph_edges USING btree (institution_id, dimension_code);


--
-- Name: idx_entity_graph_edges_source; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_edges_source ON efrm.entity_graph_edges USING btree (institution_id, source_node);


--
-- Name: idx_entity_graph_edges_target; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_edges_target ON efrm.entity_graph_edges USING btree (institution_id, target_node);


--
-- Name: idx_entity_graph_evidence_case; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_evidence_case ON efrm.entity_graph_evidence USING btree (case_id);


--
-- Name: idx_entity_graph_evidence_edge; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_evidence_edge ON efrm.entity_graph_evidence USING btree (edge_id);


--
-- Name: idx_entity_graph_evidence_rule; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_evidence_rule ON efrm.entity_graph_evidence USING btree (rule_code);


--
-- Name: idx_entity_graph_evidence_source; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_evidence_source ON efrm.entity_graph_evidence USING btree (institution_id, source_table, source_id);


--
-- Name: idx_entity_graph_evidence_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_evidence_time ON efrm.entity_graph_evidence USING btree (institution_id, event_time DESC);


--
-- Name: idx_entity_graph_evidence_transaction; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_evidence_transaction ON efrm.entity_graph_evidence USING btree (transaction_id);


--
-- Name: idx_entity_graph_nodes_dimension; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_nodes_dimension ON efrm.entity_graph_nodes USING btree (institution_id, dimension_code);


--
-- Name: idx_entity_graph_nodes_institution; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_nodes_institution ON efrm.entity_graph_nodes USING btree (institution_id);


--
-- Name: idx_entity_graph_nodes_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_nodes_type ON efrm.entity_graph_nodes USING btree (institution_id, node_type);


--
-- Name: idx_entity_graph_refresh_checkpoint_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_refresh_checkpoint_status ON efrm.entity_graph_refresh_checkpoint USING btree (institution_id, status);


--
-- Name: idx_entity_graph_refresh_config_due; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_refresh_config_due ON efrm.entity_graph_refresh_config USING btree (enabled, next_run_at);


--
-- Name: idx_entity_graph_view_config_enabled; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_graph_view_config_enabled ON efrm.entity_graph_view_config USING btree (institution_id, view_type, enabled);


--
-- Name: idx_entity_risk_factor_entity; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_risk_factor_entity ON efrm.entity_risk_factor_breakdown USING btree (entity_id);


--
-- Name: idx_entity_risk_factor_entity_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_risk_factor_entity_time ON efrm.entity_risk_factor_breakdown USING btree (entity_id, created_at DESC);


--
-- Name: idx_entity_risk_factor_event; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_risk_factor_event ON efrm.entity_risk_factor_breakdown USING btree (event_id);


--
-- Name: idx_entity_risk_factor_reference; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_risk_factor_reference ON efrm.entity_risk_factor_breakdown USING btree (reference_id);


--
-- Name: idx_entity_risk_history_entity; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_risk_history_entity ON efrm.entity_risk_history USING btree (entity_id, created_at DESC);


--
-- Name: idx_entity_risk_score; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_risk_score ON efrm.entity_risk_profile USING btree (final_score);


--
-- Name: idx_entity_risk_tier; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_entity_risk_tier ON efrm.entity_risk_profile USING btree (risk_tier);


--
-- Name: idx_graph_dimension_config_enabled; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_graph_dimension_config_enabled ON efrm.graph_dimension_config USING btree (institution_id, enabled);


--
-- Name: idx_graph_dimension_config_entity_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_graph_dimension_config_entity_type ON efrm.graph_dimension_config USING btree (institution_id, entity_type);


--
-- Name: idx_graph_dimension_config_source_table; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_graph_dimension_config_source_table ON efrm.graph_dimension_config USING btree (source_table);


--
-- Name: idx_graph_dimension_subtype_enabled; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_graph_dimension_subtype_enabled ON efrm.graph_dimension_subtype_config USING btree (institution_id, entity_type, enabled);


--
-- Name: idx_lgat_name_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_lgat_name_time ON efrm.login_attempt USING btree (attempted_username_hash, attempt_at);


--
-- Name: idx_lgat_user_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_lgat_user_time ON efrm.login_attempt USING btree (user_id, attempt_at);


--
-- Name: idx_list_addr_country; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_addr_country ON efrm.list_normalized_address USING btree (upper(country)) WHERE (country IS NOT NULL);


--
-- Name: idx_list_addr_postal; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_addr_postal ON efrm.list_normalized_address USING btree (postal_code) WHERE (postal_code IS NOT NULL);


--
-- Name: idx_list_addr_tokens; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_addr_tokens ON efrm.list_normalized_address USING gin (address_tokens);


--
-- Name: idx_list_alias_arabic_trgm; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_alias_arabic_trgm ON efrm.list_entity_alias USING gin (alias_arabic public.gin_trgm_ops);


--
-- Name: idx_list_alias_translit_trgm; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_alias_translit_trgm ON efrm.list_entity_alias USING gin (transliterated_alias public.gin_trgm_ops);


--
-- Name: idx_list_entity_alias_list_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_entity_alias_list_entity_id ON efrm.list_entity_alias USING btree (list_entity_id);


--
-- Name: idx_list_entity_arabic_trgm; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_entity_arabic_trgm ON efrm.list_entity USING gin (normalized_name_arabic public.gin_trgm_ops);


--
-- Name: idx_list_entity_country; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_entity_country ON efrm.list_entity USING btree (upper(country)) WHERE (country IS NOT NULL);


--
-- Name: idx_list_entity_entity_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_entity_entity_type ON efrm.list_entity USING btree (upper((entity_type)::text)) WHERE (entity_type IS NOT NULL);


--
-- Name: idx_list_entity_list_version_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_entity_list_version_id ON efrm.list_entity USING btree (list_version_id);


--
-- Name: idx_list_entity_normalized_name_prefix; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_entity_normalized_name_prefix ON efrm.list_entity USING btree (upper(normalized_name) text_pattern_ops) WHERE (normalized_name IS NOT NULL);


--
-- Name: idx_list_entity_screening_filters; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_entity_screening_filters ON efrm.list_entity USING btree (upper(country), upper((entity_type)::text), upper(normalized_name) text_pattern_ops) WHERE (normalized_name IS NOT NULL);


--
-- Name: idx_list_entity_translit_trgm; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_entity_translit_trgm ON efrm.list_entity USING gin (transliterated_name public.gin_trgm_ops);


--
-- Name: idx_list_source_is_active; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_source_is_active ON efrm.list_source USING btree (is_active) WHERE ((is_active)::text = 'Y'::text);


--
-- Name: idx_list_version_source_code_status_loaded; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_version_source_code_status_loaded ON efrm.list_version USING btree (source_code, status, loaded_at DESC, id DESC);


--
-- Name: idx_list_version_source_config_status_loaded; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_list_version_source_config_status_loaded ON efrm.list_version USING btree (source_config_id, status, loaded_at DESC, id DESC);


--
-- Name: idx_lock_user_active; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_lock_user_active ON efrm.account_lockout USING btree (user_id, is_active);


--
-- Name: idx_mf_inference; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX idx_mf_inference ON efrm.ml_feedback USING btree (inference_id, feedback_type);


--
-- Name: idx_mfdm_feature_order; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_mfdm_feature_order ON efrm.ml_feature_definition_metadata USING btree (feature_id, feature_order);


--
-- Name: idx_mir_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_mir_status ON efrm.ml_inference_result USING btree (status);


--
-- Name: idx_mir_txn; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_mir_txn ON efrm.ml_inference_result USING btree (transaction_id);


--
-- Name: idx_misl_inference_rank; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_misl_inference_rank ON efrm.ml_inference_shap_local USING btree (inference_id, importance_rank);


--
-- Name: idx_misl_model_version; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_misl_model_version ON efrm.ml_inference_shap_local USING btree (model_version_id);


--
-- Name: idx_ml_audit_event_aggregate; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_audit_event_aggregate ON efrm.ml_audit_event USING btree (aggregate_type, aggregate_id, created_at DESC);


--
-- Name: idx_ml_audit_event_timeline; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_audit_event_timeline ON efrm.ml_audit_event USING btree (institution_id, created_at DESC);


--
-- Name: idx_ml_data_generation_record_lookup; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_data_generation_record_lookup ON efrm.ml_data_generation_record USING btree (entity_type, entity_id);


--
-- Name: idx_ml_data_generation_run_tenant; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_data_generation_run_tenant ON efrm.ml_data_generation_run USING btree (institution_id, created_at DESC);


--
-- Name: idx_ml_deployment_allocation_version; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_deployment_allocation_version ON efrm.ml_deployment_allocation USING btree (model_version_id, created_at DESC);


--
-- Name: idx_ml_deployment_event_timeline; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_deployment_event_timeline ON efrm.ml_deployment_event USING btree (deployment_plan_id, created_at DESC);


--
-- Name: idx_ml_deployment_plan_context; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_deployment_plan_context ON efrm.ml_deployment_plan USING btree (model_id, status, created_at DESC);


--
-- Name: idx_ml_feature_definition_contract_order; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_feature_definition_contract_order ON efrm.ml_feature_definition USING btree (feature_set_version_id, feature_order);


--
-- Name: idx_ml_inference_result_monitoring; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_inference_result_monitoring ON efrm.ml_inference_result USING btree (model_version_id, created_at DESC);


--
-- Name: idx_ml_inference_review_inference; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_inference_review_inference ON efrm.ml_inference_review USING btree (inference_id, created_at DESC);


--
-- Name: idx_ml_model_job_queue; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_model_job_queue ON efrm.ml_model_job USING btree (job_type, job_status, created_at);


--
-- Name: idx_ml_model_version_approval_queue; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_model_version_approval_queue ON efrm.ml_model_version USING btree (approval_status, submitted_at);


--
-- Name: idx_ml_monitoring_alert_open; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_monitoring_alert_open ON efrm.ml_monitoring_alert USING btree (model_version_id, status, detected_at DESC);


--
-- Name: idx_ml_shadow_execution_plan; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_shadow_execution_plan ON efrm.ml_shadow_execution USING btree (deployment_plan_id, created_at DESC);


--
-- Name: idx_ml_shadow_execution_queue; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_shadow_execution_queue ON efrm.ml_shadow_execution USING btree (status, available_at, created_at);


--
-- Name: idx_ml_shadow_execution_tenant; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_shadow_execution_tenant ON efrm.ml_shadow_execution USING btree (institution_id, created_at DESC);


--
-- Name: idx_ml_simulation_result_run; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_simulation_result_run ON efrm.ml_simulation_result USING btree (simulation_run_id, row_number);


--
-- Name: idx_ml_simulation_run_model; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_simulation_run_model ON efrm.ml_simulation_run USING btree (model_version_id, created_at DESC);


--
-- Name: idx_ml_simulation_run_tenant; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_simulation_run_tenant ON efrm.ml_simulation_run USING btree (institution_id, created_at DESC);


--
-- Name: idx_ml_training_dataset_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_training_dataset_status ON efrm.ml_training_dataset USING btree (institution_id, status, uploaded_at DESC);


--
-- Name: idx_ml_worker_heartbeat_last_seen; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ml_worker_heartbeat_last_seen ON efrm.ml_worker_heartbeat USING btree (last_seen_at DESC);


--
-- Name: idx_mmds_version; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX idx_mmds_version ON efrm.ml_model_drift_summary USING btree (model_version_id);


--
-- Name: idx_mmg_version; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX idx_mmg_version ON efrm.ml_model_governance USING btree (model_version_id);


--
-- Name: idx_mmj_job_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_mmj_job_status ON efrm.ml_model_job USING btree (job_status);


--
-- Name: idx_mmj_version_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_mmj_version_type ON efrm.ml_model_job USING btree (model_version_id, job_type);


--
-- Name: idx_mmpd_date; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX idx_mmpd_date ON efrm.ml_model_performance_daily USING btree (model_version_id, metric_date);


--
-- Name: idx_mmr_lookup; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_mmr_lookup ON efrm.ml_model_registry USING btree (institution_id, source_system, channel, model_purpose);


--
-- Name: idx_mmv_version; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX idx_mmv_version ON efrm.ml_model_version USING btree (model_id, version);


--
-- Name: idx_pcap_capability; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_pcap_capability ON efrm.profile_capability USING btree (capability_code);


--
-- Name: idx_pexp_user_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_pexp_user_status ON efrm.password_expiry_notice USING btree (user_id, status);


--
-- Name: idx_prst_user_exp; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_prst_user_exp ON efrm.password_reset_token USING btree (user_id, expires_at);


--
-- Name: idx_rft_parent; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_rft_parent ON efrm.refresh_token USING btree (parent_token_id);


--
-- Name: idx_rft_sess_exp; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_rft_sess_exp ON efrm.refresh_token USING btree (session_id, expires_at);


--
-- Name: idx_rft_user_exp; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_rft_user_exp ON efrm.refresh_token USING btree (user_id, expires_at);


--
-- Name: idx_risk_event_entity; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_risk_event_entity ON efrm.risk_event_log USING btree (entity_id);


--
-- Name: idx_risk_event_entity_source_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_risk_event_entity_source_time ON efrm.risk_event_log USING btree (entity_id, event_source, event_timestamp DESC);


--
-- Name: idx_risk_event_source; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_risk_event_source ON efrm.risk_event_log USING btree (event_source);


--
-- Name: idx_risk_rating_domain_override_lookup; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_risk_rating_domain_override_lookup ON efrm.risk_rating_domain_override_config USING btree (config_master_id, risk_domain, threshold_score);


--
-- Name: idx_risk_recalculation_job_scope; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_risk_recalculation_job_scope ON efrm.risk_recalculation_job USING btree (scope_type, institution_id, config_id, entity_id);


--
-- Name: idx_risk_recalculation_job_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_risk_recalculation_job_status ON efrm.risk_recalculation_job USING btree (status);


--
-- Name: idx_saud_evt_out; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_saud_evt_out ON efrm.security_audit_log USING btree (event_type, outcome, event_time);


--
-- Name: idx_saud_request; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_saud_request ON efrm.security_audit_log USING btree (request_id);


--
-- Name: idx_saud_sess_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_saud_sess_time ON efrm.security_audit_log USING btree (session_id, event_time);


--
-- Name: idx_saud_usr_evt; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_saud_usr_evt ON efrm.security_audit_log USING btree (institution_id, user_id, event_type, event_time);


--
-- Name: idx_scap_module_resource; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_scap_module_resource ON efrm.security_capability USING btree (module_code, resource_code, status);


--
-- Name: idx_scap_product_menu; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_scap_product_menu ON efrm.security_capability USING btree (product_id, menu_id, status);


--
-- Name: idx_screening_request_channel; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_screening_request_channel ON efrm.screening_request USING btree (channel);


--
-- Name: idx_screening_request_client_request_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_screening_request_client_request_id ON efrm.screening_request USING btree (client_request_id);


--
-- Name: idx_screening_request_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_screening_request_entity_id ON efrm.screening_request USING btree (entity_id) WHERE (entity_id IS NOT NULL);


--
-- Name: idx_screening_request_entity_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_screening_request_entity_type ON efrm.screening_request USING btree (entity_type);


--
-- Name: idx_screening_result_created_at; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_screening_result_created_at ON efrm.screening_result USING btree (created_at DESC);


--
-- Name: idx_screening_result_decision; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_screening_result_decision ON efrm.screening_result USING btree (decision);


--
-- Name: idx_screening_result_request_item_order; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_screening_result_request_item_order ON efrm.screening_result USING btree (request_id, request_item_index);


--
-- Name: idx_screening_result_risk_band; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_screening_result_risk_band ON efrm.screening_result USING btree (risk_band);


--
-- Name: idx_stjti_client_exp; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_stjti_client_exp ON efrm.service_token_jti USING btree (client_id, expires_at);


--
-- Name: idx_ucred_user_active; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_ucred_user_active ON efrm.user_credential USING btree (user_id, is_active);


--
-- Name: idx_usess_abs_st; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_usess_abs_st ON efrm.user_session USING btree (absolute_expires_at, status);


--
-- Name: idx_usess_exp_st; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_usess_exp_st ON efrm.user_session USING btree (expires_at, status);


--
-- Name: idx_usess_user_st; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_usess_user_st ON efrm.user_session USING btree (user_id, status);


--
-- Name: idx_whitelist_entry_list_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX idx_whitelist_entry_list_entity_id ON efrm.whitelist_entry USING btree (list_entity_id);


--
-- Name: ix_bulk_file_inst_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_bulk_file_inst_time ON efrm.bulk_file_upload USING btree (institution_id, uploaded_at, id);


--
-- Name: ix_case_action_case_code_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_case_action_case_code_id ON efrm.case_action_execution_queue USING btree (case_id, action_code, execution_id);


--
-- Name: ix_case_action_execution_queue_case; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_case_action_execution_queue_case ON efrm.case_action_execution_queue USING btree (case_id, sequence_no);


--
-- Name: ix_case_action_execution_queue_due; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_case_action_execution_queue_due ON efrm.case_action_execution_queue USING btree (execution_status, next_retry_at, created_at);


--
-- Name: ix_case_evt_type_time_case; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_case_evt_type_time_case ON efrm.case_events USING btree (event_type, created_at, case_id);


--
-- Name: ix_case_inst_created_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_case_inst_created_id ON efrm.case_master USING btree (institution_id, created_at, case_id);


--
-- Name: ix_case_map_source_alert; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_case_map_source_alert ON efrm.case_alert_mapping USING btree (alert_source_table, alert_id, case_id);


--
-- Name: ix_dash_assign_resolve; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_dash_assign_resolve ON efrm.dashboard_assignment USING btree (institution_id, profile_id, resource_code, approval_status, is_active);


--
-- Name: ix_dash_export_actor_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_dash_export_actor_time ON efrm.dashboard_export_audit USING btree (institution_id, user_id, requested_at);


--
-- Name: ix_dash_variant_resolve; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_dash_variant_resolve ON efrm.dashboard_variant_master USING btree (resource_code, is_product_default, approval_status, is_active);


--
-- Name: ix_efrm_adverse_match_result_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_adverse_match_result_id ON efrm.adverse_match USING btree (result_id);


--
-- Name: ix_efrm_adverse_result_request_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_adverse_result_request_id ON efrm.adverse_result USING btree (request_id);


--
-- Name: ix_efrm_aggregated_metric_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_aggregated_metric_entity_id ON efrm.aggregated_metric USING btree (entity_id);


--
-- Name: ix_efrm_aggregated_metric_entity_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_aggregated_metric_entity_type ON efrm.aggregated_metric USING btree (entity_type);


--
-- Name: ix_efrm_aggregated_metric_institution_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_aggregated_metric_institution_id ON efrm.aggregated_metric USING btree (institution_id);


--
-- Name: ix_efrm_aggregated_metric_lookup; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_aggregated_metric_lookup ON efrm.aggregated_metric USING btree (institution_id, entity_type, entity_id, metric_code);


--
-- Name: ix_efrm_aggregated_metric_metric_code; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_aggregated_metric_metric_code ON efrm.aggregated_metric USING btree (metric_code);


--
-- Name: ix_efrm_bulk_file_upload_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_bulk_file_upload_id ON efrm.bulk_file_upload USING btree (id);


--
-- Name: ix_efrm_case_assignment_assignment_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_case_assignment_assignment_id ON efrm.case_assignment USING btree (assignment_id);


--
-- Name: ix_efrm_case_assignment_config_config_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_case_assignment_config_config_id ON efrm.assignment_config USING btree (config_id);


--
-- Name: ix_efrm_case_events_event_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_case_events_event_id ON efrm.case_events USING btree (event_id);


--
-- Name: ix_efrm_case_evidence_evidence_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_case_evidence_evidence_id ON efrm.case_evidence USING btree (evidence_id);


--
-- Name: ix_efrm_case_recovery_recovery_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_case_recovery_recovery_id ON efrm.case_recovery USING btree (recovery_id);


--
-- Name: ix_efrm_case_sla_tracker_tracker_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_case_sla_tracker_tracker_id ON efrm.case_sla_tracker USING btree (tracker_id);


--
-- Name: ix_efrm_chatbot_audit_log_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_chatbot_audit_log_id ON efrm.chatbot_audit_log USING btree (id);


--
-- Name: ix_efrm_engine_attribute_def_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_engine_attribute_def_id ON efrm.engine_attribute_def USING btree (id);


--
-- Name: ix_efrm_engine_flink_map_context_code; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_engine_flink_map_context_code ON efrm.engine_flink_map USING btree (context_code);


--
-- Name: ix_efrm_engine_flink_map_flink_event_key; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_engine_flink_map_flink_event_key ON efrm.engine_flink_map USING btree (flink_event_key);


--
-- Name: ix_efrm_engine_flink_map_rule_engine_key; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_engine_flink_map_rule_engine_key ON efrm.engine_flink_map USING btree (rule_engine_key);


--
-- Name: ix_efrm_entity_device_map_entity_device_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_entity_device_map_entity_device_id ON efrm.entity_device_map USING btree (entity_device_id);


--
-- Name: ix_efrm_entity_graph_edges_edge_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_entity_graph_edges_edge_id ON efrm.entity_graph_edges USING btree (edge_id);


--
-- Name: ix_efrm_entity_graph_nodes_node_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_entity_graph_nodes_node_id ON efrm.entity_graph_nodes USING btree (node_id);


--
-- Name: ix_efrm_entity_master_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_entity_master_entity_id ON efrm.entity_master USING btree (entity_id);


--
-- Name: ix_efrm_entity_relation_map_entity_relation_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_entity_relation_map_entity_relation_id ON efrm.entity_relation_map USING btree (entity_relation_id);


--
-- Name: ix_efrm_enum_value_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_enum_value_id ON efrm.enum_value USING btree (id);


--
-- Name: ix_efrm_facts_definition_source_system_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_facts_definition_source_system_id ON efrm.facts_definition USING btree (source_system_id);


--
-- Name: ix_efrm_list_entity_alias_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_list_entity_alias_id ON efrm.list_entity_alias USING btree (id);


--
-- Name: ix_efrm_list_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_list_entity_id ON efrm.list_entity USING btree (id);


--
-- Name: ix_efrm_list_normalized_address_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_list_normalized_address_id ON efrm.list_normalized_address USING btree (id);


--
-- Name: ix_efrm_list_normalized_address_list_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_list_normalized_address_list_entity_id ON efrm.list_normalized_address USING btree (list_entity_id);


--
-- Name: ix_efrm_list_source_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_list_source_id ON efrm.list_source USING btree (id);


--
-- Name: ix_efrm_list_version_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_list_version_id ON efrm.list_version USING btree (id);


--
-- Name: ix_efrm_metric_definition_metric_code; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX ix_efrm_metric_definition_metric_code ON efrm.metric_definition USING btree (metric_code);


--
-- Name: ix_efrm_ml_score_blending_policy_policy_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_ml_score_blending_policy_policy_id ON efrm.ml_score_blending_policy USING btree (policy_id);


--
-- Name: ix_efrm_notification_queue_notification_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_notification_queue_notification_id ON efrm.notification_queue USING btree (notification_id);


--
-- Name: ix_efrm_notification_template_template_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_notification_template_template_id ON efrm.notification_template USING btree (template_id);


--
-- Name: ix_efrm_operator_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_operator_id ON efrm.operator_value USING btree (id);


--
-- Name: ix_efrm_reference_data_ref_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_reference_data_ref_id ON efrm.reference_data USING btree (ref_id);


--
-- Name: ix_efrm_rule_decision_policy_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_rule_decision_policy_id ON efrm.rule_decision_policy USING btree (id);


--
-- Name: ix_efrm_rule_drl_context_context_code; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX ix_efrm_rule_drl_context_context_code ON efrm.rule_drl_context USING btree (context_code);


--
-- Name: ix_efrm_rule_group_master_group_code; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX ix_efrm_rule_group_master_group_code ON efrm.rule_group_master USING btree (group_code);


--
-- Name: ix_efrm_rule_group_source_binding_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_rule_group_source_binding_id ON efrm.rule_group_source_binding USING btree (id);


--
-- Name: ix_efrm_rule_group_version_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_rule_group_version_id ON efrm.rule_group_version USING btree (id);


--
-- Name: ix_efrm_rule_group_version_map_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_rule_group_version_map_id ON efrm.rule_group_version_map USING btree (id);


--
-- Name: ix_efrm_rule_master_rule_code; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX ix_efrm_rule_master_rule_code ON efrm.rule_master USING btree (rule_code);


--
-- Name: ix_efrm_rule_required_data_rule_version_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_rule_required_data_rule_version_id ON efrm.rule_required_data USING btree (rule_version_id);


--
-- Name: ix_efrm_rule_version_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_rule_version_id ON efrm.rule_version USING btree (id);


--
-- Name: ix_efrm_ruleengine_alert_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_ruleengine_alert_id ON efrm.transaction_alert USING btree (id);


--
-- Name: ix_efrm_ruleengine_bulk_job_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_ruleengine_bulk_job_id ON efrm.ruleengine_bulk_job USING btree (id);


--
-- Name: ix_efrm_ruleengine_bulk_job_item_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_ruleengine_bulk_job_item_id ON efrm.ruleengine_bulk_job_item USING btree (id);


--
-- Name: ix_efrm_ruleengine_bulk_job_summary_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_ruleengine_bulk_job_summary_id ON efrm.ruleengine_bulk_job_summary USING btree (id);


--
-- Name: ix_efrm_ruleengine_decision_upgrade_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_ruleengine_decision_upgrade_id ON efrm.rule_decision_upgrade USING btree (id);


--
-- Name: ix_efrm_ruleengine_match_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_ruleengine_match_id ON efrm.transaction_match USING btree (id);


--
-- Name: ix_efrm_ruleengine_request_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_ruleengine_request_id ON efrm.transaction_request USING btree (id);


--
-- Name: ix_efrm_ruleengine_result_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_ruleengine_result_id ON efrm.transaction_result USING btree (id);


--
-- Name: ix_efrm_screening_alert_alert_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX ix_efrm_screening_alert_alert_id ON efrm.screening_alert USING btree (alert_id);


--
-- Name: ix_efrm_screening_alert_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_alert_entity_id ON efrm.screening_alert USING btree (entity_id);


--
-- Name: ix_efrm_screening_alert_entity_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_alert_entity_type ON efrm.screening_alert USING btree (entity_type);


--
-- Name: ix_efrm_screening_alert_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_alert_id ON efrm.screening_alert USING btree (id);


--
-- Name: ix_efrm_screening_alert_request_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_alert_request_id ON efrm.screening_alert USING btree (request_id);


--
-- Name: ix_efrm_screening_alert_result_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_alert_result_id ON efrm.screening_alert USING btree (result_id);


--
-- Name: ix_efrm_screening_alert_status; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_alert_status ON efrm.screening_alert USING btree (status);


--
-- Name: ix_efrm_screening_bulk_job_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_bulk_job_id ON efrm.screening_bulk_job USING btree (id);


--
-- Name: ix_efrm_screening_bulk_job_item_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_bulk_job_item_id ON efrm.screening_bulk_job_item USING btree (id);


--
-- Name: ix_efrm_screening_bulk_job_summary_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_bulk_job_summary_id ON efrm.screening_bulk_job_summary USING btree (id);


--
-- Name: ix_efrm_screening_entity_entity_group; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_entity_entity_group ON efrm.screening_entity USING btree (entity_group);


--
-- Name: ix_efrm_screening_entity_entity_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX ix_efrm_screening_entity_entity_type ON efrm.screening_entity USING btree (entity_type);


--
-- Name: ix_efrm_screening_entity_field_field_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_entity_field_field_id ON efrm.screening_entity_field USING btree (field_id);


--
-- Name: ix_efrm_screening_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_entity_id ON efrm.screening_entity USING btree (id);


--
-- Name: ix_efrm_screening_match_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_match_id ON efrm.screening_match USING btree (id);


--
-- Name: ix_efrm_screening_match_result_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_match_result_id ON efrm.screening_match USING btree (result_id);


--
-- Name: ix_efrm_screening_request_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_request_id ON efrm.screening_request USING btree (id);


--
-- Name: ix_efrm_screening_request_request_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX ix_efrm_screening_request_request_id ON efrm.screening_request USING btree (request_id);


--
-- Name: ix_efrm_screening_result_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_result_entity_id ON efrm.screening_result USING btree (entity_id);


--
-- Name: ix_efrm_screening_result_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_result_id ON efrm.screening_result USING btree (id);


--
-- Name: ix_efrm_screening_result_request_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_screening_result_request_id ON efrm.screening_result USING btree (request_id);


--
-- Name: ix_efrm_sla_escalation_escalation_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_sla_escalation_escalation_id ON efrm.sla_escalation USING btree (escalation_id);


--
-- Name: ix_efrm_sla_policy_sla_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_sla_policy_sla_id ON efrm.sla_policy USING btree (sla_id);


--
-- Name: ix_efrm_source_attribute_def_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_source_attribute_def_id ON efrm.source_attribute_def USING btree (id);


--
-- Name: ix_efrm_source_column_mapping_mapping_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_source_column_mapping_mapping_id ON efrm.source_column_mapping USING btree (mapping_id);


--
-- Name: ix_efrm_source_column_mapping_source_code; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_source_column_mapping_source_code ON efrm.source_column_mapping USING btree (source_code);


--
-- Name: ix_efrm_source_config_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_source_config_id ON efrm.source_config USING btree (id);


--
-- Name: ix_efrm_source_config_list_source_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_source_config_list_source_id ON efrm.source_config USING btree (list_source_id);


--
-- Name: ix_efrm_source_system_master_institution_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_source_system_master_institution_id ON efrm.source_system_master USING btree (institution_id);


--
-- Name: ix_efrm_source_system_master_source_system_code; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_source_system_master_source_system_code ON efrm.source_system_master USING btree (source_system_code);


--
-- Name: ix_efrm_source_system_master_source_system_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_source_system_master_source_system_id ON efrm.source_system_master USING btree (source_system_id);


--
-- Name: ix_efrm_transaction_master_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_transaction_master_id ON efrm.transaction_master USING btree (id);


--
-- Name: ix_efrm_whitelist_entry_entity_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_whitelist_entry_entity_id ON efrm.whitelist_entry USING btree (entity_id);


--
-- Name: ix_efrm_whitelist_entry_entity_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_whitelist_entry_entity_type ON efrm.whitelist_entry USING btree (entity_type);


--
-- Name: ix_efrm_whitelist_entry_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_efrm_whitelist_entry_id ON efrm.whitelist_entry USING btree (id);


--
-- Name: ix_ml_job_dead_letter_open; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_ml_job_dead_letter_open ON efrm.ml_job_dead_letter USING btree (failed_at DESC) WHERE (resolved_at IS NULL);


--
-- Name: ix_ml_job_execution_available; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_ml_job_execution_available ON efrm.ml_job_execution_state USING btree (available_at) WHERE ((completed_at IS NULL) AND (dead_lettered_at IS NULL));


--
-- Name: ix_ml_worker_heartbeat_seen; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_ml_worker_heartbeat_seen ON efrm.ml_worker_heartbeat USING btree (worker_type, last_seen_at DESC);


--
-- Name: ix_rep_asn_resolve; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_rep_asn_resolve ON efrm.report_assignment USING btree (institution_id, profile_id, report_code, approval_status, is_active);


--
-- Name: ix_rep_var_resolve; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_rep_var_resolve ON efrm.report_variant_master USING btree (report_code, is_product_default, approval_status, is_active);


--
-- Name: ix_report_export_actor_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_report_export_actor_time ON efrm.report_export_audit USING btree (institution_id, user_id, requested_at);


--
-- Name: ix_rule_master_tag_rule_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_rule_master_tag_rule_id ON efrm.rule_master_tag USING btree (rule_id);


--
-- Name: ix_rule_master_tag_tag_code; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_rule_master_tag_tag_code ON efrm.rule_master_tag USING btree (tag_code);


--
-- Name: ix_screen_alert_created_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_screen_alert_created_id ON efrm.screening_alert USING btree (created_at, request_id, id);


--
-- Name: ix_screen_req_inst_time; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_screen_req_inst_time ON efrm.screening_request USING btree (institution_id, created_at, id);


--
-- Name: ix_screening_entity_relation_active; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_screening_entity_relation_active ON efrm.screening_entity_relation USING btree (entity_type, is_active);


--
-- Name: ix_screening_entity_relation_entity_type; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_screening_entity_relation_entity_type ON efrm.screening_entity_relation USING btree (entity_type);


--
-- Name: ix_sla_policy_lookup; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_sla_policy_lookup ON efrm.sla_policy USING btree (action_type, alert_type, priority);


--
-- Name: ix_txn_alert_created_id; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_txn_alert_created_id ON efrm.transaction_alert USING btree (created_at, id);


--
-- Name: ix_txn_match_result_rule; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX ix_txn_match_result_rule ON efrm.transaction_match USING btree (transaction_result_id, rule_code);


--
-- Name: menu_master_parent_id_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX menu_master_parent_id_idx ON efrm.menu_master USING btree (parent_id);


--
-- Name: menu_master_product_id_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX menu_master_product_id_idx ON efrm.menu_master USING btree (product_id);


--
-- Name: notification_queue_event_code_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX notification_queue_event_code_idx ON efrm.notification_queue USING btree (event_code);


--
-- Name: notification_queue_status_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX notification_queue_status_idx ON efrm.notification_queue USING btree (status);


--
-- Name: notification_queue_user_id_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX notification_queue_user_id_idx ON efrm.notification_queue USING btree (user_id);


--
-- Name: notification_template_channel_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX notification_template_channel_idx ON efrm.notification_template USING btree (channel);


--
-- Name: notification_template_event_code_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX notification_template_event_code_idx ON efrm.notification_template USING btree (event_code);


--
-- Name: profile_mstr_pwd_policy_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX profile_mstr_pwd_policy_idx ON efrm.profile_master USING btree (password_policy_rule_id);


--
-- Name: profile_mstr_security_chk_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX profile_mstr_security_chk_idx ON efrm.profile_master USING btree (security_check_id);


--
-- Name: profile_mstr_status_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX profile_mstr_status_idx ON efrm.profile_master USING btree (profile_status);


--
-- Name: reference_data_ref_type_active_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX reference_data_ref_type_active_idx ON efrm.reference_data USING btree (ref_type, is_active);


--
-- Name: reference_data_ref_type_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX reference_data_ref_type_idx ON efrm.reference_data USING btree (ref_type);


--
-- Name: screening_entity_field_entity_type_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX screening_entity_field_entity_type_idx ON efrm.screening_entity_field USING btree (entity_type);


--
-- Name: screening_entity_field_relation_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX screening_entity_field_relation_idx ON efrm.screening_entity_field USING btree (entity_type, entity_relation, is_active);


--
-- Name: transaction_master_institution_source_txn_id_uq; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX transaction_master_institution_source_txn_id_uq ON efrm.transaction_master USING btree (institution_id, source_txn_id) WHERE ((source_txn_id IS NOT NULL) AND (btrim((source_txn_id)::text) <> ''::text));


--
-- Name: uk_entity_graph_edge_institution_pair_dimension; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uk_entity_graph_edge_institution_pair_dimension ON efrm.entity_graph_edges USING btree (institution_id, source_node, target_node, dimension_code) WHERE ((institution_id IS NOT NULL) AND (dimension_code IS NOT NULL));


--
-- Name: uk_entity_graph_node_institution_type_hash; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uk_entity_graph_node_institution_type_hash ON efrm.entity_graph_nodes USING btree (institution_id, node_type, hash_value) WHERE ((institution_id IS NOT NULL) AND (hash_value IS NOT NULL));


--
-- Name: uk_graph_dimension_config_source; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uk_graph_dimension_config_source ON efrm.graph_dimension_config USING btree (institution_id, entity_type, source_table, COALESCE(source_column, ''::character varying), COALESCE(json_path, ''::character varying));


--
-- Name: uq_list_entity_version_external_id_not_null; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uq_list_entity_version_external_id_not_null ON efrm.list_entity USING btree (list_version_id, external_id) WHERE (external_id IS NOT NULL);


--
-- Name: uq_ml_deployment_active_plan; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uq_ml_deployment_active_plan ON efrm.ml_deployment_plan USING btree (model_id) WHERE ((status)::text = ANY ((ARRAY['APPROVED'::character varying, 'RUNNING'::character varying, 'PAUSED'::character varying])::text[]));


--
-- Name: uq_ml_feature_set_version_one_active; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uq_ml_feature_set_version_one_active ON efrm.ml_feature_set_version USING btree (feature_set_id) WHERE ((status)::text = 'ACTIVE'::text);


--
-- Name: uq_ml_job_dead_letter_external; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uq_ml_job_dead_letter_external ON efrm.ml_job_dead_letter USING btree (job_type, external_job_key) WHERE (external_job_key IS NOT NULL);


--
-- Name: uq_ml_model_job_active; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uq_ml_model_job_active ON efrm.ml_model_job USING btree (model_version_id, job_type) WHERE ((job_status)::text = ANY ((ARRAY['ACCEPTED'::character varying, 'PENDING'::character varying, 'RUNNING'::character varying])::text[]));


--
-- Name: uq_ml_model_simulation_sample_default; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uq_ml_model_simulation_sample_default ON efrm.ml_model_simulation_sample USING btree (model_version_id) WHERE is_default;


--
-- Name: uq_ml_shadow_execution_event; Type: INDEX; Schema: efrm; Owner: -
--

CREATE UNIQUE INDEX uq_ml_shadow_execution_event ON efrm.ml_shadow_execution USING btree (deployment_plan_id, source_event_hash);


--
-- Name: user_master_created_at_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX user_master_created_at_idx ON efrm.user_master USING btree (created_at);


--
-- Name: user_master_institution_id_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX user_master_institution_id_idx ON efrm.user_master USING btree (institution_id);


--
-- Name: user_master_profile_id_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX user_master_profile_id_idx ON efrm.user_master USING btree (profile_id);


--
-- Name: user_master_user_status_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX user_master_user_status_idx ON efrm.user_master USING btree (user_status);


--
-- Name: user_pwd_hist_created_at_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX user_pwd_hist_created_at_idx ON efrm.user_password_history USING btree (created_at);


--
-- Name: user_pwd_hist_is_current_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX user_pwd_hist_is_current_idx ON efrm.user_password_history USING btree (is_current);


--
-- Name: user_pwd_hist_user_name_idx; Type: INDEX; Schema: efrm; Owner: -
--

CREATE INDEX user_pwd_hist_user_name_idx ON efrm.user_password_history USING btree (user_name);


--
-- Name: ml_audit_event trg_ml_audit_event_immutable; Type: TRIGGER; Schema: efrm; Owner: -
--

CREATE TRIGGER trg_ml_audit_event_immutable BEFORE DELETE OR UPDATE ON efrm.ml_audit_event FOR EACH ROW EXECUTE FUNCTION efrm.reject_ml_audit_mutation();


--
-- Name: security_audit_log trg_saud_append_only; Type: TRIGGER; Schema: efrm; Owner: -
--

CREATE TRIGGER trg_saud_append_only BEFORE DELETE OR UPDATE ON efrm.security_audit_log FOR EACH ROW EXECUTE FUNCTION efrm.guard_security_audit_log();


--
-- Name: account_lockout account_lockout_user_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.account_lockout
    ADD CONSTRAINT account_lockout_user_id_fkey FOREIGN KEY (user_id) REFERENCES efrm.user_master(user_name);


--
-- Name: adverse_alert adverse_alert_request_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_alert
    ADD CONSTRAINT adverse_alert_request_id_fkey FOREIGN KEY (request_id) REFERENCES efrm.adverse_request(request_id) ON DELETE CASCADE;


--
-- Name: adverse_category_weight adverse_category_weight_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_category_weight
    ADD CONSTRAINT adverse_category_weight_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.adverse_config_master(id) ON DELETE CASCADE;


--
-- Name: adverse_country_risk adverse_country_risk_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_country_risk
    ADD CONSTRAINT adverse_country_risk_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.adverse_config_master(id) ON DELETE CASCADE;


--
-- Name: adverse_integration_config adverse_integration_config_master_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_integration_config
    ADD CONSTRAINT adverse_integration_config_master_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.adverse_config_master(id) ON DELETE CASCADE;


--
-- Name: adverse_match adverse_match_alert_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_match
    ADD CONSTRAINT adverse_match_alert_id_fkey FOREIGN KEY (alert_id) REFERENCES efrm.adverse_alert(id) ON DELETE SET NULL;


--
-- Name: adverse_match adverse_match_result_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_match
    ADD CONSTRAINT adverse_match_result_id_fkey FOREIGN KEY (result_id) REFERENCES efrm.adverse_result(id) ON DELETE CASCADE;


--
-- Name: adverse_recency_factor adverse_recency_factor_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_recency_factor
    ADD CONSTRAINT adverse_recency_factor_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.adverse_config_master(id) ON DELETE CASCADE;


--
-- Name: adverse_result adverse_result_request_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_result
    ADD CONSTRAINT adverse_result_request_id_fkey FOREIGN KEY (request_id) REFERENCES efrm.adverse_request(request_id) ON DELETE CASCADE;


--
-- Name: adverse_risk_band adverse_risk_band_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_risk_band
    ADD CONSTRAINT adverse_risk_band_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.adverse_config_master(id) ON DELETE CASCADE;


--
-- Name: adverse_severity_score adverse_severity_score_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_severity_score
    ADD CONSTRAINT adverse_severity_score_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.adverse_config_master(id) ON DELETE CASCADE;


--
-- Name: adverse_source_weight adverse_source_weight_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_source_weight
    ADD CONSTRAINT adverse_source_weight_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.adverse_config_master(id) ON DELETE CASCADE;


--
-- Name: aggregated_metric aggregated_metric_metric_code_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.aggregated_metric
    ADD CONSTRAINT aggregated_metric_metric_code_fkey FOREIGN KEY (metric_code) REFERENCES efrm.metric_definition(metric_code) ON DELETE RESTRICT;


--
-- Name: alert_category_master alert_category_master_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.alert_category_master
    ADD CONSTRAINT alert_category_master_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.case_config_master(id) ON DELETE CASCADE;


--
-- Name: alert_count_boost_config alert_count_boost_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.alert_count_boost_config
    ADD CONSTRAINT alert_count_boost_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.case_config_master(id) ON DELETE CASCADE;


--
-- Name: audit_trail audit_trail_user_name_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.audit_trail
    ADD CONSTRAINT audit_trail_user_name_fkey FOREIGN KEY (user_name) REFERENCES efrm.user_master(user_name);


--
-- Name: bulk_job bulk_job_list_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.bulk_job
    ADD CONSTRAINT bulk_job_list_version_id_fkey FOREIGN KEY (list_version_id) REFERENCES efrm.list_version(id);


--
-- Name: case_action_execution_log case_action_execution_log_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_execution_log
    ADD CONSTRAINT case_action_execution_log_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id) ON DELETE CASCADE;


--
-- Name: case_action_execution_log case_action_execution_log_execution_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_execution_log
    ADD CONSTRAINT case_action_execution_log_execution_id_fkey FOREIGN KEY (execution_id) REFERENCES efrm.case_action_execution_queue(execution_id) ON DELETE CASCADE;


--
-- Name: case_action_execution_queue case_action_execution_queue_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_execution_queue
    ADD CONSTRAINT case_action_execution_queue_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id) ON DELETE CASCADE;


--
-- Name: case_action_master case_action_master_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_action_master
    ADD CONSTRAINT case_action_master_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.case_config_master(id) ON DELETE CASCADE;


--
-- Name: case_alert_mapping case_alert_mapping_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_alert_mapping
    ADD CONSTRAINT case_alert_mapping_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id) ON DELETE CASCADE;


--
-- Name: case_assignment case_assignment_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_assignment
    ADD CONSTRAINT case_assignment_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id);


--
-- Name: case_decision_action_mapping case_decision_action_mapping_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_decision_action_mapping
    ADD CONSTRAINT case_decision_action_mapping_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.case_config_master(id) ON DELETE CASCADE;


--
-- Name: case_decision_master case_decision_master_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_decision_master
    ADD CONSTRAINT case_decision_master_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.case_config_master(id) ON DELETE CASCADE;


--
-- Name: case_events case_events_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_events
    ADD CONSTRAINT case_events_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id);


--
-- Name: case_evidence case_evidence_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_evidence
    ADD CONSTRAINT case_evidence_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id);


--
-- Name: case_priority_master case_priority_master_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_priority_master
    ADD CONSTRAINT case_priority_master_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.case_config_master(id) ON DELETE CASCADE;


--
-- Name: case_recovery case_recovery_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_recovery
    ADD CONSTRAINT case_recovery_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id);


--
-- Name: case_score_breakdown case_score_breakdown_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_score_breakdown
    ADD CONSTRAINT case_score_breakdown_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id) ON DELETE CASCADE;


--
-- Name: case_scoring_trace case_scoring_trace_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_scoring_trace
    ADD CONSTRAINT case_scoring_trace_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id) ON DELETE CASCADE;


--
-- Name: case_sla_tracker case_sla_tracker_case_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.case_sla_tracker
    ADD CONSTRAINT case_sla_tracker_case_id_fkey FOREIGN KEY (case_id) REFERENCES efrm.case_master(case_id);


--
-- Name: category_correlation_config category_correlation_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.category_correlation_config
    ADD CONSTRAINT category_correlation_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.case_config_master(id) ON DELETE CASCADE;


--
-- Name: critical_override_rules critical_override_rules_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.critical_override_rules
    ADD CONSTRAINT critical_override_rules_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.case_config_master(id) ON DELETE CASCADE;


--
-- Name: dashboard_assignment dashboard_assignment_institution_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.dashboard_assignment
    ADD CONSTRAINT dashboard_assignment_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES efrm.institution(institution_id);


--
-- Name: dashboard_assignment dashboard_assignment_profile_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.dashboard_assignment
    ADD CONSTRAINT dashboard_assignment_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES efrm.profile_master(profile_id);


--
-- Name: dashboard_assignment dashboard_assignment_variant_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.dashboard_assignment
    ADD CONSTRAINT dashboard_assignment_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES efrm.dashboard_variant_master(id);


--
-- Name: device_alert device_alert_device_result_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_alert
    ADD CONSTRAINT device_alert_device_result_id_fkey FOREIGN KEY (device_result_id) REFERENCES efrm.device_result(id) ON DELETE CASCADE;


--
-- Name: device_master device_master_device_request_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_master
    ADD CONSTRAINT device_master_device_request_id_fkey FOREIGN KEY (device_request_id) REFERENCES efrm.device_request(id) ON DELETE CASCADE;


--
-- Name: device_match device_match_device_result_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_match
    ADD CONSTRAINT device_match_device_result_id_fkey FOREIGN KEY (device_result_id) REFERENCES efrm.device_result(id) ON DELETE CASCADE;


--
-- Name: device_result device_result_device_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.device_result
    ADD CONSTRAINT device_result_device_master_id_fkey FOREIGN KEY (device_master_id) REFERENCES efrm.device_master(id) ON DELETE CASCADE;


--
-- Name: efrm_service_config efrm_service_config_institution_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.efrm_service_config
    ADD CONSTRAINT efrm_service_config_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES efrm.institution(institution_id);


--
-- Name: entity_device_map entity_device_map_entity_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_device_map
    ADD CONSTRAINT entity_device_map_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES efrm.entity_master(entity_id);


--
-- Name: entity_graph_cluster_nodes entity_graph_cluster_nodes_cluster_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_cluster_nodes
    ADD CONSTRAINT entity_graph_cluster_nodes_cluster_id_fkey FOREIGN KEY (cluster_id) REFERENCES efrm.entity_graph_clusters(cluster_id) ON DELETE CASCADE;


--
-- Name: entity_graph_cluster_nodes entity_graph_cluster_nodes_node_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_cluster_nodes
    ADD CONSTRAINT entity_graph_cluster_nodes_node_id_fkey FOREIGN KEY (node_id) REFERENCES efrm.entity_graph_nodes(node_id) ON DELETE CASCADE;


--
-- Name: entity_graph_edges entity_graph_edges_source_node_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_edges
    ADD CONSTRAINT entity_graph_edges_source_node_fkey FOREIGN KEY (source_node) REFERENCES efrm.entity_graph_nodes(node_id);


--
-- Name: entity_graph_edges entity_graph_edges_target_node_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_edges
    ADD CONSTRAINT entity_graph_edges_target_node_fkey FOREIGN KEY (target_node) REFERENCES efrm.entity_graph_nodes(node_id);


--
-- Name: entity_graph_evidence entity_graph_evidence_edge_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_graph_evidence
    ADD CONSTRAINT entity_graph_evidence_edge_id_fkey FOREIGN KEY (edge_id) REFERENCES efrm.entity_graph_edges(edge_id) ON DELETE CASCADE;


--
-- Name: entity_relation_map entity_relation_map_entity_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.entity_relation_map
    ADD CONSTRAINT entity_relation_map_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES efrm.entity_master(entity_id);


--
-- Name: facts_definition facts_definition_source_system_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.facts_definition
    ADD CONSTRAINT facts_definition_source_system_id_fkey FOREIGN KEY (source_system_id) REFERENCES efrm.source_system_master(source_system_id);


--
-- Name: adverse_alert fk_adv_alert_result_request; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.adverse_alert
    ADD CONSTRAINT fk_adv_alert_result_request FOREIGN KEY (result_id, request_id) REFERENCES efrm.adverse_result(id, request_id) ON DELETE CASCADE;


--
-- Name: capability_endpoint_map fk_cemap_cap; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.capability_endpoint_map
    ADD CONSTRAINT fk_cemap_cap FOREIGN KEY (capability_code) REFERENCES efrm.security_capability(capability_code);


--
-- Name: profile_capability fk_pcap_capability; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.profile_capability
    ADD CONSTRAINT fk_pcap_capability FOREIGN KEY (capability_code) REFERENCES efrm.security_capability(capability_code);


--
-- Name: profile_capability fk_pcap_profile; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.profile_capability
    ADD CONSTRAINT fk_pcap_profile FOREIGN KEY (profile_id) REFERENCES efrm.profile_master(profile_id);


--
-- Name: rule_master_tag fk_rule_master_tag_rule; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_master_tag
    ADD CONSTRAINT fk_rule_master_tag_rule FOREIGN KEY (rule_id) REFERENCES efrm.rule_master(id) ON DELETE CASCADE;


--
-- Name: screening_alert fk_scr_alert_result_request; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_alert
    ADD CONSTRAINT fk_scr_alert_result_request FOREIGN KEY (result_id, request_id) REFERENCES efrm.screening_result(id, request_id);


--
-- Name: list_entity_alias list_entity_alias_list_entity_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_entity_alias
    ADD CONSTRAINT list_entity_alias_list_entity_id_fkey FOREIGN KEY (list_entity_id) REFERENCES efrm.list_entity(id) ON DELETE CASCADE;


--
-- Name: list_entity list_entity_list_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_entity
    ADD CONSTRAINT list_entity_list_version_id_fkey FOREIGN KEY (list_version_id) REFERENCES efrm.list_version(id);


--
-- Name: list_normalized_address list_normalized_address_list_entity_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_normalized_address
    ADD CONSTRAINT list_normalized_address_list_entity_id_fkey FOREIGN KEY (list_entity_id) REFERENCES efrm.list_entity(id) ON DELETE CASCADE;


--
-- Name: list_version list_version_list_source_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_version
    ADD CONSTRAINT list_version_list_source_id_fkey FOREIGN KEY (list_source_id) REFERENCES efrm.list_source(id);


--
-- Name: list_version list_version_source_config_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.list_version
    ADD CONSTRAINT list_version_source_config_id_fkey FOREIGN KEY (source_config_id) REFERENCES efrm.source_config(id);


--
-- Name: login_attempt login_attempt_user_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.login_attempt
    ADD CONSTRAINT login_attempt_user_id_fkey FOREIGN KEY (user_id) REFERENCES efrm.user_master(user_name);


--
-- Name: menu_master menu_master_parent_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.menu_master
    ADD CONSTRAINT menu_master_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES efrm.menu_master(menu_id);


--
-- Name: menu_master menu_master_product_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.menu_master
    ADD CONSTRAINT menu_master_product_id_fkey FOREIGN KEY (product_id) REFERENCES efrm.product_master(product_id);


--
-- Name: ml_data_generation_record ml_data_generation_record_generation_run_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_data_generation_record
    ADD CONSTRAINT ml_data_generation_record_generation_run_id_fkey FOREIGN KEY (generation_run_id) REFERENCES efrm.ml_data_generation_run(generation_run_id) ON DELETE CASCADE;


--
-- Name: ml_deployment_allocation ml_deployment_allocation_deployment_plan_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_allocation
    ADD CONSTRAINT ml_deployment_allocation_deployment_plan_id_fkey FOREIGN KEY (deployment_plan_id) REFERENCES efrm.ml_deployment_plan(deployment_plan_id);


--
-- Name: ml_deployment_allocation ml_deployment_allocation_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_allocation
    ADD CONSTRAINT ml_deployment_allocation_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_deployment_event ml_deployment_event_deployment_plan_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_event
    ADD CONSTRAINT ml_deployment_event_deployment_plan_id_fkey FOREIGN KEY (deployment_plan_id) REFERENCES efrm.ml_deployment_plan(deployment_plan_id);


--
-- Name: ml_deployment_plan ml_deployment_plan_baseline_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_plan
    ADD CONSTRAINT ml_deployment_plan_baseline_model_version_id_fkey FOREIGN KEY (baseline_model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_deployment_plan ml_deployment_plan_model_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_plan
    ADD CONSTRAINT ml_deployment_plan_model_id_fkey FOREIGN KEY (model_id) REFERENCES efrm.ml_model_registry(model_id);


--
-- Name: ml_deployment_plan ml_deployment_plan_target_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_plan
    ADD CONSTRAINT ml_deployment_plan_target_model_version_id_fkey FOREIGN KEY (target_model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_deployment_stage ml_deployment_stage_deployment_plan_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_deployment_stage
    ADD CONSTRAINT ml_deployment_stage_deployment_plan_id_fkey FOREIGN KEY (deployment_plan_id) REFERENCES efrm.ml_deployment_plan(deployment_plan_id);


--
-- Name: ml_feature_definition ml_feature_definition_feature_set_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_definition
    ADD CONSTRAINT ml_feature_definition_feature_set_version_id_fkey FOREIGN KEY (feature_set_version_id) REFERENCES efrm.ml_feature_set_version(feature_set_version_id);


--
-- Name: ml_feature_definition_metadata ml_feature_definition_metadata_feature_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_definition_metadata
    ADD CONSTRAINT ml_feature_definition_metadata_feature_id_fkey FOREIGN KEY (feature_id) REFERENCES efrm.ml_feature_definition(feature_id);


--
-- Name: ml_feature_set_version ml_feature_set_version_feature_set_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feature_set_version
    ADD CONSTRAINT ml_feature_set_version_feature_set_id_fkey FOREIGN KEY (feature_set_id) REFERENCES efrm.ml_feature_set(feature_set_id);


--
-- Name: ml_feedback ml_feedback_inference_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_feedback
    ADD CONSTRAINT ml_feedback_inference_id_fkey FOREIGN KEY (inference_id) REFERENCES efrm.ml_inference_result(inference_id);


--
-- Name: ml_inference_result ml_inference_result_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_result
    ADD CONSTRAINT ml_inference_result_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_inference_review ml_inference_review_inference_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_review
    ADD CONSTRAINT ml_inference_review_inference_id_fkey FOREIGN KEY (inference_id) REFERENCES efrm.ml_inference_result(inference_id);


--
-- Name: ml_inference_shap_local ml_inference_shap_local_inference_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_shap_local
    ADD CONSTRAINT ml_inference_shap_local_inference_id_fkey FOREIGN KEY (inference_id) REFERENCES efrm.ml_inference_result(inference_id);


--
-- Name: ml_inference_shap_local ml_inference_shap_local_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_inference_shap_local
    ADD CONSTRAINT ml_inference_shap_local_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_job_dead_letter ml_job_dead_letter_model_job_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_job_dead_letter
    ADD CONSTRAINT ml_job_dead_letter_model_job_id_fkey FOREIGN KEY (model_job_id) REFERENCES efrm.ml_model_job(model_job_id) ON DELETE SET NULL;


--
-- Name: ml_job_execution_state ml_job_execution_state_model_job_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_job_execution_state
    ADD CONSTRAINT ml_job_execution_state_model_job_id_fkey FOREIGN KEY (model_job_id) REFERENCES efrm.ml_model_job(model_job_id) ON DELETE CASCADE;


--
-- Name: ml_model_drift_summary ml_model_drift_summary_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_drift_summary
    ADD CONSTRAINT ml_model_drift_summary_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_model_explainability_profile ml_model_explainability_profile_feature_set_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_explainability_profile
    ADD CONSTRAINT ml_model_explainability_profile_feature_set_version_id_fkey FOREIGN KEY (feature_set_version_id) REFERENCES efrm.ml_feature_set_version(feature_set_version_id);


--
-- Name: ml_model_explainability_profile ml_model_explainability_profile_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_explainability_profile
    ADD CONSTRAINT ml_model_explainability_profile_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_model_feature_drift ml_model_feature_drift_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_feature_drift
    ADD CONSTRAINT ml_model_feature_drift_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_model_governance ml_model_governance_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_governance
    ADD CONSTRAINT ml_model_governance_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_model_job ml_model_job_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_job
    ADD CONSTRAINT ml_model_job_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_model_performance_daily ml_model_performance_daily_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_performance_daily
    ADD CONSTRAINT ml_model_performance_daily_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_model_runtime_metrics ml_model_runtime_metrics_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_runtime_metrics
    ADD CONSTRAINT ml_model_runtime_metrics_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_model_shap_global ml_model_shap_global_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_shap_global
    ADD CONSTRAINT ml_model_shap_global_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_model_simulation_sample ml_model_simulation_sample_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_simulation_sample
    ADD CONSTRAINT ml_model_simulation_sample_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_model_version ml_model_version_feature_set_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_version
    ADD CONSTRAINT ml_model_version_feature_set_version_id_fkey FOREIGN KEY (feature_set_version_id) REFERENCES efrm.ml_feature_set_version(feature_set_version_id);


--
-- Name: ml_model_version ml_model_version_model_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_model_version
    ADD CONSTRAINT ml_model_version_model_id_fkey FOREIGN KEY (model_id) REFERENCES efrm.ml_model_registry(model_id);


--
-- Name: ml_monitoring_alert ml_monitoring_alert_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_monitoring_alert
    ADD CONSTRAINT ml_monitoring_alert_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_shadow_execution ml_shadow_execution_deployment_plan_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_shadow_execution
    ADD CONSTRAINT ml_shadow_execution_deployment_plan_id_fkey FOREIGN KEY (deployment_plan_id) REFERENCES efrm.ml_deployment_plan(deployment_plan_id);


--
-- Name: ml_shadow_execution ml_shadow_execution_inference_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_shadow_execution
    ADD CONSTRAINT ml_shadow_execution_inference_id_fkey FOREIGN KEY (inference_id) REFERENCES efrm.ml_inference_result(inference_id);


--
-- Name: ml_shadow_execution ml_shadow_execution_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_shadow_execution
    ADD CONSTRAINT ml_shadow_execution_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_simulation_result ml_simulation_result_simulation_run_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_simulation_result
    ADD CONSTRAINT ml_simulation_result_simulation_run_id_fkey FOREIGN KEY (simulation_run_id) REFERENCES efrm.ml_simulation_run(simulation_run_id) ON DELETE CASCADE;


--
-- Name: ml_simulation_run ml_simulation_run_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_simulation_run
    ADD CONSTRAINT ml_simulation_run_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_training_dataset ml_training_dataset_feature_set_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_training_dataset
    ADD CONSTRAINT ml_training_dataset_feature_set_version_id_fkey FOREIGN KEY (feature_set_version_id) REFERENCES efrm.ml_feature_set_version(feature_set_version_id);


--
-- Name: ml_training_dataset ml_training_dataset_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_training_dataset
    ADD CONSTRAINT ml_training_dataset_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: ml_training_dataset_profile ml_training_dataset_profile_model_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ml_training_dataset_profile
    ADD CONSTRAINT ml_training_dataset_profile_model_version_id_fkey FOREIGN KEY (model_version_id) REFERENCES efrm.ml_model_version(model_version_id);


--
-- Name: password_expiry_notice password_expiry_notice_credential_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.password_expiry_notice
    ADD CONSTRAINT password_expiry_notice_credential_id_fkey FOREIGN KEY (credential_id) REFERENCES efrm.user_credential(credential_id);


--
-- Name: password_expiry_notice password_expiry_notice_user_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.password_expiry_notice
    ADD CONSTRAINT password_expiry_notice_user_id_fkey FOREIGN KEY (user_id) REFERENCES efrm.user_master(user_name);


--
-- Name: password_reset_token password_reset_token_user_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.password_reset_token
    ADD CONSTRAINT password_reset_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES efrm.user_master(user_name);


--
-- Name: profile_master profile_master_password_policy_rule_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.profile_master
    ADD CONSTRAINT profile_master_password_policy_rule_id_fkey FOREIGN KEY (password_policy_rule_id) REFERENCES efrm.password_policy_rule(rule_id);


--
-- Name: profile_master profile_master_security_check_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.profile_master
    ADD CONSTRAINT profile_master_security_check_id_fkey FOREIGN KEY (security_check_id) REFERENCES efrm.security_check(security_check_id);


--
-- Name: refresh_token refresh_token_session_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.refresh_token
    ADD CONSTRAINT refresh_token_session_id_fkey FOREIGN KEY (session_id) REFERENCES efrm.user_session(session_id);


--
-- Name: refresh_token refresh_token_user_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.refresh_token
    ADD CONSTRAINT refresh_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES efrm.user_master(user_name);


--
-- Name: report_assignment report_assignment_institution_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.report_assignment
    ADD CONSTRAINT report_assignment_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES efrm.institution(institution_id);


--
-- Name: report_assignment report_assignment_profile_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.report_assignment
    ADD CONSTRAINT report_assignment_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES efrm.profile_master(profile_id);


--
-- Name: report_assignment report_assignment_variant_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.report_assignment
    ADD CONSTRAINT report_assignment_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES efrm.report_variant_master(id);


--
-- Name: risk_rating_config risk_rating_config_institution_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_config
    ADD CONSTRAINT risk_rating_config_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES efrm.institution(institution_id);


--
-- Name: risk_rating_decay_policy_config risk_rating_decay_policy_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_decay_policy_config
    ADD CONSTRAINT risk_rating_decay_policy_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.risk_rating_config(id) ON DELETE CASCADE;


--
-- Name: risk_rating_decision_impact_config risk_rating_decision_impact_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_decision_impact_config
    ADD CONSTRAINT risk_rating_decision_impact_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.risk_rating_config(id) ON DELETE CASCADE;


--
-- Name: risk_rating_domain_override_config risk_rating_domain_override_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_domain_override_config
    ADD CONSTRAINT risk_rating_domain_override_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.risk_rating_config(id) ON DELETE CASCADE;


--
-- Name: risk_rating_event_type_config risk_rating_event_type_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_event_type_config
    ADD CONSTRAINT risk_rating_event_type_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.risk_rating_config(id) ON DELETE CASCADE;


--
-- Name: risk_rating_override_policy risk_rating_override_policy_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_override_policy
    ADD CONSTRAINT risk_rating_override_policy_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.risk_rating_config(id) ON DELETE CASCADE;


--
-- Name: risk_rating_relationship_risk_config risk_rating_relationship_risk_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_relationship_risk_config
    ADD CONSTRAINT risk_rating_relationship_risk_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.risk_rating_config(id) ON DELETE CASCADE;


--
-- Name: risk_rating_service_weight_config risk_rating_service_weight_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_service_weight_config
    ADD CONSTRAINT risk_rating_service_weight_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.risk_rating_config(id) ON DELETE CASCADE;


--
-- Name: risk_rating_tier_config risk_rating_tier_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_tier_config
    ADD CONSTRAINT risk_rating_tier_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.risk_rating_config(id) ON DELETE CASCADE;


--
-- Name: risk_rating_weight_config risk_rating_weight_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.risk_rating_weight_config
    ADD CONSTRAINT risk_rating_weight_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.risk_rating_config(id) ON DELETE CASCADE;


--
-- Name: rule_group_source_binding rule_group_source_binding_rule_group_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_source_binding
    ADD CONSTRAINT rule_group_source_binding_rule_group_version_id_fkey FOREIGN KEY (rule_group_version_id) REFERENCES efrm.rule_group_version(id) ON DELETE CASCADE;


--
-- Name: rule_group_version_map rule_group_version_map_rule_group_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_version_map
    ADD CONSTRAINT rule_group_version_map_rule_group_version_id_fkey FOREIGN KEY (rule_group_version_id) REFERENCES efrm.rule_group_version(id) ON DELETE CASCADE;


--
-- Name: rule_group_version_map rule_group_version_map_rule_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_version_map
    ADD CONSTRAINT rule_group_version_map_rule_version_id_fkey FOREIGN KEY (rule_version_id) REFERENCES efrm.rule_version(id) ON DELETE CASCADE;


--
-- Name: rule_group_version rule_group_version_rule_group_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_group_version
    ADD CONSTRAINT rule_group_version_rule_group_master_id_fkey FOREIGN KEY (rule_group_master_id) REFERENCES efrm.rule_group_master(id) ON DELETE CASCADE;


--
-- Name: rule_metric_dependency rule_metric_dependency_metric_code_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_metric_dependency
    ADD CONSTRAINT rule_metric_dependency_metric_code_fkey FOREIGN KEY (metric_code) REFERENCES efrm.metric_definition(metric_code) ON DELETE RESTRICT;


--
-- Name: rule_metric_dependency rule_metric_dependency_rule_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_metric_dependency
    ADD CONSTRAINT rule_metric_dependency_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES efrm.rule_master(id) ON DELETE CASCADE;


--
-- Name: rule_required_data rule_required_data_rule_version_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_required_data
    ADD CONSTRAINT rule_required_data_rule_version_id_fkey FOREIGN KEY (rule_version_id) REFERENCES efrm.rule_version(id) ON DELETE CASCADE;


--
-- Name: rule_version rule_version_drl_context_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_version
    ADD CONSTRAINT rule_version_drl_context_id_fkey FOREIGN KEY (drl_context_id) REFERENCES efrm.rule_drl_context(id) ON DELETE RESTRICT;


--
-- Name: rule_version rule_version_rule_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.rule_version
    ADD CONSTRAINT rule_version_rule_master_id_fkey FOREIGN KEY (rule_master_id) REFERENCES efrm.rule_master(id) ON DELETE CASCADE;


--
-- Name: transaction_alert ruleengine_alert_ruleengine_result_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_alert
    ADD CONSTRAINT ruleengine_alert_ruleengine_result_id_fkey FOREIGN KEY (transaction_result_id) REFERENCES efrm.transaction_result(id) ON DELETE CASCADE;


--
-- Name: ruleengine_bulk_job_item ruleengine_bulk_job_item_bulk_job_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job_item
    ADD CONSTRAINT ruleengine_bulk_job_item_bulk_job_id_fkey FOREIGN KEY (bulk_job_id) REFERENCES efrm.ruleengine_bulk_job(id) ON DELETE CASCADE;


--
-- Name: ruleengine_bulk_job_summary ruleengine_bulk_job_summary_bulk_job_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.ruleengine_bulk_job_summary
    ADD CONSTRAINT ruleengine_bulk_job_summary_bulk_job_id_fkey FOREIGN KEY (bulk_job_id) REFERENCES efrm.ruleengine_bulk_job(id) ON DELETE CASCADE;


--
-- Name: transaction_match ruleengine_match_ruleengine_result_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_match
    ADD CONSTRAINT ruleengine_match_ruleengine_result_id_fkey FOREIGN KEY (transaction_result_id) REFERENCES efrm.transaction_result(id) ON DELETE CASCADE;


--
-- Name: transaction_result ruleengine_result_transaction_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_result
    ADD CONSTRAINT ruleengine_result_transaction_master_id_fkey FOREIGN KEY (transaction_master_id) REFERENCES efrm.transaction_master(id) ON DELETE CASCADE;


--
-- Name: screening_alert screening_alert_request_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_alert
    ADD CONSTRAINT screening_alert_request_id_fkey FOREIGN KEY (request_id) REFERENCES efrm.screening_request(request_id);


--
-- Name: screening_bulk_job_item screening_bulk_job_item_bulk_job_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job_item
    ADD CONSTRAINT screening_bulk_job_item_bulk_job_id_fkey FOREIGN KEY (bulk_job_id) REFERENCES efrm.screening_bulk_job(id) ON DELETE CASCADE;


--
-- Name: screening_bulk_job_summary screening_bulk_job_summary_bulk_job_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_bulk_job_summary
    ADD CONSTRAINT screening_bulk_job_summary_bulk_job_id_fkey FOREIGN KEY (bulk_job_id) REFERENCES efrm.screening_bulk_job(id) ON DELETE CASCADE;


--
-- Name: screening_decision_threshold screening_decision_threshold_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_decision_threshold
    ADD CONSTRAINT screening_decision_threshold_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.screening_config_master(id) ON DELETE CASCADE;


--
-- Name: screening_field_config screening_field_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_field_config
    ADD CONSTRAINT screening_field_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.screening_config_master(id) ON DELETE CASCADE;


--
-- Name: screening_group_config screening_group_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_group_config
    ADD CONSTRAINT screening_group_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.screening_config_master(id) ON DELETE CASCADE;


--
-- Name: screening_identifier_config screening_identifier_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_identifier_config
    ADD CONSTRAINT screening_identifier_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.screening_config_master(id) ON DELETE CASCADE;


--
-- Name: screening_match screening_match_result_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_match
    ADD CONSTRAINT screening_match_result_id_fkey FOREIGN KEY (result_id) REFERENCES efrm.screening_result(id) ON DELETE CASCADE;


--
-- Name: screening_result screening_result_request_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_result
    ADD CONSTRAINT screening_result_request_id_fkey FOREIGN KEY (request_id) REFERENCES efrm.screening_request(request_id);


--
-- Name: screening_risk_band screening_risk_band_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_risk_band
    ADD CONSTRAINT screening_risk_band_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.screening_config_master(id) ON DELETE CASCADE;


--
-- Name: screening_source_config screening_source_config_config_master_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_source_config
    ADD CONSTRAINT screening_source_config_config_master_id_fkey FOREIGN KEY (config_master_id) REFERENCES efrm.screening_config_master(id) ON DELETE CASCADE;


--
-- Name: screening_source_config screening_source_config_list_source_code_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.screening_source_config
    ADD CONSTRAINT screening_source_config_list_source_code_fkey FOREIGN KEY (list_source_code) REFERENCES efrm.list_source(code) ON DELETE CASCADE;


--
-- Name: security_notification security_notification_user_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.security_notification
    ADD CONSTRAINT security_notification_user_id_fkey FOREIGN KEY (user_id) REFERENCES efrm.user_master(user_name);


--
-- Name: service_token_jti service_token_jti_client_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.service_token_jti
    ADD CONSTRAINT service_token_jti_client_id_fkey FOREIGN KEY (client_id) REFERENCES efrm.service_client(client_id);


--
-- Name: sla_escalation sla_escalation_sla_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.sla_escalation
    ADD CONSTRAINT sla_escalation_sla_id_fkey FOREIGN KEY (sla_id) REFERENCES efrm.sla_policy(sla_id);


--
-- Name: source_config source_config_list_source_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.source_config
    ADD CONSTRAINT source_config_list_source_id_fkey FOREIGN KEY (list_source_id) REFERENCES efrm.list_source(id);


--
-- Name: transaction_master transaction_master_ruleengine_request_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.transaction_master
    ADD CONSTRAINT transaction_master_ruleengine_request_id_fkey FOREIGN KEY (transaction_request_id) REFERENCES efrm.transaction_request(id) ON DELETE CASCADE;


--
-- Name: user_credential user_credential_user_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_credential
    ADD CONSTRAINT user_credential_user_id_fkey FOREIGN KEY (user_id) REFERENCES efrm.user_master(user_name);


--
-- Name: user_master user_master_institution_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_master
    ADD CONSTRAINT user_master_institution_id_fkey FOREIGN KEY (institution_id) REFERENCES efrm.institution(institution_id);


--
-- Name: user_master user_master_profile_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_master
    ADD CONSTRAINT user_master_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES efrm.profile_master(profile_id);


--
-- Name: user_password_history user_password_history_user_name_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_password_history
    ADD CONSTRAINT user_password_history_user_name_fkey FOREIGN KEY (user_name) REFERENCES efrm.user_master(user_name);


--
-- Name: user_session user_session_security_check_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_session
    ADD CONSTRAINT user_session_security_check_id_fkey FOREIGN KEY (security_check_id) REFERENCES efrm.security_check(security_check_id);


--
-- Name: user_session user_session_user_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.user_session
    ADD CONSTRAINT user_session_user_id_fkey FOREIGN KEY (user_id) REFERENCES efrm.user_master(user_name);


--
-- Name: whitelist_entry whitelist_entry_list_entity_id_fkey; Type: FK CONSTRAINT; Schema: efrm; Owner: -
--

ALTER TABLE ONLY efrm.whitelist_entry
    ADD CONSTRAINT whitelist_entry_list_entity_id_fkey FOREIGN KEY (list_entity_id) REFERENCES efrm.list_entity(id);


--
-- PostgreSQL database dump complete
--

\unrestrict e6WUlNwa2sgZmYE4DudVHurJ7Lk7e89zRqZXpbpLy0Y4Wnc4zT0ADlcBe9F9F7A

