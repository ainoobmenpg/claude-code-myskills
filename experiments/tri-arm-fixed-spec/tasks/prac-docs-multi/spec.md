# Spec: prac-docs-multi

## Overview

Update the top-level README.md to document the practical test framework fixtures and evaluation criteria.

## Purpose

Improve discoverability of practical test fixtures by adding them to the main README.

## Target File

`README.md`

## In-Scope

- Add a brief mention of practical test fixtures
- Reference PRACTICAL_CRITERIA.md in the related documents section

## Out-of-Scope

- Modifying other documentation files
- Creating new sections unrelated to practical tests
- Changing the basic workflow description

## Constraints

- All changes must be in README.md only
- Preserve existing markdown formatting and structure
- Changes should be minimal and focused

## Acceptance Criteria

1. Practical test fixture names appear in README.md
2. PRACTICAL_CRITERIA.md is referenced in related documents
3. Existing README structure is preserved
4. `bats tests/unit/frontmatter.bats` passes (unchanged)

## Expected Changes

### Change 1: Add to related documents section

In the `## 関連ドキュメント` section, add:

```markdown
- [experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md](experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md) - Practical test evaluation criteria
```

### Change 2: Mention practical fixtures (optional)

Consider adding a brief note about practical test fixtures in an appropriate section, such as:

```markdown
## Practical Test Fixtures

The `experiments/tri-arm-fixed-spec/` directory includes practical test fixtures for validation:
- `prac-docs-1line`: Single-line documentation fix
- `prac-docs-multi`: Multi-line documentation updates
- `prac-code-1`: Simple code changes

See [PRACTICAL_CRITERIA.md](experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md) for evaluation criteria.
```

The exact placement and wording can be adjusted to fit naturally with the existing README flow.
