"""
Generate TITLE.PCX for the SCROLLER demo.
320x160 title splash: deep-space nebula, starfield, large cruiser silhouette,
game title + tagline.
Run from any directory; output lands next to this script.
"""
import sys, os, math, random
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'scripts'))
import pbassets as A

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 320, 160

# ---------------------------------------------------------------------------
# Palette
#   0          : black (space background)
#   1..8       : deep-space gradient (nearly-black blues)
#   10..18     : nebula purples / magentas
#   20..27     : nebula teals / cyans
#   30..34     : star whites / bright
#   40..47     : ship body greys
#   50..55     : engine glow oranges / yellows
#   60..63     : title colour - cyan/white
#   70         : drop-shadow dark
#   71         : outline near-black
#   80..83     : press-key text
# ---------------------------------------------------------------------------
pal = [(0, 0, 0)] * 256

# space background blues
space_blues = [
    (  0,  0,  0),
    (  2,  2,  8),
    (  4,  4, 16),
    (  6,  6, 24),
    (  8,  9, 32),
    ( 10, 12, 40),
    ( 12, 15, 50),
    ( 14, 18, 60),
    ( 16, 22, 72),
]
for i, rgb in enumerate(space_blues):
    pal[i] = rgb

# nebula purples  10..18
nebula_purp = [
    ( 20,  4, 30), ( 30,  8, 50), ( 40, 10, 70), ( 55, 14, 90),
    ( 70, 18,110), ( 90, 22,130), (110, 28,148), (128, 34,160), (145, 40,170),
]
for i, rgb in enumerate(nebula_purp):
    pal[10 + i] = rgb

# nebula teals  20..27
nebula_teal = [
    (  4, 20, 30), (  8, 34, 52), ( 12, 50, 76), ( 18, 68,102),
    ( 24, 88,128), ( 32,108,152), ( 42,128,172), ( 54,148,190),
]
for i, rgb in enumerate(nebula_teal):
    pal[20 + i] = rgb

# stars  30..34
pal[30] = ( 60,  70,  90)   # faint
pal[31] = (120, 130, 150)   # medium
pal[32] = (180, 190, 210)   # bright
pal[33] = (220, 228, 245)   # very bright
pal[34] = (255, 255, 255)   # white hotspot

# ship body greys  40..47
ship_greys = [
    ( 20, 22, 28), ( 35, 38, 48), ( 50, 55, 68), ( 70, 76, 92),
    ( 95,102,120), (120,128,148), (148,156,176), (180,188,208),
]
for i, rgb in enumerate(ship_greys):
    pal[40 + i] = rgb

# engine glow  50..55
engine_glow = [
    (255, 120,   0), (255, 160,  20), (255, 200,  60),
    (255, 230, 100), (255, 245, 160), (255, 255, 220),
]
for i, rgb in enumerate(engine_glow):
    pal[50 + i] = rgb

# title text  60..63
pal[60] = (  0, 220, 255)   # bright cyan
pal[61] = (  0, 180, 220)   # mid cyan
pal[62] = ( 40, 240, 255)   # highlight
pal[63] = (255, 255, 255)   # pure white

# shadow / outline
pal[70] = (  0,  10,  20)   # very dark drop shadow
pal[71] = (  0,   0,   0)   # outline black

# press-key
pal[80] = (200, 210, 230)   # light blue-white
pal[81] = ( 80,  90, 110)   # dim shadow
pal[82] = (160, 170, 190)   # mid

# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------
img = A.canvas(W, H, 0)

# -- deep-space background gradient --
for y in range(H):
    ci = (y * 8) // max(1, H - 1)
    for x in range(W):
        img[y][x] = ci

# -- nebula clouds (soft disc blobs) --
random.seed(7)

def nebula_blob(cx, cy, rx, ry, base_ci, steps):
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            nx = cx + dx; ny = cy + dy
            if not (0 <= nx < W and 0 <= ny < H):
                continue
            d2 = (dx * dx) / max(1, rx * rx) + (dy * dy) / max(1, ry * ry)
            if d2 <= 1.0:
                depth = int(d2 * (steps - 1))
                ci = base_ci + depth
                # blend: only paint if darker than existing
                if img[ny][nx] < ci:
                    img[ny][nx] = ci

# purple nebula blob upper-left
nebula_blob( 60,  50, 80, 40, 10, 8)
nebula_blob( 40,  30, 50, 28, 10, 6)
# teal nebula blob right side
nebula_blob(240, 80, 70, 45, 20, 7)
nebula_blob(280, 50, 40, 30, 20, 5)
# small accent blobs
nebula_blob(160, 20, 30, 18, 12, 5)
nebula_blob(100,110, 40, 25, 21, 5)

# dither the nebula edges to look softer
for y in range(0, H, 3):
    for x in range(0, W, 3):
        if img[y][x] >= 10:
            A.dither(img, max(0, x-2), max(0, y-2), min(W-1, x+2), min(H-1, y+2),
                     img[y][x] - 1, step=2)

# -- starfield (three layers) --
random.seed(42)
# faint tiny stars
for _ in range(90):
    sx = random.randint(0, W - 1)
    sy = random.randint(0, H - 1)
    img[sy][sx] = 30

# medium stars
for _ in range(50):
    sx = random.randint(0, W - 1)
    sy = random.randint(0, H - 1)
    img[sy][sx] = 31

# bright stars
for _ in range(20):
    sx = random.randint(0, W - 1)
    sy = random.randint(0, H - 1)
    img[sy][sx] = 33
    # small cross sparkle
    if sx > 0: img[sy][sx - 1] = 31
    if sx < W-1: img[sy][sx + 1] = 31
    if sy > 0: img[sy - 1][sx] = 31
    if sy < H-1: img[sy + 1][sx] = 31

# hotspot star
img[25][250] = 34
img[24][250] = 33; img[26][250] = 33
img[25][249] = 33; img[25][251] = 33

# -- large cruiser silhouette centred lower half --
# The ship faces RIGHT, drawn as silhouette with multi-grey shading.
# Hull: long main body
sx0, sy0 = 40, 92   # nose tip
ship_len  = 220
ship_h_half = 12    # half-height at widest

def ship_profile(t):
    # t in 0..1 (nose=0, tail=1): returns half-height
    if t < 0.15:
        return int(t / 0.15 * ship_h_half * 0.6)
    if t < 0.5:
        return ship_h_half
    if t < 0.7:
        return int(ship_h_half * (1.0 - (t - 0.5) / 0.2 * 0.3))
    return int(ship_h_half * 0.5)

# draw hull column by column
for col in range(ship_len):
    cx = sx0 + col
    if cx >= W: break
    t = col / ship_len
    hw = ship_profile(t)
    # shade by depth from centre axis
    for dh in range(-hw, hw + 1):
        cy = sy0 + dh
        if not (0 <= cy < H): continue
        depth = abs(dh)
        if depth <= hw // 4:
            ci = 46   # brightest top highlight
        elif depth <= hw // 2:
            ci = 44
        elif depth <= hw * 3 // 4:
            ci = 42
        else:
            ci = 40
        img[cy][cx] = ci

# bridge superstructure (upper bump near middle)
bx = sx0 + ship_len // 3
for col in range(45):
    cx = bx + col
    if cx >= W: break
    t2 = col / 45
    bh = int(10 * math.sin(t2 * math.pi))
    for dh in range(-bh, 1):
        cy = sy0 - ship_h_half + dh
        if not (0 <= cy < H): continue
        ci = 45 if abs(dh) < bh // 2 else 43
        img[cy][cx] = ci

# lower fin
fx = sx0 + ship_len // 2
for col in range(30):
    cx = fx + col
    if cx >= W: break
    fh = int(14 * (1.0 - col / 30))
    for dh in range(ship_h_half, ship_h_half + fh + 1):
        cy = sy0 + dh
        if not (0 <= cy < H): continue
        img[cy][cx] = 41

# engine nacelles (3 glowing exhausts at tail)
tail_x = sx0 + ship_len - 4
for nacelle_y in [sy0 - 5, sy0, sy0 + 5]:
    # engine body
    A.rect(img, tail_x - 6, nacelle_y - 2, tail_x, nacelle_y + 2, 42)
    # glow rings
    A.disc(img, tail_x - 2, nacelle_y, 3, 52)
    A.disc(img, tail_x - 2, nacelle_y, 2, 53)
    A.disc(img, tail_x - 2, nacelle_y, 1, 55)
    # tail exhaust trail
    for tx2 in range(tail_x - 20, tail_x - 5):
        if 0 <= tx2 < W and 0 <= nacelle_y < H:
            t3 = (tail_x - tx2) / 15.0
            if t3 > 1: t3 = 1.0
            ci = 50 + int(t3 * 5)
            if ci > 55: ci = 55
            img[nacelle_y][tx2] = ci

# -- title text "SCROLLER" with drop-shadow + outline --
title = "SCROLLER"
tx = (W - len(title) * 8 * 3) // 2
ty = 18

# drop-shadow
A.text(img, tx + 3, ty + 4, title, 70, scale=3)
# outline
for ox, oy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
    A.text(img, tx + ox, ty + oy, title, 71, scale=3)
# main cyan fill
A.text(img, tx, ty, title, 60, scale=3)
# highlight top strip
for row_off in range(4):
    A.text(img, tx, ty + row_off * 3, title, 62, scale=3)

# -- subtitle --
sub = "BEYOND THE VOID"
sx2 = (W - len(sub) * 8) // 2
A.text(img, sx2 + 1, ty + 30, sub, 70, scale=1)
A.text(img, sx2,     ty + 29, sub, 61, scale=1)

# -- press any key --
pak = "PRESS ANY KEY"
px3 = (W - len(pak) * 8) // 2
A.text(img, px3 + 1, H - 20, pak, 81, scale=1)
A.text(img, px3,     H - 21, pak, 80, scale=1)

# ---------------------------------------------------------------------------
# Write
# ---------------------------------------------------------------------------
A.write_pcx8(os.path.join(HERE, 'TITLE.PCX'), pal, img)
sz = os.path.getsize(os.path.join(HERE, 'TITLE.PCX'))
print('TITLE.PCX  %d bytes  (320x%d, 8bpp)' % (sz, H))
print('Assets written.')
