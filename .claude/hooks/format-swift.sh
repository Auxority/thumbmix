#!/usr/bin/env bash
# PostToolUse: formats an edited Swift file in this repo with its .swift-format, so lint stays clean.
file=$(plutil -extract tool_input.file_path raw -o - - 2> /dev/null) || exit 0
case "$file" in
  "$CLAUDE_PROJECT_DIR"/*.swift) [ -f "$file" ] && swift format format --in-place "$file" ;;
esac
exit 0
