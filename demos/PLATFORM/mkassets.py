"""
Generate TITLE.BMP for the PLATFORM demo.
320x160 title splash: sky gradient, rolling hills silhouette, game title + tagline.
Run from any directory; output lands next to this script.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'scripts'))
import pbassets as A

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 320, 160

# ---------------------------------------------------------------------------
# Palette
# Index layout:
#   0          : black (unused / border)
#   1..16      : sky gradient deep-blue -> light-blue (16 steps)
#   17..24     : far-hill silhouette greens (dark -> mid)
#   25..32     : near-hill silhouette greens (darker)
#   33..36     : cloud whites / greys
#   40..47     : title text yellow-orange
#   48         : drop-shadow dark brown
#   49         : outline black-ish
#   50..57     : press-key text: bright white, dim grey for shadow
#   60..63     : ground stripe browns
# ---------------------------------------------------------------------------
pal = [(0, 0, 0)] * 256

# sky: indices 1..16  deep-blue (#050830) -> light-sky-blue (#82CAFF)
sky_stops = [
    (5,   8,  48),   # 1
    (8,  14,  62),   # 2
    (10, 20,  74),   # 3
    (14, 28,  90),   # 4
    (18, 36, 108),   # 5
    (24, 46, 126),   # 6
    (30, 58, 148),   # 7
    (40, 72, 168),   # 8
    (52, 90, 188),   # 9
    (64,108, 204),   # 10
    (78,126, 218),   # 11
    (94,144, 228),   # 12
    (112,162,238),   # 13
    (130,180,248),   # 14
    (148,198,254),   # 15
    (166,210,255),   # 16
]
for i, (r, g, b) in enumerate(sky_stops):
    pal[1 + i] = (r, g, b)

# clouds: 33..36
pal[33] = (220, 230, 255)
pal[34] = (200, 212, 245)
pal[35] = (180, 192, 230)
pal[36] = (240, 245, 255)

# far hills: 17..24 (dark forest green)
far_greens = [
    (10, 30, 10), (14, 42, 14), (18, 52, 18), (22, 60, 22),
    (28, 70, 28), (34, 80, 34), (40, 90, 38), (46,100, 42),
]
for i, rgb in enumerate(far_greens):
    pal[17 + i] = rgb

# near hills: 25..32 (richer dark green)
near_greens = [
    (5,  18,  5), (8,  26,  8), (12, 36, 12), (16, 46, 16),
    (20, 56, 20), (26, 66, 24), (32, 76, 28), (38, 86, 32),
]
for i, rgb in enumerate(near_greens):
    pal[25 + i] = rgb

# title text: warm yellows + orange
pal[40] = (255, 220,  0)   # main yellow
pal[41] = (255, 180,  0)   # warm orange tint
pal[42] = (255, 240, 60)   # highlight
pal[43] = (200, 140,  0)   # shadow-mid
pal[48] = ( 40,  20,  0)   # drop-shadow very dark
pal[49] = (  0,   0,  0)   # outline black

# press-key text
pal[50] = (240, 240, 240)  # bright white
pal[51] = (120, 120, 120)  # shadow grey
pal[52] = (200, 200, 200)  # dim white

# ground stripe
pal[60] = ( 80, 50, 20)
pal[61] = (110, 70, 30)
pal[62] = ( 60, 38, 14)

# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------
img = A.canvas(W, H, 0)

# -- sky gradient (band every ~10 rows, 16 bands across H rows) --
bands = 16
for y in range(H):
    ci = 1 + (y * (bands - 1)) // max(1, H - 1)
    if ci > 16: ci = 16
    for x in range(W):
        img[y][x] = ci

# -- dither banding to soften gradient (every 4th band boundary) --
for band in range(1, bands):
    by = (band * (H - 1)) // (bands - 1)
    A.dither(img, 0, by - 1, W - 1, by, band, step=2)

# -- clouds (simple horizontal blobs) --
def cloud(cx, cy, rx, ry):
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            if (dx * dx * ry * ry + dy * dy * rx * rx) <= rx * rx * ry * ry:
                x = cx + dx
                y = cy + dy
                if 0 <= x < W and 0 <= y < H:
                    # colour by height within cloud
                    if dy < -ry // 2:
                        img[y][x] = 36
                    elif dy < 0:
                        img[y][x] = 33
                    else:
                        img[y][x] = 34

cloud(60,  28, 34, 12)
cloud(200, 20, 28, 10)
cloud(290, 35, 22,  9)
cloud(130, 40, 18,  7)

# -- far rolling hills (silhouette, peaks offset per column) --
import math
def hill_height_far(x):
    # sum of two sine waves
    v = (math.sin(x * 0.035 + 0.5) * 18 +
         math.sin(x * 0.018 + 1.2) * 12)
    return int(100 + v)

far_base = H  # draw from hill top to image bottom
for x in range(W):
    top = hill_height_far(x)
    for y in range(top, H):
        depth = min(7, (y - top) * 8 // max(1, H - top))
        img[y][x] = 17 + depth

# -- near rolling hills (taller, darker, different frequency) --
def hill_height_near(x):
    v = (math.sin(x * 0.025 + 2.0) * 22 +
         math.sin(x * 0.011 + 0.7) * 14)
    return int(112 + v)

for x in range(W):
    top = hill_height_near(x)
    for y in range(top, H):
        depth = min(7, (y - top) * 8 // max(1, H - top))
        img[y][x] = 25 + depth

# -- ground stripe at bottom --
A.rect(img, 0, H - 12, W - 1, H - 1, 60)
A.rect(img, 0, H - 11, W - 1, H - 8,  61)
A.rect(img, 0, H - 7,  W - 1, H - 1,  62)

# -- title text "PLATFORM" with drop-shadow + outline --
title = "PLATFORM"
tx = (W - len(title) * 8 * 3) // 2
ty = 52

# drop-shadow (2px offset)
A.text(img, tx + 3, ty + 4, title, 48, scale=3)
# outline (4 directions)
A.text(img, tx - 1, ty,     title, 49, scale=3)
A.text(img, tx + 1, ty,     title, 49, scale=3)
A.text(img, tx,     ty - 1, title, 49, scale=3)
A.text(img, tx,     ty + 1, title, 49, scale=3)
# main fill: gradient effect using two passes
A.text(img, tx, ty, title, 40, scale=3)
# highlight strip on top third
for row_off in range(8):
    A.text(img, tx, ty + row_off * 3, title, 42 if row_off < 3 else 40, scale=3)

# -- subtitle --
sub = "A PIXEL ADVENTURE"
sx = (W - len(sub) * 8) // 2
A.text(img, sx + 1, ty + 30, sub, 48, scale=1)
A.text(img, sx,     ty + 29, sub, 41, scale=1)

# -- press any key --
pak = "PRESS ANY KEY"
px2 = (W - len(pak) * 8) // 2
A.text(img, px2 + 1, H - 26, pak, 51, scale=1)
A.text(img, px2,     H - 27, pak, 50, scale=1)

# ---------------------------------------------------------------------------
# Write
# ---------------------------------------------------------------------------
A.write_bmp8(os.path.join(HERE, 'TITLE.BMP'), pal, img)
print('TITLE.BMP  %d bytes  (320x%d, 8bpp)' % (
    os.path.getsize(os.path.join(HERE, 'TITLE.BMP')), H))
print('Assets written.')
