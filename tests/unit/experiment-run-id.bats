#!/usr/bin/env bats

load '../helpers/test-common'

setup() {
  TEST_TMPDIR="$(mktemp -d)"
  SCRIPT_PATH="$PROJECT_ROOT/experiments/tri-arm-fixed-spec/bin/run-experiment.sh"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

run_script_function() {
  local function_name="$1"
  shift

  run bash -lc '
    source "$1" >/dev/null 2>&1
    shift
    "$@"
  ' bash "$SCRIPT_PATH" "$function_name" "$@"
}

write_config() {
  local path="$1"
  local experiment_id="${2:-}"

  if [ -n "$experiment_id" ]; then
    cat > "$path" <<EOF
{
  "experiment_id": "$experiment_id",
  "arms": []
}
EOF
  else
    cat > "$path" <<'EOF'
{
  "arms": []
}
EOF
  fi
}

@test "slugify_experiment_label keeps safe characters" {
  run_script_function slugify_experiment_label "spec_handoff-4arm"

  [ "$status" -eq 0 ]
  [ "$output" = "spec_handoff-4arm" ]
}

@test "slugify_experiment_label normalizes punctuation and spaces" {
  run_script_function slugify_experiment_label "my experiment v2!"

  [ "$status" -eq 0 ]
  [ "$output" = "my-experiment-v2" ]
}

@test "slugify_experiment_label guards empty result" {
  run_script_function slugify_experiment_label "!!!"

  [ "$status" -eq 0 ]
  [ "$output" = "unnamed-experiment" ]
}

@test "resolve_experiment_label prefers experiment_id from config" {
  local config_path="$TEST_TMPDIR/config.json"
  write_config "$config_path" "spec-handoff-4arm"

  run_script_function resolve_experiment_label "$config_path"

  [ "$status" -eq 0 ]
  [ "$output" = "spec-handoff-4arm" ]
}

@test "resolve_experiment_label falls back to config basename without final .json" {
  local config_path="$TEST_TMPDIR/config.foo.json"
  write_config "$config_path"

  run_script_function resolve_experiment_label "$config_path"

  [ "$status" -eq 0 ]
  [ "$output" = "config.foo" ]
}

@test "build_run_id uses experiment_id-derived suffix" {
  local config_path="$TEST_TMPDIR/config.json"
  write_config "$config_path" "spec-handoff-4arm"

  run_script_function build_run_id "$config_path"

  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{8}T[0-9]{6}Z-spec-handoff-4arm$ ]]
}

@test "build_run_id slugifies basename fallback" {
  local config_path="$TEST_TMPDIR/config.foo.json"
  write_config "$config_path"

  run_script_function build_run_id "$config_path"

  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{8}T[0-9]{6}Z-config-foo$ ]]
}

@test "build_run_id uses unnamed-experiment when fallback also normalizes to empty" {
  local config_path="$TEST_TMPDIR/!!!.json"
  write_config "$config_path"

  run_script_function build_run_id "$config_path"

  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]{8}T[0-9]{6}Z-unnamed-experiment$ ]]
}
