"""Writes the strip icons in icons.py to the app's asset catalog, one template image set per desk icon.

    python3 Design/strip-icons/generate.py                 # App/Assets.xcassets/StripIcons
    python3 Design/strip-icons/generate.py --sheet out.html # also a review sheet: every icon large and at tile size
"""
import json
import pathlib
import sys

sys.dont_write_bytecode = True  # no __pycache__ beside the design files
from icons import ICONS  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = ROOT / "App/Assets.xcassets/StripIcons"
OPEN = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000" '
        'stroke-width=".9" stroke-linecap="round" stroke-linejoin="round">')
IMAGE_SET = {"images": [{"filename": None, "idiom": "universal"}], "info": {"author": "xcode", "version": 1},
             "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"}}
FOLDER = {"info": {"author": "xcode", "version": 1}}


def svg(icon):
    """The tint is one group at 28% opacity, so overlapping body shapes tint once; outlines and details go on top."""
    body = icon.get("body", "")
    tint, outline = icon.get("tint", body), icon.get("outline", body)
    inner = (f'<g fill="#000" stroke="none" opacity=".28">{tint}</g>{outline}'
             f'{icon.get("cuts", "")}{icon.get("parts", "")}')
    if "rotate" in icon:
        inner = f'<g transform="rotate({icon["rotate"]} 12 12)">{inner}</g>'
    inner += icon.get("fixed", "")
    if "shift" in icon:
        inner = f'<g transform="translate({icon["shift"][0]} {icon["shift"][1]})">{inner}</g>'
    return (OPEN + inner + "</svg>\n").replace("currentColor", "#000")


def image_name(number):
    return f"strip-icon-{number:02d}"


def write_catalog():
    CATALOG.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text(json.dumps(FOLDER, indent=2, separators=(",", " : ")) + "\n")
    for number, icon in ICONS.items():
        folder = CATALOG / f"{image_name(number)}.imageset"
        folder.mkdir(exist_ok=True)
        (folder / f"{image_name(number)}.svg").write_text(svg(icon))
        contents = json.loads(json.dumps(IMAGE_SET))
        contents["images"][0]["filename"] = f"{image_name(number)}.svg"
        (folder / "Contents.json").write_text(json.dumps(contents, indent=2, separators=(",", " : ")) + "\n")
    print(f"wrote {len(ICONS)} image sets to {CATALOG.relative_to(ROOT)}")


def write_sheet(path):
    cell = ('<figure><div class="big">{svg}</div><div class="tile">{svg}</div>'
            '<figcaption>{number}</figcaption></figure>')
    cells = "".join(cell.format(svg=svg(icon).replace("#000", "currentColor"), number=number)
                    for number, icon in ICONS.items())
    style = ("body{background:#000;color:#fff;font:13px -apple-system,sans-serif;display:flex;flex-wrap:wrap;gap:12px}"
             "figure{margin:0;display:flex;flex-direction:column;align-items:center;gap:6px}"
             ".big svg{width:96px;height:96px}.tile svg{width:24px;height:24px}"
             ".big,.tile{background:#1c1c1e;border-radius:10px;padding:8px;display:flex}")
    pathlib.Path(path).write_text(f"<!doctype html><meta charset=utf-8><style>{style}</style>{cells}")
    print(f"wrote {path}")


if __name__ == "__main__":
    write_catalog()
    if "--sheet" in sys.argv:
        write_sheet(sys.argv[sys.argv.index("--sheet") + 1])
