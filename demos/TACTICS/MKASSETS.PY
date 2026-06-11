"""
Generate UNITS.ICO (3 x 32x32 unit portraits) and BANNER.BMP (240x48 victory
banner) for the TACTICS demo, using palette indices that mirror SetPalette.
"""
import sys
sys.path.insert(0, r'C:\tmp\PB-SvgaLibrary\scripts')
import pbassets as A

OUT = r'C:\tmp\PB-SvgaLibrary\demos\TACTICS'

# --- palette mirroring SetPalette (6-bit VGA components scaled to 8-bit) ---
# Svga_SetPalette uses 6-bit values; multiply by 4 for 8-bit colour space.
def pal():
    p = [(0, 0, 0)] * 256
    # terrain
    p[16] = (16, 80, 16)
    p[17] = ( 8, 48,  8)
    p[18] = ( 8, 32,120)
    p[19] = (80, 80, 80)
    # teams
    p[20] = (16, 48,160)   # blue
    p[21] = (160, 24, 16)  # red
    # HP bars
    p[22] = (16,160, 16)   # healthy
    p[23] = (160, 16, 16)  # wounded
    # UI
    p[24] = (200,200, 16)  # range highlight
    p[25] = (252,252,252)  # white
    p[26] = ( 32, 32, 32)  # HUD bg
    p[27] = (252,252,  0)  # cursor
    # portrait-specific additional colours
    p[30] = (200,160, 80)  # skin tone
    p[31] = (120, 80, 20)  # dark outline / hair
    p[32] = (180,140, 60)  # mid skin
    p[33] = (220,200,160)  # light skin highlight
    p[34] = ( 60, 60,160)  # blue metal / knight armour
    p[35] = (100,100,200)  # blue metal highlight
    p[36] = (180, 80,  0)  # brown leather / archer hood
    p[37] = (220,120, 40)  # light brown
    p[38] = ( 80,  0,140)  # mage purple robe
    p[39] = (140, 40,220)  # mage purple highlight
    p[40] = (240,200,  0)  # gold trim / star on mage hat
    p[41] = (200,200,220)  # silver shield face
    p[42] = (160,160,180)  # silver shadow
    p[43] = (180, 40, 40)  # red cross on shield
    p[44] = ( 40, 80, 40)  # bow wood dark
    p[45] = ( 80,140, 60)  # bow wood light
    p[46] = (220,220,220)  # white eye
    p[47] = ( 20, 20, 20)  # pupil dark
    p[48] = (200,100,  0)  # staff wood amber
    p[49] = (100,200,200)  # mage staff crystal
    # banner colours
    p[50] = ( 40, 20,  0)  # dark banner bg
    p[51] = (180,140, 20)  # gold text / laurel
    p[52] = (120, 90,  0)  # gold dark
    p[53] = (240,200, 80)  # gold bright
    p[54] = ( 60, 60, 60)  # border dark
    p[55] = (200,200,200)  # border light
    return p

PAL = pal()
BG  = 0   # transparent index — leave as 0, mask will set these transparent

# ---------- helper: make a transparent mask (1 = transparent) for bg=0 -------
def make_mask(pixels):
    return [[1 if pixels[y][x] == BG else 0
             for x in range(len(pixels[0]))]
            for y in range(len(pixels))]

# ---------- ICON 0: KNIGHT ---------------------------------------------------
# 32x32, steel blue armour, helm visor, kite shield with red cross, white face

def draw_knight():
    img = A.canvas(32, 32, BG)
    # --- helm outline ---
    A.rect(img,  8,  2, 23,  4, 31)   # helm top band dark outline
    A.rect(img,  7,  3, 24, 14, 34)   # helm body blue metal
    A.rect(img,  8,  3, 23, 13, 35)   # helm body highlight
    # visor bar
    A.rect(img,  9,  9, 22, 11, 31)   # visor dark
    A.rect(img, 10,  9, 21, 10, 42)   # visor silver
    # eye slots (small dark slits)
    A.rect(img, 10,  9, 13,  9, 47)
    A.rect(img, 18,  9, 21,  9, 47)
    # helm crest / plume top
    A.rect(img, 14,  0, 17,  3, 40)   # gold crest
    # neck
    A.rect(img, 12, 14, 19, 16, 42)   # silver neck
    A.rect(img, 12, 14, 19, 16, 31)   # neck outline
    # body armour (left side, giving room for shield right)
    A.rect(img,  6, 16, 17, 29, 34)   # armour body blue
    A.rect(img,  7, 17, 16, 28, 35)   # armour body lighter
    # pauldrons
    A.rect(img,  4, 16,  7, 21, 34)   # left pauldron
    A.rect(img, 18, 16, 21, 21, 34)   # right pauldron (visible under shield)
    # kite shield (right side, overlapping body)
    A.rect(img, 18, 15, 27, 28, 41)   # shield silver face
    A.rect(img, 18, 15, 27, 28, 31)   # shield outline (draw outline after)
    A.rect(img, 19, 16, 26, 27, 41)   # shield inner
    # red cross on shield
    A.rect(img, 21, 16, 23, 27, 43)   # vertical bar
    A.rect(img, 19, 20, 26, 22, 43)   # horizontal bar
    # boots
    A.rect(img,  8, 29, 14, 31, 31)
    A.rect(img,  8, 29, 13, 30, 42)
    # dark outline around whole figure
    for x in range(32):
        for y in range(32):
            if img[y][x] != BG:
                for dx, dy in ((-1,0),(1,0),(0,-1),(0,1)):
                    nx, ny = x+dx, y+dy
                    if 0<=nx<32 and 0<=ny<32 and img[ny][nx] == BG:
                        img[ny][nx] = 31  # outline pixel
    return img

# ---------- ICON 1: ARCHER ---------------------------------------------------
# 32x32, brown hooded figure, bow on left, quiver hint

def draw_archer():
    img = A.canvas(32, 32, BG)
    # hood (dark brown)
    A.disc(img, 16, 8, 7, 36)
    A.disc(img, 16, 8, 6, 37)
    # face inside hood
    A.disc(img, 16, 9, 4, 30)
    A.rect(img, 13, 6, 19, 8, 36)  # hood shadow over top of face
    # eyes
    A.putpx(img, 14, 9, 47)
    A.putpx(img, 18, 9, 47)
    A.putpx(img, 14,10, 46)
    A.putpx(img, 18,10, 46)
    # nose hint
    A.putpx(img, 16, 11, 32)
    # body (leather jacket)
    A.rect(img, 10, 15, 21, 29, 36)
    A.rect(img, 11, 16, 20, 28, 37)
    # collar
    A.rect(img, 13, 14, 18, 16, 31)
    # arms
    A.rect(img,  6, 17, 10, 24, 36)  # left arm (bow arm)
    A.rect(img, 21, 17, 25, 22, 36)  # right arm
    # bow (vertical arc left side)
    A.rect(img,  3, 10,  5, 28, 44)  # bow stave dark
    A.rect(img,  4, 11,  4, 27, 45)  # bow highlight
    A.putpx(img,  4,  9, 31)         # bow tip top
    A.putpx(img,  4, 29, 31)         # bow tip bottom
    # bowstring
    A.rect(img,  3,  9,  3, 29, 25)  # string (white)
    # arrow nocked
    A.rect(img,  3, 18, 14, 18, 25)  # arrow shaft (horizontal)
    A.putpx(img, 14, 18, 40)         # arrowhead gold tip
    A.putpx(img, 15, 18, 40)
    # quiver strap on right
    A.rect(img, 24, 13, 26, 22, 36)
    A.rect(img, 24, 13, 26, 13, 31)
    # boots
    A.rect(img, 11, 29, 15, 31, 31)
    A.rect(img, 16, 29, 20, 31, 31)
    A.rect(img, 12, 29, 14, 30, 37)
    A.rect(img, 17, 29, 19, 30, 37)
    # outline
    for x in range(32):
        for y in range(32):
            if img[y][x] != BG:
                for dx, dy in ((-1,0),(1,0),(0,-1),(0,1)):
                    nx, ny = x+dx, y+dy
                    if 0<=nx<32 and 0<=ny<32 and img[ny][nx] == BG:
                        img[ny][nx] = 31
    return img

# ---------- ICON 2: MAGE -----------------------------------------------------
# 32x32, tall pointed hat, robes, glowing staff

def draw_mage():
    img = A.canvas(32, 32, BG)
    # hat (tall pointed purple)
    # hat brim
    A.rect(img,  8, 14, 23, 16, 38)
    A.rect(img,  8, 14, 23, 15, 39)
    # hat cone
    pts = [(11,13),(12,11),(13, 9),(14, 7),(15, 5),(15, 4),(16, 4),(16, 5),
           (17, 7),(18, 9),(19,11),(20,13)]
    for x, y in pts:
        A.putpx(img, x, y, 38)
        A.putpx(img, x+1, y, 39)
    A.rect(img, 12, 10, 19, 14, 38)
    A.rect(img, 13, 10, 18, 13, 39)
    # gold star on hat
    A.putpx(img, 15,  6, 40)
    A.putpx(img, 16,  6, 40)
    A.putpx(img, 15,  7, 40)
    A.putpx(img, 14,  8, 40)
    A.putpx(img, 17,  8, 40)
    # face
    A.disc(img, 16, 18, 5, 30)
    A.disc(img, 16, 18, 4, 33)
    # eyes (glowing slightly)
    A.putpx(img, 14, 17, 49)   # left eye cyan
    A.putpx(img, 18, 17, 49)
    A.putpx(img, 14, 18, 46)
    A.putpx(img, 18, 18, 46)
    # beard hint
    A.rect(img, 14, 21, 18, 22, 25)
    # robes
    A.rect(img,  9, 22, 22, 31, 38)
    A.rect(img, 10, 22, 21, 30, 39)
    # arms extending from robe
    A.rect(img,  6, 22, 10, 27, 38)   # left arm
    A.rect(img, 22, 22, 26, 24, 38)   # right arm (holding staff)
    # staff (right side)
    A.rect(img, 25, 10, 26, 31, 48)   # wood shaft amber
    A.putpx(img, 25,  9, 31)
    # crystal orb top of staff
    A.disc(img, 25,  8, 3, 49)   # cyan orb
    A.putpx(img, 25,  7, 25)     # white glint
    A.putpx(img, 26,  8, 25)
    # gold trim on robe hem
    A.rect(img, 10, 30, 21, 31, 40)
    # outline
    for x in range(32):
        for y in range(32):
            if img[y][x] != BG:
                for dx, dy in ((-1,0),(1,0),(0,-1),(0,1)):
                    nx, ny = x+dx, y+dy
                    if 0<=nx<32 and 0<=ny<32 and img[ny][nx] == BG:
                        img[ny][nx] = 31
    return img

# ---------- write UNITS.ICO --------------------------------------------------
k  = draw_knight()
ar = draw_archer()
mg = draw_mage()

images = [
    (PAL, k,  make_mask(k)),
    (PAL, ar, make_mask(ar)),
    (PAL, mg, make_mask(mg)),
]
A.write_ico8(OUT + r'\UNITS.ICO', images)
print('UNITS.ICO written')

# ---------- BANNER.BMP (240 x 48) victory plate ------------------------------
bw, bh = 240, 48
ban = A.canvas(bw, bh, 50)   # dark bg

# outer border frame (double line)
A.rect(ban,  0,  0, bw-1,  0, 51)
A.rect(ban,  0, bh-1, bw-1, bh-1, 51)
A.rect(ban,  0,  0,  0, bh-1, 51)
A.rect(ban, bw-1, 0, bw-1, bh-1, 51)
A.rect(ban,  2,  2, bw-3,  2, 52)
A.rect(ban,  2, bh-3, bw-3, bh-3, 52)
A.rect(ban,  2,  2,  2, bh-3, 52)
A.rect(ban, bw-3, 2, bw-3, bh-3, 52)

# laurel decoration: left sprigs
def leaf(img, cx, cy, c):
    A.disc(img, cx, cy, 3, c)

for i in range(4):
    lx = 14 + i * 8
    leaf(ban, lx,    10, 17)   # dark green (index 17 = forest green from TACTICS pal)
    leaf(ban, lx - 3, 20, 22)  # brighter green (22=healthy green)
    leaf(ban, lx,    34, 17)
    leaf(ban, lx - 3, 25, 22)

# right side mirror
for i in range(4):
    lx = bw - 14 - i * 8
    leaf(ban, lx,    10, 17)
    leaf(ban, lx + 3, 20, 22)
    leaf(ban, lx,    34, 17)
    leaf(ban, lx + 3, 25, 22)

# gold horizontal rule top and bottom (inside border)
A.rect(ban,  5,  5, bw-6,  6, 51)
A.rect(ban,  5, bh-7, bw-6, bh-6, 51)

# "VICTORY" text centred, scale=2, bright gold
txt = 'VICTORY'
tw = len(txt) * 8 * 2
tx = (bw - tw) // 2
A.text(ban, tx, 16, txt, 53, scale=2)

# shadow behind text (1px offset, darker gold)
A.text(ban, tx + 2, 18, txt, 52, scale=2)
A.text(ban, tx,     16, txt, 53, scale=2)  # redraw on top

A.write_bmp8(OUT + r'\BANNER.BMP', PAL, ban)
print('BANNER.BMP written')

import os
usz = os.path.getsize(OUT + r'\UNITS.ICO')
bsz = os.path.getsize(OUT + r'\BANNER.BMP')
print('UNITS.ICO  %d bytes' % usz)
print('BANNER.BMP %d bytes' % bsz)
