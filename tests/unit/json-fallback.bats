#!/usr/bin/env bats
# json-fallback.bats - Tests for JSON fallback parsing logic
# Extracted from: mysk-review-fix.md, mysk-review-diffcheck.md
#
# Fallback chain:
#   findings -> issues
#   .file -> extract from .location before colon
#   .line -> extract from .location after colon
#   .detail -> .description
#   .suggested_fix -> .suggestion
#   .section -> .category
#   .summary.finding_count -> .summary.total -> findings.length
#   .source.value -> .target

load '../helpers/test-common'
load '../helpers/fixture-loader'

# ---------------------------------------------------------------------------
# Helper functions: extract data using fallback rules from command files
# ---------------------------------------------------------------------------

# Extract findings array using fallback: .findings -> .issues
extract_findings_array() {
  local json_file="$1"
  local result

  result=$(jq -r '.findings // .issues // empty' "$json_file" 2>/dev/null)
  echo "$result"
}

# Extract file from a finding: .file -> .location before colon
extract_file() {
  local finding_json="$1"
  local val

  val=$(echo "$finding_json" | jq -r '.file // empty' 2>/dev/null)
  if [ -z "$val" ]; then
    local location
    location=$(echo "$finding_json" | jq -r '.location // empty' 2>/dev/null)
    if [ -n "$location" ]; then
      val=$(echo "$location" | sed 's/:.*$//')
    fi
  fi
  echo "$val"
}

# Extract line from a finding: .line -> .location after colon (first part if hyphenated)
extract_line() {
  local finding_json="$1"
  local val

  val=$(echo "$finding_json" | jq -r '.line // empty' 2>/dev/null)
  if [ -z "$val" ]; then
    local location
    location=$(echo "$finding_json" | jq -r '.location // empty' 2>/dev/null)
    if [ -n "$location" ]; then
      # Extract after colon, take first part if hyphenated (e.g., "25-30" -> "25")
      val=$(echo "$location" | sed 's/^[^:]*://' | sed 's/-.*$//')
    fi
  fi
  echo "$val"
}

# Extract detail: .detail -> .description
extract_detail() {
  local finding_json="$1"
  local val

  val=$(echo "$finding_json" | jq -r '.detail // empty' 2>/dev/null)
  if [ -z "$val" ]; then
    val=$(echo "$finding_json" | jq -r '.description // empty' 2>/dev/null)
  fi
  echo "$val"
}

# Extract suggested_fix: .suggested_fix -> .suggestion
extract_suggested_fix() {
  local finding_json="$1"
  local val

  val=$(echo "$finding_json" | jq -r '.suggested_fix // empty' 2>/dev/null)
  if [ -z "$val" ]; then
    val=$(echo "$finding_json" | jq -r '.suggestion // empty' 2>/dev/null)
  fi
  echo "$val"
}

# Extract section: .section -> .category
extract_section() {
  local finding_json="$1"
  local val

  val=$(echo "$finding_json" | jq -r '.section // empty' 2>/dev/null)
  if [ -z "$val" ]; then
    val=$(echo "$finding_json" | jq -r '.category // empty' 2>/dev/null)
  fi
  echo "$val"
}

# Extract finding_count: .summary.finding_count -> .summary.total -> findings.length
extract_finding_count() {
  local json_file="$1"
  local val

  val=$(jq -r '.summary.finding_count // empty' "$json_file" 2>/dev/null)
  if [ -z "$val" ]; then
    val=$(jq -r '.summary.total // empty' "$json_file" 2>/dev/null)
    if [ -z "$val" ]; then
      val=$(jq '(.findings // .issues // []) | length' "$json_file" 2>/dev/null)
    fi
  fi
  echo "$val"
}

# Extract source value: .source.value -> .target
extract_source_value() {
  local json_file="$1"
  local val

  val=$(jq -r '.source.value // empty' "$json_file" 2>/dev/null)
  if [ -z "$val" ]; then
    val=$(jq -r '.target // empty' "$json_file" 2>/dev/null)
  fi
  echo "$val"
}

# Check if file is valid JSON
is_valid_json() {
  jq . "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------
setup() {
  FIXTURES_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../fixtures" && pwd)"
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ===========================================================================
# Test cases
# ===========================================================================

@test "standard keys (.findings, .detail, .suggested_fix) extracted correctly" {
  # Create a temporary file with standard keys for this test
  local tmp_fixture="${TEST_TMPDIR}/standard-keys.json"
  cat > "$tmp_fixture" << 'EOF'
{
  "version": 1,
  "run_id": "20260401-120000Z-standard",
  "findings": [
    {
      "id": "F001",
      "severity": "high",
      "file": "src/main.ts",
      "line": 10,
      "title": "standard key finding",
      "detail": "standard detail",
      "suggested_fix": "standard fix",
      "section": "Security"
    }
  ],
  "source": {"type": "diff", "value": "src/main.ts"}
}
EOF

  local findings
  findings=$(extract_findings_array "$tmp_fixture")
  [ -n "$findings" ]

  local first_finding
  first_finding=$(echo "$findings" | jq '.[0]')

  local detail
  detail=$(extract_detail "$first_finding")
  [ "$detail" = "standard detail" ]

  local fix
  fix=$(extract_suggested_fix "$first_finding")
  [ "$fix" = "standard fix" ]

  local section
  section=$(extract_section "$first_finding")
  [ "$section" = "Security" ]
}

@test "fallback .issues when .findings missing" {
  local fixture="${FIXTURES_DIR}/malformed/issues-only.json"
  [ -f "$fixture" ]

  # .findings does not exist, should fall back to .issues
  local findings
  findings=$(jq -r '.findings // empty' "$fixture" 2>/dev/null)
  [ -z "$findings" ]

  local issues
  issues=$(extract_findings_array "$fixture")
  [ -n "$issues" ]

  local title
  title=$(echo "$issues" | jq -r '.[0].title')
  [ "$title" = "issue via fallback" ]
}

@test "fallback .location colon-split for file and line" {
  local fixture="${FIXTURES_DIR}/malformed/location-colon.json"
  [ -f "$fixture" ]

  local first_finding
  first_finding=$(jq '.findings[0]' "$fixture")

  # .file does not exist -> extract from .location
  local file_val
  file_val=$(jq -r '.file // empty' <<< "$first_finding")
  [ -z "$file_val" ]

  file_val=$(extract_file "$first_finding")
  [ "$file_val" = "src/auth/middleware.ts" ]

  # .line does not exist -> extract from .location after colon
  local line_val
  line_val=$(jq -r '.line // empty' <<< "$first_finding")
  [ -z "$line_val" ]

  line_val=$(extract_line "$first_finding")
  [ "$line_val" = "42" ]
}

@test "fallback .description when .detail missing" {
  # Use the issues-only fixture where .issues items use .description not .detail
  local fixture="${FIXTURES_DIR}/malformed/issues-only.json"
  local first_issue
  first_issue=$(jq '.issues[0]' "$fixture")

  # .detail does not exist
  local detail_direct
  detail_direct=$(jq -r '.detail // empty' <<< "$first_issue")
  [ -z "$detail_direct" ]

  # Falls back to .description
  local detail
  detail=$(extract_detail "$first_issue")
  [ "$detail" = "desc via fallback" ]
}

@test "fallback .suggestion when .suggested_fix missing" {
  local fixture="${FIXTURES_DIR}/malformed/issues-only.json"
  local first_issue
  first_issue=$(jq '.issues[0]' "$fixture")

  # .suggested_fix does not exist
  local fix_direct
  fix_direct=$(jq -r '.suggested_fix // empty' <<< "$first_issue")
  [ -z "$fix_direct" ]

  # Falls back to .suggestion
  local fix
  fix=$(extract_suggested_fix "$first_issue")
  [ "$fix" = "fix via fallback" ]
}

@test "fallback .category when .section missing" {
  local fixture="${FIXTURES_DIR}/malformed/issues-only.json"
  local first_issue
  first_issue=$(jq '.issues[0]' "$fixture")

  # .section does not exist
  local section_direct
  section_direct=$(jq -r '.section // empty' <<< "$first_issue")
  [ -z "$section_direct" ]

  # Falls back to .category
  local section
  section=$(extract_section "$first_issue")
  [ "$section" = "Logic" ]
}

@test "fallback findings.length when .summary.finding_count and .summary.total missing" {
  local fixture="${FIXTURES_DIR}/malformed/no-count.json"
  [ -f "$fixture" ]

  # .summary.finding_count does not exist
  local count_fc
  count_fc=$(jq -r '.summary.finding_count // empty' "$fixture" 2>/dev/null)
  [ -z "$count_fc" ]

  # .summary.total does not exist
  local count_total
  count_total=$(jq -r '.summary.total // empty' "$fixture" 2>/dev/null)
  [ -z "$count_total" ]

  # Fallback: count the findings/issues array length
  # no-count.json has no findings and no issues, so length should be 0
  local count
  count=$(extract_finding_count "$fixture")
  [ "$count" = "0" ]
}

@test "fallback .target when .source.value missing" {
  local fixture="${FIXTURES_DIR}/malformed/source-target.json"
  [ -f "$fixture" ]

  # .source.value does not exist
  local source_val_direct
  source_val_direct=$(jq -r '.source.value // empty' "$fixture" 2>/dev/null)
  [ -z "$source_val_direct" ]

  # Falls back to .target
  local source_val
  source_val=$(extract_source_value "$fixture")
  [ "$source_val" = "src/target.ts" ]
}

@test "empty JSON {} does not crash" {
  local fixture="${FIXTURES_DIR}/malformed/empty.json"
  [ -f "$fixture" ]

  is_valid_json "$fixture"

  # All extractions should return empty/0 without crashing
  local findings
  findings=$(extract_findings_array "$fixture")
  [ -z "$findings" ] || [ "$findings" = "null" ]

  local count
  count=$(extract_finding_count "$fixture")
  [ "$count" = "0" ]

  local source_val
  source_val=$(extract_source_value "$fixture")
  [ -z "$source_val" ] || [ "$source_val" = "null" ]
}

@test "non-JSON text produces error without crash" {
  local fixture="${FIXTURES_DIR}/malformed/not-json.txt"
  [ -f "$fixture" ]

  # Should not be valid JSON
  ! is_valid_json "$fixture"

  # jq should return non-zero exit code on invalid JSON
  jq '.' "$fixture" >/dev/null 2>&1 && return_code=0 || return_code=$?
  [ "$return_code" -ne 0 ]

  # Our extraction functions should handle this gracefully (no crash)
  local findings
  findings=$(extract_findings_array "$fixture" 2>/dev/null) || true
  # Empty or null is acceptable; the key point is no crash
  [ -z "$findings" ] || [ "$findings" = "null" ]
}
