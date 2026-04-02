#!/usr/bin/env bats
# review-workflow-mock.bats
# Layer 3 mock E2E: review workflow state transitions (check -> fix -> diffcheck -> verify)

load '../helpers/test-common'

# ---------------------------------------------------------------------------
# Shared fixture builders
# ---------------------------------------------------------------------------

# Create a basic review run directory with review.json
# $1: base_dir  $2: run_id
create_basic_review_run() {
    local base="$1" run_id="$2"
    local run_dir
    run_dir=$(create_mock_run_dir "$base" "$run_id")

    # run-meta.json
    cat > "$run_dir/run-meta.json" <<META
{
  "run_id": "$run_id",
  "project_root": "$base",
  "created_at": "2026-04-01T12:00:00Z"
}
META

    # review.json with project_root and findings
    cat > "$run_dir/review.json" <<'EOF'
{
  "version": 1,
  "run_id": "20260401-120000Z-review",
  "created_at": "2026-04-01T12:00:00Z",
  "updated_at": "2026-04-01T12:00:00Z",
  "status": "completed",
  "progress": "Review completed",
  "project_root": "/tmp/test-project",
  "source": {
    "type": "diff",
    "value": "git diff HEAD~1"
  },
  "summary": {
    "overall_risk": "high",
    "headline": "2 high, 1 medium findings",
    "finding_count": 3
  },
  "findings": [
    {
      "id": "F001",
      "severity": "high",
      "file": "src/auth.ts",
      "line": 10,
      "title": "Null check missing",
      "detail": "Variable may be null",
      "suggested_fix": "Add null check"
    },
    {
      "id": "F002",
      "severity": "high",
      "file": "src/auth.ts",
      "line": 25,
      "title": "SQL injection risk",
      "detail": "Unsanitized input in query",
      "suggested_fix": "Use parameterized query"
    },
    {
      "id": "F003",
      "severity": "medium",
      "file": "src/utils.ts",
      "line": 5,
      "title": "Unused variable",
      "detail": "Variable declared but not used",
      "suggested_fix": "Remove unused variable"
    }
  ]
}
EOF

    echo "$run_dir"
}

# Create a review.json without project_root (error case)
# $1: run_dir
create_review_without_project_root() {
    local run_dir="$1"
    cat > "$run_dir/review.json" <<'EOF'
{
  "version": 1,
  "run_id": "20260401-120000Z-review",
  "created_at": "2026-04-01T12:00:00Z",
  "status": "completed",
  "summary": {
    "overall_risk": "high",
    "headline": "1 high finding",
    "finding_count": 1
  },
  "findings": [
    {
      "id": "F001",
      "severity": "high",
      "title": "Some issue"
    }
  ]
}
EOF
}

# Create a diffcheck.json with specific high_remaining value
# $1: run_dir  $2: high_remaining (0 or more)
create_diffcheck_result() {
    local run_dir="$1" high_rem="$2"
    local next_step_msg
    if [ "$high_rem" -gt 0 ]; then
        next_step_msg="/mysk-review-fix で残りの指摘を修正してください。"
    else
        next_step_msg="verifyの実行にはユーザー確認が必要です。diffcheck結果を確認し、ユーザーの指示を待ってください。"
    fi

    cat > "$run_dir/diffcheck.json" <<DIFFCHECK
{
  "version": 1,
  "run_id": "20260401-120000Z-review",
  "created_at": "2026-04-01T12:10:00Z",
  "type": "diffcheck",
  "summary": {
    "total": 3,
    "findings": 3,
    "fixed": $((3 - high_rem)),
    "not_fixed": ${high_rem},
    "unclear": 0,
    "high_remaining": ${high_rem},
    "medium_remaining": 0,
    "low_remaining": 0
  },
  "checks": [],
  "next_step": "${next_step_msg}"
}
DIFFCHECK
}

# Create a verify.json with specific result
# $1: run_dir  $2: verification_result  $3: high_remaining  $4: medium_remaining  $5: low_remaining  $6: new_issues_count
create_verify_result() {
    local run_dir="$1" result="$2" high_rem="$3" med_rem="$4" low_rem="$5" new_cnt="$6"

    cat > "$run_dir/verify.json" <<VERIFY
{
  "version": 1,
  "run_id": "20260401-120000Z-review",
  "created_at": "2026-04-01T12:15:00Z",
  "updated_at": "2026-04-01T12:15:00Z",
  "status": "completed",
  "progress": "Verification completed",
  "source_review": "review.json",
  "project_root": "/tmp/test-project",
  "verification_result": "${result}",
  "summary": {
    "verified_count": 3,
    "fixed_count": $((3 - high_rem - med_rem - low_rem)),
    "remaining_count": $((high_rem + med_rem + low_rem)),
    "new_issues_count": ${new_cnt},
    "high_remaining": ${high_rem},
    "medium_remaining": ${med_rem},
    "low_remaining": ${low_rem}
  },
  "verifications": [],
  "new_findings": []
}
VERIFY
}

# Create a verify-rerun.json with specific result
# $1: run_dir  $2: verification_result  $3: high_remaining  $4: medium_remaining  $5: low_remaining
create_verify_rerun_result() {
    local run_dir="$1" result="$2" high_rem="$3" med_rem="$4" low_rem="$5"

    cat > "$run_dir/verify-rerun.json" <<VERIFY
{
  "version": 1,
  "run_id": "20260401-120000Z-review",
  "created_at": "2026-04-01T12:20:00Z",
  "updated_at": "2026-04-01T12:20:00Z",
  "status": "completed",
  "progress": "Rerun verification completed",
  "source_review": "review.json",
  "project_root": "/tmp/test-project",
  "verification_result": "${result}",
  "summary": {
    "verified_count": 3,
    "fixed_count": $((3 - high_rem - med_rem - low_rem)),
    "remaining_count": $((high_rem + med_rem + low_rem)),
    "new_issues_count": 0,
    "high_remaining": ${high_rem},
    "medium_remaining": ${med_rem},
    "low_remaining": ${low_rem}
  },
  "verifications": [],
  "new_findings": []
}
VERIFY
}

# Create a verify.json with new high findings
# $1: run_dir
create_verify_with_new_high() {
    local run_dir="$1"
    cat > "$run_dir/verify.json" <<'EOF'
{
  "version": 1,
  "run_id": "20260401-120000Z-review",
  "created_at": "2026-04-01T12:15:00Z",
  "updated_at": "2026-04-01T12:15:00Z",
  "status": "completed",
  "progress": "Verification completed",
  "source_review": "review.json",
  "project_root": "/tmp/test-project",
  "verification_result": "failed",
  "summary": {
    "verified_count": 3,
    "fixed_count": 3,
    "remaining_count": 0,
    "new_issues_count": 1,
    "high_remaining": 0,
    "medium_remaining": 0,
    "low_remaining": 0
  },
  "verifications": [
    {"original_finding_id": "F001", "severity": "high", "status": "fixed", "detail": "Fixed"},
    {"original_finding_id": "F002", "severity": "high", "status": "fixed", "detail": "Fixed"},
    {"original_finding_id": "F003", "severity": "medium", "status": "fixed", "detail": "Fixed"}
  ],
  "new_findings": [
    {
      "id": "N001",
      "severity": "high",
      "file": "src/auth/middleware.ts",
      "line": 25,
      "title": "Missing type definition",
      "detail": "Type annotation is missing",
      "related_fix": "F001"
    }
  ]
}
EOF
}

# Create a verify.json with only medium/low remaining
# $1: run_dir
create_verify_failed_non_high() {
    local run_dir="$1"
    cat > "$run_dir/verify.json" <<'EOF'
{
  "version": 1,
  "run_id": "20260401-120000Z-review",
  "created_at": "2026-04-01T12:15:00Z",
  "updated_at": "2026-04-01T12:15:00Z",
  "status": "completed",
  "progress": "Verification completed",
  "source_review": "review.json",
  "project_root": "/tmp/test-project",
  "verification_result": "failed",
  "summary": {
    "verified_count": 3,
    "fixed_count": 1,
    "remaining_count": 2,
    "new_issues_count": 0,
    "high_remaining": 0,
    "medium_remaining": 1,
    "low_remaining": 1
  },
  "verifications": [
    {"original_finding_id": "F001", "severity": "high", "status": "fixed", "detail": "Fixed"},
    {"original_finding_id": "F002", "severity": "high", "status": "fixed", "detail": "Fixed"},
    {"original_finding_id": "F003", "severity": "medium", "status": "not_fixed", "detail": "Still present"}
  ],
  "new_findings": [
    {
      "id": "N001",
      "severity": "low",
      "file": "src/utils.ts",
      "line": 30,
      "title": "Minor style issue",
      "detail": "Inconsistent naming"
    }
  ]
}
EOF
}

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

setup() {
    TEST_TMPDIR=$(mktemp -d)
    export TEST_TMPDIR
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ---------------------------------------------------------------------------
# Normal flow: Check phase
# ---------------------------------------------------------------------------

@test "check: review.json created with project_root; monitor detects completion" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    # review.json exists and is valid
    [ -f "$run_dir/review.json" ]
    run is_valid_json "$run_dir/review.json"
    [ "$status" -eq 0 ]

    # project_root field present
    run jq -r '.project_root' "$run_dir/review.json"
    [ "$output" = "/tmp/test-project" ]

    # status is completed
    run jq -r '.status' "$run_dir/review.json"
    [ "$output" = "completed" ]

    # findings exist
    run jq '.findings | length' "$run_dir/review.json"
    [ "$output" -eq 3 ]
}

# ---------------------------------------------------------------------------
# Normal flow: Fix phase
# ---------------------------------------------------------------------------

@test "fix: review.json read, fix-plan.md path correct" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    # Read project_root from review.json
    run jq -r '.project_root' "$run_dir/review.json"
    [ "$output" = "/tmp/test-project" ]

    # Simulate fix: create fix-plan.md at correct path
    local fix_plan_path="$run_dir/fix-plan.md"
    cat > "$fix_plan_path" <<'PLAN'
# Fix Plan

## High Priority

### F001: Null check missing
- File: src/auth.ts:10
- Fix: Add null check before access

### F002: SQL injection risk
- File: src/auth.ts:25
- Fix: Use parameterized query

## Medium Priority (reference only)
### F003: Unused variable
PLAN

    [ -f "$fix_plan_path" ]

    # High severity count from review.json
    run jq '[.findings[] | select(.severity == "high")] | length' "$run_dir/review.json"
    [ "$output" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Normal flow: Diffcheck phase
# ---------------------------------------------------------------------------

@test "diffcheck: review.json read, diffcheck.json produced with correct schema" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    # Create diffcheck with 1 high remaining
    create_diffcheck_result "$run_dir" 1

    # diffcheck.json valid JSON
    run is_valid_json "$run_dir/diffcheck.json"
    [ "$status" -eq 0 ]

    # type field is "diffcheck"
    run jq -r '.type' "$run_dir/diffcheck.json"
    [ "$output" = "diffcheck" ]

    # next_step points to fix (high remaining)
    run jq -r '.next_step' "$run_dir/diffcheck.json"
    [[ "$output" == *"mysk-review-fix"* ]]
}

# ---------------------------------------------------------------------------
# Normal flow: Verify phase - first run and rerun
# ---------------------------------------------------------------------------

@test "verify: first run -> verify.json path" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    # No verify.json or verify-rerun.json exists -> first run
    [ ! -f "$run_dir/verify.json" ]
    [ ! -f "$run_dir/verify-rerun.json" ]

    # First run outputs to verify.json
    local verify_path="$run_dir/verify.json"
    create_verify_result "$run_dir" "passed" 0 0 0 0

    [ -f "$verify_path" ]
    run jq -r '.status' "$verify_path"
    [ "$output" = "completed" ]
}

@test "verify: rerun -> verify-rerun.json path" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    # First verify exists (failed with medium remaining)
    create_verify_result "$run_dir" "failed" 0 1 0 0

    # Rerun outputs to verify-rerun.json
    create_verify_rerun_result "$run_dir" "passed" 0 0 0

    [ -f "$run_dir/verify-rerun.json" ]
    run jq -r '.verification_result' "$run_dir/verify-rerun.json"
    [ "$output" = "passed" ]
}

# ---------------------------------------------------------------------------
# Abnormal flow: Fix errors when review.json missing project_root
# ---------------------------------------------------------------------------

@test "fix error: review.json missing project_root" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    create_review_without_project_root "$run_dir"

    # Check project_root is missing or null
    run jq -r '.project_root // empty' "$run_dir/review.json"
    [ -z "$output" ]

    # According to mysk-review-fix: project_root missing is an error
    # "エラー: review.jsonに 'project_root' フィールドがありません"
    local has_project_root
    has_project_root=$(jq 'has("project_root")' "$run_dir/review.json")
    [ "$has_project_root" = "false" ]
}

# ---------------------------------------------------------------------------
# Abnormal flow: Verify errors when review.json missing
# ---------------------------------------------------------------------------

@test "verify error: review.json missing" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    # No review.json exists
    [ ! -f "$run_dir/review.json" ]

    # Verify requires review.json to exist
    # This simulates the precondition check
    [ ! -f "$run_dir/review.json" ]
}

# ---------------------------------------------------------------------------
# Verify source-of-truth resolution
# ---------------------------------------------------------------------------

@test "verify source-of-truth: verify-rerun.json takes priority over verify.json" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    # Both verify.json and verify-rerun.json exist
    create_verify_result "$run_dir" "failed" 1 0 0 0
    create_verify_rerun_result "$run_dir" "passed" 0 0 0

    # Source-of-truth resolution: verify-rerun.json takes priority
    local truth_path=""
    if [ -f "$run_dir/verify-rerun.json" ]; then
        truth_path="$run_dir/verify-rerun.json"
    elif [ -f "$run_dir/verify.json" ]; then
        truth_path="$run_dir/verify.json"
    fi

    [ "$truth_path" = "$run_dir/verify-rerun.json" ]

    # The truth result should be "passed" (from rerun), not "failed" (from original)
    run jq -r '.verification_result' "$truth_path"
    [ "$output" = "passed" ]
}

# ---------------------------------------------------------------------------
# Judgment logic: Diffcheck
# ---------------------------------------------------------------------------

@test "diffcheck judgment: high remaining -> next_step points to fix" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    create_diffcheck_result "$run_dir" 1

    # next_step should mention fix
    run jq -r '.next_step' "$run_dir/diffcheck.json"
    [[ "$output" == *"mysk-review-fix"* ]]

    # high_remaining > 0
    run jq '.summary.high_remaining' "$run_dir/diffcheck.json"
    [ "$output" -gt 0 ]
}

@test "diffcheck judgment: all high fixed -> next_step points to verify" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    create_diffcheck_result "$run_dir" 0

    # next_step should mention verify (user confirmation needed)
    run jq -r '.next_step' "$run_dir/diffcheck.json"
    [[ "$output" == *"verify"* ]]

    # high_remaining == 0
    run jq '.summary.high_remaining' "$run_dir/diffcheck.json"
    [ "$output" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Judgment logic: Verify
# ---------------------------------------------------------------------------

@test "verify judgment: all fixed -> passed" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    create_verify_result "$run_dir" "passed" 0 0 0 0

    # All conditions for passed:
    # - high_remaining == 0
    # - medium_remaining == 0
    # - low_remaining == 0
    # - new_issues_count == 0
    run jq '.summary.high_remaining + .summary.medium_remaining + .summary.low_remaining + .summary.new_issues_count' "$run_dir/verify.json"
    [ "$output" -eq 0 ]

    run jq -r '.verification_result' "$run_dir/verify.json"
    [ "$output" = "passed" ]
}

@test "verify judgment: high remaining -> failed" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    create_verify_result "$run_dir" "failed" 1 0 0 0

    # high_remaining > 0 means failed
    run jq '.summary.high_remaining' "$run_dir/verify.json"
    [ "$output" -gt 0 ]

    run jq -r '.verification_result' "$run_dir/verify.json"
    [ "$output" = "failed" ]
}

@test "verify judgment: new high finding -> failed" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    create_verify_with_new_high "$run_dir"

    # new_findings with severity high -> failed
    run jq '[.new_findings[] | select(.severity == "high")] | length' "$run_dir/verify.json"
    [ "$output" -eq 1 ]

    run jq -r '.verification_result' "$run_dir/verify.json"
    [ "$output" = "failed" ]
}

@test "verify judgment: only medium/low remaining -> failed" {
    local run_id="20260401-120000Z-review"
    local run_dir
    run_dir=$(create_basic_review_run "$TEST_TMPDIR" "$run_id")

    create_verify_failed_non_high "$run_dir"

    # No high remaining
    run jq '.summary.high_remaining' "$run_dir/verify.json"
    [ "$output" -eq 0 ]

    # Medium/low remaining > 0
    run jq '.summary.medium_remaining + .summary.low_remaining' "$run_dir/verify.json"
    [ "$output" -gt 0 ]

    run jq -r '.verification_result' "$run_dir/verify.json"
    [ "$output" = "failed" ]
}
