# Generate assets for the TURNRPG demo:
#   TITLE.BMP  - JRPG title splash (320x200)
#   SLIME.GIF  -  48x40 monster
#   WOLF.GIF   -  64x44 monster
#   DEMON.GIF  -  80x64 boss monster
#
# GIF pixel indices are used DIRECTLY as VGA palette indices by DrawGif_Show.
# So every pixel value must be a valid TURNRPG game palette index.
# Sky gradient: index = 72 + (row*8)//200  (bgi 0..7).
# Ground strip: index 18 at y=130..145.
# Monster GIFs blend with the battle backdrop by matching sky indices per row.
#
# BMP loader sets the full 256-entry palette; values stored as 8-bit (0-255),
# divided by 4 to get VGA 6-bit (0-63).  Title splash uses its own palette.

import sys, os, math
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'scripts'))
import pbassets as A

HERE = os.path.dirname(__file__)

# ============================================================
# TURNRPG game palette (VGA 6-bit, as set by SetupPalette)
# Only indices actually used are listed; others default to 0.
# Used to verify GIF pixel indices map to correct game colours.
# ============================================================
# Index  0: black
# Index 15: white
# Index 16..20: overworld greens
# Index 21..22: path tan
# Index 23..24: mountain grey
# Index 25..26: town red/tan
# Index 27..28: cave grey
# Index 29..30: player blue
# Index 32..39: blue window gradient
# Index 40..43: gold/parchment
# Index 44: dark navy shadow (10,10,30)
# Index 48..55: skin/armor
# Index 56..57: slime greens
# Index 58..59: wolf browns
# Index 60..63: demon reds
# Index 64..71: battle flash colors
# Index 72..79: sky gradient (72+bgi, where bgi*2,bgi*3+4,bgi*5+8)

def sky_idx(screen_y):
    """Battle sky palette index for a given screen y coordinate."""
    bgi = (screen_y * 8) // 200
    if bgi > 7: bgi = 7
    return 72 + bgi

# ============================================================
# TITLE.BMP  320x200  deep blue JRPG splash
# ============================================================
# Palette strategy: title has its own decorative palette.
# DrawBmp_Show replaces the full VGA palette.
# The game calls SetupPalette(0) again after the splash.
# 8-bit values in BMP file; loader divides by 4 for VGA.

def vga(r6, g6, b6):
    return (r6 * 4, g6 * 4, b6 * 4)

tpal = [(0, 0, 0)] * 256
# 0: black
tpal[0] = vga(0, 0, 0)
# 1: near-black
tpal[1] = vga(2, 1, 4)
# 2-9: deep blue sky gradient (dark at top, lighter at bottom)
sky_grad = [
    (0, 0, 10), (0, 2, 16), (0, 4, 22), (2, 6, 28),
    (4, 8, 34), (6, 10, 40), (8, 12, 46), (10, 14, 52),
]
for i, rgb in enumerate(sky_grad):
    tpal[2 + i] = vga(*rgb)
# 10-15: mid-night navy (for stars bg band)
night_steps = [
    (0, 0, 14), (2, 2, 18), (4, 4, 22), (6, 6, 28),
    (8, 8, 32), (10, 10, 36)
]
for i, rgb in enumerate(night_steps):
    tpal[10 + i] = vga(*rgb)
# 16-23: gold title gradient
gold_steps = [
    (24, 12, 0), (32, 18, 0), (40, 26, 4), (48, 34, 6),
    (54, 42, 10), (58, 50, 14), (62, 56, 18), (63, 60, 24)
]
for i, rgb in enumerate(gold_steps):
    tpal[16 + i] = vga(*rgb)
# 24-31: silver/white range
silver_steps = [
    (24, 24, 28), (30, 30, 34), (38, 38, 42), (46, 46, 50),
    (52, 52, 56), (58, 58, 60), (61, 61, 63), (63, 63, 63)
]
for i, rgb in enumerate(silver_steps):
    tpal[24 + i] = vga(*rgb)
# 32-39: ornament purple/violet
purple_steps = [
    (10, 4, 16), (16, 6, 24), (22, 8, 32), (28, 10, 40),
    (34, 12, 48), (40, 14, 56), (46, 16, 62), (52, 18, 63)
]
for i, rgb in enumerate(purple_steps):
    tpal[32 + i] = vga(*rgb)
# 40-47: deep crimson for border accents
crimson_steps = [
    (16, 2, 2), (24, 4, 4), (30, 6, 6), (38, 8, 8),
    (44, 10, 10), (50, 12, 12), (56, 14, 14), (60, 16, 16)
]
for i, rgb in enumerate(crimson_steps):
    tpal[40 + i] = vga(*rgb)
# 48: bright star white
tpal[48] = vga(62, 62, 63)
# 49: dim star
tpal[49] = vga(40, 40, 50)
# 50: gold highlight
tpal[50] = vga(63, 62, 20)
# 51: shadow text
tpal[51] = vga(8, 6, 14)
# 52: blue-grey (border mid)
tpal[52] = vga(16, 16, 28)
# 53: warm off-white (subtitle text)
tpal[53] = vga(58, 56, 44)
# 54: medium gold
tpal[54] = vga(50, 38, 8)
# 55: pale ice blue
tpal[55] = vga(30, 36, 52)

TW, TH = 320, 200
timg = A.canvas(TW, TH, 2)

# Deep blue vertical gradient (top dark, bottom less dark)
for y in range(TH):
    c = 2 + (y * 6) // TH
    if c > 8: c = 8
    A.rect(timg, 0, y, TW - 1, y, c)

# Starfield (deterministic scatter)
stars = []
for i in range(120):
    sx = (i * 137 + 13) % 296 + 12
    sy = (i * 97 + 7) % 155 + 8
    bright = (i % 3 == 0)
    stars.append((sx, sy, bright))
for sx, sy, bright in stars:
    timg[sy][sx] = 48 if bright else 49
    if bright and sy + 1 < TH and sx + 1 < TW:
        timg[sy][sx + 1] = 49
        timg[sy + 1][sx] = 49

# Horizontal glowing band across middle (title area ambience)
for y in range(TH // 2 - 30, TH // 2 + 30):
    glow = 1 - abs(y - TH // 2) / 30.0
    if glow > 0:
        c = 10 + int(glow * 5)
        A.rect(timg, 0, y, TW - 1, y, c)
        # re-stamp stars that were in this band
for sx, sy, bright in stars:
    if TH // 2 - 30 <= sy <= TH // 2 + 30:
        timg[sy][sx] = 48 if bright else 49

# Double ornate border
A.rect(timg, 2, 2, TW - 3, TH - 3, 32)
A.rect(timg, 3, 3, TW - 4, TH - 4, 33)
A.rect(timg, 5, 5, TW - 6, TH - 6, 34)
A.rect(timg, 6, 6, TW - 7, TH - 7, 34)
# Inner gold border
A.rect(timg, 8, 8, TW - 9, TH - 9, 16)
A.rect(timg, 9, 9, TW - 10, TH - 10, 17)
# Corner stars / diamonds
for cx, cy in [(12, 12), (TW - 13, 12), (12, TH - 13), (TW - 13, TH - 13)]:
    A.putpx(timg, cx, cy, 50)
    A.putpx(timg, cx - 1, cy, 50); A.putpx(timg, cx + 1, cy, 50)
    A.putpx(timg, cx, cy - 1, 50); A.putpx(timg, cx, cy + 1, 50)
    A.putpx(timg, cx - 2, cy, 50); A.putpx(timg, cx + 2, cy, 50)

# Title "QUEST OF" line 1 (scale 2, gold)
line1 = "QUEST OF"
tl1w = len(line1) * 8 * 2
tl1x = (TW - tl1w) // 2
A.text(timg, tl1x + 1, 67 + 1, line1, 51, scale=2)
A.text(timg, tl1x, 67, line1, 54, scale=2)

# Title "ETERNAL SHADOW" line 2 (scale 3, bright gold)
line2 = "ETERNAL SHADOW"
tl2w = len(line2) * 8 * 3
tl2x = (TW - tl2w) // 2
A.text(timg, tl2x + 2, 84 + 2, line2, 1, scale=3)
A.text(timg, tl2x + 1, 84 + 1, line2, 16, scale=3)
A.text(timg, tl2x, 84, line2, 23, scale=3)

# Decorative horizontal rule
A.rect(timg, 16, 80, TW - 17, 81, 54)
A.rect(timg, 16, 114, TW - 17, 115, 54)
A.putpx(timg, TW // 2, 80, 50); A.putpx(timg, TW // 2, 114, 50)

# Subtitle "A Tale of Heroes and Darkness" (scale 1, ice blue)
sub = "A Tale of Heroes and Darkness"
subw = len(sub) * 8
subx = (TW - subw) // 2
A.text(timg, subx + 1, 120 + 1, sub, 51, scale=1)
A.text(timg, subx, 120, sub, 55, scale=1)

# Vertical dividers on subtitle line
A.putpx(timg, subx - 6, 123, 50)
A.putpx(timg, subx + subw + 5, 123, 50)

# "PRESS ANY KEY" footer
foot = "- PRESS ANY KEY -"
fw = len(foot) * 8
fx = (TW - fw) // 2
A.text(timg, fx + 1, 178 + 1, foot, 1, scale=1)
A.text(timg, fx, 178, foot, 53, scale=1)

A.write_bmp8(os.path.join(HERE, 'TITLE.BMP'), tpal, timg)
tsz = os.path.getsize(os.path.join(HERE, 'TITLE.BMP'))
print('Wrote TITLE.BMP -', tsz, 'bytes')

# ============================================================
# Helper: monster canvas with sky-matched background
# GIF pixels are VGA palette indices directly.
# Background rows use sky_idx(abs_y) where abs_y is screen y
# of the top of the monster sprite.
# ============================================================

def make_monster_gif(filename, w, h, draw_fn, abs_top_y):
    """
    Create a monster GIF.
    draw_fn(img, w, h) draws the monster onto the canvas.
    Background pixels are set per-row to match the battle sky.
    abs_top_y: screen y where the top of the GIF will be drawn.
    """
    img = [[0] * w for _ in range(h)]
    # Fill background per row with matching sky colour
    for row in range(h):
        bg = sky_idx(abs_top_y + row)
        for col in range(w):
            img[row][col] = bg
    draw_fn(img, w, h)
    # Build a dummy palette (256 entries, RGB 8-bit)
    # Values are irrelevant for rendering (DrawGif_DrawPixelData uses indices
    # directly as VGA indices), but the GIF format requires a colour table.
    # Use zeros for all entries.
    dummy_pal = [(0, 0, 0)] * 256
    A.write_gif87(os.path.join(HERE, filename), dummy_pal, img)
    sz = os.path.getsize(os.path.join(HERE, filename))
    print('Wrote', filename, '-', sz, 'bytes', w, 'x', h)

# ============================================================
# SLIME.GIF  48x40
# Drawn at: mox=60, moy~=75 (bob=0 for smoke)
# Centre of circle: mox=60, moy+12=87  -> abs_top = moy = 75
# Palette colours used:
#   56 = slime mid-green (20,50,20 VGA)
#   57 = slime dark-green (10,35,10 VGA)
#   44 = shadow/outline navy (10,10,30 VGA)
#   67 = battle white/eye (63,63,63 VGA)
#   0  = pure black
# ============================================================

def draw_slime(img, w, h):
    # From TURNRPG DrawMonster mi=0:
    # FillCircle(b1=mx, b2=my+12, r=15, c3=44) - shadow disc
    # FillCircle(b1=mx, b2=my+12, r=14, c1=56) - main body
    # shade loop: HLines getting shorter (c2=57)
    # eye: FillCircle(ox=mx-4, oy=my+7, r=3, 67)
    # pupils: PutPixel at (mx-3,my+10,c3=44) and (mx+3,my+10,c3=44)
    # Mirror drawing with mx=w//2, my=0 (GIF local origin)
    mx = w // 2
    my = 0
    c1 = 56  # slime mid-green
    c2 = 57  # slime dark lower half
    c3 = 44  # shadow navy
    # Shadow disc
    A.disc(img, mx, my + 12, 15, c3)
    # Body disc
    A.disc(img, mx, my + 12, 14, c1)
    # Lower shading strips (replicating the game's loop)
    for shi in range(9):
        sx1 = mx - 13 + shi
        sx2 = mx + 13 - shi
        sy = my + 12 + 5 + shi
        if sy <= my + 26:
            A.rect(img, sx1, sy, sx2, sy, c2)
    # Eye (white)
    A.disc(img, mx - 4, my + 7, 3, 67)
    # Pupils
    A.putpx(img, mx - 3, my + 10, c3)
    A.putpx(img, mx + 3, my + 10, c3)
    # Highlight dot
    A.putpx(img, mx - 5, my + 6, 67)

make_monster_gif('SLIME.GIF', 48, 40, draw_slime, abs_top_y=75)

# ============================================================
# WOLF.GIF  64x44
# Drawn at: mox=115, moy~=75 (bob=0 for smoke)
# abs_top = moy = 75
# Palette colours used:
#   58 = wolf mid-brown (40,30,10 VGA)
#   59 = wolf dark-brown (25,18,5 VGA)
#   44 = shadow navy
#   67 = white (eye/fang)
#   0  = black
# From DrawMonster mi=1:
#   FillRect(mx-15,my+4, mx+15,my+22, c3=44) - outline box
#   FillRect(mx-14,my+5, mx+14,my+21, c1=58) - body fill
#   FillRect(mx+2,my+6,  mx+14,my+20, c2=59) - dark flank
#   FillRect(mx-18,my,   mx-8,my+10,  c1=58) - head
#   FillRect(mx-22,my+4, mx-14,my+8,  c1=58) - snout
#   PutPixel(mx-15,my+3, c3=44) - eye
#   FillRect(mx-10,my+22,mx-7,my+30,  c2=59) - front leg
#   FillRect(mx,my+22,   mx+3,my+30,  c2=59) - rear leg
#   LineDraw(mx+12,my,   mx+18,my+8,  c1=58) - tail
# ============================================================

def draw_wolf(img, w, h):
    mx = w // 2
    my = 0
    c1 = 58  # wolf mid-brown
    c2 = 59  # wolf dark-brown
    c3 = 44  # shadow navy
    # Shadow outline
    A.rect(img, mx - 15, my + 4, mx + 15, my + 22, c3)
    # Body
    A.rect(img, mx - 14, my + 5, mx + 14, my + 21, c1)
    # Dark flank shading
    A.rect(img, mx + 2, my + 6, mx + 14, my + 20, c2)
    # Head
    A.rect(img, mx - 18, my, mx - 8, my + 10, c1)
    # Snout
    A.rect(img, mx - 22, my + 4, mx - 14, my + 8, c1)
    # Eye pixel
    A.putpx(img, mx - 15, my + 3, c3)
    # Fang highlights
    A.putpx(img, mx - 20, my + 8, 67)
    A.putpx(img, mx - 19, my + 8, 67)
    # Highlight on head
    A.rect(img, mx - 17, my + 1, mx - 14, my + 3, 59)
    # Front leg
    A.rect(img, mx - 10, my + 22, mx - 7, my + 30, c2)
    # Rear leg
    A.rect(img, mx, my + 22, mx + 3, my + 30, c2)
    # Mid leg pair
    A.rect(img, mx - 4, my + 22, mx - 2, my + 28, c1)
    A.rect(img, mx + 5, my + 22, mx + 7, my + 28, c1)
    # Tail
    A.rect(img, mx + 12, my, mx + 18, my + 2, c1)
    A.rect(img, mx + 14, my + 2, mx + 19, my + 4, c1)
    A.rect(img, mx + 16, my + 4, mx + 20, my + 6, c1)
    # Ear
    A.rect(img, mx - 17, my - 2, mx - 13, my, c1)
    A.putpx(img, mx - 14, my - 3, c3)

make_monster_gif('WOLF.GIF', 64, 44, draw_wolf, abs_top_y=75)

# ============================================================
# DEMON.GIF  80x64
# Boss drawn by DrawBossMonster(bx, by) with bx~=60, by~=75
# abs_top = 75
# From DrawBossMonster:
#   FillRect(bx-22,by,   bx+22,by+40, 63) - body dark-red
#   horns (triangles/rects) in 62 (bright magenta-red)
#   FillRect(bx-18,by+5, bx+18,by+35, 60) - main body bright-red
#   FillRect(bx-14,by+10,bx+14,by+30, 61) - dark centre
#   Eyes in 67 (white), pupils in 63
#   Wings FillRect in 62
#   Mouth: LineDraw in 0
# ============================================================

def draw_demon(img, w, h):
    bx = w // 2
    by = 0
    # Outer body + shadow
    A.rect(img, bx - 22, by, bx + 22, by + 40, 63)
    # Wing-like extensions
    A.rect(img, bx - 30, by + 5, bx - 22, by + 25, 62)
    A.rect(img, bx + 22, by + 5, bx + 30, by + 25, 62)
    # Wing detail
    A.rect(img, bx - 34, by + 10, bx - 30, by + 20, 63)
    A.rect(img, bx + 30, by + 10, bx + 34, by + 20, 63)
    # Main body
    A.rect(img, bx - 18, by + 5, bx + 18, by + 35, 60)
    # Dark centre / belly
    A.rect(img, bx - 14, by + 10, bx + 14, by + 30, 61)
    # Belly highlight strip
    A.rect(img, bx - 6, by + 12, bx + 6, by + 26, 60)
    # Horns
    for i in range(8):
        A.putpx(img, bx - 10 + i // 2, by - i, 62)
        A.putpx(img, bx + 10 - i // 2, by - i, 62)
    # Outline horns darker
    A.putpx(img, bx - 10, by, 63); A.putpx(img, bx + 10, by, 63)
    # Eyes
    A.disc(img, bx - 7, by + 10, 4, 67)
    A.disc(img, bx + 7, by + 10, 4, 67)
    # Pupils
    A.disc(img, bx - 7, by + 10, 2, 63)
    A.disc(img, bx + 7, by + 10, 2, 63)
    # Eye glow (inner)
    A.putpx(img, bx - 7, by + 9, 64)
    A.putpx(img, bx + 7, by + 9, 64)
    # Snout / face structure
    A.rect(img, bx - 8, by + 16, bx + 8, by + 24, 61)
    # Mouth slash
    for i in range(-6, 7):
        my2 = by + 21 + (abs(i) > 3)
        if 0 <= bx + i < w and 0 <= my2 < h:
            img[my2][bx + i] = 0
    # Claws at bottom
    A.rect(img, bx - 22, by + 36, bx - 18, by + 40, 63)
    A.rect(img, bx - 16, by + 37, bx - 12, by + 42, 0)
    A.rect(img, bx - 8, by + 37, bx - 4, by + 42, 0)
    A.rect(img, bx + 4, by + 37, bx + 8, by + 42, 0)
    A.rect(img, bx + 12, by + 37, bx + 16, by + 42, 0)
    A.rect(img, bx + 18, by + 36, bx + 22, by + 40, 63)
    # Foot pads
    for ox in [-15, -7, 5, 13]:
        A.putpx(img, bx + ox, by + 42, 63)
    # Highlight on body
    A.rect(img, bx - 4, by + 7, bx + 4, by + 14, 64)

make_monster_gif('DEMON.GIF', 80, 64, draw_demon, abs_top_y=75)

print('All TURNRPG assets generated.')
