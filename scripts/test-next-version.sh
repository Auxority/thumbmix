#!/usr/bin/env bash
# Checks the release bump rules in next-version.sh. Run by the CI `check`.
set -uo pipefail
cd "$(dirname "$0")"
failures=0

expect() {
  local name=$1 last=$2 messages=$3 want=$4 got
  got=$(printf '%b' "$messages" | ./next-version.sh "$last")
  if [ "$got" = "$want" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected '$want', got '$got'" >&2
    failures=$((failures + 1))
  fi
}

expect "a feature bumps the minor version" 0.2.0 "feat: offline mode\n" 0.3.0
expect "a fix bumps the patch version" 0.2.0 "fix: scroll position\n" 0.2.1
expect "a feature outranks a fix" 0.2.3 "fix: a\nfeat: b\nfix: c\n" 0.3.0
expect "a scoped feature counts" 1.4.2 "feat(eq): reset\n" 1.5.0
expect "docs, chore, ci and test publish nothing" 0.2.0 "docs: x\nchore: y\nci: z\ntest: w\n" ""
expect "no commits publish nothing" 0.2.0 "" ""
expect "breaking before 1.0 bumps only the minor version" 0.4.1 "feat!: new protocol\n" 0.5.0
expect "a breaking footer before 1.0 bumps only the minor version" 0.4.1 "fix: x\n\nBREAKING CHANGE: y\n" 0.5.0
expect "breaking from 1.0 bumps the major version" 1.4.2 "fix!: drop X32\n" 2.0.0
expect "a type word mid-sentence is not a type" 0.2.0 "docs: explain the feat: prefix\n" ""

[ "$failures" -eq 0 ] || { echo "$failures release versioning check(s) failed" >&2; exit 1; }
echo "release versioning: all checks passed"
