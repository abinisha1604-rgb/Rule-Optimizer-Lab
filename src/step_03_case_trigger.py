"""First agent step: read a case and decide whether to proceed to rule tracing.

This lesson uses a deliberately small policy: CLOSED, approval resolved,
decision timestamp present, and the exact final decision FALSE_POSITIVE.
Other EFRM finalization statuses will be mapped in a later exercise.
"""

import argparse
from datetime import datetime
import json
import sys

import psycopg
from psycopg.rows import dict_row

from local_postgres import CONFIG, PASSWORD_FILE


CASE_QUERY = """
SELECT case_id, institution_id, status, decision_code, approval_status,
       decision_submitted_at, approved_at
FROM efrm.case_master
WHERE institution_id = %s AND case_id = %s
"""


def read_case(institution_id, case_id):
    """Read only the requested institution's case using parameterized SQL."""
    with psycopg.connect(
        **CONFIG,
        password=PASSWORD_FILE.read_text(encoding="utf-8").strip(),
        connect_timeout=5,
        row_factory=dict_row,
        options="-c default_transaction_read_only=on -c statement_timeout=30000",
    ) as conn:
        return conn.execute(CASE_QUERY, (institution_id, case_id)).fetchone()


def check_eligibility(case, institution_id):
    """Pure Python decision: no SQL, file writes, LLM, or optimization here."""
    if case is None:
        reason = "CASE_NOT_FOUND_IN_INSTITUTION"
    elif case.get("institution_id") != institution_id:
        reason = "INSTITUTION_MISMATCH"
    elif case.get("status") != "CLOSED":
        reason = "CASE_NOT_CLOSED"
    elif case.get("approval_status") not in ("APPROVED", "NOT_REQUIRED"):
        reason = "APPROVAL_NOT_RESOLVED"
    elif not case.get("decision_code"):
        reason = "FINAL_DECISION_MISSING"
    elif not case.get("decision_submitted_at"):
        reason = "DECISION_TIMESTAMP_MISSING"
    elif case["approval_status"] == "APPROVED" and not case.get("approved_at"):
        reason = "APPROVAL_TIMESTAMP_MISSING"
    elif case["decision_code"] != "FALSE_POSITIVE":
        # GENUINE and any unknown codes do not trigger this initial lab policy.
        reason = "FINAL_DECISION_IS_NOT_FALSE_POSITIVE"
    else:
        reason = "ELIGIBLE_FALSE_POSITIVE_CASE"

    eligible = reason == "ELIGIBLE_FALSE_POSITIVE_CASE"
    return {
        "eligible": eligible,
        "reason": reason,
        "next_step": "TRACE_CASE_ALERTS" if eligible else "STOP_FOR_THIS_CASE",
    }


def synthetic_case(institution_id="KANJI"):
    """A made-up example, created in memory and never inserted into EFRM."""
    return {
        "case_id": "SYNTHETIC_FP_001",
        "institution_id": institution_id,
        "status": "CLOSED",
        "decision_code": "FALSE_POSITIVE",
        "approval_status": "NOT_REQUIRED",
        "decision_submitted_at": datetime(2026, 9, 3, 10, 0),
        "approved_at": None,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--institution", default="KANJI")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--case-id", type=int, help="Read this case from the local DB")
    mode.add_argument("--demo", action="store_true", help="Use an in-memory synthetic FP example")
    args = parser.parse_args()
    if args.demo:
        case = synthetic_case(args.institution)
        source = "SYNTHETIC_DEMO_NOT_DATABASE_EVIDENCE"
    else:
        case = read_case(args.institution, args.case_id)
        source = "LOCAL_DATABASE"
    report = {
        "source": source,
        "policy": "lesson_01_closed_false_positive_v1",
        "requested_institution": args.institution,
        "requested_case_id": case["case_id"] if args.demo else args.case_id,
        "case": case,
        "decision": check_eligibility(case, args.institution),
    }
    print(json.dumps(report, default=str, indent=2))
    # A normal skip is successful execution, not a broken program.
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

