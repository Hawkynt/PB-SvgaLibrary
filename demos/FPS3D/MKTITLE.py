"""
Generate TITLE.PCX for FPS3D: a 320x200 stone-corridor title splash.
Scene: dark converging stone corridor with glowing exit, chiseled game
title, tagline, and key-prompt.
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'scripts'))
import pbassets as A

W, H = 320, 200

# ---- palette -----------------------------------------------------------------
# We use 8-bit DAC-scale (0-63) for the original palette convention,
# but pbassets writers store them directly, so we use 0-255 here.
pal = [(0, 0, 0)] * 256

def set_pal(idx, r, g, b):
    pal[idx] = (r, g, b)

# 0 = black background
set_pal(0, 0, 0, 0)

# Stone wall shading: indices 1-32 (darker toward edges, brighter center)
# Dark grey-blue stone range: 8 shades, 4 hue variants
for shade in range(8):
    t = shade / 7.0
    # cold grey-stone: slightly blue-tinged
    r = int(18 + t * 40)
    g = int(18 + t * 38)
    b = int(22 + t * 44)
    set_pal(1 + shade, r, g, b)      # floor/ceiling cold grey
    # warm mossy grey
    r2 = int(20 + t * 35)
    g2 = int(22 + t * 40)
    b2 = int(16 + t * 30)
    set_pal(9 + shade, r2, g2, b2)   # wall sides warm
    # deep shadow
    r3 = int(8 + t * 25)
    g3 = int(8 + t * 22)
    b3 = int(10 + t * 28)
    set_pal(17 + shade, r3, g3, b3)  # far/shadowed stone
    # dither blend
    r4 = int(14 + t * 32)
    g4 = int(13 + t * 30)
    b4 = int(18 + t * 36)
    set_pal(25 + shade, r4, g4, b4)  # dither intermediate

# Exit glow: green-yellow radiance at indices 33-48
for i in range(16):
    t = i / 15.0
    r = int(60 + t * 195)
    g = int(120 + t * 135)
    b = int(0 + t * 30)
    set_pal(33 + i, r, g, b)

# Title text - chiseled: highlight (50), midtone (51), shadow (52), drop (53-54)
set_pal(50, 230, 220, 190)   # bright highlight
set_pal(51, 160, 150, 125)   # midtone
set_pal(52, 80,  72,  60)    # shadow face
set_pal(53, 25,  22,  18)    # dark drop shadow 1
set_pal(54, 12,  10,   8)    # darker drop shadow 2

# Tagline / prompt colours
set_pal(55, 180, 165, 130)   # warm parchment tagline
set_pal(56, 100,  90,  70)   # dimmer tagline
set_pal(57, 200, 190, 160)   # "PRESS ANY KEY" bright
set_pal(58,  90,  85,  65)   # "PRESS ANY KEY" dim

# Dither pairs for walls
set_pal(60, 30, 28, 35)   # dark wall dither A
set_pal(61, 42, 40, 48)   # dark wall dither B
set_pal(62, 55, 52, 62)   # mid wall dither A
set_pal(63, 68, 65, 76)   # mid wall dither B

# Floor/ceiling centre
set_pal(64, 15, 14, 18)
set_pal(65, 22, 20, 26)
set_pal(66, 32, 30, 38)
set_pal(67, 42, 40, 50)

# Horizon/floor distant dither
set_pal(68, 8, 8, 10)
set_pal(69, 12, 11, 14)

# ---- scene -------------------------------------------------------------------
img = A.canvas(W, H, 0)

# Sky/ceiling: very dark blue-grey gradient top to vanishing point
vp_y = 90   # vanishing point Y
for y in range(0, vp_y):
    # ceiling darkens toward the top
    t = (vp_y - y) / vp_y
    shade = int(t * 7)
    A.rect(img, 0, y, W - 1, y, 1 + shade)

# Floor: dark brown-grey gradient from horizon to bottom
for y in range(vp_y, H):
    t = (y - vp_y) / (H - vp_y)
    shade = int(t * 7)
    A.rect(img, 0, y, W - 1, y, 1 + (7 - shade))  # floor slightly lighter near horizon

# Corridor walls - converging perspective lines
# The corridor is a rectangular tunnel: left wall, right wall, floor, ceiling
# Converging from full-screen edges to a central vanishing point rectangle

cx = 160  # vanishing point X center
vy_top = vp_y - 22   # top of exit portal
vy_bot = vp_y + 22   # bottom of exit portal
vx_l = cx - 20       # exit portal left
vx_r = cx + 20       # exit portal right

# Draw wall panels by filling trapezoids row by row
for y in range(0, H):
    # Left wall trapezoid
    if y < vp_y:
        # ceiling slope - top portion
        t = y / vp_y if vp_y > 0 else 1
        wall_rx = int(vx_l + (0 - vx_l) * (1 - t))
        wall_lx = 0
        if wall_lx < wall_rx:
            shade_idx = min(7, int((1 - t) * 7))
            A.rect(img, wall_lx, y, wall_rx, y, 9 + shade_idx)
            # dither edge
            A.dither(img, wall_rx - 4, y, wall_rx, y, 25 + shade_idx, 2)
    else:
        # floor slope - bottom portion
        t = (y - vp_y) / (H - vp_y) if H > vp_y else 1
        wall_rx = int(vx_l + (0 - vx_l) * t)
        wall_lx = 0
        if wall_lx < wall_rx:
            shade_idx = min(7, int(t * 7))
            A.rect(img, wall_lx, y, wall_rx, y, 9 + shade_idx)
            A.dither(img, wall_rx - 4, y, wall_rx, y, 25 + shade_idx, 2)

    # Right wall trapezoid
    if y < vp_y:
        t = y / vp_y if vp_y > 0 else 1
        wall_lx = int(vx_r + (W - 1 - vx_r) * (1 - t))
        wall_rx = W - 1
        if wall_lx < wall_rx:
            shade_idx = min(7, int((1 - t) * 7))
            A.rect(img, wall_lx, y, wall_rx, y, 9 + shade_idx)
            A.dither(img, wall_lx, y, wall_lx + 4, y, 25 + shade_idx, 2)
    else:
        t = (y - vp_y) / (H - vp_y) if H > vp_y else 1
        wall_lx = int(vx_r + (W - 1 - vx_r) * t)
        wall_rx = W - 1
        if wall_lx < wall_rx:
            shade_idx = min(7, int(t * 7))
            A.rect(img, wall_lx, y, wall_rx, y, 9 + shade_idx)
            A.dither(img, wall_lx, y, wall_lx + 4, y, 25 + shade_idx, 2)

# Ceiling panel (top band between walls)
for y in range(0, vp_y):
    t = y / vp_y if vp_y > 0 else 1
    lx = int(vx_l + (0 - vx_l) * (1 - t))
    rx = int(vx_r + (W - 1 - vx_r) * (1 - t))
    shade_idx = min(7, int((1 - t) * 5))
    if lx < rx:
        A.rect(img, lx, y, rx, y, 17 + shade_idx)

# Floor panel (bottom band)
for y in range(vp_y, H):
    t = (y - vp_y) / (H - vp_y) if H > vp_y else 1
    lx = int(vx_l + (0 - vx_l) * t)
    rx = int(vx_r + (W - 1 - vx_r) * t)
    shade_idx = min(7, int((1 - t) * 5))
    if lx < rx:
        A.rect(img, lx, y, rx, y, 17 + shade_idx)

# Stone block mortar lines on walls - horizontal seams every ~16 rows
for seam_y in range(16, H, 18):
    # left wall
    for y_off in range(seam_y, seam_y + 2):
        if 0 <= y_off < H:
            if y_off < vp_y:
                t = y_off / vp_y if vp_y > 0 else 1
                wall_rx = int(vx_l + (0 - vx_l) * (1 - t))
                A.rect(img, 0, y_off, max(0, wall_rx - 1), y_off, 17)
            else:
                t = (y_off - vp_y) / (H - vp_y) if H > vp_y else 1
                wall_rx = int(vx_l + (0 - vx_l) * t)
                A.rect(img, 0, y_off, max(0, wall_rx - 1), y_off, 17)
    # right wall
    for y_off in range(seam_y, seam_y + 2):
        if 0 <= y_off < H:
            if y_off < vp_y:
                t = y_off / vp_y if vp_y > 0 else 1
                wall_lx = int(vx_r + (W - 1 - vx_r) * (1 - t))
                A.rect(img, min(W-1, wall_lx + 1), y_off, W - 1, y_off, 17)
            else:
                t = (y_off - vp_y) / (H - vp_y) if H > vp_y else 1
                wall_lx = int(vx_r + (W - 1 - vx_r) * t)
                A.rect(img, min(W-1, wall_lx + 1), y_off, W - 1, y_off, 17)

# Exit glow - radiant yellow-green rectangle at vanishing point
# Halo rings around the portal
for ring in range(30, 0, -1):
    t = ring / 30.0
    glow_idx = 33 + int(t * 15)
    rx1 = vx_l - ring
    rx2 = vx_r + ring
    ry1 = vy_top - ring
    ry2 = vy_bot + ring
    if rx1 < 0: rx1 = 0
    if rx2 > W-1: rx2 = W-1
    if ry1 < 0: ry1 = 0
    if ry2 > H-1: ry2 = H-1
    # Only draw edges of the ring (not fill, to build up glow bands)
    A.rect(img, rx1, ry1, rx2, ry1, glow_idx)
    A.rect(img, rx1, ry2, rx2, ry2, glow_idx)
    A.rect(img, rx1, ry1, rx1, ry2, glow_idx)
    A.rect(img, rx2, ry1, rx2, ry2, glow_idx)

# Dithered glow halo blending with wall
for ring in range(8, 0, -1):
    glow_idx = 33 + ring
    A.dither(img, vx_l - ring - 10, vy_top - ring, vx_l - ring, vy_bot + ring, glow_idx, 2)
    A.dither(img, vx_r + ring, vy_top - ring, vx_r + ring + 10, vy_bot + ring, glow_idx, 2)

# Bright portal interior
A.rect(img, vx_l, vy_top, vx_r, vy_bot, 48)  # brightest glow
set_pal(48, 255, 240, 100)

# ---- TITLE TEXT with chiseled multi-shadow -----------------------------------
title = "FPS 3D"
ts = 3   # scale
tw = len(title) * 8 * ts
tx = (W - tw) // 2
ty = 12

# Double drop shadow layers
A.text(img, tx + 6, ty + 6, title, 54, scale=ts)
A.text(img, tx + 4, ty + 4, title, 53, scale=ts)
# Shadow face
A.text(img, tx + 2, ty + 2, title, 52, scale=ts)
# Mid-tone face
A.text(img, tx + 1, ty + 1, title, 51, scale=ts)
# Highlight face
A.text(img, tx,     ty,     title, 50, scale=ts)
# Top-left specular gleam on first two chars
A.text(img, tx - 1, ty - 1, "FP", 50, scale=ts)

# ---- Tagline: "FIND THE EXIT" ------------------------------------------------
tag = "FIND THE EXIT"
tag_ts = 2
tag_tw = len(tag) * 8 * tag_ts
tag_tx = (W - tag_tw) // 2
tag_ty = ty + 8 * ts + 10
# shadow
A.text(img, tag_tx + 2, tag_ty + 2, tag, 53, scale=tag_ts)
A.text(img, tag_tx + 1, tag_ty + 1, tag, 56, scale=tag_ts)
A.text(img, tag_tx,     tag_ty,     tag, 55, scale=tag_ts)

# ---- Separator line ----------------------------------------------------------
sep_y = tag_ty + 8 * tag_ts + 6
A.rect(img, 40, sep_y, W - 41, sep_y,     51)
A.rect(img, 40, sep_y + 1, W - 41, sep_y + 1, 52)

# ---- "PRESS ANY KEY" at bottom -----------------------------------------------
pak = "PRESS ANY KEY"
pak_ts = 1
pak_tw = len(pak) * 8
pak_tx = (W - pak_tw) // 2
pak_ty = H - 18
A.text(img, pak_tx + 1, pak_ty + 1, pak, 58, scale=pak_ts)
A.text(img, pak_tx,     pak_ty,     pak, 57, scale=pak_ts)

# ---- Write out ---------------------------------------------------------------
out_path = os.path.join(os.path.dirname(__file__), 'TITLE.PCX')
A.write_pcx8(out_path, pal, img)
sz = os.path.getsize(out_path)
print('Written %s  %d bytes' % (out_path, sz))
assert sz < 65536, 'PCX too large: %d bytes (RLE should compress well)' % sz
print('OK')
