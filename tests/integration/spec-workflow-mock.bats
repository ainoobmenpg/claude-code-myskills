#!/usr/bin/env bats
# spec-workflow-mock.bats
# Layer 3 mock E2E: spec workflow state transitions (draft -> review -> revise -> implement)

load '../helpers/test-common'

# ---------------------------------------------------------------------------
# Shared fixture builders
# ---------------------------------------------------------------------------

# Create a complete spec run directory with all files for normal flow.
# $1: base directory  $2: run_id
create_basic_spec_run() {
    local base="$1" run_id="$2"
    local run_dir
    run_dir=$(create_mock_run_dir "$base" "$run_id")

    # run-meta.json
    cat > "$run_dir/run-meta.json" <<META
{
  "run_id": "$run_id",
  "project_root": "$base",
  "created_at": "2026-04-01T10:00:00Z",
  "topic": "user-auth"
}
META

    # spec-draft.md (initial draft)
    cat > "$run_dir/spec-draft.md" <<'DRAFT'
# user-auth

## 概要
User authentication module.

## 目的
Provide secure login/logout.

## 利用者
End users and administrators.

## ユースケース
- UC1: User logs in
- UC2: User logs out

## 入出力
- Input: credentials
- Output: session token

## スコープ
### 範囲内
Authentication flow

### 範囲外
Authorization

## 受け入れ条件
- AC1: Login returns token on valid credentials
- AC2: Logout invalidates token
DRAFT

    # status.json: in_progress (will be updated during tests)
    cat > "$run_dir/status.json" <<'STATUS'
{
  "status": "in_progress",
  "progress": "Drafting specification",
  "updated_at": "2026-04-01T10:00:30Z"
}
STATUS

    echo "$run_dir"
}

# Create spec-review.json fixture (review result)
# $1: run_dir
create_spec_review_result() {
    local run_dir="$1"
    cat > "$run_dir/spec-review.json" <<'EOF'
{
  "version": 1,
  "run_id": "20260401-100000Z-user-auth",
  "created_at": "2026-04-01T10:05:00Z",
  "source": {"type": "spec", "value": "spec.md"},
  "summary": {
    "overall_quality": "medium",
    "headline": "Basic coverage but missing error handling",
    "finding_count": {"high": 1, "medium": 1, "low": 0}
  },
  "findings": [
    {
      "id": "F1",
      "severity": "high",
      "section": "完全性",
      "title": "Error handling missing",
      "detail": "No error handling for invalid credentials",
      "suggestion": "Add error cases to acceptance criteria"
    },
    {
      "id": "F2",
      "severity": "medium",
      "section": "明確性",
      "title": "Token format unspecified",
      "detail": "Session token format is not defined",
      "suggestion": "Specify JWT or opaque token"
    }
  ]
}
EOF
}

# Create a spec.md with all required sections
# $1: run_dir
create_valid_spec_md() {
    local run_dir="$1"
    cat > "$run_dir/spec.md" <<'SPEC'
# User Authentication

## 概要
User authentication module providing login/logout.

## 目的
Provide secure login/logout with error handling.

## 利用者
End users and administrators.

## ユースケース
- UC1: User logs in with valid credentials
- UC2: User logs in with invalid credentials (error)
- UC3: User logs out

## 入出力
- Input: credentials (username + password)
- Output: JWT session token

## スコープ
### 範囲内
Authentication flow, error handling

### 範囲外
Authorization, password reset

## 受け入れ条件
- AC1: Login returns JWT on valid credentials
- AC2: Login returns 401 on invalid credentials
- AC3: Logout invalidates token
SPEC
}

# Create a spec.md missing required sections
# $1: run_dir
create_incomplete_spec_md() {
    local run_dir="$1"
    cat > "$run_dir/spec.md" <<'SPEC'
# User Authentication

## 概要
User authentication module.

## 目的
Provide secure login/logout.
SPEC
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
# Normal flow: Draft phase
# ---------------------------------------------------------------------------

@test "draft: status.json goes in_progress -> completed; monitor detects completion" {
    local run_id="20260401-100000Z-user-auth"
    local run_dir
    run_dir=$(create_basic_spec_run "$TEST_TMPDIR" "$run_id")

    # Initially in_progress
    local status_file="$run_dir/status.json"
    [ -f "$status_file" ]
    run jq -r '.status' "$status_file"
    [ "$output" = "in_progress" ]

    # Simulate sub-agent completing: update status to completed
    local updated_status
    updated_status=$(jq '.status = "completed" | .progress = "Draft completed" | .updated_at = "2026-04-01T10:02:00Z"' "$status_file")
    echo "$updated_status" > "$status_file"

    # Monitor checks status
    run jq -r '.status' "$status_file"
    [ "$output" = "completed" ]

    # Monitor should find spec-draft.md exists
    [ -f "$run_dir/spec-draft.md" ]
}

# ---------------------------------------------------------------------------
# Normal flow: Review phase
# ---------------------------------------------------------------------------

@test "review: spec.md exists -> spec-review.json created; monitor detects completion" {
    local run_id="20260401-100000Z-user-auth"
    local run_dir
    run_dir=$(create_basic_spec_run "$TEST_TMPDIR" "$run_id")

    # Simulate draft completed: copy spec-draft.md -> spec.md
    cp "$run_dir/spec-draft.md" "$run_dir/spec.md"

    # Spec path resolution: spec.md preferred, spec-draft.md fallback
    local spec_path=""
    if [ -f "$run_dir/spec.md" ]; then
        spec_path="$run_dir/spec.md"
    elif [ -f "$run_dir/spec-draft.md" ]; then
        spec_path="$run_dir/spec-draft.md"
    fi
    [ -n "$spec_path" ]
    [ "$spec_path" = "$run_dir/spec.md" ]

    # Simulate review completion: create spec-review.json
    create_spec_review_result "$run_dir"

    # Verify review JSON structure (no status field - progress tracked in status.json)
    [ -f "$run_dir/spec-review.json" ]
    run jq -r '.source.type' "$run_dir/spec-review.json"
    [ "$output" = "spec" ]

    # Monitor: check that findings exist
    run jq '.findings | length' "$run_dir/spec-review.json"
    [ "$output" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Normal flow: Revise phase
# ---------------------------------------------------------------------------

@test "revise: spec-review.json findings applied to spec.md; backup spec-v1.md created" {
    local run_id="20260401-100000Z-user-auth"
    local run_dir
    run_dir=$(create_basic_spec_run "$TEST_TMPDIR" "$run_id")

    # Pre-conditions: spec.md and spec-review.json both exist
    cp "$run_dir/spec-draft.md" "$run_dir/spec.md"
    create_spec_review_result "$run_dir"

    [ -f "$run_dir/spec.md" ]
    [ -f "$run_dir/spec-review.json" ]

    # Simulate revise: backup original as spec-v1.md
    cp "$run_dir/spec.md" "$run_dir/spec-v1.md"
    [ -f "$run_dir/spec-v1.md" ]

    # Simulate revise: update spec.md with review findings
    create_valid_spec_md "$run_dir"

    # Verify spec.md now contains error handling (F1 fix)
    run grep -c "invalid credentials" "$run_dir/spec.md"
    [ "$output" -gt 0 ]

    # Verify spec.md now specifies JWT (F2 fix)
    run grep -c "JWT" "$run_dir/spec.md"
    [ "$output" -gt 0 ]

    # Verify backup preserved original
    run grep -c "invalid credentials" "$run_dir/spec-v1.md"
    [ "$output" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Normal flow: Implement phase
# ---------------------------------------------------------------------------

@test "implement: spec.md read -> impl-plan.md output path correct" {
    local run_id="20260401-100000Z-user-auth"
    local run_dir
    run_dir=$(create_basic_spec_run "$TEST_TMPDIR" "$run_id")

    # Pre-condition: spec.md with all required sections
    create_valid_spec_md "$run_dir"

    # Verify all required sections are present
    local required_sections="概要 目的 利用者 ユースケース 入出力 スコープ 受け入れ条件"
    for section in $required_sections; do
        run grep -q "## $section" "$run_dir/spec.md"
        [ "$status" -eq 0 ]
    done

    # Simulate implement: create impl-plan.md at correct output path
    local impl_plan_path="$run_dir/impl-plan.md"
    cat > "$impl_plan_path" <<'PLAN'
# Implementation Plan

## Overview
User authentication module implementation.

## File Structure
- src/auth.ts: Authentication logic
- src/session.ts: Session management

## Phase 1: Core Auth
- Implement login/logout
- AC: AC1, AC2, AC3

## Phase 2: Error Handling
- Invalid credential handling
- AC: AC2
PLAN

    # Verify output path matches spec
    [ -f "$impl_plan_path" ]
    run grep -q "Implementation Plan" "$impl_plan_path"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Abnormal flow: Review fails when no spec files
# ---------------------------------------------------------------------------

@test "review fails: neither spec.md nor spec-draft.md exists" {
    local run_id="20260401-100000Z-user-auth"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    # Create run-meta.json but no spec files
    cat > "$run_dir/run-meta.json" <<META
{
  "run_id": "$run_id",
  "project_root": "$TEST_TMPDIR",
  "created_at": "2026-04-01T10:00:00Z"
}
META

    # Spec path resolution: neither file exists
    local spec_path=""
    if [ -f "$run_dir/spec.md" ]; then
        spec_path="$run_dir/spec.md"
    elif [ -f "$run_dir/spec-draft.md" ]; then
        spec_path="$run_dir/spec-draft.md"
    fi

    # Both checks fail: spec_path is empty
    [ -z "$spec_path" ]
}

# ---------------------------------------------------------------------------
# Abnormal flow: Revise fails when spec-review.json missing
# ---------------------------------------------------------------------------

@test "revise fails: spec-review.json missing" {
    local run_id="20260401-100000Z-user-auth"
    local run_dir
    run_dir=$(create_basic_spec_run "$TEST_TMPDIR" "$run_id")

    # spec.md exists but spec-review.json does not
    cp "$run_dir/spec-draft.md" "$run_dir/spec.md"
    [ -f "$run_dir/spec.md" ]
    [ ! -f "$run_dir/spec-review.json" ]

    # Revise requires both files; missing spec-review.json is an error
    local has_spec=0 has_review=0
    [ -f "$run_dir/spec.md" ] && has_spec=1
    [ -f "$run_dir/spec-review.json" ] && has_review=1

    # Not both present -> cannot revise
    [ "$((has_spec + has_review))" -ne 2 ]
}

# ---------------------------------------------------------------------------
# Abnormal flow: Revise fails when spec.md missing
# ---------------------------------------------------------------------------

@test "revise fails: spec.md missing" {
    local run_id="20260401-100000Z-user-auth"
    local run_dir
    run_dir=$(create_basic_spec_run "$TEST_TMPDIR" "$run_id")

    # Create spec-review.json but no spec.md
    create_spec_review_result "$run_dir"
    [ ! -f "$run_dir/spec.md" ]
    [ -f "$run_dir/spec-review.json" ]

    # Revise requires both files; missing spec.md is an error
    local has_spec=0 has_review=0
    [ -f "$run_dir/spec.md" ] && has_spec=1
    [ -f "$run_dir/spec-review.json" ] && has_review=1

    # Not both present -> cannot revise
    [ "$((has_spec + has_review))" -ne 2 ]
}

# ---------------------------------------------------------------------------
# Abnormal flow: Implement detects missing required sections in spec.md
# ---------------------------------------------------------------------------

@test "implement error: spec.md missing required sections" {
    local run_id="20260401-100000Z-user-auth"
    local run_dir
    run_dir=$(create_basic_spec_run "$TEST_TMPDIR" "$run_id")

    # Create incomplete spec.md (only 概要 and 目的)
    create_incomplete_spec_md "$run_dir"

    # Check required sections
    local required_sections="利用者 ユースケース 入出力 スコープ 受け入れ条件"
    local missing=0
    for section in $required_sections; do
        if ! grep -q "## $section" "$run_dir/spec.md"; then
            missing=$((missing + 1))
        fi
    done

    # 5 sections should be missing
    [ "$missing" -eq 5 ]
}
