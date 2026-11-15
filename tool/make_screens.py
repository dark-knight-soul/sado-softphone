# Собирает картинки для README из снимков экранов (build/shots, их делает test/screenshots_test.dart):
# дорисовывает строку состояния и полоску жестов, скругляет углы, ставит «рамку телефона»
# и раскладывает снимки в ряды. Нужен Pillow (pip install pillow).
#
#   flutter test --dart-define=SADO_SHOTS=true test/screenshots_test.dart
#   python tool/make_screens.py
import os
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FLUTTER = pathlib.Path(os.environ.get('FLUTTER_ROOT', r'C:\dev\flutter'))
FONTS = FLUTTER / 'bin' / 'cache' / 'artifacts' / 'material_fonts'
ICONS = str(FONTS / 'materialicons-regular.otf')
ROBOTO = str(FONTS / 'roboto-medium.ttf')
ROBOTO_BLACK = str(FONTS / 'roboto-black.ttf')
ROBOTO_REGULAR = str(FONTS / 'roboto-regular.ttf')
SHOTS = pathlib.Path('build/shots')
OUT = pathlib.Path('docs/screenshots')
K = 3  # снимки сделаны в тройном разрешении


def phone(name):
    """Снимок экрана → «телефон»: строка состояния, полоска жестов, скруглённые углы, рамка."""
    im = Image.open(SHOTS / f'{name}.png').convert('RGBA')
    w, h = im.size
    d = ImageDraw.Draw(im)
    # Цвет значков строки состояния — по яркости верхней кромки экрана.
    r, g, b, _ = im.getpixel((w // 2, 6 * K))
    light = (0.299 * r + 0.587 * g + 0.114 * b) > 150
    ink = (30, 30, 34, 255) if light else (255, 255, 255, 255)
    f = ImageFont.truetype(ROBOTO, 15 * K)
    fi = ImageFont.truetype(ICONS, 17 * K)
    y = 11 * K
    d.text((26 * K, y), '9:41', font=f, fill=ink)
    x = w - 24 * K
    for glyph in (0xE0D2, 0xE6E7, 0xE5A6):  # батарея, Wi-Fi, сеть
        ch = chr(glyph)
        gw = d.textlength(ch, font=fi)
        x -= gw
        d.text((x, y - 1 * K), ch, font=fi, fill=ink)
        x -= 3 * K
    # Полоска жестов внизу.
    pw, ph = 128 * K, 5 * K
    r2, g2, b2, _ = im.getpixel((w // 2, h - 4 * K))
    bar = (30, 30, 34, 200) if (0.299 * r2 + 0.587 * g2 + 0.114 * b2) > 150 else (255, 255, 255, 215)
    d.rounded_rectangle(((w - pw) // 2, h - 13 * K, (w + pw) // 2, h - 13 * K + ph), radius=ph // 2, fill=bar)
    # Скруглённые углы экрана.
    radius = 34 * K
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    im.putalpha(mask)
    # Рамка телефона.
    bezel = 5 * K
    body = Image.new('RGBA', (w + bezel * 2, h + bezel * 2), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, body.width - 1, body.height - 1), radius=radius + bezel, fill=(22, 23, 27, 255))
    body.alpha_composite(im, (bezel, bezel))
    return body


def scaled(im, width):
    return im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)


def row(names, out, width=400, gap=36):
    """Несколько телефонов в ряд на прозрачном фоне — смотрится и в светлой, и в тёмной теме GitHub."""
    ims = [scaled(phone(n), width) for n in names]
    sheet = Image.new('RGBA', (len(ims) * width + (len(ims) - 1) * gap, ims[0].height), (0, 0, 0, 0))
    for i, im in enumerate(ims):
        sheet.alpha_composite(im, (i * (width + gap), 0))
    sheet.save(OUT / out, optimize=True)
    print(out, sheet.size)


def gradient(size, top, bottom):
    w, h = size
    im = Image.new('RGBA', size)
    px = im.load()
    for y in range(h):
        for x in range(w):
            k = (x * 0.35 + y) / (w * 0.35 + h)
            px[x, y] = tuple(round(top[i] + (bottom[i] - top[i]) * k) for i in range(3)) + (255,)
    return im


def banner(names, out, size, title=True):
    """Обложка: тёмно-изумрудный фон, название и ряд телефонов с тенью."""
    w, h = size
    im = gradient(size, (22, 108, 86), (7, 30, 26))
    d = ImageDraw.Draw(im)
    top = round(h * 0.07)
    if title:
        f = ImageFont.truetype(ROBOTO_BLACK, round(h * 0.085))
        d.text((round(w * 0.05), top), 'SADO', font=f, fill=(255, 255, 255, 255))
        tw = d.textlength('SADO', font=f)
        d.rounded_rectangle((round(w * 0.05), top + round(h * 0.105), round(w * 0.05 + tw * 0.42), top + round(h * 0.117)),
                            radius=6, fill=(198, 243, 94, 255))
        fs = ImageFont.truetype(ROBOTO_REGULAR, round(h * 0.034))
        d.text((round(w * 0.05) + tw + round(w * 0.025), top + round(h * 0.036)),
               'Open-source SIP softphone for your own PBX', font=fs, fill=(214, 236, 228, 255))
    n = len(names)
    pw = round(w * 0.158)
    gap = round((w * 0.9 - n * pw) / (n - 1))
    x0 = round(w * 0.05)
    y0 = round(h * 0.25)
    for i, name in enumerate(names):
        ph = scaled(phone(name), pw)
        y = y0 + (round(h * 0.035) if i % 2 else 0)
        shadow = Image.new('RGBA', (ph.width + 120, ph.height + 120), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle((60, 70, 60 + ph.width, 70 + ph.height), radius=60, fill=(0, 0, 0, 110))
        im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)), (x0 + i * (pw + gap) - 60, y - 60))
        im.alpha_composite(ph, (x0 + i * (pw + gap), y))
    im.convert('RGB').save(OUT / out, optimize=True, quality=90)
    print(out, im.size)


OUT.mkdir(parents=True, exist_ok=True)
banner(['material-home', 'cupertino-incoming', 'dial-emerald', 'material-call', 'cupertino-call'], 'hero.png', (2400, 1320))
# Картинка для «Social preview» репозитория (GitHub просит 1280×640).
banner(['material-home', 'cupertino-incoming', 'dial-emerald', 'material-call', 'cupertino-call'], 'social-preview.png', (1280, 640))
row(['dial-emerald', 'dial-night', 'dial-air', 'dial-sunset'], 'styles.png')
row(['material-home', 'material-dial', 'material-incoming', 'material-call', 'material-transfer'], 'material.png')
row(['cupertino-history', 'cupertino-incoming', 'cupertino-call', 'cupertino-keypad'], 'cupertino.png')
row(['emerald-contacts', 'emerald-settings', 'emerald-call', 'night-incoming', 'sunset-call'], 'more.png')
