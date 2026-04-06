# Practical Test Evaluation Criteria

This document defines the pass/warning/fail criteria for practical test fixtures.

## Overall Quality Thresholds

- **Pass**: All automated checks pass and manual review finds no significant issues
- **Warning**: Minor issues found that do not block implementation
- **Fail**: Critical issues that prevent practical use of the fixture

## Dimension-Specific Criteria

### 1. Fixture Completeness

**Pass**:
- All required files exist (task.json, brief.md, spec.md, fixed-spec.md, public-tests.sh, allowed-paths.txt)
- task.json contains all 16 fields with valid values
- public-tests.sh starts with `set -euo pipefail`

**Warning**:
- Optional fields missing or using placeholder values
- public-tests.sh passes but lacks edge case coverage

**Fail**:
- Required files missing
- task.json missing mandatory fields
- public-tests.sh fails deterministic execution

### 2. Task Determinism

**Pass**:
- public-tests.sh produces identical exit codes for the same input
- No external state dependencies (no random, timestamp, or environment-dependent behavior)
- Task can be re-run on the same commit and produce same results

**Warning**:
- Minor non-determinism in output format that does not affect pass/fail
- Requires specific environment setup documented in brief

**Fail**:
- Non-deterministic pass/fail results
- Hidden state dependencies not documented

### 3. Runner Functionality

**Pass**:
- run-practical.sh executes end-to-end without errors
- Generates unique run directories per execution
- Produces required artifacts (results.json, run.log) for practical test validation
- Properly handles slug generation with empty/invalid inputs
- Note: scorecard.csv, review.json, diff.* are produced by the full benchmark runner (run-experiment.sh), not the practical test runner

**Warning**:
- Inline config could be externalized for clarity
- Output summary could be more detailed

**Fail**:
- Runner fails to execute on fresh clone
- Does not isolate runs (timestamps/slug conflicts)
- Missing required artifacts

### 4. Summary Utility

**Pass**:
- Accepts multiple run directories for comparison
- Generates markdown with task-level elapsed/findings/verify in table format
- Clearly shows before/after differences for same task across runs

**Warning**:
- Output format could be more user-friendly
- Missing additional analysis views

**Fail**:
- Fails to process valid run directories
- Does not support comparison across multiple runs
- Output missing key metrics

### 5. Documentation

**Pass**:
- README.md lists all fixture names (prac-docs-1line, prac-docs-multi, prac-code-1)
- run-practical.sh usage clearly documented
- PRACTICAL_CRITERIA.md accessible from README

**Warning**:
- Documentation could include examples
- Troubleshooting section incomplete

**Fail**:
- Fixture names missing from documentation
- Usage instructions incorrect or misleading
- Criteria not documented

## Minimum Speed Baseline

- Fixture execution time must allow for model reasoning (minimum 5 minutes per arm)
- Total test execution (public + hidden) should complete within 10 minutes
- Summary generation should complete within 30 seconds for typical runs

## Acceptance Decision Matrix

| Outcome | Condition |
|---------|-----------|
| Pass | All dimensions pass |
| Warning | No dimension fails, at least one dimension has warning |
| Fail | Any dimension fails |

## Re-evaluation Process

If a fixture receives "Fail" status:
1. Address the failing dimension(s)
2. Re-run the fixture on a fresh clone
3. Verify the fix addresses the root cause
4. Re-evaluate all dimensions

If a fixture receives "Warning" status:
1. Document the warning in fixture brief
2. Determine if the warning blocks intended use cases
3. Optionally improve to achieve full Pass status
