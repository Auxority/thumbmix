#!/usr/bin/env bash
# Checks sidestore-source.sh against a few releases shaped like GitHub's API returns them. Run by the CI `check`.
set -uo pipefail
cd "$(dirname "$0")" || exit 1
failures=0

releases='[
  {"tag_name": "v0.20.0", "name": "Thumbmix 0.20.0 (build 67)", "draft": false, "published_at": "2026-10-12T09:11:38Z",
   "body": "## What'"'"'s Changed\n* docs: a TODO by @Auxority in https://github.com/Auxority/thumbmix/pull/60\n\n\n**Full Changelog**: https://github.com/Auxority/thumbmix/compare/v0.19.0...v0.20.0",
   "assets": [{"name": "Thumbmix.ipa", "size": 560000,
               "browser_download_url": "https://github.com/Auxority/thumbmix/releases/download/v0.20.0/Thumbmix.ipa"}]},
  {"tag_name": "v0.23.0", "name": "Thumbmix 0.23.0 (build 74)", "draft": false, "published_at": "2026-10-12T14:15:43Z",
   "body": "## What'"'"'s Changed\n* feat: send settings open in a sheet by @Auxority in https://github.com/Auxority/thumbmix/pull/73\n* docs: record the decisions by @Auxority in https://github.com/Auxority/thumbmix/pull/74\n* fix(ui): a \"to Main LR\" pill by @Auxority in https://github.com/Auxority/thumbmix/pull/75\n* feat!: iOS 26 is the minimum by @Auxority in https://github.com/Auxority/thumbmix/pull/69\n* test: one launch per class by @Auxority in https://github.com/Auxority/thumbmix/pull/70\n\n\n**Full Changelog**: https://github.com/Auxority/thumbmix/compare/v0.22.0...v0.23.0",
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
# "What's new": the user-facing PR titles (feat, fix, perf), without their prefix, author and link.
expect "what's new lists the user-facing PR titles" '.apps[0].versions[0].localizedDescription' \
  '"• Send settings open in a sheet\n• A \"to Main LR\" pill\n• iOS 26 is the minimum"'
expect "a version with no user-facing title, or no notes, has no what's new" \
  '[.apps[0].versions[1:][] | has("localizedDescription")]' '[false,false]'

# SideStore refuses an install whose permissions differ from the IPA's Info.plist, so the text must match project.yml.
plist=$(sed -n 's/^ *NSLocalNetworkUsageDescription: //p' ../project.yml)
expect "the privacy text is the app's own" '.apps[0].appPermissions.privacy | keys' '["NSLocalNetworkUsageDescription"]'
expect "the privacy text matches project.yml" '.apps[0].appPermissions.privacy.NSLocalNetworkUsageDescription' \
  "$(jq -cn --arg text "$plist" '$text')"

# The user's pick (2026-10-31), taken by store-screenshots.sh. Face ID iPhone shape (9:19.5): plain URLs, no sizes.
shots='["1-overview","2-eq","3-comp","4-sends","5-dca-members"]'
expect "the screenshots, in the picked order, from main" '.apps[0].screenshots' \
  "$(jq -cn --argjson shots "$shots" \
    '$shots | map("https://raw.githubusercontent.com/Auxority/thumbmix/main/Design/store-screenshots/\(.).png")')"
# The URLs point at main, so the files must be in the repo: an iPhone 17's 1206 x 2622, the shape SideStore rounds.
for shot in $(jq -r '.[]' <<< "$shots"); do
  size=$(sips -g pixelWidth -g pixelHeight "../Design/store-screenshots/$shot.png" 2>/dev/null | awk '/pixel/ { printf "%s ", $2 }')
  if [ "$size" = "1206 2622 " ]; then
    echo "ok   $shot.png is a Face ID iPhone screenshot"
  else
    echo "FAIL $shot.png: expected 1206 x 2622 (iPhone 17), got '${size:-no file}'" >&2
    failures=$((failures + 1))
  fi
done

[ "$failures" -eq 0 ] || { echo "$failures SideStore source check(s) failed" >&2; exit 1; }
echo "SideStore source: all checks passed"
