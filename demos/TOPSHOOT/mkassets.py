"""
Generate BMP image assets for the TOPSHOOT demo.
Run from the demos/TOPSHOOT directory (or anywhere - output goes next to this script).
Produces:
  TITLE.BMP   - 320x160 title splash screen
  GAMEOVER.BMP - 200x60 game-over plate
"""
import sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'scripts'))
import pbassets as A

# ---------------------------------------------------------------------------
# Shared palette for both assets.
# We dedicate a compact region so indices 0..31 cover all art colours.
# The BMP loader will replace the full VGA DAC; TOPSHOOT.BAS re-applies
# its game palette with SetPalette after each DrawBmp_Show call.
# ---------------------------------------------------------------------------
def make_palette():
    pal = [(0, 0, 0)] * 256

    # 0  black
    pal[0]  = (0, 0, 0)
    # dark floor gradient 1..6 (used for arena floor perspective)
    pal[1]  = (8,  10, 6)
    pal[2]  = (12, 14, 9)
    pal[3]  = (16, 18, 12)
    pal[4]  = (20, 22, 15)
    pal[5]  = (24, 26, 18)
    pal[6]  = (28, 30, 22)
    # blood-red accent 7..10
    pal[7]  = (80,  0,   0)
    pal[8]  = (120, 0,   0)
    pal[9]  = (160, 8,   8)
    pal[10] = (200, 20,  20)
    # title orange-red 11..14
    pal[11] = (180, 40,  0)
    pal[12] = (210, 60,  0)
    pal[13] = (230, 80,  10)
    pal[14] = (255, 100, 20)
    # shadow/outline 15..16
    pal[15] = (20,  4,  4)
    pal[16] = (4,   0,  0)
    # bright whites / press-any-key 17..18
    pal[17] = (220, 220, 220)
    pal[18] = (255, 255, 255)
    # vignette dark edge 19..22
    pal[19] = (2,  2,  2)
    pal[20] = (5,  5,  5)
    pal[21] = (10, 10, 10)
    pal[22] = (15, 15, 15)
    # game-over crimson/gold 23..27
    pal[23] = (30,  0,   0)
    pal[24] = (80,  0,   0)
    pal[25] = (140, 20,  0)
    pal[26] = (190, 130, 0)
    pal[27] = (220, 180, 10)
    # pale text on game-over 28
    pal[28] = (200, 180, 160)

    return pal

# ---------------------------------------------------------------------------
# TITLE.BMP  320x160  8-bit
# ---------------------------------------------------------------------------
def make_title(path):
    W, H = 320, 160
    img  = A.canvas(W, H, 0)
    pal  = make_palette()

    # --- floor perspective: horizontal strips darkening toward top ---
    # Top rows very dark, bottom rows lighter (far → near illusion)
    floor_map = [
        (0,   15,  1),
        (15,  30,  1),
        (30,  50,  2),
        (50,  75,  3),
        (75,  100, 4),
        (100, 125, 5),
        (125, 160, 6),
    ]
    for y0, y1, c in floor_map:
        A.rect(img, 0, y0, W - 1, y1 - 1, c)

    # Perspective grid lines (darker accent on floor)
    for yi in range(20, 160, 18):
        A.rect(img, 0, yi, W - 1, yi, 0)

    # Vanishing-point vertical lines converging to (160, 0)
    vp_x = 160
    vp_y = 0
    for bx in range(0, W + 1, 32):
        # line from (bx, H-1) to (vp_x, vp_y)
        dx = vp_x - bx
        dy = vp_y - (H - 1)
        steps = H
        for s in range(0, steps, 2):
            t = s / float(steps - 1)
            px = int(bx + dx * t)
            py = (H - 1) + int(dy * t)
            if 0 <= px < W and 0 <= py < H:
                A.putpx(img, px, py, 0)

    # --- vignette dither around edges ---
    # corners / outer ring very dark
    for thick, c in [(8, 19), (5, 20), (3, 21), (1, 22)]:
        # top band
        A.dither(img, 0, 0, W - 1, thick - 1, c, 2)
        # bottom band
        A.dither(img, 0, H - thick, W - 1, H - 1, c, 2)
        # left band
        A.dither(img, 0, 0, thick - 1, H - 1, c, 2)
        # right band
        A.dither(img, W - thick, 0, W - 1, H - 1, c, 2)

    # --- blood-red accent bars ---
    # top bar
    A.rect(img, 0, 0, W - 1, 3, 7)
    A.rect(img, 0, 1, W - 1, 2, 8)
    # bottom bar
    A.rect(img, 0, H - 4, W - 1, H - 1, 7)
    A.rect(img, 0, H - 3, W - 1, H - 2, 8)
    # side accents
    A.rect(img, 0,   0, 3,   H - 1, 7)
    A.rect(img, 1,   0, 2,   H - 1, 8)
    A.rect(img, W - 4, 0, W - 1, H - 1, 7)
    A.rect(img, W - 3, 0, W - 2, H - 1, 8)

    # --- big game title "TOP SHOOT" ---
    # drop shadow (dark, shifted right+down by 3)
    A.text(img,  3 + 3, 52 + 3, "TOP SHOOT", 15, scale=3)
    # main text fire gradient using two passes
    A.text(img,  3,     52,     "TOP SHOOT", 11, scale=3)   # base
    A.text(img,  3,     52,     "TOP",       13, scale=3)   # brighter T
    A.text(img,  3 + 3 * 8 * 3, 52,  "SHOOT", 14, scale=3) # bright S

    # decorative horizontal rule under title
    A.rect(img, 10, 52 + 3 * 8 + 6, W - 11, 52 + 3 * 8 + 7, 9)
    A.rect(img, 10, 52 + 3 * 8 + 8, W - 11, 52 + 3 * 8 + 8, 7)

    # --- "PRESS ANY KEY" ---
    pak_x = (W - 13 * 8) // 2
    pak_y = H - 22
    A.text(img, pak_x + 1, pak_y + 1, "PRESS ANY KEY", 15, scale=1)
    A.text(img, pak_x,     pak_y,     "PRESS ANY KEY", 17, scale=1)

    # --- small blood splatters (decorative circles) ---
    for (sx, sy, sr, sc) in [(50, 40, 5, 8), (260, 35, 4, 7),
                              (90, 130, 3, 9), (230, 125, 4, 8)]:
        A.disc(img, sx, sy, sr, sc)
        A.disc(img, sx + 2, sy - 2, sr - 2, 9)

    A.write_bmp8(path, pal, img)
    sz = os.path.getsize(path)
    print(f"  {os.path.basename(path)}  {sz} bytes  ({W}x{H})")

# ---------------------------------------------------------------------------
# GAMEOVER.BMP  200x60  8-bit
# ---------------------------------------------------------------------------
def make_gameover(path):
    W, H = 200, 60
    img  = A.canvas(W, H, 0)
    pal  = make_palette()

    # dark crimson background with gradient
    A.hgrad(img, 0, 0, W - 1, H - 1, 23, 24)

    # outer border double-line
    A.rect(img, 0, 0, W - 1, H - 1, 25)
    A.rect(img, 2, 2, W - 3, H - 3, 0)
    A.rect(img, 3, 3, W - 4, H - 4, 26)

    # gold accent rule 4px from inner border
    A.rect(img, 6, 6, W - 7, 7, 27)
    A.rect(img, 6, H - 8, W - 7, H - 7, 27)

    # main "GAME OVER" text: shadow then bright
    go_x = (W - 9 * 8 * 2) // 2
    go_y = (H - 2 * 8) // 2 - 2
    A.text(img, go_x + 2, go_y + 2, "GAME OVER", 15, scale=2)
    A.text(img, go_x,     go_y,     "GAME OVER", 10, scale=2)

    A.write_bmp8(path, pal, img)
    sz = os.path.getsize(path)
    print(f"  {os.path.basename(path)}  {sz} bytes  ({W}x{H})")

# ---------------------------------------------------------------------------
if __name__ == '__main__':
    make_title(os.path.join(HERE, 'TITLE.BMP'))
    make_gameover(os.path.join(HERE, 'GAMEOVER.BMP'))
    print("Assets written.")
