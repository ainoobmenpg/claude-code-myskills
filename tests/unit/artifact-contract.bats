#!/usr/bin/env bats

load '../helpers/test-common'

# artifact-contract.bats
# 証跡 JSON の必須項目をテストで固定する
# #31: artifact-contract.bats で JSON 契約を固定

@test "review JSON includes required version field in prompt" {
  run grep -F '"version"' "$PROJECT_ROOT/templates/mysk/review-check-prompt.md"
  [ "$status" -eq 0 ]
}

@test "review JSON includes required run_id field in prompt" {
  run grep -F '"run_id"' "$PROJECT_ROOT/templates/mysk/review-check-prompt.md"
  [ "$status" -eq 0 ]
}

@test "review JSON includes required project_root field in prompt" {
  run grep -F '"project_root"' "$PROJECT_ROOT/templates/mysk/review-check-prompt.md"
  [ "$status" -eq 0 ]
}

@test "review JSON includes required findings field in prompt" {
  run grep -F '"findings"' "$PROJECT_ROOT/templates/mysk/review-check-prompt.md"
  [ "$status" -eq 0 ]
}

@test "review JSON includes required summary field in prompt" {
  run grep -F '"summary"' "$PROJECT_ROOT/templates/mysk/review-check-prompt.md"
  [ "$status" -eq 0 ]
}

@test "verify JSON includes required version field in prompt" {
  run grep -F '"version"' "$PROJECT_ROOT/templates/mysk/review-verify-prompt.md"
  [ "$status" -eq 0 ]
}

@test "verify JSON includes required run_id field in prompt" {
  run grep -F '"run_id"' "$PROJECT_ROOT/templates/mysk/review-verify-prompt.md"
  [ "$status" -eq 0 ]
}

@test "verify JSON includes required verification_result field in prompt" {
  run grep -F '"verification_result"' "$PROJECT_ROOT/templates/mysk/review-verify-prompt.md"
  [ "$status" -eq 0 ]
}

@test "verify JSON includes required verifications field in prompt" {
  run grep -F '"verifications"' "$PROJECT_ROOT/templates/mysk/review-verify-prompt.md"
  [ "$status" -eq 0 ]
}

@test "verify JSON includes required summary field in prompt" {
  run grep -F '"summary"' "$PROJECT_ROOT/templates/mysk/review-verify-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec-review JSON includes required version field in prompt" {
  run grep -F '"version"' "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec-review JSON includes required run_id field in prompt" {
  run grep -F '"run_id"' "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec-review JSON includes required findings field in prompt" {
  run grep -F '"findings"' "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec-review JSON includes required checked_paths field in prompt" {
  run grep -F '"checked_paths"' "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec-review JSON includes required checked_lines field in prompt" {
  run grep -F '"checked_lines"' "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}
