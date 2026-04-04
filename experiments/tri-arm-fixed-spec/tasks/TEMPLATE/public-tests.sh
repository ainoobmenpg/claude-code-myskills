#!/usr/bin/env bash

set -euo pipefail

# Replace this file per task.
# Keep it deterministic and visible to the agent.
# This script should validate the happy path and obvious regressions,
# while hidden tests cover edge cases and anti-overfit checks.

test -f commands/example.md
test -f templates/mysk/example.json

echo "public tests: placeholder passed"
