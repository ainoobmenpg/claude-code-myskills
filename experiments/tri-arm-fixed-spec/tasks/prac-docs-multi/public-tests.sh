#!/usr/bin/env bash

set -euo pipefail

# Practical test for multi-line documentation fix
# CWD: experiments/tri-arm-fixed-spec/
# This test is deterministic: same input always produces same exit code

# Verify target file exists
test -f "../../README.md"

# Verify PRACTICAL_CRITERIA.md is referenced
grep -q 'PRACTICAL_CRITERIA.md' "../../README.md"

# Verify practical fixture names are mentioned
grep -q 'prac-docs-1line' "../../README.md" && grep -q 'prac-docs-multi' "../../README.md" && grep -q 'prac-code-1' "../../README.md"

# Verify markdown is valid (no broken links to referenced files)
# Check that PRACTICAL_CRITERIA.md exists at the referenced path
test -f "PRACTICAL_CRITERIA.md"

echo "prac-docs-multi public tests: PASSED"
