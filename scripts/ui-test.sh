#!/usr/bin/env bash
# Runs the UI suite on clones of the iPhone SE simulator, a few test classes at a time. Each test starts its
# own fake desk inside the test runner (UITests/TestDesk.swift), so no fake-m32 needs to run beside it.
# Extra arguments go to xcodebuild, e.g. -only-testing:ThumbmixUITests/EQUITests.
set -euo pipefail
cd "$(dirname "$0")/.."
log=build/ui-test.log

# By id, and on iOS 26+ (the app's minimum): a bare name means the newest runtime, where the SE may be missing.
se=$(xcrun simctl list devices available | awk '
  /^-- iOS / { split($3, v, "."); supported = v[1] >= 26 }
  supported && /iPhone SE \(3rd generation\)/ { match($0, /[0-9A-F-]{36}/); print substr($0, RSTART, RLENGTH); exit }')
destination="${UI_TEST_DESTINATION:-id=$se}"
if [ "$destination" = "id=" ]; then
  echo "No iPhone SE (3rd generation) simulator on iOS 26+: create one in Xcode, or set UI_TEST_DESTINATION." >&2
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
exit "$status"
