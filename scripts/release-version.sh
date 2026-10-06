#!/usr/bin/env bash
# Prints this release's version: REQUESTED when given (a manual run, e.g. 1.0.0 or 1.0.0-rc.1), otherwise
# the next version from the commits since the last release. Prints nothing when there is nothing to release.
set -euo pipefail
cd "$(dirname "$0")/.."
requested=${1:-}

if [ -n "$requested" ]; then
  [[ "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] \
    || { echo "Not a semantic version: $requested" >&2; exit 1; }
  echo "$requested"
  exit 0
fi

# Release candidates and the old v0.1.0-<build> tags are pre-releases of a version, not the last version.
last=$(git tag --list 'v*' --sort=-v:refname | grep -Em1 '^v[0-9]+\.[0-9]+\.[0-9]+$' || true)
if [ -n "$last" ]; then
  git log --format='%s%n%b' "$last..HEAD" | scripts/next-version.sh "${last#v}"
else
  # Before the first semantic release, every commit counts against the 0.1.0 the app first shipped as.
  git log --format='%s%n%b' HEAD | scripts/next-version.sh 0.1.0
fi
