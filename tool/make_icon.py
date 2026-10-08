"""Draws the legacy PNG launcher icons (Android 7.x and older).

Android 8+ uses the vector icon in res/drawable/ic_launcher_foreground.xml.
The shapes below mirror it, in its 108-unit coordinate space.

Usage: python -I tool/make_icon.py <android res dir> [preview.png]
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

GREEN = "#1E7A5A"
MINT = "#E3F4EE"
SUN = "#F4B740"

# Legacy icons show the middle 72 units of the 108-unit adaptive canvas.
VISIBLE_FROM, VISIBLE_SIZE = 18, 72
DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
WORK_SIZE = 1024


def draw_icon(size: int) -> Image.Image:
    scale = size / VISIBLE_SIZE

    def p(x: float, y: float) -> tuple[float, float]:
        return ((x - VISIBLE_FROM) * scale, (y - VISIBLE_FROM) * scale)

    def box(x0: float, y0: float, x1: float, y1: float) -> list[float]:
        return [*p(x0, y0), *p(x1, y1)]

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=size * 0.22, fill=GREEN)

    # Speech bubble and its tail.
    d.rounded_rectangle(box(28, 30, 80, 72), radius=14 * scale, fill=MINT)
    d.polygon([p(48, 71), p(37, 82), p(40, 71)], fill=MINT)

    # Rising sun, its rays and the horizon.
    d.pieslice(box(44, 52, 64, 72), 180, 360, fill=SUN)
    width = round(3 * scale)
    for x0, y0, x1, y1 in [(54, 49, 54, 45), (63.2, 52.8, 66, 50), (44.8, 52.8, 42, 50)]:
        d.line([p(x0, y0), p(x1, y1)], fill=SUN, width=width)
        for x, y in [(x0, y0), (x1, y1)]:
            cx, cy = p(x, y)
            d.ellipse([cx - width / 2, cy - width / 2, cx + width / 2, cy + width / 2], fill=SUN)
    d.rounded_rectangle(box(36.5, 62, 71.5, 65), radius=1.5 * scale, fill=GREEN)
    return img


def main() -> None:
    res = Path(sys.argv[1])
    big = draw_icon(WORK_SIZE)
    for density, px in DENSITIES.items():
        big.resize((px, px), Image.LANCZOS).save(res / f"mipmap-{density}" / "ic_launcher.png")
    if len(sys.argv) > 2:
        big.resize((512, 512), Image.LANCZOS).save(sys.argv[2])


if __name__ == "__main__":
    main()
