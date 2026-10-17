#!/usr/bin/env bash
# Unused code: `swiftlint analyze` (unused_declaration, .swiftlint.yml) fails on a declaration nothing references.
# It reads the compiler commands from clean builds, so both builds below start from scratch (about 2 minutes).
set -euo pipefail
cd "$(dirname "$0")/.."

command -v swiftlint > /dev/null || { echo "swiftlint is missing: brew install swiftlint" >&2; exit 1; }
logs=build/unused
rm -rf "$logs"
mkdir -p "$logs"

# The app's scheme doesn't build Core's unit tests: log both builds, so code only those tests use counts as used.
xcodebuild clean build-for-testing -project Thumbmix.xcodeproj -scheme Thumbmix \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd-unused CODE_SIGNING_ALLOWED=NO \
  > "$logs/app.log" || { tail -20 "$logs/app.log" >&2; exit 1; }
swift build --package-path Core --scratch-path "$logs/core" --build-tests -v > "$logs/core.log" 2>&1 \
  || { tail -20 "$logs/core.log" >&2; exit 1; }
cat "$logs/app.log" "$logs/core.log" > "$logs/all.log"

swiftlint analyze --strict --quiet --compiler-log-path "$logs/all.log"
echo "swiftlint analyze: no unused code"
