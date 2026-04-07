# Spec: prac-code-1

## Overview

Create `experiments/tri-arm-fixed-spec/bin/run-practical.sh` to execute practical test fixtures with isolated run directories and automated result collection.

## Purpose

Provide a simple 1-command interface for running practical tests without manual setup or configuration file dependencies.

## Target File

`experiments/tri-arm-fixed-spec/bin/run-practical.sh` (new file)

## In-Scope

- Create bash script with inline configuration
- Implement task execution with run directory isolation
- Generate execution summary output

## Out-of-Scope

- Modifying existing run-experiment.sh
- Multi-arm comparison (single execution only)
- Review integration
- Config.json dependency

## Constraints

- Script must be bash compatible
- Use inline config only
- Follow `run-experiment.sh` conventions for slug generation, timestamp formatting, and run directory naming
- Practical test runner uses simplified output artifacts (`run.log`, `results.json`) instead of full benchmark artifacts
- ASCII-only code and comments

## Acceptance Criteria

1. Script exists at bin/run-practical.sh with execute permission
2. Accepts task_id as positional argument
3. Creates runs/<timestamp>-<slug>/ directory per execution
4. Outputs summary to stdout after completion
5. Slug defaults to "unnamed-experiment" if empty
6. Only bin/run-practical.sh is created

## Expected Behavior

### Usage

```bash
bin/run-practical.sh <task_id>
```

### Inline Configuration

The script should contain inline configuration for:
- Base repository path (auto-detected or default)
- Model to use for task execution
- Time limits

### Output Structure

Each run should create:
```
runs/<timestamp>-<slug>/
  task.json
  brief.md
  spec.md
  fixed-spec.md
  run.log
  results.json
```

### Summary Output

After completion, output to stdout:
```
Practical test completed: <task_id>
Run directory: runs/<timestamp>-<slug>
Status: <passed|failed>
Elapsed: <N> minutes
```

## Reference Implementation

See `bin/run-experiment.sh` for:
- Slug generation logic
- Run directory creation
- Shared naming conventions only; practical output stays simplified
