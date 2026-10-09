#!/usr/bin/env bash
# Publishes build/ipa/Thumbmix.ipa as GitHub Release v$VERSION on the checked-out commit, the one that was built.
# Every 0.x and every -rc is a pre-release. Needs GH_TOKEN, VERSION and BUILD_NUMBER.
set -euo pipefail
cd "$(dirname "$0")/.."

# The odd expansion below keeps an empty array safe under `set -u` in macOS's bash 3.2.
prerelease=()
case "$VERSION" in 0.* | *-*) prerelease=(--prerelease) ;; esac
gh release create "v${VERSION}" build/ipa/Thumbmix.ipa \
  --target "$(git rev-parse HEAD)" \
  --title "Thumbmix ${VERSION} (build ${BUILD_NUMBER})" \
  --generate-notes \
  ${prerelease[@]+"${prerelease[@]}"}
