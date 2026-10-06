#!/usr/bin/env bash
# Prints the next release version after LAST from the commit messages on stdin (conventional commits),
# or nothing when no commit warrants a release.
#   feat → minor, fix/perf → patch, docs/chore/ci/test/… → no release.
#   A breaking change (`type!:` or a `BREAKING CHANGE:` footer) bumps the major version from 1.0 on;
#   before 1.0 it bumps the minor, because 1.0.0 (and any -rc) is a deliberate, manual release.
set -euo pipefail
last=${1:?usage: next-version.sh LAST_VERSION < commit-messages}
IFS=. read -r major minor patch <<< "$last"

messages=$(cat)
type_line='^(feat|fix|perf)(\([^)]*\))?!?: '
if grep -Eq '^[a-z]+(\([^)]*\))?!: |^BREAKING CHANGE: ' <<< "$messages"; then
  bump=$([ "$major" -eq 0 ] && echo minor || echo major)
elif grep -Eq '^feat(\([^)]*\))?: ' <<< "$messages"; then
  bump=minor
elif grep -Eq "$type_line" <<< "$messages"; then
  bump=patch
else
  exit 0
fi

case $bump in
  major) echo "$((major + 1)).0.0" ;;
  minor) echo "$major.$((minor + 1)).0" ;;
  patch) echo "$major.$minor.$((patch + 1))" ;;
esac
