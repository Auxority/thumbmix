#!/usr/bin/env bash
# PostToolUse: formats an edited Swift file in this repo with its .swift-format, so lint stays clean.
# The repo is found from git, not $CLAUDE_PROJECT_DIR: a session started in a parent folder or moved
# into a worktree has a project dir outside this checkout.
file=$(plutil -extract tool_input.file_path raw -o - - 2> /dev/null) || exit 0
root=$(git rev-parse --show-toplevel 2> /dev/null) || exit 0
case "$file" in
  "$root"/*.swift) [ -f "$file" ] && swift format format --in-place "$file" ;;
esac
exit 0
