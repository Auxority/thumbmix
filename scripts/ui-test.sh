#!/usr/bin/env bash
# Runs the UI suite on clones of the iPhone SE simulator, a few test classes at a time. Each test starts its
# own fake desk inside the test runner (UITests/TestDesk.swift), so no fake-m32 needs to run beside it.
#   scripts/ui-test.sh                         the whole suite, on clones
#   scripts/ui-test.sh EQUITests/testX ...     only those tests (or classes), one at a time on the SE itself
#   scripts/ui-test.sh --serial                the whole suite on the SE itself, when cloning fails
# Other arguments starting with - go to xcodebuild. Screenshots land in build/screens; a failed run's result bundle
# and log are kept in build/ui-test-failed/<time>. A run whose first test hasn't started after 2 minutes has hung
# (CLAUDE.md, "A hung UI run") and is stopped (exit 2); a failed run during which the Mac slept exits 3.
set -euo pipefail
cd "$(dirname "$0")/.."
log=build/ui-test.log
results=build/ui-test.xcresult

# By id, and on iOS 26+ (the app's minimum): a bare name means the newest runtime, where the SE may be missing.
se=$(xcrun simctl list devices available | awk '
  /^-- iOS / { split($3, v, "."); supported = v[1] >= 26 }
  supported && /iPhone SE \(3rd generation\)/ { match($0, /[0-9A-F-]{36}/); print substr($0, RSTART, RLENGTH); exit }')
destination="${UI_TEST_DESTINATION:-id=$se}"
if [ "$destination" = "id=" ]; then
  echo "No iPhone SE (3rd generation) simulator on iOS 26+: create one in Xcode, or set UI_TEST_DESTINATION." >&2
  exit 1
fi

# The odd expansions below keep empty arrays safe under `set -u` in macOS's bash 3.2.
only=()
passthrough=()
serial=false
for arg in "$@"; do
  case "$arg" in
    --serial) serial=true ;;
    -*) passthrough+=("$arg") ;;
    *) only+=("-only-testing:ThumbmixUITests/$arg") ;;
  esac
done
[ ${#only[@]} -gt 0 ] && serial=true
if $serial; then
  parallel=(-parallel-testing-enabled NO)
else
  parallel=(-parallel-testing-enabled YES -parallel-testing-worker-count "${UI_TEST_WORKERS:-3}")
fi

mkdir -p build/screens
rm -rf "$results"
export TEST_RUNNER_SCREENSHOT_DIR="$PWD/build/screens"
xcodegen generate --quiet
echo "Running the UI tests on: $destination (full log: $log)"
started=$(date '+%Y-%m-%d %H:%M:%S')
xcodebuild test -project Thumbmix.xcodeproj -scheme Thumbmix -destination "$destination" "${parallel[@]}" \
  -collect-test-diagnostics never -resultBundlePath "$results" ${only[@]+"${only[@]}"} ${passthrough[@]+"${passthrough[@]}"} > "$log" 2>&1 &
run=$!

# Building takes up to a minute or two; the 2 minutes start once the build has finished.
waited=0
until grep -qE "Test [Cc]ase .* (started|passed|failed)|\*\* TEST (SUCCEEDED|FAILED|EXECUTE)" "$log" 2>/dev/null; do
  kill -0 "$run" 2>/dev/null || break
  if grep -q "Testing started" "$log" 2>/dev/null; then waited=$((waited + 5)); fi
  if [ "$waited" -ge 120 ]; then
    kill "$run" 2>/dev/null || true
    echo "No test started within 2 minutes of the build: the run hung and was stopped. See CLAUDE.md, \"A hung UI run\"." >&2
    exit 2
  fi
  sleep 5
done
status=0
wait "$run" || status=$?

grep -E ": error: |Test [Cc]ase .* failed" "$log" | sort -u || true
# Counted from the result bundle: on clones, xcodebuild's own lines cut test lines in half, so the log undercounts.
summary=$(xcrun xcresulttool get test-results summary --path "$results" 2>/dev/null || true)
count() { printf '%s\n' "$summary" | sed -nE "s/^  \"$1\" : ([0-9]+),?$/\1/p"; }
if [ -n "$summary" ]; then echo "$(count passedTests) passed, $(count failedTests) failed, $(count skippedTests) skipped"; fi
# The log can lose a failure's message the same way; the bundle keeps it.
printf '%s\n' "$summary" | jq -r '.testFailures[]? | "\(.testIdentifierString): \(.failureText)"' 2>/dev/null || true
grep -E "\*\* TEST " "$log" || true

# The next run deletes the bundle, and a flake may not come back: keep a failed run's evidence.
if [ "$status" -ne 0 ] && [ -d "$results" ]; then
  kept="build/ui-test-failed/$(date '+%Y-%m-%d-%H%M%S')"
  mkdir -p "$kept"
  cp -R "$results" "$log" "$kept/"
  echo "Kept this run's result bundle and log in $kept (open the .xcresult in Xcode for screenshots)."
fi

# A Mac that sleeps mid-run (lid closed on battery) stalls every running test for 15+ minutes, which then fail
# with "Timed out while synthesizing event": no app failure, so say so instead of leaving it to be guessed.
if [ "$status" -ne 0 ]; then
  slept=$(pmset -g log | awk -v since="$started" '$1 " " $2 >= since && /Entering Sleep state/ { print $2; exit }')
  if [ -n "$slept" ]; then
    echo "The Mac slept at $slept during the run (lid closed?), so these failures say nothing about the app. Keep it awake and run again." >&2
    exit 3
  fi
fi
exit "$status"
