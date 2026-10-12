#!/usr/bin/env bash
# Rebuilds the SideStore source from every GitHub Release and force-pushes it as the only commit of the `sidestore`
# branch, served at https://raw.githubusercontent.com/<repo>/sidestore/source.json. A branch of its own because main is
# protected; it holds no code, so its history is worth nothing. Needs GH_TOKEN and a checkout whose origin it can push to.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=${GITHUB_REPOSITORY:-Auxority/thumbmix}

source=$(gh api --paginate "repos/${repo}/releases" | jq -s 'add' | scripts/sidestore-source.sh)
echo "SideStore source lists $(printf '%s' "$source" | jq '.apps[0].versions | length') versions"

# Plumbing, so the checkout (the release's own commit) stays as it is.
blob=$(printf '%s\n' "$source" | git hash-object -w --stdin)
tree=$(printf '100644 blob %s\tsource.json\n' "$blob" | git mktree)
commit=$(git -c user.name="github-actions[bot]" -c user.email="41898282+github-actions[bot]@users.noreply.github.com" \
  commit-tree "$tree" -m "SideStore source, rebuilt from the releases")
git push --force origin "${commit}:refs/heads/sidestore"
