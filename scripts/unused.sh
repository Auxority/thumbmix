#!/usr/bin/env bash
# Unused code (Periphery, .periphery.yml): fails on any unused declaration or needless `public`.
# A false positive gets `// periphery:ignore - <why>` on the line above it.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v periphery > /dev/null || { echo "periphery is missing: brew install periphery" >&2; exit 1; }

# The app's scheme doesn't build Core's unit tests, so code only they use would look unused: index the app
# build and the package build (tests, fake-m32 and m32-probe too) and scan them together.
xcodebuild build-for-testing -project Thumbmix.xcodeproj -scheme Thumbmix -quiet \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd-unused \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=YES INDEX_ENABLE_DATA_STORE=YES
swift build --package-path Core --scratch-path Core/.build/unused --build-tests --enable-index-store --quiet

periphery scan --quiet --index-store-path build/dd-unused/Index.noindex/DataStore \
  "$(find Core/.build/unused -type d -path '*index/store' | head -1)"
echo "periphery: no unused code"
