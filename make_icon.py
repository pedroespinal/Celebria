"""
Generates Celebria's launcher icon in the neon "Tropical" style of v1.10
(deep teal background, glowing mint / magenta / gold neon cake, a lit candle,
a notification bell badge and confetti).

Outputs (consumed by flutter_launcher_icons, see flutter/pubspec.yaml):
  assets/icon.png      full 1024px icon (legacy launchers, Android < 8)
  assets/icon_fg.png   adaptive-icon FOREGROUND: same artwork on transparent,
                       scaled into the central safe zone so every launcher
                       mask (circle, squircle, teardrop) shows it uncropped
Background color for the adaptive icon: #03121A (adaptive_icon_background).

Drawn at 2x and downsampled for smooth edges. One-time design tool — not
part of the shipped app. Run:  python make_icon.py
"""
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = 1024
S = 2048  # supersampled working size

BG_TOP = (10, 42, 58)
BG_BOT = (3, 18, 26)
MINT = (0, 255, 198)
MAGENTA = (255, 79, 216)
GOLD = (255, 228, 94)
VIOLET = (157, 123, 255)
LIME = (124, 255, 79)
INK = (6, 26, 36)       # dark fill inside neon outlines
WHITE = (240, 255, 250)


def tint(col, k=0.22):
    """Dark fill tinted with the neon color (reads better than black at 48px)."""
    return tuple(int(INK[i] + (col[i] - INK[i]) * k) for i in range(3)) + (255,)


def glow_layer(draw_fn, color, width, blur):
    """Draws a shape with draw_fn on its own layer, returns (glow, crisp)."""
    crisp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(crisp), color, width)
    glow = crisp.filter(ImageFilter.GaussianBlur(blur))
    # boost glow intensity
    glow = Image.alpha_composite(glow, glow.filter(ImageFilter.GaussianBlur(blur * 2.2)))
    glow = Image.alpha_composite(glow, glow)  # brighter halo
    return glow, crisp


def artwork(scale: float) -> Image.Image:
    """The icon artwork (no background) on a transparent SxS canvas.
    `scale` shrinks it around the centre (1.0 = full icon composition)."""
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    def T(x, y):  # design coords are in a 2048 box; scale about the centre
        return (S / 2 + (x - S / 2) * scale, S / 2 + (y - S / 2) * scale)

    def R(v):
        return v * scale

    def box(x0, y0, x1, y1):
        a, b = T(x0, y0)
        c, d = T(x1, y1)
        return [a, b, c, d]

    parts = []  # (draw_fn, color, width, blur)

    # ── bottom tier (magenta) ──
    def bottom(d, col, w):
        d.rounded_rectangle(box(470, 1180, 1500, 1640), radius=R(70), fill=tint(col), outline=col + (255,), width=int(R(w)))
    parts.append((bottom, MAGENTA, 50, R(34)))

    # ── top tier (mint) ──
    def top(d, col, w):
        d.rounded_rectangle(box(640, 860, 1330, 1220), radius=R(60), fill=tint(col), outline=col + (255,), width=int(R(w)))
    parts.append((top, MINT, 50, R(34)))

    # ── frosting drips (wavy line on each tier) ──
    def drips(d, col, w):
        for (x0, x1, y, amp) in [(500, 1470, 1290, 46), (670, 1300, 960, 38)]:
            pts = []
            steps = 48
            for i in range(steps + 1):
                x = x0 + (x1 - x0) * i / steps
                import math
                yy = y + amp * (0.5 + 0.5 * math.sin(i / steps * math.pi * 6))
                pts.append(T(x, yy))
            d.line(pts, fill=col + (255,), width=int(R(w)), joint="curve")
    parts.append((drips, GOLD, 34, R(20)))

    # ── candle ──
    def candle(d, col, w):
        d.rounded_rectangle(box(948, 620, 1022, 860), radius=R(22), fill=tint(col), outline=col + (255,), width=int(R(w)))
    parts.append((candle, VIOLET, 30, R(22)))

    # ── flame ──
    def flame(d, col, w):
        d.ellipse(box(925, 420, 1045, 600), fill=col + (255,))
    parts.append((flame, GOLD, 0, R(44)))

    def flame_core(d, col, w):
        d.ellipse(box(958, 488, 1012, 584), fill=col + (255,))
    parts.append((flame_core, WHITE, 0, R(10)))

    # ── bell badge (upper right) ──
    def bell(d, col, w):
        cx, cy, r = 1530, 600, 190
        d.ellipse(box(cx - r - 40, cy - r - 40, cx + r + 40, cy + r + 40), fill=INK + (255,), outline=col + (255,), width=int(R(w)))
        # bell body
        d.pieslice(box(cx - 110, cy - 120, cx + 110, cy + 100), 180, 360, fill=col + (255,))
        d.rectangle(box(cx - 110, cy - 10, cx + 110, cy + 60), fill=col + (255,))
        d.rounded_rectangle(box(cx - 140, cy + 55, cx + 140, cy + 90), radius=R(16), fill=col + (255,))
        d.ellipse(box(cx - 32, cy + 92, cx + 32, cy + 150), fill=col + (255,))
        d.ellipse(box(cx - 22, cy - 160, cx + 22, cy - 116), fill=col + (255,))
    parts.append((bell, MAGENTA, 34, R(36)))

    for fn, col, w, blur in parts:
        g, c = glow_layer(fn, col, w, blur)
        layer = Image.alpha_composite(layer, g)
        layer = Image.alpha_composite(layer, c)

    # ── confetti + sprinkles ──
    rnd = random.Random(7)
    conf = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cd = ImageDraw.Draw(conf)
    spots = [(420, 560), (560, 380), (760, 300), (1220, 330), (330, 900), (1700, 1000),
             (1760, 1300), (300, 1300), (1150, 520), (700, 640)]
    for (x, y) in spots:
        col = rnd.choice([MINT, MAGENTA, GOLD, VIOLET, LIME])
        if rnd.random() < 0.5:
            r = rnd.randint(18, 28)
            cd.ellipse(box(x - r, y - r, x + r, y + r), fill=col + (255,))
        else:
            cd.rounded_rectangle(box(x - 34, y - 13, x + 34, y + 13), radius=R(8), fill=col + (255,))
    for (x0, y0, x1, y1) in [(540, 1360, 1430, 1580), (700, 1030, 1270, 1170)]:
        for _ in range(9):
            x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
            col = rnd.choice([MINT, MAGENTA, GOLD, LIME, VIOLET])
            cd.ellipse(box(x - 14, y - 14, x + 14, y + 14), fill=col + (255,))
    layer = Image.alpha_composite(layer, conf.filter(ImageFilter.GaussianBlur(R(10))))
    layer = Image.alpha_composite(layer, conf)
    return layer


def background() -> Image.Image:
    bg = Image.new("RGBA", (S, S))
    px = ImageDraw.Draw(bg)
    for y in range(S):
        t = y / (S - 1)
        c = tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3))
        px.line([(0, y), (S, y)], fill=c + (255,))
    # soft mint halo behind the cake
    halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([S * 0.18, S * 0.25, S * 0.82, S * 0.92], fill=MINT + (60,))
    return Image.alpha_composite(bg, halo.filter(ImageFilter.GaussianBlur(S * 0.12)))


here = os.path.dirname(os.path.abspath(__file__))

# Full legacy icon: squircle-ish rounded square, artwork at ~0.86
full = Image.alpha_composite(background(), artwork(0.86))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.23), fill=255)
full.putalpha(ImageChops.multiply(full.getchannel("A"), mask))
full.resize((OUT, OUT), Image.LANCZOS).save(os.path.join(here, "assets", "icon.png"))

# Adaptive foreground: artwork only, at full size. flutter_launcher_icons
# wraps it in a 16% inset (content = 68% of the 108dp layer), which already
# keeps it inside the 66dp safe circle — scaling it down here as well made
# the launcher icon tiny (seen on the emulator, v1.10.0 first try).
FG_SCALE = 1.0
fg = artwork(FG_SCALE)
fg.resize((OUT, OUT), Image.LANCZOS).save(os.path.join(here, "assets", "icon_fg.png"))
# Adaptive background: the gradient + mint halo (not just a flat color).
background().resize((OUT, OUT), Image.LANCZOS).save(os.path.join(here, "assets", "icon_bg.png"))

# Preview: what a round launcher actually shows (central 66.7%, circle mask)
inset = artwork(FG_SCALE).resize((int(S * 0.68), int(S * 0.68)), Image.LANCZOS)
prev = background()
prev.alpha_composite(inset, (int(S * 0.16), int(S * 0.16)))
m = int(S * (1 - 72 / 108) / 2)
prev = prev.crop((m, m, S - m, S - m))
circle = Image.new("L", prev.size, 0)
ImageDraw.Draw(circle).ellipse([0, 0, prev.size[0] - 1, prev.size[1] - 1], fill=255)
prev.putalpha(circle)
prev.resize((512, 512), Image.LANCZOS).save(os.path.join(here, "assets", "icon_preview_round.png"))
# flutter_launcher_icons reads them from flutter/assets (see pubspec.yaml)
import shutil
for name in ("icon.png", "icon_fg.png", "icon_bg.png"):
    shutil.copyfile(os.path.join(here, "assets", name), os.path.join(here, "flutter", "assets", name))
print("Saved assets/icon.png, assets/icon_fg.png, assets/icon_preview_round.png (+ copied to flutter/assets)")
print("Next: cd flutter && dart run flutter_launcher_icons")
