#!/usr/bin/env python3

import csv
import json
import sys
from pathlib import Path
from typing import List, Dict, Any


def load_json(path: Path) -> Dict[str, Any]:
    with path.open() as fh:
        return json.load(fh)


def load_rows(path: Path) -> List[Dict[str, str]]:
    with path.open(newline="") as fh:
        return list(csv.DictReader(fh))


def as_int(value: str) -> int:
    if value in ("", None):
        return 0
    return int(value)


def render_summary(run_dirs: List[Path]) -> str:
    lines = []
    lines.append("# Practical Test Summary")
    lines.append("")
    lines.append(f"Comparing {len(run_dirs)} run(s)")
    lines.append("")

    # Collect data from each run
    runs_data = []
    for run_dir in run_dirs:
        results_file = run_dir / "results.json"
        if not results_file.exists():
            continue

        results = load_json(results_file)

        # Try to load review.json for findings count
        review_file = run_dir / "review.json"
        findings_count = "N/A"
        if review_file.exists():
            try:
                review = load_json(review_file)
                findings = review.get("findings", [])
                if findings:
                    high = sum(1 for f in findings if f.get("severity") == "high")
                    medium = sum(1 for f in findings if f.get("severity") == "medium")
                    low = sum(1 for f in findings if f.get("severity") == "low")
                    findings_count = f"H:{high} M:{medium} L:{low}"
                else:
                    findings_count = "0"
            except Exception:
                findings_count = "Error"

        # Try to load verify.json for verification result
        verify_file = run_dir / "verify.json"
        verify_result = "N/A"
        if verify_file.exists():
            try:
                verify = load_json(verify_file)
                verify_result = verify.get("verification_result", "N/A")
                # If verification_result is null, check status
                if verify_result is None:
                    status = verify.get("status", "")
                    if status == "completed":
                        verify_result = "completed"
                    elif status == "in_progress":
                        verify_result = "in_progress"
                    elif status == "failed":
                        verify_result = "failed"
            except Exception:
                verify_result = "Error"

        runs_data.append({
            "run_id": run_dir.name,
            "task_id": results.get("task_id", "unknown"),
            "status": results.get("status", "unknown"),
            "verify_result": verify_result,
            "findings_count": findings_count,
            "elapsed_minutes": results.get("elapsed_minutes", 0),
            "started_at": results.get("started_at", ""),
            "completed_at": results.get("completed_at", ""),
        })

    if not runs_data:
        lines.append("No valid runs found.")
        return "\n".join(lines)

    # Sort by completion time
    runs_data.sort(key=lambda x: x["completed_at"])

    # Task comparison table
    lines.append("## Task Comparison")
    lines.append("")
    lines.append("| Run ID | Task | Status | Verify | Findings | Elapsed (min) | Started | Completed |")
    lines.append("|--------|------|--------|--------|----------|---------------|---------|-----------|")

    for run in runs_data:
        lines.append(f"| {run['run_id']} | {run['task_id']} | {run['status']} | {run['verify_result']} | {run['findings_count']} | {run['elapsed_minutes']} | {run['started_at']} | {run['completed_at']} |")

    lines.append("")

    # Status summary
    passed = sum(1 for r in runs_data if r["status"] == "passed")
    failed = sum(1 for r in runs_data if r["status"] == "failed")

    lines.append("## Status Summary")
    lines.append("")
    lines.append(f"- **Passed**: {passed}")
    lines.append(f"- **Failed**: {failed}")
    lines.append("")

    # Detailed findings (placeholder for future enhancement)
    lines.append("## Detailed Findings")
    lines.append("")
    lines.append("Detailed findings analysis will be added in future versions.")
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 render-practical-summary.py <run_dir> [<run_dir>...]", file=sys.stderr)
        print("Output: Markdown summary to stdout", file=sys.stderr)
        sys.exit(1)

    run_dirs = [Path(p).resolve() for p in sys.argv[1:]]

    # Validate run directories
    for run_dir in run_dirs:
        if not run_dir.exists():
            print(f"Error: Run directory not found: {run_dir}", file=sys.stderr)
            sys.exit(1)

        results_file = run_dir / "results.json"
        if not results_file.exists():
            print(f"Warning: results.json not found in {run_dir}", file=sys.stderr)

    # Render and print summary to stdout
    summary = render_summary(run_dirs)
    print(summary)


if __name__ == "__main__":
    main()
