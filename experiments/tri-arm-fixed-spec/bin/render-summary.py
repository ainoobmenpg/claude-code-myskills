#!/usr/bin/env python3

import csv
import json
import sys
from pathlib import Path


def load_json(path: Path):
    with path.open() as fh:
        return json.load(fh)


def load_rows(path: Path):
    with path.open(newline="") as fh:
        return list(csv.DictReader(fh))


def as_int(value: str) -> int:
    if value in ("", None):
        return 0
    return int(value)


def as_float(value: str) -> float:
    if value in ("", None):
        return 0.0
    return float(value)


def row_int(row, key: str, default: int = 0) -> int:
    value = row.get(key)
    if value in ("", None):
        return default
    return as_int(value)


def discover_tasks(run_dir: Path):
    tasks_dir = run_dir / "tasks"
    tasks = []
    for task_dir in sorted(tasks_dir.iterdir()):
        if not task_dir.is_dir():
            continue
        task_json = task_dir / "task.json"
        if not task_json.exists():
            continue
        data = load_json(task_json)
        tasks.append(data)
    return tasks


def row_map(rows):
    data = {}
    for row in rows:
        data[(row["task_id"], row["arm"])] = row
    return data


def all_green(row):
    return (
        row_int(row, "patch_non_empty", 1) == 1
        and row_int(row, "allowed_paths_only", 1) == 1
        and row_int(row, "task_specific_tests_passed", 0) == 1
        and row_int(row, "hidden_tests_passed", 1) == 1
        and row_int(row, "repo_regression_tests_passed", 0) == 1
        and row_int(row, "acceptance_met", 0) == 1
        and row_int(row, "review_high_remaining", 99) == 0
        and row_int(row, "review_medium_remaining", 99) == 0
    )


def metric_cell(row):
    return (
        f"patch={row.get('patch_non_empty', '1')}, "
        f"allow={row.get('allowed_paths_only', '1')}, "
        f"task={row.get('task_specific_tests_passed', '')}, "
        f"hidden={row.get('hidden_tests_passed', '1')}, "
        f"repo={row.get('repo_regression_tests_passed', '')}, "
        f"accept={row.get('acceptance_met', '')}, "
        f"H={row.get('review_high_remaining', '')}, "
        f"M={row.get('review_medium_remaining', '')}"
    )


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <run_dir>", file=sys.stderr)
        return 1

    run_dir = Path(sys.argv[1]).resolve()
    config = load_json(run_dir / "config.json")
    rows = load_rows(run_dir / "scorecard.csv")
    tasks = discover_tasks(run_dir)
    rows_by_key = row_map(rows)
    arms = config["arms"]

    summary_path = run_dir / "summary.md"

    arm_totals = {}
    for arm in arms:
        arm_id = arm["id"]
        arm_rows = [r for r in rows if r["arm"] == arm_id]
        arm_totals[arm_id] = {
            "label": arm["label"],
            "all_green": sum(1 for row in arm_rows if all_green(row)),
            "elapsed_minutes": sum(row_int(row, "elapsed_minutes", 0) for row in arm_rows),
            "clarification_questions": sum(row_int(row, "clarification_questions", 0) for row in arm_rows),
            "user_interventions": sum(row_int(row, "user_interventions", 0) for row in arm_rows),
            "review_high_remaining": sum(row_int(row, "review_high_remaining", 99) for row in arm_rows),
            "review_medium_remaining": sum(row_int(row, "review_medium_remaining", 99) for row in arm_rows),
            "review_low_remaining": sum(row_int(row, "review_low_remaining", 99) for row in arm_rows),
            "patch_non_empty": sum(row_int(row, "patch_non_empty", 1) for row in arm_rows),
            "allowed_paths_only": sum(row_int(row, "allowed_paths_only", 1) for row in arm_rows),
            "task_specific_tests_passed": sum(row_int(row, "task_specific_tests_passed", 0) for row in arm_rows),
            "hidden_tests_passed": sum(row_int(row, "hidden_tests_passed", 1) for row in arm_rows),
            "repo_regression_tests_passed": sum(row_int(row, "repo_regression_tests_passed", 0) for row in arm_rows),
            "acceptance_met": sum(row_int(row, "acceptance_met", 0) for row in arm_rows),
            "total_cost_usd": sum(as_float(row.get("total_cost_usd", "")) for row in arm_rows),
        }

    ranked = sorted(
        arm_totals.items(),
        key=lambda item: (
            -item[1]["all_green"],
            -(item[1]["patch_non_empty"] + item[1]["allowed_paths_only"] + item[1]["hidden_tests_passed"]),
            item[1]["review_high_remaining"] + item[1]["review_medium_remaining"],
            item[1]["elapsed_minutes"],
            item[1]["clarification_questions"] + item[1]["user_interventions"],
        ),
    )

    best_arm = ranked[0][0]
    tied = [
        arm_id
        for arm_id, metrics in arm_totals.items()
        if (
            metrics["all_green"],
            metrics["patch_non_empty"] + metrics["allowed_paths_only"] + metrics["hidden_tests_passed"],
            -(metrics["review_high_remaining"] + metrics["review_medium_remaining"]),
            -metrics["elapsed_minutes"],
            -(metrics["clarification_questions"] + metrics["user_interventions"]),
        )
        == (
            arm_totals[best_arm]["all_green"],
            arm_totals[best_arm]["patch_non_empty"] + arm_totals[best_arm]["allowed_paths_only"] + arm_totals[best_arm]["hidden_tests_passed"],
            -(arm_totals[best_arm]["review_high_remaining"] + arm_totals[best_arm]["review_medium_remaining"]),
            -arm_totals[best_arm]["elapsed_minutes"],
            -(arm_totals[best_arm]["clarification_questions"] + arm_totals[best_arm]["user_interventions"]),
        )
    ]

    if arm_totals[best_arm]["all_green"] == 0:
        recommendation = "No successful arm"
    elif len(tied) == 1:
        recommendation = arm_totals[best_arm]["label"]
    else:
        recommendation = "No clear winner"

    lines = []
    lines.append("# 3-arm Experiment Summary")
    lines.append("")
    lines.append("## Overview")
    lines.append("")
    lines.append("| Item | Value |")
    lines.append("|------|-------|")
    lines.append(f"| experiment_id | {config['experiment_id']} |")
    lines.append(f"| run_dir | `{run_dir}` |")
    lines.append(f"| task_count | {len(tasks)} |")
    lines.append(f"| recommendation | {recommendation} |")
    lines.append("")
    lines.append("## Arms")
    lines.append("")
    lines.append("| Arm | Model | Prompt Kind |")
    lines.append("|-----|-------|-------------|")
    for arm in arms:
      lines.append(f"| {arm['label']} | `{arm['model']}` | `{arm['prompt_kind']}` |")
    lines.append("")
    lines.append("## Per-task Results")
    lines.append("")
    lines.append("| Task | " + " | ".join(arm["label"] for arm in arms) + " |")
    lines.append("|------|" + "|".join(["---"] * len(arms)) + "|")
    for task in tasks:
        cells = []
        for arm in arms:
            row = rows_by_key.get((task["task_id"], arm["id"]))
            if row is None:
                cells.append("missing")
            else:
                cells.append(metric_cell(row))
        lines.append(f"| {task['task_id']} | " + " | ".join(cells) + " |")
    lines.append("")
    lines.append("## Aggregate Metrics")
    lines.append("")
    lines.append("| Arm | all_green_tasks | patch_non_empty | allowed_paths_only | hidden_tests_passed | elapsed_minutes | clarification_questions | user_interventions | high_remaining | medium_remaining |")
    lines.append("|-----|-----------------|-----------------|--------------------|---------------------|-----------------|-------------------------|--------------------|----------------|------------------|")
    for arm in arms:
        metrics = arm_totals[arm["id"]]
        lines.append(
            f"| {metrics['label']} | {metrics['all_green']} | {metrics['patch_non_empty']} | "
            f"{metrics['allowed_paths_only']} | {metrics['hidden_tests_passed']} | {metrics['elapsed_minutes']} | "
            f"{metrics['clarification_questions']} | {metrics['user_interventions']} | "
            f"{metrics['review_high_remaining']} | {metrics['review_medium_remaining']} |"
        )
    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- `all_green_tasks` means patch is non-empty, changed paths stay within scope, visible tests pass, hidden tests pass, repo regression passes, acceptance passes, and remaining high/medium review findings are zero.")
    lines.append("- Recommendation is computed by: all_green_tasks desc, patch+allowed+hidden desc, remaining high+medium asc, elapsed_minutes asc, questions+interventions asc.")
    lines.append("- If your CLI returns token/cost metadata, they remain in `scorecard.csv` for downstream analysis.")
    lines.append("")

    summary_path.write_text("\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
