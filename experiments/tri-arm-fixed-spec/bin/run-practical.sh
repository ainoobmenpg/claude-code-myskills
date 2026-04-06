#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${EXP_DIR}/../.." && pwd)"

# Inline configuration
DEFAULT_MODEL="glm-4.7"
DEFAULT_TIME_MINUTES=30

# Slug generation (filesystem-safe)
slugify() {
  local raw="$1"
  local slug
  slug="$(printf '%s' "${raw}" | tr -c '[:alnum:]_-' '-' | tr -s '-' | sed 's/^-//;s/-$//')"
  if [ -z "${slug}" ]; then
    slug="unnamed-experiment"
  fi
  printf '%s\n' "${slug}"
}

usage() {
  echo "Usage: $0 <task_id>" >&2
  echo "Run a practical test fixture with isolated output directory." >&2
  exit 1
}

main() {
  local task_id="${1:-}"
  local timestamp slug run_dir task_dir start_time end_time

  if [ -z "${task_id}" ]; then
    usage
  fi

  task_dir="${EXP_DIR}/tasks/${task_id}"
  if [ ! -d "${task_dir}" ]; then
    echo "Error: Task directory not found: ${task_dir}" >&2
    exit 1
  fi

  timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
  slug="$(slugify "${task_id}")"
  run_dir="${EXP_DIR}/runs/${timestamp}-${slug}"

  mkdir -p "${run_dir}"

  # Store timestamps as strings for macOS compatibility
  start_time="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Copy task files to run directory
  cp -r "${task_dir}"/* "${run_dir}/"

  # Create run log
  {
    echo "Practical Test Run"
    echo "=================="
    echo "Task ID: ${task_id}"
    echo "Run ID: ${timestamp}-${slug}"
    echo "Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "Repository: ${REPO_ROOT}"
    echo ""
  } > "${run_dir}/run.log"

  # Run public tests (with CWD set to EXP_DIR)
  echo "Running public tests..."
  if ( cd "${EXP_DIR}" && bash "${task_dir}/public-tests.sh" ) >> "${run_dir}/run.log" 2>&1; then
    echo "Public tests: PASSED" >> "${run_dir}/run.log"
    test_status="passed"
  else
    echo "Public tests: FAILED" >> "${run_dir}/run.log"
    test_status="failed"
  fi

  end_time="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Calculate elapsed minutes (since we have timestamps, not epochs)
  # This is an approximation for display purposes
  start_seconds="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${start_time}" +%s 2>/dev/null || date -d "${start_time}" +%s)"
  end_seconds="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${end_time}" +%s 2>/dev/null || date -d "${end_time}" +%s)"
  elapsed_minutes=$(( (end_seconds - start_seconds) / 60 ))

  # Create results JSON
  cat > "${run_dir}/results.json" <<EOF
{
  "task_id": "${task_id}",
  "run_id": "${timestamp}-${slug}",
  "started_at": "${start_time}",
  "completed_at": "${end_time}",
  "elapsed_minutes": ${elapsed_minutes},
  "status": "${test_status}",
  "repository": "${REPO_ROOT}"
}
EOF

  # Output summary
  echo ""
  echo "Practical test completed: ${task_id}"
  echo "Run directory: runs/${timestamp}-${slug}"
  echo "Status: ${test_status}"
  echo "Elapsed: ${elapsed_minutes} minutes"
}

main "$@"
