#!/usr/bin/env python3
"""Draws the ZipFast app icon sources into assets/icon/ (needs Pillow).

  icon.png             1024 full icon (legacy launchers, Play Store)
  icon_foreground.png  adaptive-icon foreground (content inside the 66% safe zone)
  icon_monochrome.png  Android 13 themed icon
  play_store_512.png   Play Store listing icon

Then run: dart run flutter_launcher_icons
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'icon')
os.makedirs(OUT, exist_ok=True)
S = 4  # supersampling
N = 1024

INDIGO_TOP = (99, 102, 241)    # #6366F1
INDIGO_BOTTOM = (67, 56, 202)  # #4338CA
WHITE = (255, 255, 255, 255)
AMBER = (251, 191, 36, 255)    # #FBBF24
AMBER_DARK = (245, 158, 11, 255)


def gradient(size):
    img = Image.new('RGBA', (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(INDIGO_TOP[i] * (1 - t) + INDIGO_BOTTOM[i] * t) for i in range(3)) + (255,)
        for x in range(size):
            px[x, y] = c
    return img


def rrect(d, box, r, fill):
    d.rounded_rectangle([v * S for v in box], radius=r * S, fill=fill)


def zipper(mono=False):
    """A zipped package on a transparent 1024 canvas, inside the adaptive-icon safe zone.

    White box, a zip running down from its top edge with alternating teeth, and
    an amber pull tab at the zip's end. In `mono` mode teeth are cut out of the
    silhouette so it works as an Android 13 themed icon.
    """
    img = Image.new('RGBA', (N * S, N * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = 512
    cut = (0, 0, 0, 0) if mono else INDIGO_BOTTOM + (255,)

    # The package.
    rrect(d, (cx - 235, 235, cx + 235, 790), 96, WHITE)

    # Zip teeth: alternate left/right of the centre line, running from the top edge.
    y, left = 235, True
    while y < 470:
        x0, x1 = (cx - 62, cx - 6) if left else (cx + 6, cx + 62)
        d.rounded_rectangle([x0 * S, (y + 12) * S, x1 * S, (y + 44) * S], radius=10 * S, fill=cut)
        left = not left
        y += 44

    # Pull tab at the end of the zip.
    # A gap around the tab so it separates from the teeth.
    d.rounded_rectangle([(cx - 84) * S, 520 * S, (cx + 84) * S, 740 * S], radius=62 * S, fill=cut)
    tab = WHITE if mono else AMBER
    rrect(d, (cx - 64, 538, cx + 64, 722), 48, tab)
    d.rounded_rectangle([(cx - 24) * S, 584 * S, (cx + 24) * S, 660 * S], radius=24 * S,
                        fill=(0, 0, 0, 0) if mono else WHITE)
    return img.resize((N, N), Image.LANCZOS)


def with_shadow(glyph):
    """Soft drop shadow so the white glyph lifts off the indigo."""
    from PIL import ImageFilter
    alpha = glyph.split()[-1]
    shadow = Image.new('RGBA', glyph.size, (20, 16, 90, 0))
    shadow.putalpha(alpha.point(lambda a: int(a * 0.35)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    out = Image.new('RGBA', glyph.size, (0, 0, 0, 0))
    out.alpha_composite(shadow, (0, 14))
    out.alpha_composite(glyph)
    return out


glyph = zipper()
fg = with_shadow(glyph)

# Full-bleed icon: indigo gradient + glyph (launchers apply their own mask).
full = gradient(N)
full.alpha_composite(fg)
full.save(os.path.join(OUT, 'icon.png'))

# Adaptive foreground: transparent, glyph only.
fg.save(os.path.join(OUT, 'icon_foreground.png'))

# Themed (monochrome) icon: single-colour silhouette.
zipper(mono=True).save(os.path.join(OUT, 'icon_monochrome.png'))

# Play Store: 512, rounded by the store, so keep full-bleed.
full.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, 'play_store_512.png'))
print('wrote', sorted(os.listdir(OUT)))
