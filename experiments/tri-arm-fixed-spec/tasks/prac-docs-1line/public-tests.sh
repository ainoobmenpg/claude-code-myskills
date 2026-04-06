#!/usr/bin/env bash

set -euo pipefail

# Practical test for 1-line documentation fix
# CWD: experiments/tri-arm-fixed-spec/

# Verify target file exists
test -f "../../commands/mysk-help.md"

# Verify frontmatter structure
grep -q '^---$' "../../commands/mysk-help.md"
COUNT=$(grep -c '^---$' "../../commands/mysk-help.md")
test "$COUNT" -ge 2

# Verify description field exists and is non-empty
grep -q '^description:' "../../commands/mysk-help.md"
DESC=$(grep '^description:' "../../commands/mysk-help.md" | sed 's/description: *//')
test -n "$DESC"

# Verify description is single line
LINES=$(echo "$DESC" | wc -l | tr -d ' ')
test "$LINES" -eq 1

# Verify all required frontmatter fields exist
grep -q '^description:' "../../commands/mysk-help.md"
grep -q '^argument-hint:' "../../commands/mysk-help.md"
grep -q '^user-invocable:' "../../commands/mysk-help.md"

echo "prac-docs-1line public tests: PASSED"
