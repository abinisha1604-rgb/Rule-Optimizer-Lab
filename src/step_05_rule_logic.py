"""Lesson 3: read one exact rule version and its declared dependencies.

Metric SQL is returned as text for inspection. This lesson never executes it.
The connection is read-only and the rule is selected by code plus version number.
"""

import argparse
import json
import sys

import psycopg
from psycopg.rows import dict_row

from local_postgres import CONFIG, PASSWORD_FILE


RULE_QUERY = """
SELECT rm.id AS rule_master_id,
       rm.rule_code,
       rm.name AS rule_name,
       rm.rule_type,
       rm.fact,
       rm.description AS rule_description,
       rv.id AS rule_version_id,
       rv.version_no,
       rv.status,
       rv.logic,
       rv.drl_context_id,
       rv.drl_rule,
       rv.checksum,
       rv.test_count,
       rv.signal_code,
       rv.signal_weight,
       rv.primary_entity,
       rv.signal_category,
       rv.signal_severity,
       rv.severity_rank
FROM efrm.rule_master AS rm
JOIN efrm.rule_version AS rv
  ON rv.rule_master_id = rm.id
WHERE rm.rule_code = %s
  AND rv.version_no = %s
"""

METRIC_QUERY = """
SELECT rmd.id AS dependency_id,
       rmd.metric_code,
       rmd.entity_type,
       rmd.metric_role,
       md.id AS metric_definition_id,
       md.metric_name,
       md.window_type,
       md.window_size,
       md.data_type,
       md.aggregation_type,
       md.context_code,
       md.is_active AS metric_is_active,
       md.sql_statement
FROM efrm.rule_metric_dependency AS rmd
LEFT JOIN efrm.metric_definition AS md
  ON md.metric_code = rmd.metric_code
WHERE rmd.rule_id = %s
ORDER BY rmd.id
"""

REQUIRED_DATA_QUERY = """
SELECT id, variable_type, variable, entity_type
FROM efrm.rule_required_data
WHERE rule_version_id = %s
ORDER BY id
"""


def summarize_metric_dependencies(metrics):
    """Classify dependency completeness without evaluating any SQL text."""
    missing_definition = [m["metric_code"] for m in metrics if m["metric_definition_id"] is None]
    missing_sql = [m["metric_code"] for m in metrics
                   if m["metric_definition_id"] is not None and not m["sql_statement"]]
    return {
        "dependency_count": len(metrics),
        "missing_metric_definitions": missing_definition,
        "missing_sql_definitions": missing_sql,
        "all_dependencies_resolved": not missing_definition and not missing_sql,
        "metric_sql_execution": "NOT_RUN_IN_THIS_LESSON",
    }


def read_rule(rule_code, version_no):
    password = PASSWORD_FILE.read_text(encoding="utf-8").strip()
    with psycopg.connect(
        **CONFIG, password=password, connect_timeout=5, row_factory=dict_row,
        options="-c default_transaction_read_only=on -c statement_timeout=30000",
    ) as conn:
        rule = conn.execute(RULE_QUERY, (rule_code, version_no)).fetchone()
        if rule is None:
            return {
                "source": "LOCAL_DATABASE",
                "requested_rule_code": rule_code,
                "requested_version_no": version_no,
                "status": "RULE_VERSION_NOT_FOUND",
            }
        metrics = conn.execute(METRIC_QUERY, (rule["rule_master_id"],)).fetchall()
        required_data = conn.execute(REQUIRED_DATA_QUERY, (rule["rule_version_id"],)).fetchall()

    metric_dicts = [dict(m) for m in metrics]
    required_dicts = [dict(item) for item in required_data]
    checks = summarize_metric_dependencies(metric_dicts)
    checks.update({
        "required_data_count": len(required_dicts),
        "rule_status": rule["status"],
        "rule_checksum_present": bool(rule["checksum"]),
    })
    result = {
        "source": "LOCAL_DATABASE",
        "requested_rule_code": rule_code,
        "requested_version_no": version_no,
        "status": "RULE_VERSION_READ",
        "rule": dict(rule),
        "metric_dependencies": metric_dicts,
        "required_data": required_dicts,
        "checks": checks,
        "next_step": (
            "RECONSTRUCT_METRICS"
            if checks["all_dependencies_resolved"] else "INSPECT_MISSING_DEPENDENCIES"
        ),
    }
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rule-code", required=True)
    parser.add_argument("--version", type=int, default=1)
    parser.add_argument("--summary", action="store_true", help="Print metadata without JSON/DRL/SQL text")
    args = parser.parse_args()
    report = read_rule(args.rule_code, args.version)
    if args.summary and report.get("status") == "RULE_VERSION_READ":
        full = report
        report = {
            key: full[key] for key in (
                "source", "requested_rule_code", "requested_version_no", "status",
                "checks", "next_step",
            )
        }
        # Keep the compact output useful while omitting executable/text payloads.
        report["rule"] = {
            key: full["rule"][key]
            for key in ("rule_master_id", "rule_code", "rule_name", "rule_type", "fact",
                        "rule_version_id", "version_no", "status", "signal_code", "signal_weight")
        }
        report["metric_dependencies"] = [
            {key: metric[key] for key in (
                "dependency_id", "metric_code", "entity_type", "metric_role",
                "metric_definition_id", "metric_name", "window_type", "window_size",
                "metric_is_active",
            )}
            for metric in full["metric_dependencies"]
        ]
        report["required_data"] = full["required_data"]
    print(json.dumps(report, default=str, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except psycopg.Error as exc:
        print(f"Database read failed ({type(exc).__name__}). Check that the lab is running.", file=sys.stderr)
        raise SystemExit(1)
    except OSError as exc:
        print(f"Local setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
