"""Generates every Zapline icon and banner from one geometric definition.

    python -I tools/brand/generate.py [--preview out.png]

The mark, "hidden Z": a dark play button on an amber tile, cut through by a
Z-shaped line in the tile's colour, so the Z only appears in the gap. The
wordmark is "zapline" in Inter ExtraBold (bundled with the app, SIL OFL).
Everything is supersampled and downscaled for clean edges.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "apps" / "zapline"
FONT = APP / "assets" / "fonts" / "inter" / "Inter-ExtraBold.ttf"

GROUND = (11, 14, 19)
INK = (20, 25, 34)
AMBER_TOP = (255, 209, 102)
AMBER_BOTTOM = (245, 158, 11)
AMBER = (249, 182, 54)  # the tile's middle, for flat fills
TEXT = (238, 242, 247)

SS = 4  # supersampling factor

# Geometry on a 100-unit tile (the same numbers as widgets/brand.dart).
_PLAY = [  # (kind, points): straight lines and quadratic corners
    ("M", (31, 21)), ("Q", (27, 19), (27, 24)), ("L", (27, 76)),
    ("Q", (27, 81), (31, 79)), ("L", (81, 53.5)), ("Q", (85, 50), (81, 46.5)),
]
_CUT = [(20, 40), (60, 40), (39, 60), (90, 60)]
_CUT_WIDTH = 5.5
TILE_RADIUS = 0.23


# ---------------------------------------------------------------- drawing


def _play_points(scale, ox, oy):
    pts, cur = [], None
    for seg in _PLAY:
        if seg[0] in ("M", "L"):
            cur = seg[1]
            pts.append(cur)
        else:
            (cx, cy), end = seg[1], seg[2]
            for i in range(1, 13):
                t = i / 12
                x = (1 - t) ** 2 * cur[0] + 2 * (1 - t) * t * cx + t * t * end[0]
                y = (1 - t) ** 2 * cur[1] + 2 * (1 - t) * t * cy + t * t * end[1]
                pts.append((x, y))
            cur = end
    return [(ox + x * scale, oy + y * scale) for x, y in pts]


def _thick_polyline(points, width):
    """Outline of a polyline with mitred joins and flat ends."""
    h = width / 2

    def normal(a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = (dx * dx + dy * dy) ** 0.5
        return (-dy / ln * h, dx / ln * h)

    def offset(a, b, sign):
        n = normal(a, b)
        return ((a[0] + sign * n[0], a[1] + sign * n[1]),
                (b[0] + sign * n[0], b[1] + sign * n[1]))

    def cross(l1, l2):
        (x1, y1), (x2, y2) = l1
        (x3, y3), (x4, y4) = l2
        d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        if abs(d) < 1e-9:
            return l1[1]
        t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / d
        return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))

    sides = []
    for sign in (1, -1):
        segs = [offset(a, b, sign) for a, b in zip(points, points[1:])]
        side = [segs[0][0]]
        for s1, s2 in zip(segs, segs[1:]):
            side.append(cross(s1, s2))
        side.append(segs[-1][1])
        sides.append(side)
    return sides[0] + sides[1][::-1]


def _gradient(n):
    """Amber tile colours, top-left light to bottom-right deep."""
    small = Image.new("RGB", (64, 64))
    px = small.load()
    for y in range(64):
        for x in range(64):
            t = (x + y) / 126
            px[x, y] = tuple(round(a + (b - a) * t)
                             for a, b in zip(AMBER_TOP, AMBER_BOTTOM))
    return small.resize((n, n), Image.BILINEAR)


def _mark_mask(n, scale, ox, oy):
    """White where the play shows: the play minus the Z cut."""
    mask = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(mask)
    d.polygon(_play_points(scale, ox, oy), fill=255)
    cut = [(ox + x * scale, oy + y * scale) for x, y in _CUT]
    d.polygon(_thick_polyline(cut, _CUT_WIDTH * scale), fill=0)
    return mask


def _icon(n, rounded=True, inset=0):
    """The full icon at n x n (supersampled pixels)."""
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    size = n - 2 * inset
    tile = _gradient(size).convert("RGBA")
    shape = Image.new("L", (size, size), 0)
    sd = ImageDraw.Draw(shape)
    if rounded:
        sd.rounded_rectangle([0, 0, size - 1, size - 1],
                             radius=round(size * TILE_RADIUS), fill=255)
    else:
        sd.rectangle([0, 0, size - 1, size - 1], fill=255)
    img.paste(tile, (inset, inset), shape)
    mark = _mark_mask(n, size / 100, inset, inset)
    img.paste(Image.new("RGBA", (n, n), INK + (255,)), (0, 0), mark)
    return img


def _font(px):
    return ImageFont.truetype(str(FONT), round(px))


# ---------------------------------------------------------------- assets


def _down(img, w, h):
    return img.resize((w, h), Image.LANCZOS)


def icon_square(px, rounded=True, padding=0.0):
    """Full icon: amber tile and the mark. `rounded` for platforms that
    don't mask icons themselves (Android legacy, macOS, Windows, Linux)."""
    n = px * SS
    return _down(_icon(n, rounded, round(n * padding)), px, px)


def adaptive_foreground(px):
    """Android adaptive icon foreground (108 units, 66 safe): the dark play
    alone; the amber comes from the background layer and fills the cut."""
    n = px * SS
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    # The tile's 100 units shown over the 72-unit visible area, centred.
    scale = n * 0.66 / 100
    off = (n - 100 * scale) / 2
    mark = _mark_mask(n, scale, off, off)
    img.paste(Image.new("RGBA", (n, n), INK + (255,)), (0, 0), mark)
    return _down(img, px, px)


def tv_banner(w, h):
    """Android TV / Fire TV launcher banner with the app name (TV-BN)."""
    W, H = w * SS, h * SS
    img = Image.new("RGB", (W, H), GROUND)
    icon = H * 0.56
    font = _font(H * 0.30)
    d = ImageDraw.Draw(img)
    words = d.textlength("zapline", font=font)
    gap = H * 0.10
    left = (W - icon - gap - words) / 2
    ic = _icon(round(icon))
    img.paste(ic, (round(left), round((H - icon) / 2)), ic)
    d.text((left + icon + gap, H / 2), "zapline", font=font, fill=TEXT,
           anchor="lm")
    return _down(img, w, h)


def lockup(w, h):
    """Icon + wordmark on the dark ground, for README and stores."""
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
        '    <color name="ic_launcher_background">#F9B636</color>\n'
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
    circle = Image.new("RGB", (324, 324), AMBER)
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
