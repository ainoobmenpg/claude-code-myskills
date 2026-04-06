# Fixed Spec: prac-docs-multi

## Implementation Target

Update `README.md` to document practical test fixtures.

## Required Changes

### Change 1: Add to related documents section

Find the `## 関連ドキュメント` section and add this line after the existing list items:

```markdown
- [experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md](experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md) - Practical test evaluation criteria
```

The literal text to add is:
`- [experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md](experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md) - Practical test evaluation criteria`

### Change 2: Add practical fixtures section

After the `## 基本フロー` section, add a new section:

```markdown
## Practical Test Fixtures

The `experiments/tri-arm-fixed-spec/` directory includes practical test fixtures:
- `prac-docs-1line`: Single-line documentation fix
- `prac-docs-multi`: Multi-line documentation updates
- `prac-code-1`: Simple code changes

See [PRACTICAL_CRITERIA.md](experiments/tri-arm-fixed-spec/PRACTICAL_CRITERIA.md) for evaluation criteria.
```

The literal text to add is the entire section above.

## Boundary Conditions

- Only README.md is modified
- All existing content remains unchanged
- New content is added without deleting existing sections
- Markdown formatting must be valid

## Non-Targets

- Do NOT modify any other files
- Do NOT change existing section content
- Do NOT remove or reorder existing documentation links

## Acceptance Tests

1. Verify README.md contains the new practical fixtures section
2. Verify PRACTICAL_CRITERIA.md is in the related documents list
3. Run `git diff --name-only` - should only show README.md
4. Verify markdown syntax is valid

## Hidden Tests

Hidden tests will verify:
- No other files were modified
- The new section is properly formatted markdown
- Links are valid and point to existing files
- Existing README sections are unchanged
