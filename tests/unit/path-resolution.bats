#!/usr/bin/env bats
# path-resolution.bats - Tests for path resolution logic
# Extracted from: mysk-review-fix.md, mysk-review-diffcheck.md, mysk-spec-review.md
#
# Path resolution algorithm:
#   resolved_path = project_root + "/" + file
#
# Spec-review path resolution:
#   spec.md preferred over spec-draft.md
#   Falls back to spec-draft.md when spec.md missing
#   Errors when neither exists
#
# Implement-start path resolution:
#   fixed-spec.md preferred over spec.md
#   Falls back to spec.md when fixed-spec.md missing
#   Errors when neither exists

load '../helpers/test-common'
load '../helpers/fixture-loader'

# ---------------------------------------------------------------------------
# Helper: resolve file path (project_root + "/" + file)
# ---------------------------------------------------------------------------
resolve_file_path() {
  local project_root="$1"
  local file="$2"

  echo "${project_root}/${file}"
}

# ---------------------------------------------------------------------------
# Helper: find spec path (spec-review algorithm from spec-review.md)
# Returns the spec path, or "ERROR" if neither exists
# ---------------------------------------------------------------------------
find_spec_path() {
  local run_dir="$1"

  if [ -f "${run_dir}/spec.md" ]; then
    echo "${run_dir}/spec.md"
  elif [ -f "${run_dir}/spec-draft.md" ]; then
    echo "${run_dir}/spec-draft.md"
  else
    echo "ERROR"
    return 1
  fi
}

find_executor_spec_path() {
  local run_dir="$1"

  if [ -f "${run_dir}/fixed-spec.md" ]; then
    echo "${run_dir}/fixed-spec.md"
  elif [ -f "${run_dir}/spec.md" ]; then
    echo "${run_dir}/spec.md"
  else
    echo "ERROR"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Helper: extract project_root from review.json
# Returns project_root or "ERROR" if missing
# ---------------------------------------------------------------------------
extract_project_root() {
  local review_json="$1"
  local val

  val=$(jq -r '.project_root // empty' "$review_json" 2>/dev/null)
  if [ -z "$val" ]; then
    echo "ERROR"
    return 1
  fi
  echo "$val"
}

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------
setup() {
  TEST_TMPDIR="$(mktemp -d)"
  PROJECT_ROOT="${TEST_TMPDIR}/project"
  RUN_DIR="${TEST_TMPDIR}/run"
  mkdir -p "$PROJECT_ROOT"
  mkdir -p "$RUN_DIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ===========================================================================
# Test cases
# ===========================================================================

@test "project_root + / + file produces absolute path" {
  local resolved
  resolved=$(resolve_file_path "/test/project" "src/auth.ts")

  [ "$resolved" = "/test/project/src/auth.ts" ]
}

@test "multi-level relative paths work" {
  # Create nested directory structure
  mkdir -p "${PROJECT_ROOT}/src/auth/middleware"

  # Resolve a deeply nested path
  local resolved
  resolved=$(resolve_file_path "$PROJECT_ROOT" "src/auth/middleware/handler.ts")

  [ "$resolved" = "${PROJECT_ROOT}/src/auth/middleware/handler.ts" ]

  # Create the file and verify it exists
  touch "$resolved"
  [ -f "$resolved" ]
}

@test "spec-review prefers spec.md over spec-draft.md" {
  # Create both files
  touch "${RUN_DIR}/spec.md"
  touch "${RUN_DIR}/spec-draft.md"

  local spec_path
  spec_path=$(find_spec_path "$RUN_DIR")

  [ "$spec_path" = "${RUN_DIR}/spec.md" ]
}

@test "spec-review falls back to spec-draft.md when spec.md missing" {
  # Only create spec-draft.md
  touch "${RUN_DIR}/spec-draft.md"

  local spec_path
  spec_path=$(find_spec_path "$RUN_DIR")

  [ "$spec_path" = "${RUN_DIR}/spec-draft.md" ]
}

@test "spec-review errors when neither exists" {
  # RUN_DIR exists but has no spec files

  local spec_path
  spec_path=$(find_spec_path "$RUN_DIR") && status=0 || status=$?

  [ "$spec_path" = "ERROR" ]
  [ "$status" -ne 0 ]
}

@test "implement-start prefers fixed-spec.md over spec.md" {
  touch "${RUN_DIR}/fixed-spec.md"
  touch "${RUN_DIR}/spec.md"

  local spec_path
  spec_path=$(find_executor_spec_path "$RUN_DIR")

  [ "$spec_path" = "${RUN_DIR}/fixed-spec.md" ]
}

@test "implement-start falls back to spec.md when fixed-spec.md missing" {
  touch "${RUN_DIR}/spec.md"

  local spec_path
  spec_path=$(find_executor_spec_path "$RUN_DIR")

  [ "$spec_path" = "${RUN_DIR}/spec.md" ]
}

@test "implement-start errors when neither fixed-spec.md nor spec.md exists" {
  local spec_path
  spec_path=$(find_executor_spec_path "$RUN_DIR") && status=0 || status=$?

  [ "$spec_path" = "ERROR" ]
  [ "$status" -ne 0 ]
}

@test "review-fix errors when project_root missing from review.json" {
  # Create review.json without project_root
  cat > "${RUN_DIR}/review.json" << EOF
{
  "version": 1,
  "run_id": "test-run",
  "findings": []
}
EOF

  local result
  result=$(extract_project_root "${RUN_DIR}/review.json") && status=0 || status=$?

  [ "$result" = "ERROR" ]
  [ "$status" -ne 0 ]
}

@test "review-fix extracts project_root when present" {
  cat > "${RUN_DIR}/review.json" << EOF
{
  "version": 1,
  "run_id": "test-run",
  "project_root": "${PROJECT_ROOT}",
  "findings": []
}
EOF

  local result
  result=$(extract_project_root "${RUN_DIR}/review.json")

  [ "$result" = "$PROJECT_ROOT" ]
}

@test "path resolution with file from finding" {
  # Simulate full path resolution as done in review-fix/diffcheck
  cat > "${RUN_DIR}/review.json" << EOF
{
  "version": 1,
  "project_root": "${PROJECT_ROOT}",
  "findings": [
    {"id": "F001", "file": "src/main.ts", "line": 10}
  ]
}
EOF

  local project_root
  project_root=$(extract_project_root "${RUN_DIR}/review.json")
  [ "$project_root" = "$PROJECT_ROOT" ]

  local file
  file=$(jq -r '.findings[0].file' "${RUN_DIR}/review.json")

  local resolved
  resolved=$(resolve_file_path "$project_root" "$file")

  [ "$resolved" = "${PROJECT_ROOT}/src/main.ts" ]

  # Create the file to verify existence check
  mkdir -p "${PROJECT_ROOT}/src"
  touch "$resolved"
  [ -f "$resolved" ]
}

@test "verify source-of-truth: verify-rerun.json preferred over verify.json" {
  # Create both files
  echo '{"verification_result": "passed", "v": "rerun"}' > "${RUN_DIR}/verify-rerun.json"
  echo '{"verification_result": "failed", "v": "first"}' > "${RUN_DIR}/verify.json"

  # source-of-truth resolution (from verify-schema.json usage_notes)
  local truth_path
  if [ -f "${RUN_DIR}/verify-rerun.json" ]; then
    truth_path="${RUN_DIR}/verify-rerun.json"
  elif [ -f "${RUN_DIR}/verify.json" ]; then
    truth_path="${RUN_DIR}/verify.json"
  fi

  [ "$truth_path" = "${RUN_DIR}/verify-rerun.json" ]

  local result
  result=$(jq -r '.v' "$truth_path")
  [ "$result" = "rerun" ]
}

@test "verify source-of-truth: verify.json when verify-rerun.json absent" {
  echo '{"verification_result": "failed", "v": "first"}' > "${RUN_DIR}/verify.json"

  local truth_path
  if [ -f "${RUN_DIR}/verify-rerun.json" ]; then
    truth_path="${RUN_DIR}/verify-rerun.json"
  elif [ -f "${RUN_DIR}/verify.json" ]; then
    truth_path="${RUN_DIR}/verify.json"
  fi

  [ "$truth_path" = "${RUN_DIR}/verify.json" ]

  local result
  result=$(jq -r '.v' "$truth_path")
  [ "$result" = "first" ]
}
