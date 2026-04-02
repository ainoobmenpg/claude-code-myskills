#!/usr/bin/env bats
# json-schema.bats - Validate JSON validity and schema structure
# Layer 1 static test: no runtime dependencies

load '../helpers/test-common'

# Path to the python validation helper
_JSON_VALIDATOR="${PROJECT_ROOT}/tests/helpers/validate-json-blocks.py"

# ----------------------------------------------------------------------
# Helper: extract JSON blocks from a markdown file
#         Uses python3 for reliable extraction
# ----------------------------------------------------------------------
_extract_json_blocks() {
    local file="$1"
    python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    text = f.read()
blocks = re.findall(r'\x60\x60\x60json\n(.*?)\x60\x60\x60', text, re.DOTALL)
for i, b in enumerate(blocks):
    print(f'---BLOCK{i+1}---')
    print(b)
" "$file"
}

# Helper: validate a single JSON block (with placeholder substitution)
_validate_json_block() {
    python3 "$_JSON_VALIDATOR" <<< "$1" 2>/dev/null
}

# ----------------------------------------------------------------------
# Test: verify-schema.json is valid JSON
# ----------------------------------------------------------------------
@test "verify-schema.json is valid JSON" {
    is_valid_json "$TEMPLATES_DIR/verify-schema.json"
}

# ----------------------------------------------------------------------
# Test: verify-schema.json has verification_result enum with correct values
# ----------------------------------------------------------------------
@test "verify-schema.json has verification_result enum with passed/failed" {
    local result
    result=$(python3 -c "
import json
with open('$TEMPLATES_DIR/verify-schema.json') as f:
    schema = json.load(f)
enum_values = schema['properties']['verification_result']['enum']
expected = ['passed', 'failed']
assert enum_values == expected, f'Got {enum_values}, expected {expected}'
print('OK')
" 2>&1)
    [ "$result" = "OK" ]
}

# ----------------------------------------------------------------------
# Test: verify-schema.json has result_criteria in definitions
# ----------------------------------------------------------------------
@test "verify-schema.json has result_criteria definitions" {
    python3 -c "
import json
with open('$TEMPLATES_DIR/verify-schema.json') as f:
    schema = json.load(f)
assert 'result_criteria' in schema.get('definitions', {}), 'Missing result_criteria'
assert 'passed' in schema['definitions']['result_criteria']
assert 'failed' in schema['definitions']['result_criteria']
print('OK')
" 2>&1
    [ "$?" -eq 0 ]
}

# ----------------------------------------------------------------------
# Test: all JSON blocks in command files are parseable
# ----------------------------------------------------------------------
@test "JSON blocks in command files are parseable" {
    local failures=""
    while IFS= read -r cmd_file; do
        local basename_
        basename_=$(basename "$cmd_file")
        local block_output
        block_output=$(_extract_json_blocks "$cmd_file")

        [ -z "$block_output" ] && continue

        local current_block=""
        local block_num=0
        while IFS= read -r line; do
            if echo "$line" | grep -q '^---BLOCK[0-9]*---$'; then
                # New block starting
                if [ -n "$current_block" ]; then
                    block_num=$((block_num + 1))
                    if ! _validate_json_block "$current_block"; then
                        failures="${failures}FAIL: ${basename_} block #${block_num}\n"
                    fi
                fi
                current_block=""
            else
                if [ -n "$current_block" ]; then
                    current_block="${current_block}
${line}"
                else
                    current_block="$line"
                fi
            fi
        done <<< "$block_output"

        # Handle last block
        if [ -n "$current_block" ]; then
            block_num=$((block_num + 1))
            if ! _validate_json_block "$current_block"; then
                failures="${failures}FAIL: ${basename_} block #${block_num}\n"
            fi
        fi
    done < <(get_command_files)

    if [ -n "$failures" ]; then
        echo -e "$failures"
        return 1
    fi
}

# ----------------------------------------------------------------------
# Test: all JSON blocks in mysk-workflow.md are parseable
# ----------------------------------------------------------------------
@test "JSON blocks in mysk-workflow.md are parseable" {
    local workflow_file="$COMMANDS_DIR/mysk-workflow.md"
    local failures=""

    local block_output
    block_output=$(_extract_json_blocks "$workflow_file")

    [ -z "$block_output" ] && return 0

    local current_block=""
    local block_num=0
    while IFS= read -r line; do
        if echo "$line" | grep -q '^---BLOCK[0-9]*---$'; then
            if [ -n "$current_block" ]; then
                block_num=$((block_num + 1))
                if ! _validate_json_block "$current_block"; then
                    failures="${failures}FAIL: mysk-workflow.md block #${block_num}\n"
                fi
            fi
            current_block=""
        else
            if [ -n "$current_block" ]; then
                current_block="${current_block}
${line}"
            else
                current_block="$line"
            fi
        fi
    done <<< "$block_output"

    # Handle last block
    if [ -n "$current_block" ]; then
        block_num=$((block_num + 1))
        if ! _validate_json_block "$current_block"; then
            failures="${failures}FAIL: mysk-workflow.md block #${block_num}\n"
        fi
    fi

    if [ -n "$failures" ]; then
        echo -e "$failures"
        return 1
    fi
}

# ----------------------------------------------------------------------
# Test: verify-schema.json has required $schema field
# ----------------------------------------------------------------------
@test "verify-schema.json has dollar-sign schema field" {
    python3 -c "
import json
with open('$TEMPLATES_DIR/verify-schema.json') as f:
    schema = json.load(f)
assert '\$schema' in schema, 'Missing dollar-sign schema field'
assert schema['\$schema'] == 'http://json-schema.org/draft-07/schema#'
print('OK')
" 2>&1
    [ "$?" -eq 0 ]
}

# ----------------------------------------------------------------------
# Test: verify-schema.json has transition_rules in definitions
# ----------------------------------------------------------------------
@test "verify-schema.json has transition_rules" {
    python3 -c "
import json
with open('$TEMPLATES_DIR/verify-schema.json') as f:
    schema = json.load(f)
assert 'transition_rules' in schema.get('definitions', {}), 'Missing transition_rules'
rules = schema['definitions']['transition_rules']['rules']
assert len(rules) > 0, 'No transition rules defined'
print('OK')
" 2>&1
    [ "$?" -eq 0 ]
}
