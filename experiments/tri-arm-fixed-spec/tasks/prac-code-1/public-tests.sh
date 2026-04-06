#!/usr/bin/env bash

set -euo pipefail

# Practical test for code change (runner script)
# CWD: experiments/tri-arm-fixed-spec/

# Verify target script exists
test -f "bin/run-practical.sh"

# Verify script is executable
test -x "bin/run-practical.sh"

# Verify script has valid shebang
head -n 1 "bin/run-practical.sh" | grep -q '#!/usr/bin/env bash'

# Verify script has slugify function
grep -q 'slugify()' "bin/run-practical.sh"

# Verify script has main function
grep -q 'main()' "bin/run-practical.sh"

# Test slug generation with empty input (should default to unnamed-experiment)
# This tests the edge case handling mentioned in fixed-spec
# Run the script with empty input to verify slugify behavior
# Note: This will fail on usage, which is expected behavior for missing task_id
if bash bin/run-practical.sh 2>&1 | grep -q "Usage:"; then
  # Script correctly rejects empty input
  :
else
  # Unexpected behavior - script should reject empty input
  exit 1
fi

# Test slug generation with special characters
# We verify slugify handles special characters by checking the function
if grep -q 'tr -c ' "bin/run-practical.sh"; then
  # slugify uses proper character filtering
  :
else
  # Missing slugify implementation
  exit 1
fi

# Test slugify function behavior directly
# Source the script to access slugify function, then test it
# Use a subshell to avoid polluting the current environment
TEST_RESULT=$(
  set -euo pipefail
  # Source only the slugify function by extracting and evaling it
  eval "$(grep -A 10 '^slugify()' bin/run-practical.sh | head -11)"

  # Test 1: Empty input should default to unnamed-experiment
  result=$(slugify "")
  if [ "$result" != "unnamed-experiment" ]; then
    echo "FAIL: Empty input should produce 'unnamed-experiment', got '$result'"
    exit 1
  fi

  # Test 2: Special characters should be sanitized to hyphens
  result=$(slugify "test!!@#\$%^&*()")
  if [ "$result" != "test" ]; then
    echo "FAIL: Special chars not properly sanitized, got '$result'"
    exit 1
  fi

  # Test 3: Normal input should pass through
  result=$(slugify "test-task-123")
  if [ "$result" != "test-task-123" ]; then
    echo "FAIL: Normal input changed, got '$result'"
    exit 1
  fi

  # Test 4: Multiple hyphens should be collapsed
  result=$(slugify "test---multiple---hyphens")
  if [ "$result" != "test-multiple-hyphens" ]; then
    echo "FAIL: Multiple hyphens not collapsed, got '$result'"
    exit 1
  fi

  echo "slugify tests passed"
)
if [ $? -eq 0 ]; then
  :
else
  echo "Slugify function tests failed: $TEST_RESULT"
  exit 1
fi

echo "prac-code-1 public tests: PASSED"
