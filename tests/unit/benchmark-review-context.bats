#!/usr/bin/env bats

load '../helpers/test-common'

@test "run-task review prompt includes changed paths section" {
  run grep -F "## Changed Paths" "$PROJECT_ROOT/experiments/tri-arm-fixed-spec/bin/run-task.sh"
  [ "$status" -eq 0 ]
}

@test "run-task review prompt includes diff patch section" {
  run grep -F "## Diff Patch" "$PROJECT_ROOT/experiments/tri-arm-fixed-spec/bin/run-task.sh"
  [ "$status" -eq 0 ]
}

@test "benchmark review prompt tells reviewer to use diff artifacts first" {
  run grep -F "Changed Paths / Diff Stat / Diff Patch" "$PROJECT_ROOT/experiments/tri-arm-fixed-spec/prompts/review.md"
  [ "$status" -eq 0 ]
}

@test "spec prompt requires repo evidence for current behavior claims" {
  run grep -F "現在の実装や既存挙動を本文で断定する場合" "$PROJECT_ROOT/templates/mysk/spec-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec prompt limits narrow-task exploration to smallest relevant file set" {
  run grep -F "関連ファイル・関連テストの最小集合" "$PROJECT_ROOT/templates/mysk/spec-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec review prompt checks current behavior claims against repo evidence" {
  run grep -F "現在の helper" "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "mysk-spec command tells planner to start from smallest relevant files and tests" {
  run grep -F "Start from the smallest relevant files/tests implied by the topic" "$PROJECT_ROOT/commands/mysk-spec.md"
  [ "$status" -eq 0 ]
}
