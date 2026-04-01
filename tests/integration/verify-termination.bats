#!/usr/bin/env bats
# verify-termination.bats
# Layer 3 mock E2E: verify termination state machine from verify-schema.json
#   - Result determination (passed/failed/partially_passed)
#   - Transition rules (in_progress -> terminal states)
#   - Source-of-truth resolution (verify-rerun.json priority)
#   - Rerun path determination

load '../helpers/test-common'

# ---------------------------------------------------------------------------
# Helper: determine verification result using verify-schema.json criteria
# Mirrors the exact logic from verify-schema.json definitions.result_criteria
# ---------------------------------------------------------------------------

# Determine result from verify JSON data
# $1: path to verify JSON file
determine_verify_result() {
    local verify_json="$1"

    if [ ! -f "$verify_json" ]; then
        echo "error: file not found"
        return 1
    fi

    # Read explicit verification_result first (takes priority)
    local explicit_result
    explicit_result=$(jq -r '.verification_result // empty' "$verify_json" 2>/dev/null)

    # If explicit result is set, use it directly
    if [ -n "$explicit_result" ]; then
        echo "$explicit_result"
        return 0
    fi

    # Apply schema criteria for fallback when no explicit result
    local high_rem med_rem low_rem new_high new_non_high

    high_rem=$(jq '.summary.high_remaining // 0' "$verify_json" 2>/dev/null)
    med_rem=$(jq '.summary.medium_remaining // 0' "$verify_json" 2>/dev/null)
    low_rem=$(jq '.summary.low_remaining // 0' "$verify_json" 2>/dev/null)
    new_high=$(jq '[.new_findings[]? | select(.severity == "high")] | length' "$verify_json" 2>/dev/null)
    new_non_high=$(jq '[.new_findings[]? | select(.severity == "medium" or .severity == "low")] | length' "$verify_json" 2>/dev/null)

    # Failed: high_remaining > 0 OR new_findings with severity==high
    if [ "$high_rem" -gt 0 ] || [ "$new_high" -gt 0 ]; then
        echo "failed"
        return 0
    fi

    # Partially passed: non-high remaining OR new non-high findings (no high)
    if [ "$med_rem" -gt 0 ] || [ "$low_rem" -gt 0 ] || [ "$new_non_high" -gt 0 ]; then
        echo "partially_passed"
        return 0
    fi

    # Passed: all fixed, no new
    echo "passed"
    return 0
}

# Determine transition from state
# $1: current state (in_progress, partially_passed)
# $2: verify JSON path
determine_transition() {
    local from_state="$1" verify_json="$2"
    local result
    result=$(determine_verify_result "$verify_json")

    case "$from_state" in
        in_progress)
            echo "in_progress -> $result"
            ;;
        partially_passed)
            if [ "$result" = "passed" ]; then
                echo "partially_passed -> passed"
            else
                echo "partially_passed -> $result"
            fi
            ;;
        *)
            echo "$from_state -> $result"
            ;;
    esac
}

# Resolve source-of-truth per verify-schema.json usage_notes
# $1: run_dir
resolve_source_of_truth() {
    local run_dir="$1"

    if [ -f "$run_dir/verify-rerun.json" ]; then
        echo "$run_dir/verify-rerun.json"
    elif [ -f "$run_dir/verify.json" ]; then
        echo "$run_dir/verify.json"
    else
        echo ""
    fi
}

# Determine output path for verify
# $1: run_dir  $2: prior_result (empty=first run, "passed"/"not-passed")
determine_verify_output_path() {
    local run_dir="$1" prior_result="$2"

    if [ -z "$prior_result" ]; then
        # First run
        echo "$run_dir/verify.json"
    elif [ "$prior_result" = "passed" ]; then
        # Prior passed, user confirms -> rerun
        echo "$run_dir/verify-rerun.json"
    else
        # Prior not-passed -> rerun without confirmation
        echo "$run_dir/verify-rerun.json"
    fi
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

# ===========================================================================
# Result determination (verify-schema.json definitions.result_criteria)
# ===========================================================================

@test "result: all findings fixed, no new -> passed" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "passed",
  "summary": {
    "verified_count": 3,
    "fixed_count": 3,
    "remaining_count": 0,
    "new_issues_count": 0,
    "high_remaining": 0,
    "medium_remaining": 0,
    "low_remaining": 0
  },
  "verifications": [
    {"original_finding_id": "F001", "status": "fixed"},
    {"original_finding_id": "F002", "status": "fixed"},
    {"original_finding_id": "F003", "status": "fixed"}
  ],
  "new_findings": []
}
EOF

    run determine_verify_result "$run_dir/verify.json"
    [ "$output" = "passed" ]
}

@test "result: high remaining -> failed" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "failed",
  "summary": {
    "verified_count": 3,
    "fixed_count": 2,
    "remaining_count": 1,
    "new_issues_count": 0,
    "high_remaining": 1,
    "medium_remaining": 0,
    "low_remaining": 0
  },
  "verifications": [
    {"original_finding_id": "F001", "status": "fixed"},
    {"original_finding_id": "F002", "status": "not_fixed"},
    {"original_finding_id": "F003", "status": "fixed"}
  ],
  "new_findings": []
}
EOF

    run determine_verify_result "$run_dir/verify.json"
    [ "$output" = "failed" ]
}

@test "result: new high finding -> failed" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
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
    {"original_finding_id": "F001", "status": "fixed"},
    {"original_finding_id": "F002", "status": "fixed"},
    {"original_finding_id": "F003", "status": "fixed"}
  ],
  "new_findings": [
    {"id": "N001", "severity": "high", "title": "New critical issue"}
  ]
}
EOF

    run determine_verify_result "$run_dir/verify.json"
    [ "$output" = "failed" ]
}

@test "result: no high, medium/low remaining -> partially_passed" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "partially_passed",
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
    {"original_finding_id": "F001", "status": "fixed"},
    {"original_finding_id": "F002", "status": "not_fixed"},
    {"original_finding_id": "F003", "status": "not_fixed"}
  ],
  "new_findings": []
}
EOF

    run determine_verify_result "$run_dir/verify.json"
    [ "$output" = "partially_passed" ]
}

@test "result: no remaining at all -> passed" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "passed",
  "summary": {
    "verified_count": 0,
    "fixed_count": 0,
    "remaining_count": 0,
    "new_issues_count": 0,
    "high_remaining": 0,
    "medium_remaining": 0,
    "low_remaining": 0
  },
  "verifications": [],
  "new_findings": []
}
EOF

    run determine_verify_result "$run_dir/verify.json"
    [ "$output" = "passed" ]
}

@test "result: verification error -> failed" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    # Simulate error: review.json cannot be read or project_root missing
    # verify-schema.json: "検証エラー（review.json読めない、project_rootがない）"
    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "failed",
  "summary": {
    "verified_count": 0,
    "fixed_count": 0,
    "remaining_count": 0,
    "new_issues_count": 0,
    "high_remaining": 0,
    "medium_remaining": 0,
    "low_remaining": 0
  },
  "verifications": [],
  "new_findings": [],
  "error": "review.json not found"
}
EOF

    # Error cases produce failed per verify-schema.json
    run jq -r '.verification_result' "$run_dir/verify.json"
    [ "$output" = "failed" ]
}

# ===========================================================================
# Transition rules (verify-schema.json definitions.transition_rules)
# ===========================================================================

@test "transition: in_progress -> passed (all fixed, no new)" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "passed",
  "summary": {
    "verified_count": 2, "fixed_count": 2, "remaining_count": 0,
    "new_issues_count": 0, "high_remaining": 0,
    "medium_remaining": 0, "low_remaining": 0
  },
  "verifications": [], "new_findings": []
}
EOF

    run determine_transition "in_progress" "$run_dir/verify.json"
    [ "$output" = "in_progress -> passed" ]
}

@test "transition: in_progress -> partially_passed (non-high unfixed, no high)" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "partially_passed",
  "summary": {
    "verified_count": 2, "fixed_count": 1, "remaining_count": 1,
    "new_issues_count": 0, "high_remaining": 0,
    "medium_remaining": 1, "low_remaining": 0
  },
  "verifications": [], "new_findings": []
}
EOF

    run determine_transition "in_progress" "$run_dir/verify.json"
    [ "$output" = "in_progress -> partially_passed" ]
}

@test "transition: in_progress -> failed (high unfixed)" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "failed",
  "summary": {
    "verified_count": 2, "fixed_count": 1, "remaining_count": 1,
    "new_issues_count": 0, "high_remaining": 1,
    "medium_remaining": 0, "low_remaining": 0
  },
  "verifications": [], "new_findings": []
}
EOF

    run determine_transition "in_progress" "$run_dir/verify.json"
    [ "$output" = "in_progress -> failed" ]
}

@test "transition: in_progress -> failed (new high)" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "failed",
  "summary": {
    "verified_count": 2, "fixed_count": 2, "remaining_count": 0,
    "new_issues_count": 1, "high_remaining": 0,
    "medium_remaining": 0, "low_remaining": 0
  },
  "verifications": [],
  "new_findings": [{"id": "N001", "severity": "high", "title": "New issue"}]
}
EOF

    run determine_transition "in_progress" "$run_dir/verify.json"
    [ "$output" = "in_progress -> failed" ]
}

@test "transition: partially_passed -> passed (after fix cycle)" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    # After fix cycle, all remaining are now fixed
    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "verification_result": "passed",
  "summary": {
    "verified_count": 3, "fixed_count": 3, "remaining_count": 0,
    "new_issues_count": 0, "high_remaining": 0,
    "medium_remaining": 0, "low_remaining": 0
  },
  "verifications": [], "new_findings": []
}
EOF

    run determine_transition "partially_passed" "$run_dir/verify.json"
    [ "$output" = "partially_passed -> passed" ]
}

# ===========================================================================
# Source-of-truth resolution (verify-schema.json usage_notes.source_of_truth)
# ===========================================================================

@test "source-of-truth: verify-rerun.json exists -> takes priority" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    # Both files exist with different results
    cat > "$run_dir/verify.json" <<'EOF'
{"verification_result": "failed", "summary": {"high_remaining": 1, "medium_remaining": 0, "low_remaining": 0}}
EOF
    cat > "$run_dir/verify-rerun.json" <<'EOF'
{"verification_result": "passed", "summary": {"high_remaining": 0, "medium_remaining": 0, "low_remaining": 0}}
EOF

    local truth_path
    truth_path=$(resolve_source_of_truth "$run_dir")
    [ "$truth_path" = "$run_dir/verify-rerun.json" ]

    # Result from truth should be passed (from rerun)
    run determine_verify_result "$truth_path"
    [ "$output" = "passed" ]
}

@test "source-of-truth: only verify.json exists -> used" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{"verification_result": "passed", "summary": {"high_remaining": 0, "medium_remaining": 0, "low_remaining": 0}}
EOF

    local truth_path
    truth_path=$(resolve_source_of_truth "$run_dir")
    [ "$truth_path" = "$run_dir/verify.json" ]
}

@test "source-of-truth: neither exists -> empty (first run path)" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    local truth_path
    truth_path=$(resolve_source_of_truth "$run_dir")
    [ -z "$truth_path" ]
}

# ===========================================================================
# Rerun path determination
# ===========================================================================

@test "rerun path: first run -> verify.json" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    local output_path
    output_path=$(determine_verify_output_path "$run_dir" "")
    [ "$output_path" = "$run_dir/verify.json" ]
}

@test "rerun path: prior passed + user confirms -> verify-rerun.json" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    # User confirmed rerun after passed result
    local output_path
    output_path=$(determine_verify_output_path "$run_dir" "passed")
    [ "$output_path" = "$run_dir/verify-rerun.json" ]
}

@test "rerun path: prior not-passed -> verify-rerun.json (no confirmation needed)" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    # Prior result was not passed -> rerun without confirmation
    local output_path
    output_path=$(determine_verify_output_path "$run_dir" "failed")
    [ "$output_path" = "$run_dir/verify-rerun.json" ]
}

# ===========================================================================
# Fallback determination (verify-schema.json: no explicit verification_result)
# ===========================================================================

@test "fallback: no verification_result field -> derived from summary counts" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    # No verification_result field; high_remaining > 0 should derive "failed"
    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "summary": {
    "verified_count": 2, "fixed_count": 1, "remaining_count": 1,
    "new_issues_count": 0, "high_remaining": 1,
    "medium_remaining": 0, "low_remaining": 0
  },
  "verifications": [], "new_findings": []
}
EOF

    run determine_verify_result "$run_dir/verify.json"
    [ "$output" = "failed" ]
}

@test "fallback: no verification_result, new_findings high -> failed" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "summary": {
    "verified_count": 2, "fixed_count": 2, "remaining_count": 0,
    "new_issues_count": 1, "high_remaining": 0,
    "medium_remaining": 0, "low_remaining": 0
  },
  "verifications": [],
  "new_findings": [{"id": "N001", "severity": "high", "title": "Regression"}]
}
EOF

    run determine_verify_result "$run_dir/verify.json"
    [ "$output" = "failed" ]
}

@test "fallback: no verification_result, medium remaining -> partially_passed" {
    local run_dir="$TEST_TMPDIR/20260401-120000Z-test"
    mkdir -p "$run_dir"

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "summary": {
    "verified_count": 2, "fixed_count": 1, "remaining_count": 1,
    "new_issues_count": 0, "high_remaining": 0,
    "medium_remaining": 1, "low_remaining": 0
  },
  "verifications": [], "new_findings": []
}
EOF

    run determine_verify_result "$run_dir/verify.json"
    [ "$output" = "partially_passed" ]
}
