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

@test "spec prompt requires minimal working set section" {
  run grep -F "## 最小確認対象" "$PROJECT_ROOT/templates/mysk/spec-prompt.md"
  [ "$status" -eq 0 ]
  run grep -F '`最小確認対象` セクション' "$PROJECT_ROOT/templates/mysk/spec-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec prompt forbids mixing helper-external preprocessing into helper behavior" {
  run grep -F "前処理・後処理を混ぜない" "$PROJECT_ROOT/templates/mysk/spec-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec prompt forbids acceptance criteria from canceling each other out" {
  run grep -F '受け入れ条件` 同士が互いを打ち消さない' "$PROJECT_ROOT/templates/mysk/spec-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec prompt requires literal post-edit text for narrow text-only tasks" {
  run grep -F "literal な文言" "$PROJECT_ROOT/templates/mysk/spec-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec review prompt checks current behavior claims against repo evidence" {
  run grep -F "現在の helper" "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec review prompt tells reviewer to save draft review json early" {
  run grep -F "初期JSONを保存" "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec review prompt checks acceptance criteria collisions" {
  run grep -F '受け入れ条件` が、他の `受け入れ条件`' "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec review prompt checks literal post-edit text for narrow text-only tasks" {
  run grep -F "literal に特定できるか" "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "spec review prompt checks minimal working set section" {
  run grep -F "最小確認対象" "$PROJECT_ROOT/templates/mysk/spec-review-prompt.md"
  [ "$status" -eq 0 ]
}

@test "benchmark review prompt checks acceptance criteria collisions" {
  run grep -F "acceptance criterion が、他の acceptance" "$PROJECT_ROOT/experiments/tri-arm-fixed-spec/prompts/review.md"
  [ "$status" -eq 0 ]
}

@test "benchmark review prompt prioritizes literal post-edit text over summary patterns" {
  run grep -F "literal な変更後文言" "$PROJECT_ROOT/experiments/tri-arm-fixed-spec/prompts/review.md"
  [ "$status" -eq 0 ]
}

@test "mysk-spec command tells planner to start from smallest relevant files and tests" {
  run grep -F "Start from the smallest relevant files/tests implied by the topic" "$PROJECT_ROOT/commands/mysk-spec.md"
  [ "$status" -eq 0 ]
}

@test "mysk-spec command tells planner to make literal post-edit text explicit" {
  run grep -F "literal post-edit text explicit" "$PROJECT_ROOT/commands/mysk-spec.md"
  [ "$status" -eq 0 ]
}

@test "mysk-spec command tells planner to write minimal working set section" {
  run grep -F "write a concrete 最小確認対象 section" "$PROJECT_ROOT/commands/mysk-spec.md"
  [ "$status" -eq 0 ]
}

@test "cmux launch procedure uses alias as source of truth" {
  run grep -F 'MODEL_ALIAS="${MYSK_MODEL_ALIAS:-opus}"' "$PROJECT_ROOT/templates/mysk/cmux-launch-procedure.md"
  [ "$status" -eq 0 ]
  run grep -F 'requested_model_alias' "$PROJECT_ROOT/templates/mysk/cmux-launch-procedure.md"
  [ "$status" -eq 0 ]
}

@test "cmux launch procedure records runtime model as diagnostic" {
  run grep -F 'configured_runtime_model' "$PROJECT_ROOT/templates/mysk/cmux-launch-procedure.md"
  [ "$status" -eq 0 ]
  run grep -F 'resolved_runtime_model' "$PROJECT_ROOT/templates/mysk/cmux-launch-procedure.md"
  [ "$status" -eq 0 ]
}

@test "mysk-spec command sets launch metadata paths" {
  run grep -F 'SPEC_LAUNCH_META_PATH="$RUN_DIR/spec-launch-meta.json"' "$PROJECT_ROOT/commands/mysk-spec.md"
  [ "$status" -eq 0 ]
  run grep -F 'SPEC_REVIEW_LAUNCH_META_PATH="$RUN_DIR/spec-review-launch-meta.json"' "$PROJECT_ROOT/commands/mysk-spec.md"
  [ "$status" -eq 0 ]
}

@test "review-check prompt includes diff artifacts section" {
  run grep -F "## Diff Artifacts" "$PROJECT_ROOT/templates/mysk/review-check-prompt.md"
  [ "$status" -eq 0 ]
}

@test "review-check prompt includes minimal working set snapshot" {
  run grep -F "## Spec Snapshot" "$PROJECT_ROOT/templates/mysk/review-check-prompt.md"
  [ "$status" -eq 0 ]
  run grep -F "最小確認対象スナップショット" "$PROJECT_ROOT/templates/mysk/review-check-prompt.md"
  [ "$status" -eq 0 ]
}

@test "mysk-review command renders changed paths and diff artifacts" {
  run grep -F "\"{CHANGED_PATHS}\": render_changed_paths()" "$PROJECT_ROOT/commands/mysk-review.md"
  [ "$status" -eq 0 ]
}

@test "mysk-review command renders minimal working set snapshot" {
  run grep -F "\"{SPEC_MINIMUM_CONTEXT}\": render_spec_section(\"最小確認対象\")" "$PROJECT_ROOT/commands/mysk-review.md"
  [ "$status" -eq 0 ]
}

@test "verify prompt forbids invented acceptance ids and extra top-level fields" {
  run grep -F "新しいIDを発明せず" "$PROJECT_ROOT/templates/mysk/review-verify-prompt.md"
  [ "$status" -eq 0 ]
  run grep -F "余分なトップレベルフィールドを追加しない" "$PROJECT_ROOT/templates/mysk/review-verify-prompt.md"
  [ "$status" -eq 0 ]
}

@test "mysk-review command renders spec snapshot placeholders for verify" {
  run grep -F "\"{SPEC_ACCEPTANCE_CONTEXT}\": render_spec_section(\"受け入れ条件\")" "$PROJECT_ROOT/commands/mysk-review.md"
  [ "$status" -eq 0 ]
}

@test "verify prompt includes minimal working set snapshot" {
  run grep -F "最小確認対象スナップショット" "$PROJECT_ROOT/templates/mysk/review-verify-prompt.md"
  [ "$status" -eq 0 ]
}

@test "mysk-review command sets launch metadata paths" {
  run grep -F 'REVIEW_CHECK_LAUNCH_META_PATH="$RUN_DIR/review-check-launch-meta.json"' "$PROJECT_ROOT/commands/mysk-review.md"
  [ "$status" -eq 0 ]
  run grep -F 'VERIFY_LAUNCH_META_PATH="$RUN_DIR/review-verify-launch-meta.json"' "$PROJECT_ROOT/commands/mysk-review.md"
  [ "$status" -eq 0 ]
}
