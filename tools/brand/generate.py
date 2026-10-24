"""Generates every Zapline icon and banner from one geometric definition.

    python -I tools/brand/generate.py [--preview]

The mark: an amber "Z" whose diagonal is a lightning bolt (the zap, channel
switching) and whose base runs on into a line ending in a dot (the line, a
playhead on a timeline). The wordmark is drawn from strokes defined here,
so the logo depends on no font licence. Everything is supersampled and
downscaled for clean edges.
"""

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps" / "zapline"

GROUND = (11, 14, 19)
SURFACE = (20, 25, 34)
AMBER = (245, 184, 65)
TEXT = (238, 242, 247)

SS = 4  # supersampling factor


# ---------------------------------------------------------------- drawing


def _stroke(draw, points, width, color):
    """Polyline with round caps and joins."""
    for a, b in zip(points, points[1:]):
        draw.line([a, b], fill=color, width=round(width))
    r = width / 2
    for x, y in points:
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def _mark(draw, cx, cy, size, color=AMBER):
    """The Z-zap-line mark centred on (cx, cy), `size` = its height."""
    s = size / 1000
    w = 118 * s

    def p(x, y):
        return (cx + (x - 500) * s, cy + (y - 500) * s)

    # Top bar, lightning diagonal (with its zig), bottom bar.
    _stroke(draw, [p(150, 80), p(720, 80), p(400, 470), p(600, 470),
                   p(220, 920)], w, color)
    _stroke(draw, [p(220, 920), p(690, 920)], w, color)
    # The playhead dot at the end of the line.
    r = 74 * s
    x, y = p(850, 920)
    draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


# Wordmark: lowercase geometric letters on an x-height of 1.
def _glyph(draw, ch, x, base, xh, w, color):
    """Draws one letter with its top-left at (x, base - xh); returns advance."""
    top = base - xh

    def pt(u, v):
        return (x + u * xh, top + v * xh)

    def ring(u, v, r, start=0, end=360):
        box = [x + (u - r) * xh, top + (v - r) * xh,
               x + (u + r) * xh, top + (v + r) * xh]
        # PIL draws arc width inwards; widen the box by half the stroke.
        h = w / 2
        box = [box[0] - h, box[1] - h, box[2] + h, box[3] + h]
        draw.arc(box, start, end, fill=color, width=round(w))

    if ch == "z":
        _stroke(draw, [pt(0, 0), pt(0.78, 0), pt(0, 1), pt(0.78, 1)], w, color)
        return 0.78
    if ch == "a":
        ring(0.46, 0.5, 0.46)
        _stroke(draw, [pt(0.92, 0), pt(0.92, 1)], w, color)
        return 0.92
    if ch == "p":
        ring(0.46, 0.5, 0.46)
        _stroke(draw, [pt(0, 0), pt(0, 1.42)], w, color)
        return 0.92
    if ch == "l":
        _stroke(draw, [pt(0, -0.48), pt(0, 1)], w, color)
        return 0
    if ch == "i":
        _stroke(draw, [pt(0, 0), pt(0, 1)], w, color)
        r = w * 0.62
        cx, cy = pt(0, -0.36)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
        return 0
    if ch == "n":
        _stroke(draw, [pt(0, 0), pt(0, 1)], w, color)
        ring(0.41, 0.41, 0.41, 180, 360)
        _stroke(draw, [pt(0.82, 0.41), pt(0.82, 1)], w, color)
        return 0.82
    if ch == "e":
        ring(0.47, 0.5, 0.47, 28, 360)
        _stroke(draw, [pt(0.0, 0.5), pt(0.94, 0.5)], w, color)
        return 0.94
    raise ValueError(ch)


def _wordmark(draw, x, base, xh, colors):
    """'zapline' with 'zap' and 'line' in their own colours; returns width."""
    w = xh * 0.17
    gap = xh * 0.3
    start = x
    for i, ch in enumerate("zapline"):
        color = colors[0] if i < 3 else colors[1]
        x += _glyph(draw, ch, x, base, xh, w, color) * xh + gap
    return x - gap - start


def _wordmark_width(xh):
    img = Image.new("RGB", (10, 10))
    return _wordmark(ImageDraw.Draw(img), 0, 0, xh, (TEXT, TEXT))


# ---------------------------------------------------------------- assets


def _canvas(w, h, color=None):
    mode = "RGBA" if color is None else "RGB"
    img = Image.new(mode, (w * SS, h * SS), color or (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def _down(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def icon_square(px, rounded=True, padding=0.0):
    """Full icon: dark tile and mark. `rounded` for platforms that don't
    mask icons themselves (Android legacy, macOS, Windows, Linux)."""
    n = px * SS
    img, d = _canvas(px, px)
    inset = round(n * padding)
    box = [inset, inset, n - inset, n - inset]
    if rounded:
        d.rounded_rectangle(box, radius=round((n - 2 * inset) * 0.22),
                            fill=GROUND)
    else:
        d.rectangle(box, fill=GROUND)
    _mark(d, n / 2, n / 2, (n - 2 * inset) * 0.56)
    return _down(img, px, px)


def adaptive_foreground(px):
    """Android adaptive icon foreground: mark inside the 66% safe zone."""
    n = px * SS
    img, d = _canvas(px, px)
    _mark(d, n / 2, n / 2, n * 0.40)
    return _down(img, px, px)


def tv_banner(w, h):
    """Android TV / Fire TV launcher banner with the app name (TV-BN)."""
    img, d = _canvas(w, h, GROUND)
    W, H = w * SS, h * SS
    mark = H * 0.40
    xh = H * 0.15
    words = _wordmark_width(xh)
    gap = H * 0.12
    total = mark * 0.9 + gap + words
    left = (W - total) / 2
    _mark(d, left + mark * 0.45, H / 2, mark)
    _wordmark(d, left + mark * 0.9 + gap, H / 2 + xh / 2, xh, (AMBER, TEXT))
    return _down(img, w, h)


def lockup(w, h):
    """Mark + wordmark on the dark ground, for README and stores."""
    return tv_banner(w, h)


# ---------------------------------------------------------------- writing


def save(img, path, rgb=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    if rgb and img.mode == "RGBA":
        bg = Image.new("RGB", img.size, GROUND)
        bg.paste(img, mask=img.split()[3])
        img = bg
    img.save(path)
    print("wrote", path.relative_to(ROOT))


def android():
    res = APP / "android" / "app" / "src" / "main" / "res"
    for density, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                        "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(icon_square(px), res / f"mipmap-{density}" / "ic_launcher.png")
        save(adaptive_foreground(round(px * 108 / 48)),
             res / f"mipmap-{density}" / "ic_launcher_foreground.png")
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android='
        '"http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n', encoding="utf-8")
    values = res / "values" / "ic_launcher_background.xml"
    values.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#0B0E13</color>\n'
        '</resources>\n', encoding="utf-8")
    # TV banner: 320x180 at xhdpi, plus a sharper xxhdpi version.
    save(tv_banner(320, 180), res / "drawable-xhdpi" / "banner.png", rgb=True)
    save(tv_banner(480, 270), res / "drawable-xxhdpi" / "banner.png", rgb=True)
    old = res / "drawable" / "banner.xml"
    if old.exists():
        old.unlink()
        print("removed", old.relative_to(ROOT))


def ios():
    folder = APP / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = json.loads((folder / "Contents.json").read_text())
    for entry in contents["images"]:
        name = entry.get("filename")
        if not name:
            continue
        size = float(entry["size"].split("x")[0])
        scale = int(entry["scale"].rstrip("x"))
        px = round(size * scale)
        # iOS masks icons itself and rejects transparency: square, opaque.
        save(icon_square(px, rounded=False), folder / name, rgb=True)


def macos():
    folder = APP / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for f in folder.glob("app_icon_*.png"):
        px = int(f.stem.split("_")[-1])
        # macOS icons carry their own rounded tile with a margin.
        save(icon_square(px, padding=0.1), f)


def windows():
    path = APP / "windows" / "runner" / "resources" / "app_icon.ico"
    big = icon_square(256)
    big.save(path, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print("wrote", path.relative_to(ROOT))


def web():
    w = APP / "web"
    save(icon_square(32), w / "favicon.png")
    save(icon_square(192), w / "icons" / "Icon-192.png")
    save(icon_square(512), w / "icons" / "Icon-512.png")
    save(icon_square(192, rounded=False), w / "icons" / "Icon-maskable-192.png")
    save(icon_square(512, rounded=False), w / "icons" / "Icon-maskable-512.png")


def linux_and_docs():
    save(icon_square(256), ROOT / "packaging" / "linux" /
         "io.github.OWNER.Zapline.png")
    save(lockup(1280, 640), ROOT / "docs" / "brand" / "zapline-lockup.png",
         rgb=True)
    save(icon_square(1024), ROOT / "docs" / "brand" / "zapline-icon-1024.png")


def preview(out):
    sheet = Image.new("RGB", (1500, 900), (40, 44, 52))
    sheet.paste(icon_square(512), (40, 40), icon_square(512))
    for i, px in enumerate((192, 96, 48)):
        ic = icon_square(px)
        sheet.paste(ic, (600 + i * 220, 40), ic)
    sheet.paste(tv_banner(640, 360), (600, 300))
    fg = adaptive_foreground(324)
    circle = Image.new("RGB", (324, 324), GROUND)
    mask = Image.new("L", (324, 324), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, 323, 323], fill=255)
    circle.paste(fg, (0, 0), fg)
    sheet.paste(circle, (100, 560), mask)
    sheet.save(out)
    print("preview", out)


if __name__ == "__main__":
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
    else:
        android()
        ios()
        macos()
        windows()
        web()
        linux_and_docs()
