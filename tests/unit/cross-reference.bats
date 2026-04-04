#!/usr/bin/env bats
# cross-reference.bats - Validate command<->template cross-reference consistency
# Layer 1 static test: no runtime dependencies

load '../helpers/test-common'

# ----------------------------------------------------------------------
# Helper: extract template file names referenced by a command
# ----------------------------------------------------------------------
_get_template_refs_from_command() {
    local cmd_file="$1"
    grep -oE '(cmux-launch-procedure|fixed-spec-draft-prompt|fixed-spec-draft-monitor|fixed-spec-review-prompt|fixed-spec-review-monitor|spec-draft-prompt|spec-draft-monitor|spec-review-prompt|spec-review-monitor|review-check-prompt|review-check-monitor|review-verify-prompt|review-verify-monitor)\.md' "$cmd_file" | sort -u
}

# ----------------------------------------------------------------------
# Test: each sub-pane command references 3 templates that all exist
# ----------------------------------------------------------------------
@test "legacy fixed-spec-draft references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$LEGACY_COMMANDS_DIR/fixed-spec-draft.md")
    local ref_count
    ref_count=$(echo "$refs" | wc -l | tr -d ' ')

    [ "$ref_count" -eq 3 ]

    for ref in $refs; do
        [ -f "$TEMPLATES_DIR/$ref" ]
    done
}

@test "legacy fixed-spec-review references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$LEGACY_COMMANDS_DIR/fixed-spec-review.md")
    local ref_count
    ref_count=$(echo "$refs" | wc -l | tr -d ' ')

    [ "$ref_count" -eq 3 ]

    for ref in $refs; do
        [ -f "$TEMPLATES_DIR/$ref" ]
    done
}

@test "legacy spec-draft references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$LEGACY_COMMANDS_DIR/spec-draft.md")
    local ref_count
    ref_count=$(echo "$refs" | wc -l | tr -d ' ')

    [ "$ref_count" -eq 3 ]

    for ref in $refs; do
        [ -f "$TEMPLATES_DIR/$ref" ]
    done
}

@test "legacy spec-review references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$LEGACY_COMMANDS_DIR/spec-review.md")
    local ref_count
    ref_count=$(echo "$refs" | wc -l | tr -d ' ')

    [ "$ref_count" -eq 3 ]

    for ref in $refs; do
        [ -f "$TEMPLATES_DIR/$ref" ]
    done
}

@test "legacy review-check references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$LEGACY_COMMANDS_DIR/review-check.md")
    local ref_count
    ref_count=$(echo "$refs" | wc -l | tr -d ' ')

    [ "$ref_count" -eq 3 ]

    for ref in $refs; do
        [ -f "$TEMPLATES_DIR/$ref" ]
    done
}

@test "legacy review-verify references 3 existing templates" {
    local refs
    refs=$(_get_template_refs_from_command "$LEGACY_COMMANDS_DIR/review-verify.md")
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

        if [ "$found" -eq 0 ]; then
            while IFS= read -r cmd_file; do
                if command_references_template "$cmd_file" "$tmpl_name"; then
                    found=1
                    break
                fi
            done < <(get_legacy_command_files)
        fi

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
    done < <(get_legacy_command_files)
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
@test "verify-schema.json is referenced by legacy review-verify command" {
    grep -q 'verify-schema.json' "$LEGACY_COMMANDS_DIR/review-verify.md"
}

# ----------------------------------------------------------------------
# Test: sub-pane commands reference cmux-launch-procedure.md
# ----------------------------------------------------------------------
@test "all legacy sub-pane commands reference cmux-launch-procedure.md" {
    for cmd in fixed-spec-draft fixed-spec-review spec-draft spec-review review-check review-verify; do
        grep -q 'cmux-launch-procedure.md' "$LEGACY_COMMANDS_DIR/${cmd}.md"
    done
}

# ----------------------------------------------------------------------
# Test: public commands route through legacy commands, not cmux directly
# ----------------------------------------------------------------------
@test "public commands do not reference cmux-launch-procedure directly" {
    for cmd in mysk-spec mysk-implement mysk-review mysk-help mysk-reset; do
        run grep -q 'cmux-launch-procedure.md' "$COMMANDS_DIR/${cmd}.md"
        [ "$status" -ne 0 ]
    done
}

@test "public wrapper commands reference legacy command archive" {
    grep -q 'legacy-commands/spec-draft.md' "$COMMANDS_DIR/mysk-spec.md"
    grep -q 'legacy-commands/spec-review.md' "$COMMANDS_DIR/mysk-spec.md"
    grep -q 'legacy-commands/review-check.md' "$COMMANDS_DIR/mysk-review.md"
    grep -q 'legacy-commands/cleanup.md' "$COMMANDS_DIR/mysk-reset.md"
}

@test "legacy archive contains former public commands" {
    local count
    count=$(get_legacy_command_files | wc -l | tr -d ' ')
    [ "$count" -ge 12 ]
}

@test "commands directory no longer contains archived command names" {
    local archived_names="mysk-fixed-spec-draft mysk-fixed-spec-review mysk-spec-draft mysk-spec-review mysk-spec-implement mysk-implement-start mysk-review-check mysk-review-fix mysk-review-diffcheck mysk-review-verify mysk-workflow mysk-cleanup"
    for cmd in $archived_names; do
        [ ! -f "$COMMANDS_DIR/${cmd}.md" ]
    done
}
