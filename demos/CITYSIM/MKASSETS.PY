"""
Generate CITYHUD.TIF (96x20 HUD emblem strip) and TITLE.BMP (320x60 title
plate) for the CITYSIM demo.  The TIFF decoder writes raw byte values as
palette indices, so every pixel value here corresponds to the CITYSIM palette
indices programmed via Svga_SetPalette in CITYSIM.BAS.
"""
import sys
sys.path.insert(0, r'C:\tmp\PB-SvgaLibrary\scripts')
import pbassets as A

OUT = r'C:\tmp\PB-SvgaLibrary\demos\CITYSIM'

# --- CITYSIM palette (8-bit scaled from 6-bit VGA components * 4) -----------
# These are the indices directly programmed by CITYSIM.BAS SetPalette calls.
def pal():
    p = [(0, 0, 0)] * 256
    p[32]  = ( 20, 88, 20)   # grass
    p[33]  = ( 32,112, 32)   # grass speckle
    p[34]  = ( 72, 72, 72)   # road
    p[35]  = (168,168,168)   # lane dash
    p[36]  = ( 32,152, 32)   # res stage 1
    p[37]  = ( 16,192, 16)   # res stage 2
    p[38]  = (  8,232,  8)   # res stage 3
    p[39]  = ( 56,120, 56)   # res no-road
    p[40]  = ( 32, 32,168)   # com stage 1
    p[41]  = ( 16, 16,208)   # com stage 2
    p[42]  = (  8,  8,248)   # com stage 3
    p[43]  = ( 56, 56,120)   # com no-road
    p[44]  = ( 32, 32, 32)   # HUD bg
    p[45]  = (248,248,248)   # HUD text
    p[46]  = (248,248,  0)   # cursor
    p[47]  = (160, 88, 16)   # mild congestion
    p[48]  = (192, 32, 16)   # heavy congestion
    p[49]  = (112, 88, 32)   # brownish zone
    p[50]  = (248, 40, 40)   # car red
    p[51]  = (248,248, 40)   # car yellow
    p[52]  = ( 40, 40,248)   # car blue
    p[53]  = (248, 40,248)   # car magenta
    return p

PAL = pal()

# ============================================================
# CITYHUD.TIF  96 x 20  — drawn via DrawTif_Show on the HUD bar
# Pixels are palette indices fed directly to the screen renderer.
# Background = 44 (HUD bg dark), text/art use 45 (white-ish) and 46 (gold).
# ============================================================
HW, HH = 96, 12
BG  = 44   # HUD bg (fits in 14-pixel HUD bar at y=0..13)
FG  = 45   # text / highlight
GLD = 46   # gold accent

hud = A.canvas(HW, HH, BG)

# --- border top and bottom ---
A.rect(hud,  0,  0, HW-1,  0, GLD)
A.rect(hud,  0, HH-1, HW-1, HH-1, GLD)
A.rect(hud,  0,  0,  0, HH-1, GLD)
A.rect(hud, HW-1, 0, HW-1, HH-1, GLD)

# --- tiny skyline silhouette (left 40 px) ---
# buildings as columns of varying heights, bottom at y=9
skyline = [
    # (x, top_y)  columns 3px wide
    ( 2,  3),
    ( 5,  2),
    ( 8,  4),
    (11,  2),
    (14,  3),
    (17,  1),
    (20,  4),
    (23,  2),
    (26,  3),
    (29,  4),
    (32,  2),
    (35,  3),
    (38,  2),
]
for bx, ty in skyline:
    A.rect(hud, bx, ty, bx+2, 9, FG)
    # single window dot per building
    if 9 - ty > 3:
        A.putpx(hud, bx+1, ty+2, BG)

# ground line
A.rect(hud, 1, 10, 40, 10, 33)

# --- "CITYSIM" text right half (x=43 onwards), scale=1 ---
A.text(hud, 43, 2, 'CITYSIM', GLD, scale=1)

A.write_tif8(OUT + r'\CITYHUD.TIF', hud)
print('CITYHUD.TIF written')

# ============================================================
# TITLE.BMP  320 x 60  — palette must match CITYSIM palette
# Shown once at startup then game palette re-applied (no issue since BMP
# loader reads palette into hardware; when demo then calls Svga_SetPalette
# the palette is restored to the game layout).
# We build the art using only indices already in the CITYSIM palette so even
# the loader-applied palette looks correct.
# ============================================================
TW, TH = 320, 60

def make_title():
    img = A.canvas(TW, TH, 0)   # index 0 = black default

    # sky gradient (from index 40..42 = blue range, com stage colours)
    A.hgrad(img, 0, 0, TW-1, TH-1, 40, 44)

    # horizon glow (road grey band)
    A.rect(img, 0, 42, TW-1, 44, 34)
    A.rect(img, 0, 43, TW-1, 43, 35)

    # skyline silhouette across full width (index 44 = dark)
    sil = [
        (  0,32,12),(  12,28, 8),(  20,34, 8),(  28,26,10),
        ( 38,30, 8),( 46,22,12),( 58,30, 8),( 66,28, 8),
        ( 74,34, 6),( 80,24,10),( 90,28, 8),(100,30, 8),
        (108,26,10),(118,32, 8),(126,22,14),(140,28, 8),
        (148,30, 8),(156,26,10),(166,34, 6),(172,24,12),
        (184,28, 8),(192,30, 8),(200,26,10),(210,32, 8),
        (218,22,14),(232,28, 8),(240,30, 8),(248,26,10),
        (258,34, 6),(264,24,12),(276,28, 8),(284,30, 8),
        (292,26,10),(302,22,14),(308,28,12),
    ]
    for sx, sy, sw in sil:
        A.rect(img, sx, sy, sx+sw-1, 42, 44)
        # windows: small yellow dots inside buildings
        for wy in range(sy+2, 42, 4):
            for wx in range(sx+1, sx+sw-1, 4):
                A.putpx(img, wx, wy, 46)

    # road surface (34 grey) bottom strip
    A.rect(img, 0, 45, TW-1, TH-1, 34)
    # lane dashes
    for lx in range(20, TW, 30):
        A.rect(img, lx, TH//2+8, lx+14, TH//2+8, 35)

    # main title text centred, scale=2
    title = 'CITYSIM'
    tw = len(title) * 8 * 2
    tx = (TW - tw) // 2
    # shadow
    A.text(img, tx+2, 14, title, 44, scale=2)
    # gold
    A.text(img, tx,   12, title, 46, scale=2)

    # sub-title line
    sub = 'CITY SIMULATION'
    stw = len(sub) * 8
    stx = (TW - stw) // 2
    A.text(img, stx+1, 34, sub, 44, scale=1)
    A.text(img, stx,   33, sub, 45, scale=1)

    return img

title_img = make_title()
A.write_bmp8(OUT + r'\TITLE.BMP', PAL, title_img)
print('TITLE.BMP written')

import os
hsz = os.path.getsize(OUT + r'\CITYHUD.TIF')
tsz = os.path.getsize(OUT + r'\TITLE.BMP')
print('CITYHUD.TIF %d bytes' % hsz)
print('TITLE.BMP   %d bytes' % tsz)
