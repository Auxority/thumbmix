#!/usr/bin/env bash
# Runs the UI suite on clones of the iPhone SE simulator, a few test classes at a time. Each test starts its
# own fake desk inside the test runner (UITests/TestDesk.swift), so no fake-m32 needs to run beside it.
# Extra arguments go to xcodebuild, e.g. -only-testing:ThumbmixUITests/EQUITests.
set -euo pipefail
cd "$(dirname "$0")/.."
log=build/ui-test.log
glass_log=build/ui-test-glass.log

# By id: a bare name means the newest runtime, where the SE may be missing or named differently.
se=$(xcrun simctl list devices available | grep "iPhone SE (3rd generation)" | grep -oE '[0-9A-F-]{36}' | head -1 || true)
destination="${UI_TEST_DESTINATION:-id=$se}"
if [ "$destination" = "id=" ]; then
  echo "No iPhone SE (3rd generation) simulator: create one in Xcode, or set UI_TEST_DESTINATION." >&2
  exit 1
fi

mkdir -p build
xcodegen generate --quiet
echo "Running the UI suite on: $destination (full log: $log)"
status=0
xcodebuild test -project Thumbmix.xcodeproj -scheme Thumbmix -destination "$destination" \
  -parallel-testing-enabled YES -parallel-testing-worker-count "${UI_TEST_WORKERS:-3}" \
  -collect-test-diagnostics never "$@" > "$log" 2>&1 || status=$?

grep -E ": error: |Test [Cc]ase .* failed" "$log" | sort -u || true
grep -E "Executed [0-9]+ tests?, with|Test session results" "$log" | tail -1 || true
grep -E "\*\* TEST " "$log" || true

# iOS 26+ wraps toolbar buttons in grey glass that iOS 17 doesn't draw: only a newer SE catches it coming back.
if [ $# -eq 0 ] && [ -z "${UI_TEST_DESTINATION:-}" ]; then
  glass_se=$(xcrun simctl list devices available | awk '
    /^-- iOS / { split($3, v, "."); newer = v[1] >= 26 }
    newer && /iPhone SE \(3rd generation\)/ { match($0, /[0-9A-F-]{36}/); print substr($0, RSTART, RLENGTH); exit }')
  if [ -n "$glass_se" ]; then
    echo "Checking for toolbar glass on the iOS 26+ SE (full log: $glass_log)"
    xcodebuild test -project Thumbmix.xcodeproj -scheme Thumbmix -destination "id=$glass_se" \
      -only-testing:ThumbmixUITests/BlackButtonsUITests -collect-test-diagnostics never > "$glass_log" 2>&1 || status=$?
    grep -E ": error: |\*\* TEST " "$glass_log" || true
  else
    echo "No iPhone SE (3rd generation) on iOS 26+: toolbar glass goes unchecked." >&2
  fi
fi
exit "$status"
