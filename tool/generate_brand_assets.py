#!/usr/bin/env python3
"""Tạo icon/splash native từ mascot Mindy có sẵn, không phụ thuộc Flutter package.
Chạy khi đổi mascot: python3 -m pip install Pillow; python3 tool/generate_brand_assets.py.
"""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
mascot = Image.open(ROOT / 'assets/illustrations/mindy-mascot-laptop.png').convert('RGBA')
BACKGROUND = '#FFF9EF'


def asset(path, size, ratio=.80, opaque=True):
    canvas = Image.new('RGBA', (size, size), BACKGROUND if opaque else (0, 0, 0, 0))
    figure = mascot.copy()
    figure.thumbnail((round(size * ratio), round(size * ratio)), Image.Resampling.LANCZOS)
    canvas.alpha_composite(figure, ((size - figure.width) // 2, (size - figure.height) // 2))
    path.parent.mkdir(parents=True, exist_ok=True)
    (canvas.convert('RGB') if opaque else canvas).save(path)


icons = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((icons / 'Contents.json').read_text())['images']:
    size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
    asset(icons / entry['filename'], size)
launch = ROOT / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
entries = []
for scale in (1, 2, 3):
    filename = 'LaunchImage.png' if scale == 1 else f'LaunchImage@{scale}x.png'
    asset(launch / filename, 180 * scale, ratio=.94, opaque=False)
    entries.append(dict(idiom='universal', filename=filename, scale=f'{scale}x'))
(launch / 'Contents.json').write_text(json.dumps(dict(images=entries, info=dict(version=1, author='xcode')), indent=2)+'\n')
res = ROOT / 'android/app/src/main/res'
for density, factor in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    asset(res / f'mipmap-{density}/ic_launcher.png', round(48 * factor))
    # Adaptive icon mask giữ toàn bộ mascot trong safe zone 66/108.
    asset(res / f'mipmap-{density}/ic_launcher_foreground.png', round(108 * factor), ratio=.58, opaque=False)
    asset(res / f'drawable-{density}/launch_mascot.png', round(180 * factor), ratio=.94, opaque=False)
