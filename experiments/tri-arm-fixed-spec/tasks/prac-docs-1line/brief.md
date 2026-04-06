# Task: Fix 1-line comment in command description

## Purpose

Update the description field in `commands/mysk-help.md` to clarify that the command displays the current public workflow (4 commands) rather than listing all 5 commands.

## In-Scope

- Modify the `description` field in `commands/mysk-help.md` frontmatter
- Preserve all other frontmatter fields unchanged
- Ensure the file remains valid YAML frontmatter

## Out-of-Scope

- Changing the command name or argument-hint
- Modifying command body content
- Updating other command files
- Changing test files

## Constraints

- The description must be a single line (no embedded newlines)
- All frontmatter fields must remain present
- The file must pass `tests/unit/frontmatter.bats` validation

## Acceptance Criteria

1. The description field clearly indicates mysk-help shows the current public workflow
2. All existing frontmatter fields are preserved
3. `bats tests/unit/frontmatter.bats` passes after the change
4. Only `commands/mysk-help.md` is modified

## Allowed Paths

See `allowed-paths.txt` for the complete list of modifiable paths.

## Known Pitfalls

- The description test in frontmatter.bats requires a single-line description
- The frontmatter must begin and end with `---` delimiters
- No extra whitespace after field values
