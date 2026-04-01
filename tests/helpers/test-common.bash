#!/usr/bin/env bash
# Shared test utilities for mysk tests

_PROJECT_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${_PROJECT_HELPERS_DIR}/../.." && pwd)"
COMMANDS_DIR="$PROJECT_ROOT/commands"
TEMPLATES_DIR="$PROJECT_ROOT/templates/mysk"

# Get all command files
get_command_files() {
    find "$COMMANDS_DIR" -name 'mysk-*.md' -type f | sort
}

# Get all template files
get_template_files() {
    find "$TEMPLATES_DIR" -type f | sort
}

# Extract frontmatter from a markdown file
# Usage: extract_frontmatter <file> <key>
extract_frontmatter() {
    local file="$1" key="$2"
    sed -n "/^---$/,/^---$/p" "$file" | grep "^${key}:" | sed "s/^${key}: *//" | tr -d '"' | tr -d "'"
}

# Check if a command file references a template
command_references_template() {
    local cmd_file="$1" template_name="$2"
    grep -q "$template_name" "$cmd_file"
}

# Extract all {VARIABLE} tokens from a file
extract_template_vars() {
    local file="$1"
    grep -oE '\{[A-Z_]+\}' "$file" | sort -u
}

# Extract sed substitution variable names from a command file
# Looks for patterns like: s|{VAR}|value|g
extract_substituted_vars() {
    local file="$1"
    grep -oE 's\|[^|]*\{([A-Z_]+)\}[^|]*\|' "$file" | grep -oE '\{[A-Z_]+\}' | sort -u
}

# Create a temporary run directory structure
create_mock_run_dir() {
    local base_dir="$1" run_id="$2"
    local run_dir="$base_dir/$run_id"
    mkdir -p "$run_dir"
    echo "$run_dir"
}

# Validate JSON with jq
is_valid_json() {
    jq . "$1" >/dev/null 2>&1
}

# Check frontmatter has required fields
check_frontmatter_fields() {
    local file="$1"
    local has_desc=0 has_arg=0 has_invocable=0
    local in_fm=0

    while IFS= read -r line; do
        if [ "$line" = "---" ]; then
            if [ $in_fm -eq 0 ]; then
                in_fm=1
            else
                break
            fi
            continue
        fi
        if [ $in_fm -eq 1 ]; then
            case "$line" in
                description:*) has_desc=1 ;;
                argument-hint:*) has_arg=1 ;;
                user-invocable:*) has_invocable=1 ;;
            esac
        fi
    done < "$file"

    echo "$has_desc $has_arg $has_invocable"
}
