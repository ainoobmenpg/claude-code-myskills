#!/usr/bin/env bats
# monitor-logic.bats
# Layer 3 mock E2E: monitor logic for all 4 monitor types
#   - Draft monitor (spec-draft-monitor.md)
#   - Review monitor (spec-review-monitor.md)
#   - Check monitor (review-check-monitor.md)
#   - Verify monitor (review-verify-monitor.md)

load '../helpers/test-common'

# ---------------------------------------------------------------------------
# Helper: simulate monitor decision based on status.json content
# These functions mirror the logic in the actual monitor templates.
# ---------------------------------------------------------------------------

# Draft monitor logic (from spec-draft-monitor.md)
# Returns the action the monitor would take
simulate_draft_monitor() {
    local status_file="$1"

    if [ ! -f "$status_file" ]; then
        echo "no_action"
        return
    fi

    local status
    status=$(jq -r '.status // empty' "$status_file" 2>/dev/null)

    if [ -z "$status" ]; then
        echo "no_action"
        return
    fi

    case "$status" in
        completed)
            echo "cleanup_with_summary"
            ;;
        failed)
            echo "error_then_cleanup"
            ;;
        waiting_for_user)
            echo "message_no_cleanup"
            ;;
        in_progress)
            # Check timeout: updated_at more than 15 minutes ago
            local updated_at current_ts updated_ts diff_minutes
            updated_at=$(jq -r '.updated_at // empty' "$status_file" 2>/dev/null)
            if [ -n "$updated_at" ]; then
                current_ts=$(date -u +%s)
                # macOS: date -j, Linux: date -d
                updated_ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" +%s 2>/dev/null || date -u -d "$updated_at" +%s 2>/dev/null || echo "0")
                if [ "$updated_ts" != "0" ]; then
                    diff_minutes=$(( (current_ts - updated_ts) / 60 ))
                    if [ "$diff_minutes" -gt 15 ]; then
                        echo "timeout_warning"
                        return
                    fi
                fi
            fi
            echo "no_action"
            ;;
        *)
            echo "no_action"
            ;;
    esac
}

# Review monitor logic (from spec-review-monitor.md)
simulate_review_monitor() {
    local status_file="$1"

    if [ ! -f "$status_file" ]; then
        echo "no_action"
        return
    fi

    local status
    status=$(jq -r '.status // empty' "$status_file" 2>/dev/null)

    if [ -z "$status" ]; then
        echo "no_action"
        return
    fi

    case "$status" in
        completed)
            echo "summary_displayed_cleanup"
            ;;
        failed)
            echo "error_displayed_cleanup"
            ;;
        in_progress)
            # Check timeout
            local updated_at current_ts updated_ts diff_minutes
            updated_at=$(jq -r '.updated_at // empty' "$status_file" 2>/dev/null)
            if [ -n "$updated_at" ]; then
                current_ts=$(date -u +%s)
                # macOS: date -j, Linux: date -d
                updated_ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" +%s 2>/dev/null || date -u -d "$updated_at" +%s 2>/dev/null || echo "0")
                if [ "$updated_ts" != "0" ]; then
                    diff_minutes=$(( (current_ts - updated_ts) / 60 ))
                    if [ "$diff_minutes" -gt 15 ]; then
                        echo "timeout_warning"
                        return
                    fi
                fi
            fi
            echo "no_action"
            ;;
        *)
            echo "no_action"
            ;;
    esac
}

# Check monitor logic (from review-check-monitor.md)
simulate_check_monitor() {
    local review_json="$1"

    if [ ! -f "$review_json" ]; then
        echo "no_action"
        return
    fi

    # Check if status field exists
    local has_status
    has_status=$(jq 'has("status")' "$review_json" 2>/dev/null)

    if [ "$has_status" = "false" ]; then
        echo "error_missing_status_cleanup"
        return
    fi

    local status
    status=$(jq -r '.status // empty' "$review_json" 2>/dev/null)

    case "$status" in
        completed)
            echo "summary_displayed_cleanup"
            ;;
        failed)
            echo "error_displayed_cleanup"
            ;;
        *)
            echo "no_action"
            ;;
    esac
}

# Verify monitor termination logic (from review-verify-monitor.md + verify-schema.json)
# Returns the termination action based on verification_result
simulate_verify_termination() {
    local verify_json="$1"

    if [ ! -f "$verify_json" ]; then
        echo "no_action"
        return
    fi

    # Check if status field exists
    local has_status
    has_status=$(jq 'has("status")' "$verify_json" 2>/dev/null)

    if [ "$has_status" = "false" ]; then
        echo "error_missing_status_cleanup"
        return
    fi

    local status
    status=$(jq -r '.status // empty' "$verify_json" 2>/dev/null)

    if [ "$status" = "failed" ]; then
        echo "error_then_cleanup"
        return
    fi

    if [ "$status" != "completed" ]; then
        # in_progress or other: check timeout
        local updated_at current_ts updated_ts diff_minutes
        updated_at=$(jq -r '.updated_at // empty' "$verify_json" 2>/dev/null)
        if [ -n "$updated_at" ]; then
            current_ts=$(date -u +%s)
            updated_ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" +%s 2>/dev/null || echo "0")
            if [ "$updated_ts" != "0" ]; then
                diff_minutes=$(( (current_ts - updated_ts) / 60 ))
                if [ "$diff_minutes" -gt 15 ]; then
                    echo "timeout_warning"
                    return
                fi
            fi
        fi
        echo "no_action"
        return
    fi

    # status == "completed" -> apply termination logic from verify-schema.json
    # Determine verification_result with fallback
    local result
    result=$(jq -r '.verification_result // empty' "$verify_json" 2>/dev/null)

    if [ -z "$result" ]; then
        # Fallback determination per verify-schema.json priority
        local high_rem new_high
        high_rem=$(jq '.summary.high_remaining // 0' "$verify_json" 2>/dev/null)
        new_high=$(jq '[.new_findings[]? | select(.severity == "high")] | length' "$verify_json" 2>/dev/null)

        if [ "$high_rem" -gt 0 ] || [ "$new_high" -gt 0 ]; then
            result="failed"
        else
            local med_rem low_rem new_non_high
            med_rem=$(jq '.summary.medium_remaining // 0' "$verify_json" 2>/dev/null)
            low_rem=$(jq '.summary.low_remaining // 0' "$verify_json" 2>/dev/null)
            new_non_high=$(jq '[.new_findings[]? | select(.severity == "medium" or .severity == "low")] | length' "$verify_json" 2>/dev/null)

            if [ "$med_rem" -gt 0 ] || [ "$low_rem" -gt 0 ] || [ "$new_non_high" -gt 0 ]; then
                result="partially_passed"
            else
                result="passed"
            fi
        fi
    fi

    case "$result" in
        passed)
            echo "end"
            ;;
        failed)
            echo "error_end"
            ;;
        partially_passed)
            echo "ask_user"
            ;;
        *)
            echo "end"
            ;;
    esac
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
# Draft monitor tests (spec-draft-monitor.md)
# ===========================================================================

@test "draft monitor: status.json missing -> no action" {
    local run_id="20260401-100000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    # No status.json created
    local action
    action=$(simulate_draft_monitor "$run_dir/status.json")
    [ "$action" = "no_action" ]
}

@test "draft monitor: status=completed -> cleanup triggered" {
    local run_id="20260401-100000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/status.json" <<'EOF'
{"status": "completed", "progress": "Draft done", "updated_at": "2026-04-01T10:02:00Z"}
EOF

    local action
    action=$(simulate_draft_monitor "$run_dir/status.json")
    [ "$action" = "cleanup_with_summary" ]
}

@test "draft monitor: status=failed -> error + cleanup" {
    local run_id="20260401-100000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/status.json" <<'EOF'
{"status": "failed", "progress": "Out of tokens", "updated_at": "2026-04-01T10:01:00Z"}
EOF

    local action
    action=$(simulate_draft_monitor "$run_dir/status.json")
    [ "$action" = "error_then_cleanup" ]
}

@test "draft monitor: status=waiting_for_user -> message, no cleanup" {
    local run_id="20260401-100000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/status.json" <<'EOF'
{"status": "waiting_for_user", "progress": "Asking question", "updated_at": "2026-04-01T10:01:00Z"}
EOF

    local action
    action=$(simulate_draft_monitor "$run_dir/status.json")
    [ "$action" = "message_no_cleanup" ]
}

@test "draft monitor: status=in_progress + old updated_at -> timeout warning" {
    local run_id="20260401-100000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    # Create status with updated_at 20 minutes in the past
    local old_ts
    old_ts=$(date -u -v-20M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "20 minutes ago" +%Y-%m-%dT%H:%M:%SZ)
    cat > "$run_dir/status.json" <<STATUS
{"status": "in_progress", "progress": "Still working", "updated_at": "${old_ts}"}
STATUS

    local action
    action=$(simulate_draft_monitor "$run_dir/status.json")
    [ "$action" = "timeout_warning" ]
}

@test "draft monitor: status=in_progress + recent updated_at -> no action" {
    local run_id="20260401-100000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    # Create status with recent updated_at (1 minute ago)
    local recent_ts
    recent_ts=$(date -u -v-1M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "1 minute ago" +%Y-%m-%dT%H:%M:%SZ)
    cat > "$run_dir/status.json" <<STATUS
{"status": "in_progress", "progress": "Working", "updated_at": "${recent_ts}"}
STATUS

    local action
    action=$(simulate_draft_monitor "$run_dir/status.json")
    [ "$action" = "no_action" ]
}

# ===========================================================================
# Review monitor tests (spec-review-monitor.md)
# ===========================================================================

@test "review monitor: status=completed -> summary displayed, cleanup" {
    local run_id="20260401-100000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/status.json" <<'EOF'
{"status": "completed", "progress": "Review done", "updated_at": "2026-04-01T10:05:00Z"}
EOF

    local action
    action=$(simulate_review_monitor "$run_dir/status.json")
    [ "$action" = "summary_displayed_cleanup" ]
}

@test "review monitor: status=failed -> error displayed, cleanup" {
    local run_id="20260401-100000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/status.json" <<'EOF'
{"status": "failed", "progress": "Review error", "updated_at": "2026-04-01T10:05:00Z"}
EOF

    local action
    action=$(simulate_review_monitor "$run_dir/status.json")
    [ "$action" = "error_displayed_cleanup" ]
}

# ===========================================================================
# Check monitor tests (review-check-monitor.md)
# ===========================================================================

@test "check monitor: status=completed -> summary displayed, cleanup" {
    local run_id="20260401-120000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/review.json" <<'EOF'
{
  "status": "completed",
  "progress": "Review completed",
  "project_root": "/tmp/test",
  "findings": [{"id": "F001", "severity": "high", "title": "Issue"}]
}
EOF

    local action
    action=$(simulate_check_monitor "$run_dir/review.json")
    [ "$action" = "summary_displayed_cleanup" ]
}

@test "check monitor: missing status field -> error, cleanup" {
    local run_id="20260401-120000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/review.json" <<'EOF'
{
  "project_root": "/tmp/test",
  "findings": [{"id": "F001", "severity": "high", "title": "Issue"}]
}
EOF

    local action
    action=$(simulate_check_monitor "$run_dir/review.json")
    [ "$action" = "error_missing_status_cleanup" ]
}

# ===========================================================================
# Verify monitor tests (review-verify-monitor.md)
# ===========================================================================

@test "verify monitor: status=completed + passed -> end" {
    local run_id="20260401-120000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "progress": "Done",
  "verification_result": "passed",
  "summary": {
    "verified_count": 2,
    "fixed_count": 2,
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

    local action
    action=$(simulate_verify_termination "$run_dir/verify.json")
    [ "$action" = "end" ]
}

@test "verify monitor: status=completed + failed -> error, end" {
    local run_id="20260401-120000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "progress": "Done",
  "verification_result": "failed",
  "summary": {
    "verified_count": 2,
    "fixed_count": 1,
    "remaining_count": 1,
    "new_issues_count": 0,
    "high_remaining": 1,
    "medium_remaining": 0,
    "low_remaining": 0
  },
  "verifications": [],
  "new_findings": []
}
EOF

    local action
    action=$(simulate_verify_termination "$run_dir/verify.json")
    [ "$action" = "error_end" ]
}

@test "verify monitor: status=completed + partially_passed -> ask user" {
    local run_id="20260401-120000Z-test"
    local run_dir
    run_dir=$(create_mock_run_dir "$TEST_TMPDIR" "$run_id")

    cat > "$run_dir/verify.json" <<'EOF'
{
  "status": "completed",
  "progress": "Done",
  "verification_result": "partially_passed",
  "summary": {
    "verified_count": 2,
    "fixed_count": 1,
    "remaining_count": 1,
    "new_issues_count": 0,
    "high_remaining": 0,
    "medium_remaining": 1,
    "low_remaining": 0
  },
  "verifications": [],
  "new_findings": []
}
EOF

    local action
    action=$(simulate_verify_termination "$run_dir/verify.json")
    [ "$action" = "ask_user" ]
}
