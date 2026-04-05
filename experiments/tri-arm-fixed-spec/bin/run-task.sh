#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${EXP_DIR}/../.." && pwd)"

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <run_dir> <base_commit> <task_id>" >&2
  exit 1
fi

RUN_DIR="$1"
BASE_COMMIT="$2"
TASK_ID="$3"

CONFIG_PATH="${RUN_DIR}/config.json"
TASK_DIR="${EXP_DIR}/tasks/${TASK_ID}"
TASK_JSON="${TASK_DIR}/task.json"
RUN_TASK_DIR="${RUN_DIR}/${TASK_ID}"
SCORECARD_PATH="${RUN_DIR}/scorecard.csv"
RUN_SCHEMA_PATH="${EXP_DIR}/schema/run-output.json"
REVIEW_SCHEMA_PATH="${EXP_DIR}/schema/review-output.json"
PROMPT_DIRECT_PATH="${EXP_DIR}/prompts/direct.md"
PROMPT_FIXED_SPEC_PATH="${EXP_DIR}/prompts/fixed-spec.md"
PROMPT_SPEC_MD_PATH="${EXP_DIR}/prompts/spec-md.md"
PROMPT_REVIEW_PATH="${EXP_DIR}/prompts/review.md"

if [ ! -f "${CONFIG_PATH}" ]; then
  echo "Missing config snapshot: ${CONFIG_PATH}" >&2
  exit 1
fi

if [ ! -f "${TASK_JSON}" ]; then
  echo "Missing task.json: ${TASK_JSON}" >&2
  exit 1
fi

target_repo_root="$(jq -r '.repo_path // empty' "${TASK_JSON}")"
if [ -z "${target_repo_root}" ]; then
  target_repo_root="${REPO_ROOT}"
fi
if [ ! -d "${target_repo_root}" ]; then
  echo "Missing target repo path: ${target_repo_root}" >&2
  exit 1
fi
if ! git -C "${target_repo_root}" rev-parse --verify "${BASE_COMMIT}^{commit}" >/dev/null 2>&1; then
  echo "Invalid base commit ${BASE_COMMIT} for repo ${target_repo_root}" >&2
  exit 1
fi

mkdir -p "${RUN_TASK_DIR}"
mkdir -p "${RUN_DIR}/tasks/${TASK_ID}"
cp "${TASK_JSON}" "${RUN_DIR}/tasks/${TASK_ID}/task.json"
cp "${TASK_DIR}/brief.md" "${RUN_DIR}/tasks/${TASK_ID}/brief.md"
if [ -f "${TASK_DIR}/fixed-spec.md" ]; then
  cp "${TASK_DIR}/fixed-spec.md" "${RUN_DIR}/tasks/${TASK_ID}/fixed-spec.md"
fi
if [ -f "${TASK_DIR}/public-tests.sh" ]; then
  cp "${TASK_DIR}/public-tests.sh" "${RUN_DIR}/tasks/${TASK_ID}/public-tests.sh"
fi
if [ -f "${TASK_DIR}/allowed-paths.txt" ]; then
  cp "${TASK_DIR}/allowed-paths.txt" "${RUN_DIR}/tasks/${TASK_ID}/allowed-paths.txt"
fi

task_title="$(jq -r '.title' "${TASK_JSON}")"
benchmark_version="$(jq -r '.benchmark_version // "v1"' "${TASK_JSON}")"
time_budget_minutes="$(jq -r '.time_budget_minutes' "${TASK_JSON}")"
max_clarification_questions="$(jq -r '.max_clarification_questions' "${TASK_JSON}")"
allowed_paths_file_rel="$(jq -r '.allowed_paths_file // empty' "${TASK_JSON}")"
allowed_paths_file_abs=""
if [ -n "${allowed_paths_file_rel}" ]; then
  allowed_paths_file_abs="${REPO_ROOT}/${allowed_paths_file_rel}"
fi
if [ -n "${allowed_paths_file_abs}" ] && [ -f "${allowed_paths_file_abs}" ]; then
  allowed_paths_display="$(sed 's/^/- /' "${allowed_paths_file_abs}")"
else
  allowed_paths_display="$(jq -r '.allowed_files[]?' "${TASK_JSON}" | sed 's/^/- /')"
fi
review_paths="$(jq -r '.review_paths[]' "${TASK_JSON}" | sed 's/^/- /')"
acceptance_criteria="$(jq -r '.acceptance_criteria[]' "${TASK_JSON}" | sed 's/^/- /')"
public_test_command="$(jq -r '.public_test_command // .task_test_command' "${TASK_JSON}")"
task_test_command="${public_test_command}"
hidden_test_id="$(jq -r '.hidden_test_id // empty' "${TASK_JSON}")"
no_op_is_failure="$(jq -r '.no_op_is_failure // false' "${TASK_JSON}")"
wrong_files_is_failure="$(jq -r '.wrong_files_is_failure // false' "${TASK_JSON}")"
repo_test_command="$(jq -r '.repo_test_command_override // .repo_test_command // empty' "${TASK_JSON}")"
if [ -z "${repo_test_command}" ]; then
  repo_test_command="$(jq -r '.repo_test_command' "${CONFIG_PATH}")"
fi

csv_escape() {
  local raw="$1"
  raw="${raw//\"/\"\"}"
  printf '"%s"' "${raw}"
}

write_impl_prompt() {
  local prompt_kind="$1"
  local worktree="$2"
  local output_path="$3"

  if [ "${prompt_kind}" = "fixed_spec" ]; then
    cat "${PROMPT_FIXED_SPEC_PATH}" > "${output_path}"
  elif [ "${prompt_kind}" = "spec_md" ]; then
    cat "${PROMPT_SPEC_MD_PATH}" > "${output_path}"
  else
    cat "${PROMPT_DIRECT_PATH}" > "${output_path}"
  fi

  {
    printf '\n## Task Metadata\n\n'
    printf -- '- task_id: `%s`\n' "${TASK_ID}"
    printf -- '- title: `%s`\n' "${task_title}"
    printf -- '- time_budget_minutes: `%s`\n' "${time_budget_minutes}"
    printf -- '- max_clarification_questions: `%s`\n' "${max_clarification_questions}"
    printf -- '- base_commit: `%s`\n' "${BASE_COMMIT}"
    printf -- '- isolated_worktree: `%s`\n' "${worktree}"
    printf -- '- source_repo_root: `%s`\n' "${target_repo_root}"
    printf '\n## Allowed Paths\n\n%s\n' "${allowed_paths_display}"
    printf '\n## Acceptance Criteria\n\n%s\n' "${acceptance_criteria}"
    printf '\n## Task Brief\n\n'
    cat "${TASK_DIR}/brief.md"
    if [ "${prompt_kind}" = "fixed_spec" ]; then
      printf '\n\n## Fixed Spec\n\n'
      cat "${TASK_DIR}/fixed-spec.md"
    elif [ "${prompt_kind}" = "spec_md" ]; then
      printf '\n\n## Spec\n\n'
      cat "${TASK_DIR}/spec.md"
    fi
    printf '\n\n## Test Commands\n\n'
    printf -- '- public_task_specific: `%s`\n' "${public_test_command}"
    printf -- '- repo_regression: `%s`\n' "${repo_test_command}"
    printf -- '- hidden tests exist and are not shown to you\n'
    printf '\n## Execution Rules\n\n'
    printf -- '- Do not ask the user questions.\n'
    printf -- '- You are already running inside the isolated worktree `%s`.\n' "${worktree}"
    printf -- '- Do not `cd` to `%s`; inspect, edit, and test only in the current working directory.\n' "${target_repo_root}"
    printf -- '- Writing outside allowed paths will fail evaluation.\n'
    printf -- '- A no-op patch will fail evaluation.\n'
  } >> "${output_path}"
}

write_review_prompt() {
  local prompt_kind="$1"
  local arm_dir="$2"
  local worktree="$3"
  local output_path="$4"

  cat "${PROMPT_REVIEW_PATH}" > "${output_path}"
  {
    printf '\n## Review Context\n\n'
    printf -- '- task_id: `%s`\n' "${TASK_ID}"
    printf -- '- title: `%s`\n' "${task_title}"
    printf -- '- base_commit: `%s`\n' "${BASE_COMMIT}"
    printf -- '- isolated_worktree: `%s`\n' "${worktree}"
    printf -- '- source_repo_root: `%s`\n' "${target_repo_root}"
    printf '\n## Review Focus Paths\n\n%s\n' "${review_paths}"
    printf '\n## Acceptance Criteria\n\n%s\n' "${acceptance_criteria}"
    printf '\n## Task Brief\n\n'
    cat "${TASK_DIR}/brief.md"
    if [ "${prompt_kind}" = "fixed_spec" ] && [ -f "${TASK_DIR}/fixed-spec.md" ]; then
      printf '\n\n## Fixed Spec\n\n'
      cat "${TASK_DIR}/fixed-spec.md"
    elif [ "${prompt_kind}" = "spec_md" ] && [ -f "${TASK_DIR}/spec.md" ]; then
      printf '\n\n## Spec\n\n'
      cat "${TASK_DIR}/spec.md"
    fi
    printf '\n\n## Reviewer Instructions\n\n'
    printf -- '- Compare current worktree against `%s`.\n' "${BASE_COMMIT}"
    printf -- '- Inspect only changed files and their local context.\n'
    printf -- '- If no remaining issue exists, return zero counts.\n'
  } >> "${output_path}"
}

json_pick() {
  local file="$1"
  local expression="$2"
  jq -r "${expression}" "${file}" 2>/dev/null || true
}

collect_changed_paths() {
  local worktree="$1"
  local output_path="$2"

  {
    git -C "${worktree}" diff --name-only
    git -C "${worktree}" ls-files --others --exclude-standard
  } | sed '/^$/d' | sort -u > "${output_path}"
}

path_matches_allowed() {
  local rel_path="$1"
  local allow_file="$2"

  while IFS= read -r allowed_path || [ -n "${allowed_path}" ]; do
    allowed_path="${allowed_path%$'\r'}"
    [ -z "${allowed_path}" ] && continue
    case "${allowed_path}" in
      \#*) continue ;;
    esac
    if [ "${rel_path}" = "${allowed_path}" ]; then
      return 0
    fi
    case "${rel_path}" in
      "${allowed_path}/"*) return 0 ;;
    esac
    case "${allowed_path}" in
      */)
        case "${rel_path}" in
          "${allowed_path}"*) return 0 ;;
        esac
        ;;
    esac
  done < "${allow_file}"

  return 1
}

check_allowed_paths() {
  local changed_paths_file="$1"
  local allow_file="$2"
  local violations_file="$3"

  : > "${violations_file}"
  if [ ! -s "${changed_paths_file}" ]; then
    return 0
  fi

  while IFS= read -r changed_path || [ -n "${changed_path}" ]; do
    if ! path_matches_allowed "${changed_path}" "${allow_file}"; then
      printf '%s\n' "${changed_path}" >> "${violations_file}"
    fi
  done < "${changed_paths_file}"

  [ ! -s "${violations_file}" ]
}

write_diff_artifacts() {
  local worktree="$1"
  local diff_patch="$2"
  local diff_stat="$3"

  git -C "${worktree}" diff --binary > "${diff_patch}" || true
  git -C "${worktree}" diff --stat > "${diff_stat}" || true

  while IFS= read -r rel_path || [ -n "${rel_path}" ]; do
    [ -z "${rel_path}" ] && continue
    if git -C "${worktree}" ls-files --others --exclude-standard -- "${rel_path}" | grep -q .; then
      git -C "${worktree}" diff --binary --no-index -- /dev/null "${worktree}/${rel_path}" >> "${diff_patch}" || true
      printf 'untracked %s\n' "${rel_path}" >> "${diff_stat}"
    fi
  done < <(git -C "${worktree}" ls-files --others --exclude-standard)
}

compute_lines_changed() {
  local worktree="$1"
  local added=0
  local deleted=0
  local file_lines

  while IFS=$'\t' read -r add_count del_count _path; do
    [ -z "${add_count}" ] && continue
    if [ "${add_count}" = "-" ] || [ "${del_count}" = "-" ]; then
      continue
    fi
    added=$((added + add_count))
    deleted=$((deleted + del_count))
  done < <(git -C "${worktree}" diff --numstat)

  while IFS= read -r rel_path || [ -n "${rel_path}" ]; do
    [ -z "${rel_path}" ] && continue
    if git -C "${worktree}" ls-files --others --exclude-standard -- "${rel_path}" | grep -q .; then
      file_lines="$(wc -l < "${worktree}/${rel_path}" | tr -d ' ')"
      added=$((added + file_lines))
    fi
  done < <(git -C "${worktree}" ls-files --others --exclude-standard)

  printf '+%d/-%d' "${added}" "${deleted}"
}

run_claude_impl() {
  local worktree="$1"
  local model="$2"
  local prompt_path="$3"
  local output_json="$4"
  local stderr_log="$5"

  local -a cmd
  cmd=(claude -p --output-format json --json-schema "$(cat "${RUN_SCHEMA_PATH}")" --model "${model}")
  if [ "${MYSK_EXPERIMENT_SKIP_PERMISSIONS:-false}" = "true" ]; then
    cmd+=(--dangerously-skip-permissions)
  else
    cmd+=(--permission-mode acceptEdits)
  fi
  if [ -n "${MYSK_EXPERIMENT_MAX_BUDGET_USD:-}" ]; then
    cmd+=(--max-budget-usd "${MYSK_EXPERIMENT_MAX_BUDGET_USD}")
  fi
  local timeout_seconds="${MYSK_EXPERIMENT_CLAUDE_TIMEOUT_SECONDS:-180}"

  (
    cd "${worktree}"
    prompt_text="$(cat "${prompt_path}")"
    env \
      MYSK_TASK_DIR="${TASK_DIR}" \
      MYSK_WORKTREE="${worktree}" \
      MYSK_BASE_COMMIT="${BASE_COMMIT}" \
      MYSK_TARGET_REPO_ROOT="${target_repo_root}" \
      MYSK_ALLOWED_PATHS_FILE="${allowed_paths_file_abs}" \
      MYSK_REPO_TEST_COMMAND="${repo_test_command}" \
      timeout "${timeout_seconds}" "${cmd[@]}" "${prompt_text}" > "${output_json}" 2> "${stderr_log}"
  )
}

run_claude_review() {
  local worktree="$1"
  local model="$2"
  local prompt_path="$3"
  local output_json="$4"
  local stderr_log="$5"

  local -a cmd
  cmd=(claude -p --output-format json --json-schema "$(cat "${REVIEW_SCHEMA_PATH}")" --model "${model}")
  if [ "${MYSK_EXPERIMENT_SKIP_PERMISSIONS:-false}" = "true" ]; then
    cmd+=(--dangerously-skip-permissions)
  else
    cmd+=(--permission-mode acceptEdits)
  fi
  if [ -n "${MYSK_EXPERIMENT_MAX_BUDGET_USD:-}" ]; then
    cmd+=(--max-budget-usd "${MYSK_EXPERIMENT_MAX_BUDGET_USD}")
  fi
  local timeout_seconds="${MYSK_EXPERIMENT_CLAUDE_TIMEOUT_SECONDS:-180}"

  (
    cd "${worktree}"
    prompt_text="$(cat "${prompt_path}")"
    env \
      MYSK_TASK_DIR="${TASK_DIR}" \
      MYSK_WORKTREE="${worktree}" \
      MYSK_BASE_COMMIT="${BASE_COMMIT}" \
      MYSK_TARGET_REPO_ROOT="${target_repo_root}" \
      MYSK_ALLOWED_PATHS_FILE="${allowed_paths_file_abs}" \
      timeout "${timeout_seconds}" "${cmd[@]}" "${prompt_text}" > "${output_json}" 2> "${stderr_log}"
  )
}

write_skipped_review_json() {
  local output_json="$1"
  cat > "${output_json}" <<'EOF'
{
  "acceptance_met": true,
  "review_high_remaining": 0,
  "review_medium_remaining": 0,
  "review_low_remaining": 0,
  "failure_type": null,
  "summary": "review skipped by MYSK_EXPERIMENT_SKIP_REVIEW",
  "findings": []
}
EOF
}

append_score_row() {
  local row="$1"
  printf '%s\n' "${row}" >> "${SCORECARD_PATH}"
}

arm_count="$(jq '.arms | length' "${CONFIG_PATH}")"

for ((i=0; i<arm_count; i++)); do
  arm_id="$(jq -r ".arms[${i}].id" "${CONFIG_PATH}")"
  arm_label="$(jq -r ".arms[${i}].label" "${CONFIG_PATH}")"
  arm_model="$(jq -r ".arms[${i}].model" "${CONFIG_PATH}")"
  prompt_kind="$(jq -r ".arms[${i}].prompt_kind" "${CONFIG_PATH}")"
  review_model="$(jq -r '.review_model' "${CONFIG_PATH}")"
  skip_review="${MYSK_EXPERIMENT_SKIP_REVIEW:-false}"

  arm_dir="${RUN_TASK_DIR}/${arm_id}"
  worktree="${arm_dir}/worktree"
  mkdir -p "${arm_dir}"

  start_time="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  start_epoch="$(date +%s)"

  if [ "${prompt_kind}" = "fixed_spec" ] && [ ! -f "${TASK_DIR}/fixed-spec.md" ]; then
    echo "Missing fixed-spec.md for ${TASK_ID}" > "${arm_dir}/run.stderr.log"
    append_score_row "$(printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s' \
      "${TASK_ID}" \
      "${arm_id}" \
      "${start_time}" \
      "${start_time}" \
      "0" \
      "0" \
      "0" \
      "0" \
      "+0/-0" \
      "0" \
      "0" \
      "0" \
      "0" \
      "0" \
      "0" \
      "99" \
      "99" \
      "99" \
      "partial_implementation" \
      "30" \
      "" \
      "" \
      "" \
      "${BASE_COMMIT}" \
      "${review_model}" \
      "$(csv_escape "Missing fixed-spec.md for ${TASK_ID}")")"
    continue
  fi

  if [ "${prompt_kind}" = "spec_md" ] && [ ! -f "${TASK_DIR}/spec.md" ]; then
    echo "Missing spec.md for ${TASK_ID}" > "${arm_dir}/run.stderr.log"
    append_score_row "$(printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s' \
      "${TASK_ID}" \
      "${arm_id}" \
      "${start_time}" \
      "${start_time}" \
      "0" \
      "0" \
      "0" \
      "0" \
      "+0/-0" \
      "0" \
      "0" \
      "0" \
      "0" \
      "0" \
      "0" \
      "99" \
      "99" \
      "99" \
      "partial_implementation" \
      "30" \
      "" \
      "" \
      "" \
      "${BASE_COMMIT}" \
      "${review_model}" \
      "$(csv_escape "Missing spec.md for ${TASK_ID}")")"
    continue
  fi

  git -C "${target_repo_root}" worktree add --detach "${worktree}" "${BASE_COMMIT}" > "${arm_dir}/worktree-add.log" 2>&1

  prompt_path="${arm_dir}/prompt.md"
  write_impl_prompt "${prompt_kind}" "${worktree}" "${prompt_path}"

  run_json="${arm_dir}/run.json"
  run_stderr="${arm_dir}/run.stderr.log"

  impl_exit=0
  if ! run_claude_impl "${worktree}" "${arm_model}" "${prompt_path}" "${run_json}" "${run_stderr}"; then
    impl_exit=$?
  fi

  task_test_log="${arm_dir}/task-test.log"
  repo_test_log="${arm_dir}/repo-test.log"
  hidden_test_log="${arm_dir}/hidden-test.log"
  changed_paths_file="${arm_dir}/changed-paths.txt"
  allowed_violations_file="${arm_dir}/allowed-path-violations.txt"
  task_specific_tests_passed=0
  hidden_tests_passed=1
  hidden_test_failure_mode=""
  repo_regression_tests_passed=0

  collect_changed_paths "${worktree}" "${changed_paths_file}"
  patch_non_empty=0
  if [ -s "${changed_paths_file}" ]; then
    patch_non_empty=1
  fi

  allowed_paths_only=1
  if [ -n "${allowed_paths_file_abs}" ] && [ -f "${allowed_paths_file_abs}" ]; then
    if ! check_allowed_paths "${changed_paths_file}" "${allowed_paths_file_abs}" "${allowed_violations_file}"; then
      allowed_paths_only=0
    fi
  else
    : > "${allowed_violations_file}"
  fi

  if (
    cd "${worktree}"
    env \
      MYSK_TASK_ID="${TASK_ID}" \
      MYSK_TASK_DIR="${TASK_DIR}" \
      MYSK_TASK_RUN_DIR="${RUN_DIR}/tasks/${TASK_ID}" \
      MYSK_TARGET_REPO_ROOT="${target_repo_root}" \
      bash -lc "${public_test_command}"
  ) > "${task_test_log}" 2>&1; then
    task_specific_tests_passed=1
  fi

  if (
    cd "${worktree}"
    env \
      MYSK_TASK_ID="${TASK_ID}" \
      MYSK_TASK_DIR="${TASK_DIR}" \
      MYSK_TASK_RUN_DIR="${RUN_DIR}/tasks/${TASK_ID}" \
      MYSK_TARGET_REPO_ROOT="${target_repo_root}" \
      bash -lc "${repo_test_command}"
  ) > "${repo_test_log}" 2>&1; then
    repo_regression_tests_passed=1
  fi

  if [ "${benchmark_version}" = "v2" ] && [ -z "${hidden_test_id}" ]; then
    hidden_tests_passed=0
    hidden_test_failure_mode="infra"
    printf 'Missing hidden_test_id for benchmark_version=v2\n' > "${hidden_test_log}"
  elif [ -n "${hidden_test_id}" ]; then
    hidden_tests_passed=0
    hidden_test_root="${MYSK_HIDDEN_TEST_ROOT:-}"
    hidden_test_script=""
    if [ -n "${hidden_test_root}" ]; then
      hidden_test_script="${hidden_test_root}/${hidden_test_id}/hidden-tests.sh"
    fi
    if [ -z "${hidden_test_root}" ]; then
      hidden_test_failure_mode="infra"
      printf 'Missing MYSK_HIDDEN_TEST_ROOT for hidden_test_id=%s\n' "${hidden_test_id}" > "${hidden_test_log}"
    elif [ ! -f "${hidden_test_script}" ]; then
      hidden_test_failure_mode="infra"
      printf 'Missing hidden test script: %s\n' "${hidden_test_script}" > "${hidden_test_log}"
    elif (
      cd "${worktree}"
      env \
        MYSK_TASK_ID="${TASK_ID}" \
        MYSK_HIDDEN_TEST_ID="${hidden_test_id}" \
        MYSK_BASE_COMMIT="${BASE_COMMIT}" \
        MYSK_WORKTREE="${worktree}" \
        bash "${hidden_test_script}"
    ) > "${hidden_test_log}" 2>&1; then
      hidden_tests_passed=1
    else
      hidden_test_failure_mode="test"
    fi
  else
    printf 'Hidden tests not configured for this task.\n' > "${hidden_test_log}"
  fi

  diff_patch="${arm_dir}/diff.patch"
  diff_stat_path="${arm_dir}/diff.stat"
  write_diff_artifacts "${worktree}" "${diff_patch}" "${diff_stat_path}"

  files_changed_count="$(wc -l < "${changed_paths_file}" | tr -d ' ')"
  lines_changed="$(compute_lines_changed "${worktree}")"

  review_prompt_path="${arm_dir}/review-prompt.md"
  write_review_prompt "${prompt_kind}" "${arm_dir}" "${worktree}" "${review_prompt_path}"
  review_json="${arm_dir}/review.json"
  review_stderr="${arm_dir}/review.stderr.log"

  review_exit=0
  if [ "${skip_review}" = "true" ]; then
    write_skipped_review_json "${review_json}"
    printf 'review skipped by MYSK_EXPERIMENT_SKIP_REVIEW=true\n' > "${review_stderr}"
    review_model="skipped"
  else
    if ! run_claude_review "${worktree}" "${review_model}" "${review_prompt_path}" "${review_json}" "${review_stderr}"; then
      review_exit=$?
    fi
  fi

  end_time="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  end_epoch="$(date +%s)"
  elapsed_minutes="$(( (end_epoch - start_epoch + 59) / 60 ))"

  status="$(json_pick "${run_json}" '.status // .result.status // .data.status // "failed"')"
  clarification_questions="$(json_pick "${run_json}" '.clarification_questions // .result.clarification_questions // .data.clarification_questions // 0')"
  user_interventions="$(json_pick "${run_json}" '.user_interventions // .result.user_interventions // .data.user_interventions // 0')"
  run_summary="$(json_pick "${run_json}" '.summary // .result.summary // .data.summary // empty')"
  notes_joined="$(json_pick "${run_json}" '((.notes // .result.notes // .data.notes // []) | join(" | "))')"

  reviewer_acceptance_met="$(json_pick "${review_json}" '.acceptance_met // .result.acceptance_met // .data.acceptance_met // false')"
  review_high_remaining="$(json_pick "${review_json}" '.review_high_remaining // .result.review_high_remaining // .data.review_high_remaining // 99')"
  review_medium_remaining="$(json_pick "${review_json}" '.review_medium_remaining // .result.review_medium_remaining // .data.review_medium_remaining // 99')"
  review_low_remaining="$(json_pick "${review_json}" '.review_low_remaining // .result.review_low_remaining // .data.review_low_remaining // 99')"
  failure_type="$(json_pick "${review_json}" '.failure_type // .result.failure_type // .data.failure_type // empty')"
  review_summary="$(json_pick "${review_json}" '.summary // .result.summary // .data.summary // empty')"

  prompt_tokens="$(json_pick "${run_json}" '.usage.input_tokens // .result.usage.input_tokens // .metadata.usage.input_tokens // empty')"
  completion_tokens="$(json_pick "${run_json}" '.usage.output_tokens // .result.usage.output_tokens // .metadata.usage.output_tokens // empty')"
  total_cost_usd="$(json_pick "${run_json}" '.cost_usd // .result.cost_usd // .metadata.cost_usd // empty')"

  manual_fix_minutes_estimate=0
  if [ "${review_high_remaining}" != "0" ] || [ "${review_medium_remaining}" != "0" ]; then
    manual_fix_minutes_estimate=30
  fi

  acceptance_met_num=0
  if [ "${patch_non_empty}" = "1" ] \
    && [ "${allowed_paths_only}" = "1" ] \
    && [ "${task_specific_tests_passed}" = "1" ] \
    && [ "${hidden_tests_passed}" = "1" ] \
    && [ "${repo_regression_tests_passed}" = "1" ]; then
    acceptance_met_num=1
  fi

  if [ -z "${failure_type}" ]; then
    if [ "${no_op_is_failure}" = "true" ] && [ "${patch_non_empty}" = "0" ]; then
      failure_type="no_op"
    elif [ "${impl_exit}" -eq 124 ] || [ "${review_exit}" -eq 124 ]; then
      failure_type="timeout"
    elif [ "${wrong_files_is_failure}" = "true" ] && [ "${allowed_paths_only}" = "0" ]; then
      failure_type="wrong_files"
    elif [ "${hidden_test_failure_mode}" = "infra" ]; then
      failure_type="tool_error"
    elif [ "${task_specific_tests_passed}" = "1" ] && [ "${hidden_tests_passed}" = "0" ]; then
      failure_type="public_pass_hidden_fail"
    elif [ "${repo_regression_tests_passed}" = "0" ]; then
      failure_type="repo_regression_fail"
    elif [ "${impl_exit}" -ne 0 ] || [ "${review_exit}" -ne 0 ]; then
      failure_type="tool_error"
    fi
  fi

  if [ "${impl_exit}" -ne 0 ] && [ -z "${notes_joined}" ]; then
    notes_joined="implementation command exited ${impl_exit}"
  fi
  if [ "${review_exit}" -ne 0 ]; then
    if [ -n "${notes_joined}" ]; then
      notes_joined="${notes_joined} | review command exited ${review_exit}"
    else
      notes_joined="review command exited ${review_exit}"
    fi
  fi
  if [ "${status}" != "completed" ] && [ -n "${run_summary}" ]; then
    if [ -n "${notes_joined}" ]; then
      notes_joined="${notes_joined} | ${run_summary}"
    else
      notes_joined="${run_summary}"
    fi
  fi
  if [ -n "${review_summary}" ]; then
    if [ -n "${notes_joined}" ]; then
      notes_joined="${notes_joined} | review: ${review_summary}"
    else
      notes_joined="review: ${review_summary}"
    fi
  fi
  if [ "${reviewer_acceptance_met}" != "true" ] && [ -n "${reviewer_acceptance_met}" ]; then
    if [ -n "${notes_joined}" ]; then
      notes_joined="${notes_joined} | reviewer_acceptance=${reviewer_acceptance_met}"
    else
      notes_joined="reviewer_acceptance=${reviewer_acceptance_met}"
    fi
  fi
  if [ "${patch_non_empty}" = "0" ]; then
    if [ -n "${notes_joined}" ]; then
      notes_joined="${notes_joined} | no-op patch detected"
    else
      notes_joined="no-op patch detected"
    fi
  fi
  if [ "${allowed_paths_only}" = "0" ] && [ -s "${allowed_violations_file}" ]; then
    violations_joined="$(paste -sd ';' "${allowed_violations_file}")"
    if [ -n "${notes_joined}" ]; then
      notes_joined="${notes_joined} | disallowed paths: ${violations_joined}"
    else
      notes_joined="disallowed paths: ${violations_joined}"
    fi
  fi
  if [ "${hidden_tests_passed}" = "0" ] && [ -s "${hidden_test_log}" ]; then
    hidden_note="$(tr '\n' ' ' < "${hidden_test_log}" | sed 's/[[:space:]]\+/ /g' | sed 's/^ //; s/ $//')"
    if [ -n "${hidden_note}" ]; then
      if [ -n "${notes_joined}" ]; then
        notes_joined="${notes_joined} | hidden: ${hidden_note}"
      else
        notes_joined="hidden: ${hidden_note}"
      fi
    fi
  fi

  append_score_row "$(printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s' \
    "${TASK_ID}" \
    "${arm_id}" \
    "${start_time}" \
    "${end_time}" \
    "${elapsed_minutes}" \
    "${clarification_questions}" \
    "${user_interventions}" \
    "${files_changed_count}" \
    "${lines_changed}" \
    "${patch_non_empty}" \
    "${allowed_paths_only}" \
    "${task_specific_tests_passed}" \
    "${hidden_tests_passed}" \
    "${repo_regression_tests_passed}" \
    "${acceptance_met_num}" \
    "${review_high_remaining}" \
    "${review_medium_remaining}" \
    "${review_low_remaining}" \
    "${failure_type}" \
    "${manual_fix_minutes_estimate}" \
    "${prompt_tokens}" \
    "${completion_tokens}" \
    "${total_cost_usd}" \
    "${BASE_COMMIT}" \
    "${review_model}" \
    "$(csv_escape "${notes_joined}")")"

  printf '%s\n' "${arm_label}" > "${arm_dir}/arm-label.txt"
done
