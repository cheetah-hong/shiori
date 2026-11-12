#!/usr/bin/env python3
"""App icon and launch screen assets for iOS and Android, from one drawing.

The icon is a few plain shapes (rounded rectangles, a polygon and round
stroked paths, no font glyphs) on a 1024 x 1024 canvas. This script draws
them into:

  design/icon/shiori.svg, shiori-dev.svg            the drawing, for people
  app/ios/Runner/Assets.xcassets/AppIcon.appiconset/        prod icon (no alpha)
  app/ios/Runner/Assets.xcassets/AppIcon-dev.appiconset/    dev icon (DEV band)
  app/ios/Runner/Assets.xcassets/LaunchImage.imageset/      launch page, light/dark
  app/ios/Runner/Assets.xcassets/LaunchBackground.colorset/ launch ground
  app/android/app/src/main/res/  mipmap-*/ic_launcher.png, adaptive icon,
                                 launch drawable and colors
  app/android/app/src/dev/res/   the dev icon (flavor source set)

Usage:
    python3 tools/design/make_icons.py            # write the files
    python3 tools/design/make_icons.py --check    # exit 1 when a file is out of date

Requires Pillow (as tools/ocr/make_fixture.py). Nothing is fetched.
"""
from __future__ import annotations

import argparse
import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]

# Palette: the app's color tokens (app/lib/app/theme.dart, light and dark).
LIGHT = {'bg': '#FFFFFF', 'text': '#1F2A22', 'line': '#DFE6D8',
         'accent': '#287A4E', 'tint': '#E3F2E8'}
DARK = {'bg': '#111612', 'text': '#E7EFE8', 'line': '#2A352D',
        'accent': '#6CC593', 'tint': '#1C3526'}
DEV_BAND = '#8F5300'
WHITE = '#FFFFFF'

# The 「し」 stroke, shared with the opening (app/lib/shared/shi_stroke.dart).
SHI = [('M', 448, 372), ('V', 548), ('C', 448, 650, 522, 680, 574, 640),
       ('C', 604, 616, 620, 590, 628, 560)]

FRAME = [[(196, 330), (196, 196), (330, 196)], [(694, 196), (828, 196), (828, 330)],
         [(828, 694), (828, 828), (694, 828)], [(330, 828), (196, 828), (196, 694)]]

# A shape is ('rect', x, y, w, h, radius, color) | ('poly', points, color)
#          | ('stroke', commands, width, color).
PAGE = ('rect', 336, 300, 352, 424, 30, WHITE)


def icon(dev: bool = False) -> list[tuple]:
    """The app icon: a white page in a camera frame, 「し」 written on it in
    one green stroke."""
    shapes = [('rect', 0, 0, 1024, 1024, 0, LIGHT['accent'])]
    shapes += [('stroke', [('M', *c[0]), ('L', *c[1]), ('L', *c[2])], 64, WHITE)
               for c in FRAME]
    shapes += [PAGE, ('stroke', SHI, 58, LIGHT['accent'])]
    if dev:
        shapes += dev_band()
    return shapes


def dev_band() -> list[tuple]:
    """A brown band with DEV drawn in strokes along the bottom."""
    x, y = 352, 882
    letters = [
        [('M', x, y), ('V', y + 100), ('H', x + 32),
         ('C', x + 72, y + 100, x + 80, y + 78, x + 80, y + 50),
         ('C', x + 80, y + 22, x + 72, y, x + 32, y), ('L', x, y)],
        [('M', x + 200, y), ('H', x + 120), ('V', y + 100), ('H', x + 200)],
        [('M', x + 120, y + 50), ('H', x + 182)],
        [('M', x + 240, y), ('L', x + 280, y + 100), ('L', x + 320, y)],
    ]
    return [('rect', 0, 842, 1024, 182, 0, DEV_BAND)] + [
        ('stroke', l, 22, WHITE) for l in letters]


def launch_page(p: dict) -> list[tuple]:
    """The first frame of the opening: the page, nothing else (transparent
    around it, laid on LaunchBackground)."""
    return [
        ('rect', 336, 300, 352, 424, 30, p['bg']),
        ('stroke_rect', 336, 300, 352, 424, 30, 14, p['line']),
        ('rect', 392, 392, 170, 36, 18, p['text']),
        ('rect', 392, 476, 200, 26, 13, p['accent']),
        ('rect', 392, 540, 140, 26, 13, p['line']),
    ]


# --- drawing --------------------------------------------------------------

def _points(commands, steps: int = 48) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = []
    x = y = 0.0
    for c in commands:
        op = c[0]
        if op in ('M', 'L'):
            x, y = c[1], c[2]
            pts.append((x, y))
        elif op == 'H':
            x = c[1]
            pts.append((x, y))
        elif op == 'V':
            y = c[1]
            pts.append((x, y))
        elif op == 'C':
            x1, y1, x2, y2, x3, y3 = c[1:]
            for i in range(1, steps + 1):
                t = i / steps
                u = 1 - t
                pts.append((u ** 3 * x + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t ** 3 * x3,
                            u ** 3 * y + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t ** 3 * y3))
            x, y = x3, y3
    return pts


def _dense(pts, step: float) -> list[tuple[float, float]]:
    out = [pts[0]]
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        d = max(abs(bx - ax), abs(by - ay))
        n = max(1, int(d / step))
        out += [(ax + (bx - ax) * i / n, ay + (by - ay) * i / n) for i in range(1, n + 1)]
    return out


def render(shapes, size: int, transparent: bool = False) -> Image.Image:
    """Draws [shapes] (1024 units) at [size] px, 4x supersampled."""
    k = size * 4 / 1024
    big = Image.new('RGBA', (size * 4, size * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    for s in shapes:
        kind = s[0]
        if kind == 'rect':
            _, x, y, w, h, r, col = s
            d.rounded_rectangle([x * k, y * k, (x + w) * k - 1, (y + h) * k - 1],
                                radius=r * k, fill=col)
        elif kind == 'stroke_rect':
            _, x, y, w, h, r, width, col = s
            d.rounded_rectangle([x * k, y * k, (x + w) * k - 1, (y + h) * k - 1],
                                radius=r * k, outline=col, width=max(1, round(width * k / 2)))
        elif kind == 'poly':
            _, pts, col = s
            d.polygon([(px * k, py * k) for px, py in pts], fill=col)
        elif kind == 'stroke':
            _, cmds, width, col = s
            rad = width * k / 2
            for px, py in _dense(_points(cmds), step=max(1.0, rad / 4) / k):
                d.ellipse([px * k - rad, py * k - rad, px * k + rad, py * k + rad], fill=col)
    img = big.resize((size, size), Image.LANCZOS)
    if transparent:
        return img
    flat = Image.new('RGB', img.size, LIGHT['accent'])
    flat.paste(img, mask=img.split()[3])
    return flat


def png(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, 'PNG', optimize=True)
    return buf.getvalue()


# --- formats --------------------------------------------------------------

def _svg_path(cmds) -> str:
    return ' '.join(f'{c[0]}{" ".join(str(v) for v in c[1:])}' for c in cmds)


def svg(shapes) -> str:
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">']
    for s in shapes:
        if s[0] == 'rect':
            _, x, y, w, h, r, col = s
            out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{col}"/>')
        elif s[0] == 'poly':
            pts = ' '.join(f'{x},{y}' for x, y in s[1])
            out.append(f'<polygon points="{pts}" fill="{s[2]}"/>')
        elif s[0] == 'stroke':
            out.append(f'<path d="{_svg_path(s[1])}" fill="none" stroke="{s[3]}" '
                       f'stroke-width="{s[2]}" stroke-linecap="round" stroke-linejoin="round"/>')
    out.append('</svg>')
    return '\n'.join(out) + '\n'


def _rect_path(x, y, w, h, r) -> str:
    return (f'M{x + r},{y} H{x + w - r} A{r},{r} 0 0 1 {x + w},{y + r} V{y + h - r} '
            f'A{r},{r} 0 0 1 {x + w - r},{y + h} H{x + r} A{r},{r} 0 0 1 {x},{y + h - r} '
            f'V{y + r} A{r},{r} 0 0 1 {x + r},{y} Z')


def vector_drawable(shapes) -> str:
    """Android adaptive foreground: 108dp, the drawing scaled into the 66dp
    safe zone (its frame reaches 447 units from the center)."""
    scale = 33 / 447
    shift = 54 - 512 * scale
    out = ['<?xml version="1.0" encoding="utf-8"?>',
           '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
           '    android:width="108dp" android:height="108dp"',
           '    android:viewportWidth="108" android:viewportHeight="108">',
           f'    <group android:scaleX="{scale:.6f}" android:scaleY="{scale:.6f}"'
           f' android:translateX="{shift:.6f}" android:translateY="{shift:.6f}">']
    for s in shapes[1:]:  # the first shape is the background (its own layer)
        if s[0] == 'rect':
            _, x, y, w, h, r, col = s
            out.append(f'        <path android:fillColor="{col}" android:pathData="{_rect_path(x, y, w, h, r)}"/>')
        elif s[0] == 'poly':
            d = 'M' + ' L'.join(f'{x},{y}' for x, y in s[1]) + ' Z'
            out.append(f'        <path android:fillColor="{s[2]}" android:pathData="{d}"/>')
        elif s[0] == 'stroke':
            out.append(f'        <path android:strokeColor="{s[3]}" android:strokeWidth="{s[2]}"'
                       ' android:strokeLineCap="round" android:strokeLineJoin="round"'
                       f' android:pathData="{_svg_path(s[1])}"/>')
    out += ['    </group>', '</vector>']
    return '\n'.join(out) + '\n'


ADAPTIVE = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
'''


def color_res(name: str, value: str) -> str:
    return ('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            f'    <color name="{name}">{value}</color>\n</resources>\n')


def colorset(light: str, dark: str) -> str:
    def comp(h):
        return {'color-space': 'srgb', 'components': {
            'alpha': '1.000', 'red': f'0x{h[1:3]}', 'green': f'0x{h[3:5]}', 'blue': f'0x{h[5:7]}'}}
    return json.dumps({'colors': [
        {'idiom': 'universal', 'color': comp(light)},
        {'idiom': 'universal', 'appearances': [{'appearance': 'luminosity', 'value': 'dark'}],
         'color': comp(dark)},
    ], 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n'


LAUNCH_IMAGES = json.dumps({'images': [
    {'idiom': 'universal', 'filename': f'LaunchImage{s}.png', 'scale': f'{n}x'}
    for n, s in ((1, ''), (2, '@2x'), (3, '@3x'))] + [
    {'idiom': 'universal', 'appearances': [{'appearance': 'luminosity', 'value': 'dark'}],
     'filename': f'LaunchImageDark{s}.png', 'scale': f'{n}x'}
    for n, s in ((1, ''), (2, '@2x'), (3, '@3x'))],
    'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n'

# The launch page is drawn on the opening's canvas: 72% of a 390 pt wide
# screen (the storyboard scales it to 72% of any width).
LAUNCH_PT = 281
ANDROID_DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}


def outputs() -> dict[Path, bytes]:
    files: dict[Path, bytes] = {}
    prod, dev = icon(), icon(dev=True)
    files[ROOT / 'design/icon/shiori.svg'] = svg(prod).encode()
    files[ROOT / 'design/icon/shiori-dev.svg'] = svg(dev).encode()

    assets = ROOT / 'app/ios/Runner/Assets.xcassets'
    contents = json.loads((assets / 'AppIcon.appiconset/Contents.json').read_text())
    for name, shapes in (('AppIcon', prod), ('AppIcon-dev', dev)):
        folder = assets / f'{name}.appiconset'
        files[folder / 'Contents.json'] = (json.dumps(contents, indent=2) + '\n').encode()
        for entry in contents['images']:
            px = round(float(entry['size'].split('x')[0]) * int(entry['scale'][0]))
            files[folder / entry['filename']] = png(render(shapes, px))

    launch = assets / 'LaunchImage.imageset'
    files[launch / 'Contents.json'] = LAUNCH_IMAGES.encode()
    for n, suffix in ((1, ''), (2, '@2x'), (3, '@3x')):
        files[launch / f'LaunchImage{suffix}.png'] = png(render(launch_page(LIGHT), LAUNCH_PT * n, True))
        files[launch / f'LaunchImageDark{suffix}.png'] = png(render(launch_page(DARK), LAUNCH_PT * n, True))
    files[assets / 'LaunchBackground.colorset/Contents.json'] = colorset(LIGHT['bg'], DARK['bg']).encode()

    for flavor, shapes, ground in (('main', prod, LIGHT['accent']), ('dev', dev, DEV_BAND)):
        res = ROOT / f'app/android/app/src/{flavor}/res'
        for density, px in ANDROID_DENSITIES.items():
            files[res / f'mipmap-{density}/ic_launcher.png'] = png(render(shapes, px))
        files[res / 'mipmap-anydpi-v26/ic_launcher.xml'] = ADAPTIVE.encode()
        # One foreground for both; the dev icon is told apart by its ground.
        files[res / 'drawable/ic_launcher_foreground.xml'] = vector_drawable(prod).encode()
        files[res / 'values/ic_launcher_background.xml'] = color_res('ic_launcher_background', ground).encode()

    main = ROOT / 'app/android/app/src/main/res'
    files[main / 'drawable-nodpi/launch_page.png'] = png(render(launch_page(LIGHT), 843, True))
    files[main / 'drawable-night-nodpi/launch_page.png'] = png(render(launch_page(DARK), 843, True))
    files[main / 'values/launch_colors.xml'] = color_res('launch_background', LIGHT['bg']).encode()
    files[main / 'values-night/launch_colors.xml'] = color_res('launch_background', DARK['bg']).encode()
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--check', action='store_true', help='compare instead of writing')
    args = parser.parse_args()
    stale = []
    for path, data in outputs().items():
        if args.check:
            if not path.exists() or path.read_bytes() != data:
                stale.append(path.relative_to(ROOT))
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    if stale:
        print('out of date (run python3 tools/design/make_icons.py):')
        for p in stale:
            print(f'  {p}')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
