#!/usr/bin/env bash

set -euo pipefail

# Backward-compatible wrapper. New tasks should use public-tests.sh directly.
bash experiments/tri-arm-fixed-spec/tasks/TEMPLATE/public-tests.sh
