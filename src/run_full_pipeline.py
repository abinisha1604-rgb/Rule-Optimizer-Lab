"""Run the local rule-optimizer learning flow from one command.

The orchestrator runs the existing lesson scripts as separate read-only
processes and saves each report under one run directory. It is deliberately a
lab harness: it never activates a rule, writes to PostgreSQL, executes stored
metric SQL, or calls an external model.
"""

import argparse
from datetime import datetime
import json
from pathlib import Path
import re
import subprocess
import sys


SOURCE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SOURCE_DIR.parent
DEFAULT_SOURCE_SYSTEM = "CARD_TRANSACTION"
DEFAULT_MULTIPLIERS = "2,2.5,3,3.5,4"


class PipelineError(RuntimeError):
    """A step failed or returned an unusable report."""


class EligibilityStop(PipelineError):
    """The case was ineligible and the caller did not request lab continuation."""


def _json_from_output(text):
    """Extract the root JSON report from CLI output.

    Some lesson scripts put their status at the root, while the trace and
    eligibility reports keep it in a nested summary/case object.  Prefer the
    first complete report object so a nested ``status`` field is not mistaken
    for the whole report.
    """
    decoder = json.JSONDecoder()
    text = text or ""
    for index, character in enumerate(text):
        if character != "{":
            continue
        try:
            value, _ = decoder.raw_decode(text[index:])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and any(key in value for key in (
            "source", "status", "summary", "decision", "transaction_alerts"
        )):
            return value
    raise PipelineError("step output did not contain a JSON report")


def _report_status(report):
    """Return the completion/status field used by a lesson report."""
    if report.get("status"):
        return report["status"]
    summary = report.get("summary")
    if isinstance(summary, dict) and summary.get("status"):
        return summary["status"]
    if isinstance(report.get("decision"), dict):
        return "ELIGIBILITY_CHECK_COMPLETE"
    # Eligibility has no report-level status; its case status is still useful
    # in the progress line, while the decision below controls the gate.
    case = report.get("case")
    if isinstance(case, dict) and case.get("status"):
        return f"ELIGIBILITY_READ_{case['status']}"
    return "UNKNOWN_STATUS"


def _write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, default=str, indent=2) + "\n", encoding="utf-8")


def _read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PipelineError(f"could not read report {path}: {exc}") from exc


def _safe_name(value):
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", str(value)).strip("._") or "pipeline"


def _display_path(path):
    try:
        return str(Path(path).resolve().relative_to(PROJECT_ROOT))
    except ValueError:
        return str(path)


def select_rule(trace, requested_code=None, requested_version=None):
    """Select a trace-resolved rule deterministically for baseline replay."""
    candidates = []
    seen = set()
    for alert in trace.get("transaction_alerts") or []:
        for match in alert.get("rule_matches") or []:
            code = match.get("rule_code")
            version = match.get("recorded_rule_version")
            if (not code or version is None or
                    match.get("resolution_status") != "RULE_REFERENCE_RESOLVED_FOR_TRACE"):
                continue
            key = (str(code), int(version))
            if key in seen:
                continue
            seen.add(key)
            candidates.append({
                "rule_code": key[0],
                "version": key[1],
                "signal_code": match.get("signal_code"),
                "rule_master_id": match.get("rule_master_id"),
                "resolution_status": match.get("resolution_status"),
            })

    filtered = candidates
    if requested_code:
        filtered = [row for row in filtered if row["rule_code"] == requested_code]
    if requested_version is not None:
        filtered = [row for row in filtered if row["version"] == requested_version]
    if not filtered:
        requested = requested_code or "the first resolved rule"
        raise PipelineError(f"trace has no resolved match for {requested}")
    selected = dict(filtered[0])
    selected["available_trace_rules"] = candidates
    selected["selection_reason"] = (
        "EXPLICIT_RULE_ARGUMENT"
        if requested_code or requested_version is not None
        else "FIRST_RESOLVED_RULE_IN_TRACE"
    )
    return selected


def choose_runtime_event_ids(baseline, limit=3):
    """Choose one matched event and unresolved non-empty-history mismatches."""
    events = baseline.get("events") or []
    selected = []
    for event in events:
        if event.get("recorded_rule_match") is True:
            selected.append(event.get("transaction_master_id"))
            break
    mismatch_ids = set((baseline.get("summary") or {}).get("mismatch_event_ids") or [])
    for event in events:
        event_id = event.get("transaction_master_id")
        if event_id in mismatch_ids and (event.get("history_debit_count") or 0) > 0:
            if event_id not in selected:
                selected.append(event_id)
        if len(selected) >= limit:
            break
    for event in events:
        event_id = event.get("transaction_master_id")
        if event_id not in selected:
            selected.append(event_id)
        if len(selected) >= limit:
            break
    return [event_id for event_id in selected if event_id is not None][:limit]


def _run_step(run_dir, step_name, script_name, arguments, output_path=None):
    """Run one lesson script, save logs, and return its JSON report."""
    command = [sys.executable, str(SOURCE_DIR / script_name), *[str(item) for item in arguments]]
    logs_dir = run_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    completed = subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    (logs_dir / f"{step_name}.stdout.txt").write_text(completed.stdout or "", encoding="utf-8")
    (logs_dir / f"{step_name}.stderr.txt").write_text(completed.stderr or "", encoding="utf-8")
    if completed.returncode != 0:
        details = (completed.stderr or completed.stdout or "step returned a non-zero exit code").strip()
        raise PipelineError(f"{step_name} failed (exit {completed.returncode}): {details}")
    if output_path is not None:
        if not output_path.exists():
            raise PipelineError(f"{step_name} reported success but did not create {output_path}")
        return _read_json(output_path)
    return _json_from_output(completed.stdout)


def _record_step(steps, label, report, output_path):
    status = _report_status(report)
    steps.append({"step": label, "status": status, "output": _display_path(output_path)})
    print(f"[{len(steps):02d}] {label}: {status}")
    return report


def _run_pipeline(args):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run_id = _safe_name(args.run_id or f"case_{args.case_id}_{args.institution}_{timestamp}")
    output_root = Path(args.output_root)
    if not output_root.is_absolute():
        output_root = PROJECT_ROOT / output_root
    run_dir = output_root / run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    steps = []

    print(f"Pipeline run: {run_id}")
    print(f"Scope: institution={args.institution}, case_id={args.case_id}")

    eligibility_path = run_dir / "01_eligibility.json"
    eligibility = _run_step(
        run_dir,
        "01_eligibility",
        "step_03_case_trigger.py",
        ["--institution", args.institution, "--case-id", args.case_id],
    )
    _write_json(eligibility_path, eligibility)
    _record_step(steps, "Eligibility Check", eligibility, eligibility_path)
    eligible = (eligibility.get("decision") or {}).get("eligible") is True
    if not eligible and not args.continue_on_ineligible:
        summary = {
            "status": "PIPELINE_STOPPED_AT_ELIGIBILITY",
            "reason": (eligibility.get("decision") or {}).get("reason"),
            "run_id": run_id,
            "run_directory": _display_path(run_dir),
            "steps": steps,
            "checks": {"database_writes": "NONE", "pipeline_continued_after_ineligible": False},
            "next_step": "USE_A_FINALIZED_FALSE_POSITIVE_CASE_OR_ADD --continue-on-ineligible FOR_LAB_ONLY",
        }
        _write_json(run_dir / "pipeline_summary.json", summary)
        print(f"Pipeline stopped: {summary['reason']}")
        raise EligibilityStop(summary["reason"])
    if not eligible:
        print("  Warning: continuing after an ineligible case because --continue-on-ineligible was supplied.")

    trace_path = run_dir / "02_rule_trace.json"
    trace = _run_step(
        run_dir,
        "02_rule_trace",
        "step_04_trace_case.py",
        ["--institution", args.institution, "--case-id", args.case_id],
    )
    _write_json(trace_path, trace)
    _record_step(steps, "Rule Trace", trace, trace_path)
    selected_rule = select_rule(trace, args.rule_code, args.version)
    print(f"  Selected rule: {selected_rule['rule_code']} v{selected_rule['version']}")

    baseline_path = run_dir / "03_baseline_replay.json"
    baseline = _run_step(
        run_dir,
        "03_baseline_replay",
        "step_07_baseline_replay.py",
        [
            "--rule-code", selected_rule["rule_code"],
            "--version", selected_rule["version"],
            "--institution", args.institution,
            "--source-system", args.source_system,
            "--output", baseline_path,
        ],
        baseline_path,
    )
    _record_step(steps, "Baseline Replay", baseline, baseline_path)

    runtime_semantics_path = run_dir / "04_runtime_semantics.json"
    runtime_semantics = _run_step(
        run_dir,
        "04_runtime_semantics",
        "step_09_runtime_semantics.py",
        ["--baseline", baseline_path, "--output", runtime_semantics_path],
        runtime_semantics_path,
    )
    _record_step(steps, "Runtime Semantics (support)", runtime_semantics, runtime_semantics_path)

    runtime_selection_path = run_dir / "05_runtime_selection.json"
    runtime_event_ids = choose_runtime_event_ids(baseline)
    runtime_arguments = [
        "--baseline", baseline_path,
        "--institution", args.institution,
        "--source-system", args.source_system,
        "--output", runtime_selection_path,
    ]
    for event_id in runtime_event_ids:
        runtime_arguments.extend(["--event-id", event_id])
    runtime_selection = _run_step(
        run_dir,
        "05_runtime_selection",
        "step_10_runtime_selection.py",
        runtime_arguments,
        runtime_selection_path,
    )
    _record_step(steps, "Runtime Selection (support)", runtime_selection, runtime_selection_path)

    dataset_path = run_dir / "06_historical_dataset.json"
    dataset = _run_step(
        run_dir,
        "06_historical_dataset",
        "step_11_historical_dataset.py",
        [
            "--baseline", baseline_path,
            "--institution", args.institution,
            "--source-system", args.source_system,
            "--output", dataset_path,
        ],
        dataset_path,
    )
    _record_step(steps, "Labeled Historical Dataset", dataset, dataset_path)

    # Keep the snapshot at a short, stable sibling path.  Snapshot partition
    # keys are intentionally descriptive (institution/source/channel/date),
    # and nesting them under a long run directory can exceed Windows' path
    # limit.  The content hash in the snapshot ID still keeps runs immutable.
    snapshot_output_root = output_root.parent / "snapshots"
    snapshot_builder = _run_step(
        run_dir,
        "07_snapshot_builder",
        "step_15_snapshot_builder.py",
        ["--dataset", dataset_path, "--output-dir", snapshot_output_root, "--summary"],
    )
    snapshot_dir = Path(snapshot_builder.get("snapshot_directory", ""))
    if not snapshot_dir.is_absolute():
        snapshot_dir = PROJECT_ROOT / snapshot_dir
    snapshot_summary_path = run_dir / "07_snapshot_builder.json"
    _write_json(snapshot_summary_path, snapshot_builder)
    _record_step(steps, "Snapshot Builder", snapshot_builder, snapshot_summary_path)
    if not snapshot_dir.is_dir():
        raise PipelineError(f"snapshot builder did not create directory {snapshot_dir}")

    snapshot_read_path = run_dir / "08_snapshot_read.json"
    snapshot_read = _run_step(
        run_dir,
        "08_snapshot_read",
        "step_16_read_snapshot.py",
        [snapshot_dir, "--summary"],
    )
    _write_json(snapshot_read_path, snapshot_read)
    _record_step(steps, "Snapshot Read Check", snapshot_read, snapshot_read_path)

    candidate_path = run_dir / "09_candidate_search.json"
    candidate = _run_step(
        run_dir,
        "09_candidate_search",
        "step_12_candidate_search.py",
        [
            "--snapshot", snapshot_dir,
            "--multipliers", args.multipliers,
            "--current-multiplier", args.current_multiplier,
            "--output", candidate_path,
        ],
        candidate_path,
    )
    _record_step(steps, "Candidate Search", candidate, candidate_path)

    holdout_path = run_dir / "10_holdout_validation.json"
    holdout = _run_step(
        run_dir,
        "10_holdout_validation",
        "step_13_holdout_validation.py",
        [
            "--snapshot", snapshot_dir,
            "--multipliers", args.multipliers,
            "--current-multiplier", args.current_multiplier,
            "--output", holdout_path,
        ],
        holdout_path,
    )
    _record_step(steps, "Holdout Validation", holdout, holdout_path)

    reasoning_path = run_dir / "11_agent_reasoning.json"
    reasoning = _run_step(
        run_dir,
        "11_agent_reasoning",
        "step_14_agent_reasoning.py",
        [
            "--candidate-search", candidate_path,
            "--holdout-validation", holdout_path,
            "--runtime-semantics", runtime_semantics_path,
            "--runtime-selection", runtime_selection_path,
            "--output", reasoning_path,
        ],
        reasoning_path,
    )
    _record_step(steps, "Agent Reasoning", reasoning, reasoning_path)

    summary = {
        "status": "PIPELINE_COMPLETE",
        "run_id": run_id,
        "run_directory": _display_path(run_dir),
        "requested_case_id": args.case_id,
        "requested_institution": args.institution,
        "source_system": args.source_system,
        "eligibility": {
            "eligible": eligible,
            "reason": (eligibility.get("decision") or {}).get("reason"),
            "continued_after_ineligible": not eligible,
        },
        "selected_rule": selected_rule,
        "runtime_event_ids_inspected": runtime_event_ids,
        "steps": steps,
        "final_decision": {
            "status": (reasoning.get("decision") or {}).get("status"),
            "recommendation": (reasoning.get("decision") or {}).get("recommendation"),
            "recommendation_gate": reasoning.get("recommendation_gate"),
        },
        "checks": {
            "database_writes": "NONE",
            "stored_metric_sql_execution": "NOT_RUN",
            "network_calls": "NONE",
            "model_call": "NONE",
            "snapshot_directory": _display_path(snapshot_dir),
        },
        "next_step": "REVIEW_PIPELINE_SUMMARY_AND_AGENT_REASONING",
    }
    summary_path = run_dir / "pipeline_summary.json"
    _write_json(summary_path, summary)
    print(f"Pipeline complete. Summary: {_display_path(summary_path)}")
    print(f"Final recommendation status: {summary['final_decision']['status']}")
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case-id", type=int, required=True)
    parser.add_argument("--institution", required=True)
    parser.add_argument("--source-system", default=DEFAULT_SOURCE_SYSTEM)
    parser.add_argument("--rule-code", help="Optional rule code; otherwise use the first resolved trace rule")
    parser.add_argument("--version", type=int, help="Optional rule version paired with --rule-code")
    parser.add_argument("--multipliers", default=DEFAULT_MULTIPLIERS)
    parser.add_argument("--current-multiplier", default="3")
    parser.add_argument("--continue-on-ineligible", action="store_true",
                        help="Continue for lab inspection when the case is not a finalized false positive")
    parser.add_argument("--output-root", type=Path, default=Path("outputs/pipeline_runs"))
    parser.add_argument("--run-id", help="Optional readable run directory name")
    args = parser.parse_args()
    try:
        _run_pipeline(args)
        return 0
    except EligibilityStop:
        return 2
    except (OSError, PipelineError, ValueError) as exc:
        print(f"Pipeline failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
