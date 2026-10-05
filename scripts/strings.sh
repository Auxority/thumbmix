#!/usr/bin/env bash
# Refreshes the app's String Catalog from the code and checks both catalogs are valid JSON. Run it after
# changing user-facing text, and after resolving a catalog merge conflict by taking main's version.
set -euo pipefail
cd "$(dirname "$0")/.."
log=build/strings.log
mkdir -p build

xcodegen generate --quiet
xcodebuild -exportLocalizations -project Thumbmix.xcodeproj -localizationPath build/loc -exportLanguage en \
  > "$log" 2>&1 || { tail -20 "$log" >&2; exit 1; }

for catalog in App/Localizable.xcstrings Core/Sources/ThumbmixCore/Resources/Localizable.xcstrings; do
  # Strict JSON: plutil reads JSON5 and would let a trailing comma from a hand merge through.
  python3 -m json.tool "$catalog" > /dev/null || { echo "$catalog is not valid JSON" >&2; exit 1; }
done
echo "String catalogs: exported and valid"
