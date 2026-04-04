#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${EXP_DIR}/../.." && pwd)"
CONFIG_PATH="${EXP_DIR}/config.json"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <base_commit|auto> [task_id...]" >&2
  exit 1
fi

BASE_COMMIT="$1"
shift

for required_cmd in claude jq python3 git bats; do
  if ! command -v "${required_cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${required_cmd}" >&2
    exit 1
  fi
done

if [ "$#" -gt 0 ]; then
  TASK_IDS=("$@")
else
  mapfile -t TASK_IDS < <(
    find "${EXP_DIR}/tasks" -mindepth 1 -maxdepth 1 -type d | sort | while read -r task_dir; do
      task_id="$(basename "${task_dir}")"
      if [ "${task_id}" = "TEMPLATE" ]; then
        continue
      fi
      task_json="${task_dir}/task.json"
      if [ -f "${task_json}" ] && [ "$(jq -r '.disabled // false' "${task_json}")" = "true" ]; then
        continue
      fi
      printf '%s\n' "${task_id}"
    done
  )
fi

if [ "${#TASK_IDS[@]}" -eq 0 ]; then
  echo "No task directories found under ${EXP_DIR}/tasks" >&2
  exit 1
fi

RUN_ID="$(date -u +"%Y%m%dT%H%M%SZ")-tri-arm"
RUN_DIR="${EXP_DIR}/runs/${RUN_ID}"
mkdir -p "${RUN_DIR}"
cp "${CONFIG_PATH}" "${RUN_DIR}/config.json"

cat > "${RUN_DIR}/scorecard.csv" <<'EOF'
task_id,arm,start_time,end_time,elapsed_minutes,clarification_questions,user_interventions,files_changed_count,lines_changed,patch_non_empty,allowed_paths_only,task_specific_tests_passed,hidden_tests_passed,repo_regression_tests_passed,acceptance_met,review_high_remaining,review_medium_remaining,review_low_remaining,failure_type,manual_fix_minutes_estimate,prompt_tokens,completion_tokens,total_cost_usd,base_commit,reviewer_model,notes
EOF

for task_id in "${TASK_IDS[@]}"; do
  task_json="${EXP_DIR}/tasks/${task_id}/task.json"
  if [ "$(jq -r '.disabled // false' "${task_json}")" = "true" ]; then
    echo "Skipping disabled task: ${task_id}" >&2
    continue
  fi
  task_base_commit="${BASE_COMMIT}"
  if [ "${BASE_COMMIT}" = "auto" ]; then
    task_base_commit="$(jq -r '.suggested_base_commit // empty' "${task_json}")"
    if [ -z "${task_base_commit}" ]; then
      echo "task ${task_id} is missing suggested_base_commit but run-experiment.sh was invoked with auto" >&2
      exit 1
    fi
  fi
  "${SCRIPT_DIR}/run-task.sh" "${RUN_DIR}" "${task_base_commit}" "${task_id}"
done

python3 "${SCRIPT_DIR}/render-summary.py" "${RUN_DIR}"

printf 'Run completed: %s\n' "${RUN_DIR}"
