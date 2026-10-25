"""Draws the made-up channel logos and film posters the README screenshots
use, so they look like a real library without showing anyone's brand.

    python -I tool/screenshots/make_assets.py

Needs Microsoft Edge (headless). PNGs land in tool/screenshots/assets/.
"""
import os
import pathlib
import subprocess
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / 'assets'
EDGE = next(
    p for p in [
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    ] if os.path.exists(p)
)

FONT = (HERE.parent.parent / 'assets' / 'fonts' / 'inter').as_uri()
BASE = f"""
@font-face {{ font-family: Inter; font-weight: 500; src: url('{FONT}/Inter-Medium.ttf'); }}
@font-face {{ font-family: Inter; font-weight: 700; src: url('{FONT}/Inter-Bold.ttf'); }}
@font-face {{ font-family: Inter; font-weight: 800; src: url('{FONT}/Inter-ExtraBold.ttf'); }}
html, body {{ margin: 0; padding: 0; overflow: hidden; }}
body {{ font-family: Inter, sans-serif; }}
"""

# id, name, mark (short text), colours, shape
LOGOS = [
    ('meridian', 'MERIDIAN', 'NEWS', '#E63946', '#1D3557', 'bar'),
    ('arena', 'ARENA', 'SPORTS', '#06D6A0', '#073B4C', 'ring'),
    ('velvet', 'velvet', 'cinema', '#C77DFF', '#240046', 'script'),
    ('kite', 'kite', 'kids', '#FFFFFF', '#FB8500', 'kids'),
    ('terra', 'TERRA', 'DOCS', '#90BE6D', '#2D3A1F', 'leaf'),
    ('pulse', 'PULSE', 'MUSIC', '#FF006E', '#3A0CA3', 'wave'),
    ('harbor', 'HARBOR', 'ONE', '#48CAE4', '#03045E', 'one'),
    ('summit', 'SUMMIT', 'SPORTS 2', '#F77F00', '#1B1B1B', 'ring'),
    ('lumen', 'LUMEN', 'DRAMA', '#F4D35E', '#0D1B2A', 'bar'),
    ('orbit', 'ORBIT', 'SCIENCE', '#4CC9F0', '#10002B', 'orbit'),
    ('bistro', 'bistro', 'food', '#E76F51', '#FFF1E6', 'script'),
    ('atlas', 'ATLAS', 'WEATHER', '#8ECAE6', '#023047', 'bar'),
]


def logo_html(name, sub, a, b, shape):
    light = b.startswith('#F')
    ink = '#1B1B1B' if light else '#FFFFFF'
    mark = {
        'bar': f'<div style="width:46px;height:110px;background:{a};border-radius:10px;margin-right:22px"></div>',
        'ring': f'<div style="width:96px;height:96px;border:16px solid {a};border-radius:50%;margin-right:22px"></div>',
        'script': f'<div style="width:92px;height:92px;background:{a};border-radius:28px;transform:rotate(12deg);margin-right:26px"></div>',
        'kids': f'<div style="width:104px;height:104px;background:#fff;clip-path:polygon(50% 0,100% 50%,50% 100%,0 50%);margin-right:22px"></div>',
        'leaf': f'<div style="width:96px;height:96px;background:{a};border-radius:0 60px 0 60px;margin-right:22px"></div>',
        'wave': f'<div style="width:110px;height:84px;background:repeating-linear-gradient(90deg,{a} 0 14px,transparent 14px 24px);margin-right:22px;-webkit-mask:radial-gradient(circle at 50% 100%,#000 60%,transparent 61%)"></div>',
        'one': f'<div style="width:100px;height:100px;background:{a};border-radius:22px;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:72px;color:{b};margin-right:22px">1</div>',
        'orbit': f'<div style="width:100px;height:100px;border:10px solid {a};border-radius:50%;position:relative;margin-right:22px"><div style="position:absolute;width:30px;height:30px;background:#fff;border-radius:50%;top:-14px;left:48px"></div></div>',
    }[shape]
    lower = name.islower()
    return f"""<html><head><style>{BASE}</style></head><body>
<div style="width:512px;height:288px;background:{b};display:flex;align-items:center;justify-content:center">
  {mark}
  <div style="color:{ink};line-height:1">
    <div style="font-weight:800;font-size:{70 if lower else 62}px;letter-spacing:{'-2px' if lower else '3px'}">{name}</div>
    <div style="font-weight:700;font-size:28px;letter-spacing:{'1px' if lower else '9px'};color:{a};margin-top:10px">{sub}</div>
  </div>
</div></body></html>"""


# title, tagline, colours, scene
POSTERS = [
    ('The Last Lighthouse', 'Some lights never go out', '#0B132B', '#F4A261', 'sun'),
    ('Neon Harbor', 'The city never sleeps', '#10002B', '#FF006E', 'grid'),
    ('Glass Mountains', 'The climb is only half of it', '#1B263B', '#8ECAE6', 'peaks'),
    ('Signal Lost', 'Somebody is still out there', '#03071E', '#48CAE4', 'orbit'),
    ('Paper Moons', 'A summer to remember', '#3D1A3A', '#FFD6A5', 'moons'),
    ('Red Meridian', 'Every border has a price', '#2B0A0A', '#E63946', 'sun'),
    ('Saltwater', 'The sea keeps its secrets', '#012A4A', '#61A5C2', 'waves'),
    ('Northbound', 'One road. No way back', '#14213D', '#FCA311', 'road'),
    ('The Quiet Orbit', 'Alone, 400 km up', '#000814', '#FFC300', 'orbit'),
    ('Wild Hours', 'The night is young', '#240046', '#C77DFF', 'grid'),
    ('Ember', 'Fire remembers', '#1A0B00', '#F77F00', 'peaks'),
    ('Small Hours', 'Love, at 3 a.m.', '#1D3557', '#F1FAEE', 'moons'),
]


def scene(kind, a):
    return {
        'sun': f'<div style="position:absolute;width:460px;height:460px;border-radius:50%;left:20px;top:180px;background:radial-gradient(circle,{a} 0 40%,transparent 70%);opacity:.95"></div>'
               f'<div style="position:absolute;left:0;right:0;top:470px;height:300px;background:linear-gradient(transparent,#000 60%)"></div>',
        'grid': f'<div style="position:absolute;left:-200px;right:-200px;top:380px;height:400px;background:repeating-linear-gradient(90deg,{a}66 0 2px,transparent 2px 60px),repeating-linear-gradient(0deg,{a}66 0 2px,transparent 2px 40px);transform:perspective(300px) rotateX(60deg)"></div>'
                f'<div style="position:absolute;width:300px;height:300px;border-radius:50%;left:100px;top:120px;background:linear-gradient({a},#FFBE0B)"></div>',
        'peaks': f'<div style="position:absolute;left:0;right:0;top:250px;height:500px;background:{a};clip-path:polygon(0 70%,22% 25%,38% 50%,58% 5%,78% 45%,100% 20%,100% 100%,0 100%);opacity:.9"></div>'
                 f'<div style="position:absolute;left:0;right:0;top:420px;height:400px;background:#000;clip-path:polygon(0 40%,30% 10%,55% 45%,80% 15%,100% 35%,100% 100%,0 100%);opacity:.8"></div>',
        'orbit': f'<div style="position:absolute;width:520px;height:520px;border-radius:50%;left:-10px;top:140px;border:2px solid {a}88"></div>'
                 f'<div style="position:absolute;width:260px;height:260px;border-radius:50%;left:120px;top:270px;background:radial-gradient(circle at 30% 30%,#fff,{a} 35%,#000 80%)"></div>'
                 f'<div style="position:absolute;width:18px;height:18px;border-radius:50%;left:420px;top:200px;background:#fff;box-shadow:0 0 30px #fff"></div>',
        'moons': ''.join(
            f'<div style="position:absolute;width:{s}px;height:{s}px;border-radius:50%;left:{x}px;top:{y}px;background:{a};box-shadow:inset -{s//4}px -{s//8}px 0 rgba(0,0,0,.35)"></div>'
            for s, x, y in [(220, 150, 170), (90, 60, 420), (60, 380, 470), (40, 330, 130)]),
        'waves': ''.join(
            f'<div style="position:absolute;left:-50px;right:-50px;top:{t}px;height:220px;border-radius:50% 50% 0 0;background:{a};opacity:{o}"></div>'
            for t, o in [(330, .35), (420, .55), (520, .85)]),
        'road': f'<div style="position:absolute;left:0;right:0;top:400px;height:400px;background:#111;clip-path:polygon(46% 0,54% 0,100% 100%,0 100%)"></div>'
                f'<div style="position:absolute;left:247px;top:420px;width:6px;height:340px;background:repeating-linear-gradient({a} 0 30px,transparent 30px 60px)"></div>'
                f'<div style="position:absolute;width:200px;height:200px;border-radius:50%;left:150px;top:260px;background:{a};opacity:.9"></div>',
    }[kind]


def poster_html(title, tag, bg, a, kind, w=500, h=750):
    return f"""<html><head><style>{BASE}</style></head><body>
<div style="width:{w}px;height:{h}px;position:relative;overflow:hidden;background:linear-gradient(180deg,{bg},#000)">
  {scene(kind, a)}
  <div style="position:absolute;left:0;right:0;bottom:0;height:300px;background:linear-gradient(transparent,rgba(0,0,0,.85))"></div>
  <div style="position:absolute;left:36px;right:36px;top:40px;color:#fff;font-weight:500;font-size:20px;letter-spacing:4px;opacity:.85;text-transform:uppercase">{tag}</div>
  <div style="position:absolute;left:36px;right:36px;bottom:70px;color:#fff;font-weight:800;font-size:{64 if len(title) < 14 else 52}px;line-height:1;letter-spacing:-1px">{title}</div>
  <div style="position:absolute;left:36px;bottom:36px;color:{a};font-weight:700;font-size:16px;letter-spacing:6px">IN CINEMAS</div>
</div></body></html>"""


def backdrop_html(title, tag, bg, a, kind):
    # Wide picture without the lettering: the app writes the title itself.
    return f"""<html><head><style>{BASE}</style></head><body>
<div style="width:1280px;height:720px;position:relative;overflow:hidden;background:linear-gradient(120deg,{bg},#000)">
  <div style="position:absolute;left:0;right:0;bottom:0;height:260px;background:repeating-linear-gradient(90deg,{a}33 0 2px,transparent 2px 80px);transform:perspective(400px) rotateX(55deg);transform-origin:bottom"></div>
  <div style="position:absolute;left:700px;top:40px;width:500px;height:750px;transform:scale(0.85);transform-origin:top left">{scene(kind, a)}</div>
  <div style="position:absolute;inset:0;background:linear-gradient(90deg,{bg} 0,transparent 55%)"></div>
</div></body></html>"""


def render(html, path, w, h):
    with tempfile.TemporaryDirectory() as tmp:
        page = pathlib.Path(tmp) / 'p.html'
        page.write_text(html, encoding='utf-8')
        subprocess.run([
            EDGE, '--headless=new', '--disable-gpu', '--hide-scrollbars',
            f'--window-size={w},{h}', f'--screenshot={path}',
            '--force-device-scale-factor=1', '--allow-file-access-from-files',
            page.as_uri(),
        ], check=True, capture_output=True, timeout=60)


def main():
    OUT.mkdir(exist_ok=True)
    for (key, name, sub, a, b, shape) in LOGOS:
        render(logo_html(name, sub, a, b, shape), OUT / f'logo-{key}.png', 512, 288)
    for i, (title, tag, bg, a, kind) in enumerate(POSTERS, 1):
        render(poster_html(title, tag, bg, a, kind), OUT / f'poster-{i}.png', 500, 750)
        render(backdrop_html(title, tag, bg, a, kind), OUT / f'backdrop-{i}.png', 1280, 720)
    print('done', len(list(OUT.glob('*.png'))))


main()
