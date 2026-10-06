#!/usr/bin/env bash
# Renders Design/AppIcon.svg into the app's 1024 px icon. Run it after changing the SVG, and commit both.
# Needs `brew install librsvg imagemagick`. The PNG is flattened: App Store icons may not have an alpha channel.
set -euo pipefail
cd "$(dirname "$0")/.."
out=App/Assets.xcassets/AppIcon.appiconset/AppIcon.png
rsvg-convert --width 1024 --height 1024 Design/AppIcon.svg | magick - -background black -alpha remove -alpha off "$out"
echo "Rendered $out"
