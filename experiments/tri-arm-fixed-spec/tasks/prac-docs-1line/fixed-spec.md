# Fixed Spec: prac-docs-1line

## Implementation Target

Update `commands/mysk-help.md` description field.

## Required Change

Replace the current description with:
"Display the current public workflow and usage for mysk commands."

This clarifies that mysk-help shows the operational workflow rather than listing all commands.

## Boundary Conditions

- Only the description field value changes
- All other frontmatter fields remain unchanged
- The `---` delimiters must be preserved
- No whitespace changes outside the description value

## Non-Targets

- Do NOT modify argument-hint field
- Do NOT modify user-invocable field
- Do NOT change command body content
- Do NOT modify any other files

## Acceptance Tests

1. Verify description field contains the updated text
2. Verify all 4 frontmatter fields are present
3. Run `bats tests/unit/frontmatter.bats` - must pass
4. Run `git diff --name-only` - should only show commands/mysk-help.md

## Hidden Tests

Hidden tests will verify:
- No other command files were modified
- The description is exactly one line (no newlines)
- The file remains valid YAML frontmatter
- No unintended whitespace changes
