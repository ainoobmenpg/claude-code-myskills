#!/usr/bin/env bats
# template-vars.bats - Validate template variable completeness
# Layer 1 static test: no runtime dependencies
# Ensures every {VAR} in a template is substituted by the corresponding command.

load '../helpers/test-common'

# Sub-pane command template mapping (no associative arrays for bash 3 compat)
# Format: "command:prompt_template monitor_template"
SUBPANE_MAP="
public-spec:spec-prompt.md spec-monitor.md spec-review-prompt.md spec-review-monitor.md
public-review:review-check-prompt.md review-check-monitor.md review-verify-prompt.md review-verify-monitor.md
fixed-spec-draft:fixed-spec-draft-prompt.md fixed-spec-draft-monitor.md
fixed-spec-review:fixed-spec-review-prompt.md fixed-spec-review-monitor.md
spec-draft:spec-draft-prompt.md spec-draft-monitor.md
spec-review:spec-review-prompt.md spec-review-monitor.md
review-check:review-check-prompt.md review-check-monitor.md
review-verify:review-verify-prompt.md review-verify-monitor.md
"

# ----------------------------------------------------------------------
# Helper: get template names for a sub-pane command
# ----------------------------------------------------------------------
_get_templates_for_command() {
    local cmd_name="$1"
    echo "$SUBPANE_MAP" | grep "^${cmd_name}:" | sed "s/^${cmd_name}://"
}

# ----------------------------------------------------------------------
# Helper: get all template vars from a sub-pane command's templates
#         plus cmux-launch-procedure.md (used by all)
# ----------------------------------------------------------------------
_get_all_template_vars_for_command() {
    local cmd_name="$1"
    local templates
    templates=$(_get_templates_for_command "$cmd_name")
    local all_vars=""

    # Always include cmux-launch-procedure.md vars
    all_vars=$(extract_template_vars "$TEMPLATES_DIR/cmux-launch-procedure.md")

    for tmpl in $templates; do
        local tmpl_path="$TEMPLATES_DIR/$tmpl"
        if [ -f "$tmpl_path" ]; then
            local vars
            vars=$(extract_template_vars "$tmpl_path")
            all_vars=$(printf '%s\n%s\n' "$all_vars" "$vars")
        fi
    done

    echo "$all_vars" | sort -u | grep -v '^$'
}

# Helper: get all vars that a command handles (sed substitutions + text mentions)
_get_all_command_vars() {
    local cmd_file="$1"
    # Extract vars from sed patterns
    local sed_vars
    sed_vars=$(extract_substituted_vars "$cmd_file")
    # Also extract vars mentioned in the file text (for WORK_DIR-style text substitutions)
    local text_vars
    text_vars=$(grep -oE '\{[A-Z_]+\}' "$cmd_file" | sort -u)
    # Combine
    printf '%s\n%s\n' "$sed_vars" "$text_vars" | sort -u | grep -v '^$'
}

# ----------------------------------------------------------------------
# Test: for each sub-pane command, every template var is substituted
# ----------------------------------------------------------------------
@test "mysk-spec: all template vars are referenced by command" {
    local cmd_file="$COMMANDS_DIR/mysk-spec.md"
    local template_vars
    template_vars=$(_get_all_template_vars_for_command "public-spec")

    local cmd_vars
    cmd_vars=$(_get_all_command_vars "$cmd_file")

    while IFS= read -r var; do
        [ -n "$var" ] || continue
        echo "$cmd_vars" | grep -qF "$var"
    done <<< "$template_vars"
}

@test "mysk-review: all template vars are referenced by command" {
    local cmd_file="$COMMANDS_DIR/mysk-review.md"
    local template_vars
    template_vars=$(_get_all_template_vars_for_command "public-review")

    local cmd_vars
    cmd_vars=$(_get_all_command_vars "$cmd_file")

    while IFS= read -r var; do
        [ -n "$var" ] || continue
        echo "$cmd_vars" | grep -qF "$var"
    done <<< "$template_vars"
}

@test "fixed-spec-draft: all template vars are substituted by command" {
    local cmd_file="$LEGACY_COMMANDS_DIR/fixed-spec-draft.md"
    local template_vars
    template_vars=$(_get_all_template_vars_for_command "fixed-spec-draft")

    local cmd_vars
    cmd_vars=$(_get_all_command_vars "$cmd_file")

    while IFS= read -r var; do
        [ -n "$var" ] || continue
        echo "$cmd_vars" | grep -qF "$var"
    done <<< "$template_vars"
}

@test "fixed-spec-review: all template vars are substituted by command" {
    local cmd_file="$LEGACY_COMMANDS_DIR/fixed-spec-review.md"
    local template_vars
    template_vars=$(_get_all_template_vars_for_command "fixed-spec-review")

    local cmd_vars
    cmd_vars=$(_get_all_command_vars "$cmd_file")

    while IFS= read -r var; do
        [ -n "$var" ] || continue
        echo "$cmd_vars" | grep -qF "$var"
    done <<< "$template_vars"
}

@test "spec-draft: all template vars are substituted by command" {
    local cmd_file="$LEGACY_COMMANDS_DIR/spec-draft.md"
    local template_vars
    template_vars=$(_get_all_template_vars_for_command "spec-draft")

    local cmd_vars
    cmd_vars=$(_get_all_command_vars "$cmd_file")

    # Every template var must appear in the command's vars
    while IFS= read -r var; do
        [ -n "$var" ] || continue
        echo "$cmd_vars" | grep -qF "$var"
    done <<< "$template_vars"
}

@test "spec-review: all template vars are substituted by command" {
    local cmd_file="$LEGACY_COMMANDS_DIR/spec-review.md"
    local template_vars
    template_vars=$(_get_all_template_vars_for_command "spec-review")

    local cmd_vars
    cmd_vars=$(_get_all_command_vars "$cmd_file")

    while IFS= read -r var; do
        [ -n "$var" ] || continue
        echo "$cmd_vars" | grep -qF "$var"
    done <<< "$template_vars"
}

@test "review-check: all template vars are substituted by command" {
    local cmd_file="$LEGACY_COMMANDS_DIR/review-check.md"
    local template_vars
    template_vars=$(_get_all_template_vars_for_command "review-check")

    local cmd_vars
    cmd_vars=$(_get_all_command_vars "$cmd_file")

    while IFS= read -r var; do
        [ -n "$var" ] || continue
        echo "$cmd_vars" | grep -qF "$var"
    done <<< "$template_vars"
}

@test "review-verify: all template vars are substituted by command" {
    local cmd_file="$LEGACY_COMMANDS_DIR/review-verify.md"
    local template_vars
    template_vars=$(_get_all_template_vars_for_command "review-verify")

    local cmd_vars
    cmd_vars=$(_get_all_command_vars "$cmd_file")

    while IFS= read -r var; do
        [ -n "$var" ] || continue
        echo "$cmd_vars" | grep -qF "$var"
    done <<< "$template_vars"
}

# ----------------------------------------------------------------------
# Test: cmux-launch-procedure.md {WORK_DIR} is substituted by all
#       4 sub-pane commands
# ----------------------------------------------------------------------
@test "mysk-spec substitutes {WORK_DIR} from cmux-launch-procedure" {
    grep -q '{WORK_DIR}' "$COMMANDS_DIR/mysk-spec.md"
}

@test "mysk-review substitutes {WORK_DIR} from cmux-launch-procedure" {
    grep -q '{WORK_DIR}' "$COMMANDS_DIR/mysk-review.md"
}

@test "fixed-spec-draft substitutes {WORK_DIR} from cmux-launch-procedure" {
    grep -q '{WORK_DIR}' "$LEGACY_COMMANDS_DIR/fixed-spec-draft.md"
}

@test "fixed-spec-review substitutes {WORK_DIR} from cmux-launch-procedure" {
    grep -q '{WORK_DIR}' "$LEGACY_COMMANDS_DIR/fixed-spec-review.md"
}

@test "spec-draft substitutes {WORK_DIR} from cmux-launch-procedure" {
    grep -q '{WORK_DIR}' "$LEGACY_COMMANDS_DIR/spec-draft.md"
}

@test "spec-review substitutes {WORK_DIR} from cmux-launch-procedure" {
    grep -q '{WORK_DIR}' "$LEGACY_COMMANDS_DIR/spec-review.md"
}

@test "review-check substitutes {WORK_DIR} from cmux-launch-procedure" {
    grep -q '{WORK_DIR}' "$LEGACY_COMMANDS_DIR/review-check.md"
}

@test "review-verify substitutes {WORK_DIR} from cmux-launch-procedure" {
    grep -q '{WORK_DIR}' "$LEGACY_COMMANDS_DIR/review-verify.md"
}

# ----------------------------------------------------------------------
# Test: no unsubstituted template variables remain in templates
#       Every {VAR} in every template must have a matching sed in at
#       least one command file
# ----------------------------------------------------------------------
@test "no template has vars that lack any substitution in commands" {
    local failures=""
    while IFS= read -r tmpl_file; do
        local tmpl_name
        tmpl_name=$(basename "$tmpl_file")

        # verify-schema.json is not a template with sed substitutions
        [ "$tmpl_name" = "verify-schema.json" ] && continue

        local tmpl_vars
        tmpl_vars=$(extract_template_vars "$tmpl_file")

        [ -z "$tmpl_vars" ] && continue

        while IFS= read -r var; do
            [ -z "$var" ] && continue
            local found=0
            while IFS= read -r cmd_file; do
                # Check sed substitution: s|...{VAR}...|...|
                if grep -q "s|[^|]*${var}[^|]*|" "$cmd_file"; then
                    found=1
                    break
                fi
                # Check natural-language substitution instruction: {VAR}→ or {VAR} ->
                if grep -q "${var}" "$cmd_file"; then
                    found=1
                    break
                fi
            done < <(get_command_files)
            if [ "$found" -eq 0 ]; then
                while IFS= read -r cmd_file; do
                    if grep -q "s|[^|]*${var}[^|]*|" "$cmd_file"; then
                        found=1
                        break
                    fi
                    if grep -q "${var}" "$cmd_file"; then
                        found=1
                        break
                    fi
                done < <(get_legacy_command_files)
            fi
            if [ "$found" -eq 0 ]; then
                failures="${failures} Unsubstituted: ${var} in ${tmpl_name}"
            fi
        done <<< "$tmpl_vars"
    done < <(get_template_files)

    [ -z "$failures" ] || { echo "$failures"; return 1; }
}

# ----------------------------------------------------------------------
# Test: all sed expressions use consistent delimiter (|)
# ----------------------------------------------------------------------
@test "all sed expressions use pipe delimiter" {
    while IFS= read -r cmd_file; do
        # sed patterns should use | as delimiter: s|...|...|g
        # Check no sed with / delimiter for template vars
        run grep -E 's/\{[A-Z_]+\}' "$cmd_file"
        [ "$status" -ne 0 ]
    done < <(get_legacy_command_files)
}
