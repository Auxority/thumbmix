#!/usr/bin/env bash
# Builds an unsigned Thumbmix.ipa. SideStore re-signs it with your free Apple ID on install,
# so no developer account or signing identity is needed here.
# BUILD_NUMBER (optional) becomes CFBundleVersion, so every CI release is newer than the last.
set -euo pipefail
cd "$(dirname "$0")/.."
build_number="${BUILD_NUMBER:-1}"
[[ "$build_number" =~ ^[0-9]+$ ]] || { echo "BUILD_NUMBER must be a positive integer, got: $build_number" >&2; exit 2; }

xcodegen generate
rm -rf build/ipa
xcodebuild archive \
  -project Thumbmix.xcodeproj -scheme Thumbmix -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/ipa/Thumbmix.xcarchive \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  CURRENT_PROJECT_VERSION="$build_number"
mkdir -p build/ipa/Payload
cp -R build/ipa/Thumbmix.xcarchive/Products/Applications/Thumbmix.app build/ipa/Payload/
(cd build/ipa && zip -qr Thumbmix.ipa Payload)
echo "Built build/ipa/Thumbmix.ipa"
