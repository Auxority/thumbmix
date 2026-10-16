#!/usr/bin/env bash
# Renders Design/strip-icons/icons.py into the app's strip icons, one template SVG image set per desk icon in
# App/Assets.xcassets/StripIcons. Run it after changing a drawing, and commit both.
# `--sheet <file.html>` also writes a review page: every icon large and at the picker's tile size.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 -B - "$@" <<'PY'
import json
import pathlib
import sys

sys.path.insert(0, "Design/strip-icons")
from icons import ICONS

CATALOG = pathlib.Path("App/Assets.xcassets/StripIcons")
OPEN = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" '
        'stroke-width=".9" stroke-linecap="round" stroke-linejoin="round">')
IMAGE_SET = {"images": [{"filename": None, "idiom": "universal"}], "info": {"author": "xcode", "version": 1},
             "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"}}


def svg(icon):
    """The tint is one group at 28% opacity, so overlapping body shapes tint once; outlines and details go on top."""
    body = icon.get("body", "")
    tint, outline = icon.get("tint", body), icon.get("outline", body)
    inner = f'<g fill="#000" stroke="none" opacity=".28">{tint}</g>{outline}{icon.get("cuts", "")}{icon.get("parts", "")}'
    if "rotate" in icon:
        inner = f'<g transform="rotate({icon["rotate"]} 12 12)">{inner}</g>'
    inner += icon.get("fixed", "")
    if "shift" in icon:
        inner = f'<g transform="translate({icon["shift"][0]} {icon["shift"][1]})">{inner}</g>'
    return (OPEN + inner + "</svg>\n").replace("currentColor", "#000")


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, separators=(",", " : ")) + "\n")


CATALOG.mkdir(parents=True, exist_ok=True)
write_json(CATALOG / "Contents.json", {"info": {"author": "xcode", "version": 1}})
for number, icon in ICONS.items():
    name = f"strip-icon-{number:02d}"
    folder = CATALOG / f"{name}.imageset"
    folder.mkdir(exist_ok=True)
    (folder / f"{name}.svg").write_text(svg(icon))
    contents = json.loads(json.dumps(IMAGE_SET))
    contents["images"][0]["filename"] = f"{name}.svg"
    write_json(folder / "Contents.json", contents)
print(f"Rendered {len(ICONS)} strip icons into {CATALOG}")

if "--sheet" in sys.argv:
    path = sys.argv[sys.argv.index("--sheet") + 1]
    cell = '<figure><div class="big">{0}</div><div class="tile">{0}</div><figcaption>{1}</figcaption></figure>'
    cells = "".join(cell.format(svg(icon).replace("#000", "currentColor"), number) for number, icon in ICONS.items())
    style = ("body{background:#000;color:#fff;font:13px -apple-system,sans-serif;display:flex;flex-wrap:wrap;gap:12px}"
             "figure{margin:0;display:flex;flex-direction:column;align-items:center;gap:6px}"
             ".big svg{width:96px;height:96px}.tile svg{width:24px;height:24px}"
             ".big,.tile{background:#1c1c1e;border-radius:10px;padding:8px;display:flex}")
    pathlib.Path(path).write_text(f"<!doctype html><meta charset=utf-8><style>{style}</style>{cells}")
    print(f"Review sheet: {path}")
PY
