#!/usr/bin/env bash
# Fixture loading utilities for mysk tests

_FIXTURE_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="${_FIXTURE_HELPERS_DIR}/../fixtures"

# Create a temporary directory with fixtures loaded
setup_mock_environment() {
    local fixture_name="$1"
    local temp_dir
    temp_dir="$(mktemp -d)"

    if [ -d "$FIXTURES_DIR/run-directories/$fixture_name" ]; then
        cp -r "$FIXTURES_DIR/run-directories/$fixture_name"/* "$temp_dir/"
    fi

    echo "$temp_dir"
}

# Cleanup temporary directory
teardown_mock_environment() {
    local temp_dir="$1"
    rm -rf "$temp_dir"
}

# Create a minimal valid run-meta.json
create_run_meta() {
    local dir="$1" run_id="$2" project_root="$3" topic="$4"
    cat > "$dir/run-meta.json" << METAEOF
{
  "run_id": "$run_id",
  "project_root": "$project_root",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "topic": "$topic"
}
METAEOF
}

# Create a status.json with given status
create_status_json() {
    local dir="$1" status="$2" progress="${3:-}"
    cat > "$dir/status.json" << STATUSEOF
{
  "status": "$status",
  "progress": "$progress",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
STATUSEOF
}

# Create a valid review.json
create_review_json() {
    local dir="$1" run_id="$2" project_root="$3" finding_count="${4:-2}"
    local findings
    if [ "$finding_count" -ge 1 ]; then
        findings='{"id":"F001","severity":"high","file":"src/main.ts","line":10,"title":"test finding","detail":"test detail","suggested_fix":"test fix"}'
    fi
    if [ "$finding_count" -ge 2 ]; then
        findings="$findings"',{"id":"F002","severity":"medium","file":"src/util.ts","line":20,"title":"medium finding","detail":"medium detail","suggested_fix":"medium fix"}'
    fi

    cat > "$dir/review.json" << REVIEWEOF
{
  "version": 1,
  "run_id": "$run_id",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "completed",
  "progress": "review completed",
  "project_root": "$project_root",
  "source": {"type": "diff", "value": "git diff"},
  "summary": {
    "overall_risk": "$([ "$finding_count" -gt 0 ] && echo high || echo low)",
    "headline": "high priority ${finding_count}",
    "finding_count": $finding_count
  },
  "findings": [$findings]
}
REVIEWEOF
}

# Create a valid verify.json
create_verify_json() {
    local dir="$1" run_id="$2" result="$3" high_rem="${4:-0}" med_rem="${5:-0}" low_rem="${6:-0}"
    cat > "$dir/verify.json" << VERIFYEOF
{
  "version": 1,
  "run_id": "$run_id",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "completed",
  "progress": "Verification completed",
  "source_review": "review.json",
  "project_root": "/test/project",
  "verification_result": "$result",
  "summary": {
    "verified_count": 2,
    "fixed_count": $([ "$high_rem" -eq 0 ] && echo 2 || echo 1),
    "remaining_count": $((high_rem + med_rem + low_rem)),
    "new_issues_count": 0,
    "high_remaining": $high_rem,
    "medium_remaining": $med_rem,
    "low_remaining": $low_rem
  },
  "verifications": [],
  "new_findings": []
}
VERIFYEOF
}
