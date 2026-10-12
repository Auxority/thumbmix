#!/usr/bin/env bash
# Checks sidestore-source.sh against a few releases shaped like GitHub's API returns them. Run by the CI `check`.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
failures=0

releases='[
  {"tag_name": "v0.20.0", "name": "Thumbmix 0.20.0 (build 67)", "draft": false, "published_at": "2026-10-12T09:11:38Z",
   "assets": [{"name": "Thumbmix.ipa", "size": 560000,
               "browser_download_url": "https://github.com/Auxority/thumbmix/releases/download/v0.20.0/Thumbmix.ipa"}]},
  {"tag_name": "v0.23.0", "name": "Thumbmix 0.23.0 (build 74)", "draft": false, "published_at": "2026-10-12T14:15:43Z",
   "assets": [{"name": "Thumbmix.ipa", "size": 563622,
               "browser_download_url": "https://github.com/Auxority/thumbmix/releases/download/v0.23.0/Thumbmix.ipa"}]},
  {"tag_name": "v0.24.0", "name": "Thumbmix 0.24.0 (build 80)", "draft": true, "published_at": null, "assets": []},
  {"tag_name": "v0.19.0", "name": "Thumbmix 0.19.0 (build 60)", "draft": false, "published_at": "2026-10-11T08:00:00Z",
   "assets": []},
  {"tag_name": "v0.1.0-1", "name": "Thumbmix 0.1.0-1 (build 1)", "draft": false, "published_at": "2026-10-05T11:31:55Z",
   "assets": [{"name": "Thumbmix.ipa", "size": 247602,
               "browser_download_url": "https://github.com/Auxority/thumbmix/releases/download/v0.1.0-1/Thumbmix.ipa"}]}
]'
source=$(printf '%s' "$releases" | ./sidestore-source.sh)

expect() {
  local name=$1 filter=$2 want=$3 got
  got=$(printf '%s' "$source" | jq -c "$filter" 2>&1)
  if [ "$got" = "$want" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected $want, got $got" >&2
    failures=$((failures + 1))
  fi
}

expect "one app, the one the IPA builds" '[.apps[].bundleIdentifier]' '["dev.thumbmix.app"]'
expect "newest version first; drafts and releases without an IPA left out" \
  '[.apps[0].versions[].version]' '["0.23.0","0.20.0","0.1.0"]'
expect "a suffixed tag shows in full but keeps the IPA's own version" '.apps[0].versions[2] | [.version, .marketingVersion]' \
  '["0.1.0","0.1.0-1"]'
expect "the build number is the release title's" '[.apps[0].versions[].buildVersion]' '["74","67","1"]'
expect "each version downloads its own release's IPA" '.apps[0].versions[0].downloadURL' \
  '"https://github.com/Auxority/thumbmix/releases/download/v0.23.0/Thumbmix.ipa"'
expect "size and date come from the release" '.apps[0].versions[0] | [.size, .date]' '[563622,"2026-10-12T14:15:43Z"]'
expect "0.21.0 onward needs iOS 26, earlier ones iOS 17" '[.apps[0].versions[].minOSVersion]' '["26.0","17.0","17.0"]'
expect "an unsigned IPA has no entitlements" '.apps[0].appPermissions.entitlements' '[]'
expect "a source says whether it's NSFW" '.nsfw' 'false'

# SideStore refuses an install whose permissions differ from the IPA's Info.plist, so the text must match project.yml.
plist=$(sed -n 's/^ *NSLocalNetworkUsageDescription: //p' ../project.yml)
expect "the privacy text is the app's own" '.apps[0].appPermissions.privacy | keys' '["NSLocalNetworkUsageDescription"]'
expect "the privacy text matches project.yml" '.apps[0].appPermissions.privacy.NSLocalNetworkUsageDescription' \
  "$(jq -cn --arg text "$plist" '$text')"

[ "$failures" -eq 0 ] || { echo "$failures SideStore source check(s) failed" >&2; exit 1; }
echo "SideStore source: all checks passed"
