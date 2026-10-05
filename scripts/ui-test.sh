#!/usr/bin/env bash
# Runs the UI suite against a freshly started fake-m32, then stops it. The fake keeps every set it
# receives, so a used one fails state-dependent tests: this refuses to run beside one already listening.
# Extra arguments go to xcodebuild, e.g. -only-testing:ThumbmixUITests/ChannelUITests.
set -euo pipefail
cd "$(dirname "$0")/.."
log=build/ui-test.log
fake_log=build/fake-m32.log

# The app under test connects to 127.0.0.1:10023, so the fake can't move to a free port.
# Only the bound socket counts: an app in the simulator also shows up, as a client of 10023.
listener=$({ lsof -nP -iUDP:10023 || true; } | awk '$NF ~ /:10023$/ && $NF !~ /->/ { print $1 " (pid " $2 ")" }' | sort -u)
if [ -n "$listener" ]; then
  echo "UDP 10023 is taken by $listener, probably a used fake-m32. Stop it, then run this again." >&2
  exit 1
fi

# By id: a bare name means the newest runtime, where the SE may be missing or named differently.
se=$(xcrun simctl list devices available | grep "iPhone SE (3rd generation)" | grep -oE '[0-9A-F-]{36}' | head -1 || true)
destination="${UI_TEST_DESTINATION:-id=$se}"
if [ "$destination" = "id=" ]; then
  echo "No iPhone SE (3rd generation) simulator: create one in Xcode, or set UI_TEST_DESTINATION." >&2
  exit 1
fi

mkdir -p build
swift build --package-path Core --product fake-m32 > "$fake_log" 2>&1 || { cat "$fake_log" >&2; exit 1; }
"$(swift build --package-path Core --show-bin-path)/fake-m32" >> "$fake_log" 2>&1 &
fake=$!
trap 'kill "$fake" 2> /dev/null || true' EXIT
for _ in $(seq 100); do
  grep -q "listening" "$fake_log" && break
  kill -0 "$fake" 2> /dev/null || { cat "$fake_log" >&2; exit 1; }
  sleep 0.1
done

xcodegen generate --quiet
echo "Running the UI suite on: $destination (full log: $log)"
status=0
xcodebuild test -project Thumbmix.xcodeproj -scheme Thumbmix -destination "$destination" \
  -collect-test-diagnostics never "$@" > "$log" 2>&1 || status=$?

grep -E ": error: |Test Case .* failed" "$log" | sort -u || true
grep -E "Executed [0-9]+ tests?, with" "$log" | tail -1 || true
grep -E "\*\* TEST " "$log" || true
exit "$status"
