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

# New Core text arrives as an empty entry, which SwiftPM drops (the app would show the raw key; LocalizationTests
# fails). Its key is the English text, so it becomes the English value, in Xcode's own layout to keep diffs clean.
python3 - Core/Sources/ThumbmixCore/Resources/Localizable.xcstrings <<'PY'
import json, sys
from collections import OrderedDict
path = sys.argv[1]
catalog = json.load(open(path), object_pairs_hook=OrderedDict)
filled = [key for key, entry in catalog["strings"].items() if "en" not in entry.get("localizations", {})]
for key in filled:
    catalog["strings"][key].setdefault("localizations", OrderedDict())["en"] = {
        "stringUnit": {"state": "translated", "value": key}}
if filled:
    open(path, "w").write(json.dumps(catalog, indent=2, ensure_ascii=False, separators=(",", " : ")))
    print(f"Core catalog: English filled in for {len(filled)} new string(s)")
PY

for catalog in App/Localizable.xcstrings Core/Sources/ThumbmixCore/Resources/Localizable.xcstrings; do
  # Strict JSON: plutil reads JSON5 and would let a trailing comma from a hand merge through.
  python3 -m json.tool "$catalog" > /dev/null || { echo "$catalog is not valid JSON" >&2; exit 1; }
done
echo "String catalogs: exported and valid"
