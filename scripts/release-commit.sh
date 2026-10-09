#!/usr/bin/env bash
# Prints the commit to release: main's newest commit whose CI passed on its push, not the one whose CI started
# this run. GitHub keeps only one waiting release run and cancels the older, so after quick merges the surviving
# run may be for an older commit; building the newest green one strands none (#58 on 2026-10-09).
# Needs GH_TOKEN; GITHUB_EVENT_NAME and GITHUB_SHA (main's head) come from Actions.
set -euo pipefail
cd "$(dirname "$0")/.."

# Runs are created in push order, so the newest successful one is main's newest green commit. Not main's head:
# its CI may still run or have failed, and its own completion starts the next release run.
sha=$(gh run list --workflow ci.yml --branch main --event push --status success --limit 1 \
  --json headSha --jq '.[0].headSha // empty')
[ -n "$sha" ] || { echo "No commit on main has passed CI" >&2; exit 1; }

# A manual run means main as it is now: building an older commit could tag 1.0.0 without the last merge.
if [ "${GITHUB_EVENT_NAME:-}" = workflow_dispatch ] && [ "$sha" != "$GITHUB_SHA" ]; then
  echo "CI hasn't passed on main's latest commit $GITHUB_SHA yet; run this again once it has" >&2
  exit 1
fi
echo "$sha"
