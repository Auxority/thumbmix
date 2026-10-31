#!/usr/bin/env bash
# Retakes the screenshots SideStore shows (Design/store-screenshots, listed by sidestore-source.sh) with
# UITests/StoreScreenshotsUITests.swift. Run it after a change to those screens, then commit the images.
# The iPhone 17 is a Face ID iPhone (9:19.5), the shape SideStore sizes and rounds by itself.
set -euo pipefail
cd "$(dirname "$0")/.."

phone=$(xcrun simctl list devices available | awk '
  /^-- iOS / { split($3, v, "."); supported = v[1] >= 26 }
  supported && /iPhone 17 \(/ { match($0, /[0-9A-F-]{36}/); print substr($0, RSTART, RLENGTH); exit }')
if [ -z "$phone" ]; then
  echo "No iPhone 17 simulator on iOS 26+: create one in Xcode." >&2
  exit 1
fi

xcrun simctl boot "$phone" 2>/dev/null || true
xcrun simctl bootstatus "$phone" -b > /dev/null
# A tidy status bar, as Apple's own screenshots show it; cleared again however the run ends.
trap 'xcrun simctl status_bar "$phone" clear' EXIT
xcrun simctl status_bar "$phone" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --operatorName "" --batteryState charged --batteryLevel 100

out="$PWD/Design/store-screenshots"
mkdir -p "$out"
export TEST_RUNNER_STORE_SCREENSHOT_DIR="$out"
UI_TEST_DESTINATION="id=$phone" scripts/ui-test.sh StoreScreenshotsUITests
ls "$out"
