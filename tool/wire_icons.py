#!/usr/bin/env python3
"""Regenerate every platform icon from AppStore/icon.png.

Run: uv run --with pillow python tool/wire_icons.py

Outputs: Windows .ico, Android legacy mipmaps, iOS AppIcon set.
ponytail: Android uses legacy square mipmaps (icon is edge-to-edge art);
add an adaptive-icon foreground/background pair if launcher masking matters.
"""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "AppStore" / "icon.png"

ANDROID = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]


def resized(img: Image.Image, px: int) -> Image.Image:
    return img.resize((px, px), Image.LANCZOS)


def main() -> None:
    src = Image.open(SRC)
    assert src.size == (1024, 1024), src.size
    src = src.convert("RGB")  # iOS forbids alpha; source is already RGB

    ico = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    src.save(ico, format="ICO", sizes=[(s, s) for s in ICO_SIZES])

    for density, px in ANDROID.items():
        out = ROOT / "android/app/src/main/res" / f"mipmap-{density}" / "ic_launcher.png"
        resized(src, px).save(out, format="PNG")

    iconset = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((iconset / "Contents.json").read_text())
    for entry in contents["images"]:
        base = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        resized(src, round(base * scale)).save(iconset / entry["filename"], format="PNG")
    print("icons wired from", SRC)


if __name__ == "__main__":
    main()
