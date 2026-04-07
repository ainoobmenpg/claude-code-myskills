# Task: Add practical test runner script

## Purpose

Create `experiments/tri-arm-fixed-spec/bin/run-practical.sh` to automate practical test execution with isolated run directories and result collection.

## In-Scope

- Create run-practical.sh script
- Implement inline configuration (no external config dependency)
- Generate unique run directories per execution
- Output execution summary to stdout

## Out-of-Scope

- Modifying existing run-experiment.sh
- Changing config.json structure
- Implementing review integration (for now)

## Constraints

- Script must be bash compatible
- Use inline config (do not depend on config.json)
- Follow run-experiment.sh naming conventions, but keep practical output limited to `run.log` and `results.json`
- Use filesystem-safe slug generation

## Acceptance Criteria

1. run-practical.sh exists and is executable
2. Accepts task_id as argument
3. Creates isolated run directory with timestamp and slug
4. Outputs summary to stdout after completion
5. Only bin/run-practical.sh is created

## Allowed Paths

See `allowed-paths.txt` for the complete list of modifiable paths.

## Known Pitfalls

- Slug generation must handle empty/invalid input gracefully
- Run directory must be unique to avoid conflicts
- Must handle permission errors gracefully
- Summary output should be concise and readable

## Implementation Notes

- Reference run-experiment.sh for slug and run directory conventions
- Use `date -u +"%Y%m%dT%H%M%SZ"` for timestamp
- Default slug to "unnamed-experiment" if empty
- Create runs/<timestamp>-<slug>/ directory structure
