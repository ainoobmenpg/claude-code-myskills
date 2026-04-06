# Fixed Spec: prac-code-1

## Implementation Target

Create `experiments/tri-arm-fixed-spec/bin/run-practical.sh`

## Required Implementation

### Script Structure

```bash
#!/usr/bin/env bash

set -euo pipefail

# Inline configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${EXP_DIR}/../.." && pwd)"
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

# Main execution
main() {
  local task_id="$1"
  local timestamp slug run_dir

  if [ -z "${task_id}" ]; then
    echo "Usage: $0 <task_id>" >&2
    exit 1
  fi

  timestamp="$(date -u +"%Y%m%dT%H%M%SZ")"
  slug="$(slugify "${task_id}")"
  run_dir="${EXP_DIR}/runs/${timestamp}-${slug}"

  mkdir -p "${run_dir}"

  # Copy task files
  cp -r "${EXP_DIR}/tasks/${task_id}"/* "${run_dir}/"

  # Execute task (placeholder for actual implementation)
  echo "Running practical test: ${task_id}"
  echo "Run directory: ${run_dir}"

  # Output summary
  echo ""
  echo "Practical test completed: ${task_id}"
  echo "Run directory: runs/${timestamp}-${slug}"
  echo "Status: completed"
  echo "Elapsed: ${DEFAULT_TIME_MINUTES} minutes"
}

main "$@"
```

## Boundary Conditions

- Script must be executable (chmod +x)
- Slug generation must handle empty/invalid input
- Run directory must not conflict with existing runs
- All paths must be relative to EXP_DIR

## Non-Targets

- Do NOT modify run-experiment.sh
- Do NOT create config dependencies
- Do NOT implement review integration
- Do NOT use non-ASCII characters

## Acceptance Tests

1. Verify script exists at bin/run-practical.sh
2. Verify script is executable
3. Run `bin/run-practical.sh prac-docs-1line` - should create run directory
4. Verify run directory has timestamp-slug format
5. Verify stdout contains summary

## Hidden Tests

Hidden tests will verify:
- Slug generation handles empty input (defaults to unnamed-experiment)
- Slug generation handles special characters
- Run directory is unique per execution
- Script fails gracefully on invalid task_id
- No files are created outside runs/ directory
