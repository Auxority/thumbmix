#!/usr/bin/env bash
# Turns GitHub's release list (the API's JSON, on stdin) into a SideStore source (stdout): AltStore's format,
# https://faq.altstore.io/developers/make-a-source. Rebuilt whole every time, so it never drifts from the releases.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=${GITHUB_REPOSITORY:-Auxority/thumbmix}

# SideStore refuses an install whose permissions differ from the IPA's Info.plist: take the text from where it's built.
local_network=$(sed -n 's/^ *NSLocalNetworkUsageDescription: //p' project.yml)
# The files store-screenshots.sh takes, in their numbered order.
screenshots=$(find Design/store-screenshots -name '*.png' | sort | jq -R . | jq -s .)

jq --arg repo "$repo" --arg localNetwork "$local_network" --argjson screenshots "$screenshots" '
  # The release title carries the build number: "Thumbmix 0.23.0 (build 74)".
  def build: capture("\\(build (?<n>[0-9]+)\\)").n;
  def semver: ltrimstr("v") | split("-")[0] | split(".") | map(tonumber);
  # The version notes SideStore shows as what is new, from the notes GitHub generates ("* <PR title> by @<author> in
  # <link>"): only titles a user notices (feat, fix, perf, as next-version.sh counts them), unprefixed; capitalised
  # unless a word like "iOS" leads.
  def whatsNew:
    [ (.body // "") | split("\n")[]
      | capture("^\\* (?:feat|fix|perf)(?:\\([^)]*\\))?!?: (?<title>.+) by @\\S+ in https://\\S+$")
      | .title
      | if test("^[a-z]+( |$)") then (.[:1] | ascii_upcase) + .[1:] else . end
      | "• " + . ]
    | join("\n");
  {
    name: "Thumbmix",
    subtitle: "An iPhone remote for the Midas M32",
    website: "https://github.com/\($repo)",
    nsfw: false,
    apps: [{
      name: "Thumbmix",
      bundleIdentifier: "dev.thumbmix.app",
      developerName: "Auxority",
      subtitle: "An iPhone remote for the Midas M32",
      localizedDescription: "An open-source remote for the Midas M32, built for thumbs: horizontal fader rows you drag anywhere, every common action at most two taps deep.",
      iconURL: "https://raw.githubusercontent.com/\($repo)/main/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
      category: "utilities",
      # Face ID iPhone shots (9:19.5): plain URLs, which SideStore sizes and rounds by itself.
      screenshots: [$screenshots[] | "https://raw.githubusercontent.com/\($repo)/main/\(.)"],
      # Unsigned, so the IPA carries no entitlements; SideStore adds its own when it signs.
      appPermissions: { entitlements: [], privacy: { NSLocalNetworkUsageDescription: $localNetwork } },
      versions: [
        .[]
        | select(.draft | not)
        | { release: ., ipa: (.assets | map(select(.name == "Thumbmix.ipa")) | first) }
        | select(.ipa)
        | {
            # The version inside the IPA is three numbers (build-ipa.sh drops a -rc suffix); the tag shows in full.
            version: (.release.tag_name | semver | map(tostring) | join(".")),
            marketingVersion: (.release.tag_name | ltrimstr("v")),
            buildVersion: (.release.name | build),
            date: .release.published_at,
            downloadURL: .ipa.browser_download_url,
            size: .ipa.size,
            # 0.21.0 (#69) was the first to need iOS 26.
            minOSVersion: (if (.release.tag_name | semver) >= [0, 21, 0] then "26.0" else "17.0" end)
          }
          + (.release | whatsNew | if . == "" then {} else { localizedDescription: . } end)
      ]
      # AltStore takes the first version as the newest.
      | sort_by(.date) | reverse
    }]
  }
'
