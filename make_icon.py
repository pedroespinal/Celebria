"""
Generates Celebria's app icon: a birthday cake + notification bell, using the
app's own Fiesta palette (coral / gold / lime / pink) on the dark teal
background, so the launcher icon matches the in-app branding instead of an
unrelated neon cyan/purple scheme. Bold, flat shapes for legibility at
launcher size. One-time design tool -- not part of the shipped app.
"""
from PIL import Image, ImageDraw
import random, os

SIZE = 1024
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Fiesta palette (matches flutter/lib/core/palette.dart _darkRaw)
BG    = (6,   20,  24, 255)   # #061418
CORAL = (255, 107, 107, 255)  # #ff6b6b
GOLD  = (255, 217,  61, 255)  # #ffd93d
LIME  = (107, 203, 119, 255)  # #6bcb77
PINK  = (255,  78, 136, 255)  # #ff4e88
CREAM = (255, 232, 208, 255)  # #ffe8d0 (t1)

# ── Background: solid dark teal circle ──────────────────────────────────────
draw.ellipse([0, 0, SIZE, SIZE], fill=BG)

# ── Soft coral glow behind the cake for depth ───────────────────────────────
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
gdraw = ImageDraw.Draw(glow)
cx, cy = SIZE // 2, SIZE // 2 + 40
for r, a in [(430, 18), (360, 26), (300, 34)]:
    gdraw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*CORAL[:3], a))
img = Image.alpha_composite(img, glow)
draw = ImageDraw.Draw(img)

# Everything below is kept within a safe zone (roughly the inner 78% of the
# canvas) so adaptive-icon masking on real launchers never clips it.
cake_w = 480
cake_cx = SIZE // 2 - 20

# ── Bottom tier (wider, pink) ────────────────────────────────────────────────
bot_w, bot_h = cake_w, 200
bot_x0 = cake_cx - bot_w // 2
bot_y0 = 660
draw.rounded_rectangle([bot_x0, bot_y0, bot_x0 + bot_w, bot_y0 + bot_h], radius=26, fill=PINK)
draw.rectangle([bot_x0, bot_y0, bot_x0 + bot_w, bot_y0 + 30], fill=CREAM)

# ── Top tier (narrower, coral) ───────────────────────────────────────────────
top_w, top_h = int(cake_w * 0.66), 165
top_x0 = cake_cx - top_w // 2
top_y0 = bot_y0 - top_h + 22
draw.rounded_rectangle([top_x0, top_y0, top_x0 + top_w, top_y0 + top_h], radius=22, fill=CORAL)
draw.rectangle([top_x0, top_y0, top_x0 + top_w, top_y0 + 24], fill=CREAM)

# Sprinkle dots on both tiers
random.seed(11)
for (x0, y0, w, h) in [(bot_x0, bot_y0 + 44, bot_w, bot_h - 54),
                       (top_x0, top_y0 + 38, top_w, top_h - 48)]:
    for _ in range(12):
        px = random.randint(x0 + 18, x0 + w - 18)
        py = random.randint(y0, y0 + h)
        col = random.choice([GOLD, LIME, CREAM])
        draw.ellipse([px - 6, py - 6, px + 6, py + 6], fill=col)

# ── Candle + flame ───────────────────────────────────────────────────────────
candle_w, candle_h = 30, 78
cand_x0 = cake_cx - candle_w // 2
cand_y0 = top_y0 - candle_h
draw.rounded_rectangle([cand_x0, cand_y0, cand_x0 + candle_w, cand_y0 + candle_h], radius=7, fill=GOLD)
for i in range(3):
    sy = cand_y0 + 15 + i * 20
    draw.rectangle([cand_x0, sy, cand_x0 + candle_w, sy + 7], fill=CORAL)

flame_cx, flame_cy = cake_cx, cand_y0 - 30
draw.ellipse([flame_cx - 22, flame_cy - 32, flame_cx + 22, flame_cy + 20], fill=GOLD)
draw.ellipse([flame_cx - 12, flame_cy - 16, flame_cx + 12, flame_cy + 16], fill=(255, 140, 60, 255))

# ── Notification bell badge, upper-right corner, fully inside the safe zone ─
bell_cx, bell_cy, bell_r = SIZE - 300, 300, 110

# White-on-background halo ring first, so the bell sits "on top" of a clean disc
draw.ellipse(
    [bell_cx - bell_r - 22, bell_cy - bell_r - 22, bell_cx + bell_r + 22, bell_cy + bell_r + 22],
    fill=BG,
)
draw.pieslice([bell_cx - bell_r, bell_cy - bell_r, bell_cx + bell_r, bell_cy + bell_r],
              180, 360, fill=LIME)
draw.rectangle([bell_cx - bell_r, bell_cy, bell_cx + bell_r, bell_cy + int(bell_r * 0.5)], fill=LIME)
draw.pieslice(
    [bell_cx - bell_r, bell_cy + int(bell_r * 0.05), bell_cx + bell_r, bell_cy + int(bell_r * 1.05)],
    0, 180, fill=LIME,
)
rail_y = bell_cy + int(bell_r * 0.58)
draw.rounded_rectangle(
    [bell_cx - int(bell_r * 1.05), rail_y, bell_cx + int(bell_r * 1.05), rail_y + 18],
    radius=9, fill=CREAM,
)
draw.ellipse([bell_cx - 16, rail_y + 18, bell_cx + 16, rail_y + 50], fill=CREAM)
draw.ellipse([bell_cx - 12, bell_cy - bell_r - 10, bell_cx + 12, bell_cy - bell_r + 14], fill=CREAM)

# ── Clip to circle ───────────────────────────────────────────────────────────
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).ellipse([0, 0, SIZE, SIZE], fill=255)
img.putalpha(mask)

out = os.path.join(os.path.dirname(__file__), "assets", "icon.png")
img.save(out)
print(f"Saved: {out}")
