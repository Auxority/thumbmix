#!/usr/bin/env bash
# PreToolUse: before an agent's `git push` or `gh pr create`, lint and look for unused code, so CI's `check` doesn't
# find it ~5 minutes later. Like CI, a branch that changes only Markdown skips it.
command=$(plutil -extract tool_input.command raw -o - - 2> /dev/null) || exit 0
grep -qE '(^|[;&|[:space:]])(git push|gh pr create)([[:space:]]|$)' <<< "$command" || exit 0

cd "$(git rev-parse --show-toplevel)" || exit 0
files=$(git diff --name-only origin/main...HEAD 2> /dev/null)
[ -n "$files" ] && ! grep -qv '\.md$' <<< "$files" && exit 0

if ! output=$(scripts/lint.sh 2>&1 && scripts/unused.sh 2>&1); then
  echo "Fix these before pushing (scripts/lint.sh, scripts/unused.sh):" >&2
  tail -30 <<< "$output" >&2
  exit 2
fi
