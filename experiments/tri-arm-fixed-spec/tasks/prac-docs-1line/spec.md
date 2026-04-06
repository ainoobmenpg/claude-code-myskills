# Spec: prac-docs-1line

## Overview

Update the description field in `commands/mysk-help.md` to accurately reflect that the command displays the current public workflow (4 commands: mysk-spec, mysk-implement, mysk-review, mysk-reset).

## Purpose

The current description may be misleading. Clarify that mysk-help shows the operational workflow rather than listing all available commands.

## Target File

`commands/mysk-help.md`

## In-Scope

- Modify the `description` field in frontmatter
- Preserve all other frontmatter fields
- Maintain valid YAML frontmatter structure

## Out-of-Scope

- Changing argument-hint or user-invocable fields
- Modifying command body
- Updating other command files
- Test file changes

## Constraints

- Description must be a single line (no embedded newlines)
- All frontmatter fields must remain present
- Must pass `tests/unit/frontmatter.bats` validation

## Acceptance Criteria

1. The description clearly states mysk-help displays the current public workflow
2. All 4 frontmatter fields remain present (description, argument-hint, user-invocable, `---` delimiters)
3. `bats tests/unit/frontmatter.bats` passes
4. Only `commands/mysk-help.md` is modified

## Expected Changes

The description should be updated to something like:
"Display the current public workflow commands and their usage."

Or more specifically:
"Show the 4-command public workflow: spec, implement, review, reset."

The exact wording is flexible as long as it clarifies the workflow-focused nature of the command.
