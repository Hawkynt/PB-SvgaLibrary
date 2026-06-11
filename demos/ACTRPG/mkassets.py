# Generate TITLE.BMP for the ACTRPG demo.
# Zelda-esque parchment splash: dithered vignette backdrop, sword-and-shield
# emblem, big runic-looking title text, "PRESS ANY KEY" footer.
#
# BMP loader (DrawBmp_Show) loads the full 256-entry palette from the file and
# writes it directly to VGA registers, dividing each 8-bit channel by 4 to
# produce 6-bit VGA values.  So to get VGA value V store V*4 in the BMP palette.
# The game calls SetupPalette() again after the splash so the gameplay palette
# is always restored.

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'scripts'))
import pbassets as A

OUT = os.path.join(os.path.dirname(__file__), 'TITLE.BMP')

W, H = 320, 200

# ---- palette (stored as 8-bit; loader divides by 4 -> 6-bit VGA) -----------
# Index 0  : black outline
# Index 1  : deep shadow
# Index 2-9: parchment gradient (warm cream to tan)
# Index 10-15: aged parchment edge (brownish)
# Index 16-23: gold/brass range for title glow
# Index 24-31: blade silver range
# Index 32-39: ornament forest green
# Index 40-47: sky/vignette navy-to-black
# Index 48 : blood red (shield boss)
# Index 49 : bright gold highlight
# Index 50 : white
# Index 51 : mid-shadow
# Index 52 : rust/border brown
# Index 53 : dark forest green
# Index 54 : light parchment
# Index 55 : warm white (text)
# Remaining: padding black

def vga(r6,g6,b6):
    """Convert 6-bit VGA channel to 8-bit BMP storage value."""
    return (r6*4, g6*4, b6*4)

pal = [(0,0,0)] * 256

# 0: true black
pal[0] = vga(0,0,0)
# 1: near-black shadow
pal[1] = vga(3,2,1)
# 2-9: parchment cream gradient (light to mid)
parch_steps = [
    (56,50,34), (58,52,36), (60,54,38), (62,56,40),
    (62,58,42), (62,56,36), (60,52,32), (56,46,28),
]
for i,rgb in enumerate(parch_steps):
    pal[2+i] = vga(*rgb)
# 10-15: aged edge tones (warm brown)
edge_steps = [
    (44,34,18),(40,30,14),(36,26,10),(32,22,8),(28,18,5),(24,14,3)
]
for i,rgb in enumerate(edge_steps):
    pal[10+i] = vga(*rgb)
# 16-23: gold gradient for title glow
gold_steps = [
    (20,12,0),(28,18,0),(36,24,2),(44,32,4),
    (52,40,8),(58,48,12),(62,54,16),(63,60,24)
]
for i,rgb in enumerate(gold_steps):
    pal[16+i] = vga(*rgb)
# 24-31: blade silver
silver_steps = [
    (20,20,22),(28,28,30),(36,36,38),(44,44,46),
    (50,50,52),(56,56,58),(60,60,62),(63,63,63)
]
for i,rgb in enumerate(silver_steps):
    pal[24+i] = vga(*rgb)
# 32-39: forest green for ornament
green_steps = [
    (2,8,2),(4,14,4),(6,20,6),(8,26,8),
    (10,30,10),(12,34,12),(14,38,14),(16,42,16)
]
for i,rgb in enumerate(green_steps):
    pal[32+i] = vga(*rgb)
# 40-47: vignette navy-to-black
navy_steps = [
    (16,12,20),(14,10,18),(12,8,16),(10,6,14),
    (8,4,12),(6,2,10),(4,1,7),(2,0,4)
]
for i,rgb in enumerate(navy_steps):
    pal[40+i] = vga(*rgb)
# 48: blood red
pal[48] = vga(50,4,4)
# 49: bright gold highlight
pal[49] = vga(63,62,20)
# 50: white
pal[50] = vga(63,63,63)
# 51: mid shadow grey
pal[51] = vga(20,18,16)
# 52: rust/dark border brown
pal[52] = vga(30,16,6)
# 53: deep forest green
pal[53] = vga(4,22,4)
# 54: light parchment
pal[54] = vga(63,60,46)
# 55: warm text white
pal[55] = vga(62,60,50)

# ---- canvas ------------------------------------------------------------------
img = A.canvas(W, H, 4)  # base: mid parchment

# Parchment gradient top-to-bottom (warm centre, darker edges)
for y in range(H):
    center_dist = abs(y - H//2) * 2 / H   # 0=centre, 1=edge
    if center_dist < 0.3:
        row_c = 4   # light cream
    elif center_dist < 0.5:
        row_c = 5
    elif center_dist < 0.7:
        row_c = 6
    elif center_dist < 0.85:
        row_c = 7
    else:
        row_c = 8
    A.rect(img, 0, y, W-1, y, row_c)

# Vignette: dithered dark overlay on edges
for y in range(H):
    vy = abs(y - H//2) / (H//2)
    for x in range(W):
        vx = abs(x - W//2) / (W//2)
        v = max(vx, vy)
        if v > 0.85:
            depth = int((v - 0.85) / 0.15 * 7)
            vig_c = 40 + min(depth, 7)
            if (x + y) % 2 == 0:
                A.putpx(img, x, y, vig_c)
        elif v > 0.70:
            if (x + y) % 4 == 0:
                A.putpx(img, x, y, 40)

# Ornamental border double-line
A.rect(img, 4, 4, W-5, H-5, 52)
A.rect(img, 5, 5, W-6, H-6, 52)
A.rect(img, 7, 7, W-8, H-8, 10)
A.rect(img, 8, 8, W-9, H-9, 10)
# Corner ornament (small diamond)
for corner in [(10,10),(W-11,10),(10,H-11),(W-11,H-11)]:
    cx, cy = corner
    A.putpx(img, cx, cy, 49)
    A.putpx(img, cx-1, cy, 49); A.putpx(img, cx+1, cy, 49)
    A.putpx(img, cx, cy-1, 49); A.putpx(img, cx+1, cy+1, 49)

# ---- Shield emblem (centre, upper half) ------------------------------------
SX, SY = W//2, 70   # shield centre-top reference

# Shield body (pentagon shape)
for dy in range(40):
    width = 28 - dy * 28 // 40
    x1 = SX - width
    x2 = SX + width
    shade = 25 + dy // 5
    if shade > 31: shade = 31
    A.rect(img, x1, SY + dy, x2, SY + dy, shade)
# Shield outline
for dy in range(40):
    width = 28 - dy * 28 // 40
    A.putpx(img, SX - width, SY + dy, 0)
    A.putpx(img, SX + width, SY + dy, 0)
A.rect(img, SX-28, SY, SX+28, SY, 0)
A.putpx(img, SX, SY+40, 0)

# Shield boss (centre circle, red)
A.disc(img, SX, SY+16, 7, 48)
A.disc(img, SX, SY+16, 6, 48)
A.putpx(img, SX-2, SY+14, 49); A.putpx(img, SX-2, SY+13, 49)
A.disc(img, SX, SY+16, 1, 0)

# Shield cross pattern
A.rect(img, SX-1, SY+4, SX+1, SY+36, 50)
A.rect(img, SX-18, SY+14, SX+18, SY+17, 50)
A.rect(img, SX-1, SY+4, SX+1, SY+36, 51)
A.rect(img, SX-18, SY+14, SX+18, SY+17, 51)
# Re-draw with silver
A.rect(img, SX-1, SY+4, SX+1, SY+34, 29)
A.rect(img, SX-17, SY+15, SX+17, SY+16, 29)

# ---- Sword (overlapping shield, tilted right) ------------------------------
# Blade (vertical bar shifted right)
BX = SX + 20
BY = SY - 15
for i in range(60):
    A.putpx(img, BX + i//10, BY + i, 28 + i//10)
    if i < 58:
        A.putpx(img, BX + 1 + i//10, BY + i, 25)
# Sword outline
for i in range(60):
    A.putpx(img, BX - 1 + i//12, BY + i, 0)
    A.putpx(img, BX + 2 + i//10, BY + i, 0)
# Crossguard
A.rect(img, BX-6, BY+42, BX+9, BY+45, 21)
A.rect(img, BX-6, BY+42, BX+9, BY+45, 0)
A.rect(img, BX-5, BY+43, BX+8, BY+44, 20)
# Pommel
A.disc(img, BX+1, BY+52, 4, 20)
A.disc(img, BX+1, BY+52, 3, 21)
A.putpx(img, BX+1, BY+50, 0)

# ---- Title text "LEGEND BLADE" (scale 3, shadow then colour) ---------------
title1 = "LEGEND"
title2 = "BLADE"
tw1 = len(title1) * 8 * 3
tw2 = len(title2) * 8 * 3
tx1 = (W - tw1) // 2
tx2 = (W - tw2) // 2
TY1 = 112
TY2 = 138

# Shadow (offset +2, dark brown)
A.text(img, tx1+2, TY1+2, title1, 1, scale=3)
A.text(img, tx2+2, TY2+2, title2, 1, scale=3)
# Gold outline (offset +1)
A.text(img, tx1+1, TY1+1, title1, 16, scale=3)
A.text(img, tx2+1, TY2+1, title2, 16, scale=3)
# Main title: bright gold
A.text(img, tx1, TY1, title1, 23, scale=3)
A.text(img, tx2, TY2, title2, 23, scale=3)

# Decorative divider lines under/above title
A.rect(img, 20, TY1-4, W-21, TY1-3, 17)
A.rect(img, 20, TY2+26, W-21, TY2+27, 17)
A.putpx(img, W//2, TY1-4, 49); A.putpx(img, W//2, TY2+26, 49)

# ---- "PRESS ANY KEY" footer (scale 1, centred) ----------------------------
foot = "PRESS ANY KEY"
ftw = len(foot) * 8
ftx = (W - ftw) // 2
A.text(img, ftx+1, 183+1, foot, 10, scale=1)
A.text(img, ftx, 183, foot, 55, scale=1)

# ---- write file --------------------------------------------------------------
A.write_bmp8(OUT, pal, img)
sz = os.path.getsize(OUT)
print('Wrote', OUT, '-', sz, 'bytes', W, 'x', H)
