#!/usr/bin/env bats
# frontmatter.bats - Validate YAML frontmatter of all command files
# Layer 1 static test: no runtime dependencies

load '../helpers/test-common'

# Allowed frontmatter keys
ALLOWED_KEYS="description argument-hint user-invocable"

# ----------------------------------------------------------------------
# Helper: extract all frontmatter keys from a file
# ----------------------------------------------------------------------
_extract_all_fm_keys() {
    local file="$1"
    # awk: count --- delimiters, only print lines between first and second one
    awk '/^---$/{n++; next} n==1{print}' "$file" | sed 's/:.*//' | sort -u
}

# ----------------------------------------------------------------------
# Test: every mysk-*.md in commands/ has frontmatter (two --- delimiters)
# ----------------------------------------------------------------------
@test "every command file has frontmatter delimiters" {
    local count=0
    while IFS= read -r cmd_file; do
        count=$((count + 1))
        # Must have at least two --- lines
        local delimiter_count
        delimiter_count=$(grep -c '^---$' "$cmd_file")
        [ "$delimiter_count" -ge 2 ]
    done < <(get_command_files)
    # Verify we actually tested files
    [ "$count" -gt 0 ]
}

# ----------------------------------------------------------------------
# Test: every command has non-empty description
# ----------------------------------------------------------------------
@test "every command has non-empty description" {
    while IFS= read -r cmd_file; do
        local desc
        desc=$(extract_frontmatter "$cmd_file" "description")
        [ -n "$desc" ]
    done < <(get_command_files)
}

# ----------------------------------------------------------------------
# Test: every command has argument-hint field
# ----------------------------------------------------------------------
@test "every command has argument-hint field" {
    while IFS= read -r cmd_file; do
        local hint
        hint=$(extract_frontmatter "$cmd_file" "argument-hint")
        [ -n "$hint" ]
    done < <(get_command_files)
}

# ----------------------------------------------------------------------
# Test: every command has user-invocable: true
# ----------------------------------------------------------------------
@test "every command has user-invocable: true" {
    while IFS= read -r cmd_file; do
        local val
        val=$(extract_frontmatter "$cmd_file" "user-invocable")
        [ "$val" = "true" ]
    done < <(get_command_files)
}

# ----------------------------------------------------------------------
# Test: no unexpected frontmatter keys
# ----------------------------------------------------------------------
@test "no unexpected frontmatter keys" {
    while IFS= read -r cmd_file; do
        local keys
        keys=$(_extract_all_fm_keys "$cmd_file")
        for key in $keys; do
            local found=0
            local allowed
            for allowed in $ALLOWED_KEYS; do
                [ "$key" = "$allowed" ] && found=1 && break
            done
            [ "$found" -eq 1 ]
        done
    done < <(get_command_files)
}

# ----------------------------------------------------------------------
# Test: public command set and argument-hint values
# ----------------------------------------------------------------------
@test "public command surface is exactly 6 files" {
    local count
    count=$(get_command_files | wc -l | tr -d ' ')
    [ "$count" -eq 6 ]
}

@test "mysk-spec has argument-hint [topic_or_run_id]" {
    local hint
    hint=$(extract_frontmatter "$COMMANDS_DIR/mysk-spec.md" "argument-hint")
    [ "$hint" = "[topic_or_run_id]" ]
}

@test "mysk-implement has argument-hint [run_id]" {
    local hint
    hint=$(extract_frontmatter "$COMMANDS_DIR/mysk-implement.md" "argument-hint")
    [ "$hint" = "[run_id]" ]
}

@test "mysk-issue has argument-hint [run_id]" {
    local hint
    hint=$(extract_frontmatter "$COMMANDS_DIR/mysk-issue.md" "argument-hint")
    [ "$hint" = "[run_id]" ]
}

@test "mysk-review has argument-hint [run_id]" {
    local hint
    hint=$(extract_frontmatter "$COMMANDS_DIR/mysk-review.md" "argument-hint")
    [ "$hint" = "[run_id]" ]
}

@test "mysk-help has empty argument-hint (nashi)" {
    local hint
    hint=$(extract_frontmatter "$COMMANDS_DIR/mysk-help.md" "argument-hint")
    [ "$hint" = "$(printf '\xe3\x81\xaa\xe3\x81\x97')" ]
}

@test "mysk-reset has argument-hint [--force]" {
    local hint
    hint=$(extract_frontmatter "$COMMANDS_DIR/mysk-reset.md" "argument-hint")
    [ "$hint" = "[--force]" ]
}

# ----------------------------------------------------------------------
# Test: description is single line (no embedded newlines)
# ----------------------------------------------------------------------
@test "every command description is single line" {
    while IFS= read -r cmd_file; do
        local desc
        desc=$(extract_frontmatter "$cmd_file" "description")
        # Should not contain newlines
        local line_count
        line_count=$(echo "$desc" | wc -l | tr -d ' ')
        [ "$line_count" -eq 1 ]
    done < <(get_command_files)
}
