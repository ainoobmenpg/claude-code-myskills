#!/bin/bash
# stage-time-summary.sh
# 各 stage の所要時間を集計するスクリプト

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <run_id>" >&2
  echo "Example: $0 20260405-225828Z-p1-issue" >&2
  exit 1
fi

RUN_ID="$1"
DATA_DIR="$HOME/.local/share/claude-mysk"
RUN_DIR="$DATA_DIR/$RUN_ID"

if [ ! -d "$RUN_DIR" ]; then
  echo "Error: Run directory not found: $RUN_DIR" >&2
  exit 1
fi

echo "# Stage Time Summary"
echo ""
echo "run_id: $RUN_ID"
echo ""

# Helper function to calculate duration in seconds
calculate_duration() {
  local start="$1"
  local end="$2"
  
  if [ -z "$start" ] || [ -z "$end" ]; then
    echo "N/A"
    return
  fi
  
  # macOS and Linux compatible date calculation
  if date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start" +%s >/dev/null 2>&1; then
    # macOS
    local start_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$start" +%s)
    local end_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$end" +%s)
    echo $((end_ts - start_ts))
  else
    # Linux
    local start_ts=$(date -d "$start" +%s)
    local end_ts=$(date -d "$end" +%s)
    echo $((end_ts - start_ts))
  fi
}

# Helper function to format seconds as human readable
format_duration() {
  local seconds="$1"
  
  if [ "$seconds" = "N/A" ]; then
    echo "N/A"
    return
  fi
  
  local minutes=$((seconds / 60))
  local remaining_seconds=$((seconds % 60))
  
  if [ $minutes -gt 0 ]; then
    echo "${minutes}m ${remaining_seconds}s"
  else
    echo "${seconds}s"
  fi
}

# Stage artifacts
declare -A STAGE_START
declare -A STAGE_FIRST
declare -A STAGE_COMPLETE

# Read spec status.json
if [ -f "$RUN_DIR/status.json" ]; then
  SPEC_STATUS="$RUN_DIR/status.json"
  STARTED=$(grep -o '"started_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$SPEC_STATUS" | cut -d'"' -f4 | head -1)
  COMPLETED=$(grep -o '"completed_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$SPEC_STATUS" | cut -d'"' -f4 | head -1)

  STAGE_START[spec]="$STARTED"
  STAGE_FIRST[spec]="N/A"
  STAGE_COMPLETE[spec]="$COMPLETED"
fi

# Read spec-review.json
if [ -f "$RUN_DIR/spec-review.json" ]; then
  SPEC_REVIEW="$RUN_DIR/spec-review.json"
  STARTED=$(grep -o '"started_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$SPEC_REVIEW" | cut -d'"' -f4 | head -1)
  FIRST=$(grep -o '"first_artifact_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$SPEC_REVIEW" | cut -d'"' -f4 | head -1)
  COMPLETED=$(grep -o '"completed_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$SPEC_REVIEW" | cut -d'"' -f4 | head -1)
  
  STAGE_START[spec-review]="$STARTED"
  STAGE_FIRST[spec-review]="$FIRST"
  STAGE_COMPLETE[spec-review]="$COMPLETED"
fi

# Read review.json
if [ -f "$RUN_DIR/review.json" ]; then
  REVIEW="$RUN_DIR/review.json"
  STARTED=$(grep -o '"started_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$REVIEW" | cut -d'"' -f4 | head -1)
  FIRST=$(grep -o '"first_artifact_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$REVIEW" | cut -d'"' -f4 | head -1)
  COMPLETED=$(grep -o '"completed_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$REVIEW" | cut -d'"' -f4 | head -1)
  
  STAGE_START[review]="$STARTED"
  STAGE_FIRST[review]="$FIRST"
  STAGE_COMPLETE[review]="$COMPLETED"
fi

# Read verify.json or verify-rerun.json
VERIFY_FILE=""
if [ -f "$RUN_DIR/verify-rerun.json" ]; then
  VERIFY_FILE="$RUN_DIR/verify-rerun.json"
elif [ -f "$RUN_DIR/verify.json" ]; then
  VERIFY_FILE="$RUN_DIR/verify.json"
fi

if [ -n "$VERIFY_FILE" ]; then
  STARTED=$(grep -o '"started_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERIFY_FILE" | cut -d'"' -f4 | head -1)
  FIRST=$(grep -o '"first_artifact_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERIFY_FILE" | cut -d'"' -f4 | head -1)
  COMPLETED=$(grep -o '"completed_at"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERIFY_FILE" | cut -d'"' -f4 | head -1)
  
  STAGE_START[verify]="$STARTED"
  STAGE_FIRST[verify]="$FIRST"
  STAGE_COMPLETE[verify]="$COMPLETED"
fi

# Display summary
echo "| Stage | Started | First Artifact | Completed | Duration |"
echo "|-------|---------|----------------|-----------|----------|"

TOTAL_SECONDS=0
TOTAL_COUNTED=0

for stage in spec spec-review review verify; do
  if [ -n "${STAGE_START[$stage]}" ]; then
    STARTED="${STAGE_START[$stage]}"
    FIRST="${STAGE_FIRST[$stage]:-N/A}"
    COMPLETED="${STAGE_COMPLETE[$stage]:-N/A}"
    
    DURATION_SECONDS="N/A"
    if [ "$COMPLETED" != "N/A" ] && [ "$STARTED" != "N/A" ]; then
      DURATION_SECONDS=$(calculate_duration "$STARTED" "$COMPLETED")
    fi
    if [ "$DURATION_SECONDS" != "N/A" ]; then
      TOTAL_SECONDS=$((TOTAL_SECONDS + DURATION_SECONDS))
      TOTAL_COUNTED=$((TOTAL_COUNTED + 1))
    fi
    
    DURATION_FORMATTED=$(format_duration "$DURATION_SECONDS")
    
    # Format timestamps as short strings
    STARTED_SHORT=$(echo "$STARTED" | sed 's/T/ /' | sed 's/\.[0-9]*Z/Z/')
    FIRST_SHORT=$(echo "$FIRST" | sed 's/T/ /' | sed 's/\.[0-9]*Z/Z/')
    COMPLETED_SHORT=$(echo "$COMPLETED" | sed 's/T/ /' | sed 's/\.[0-9]*Z/Z/')
    
    echo "| $stage | $STARTED_SHORT | $FIRST_SHORT | $COMPLETED_SHORT | $DURATION_FORMATTED |"
  fi
done

echo ""
if [ "$TOTAL_COUNTED" -gt 0 ]; then
  echo "Total: $(format_duration "$TOTAL_SECONDS")"
  echo ""
fi
echo "## Notes"
echo "- N/A: データなし"
echo "- 時刻は全て UTC"
echo "- Duration は started から completed までの時間"
