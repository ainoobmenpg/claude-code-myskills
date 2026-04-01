#!/usr/bin/env bats
# cross-reference.bats - Validate command<->template cross-reference consistency
# Layer 1 static test: no runtime dependencies

load '../helpers/test-common'

# ----------------------------------------------------------------------
# Helper: extract template file names referenced by a command
# ----------------------------------------------------------------------
_get_template_refs_from_command() {
    local cmd_file="$1"
    grep -oE '(cmux-launch-procedure|spec-draft-prompt|spec-draft-monitor|spec-review-prompt|spec-review-monitor|review-check-prompt|review-check-monitor|review-verify-prompt|review-verify-monitor)\.md' "$cmd_file" | sort -u
}

# ----------------------------------------------------------------------
# Test: each sub-pane command references 3 templates that all exist
# ----------------------------------------------------------------------
@test "spec-draft references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$COMMANDS_DIR/mysk-spec-draft.md")
    local ref_count
    ref_count=$(echo "$refs" | wc -l | tr -d ' ')

    [ "$ref_count" -eq 3 ]

    for ref in $refs; do
        [ -f "$TEMPLATES_DIR/$ref" ]
    done
}

@test "spec-review references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$COMMANDS_DIR/mysk-spec-review.md")
    local ref_count
    ref_count=$(echo "$refs" | wc -l | tr -d ' ')

    [ "$ref_count" -eq 3 ]

    for ref in $refs; do
        [ -f "$TEMPLATES_DIR/$ref" ]
    done
}

@test "review-check references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$COMMANDS_DIR/mysk-review-check.md")
    local ref_count
    ref_count=$(echo "$refs" | wc -l | tr -d ' ')

    [ "$ref_count" -eq 3 ]

    for ref in $refs; do
        [ -f "$TEMPLATES_DIR/$ref" ]
    done
}

@test "review-verify references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$COMMANDS_DIR/mysk-review-verify.md")
    local ref_count
    ref_count=$(echo "$refs" | wc -l | tr -d ' ')

    [ "$ref_count" -eq 3 ]

    for ref in $refs; do
        [ -f "$TEMPLATES_DIR/$ref" ]
    done
}

# ----------------------------------------------------------------------
# Test: every template file is referenced by at least one command
# ----------------------------------------------------------------------
@test "every template file is referenced by at least one command" {
    while IFS= read -r tmpl_file; do
        local tmpl_name
        tmpl_name=$(basename "$tmpl_file")
        local found=0

        while IFS= read -r cmd_file; do
            if command_references_template "$cmd_file" "$tmpl_name"; then
                found=1
                break
            fi
        done < <(get_command_files)

        [ "$found" -eq 1 ]
    done < <(get_template_files)
}

# ----------------------------------------------------------------------
# Test: template paths use correct $HOME/.claude/templates/mysk/ prefix
# ----------------------------------------------------------------------
@test "template references use correct path prefix" {
    while IFS= read -r cmd_file; do
        # Lines referencing templates/mysk/ should use $HOME prefix
        # Exception: the for-loop variable $f
        local bad_refs
        bad_refs=$(grep -n 'templates/mysk/' "$cmd_file" | grep -v 'HOME/.claude/templates/mysk/' | grep -v 'templates/mysk/\$f' | grep -v '^$' || true)

        [ -z "$bad_refs" ]
    done < <(get_command_files)
}

# ----------------------------------------------------------------------
# Test: verify-schema.json is referenced by review-verify-prompt
# ----------------------------------------------------------------------
@test "verify-schema.json is referenced by review-verify-prompt" {
    grep -q 'verify-schema.json' "$TEMPLATES_DIR/review-verify-prompt.md"
}

# ----------------------------------------------------------------------
# Test: verify-schema.json is referenced by review-verify-monitor
# ----------------------------------------------------------------------
@test "verify-schema.json is referenced by review-verify-monitor" {
    grep -q 'verify-schema.json' "$TEMPLATES_DIR/review-verify-monitor.md"
}

# ----------------------------------------------------------------------
# Test: verify-schema.json is referenced by review-verify command
# ----------------------------------------------------------------------
@test "verify-schema.json is referenced by review-verify command" {
    grep -q 'verify-schema.json' "$COMMANDS_DIR/mysk-review-verify.md"
}

# ----------------------------------------------------------------------
# Test: sub-pane commands reference cmux-launch-procedure.md
# ----------------------------------------------------------------------
@test "all sub-pane commands reference cmux-launch-procedure.md" {
    for cmd in mysk-spec-draft mysk-spec-review mysk-review-check mysk-review-verify; do
        grep -q 'cmux-launch-procedure.md' "$COMMANDS_DIR/${cmd}.md"
    done
}

# ----------------------------------------------------------------------
# Test: non-subpane commands do not reference cmux templates
# ----------------------------------------------------------------------
@test "non-subpane commands do not reference cmux-launch-procedure" {
    local non_subpane="mysk-spec-revise mysk-spec-implement mysk-implement-start mysk-review-fix mysk-review-diffcheck mysk-workflow mysk-cleanup"
    for cmd in $non_subpane; do
        if [ -f "$COMMANDS_DIR/${cmd}.md" ]; then
            run grep -q 'cmux-launch-procedure.md' "$COMMANDS_DIR/${cmd}.md"
            [ "$status" -ne 0 ]
        fi
    done
}
