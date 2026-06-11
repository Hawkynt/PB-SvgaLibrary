"""
Generate TITLE.GIF for RACER: a 224x140 sunset-highway title splash.
Scene: banded gradient sunset sky with dithered sun disc, road vanishing
to horizon with perspective stripes, palm tree silhouettes, chrome title.

Uses a proper LZW encoder (not pbassets write_gif87) so the GIF library
decoder handles far fewer codes on a 224x140 image (horizontal bands
compress very well with LZW).

224x140 = 31360 pixels; the DOS GIF decoder crashes above ~32640 pixels
due to a signed-integer overflow in decodedData string length tracking.
"""
import sys, os, math, struct
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'scripts'))
import pbassets as A

W, H = 224, 140
HORIZON = 84    # horizon line y (60% down = 84 of 140)

# ---- palette -----------------------------------------------------------------
pal = [(0, 0, 0)] * 256

def sp(idx, r, g, b):
    pal[idx] = (r, g, b)

# Sky gradient: 24 bands from top (deep indigo) to horizon (hot orange-red)
# indices 1-24
SKY_BASE = 1
SKY_N = 24
sky_cols = [
    ( 20,  10,  50),   # top - deep purple/indigo
    ( 28,  14,  62),
    ( 38,  18,  70),
    ( 55,  22,  72),
    ( 70,  26,  70),
    ( 90,  30,  65),
    (115,  38,  58),
    (138,  50,  50),
    (160,  62,  42),
    (180,  78,  34),
    (198,  95,  26),
    (212, 112,  20),
    (220, 130,  18),
    (228, 148,  18),
    (232, 162,  22),
    (236, 175,  28),
    (238, 188,  38),
    (240, 198,  52),
    (242, 208,  70),
    (244, 215,  90),
    (245, 220, 108),
    (246, 225, 125),
    (248, 230, 145),
    (250, 235, 165),   # near horizon - pale yellow
]
for i, (r, g, b) in enumerate(sky_cols):
    sp(SKY_BASE + i, r, g, b)

# Sun disc: 8 shades, indices 25-32
SUN_BASE = 25
sun_cols = [
    (255, 255, 220),   # white-hot core
    (255, 250, 180),
    (255, 240, 130),
    (255, 220,  90),
    (255, 200,  50),
    (245, 170,  20),
    (230, 140,  10),
    (200, 100,   5),   # outer ring
]
for i, (r, g, b) in enumerate(sun_cols):
    sp(SUN_BASE + i, r, g, b)

# Road asphalt: 8 shades, indices 33-40
ROAD_BASE = 33
for i in range(8):
    t = i / 7.0
    sp(ROAD_BASE + i,
       int(30 + t * 55), int(28 + t * 50), int(32 + t * 58))

# Road centre stripe, indices 41-42
sp(41, 220, 200,  40)   # yellow centre stripe
sp(42, 200, 180,  30)   # dimmer yellow

# Road shoulder, indices 43-44
sp(43, 180,  70,  20)   # rust rumble near
sp(44, 150,  55,  15)   # rust rumble far

# Ground beside road, indices 45-46
sp(45,  55,  35,  15)
sp(46,  80,  55,  25)

# Palm silhouettes, indices 47-48
sp(47,  12,   8,  18)
sp(48,  22,  15,  30)

# Title chrome, indices 50-58
sp(50, 240, 235, 200)
sp(51, 190, 185, 155)
sp(52, 130, 125, 100)
sp(53,  75,  72,  58)
sp(54,  40,  38,  30)
sp(55, 100,  98,  80)
sp(56, 170, 165, 135)
sp(57, 210, 205, 170)
sp(58,  20,  18,  12)   # drop shadow

# Tagline and prompt, indices 59-62
sp(59, 220, 200,  80)
sp(60, 140, 120,  50)
sp(61, 235, 225, 200)
sp(62, 100,  95,  75)

# Horizon haze, indices 63-64
sp(63, 248, 230, 160)
sp(64, 235, 210, 130)

# ---- canvas ------------------------------------------------------------------
img = A.canvas(W, H, 0)

# SKY: banded gradient (each row is one solid colour -> LZW compresses runs)
for y in range(HORIZON):
    band_f = y / max(1, HORIZON - 1) * (SKY_N - 1)
    band_i = int(band_f)
    if band_i >= SKY_N - 1:
        band_i = SKY_N - 2
    ci = SKY_BASE + band_i
    A.rect(img, 0, y, W - 1, y, ci)

# SUN DISC: solid concentric rings (no checkerboard dither: better LZW)
sun_cx = W // 2
sun_cy = HORIZON - 22
sun_r  = 16
A.disc(img, sun_cx, sun_cy, sun_r,      SUN_BASE + 5)
A.disc(img, sun_cx, sun_cy, sun_r - 3,  SUN_BASE + 3)
A.disc(img, sun_cx, sun_cy, sun_r - 7,  SUN_BASE + 1)
A.disc(img, sun_cx, sun_cy, sun_r - 10, SUN_BASE + 0)
# Outer glow rings (full arcs, no dither)
for ring in range(4):
    for yy in range(sun_cy - sun_r - ring - 1, sun_cy + sun_r + ring + 2):
        for xx in range(sun_cx - sun_r - ring - 1, sun_cx + sun_r + ring + 2):
            dx = xx - sun_cx
            dy = yy - sun_cy
            d2 = dx*dx + dy*dy
            r2_in  = (sun_r + ring) * (sun_r + ring)
            r2_out = (sun_r + ring + 1) * (sun_r + ring + 1)
            if r2_in <= d2 < r2_out:
                A.putpx(img, xx, yy, SUN_BASE + 6 + min(1, ring))

# Horizon haze band (solid)
A.rect(img, 0, HORIZON - 3, W - 1, HORIZON - 1, 63)
A.rect(img, 0, HORIZON - 6, W - 1, HORIZON - 4, 64)

# GROUND: dark band below horizon
A.rect(img, 0, HORIZON, W - 1, H - 1, 45)
A.rect(img, 0, HORIZON, W - 1, HORIZON + 4, 46)

# ROAD: converging trapezoid (each row: solid sections -> good LZW compression)
road_cx = W // 2
road_w_far  = 8
road_w_near = 70
road_top_y = HORIZON + 2

for y in range(road_top_y, H):
    t = (y - road_top_y) / max(1, H - 1 - road_top_y)
    hw = int(road_w_far + (road_w_near - road_w_far) * t)
    shade = int(t * 7)
    road_ci = ROAD_BASE + shade
    rx1 = road_cx - hw
    rx2 = road_cx + hw
    if rx1 < 0: rx1 = 0
    if rx2 > W - 1: rx2 = W - 1
    A.rect(img, rx1, y, rx2, y, road_ci)
    rumb_w = max(2, hw // 8)
    rum_ci = 43 if t > 0.5 else 44
    A.rect(img, max(0, rx1 - rumb_w), y, rx1, y, rum_ci)
    A.rect(img, rx2, y, min(W - 1, rx2 + rumb_w), y, rum_ci)

# Road centre stripe dashes (keep solid lines for LZW)
stripe_spacing = 10
for stripe_y in range(road_top_y + 3, H - 3, stripe_spacing):
    t = (stripe_y - road_top_y) / max(1, H - 1 - road_top_y)
    hw = int(road_w_far + (road_w_near - road_w_far) * t)
    sw = max(1, hw // 6)
    stripe_len = max(2, int(4 * t))
    for dy in range(stripe_len):
        sy = stripe_y + dy
        if road_top_y <= sy < H:
            A.rect(img, road_cx - sw, sy, road_cx + sw, sy, 41)

# PALM SILHOUETTES (scaled to smaller canvas)
def draw_palm(img, px, base_y, trunk_h, frond_r):
    for ti in range(trunk_h):
        tx = px + ti // 8
        ty = base_y - ti
        if 0 <= ty < H and 0 <= tx < W:
            A.putpx(img, tx, ty, 47)
    crown_x = px + trunk_h // 8
    crown_y = base_y - trunk_h
    for ang in [-110, -80, -55, -35, -10, 10, 30, 55, 75, 100]:
        rad = math.radians(ang)
        for fi in range(frond_r):
            fx = crown_x + int(math.cos(rad) * fi)
            fy = crown_y + int(math.sin(rad) * fi)
            if 0 <= fy < H and 0 <= fx < W:
                A.putpx(img, fx, fy, 47)

draw_palm(img,  16, H - 7, 42, 20)
draw_palm(img,  35, H - 7, 32, 16)
draw_palm(img, 178, H - 7, 44, 21)
draw_palm(img, 196, H - 7, 30, 14)
draw_palm(img,  68, HORIZON + 24, 18, 11)
draw_palm(img, 152, HORIZON + 24, 19, 12)

# ---- TITLE TEXT: chrome "RACER" ----------------------------------------------
title = "RACER"
ts = 2
tw = len(title) * 8 * ts
tx = (W - tw) // 2
ty = 12
# Drop shadows
A.text(img, tx + 3, ty + 3, title, 58, scale=ts)
A.text(img, tx + 2, ty + 2, title, 58, scale=ts)
# Chrome face
A.text(img, tx,     ty,     title, 50, scale=ts)
A.text(img, tx + 1, ty + 1, title, 53, scale=ts)
A.text(img, tx,     ty,     title, 50, scale=ts)
# Chrome bands
for row_off in range(8 * ts):
    band_t = row_off / (8.0 * ts)
    ci_map = [50, 50, 51, 52, 52, 53, 54, 55, 56, 57, 57, 50]
    ci = ci_map[min(len(ci_map) - 1, int(band_t * len(ci_map)))]
    for tx_p in range(tx, tx + tw):
        if 0 <= ty + row_off < H:
            if img[ty + row_off][tx_p] == 50:
                img[ty + row_off][tx_p] = ci

# Subtitle
sub = "SPEED CHALLENGE"
sub_tw = len(sub) * 8
sub_tx = (W - sub_tw) // 2
sub_ty = ty + 8 * ts + 6
A.text(img, sub_tx + 1, sub_ty + 1, sub, 60, scale=1)
A.text(img, sub_tx,     sub_ty,     sub, 59, scale=1)

# Separator
sep_y = sub_ty + 12
A.rect(img, 20, sep_y,     W - 21, sep_y,     50)
A.rect(img, 20, sep_y + 1, W - 21, sep_y + 1, 53)

# PRESS ANY KEY
pak = "PRESS ANY KEY"
pak_tw = len(pak) * 8
pak_tx = (W - pak_tw) // 2
pak_ty = H - 12
A.text(img, pak_tx + 1, pak_ty + 1, pak, 62, scale=1)
A.text(img, pak_tx,     pak_ty,     pak, 61, scale=1)


# ---- Proper LZW GIF87a writer -----------------------------------------------
# Real LZW encoder so the library decoder handles far fewer codes.
# Horizontal bands compress very well; the decoder (which builds decodedData
# via string concatenation in PB 3.5) runs O(codes) iterations not O(pixels),
# making 320x200 feasible within the DOS heap and time budget.

def write_gif87_lzw(path, palette, pixels):
    """
    GIF87a with proper variable-width LZW.
    palette : 256 (r,g,b) tuples, 8-bit
    pixels  : list of H rows of W palette indices
    """
    h = len(pixels)
    w = len(pixels[0])

    MIN_CODE = 8
    CLEAR    = 1 << MIN_CODE             # 256
    EOI      = CLEAR + 1                 # 257

    # Encode and pack bits in a single pass so cs stays perfectly in sync
    cs  = MIN_CODE + 1                   # current code width
    mc  = (1 << cs) - 1                  # max code for current width
    nc  = EOI + 1                        # next assignable code
    table = {bytes([i]): i for i in range(CLEAR)}

    packed = bytearray()
    acc = 0
    nb  = 0

    def emit(code):
        nonlocal acc, nb
        acc |= (code << nb)
        nb  += cs
        while nb >= 8:
            packed.append(acc & 0xFF)
            acc >>= 8
            nb  -= 8

    def do_reset():
        nonlocal cs, mc, nc, table
        cs    = MIN_CODE + 1
        mc    = (1 << cs) - 1
        nc    = EOI + 1
        table = {bytes([i]): i for i in range(CLEAR)}

    # Initial CLEAR, then reset decoder state
    emit(CLEAR)
    do_reset()

    flat = [px for row in pixels for px in row]
    buf  = bytes([flat[0]])

    for px in flat[1:]:
        ext = buf + bytes([px])
        if ext in table:
            buf = ext
        else:
            emit(table[buf])
            if nc <= 4095:
                table[ext] = nc
                nc += 1
                if nc > mc and cs < 12:
                    cs += 1
                    mc  = (1 << cs) - 1
            if nc > 4095:
                # Dictionary full: emit CLEAR and reset
                emit(CLEAR)
                do_reset()
            buf = bytes([px])

    # Last buffered token
    emit(table[buf] if buf in table else buf[0])
    # Advance nc so cs is at the right width for EOI
    nc += 1
    if nc > mc and cs < 12:
        cs += 1
        mc  = (1 << cs) - 1
    emit(EOI)
    if nb:
        packed.append(acc & 0xFF)

    # ---- assemble GIF file ----
    out = bytearray(b'GIF87a')
    out += struct.pack('<HH', w, h)
    out += bytes([0xF7, 0, 0])           # global CT, 256 entries
    for r, g, b in palette[:256]:
        out += bytes([r & 0xFF, g & 0xFF, b & 0xFF])
    out += b'\x00' * max(0, 768 - 3 * min(256, len(palette)))

    out += b'\x2C'
    out += struct.pack('<HHHH', 0, 0, w, h)
    out += b'\x00'                       # no local CT, not interlaced
    out.append(MIN_CODE)

    i = 0
    while i < len(packed):
        chunk = packed[i:i + 255]
        out.append(len(chunk))
        out += chunk
        i += 255
    out += b'\x00\x3B'                   # block terminator + GIF trailer

    open(path, 'wb').write(out)


# ---- Write out ---------------------------------------------------------------
out_path = os.path.join(os.path.dirname(__file__), 'TITLE.GIF')
write_gif87_lzw(out_path, pal, img)
sz = os.path.getsize(out_path)
print('Written %s  %d bytes' % (out_path, sz))
print('OK')
