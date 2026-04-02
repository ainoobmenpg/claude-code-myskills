#!/usr/bin/env bats
# status-state-machine.bats - Tests for status state machine
# Extracted from: monitor templates (spec-draft-monitor.md, review-check-monitor.md,
#   review-verify-monitor.md)
#
# Valid statuses: in_progress, waiting_for_user, completed, failed
# Timeout: 30 minutes

load '../helpers/test-common'
load '../helpers/fixture-loader'

# ---------------------------------------------------------------------------
# Helper: check status validity
# ---------------------------------------------------------------------------
is_valid_status() {
  local status="$1"
  case "$status" in
    in_progress|waiting_for_user|completed|failed)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Helper: check if status.json exists (monitor ignores non-existent)
# ---------------------------------------------------------------------------
status_file_exists() {
  local status_file="$1"
  [ -f "$status_file" ]
}

# ---------------------------------------------------------------------------
# Helper: determine action from status
# Returns: cleanup, error_cleanup, message_only, none, timeout
# ---------------------------------------------------------------------------
determine_action() {
  local status_file="$1"

  # Non-existent file -> do nothing
  if [ ! -f "$status_file" ]; then
    echo "none"
    return 0
  fi

  local status
  status=$(jq -r '.status // empty' "$status_file" 2>/dev/null)

  case "$status" in
    completed)
      echo "cleanup"
      ;;
    failed)
      echo "error_cleanup"
      ;;
    waiting_for_user)
      echo "message_only"
      ;;
    in_progress)
      # Check for timeout (TZ=UTC to match Z suffix timestamps)
      local updated_at
      updated_at=$(jq -r '.updated_at // empty' "$status_file" 2>/dev/null)
      if [ -n "$updated_at" ]; then
        local current_ts updated_ts diff_min
        current_ts=$(TZ=UTC date -u +%s)
        # Parse ISO timestamp to epoch (macOS and Linux compatible)
        updated_ts=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" +%s 2>/dev/null || TZ=UTC date -d "$updated_at" +%s 2>/dev/null || echo "$current_ts")
        diff_min=$(( (current_ts - updated_ts) / 60 ))
        if [ "$diff_min" -gt 30 ]; then
          echo "timeout"
          return 0
        fi
      fi
      echo "none"
      ;;
    *)
      # No status field -> error_cleanup (per monitor templates)
      echo "error_cleanup"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------
setup() {
  TEST_TMPDIR="$(mktemp -d)"
  STATUS_FILE="${TEST_TMPDIR}/status.json"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ===========================================================================
# Test cases
# ===========================================================================

@test "valid statuses recognized: in_progress, waiting_for_user, completed, failed" {
  is_valid_status "in_progress"
  is_valid_status "waiting_for_user"
  is_valid_status "completed"
  is_valid_status "failed"
}

@test "invalid status rejected" {
  ! is_valid_status "pending"
  ! is_valid_status "running"
  ! is_valid_status "done"
  ! is_valid_status ""
}

@test "monitor ignores non-existent status.json" {
  # status.json does not exist
  [ ! -f "$STATUS_FILE" ]

  local action
  action=$(determine_action "$STATUS_FILE")

  [ "$action" = "none" ]
}

@test "completed triggers cleanup" {
  cat > "$STATUS_FILE" << EOF
{
  "status": "completed",
  "progress": "done",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

  local action
  action=$(determine_action "$STATUS_FILE")

  [ "$action" = "cleanup" ]
}

@test "failed triggers error + cleanup" {
  cat > "$STATUS_FILE" << EOF
{
  "status": "failed",
  "progress": "error occurred",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

  local action
  action=$(determine_action "$STATUS_FILE")

  [ "$action" = "error_cleanup" ]
}

@test "waiting_for_user shows message, no cleanup" {
  cat > "$STATUS_FILE" << EOF
{
  "status": "waiting_for_user",
  "progress": "waiting for response",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

  local action
  action=$(determine_action "$STATUS_FILE")

  [ "$action" = "message_only" ]
}

@test "30-minute timeout detection (updated_at older than 30 min)" {
  # Create a timestamp 35 minutes ago
  local old_ts
  old_ts=$(date -u -v-35M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '35 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)

  cat > "$STATUS_FILE" << EOF
{
  "status": "in_progress",
  "progress": "working",
  "updated_at": "${old_ts}"
}
EOF

  local action
  action=$(determine_action "$STATUS_FILE")

  [ "$action" = "timeout" ]
}

@test "20-minute updated_at does not trigger timeout" {
  # Create a timestamp 20 minutes ago (should NOT trigger 30-min timeout)
  local old_ts
  old_ts=$(date -u -v-20M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '20 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)

  cat > "$STATUS_FILE" << EOF
{
  "status": "in_progress",
  "progress": "working",
  "updated_at": "${old_ts}"
}
EOF

  local action
  action=$(determine_action "$STATUS_FILE")

  [ "$action" = "none" ]
}

@test "recent updated_at produces no timeout" {
  cat > "$STATUS_FILE" << EOF
{
  "status": "in_progress",
  "progress": "working",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

  local action
  action=$(determine_action "$STATUS_FILE")

  [ "$action" = "none" ]
}
