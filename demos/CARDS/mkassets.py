"""
Generate ARROW.CUR, SPARK.ANI and TITLE.BMP assets for the CARDS demo.
Run once from the demos/CARDS directory (or anywhere - output goes next to this script).
"""
import sys, struct, os

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'scripts'))
import pbassets as A

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def le16(v): return struct.pack('<H', v & 0xFFFF)
def le32(v): return struct.pack('<I', v & 0xFFFFFFFF)

# ---------------------------------------------------------------------------
# ARROW.CUR  --  32x32, 4-bit, hotspot (0,0)
# Classic top-left arrow pointer: white fill with black outline.
# Palette: index 0 = transparent (background shows through), index 1 = black,
#          index 15 = white.  4-bit, so 16 palette entries.
# The AND mask marks every pixel outside the arrow shape as transparent (1).
# ---------------------------------------------------------------------------
def make_arrow_cur(path):
    W, H = 32, 32
    hotX, hotY = 0, 0

    # 4-bit palette: 16 entries.
    # Index 0 = black, index 15 = white; others unused (set to black).
    PAL_BLACK = 0
    PAL_WHITE = 15
    palette = [(0, 0, 0)] * 16
    palette[PAL_WHITE] = (255, 255, 255)

    # Arrow pixel map (32x32): True = filled pixel, False = transparent
    # Classic top-left pointer shape.
    def arrow_pixel(col, row):
        if col < 0 or row < 0 or col >= W or row >= H:
            return False
        # The shaft of the arrow widens by one column per row from the top-left,
        # forming a filled triangle on the left side.  Rows 16+ are the tail.
        if row <= 15:
            # diagonal edge: include pixel if col <= row
            if col > row:
                return False
            return True
        else:
            # tail: two columns wide (cols 0-1) for rows 16-30; row 31 is empty
            if row >= 31:
                return False
            if col <= 1:
                return True
            # right side of lower arrow body (col == row - 14 at widths that
            # mirror a classic pointer's shoulder at row 10-15)
            # We keep only the narrow tail after the notch at row 10 edge:
            return False

    pixels = []
    mask = []
    for row in range(H):
        prow = []
        mrow = []
        for col in range(W):
            if arrow_pixel(col, row):
                prow.append(PAL_WHITE)
                mrow.append(0)        # opaque
            else:
                prow.append(PAL_BLACK)
                mrow.append(1)        # transparent
        pixels.append(prow)
        mask.append(mrow)

    # Add a 1-pixel black outline on the inner left/top edge of the arrow
    for row in range(1, H):
        for col in range(W):
            if arrow_pixel(col, row) and not arrow_pixel(col, row - 1):
                pixels[row][col] = PAL_BLACK
            if arrow_pixel(col, row) and not arrow_pixel(col - 1, row):
                pixels[row][col] = PAL_BLACK

    A.write_cur(path, (hotX, hotY), palette, pixels, mask)
    sz = os.path.getsize(path)
    print(f"  {os.path.basename(path)}  {sz} bytes  ({W}x{H} 4-bit)")

# ---------------------------------------------------------------------------
# SPARK.ANI  --  4-frame sparkle animation, 16x16, 4-bit, RIFF ACON
# Each frame is a complete embedded .CUR image (16x16, 4-bit palette,
# transparent background, rotating/growing sparkle shape).
# ---------------------------------------------------------------------------
def make_spark_ani(path):
    W, H = 16, 16
    DISPLAY_RATE = 6    # ~100ms per frame (6/60 sec)

    # 4-bit palette: 16 entries
    # index 0 = black (unused / transparent background colour)
    # index 1 = dark yellow
    # index 2 = bright yellow
    # index 3 = white
    # others = black
    PAL = [(0, 0, 0)] * 16
    PAL[1] = (180, 160, 0)
    PAL[2] = (255, 220, 0)
    PAL[3] = (255, 255, 255)

    def blank():
        return [[0] * W for _ in range(H)]

    def blank_mask(all_transparent=True):
        v = 1 if all_transparent else 0
        return [[v] * W for _ in range(H)]

    def put(px, py, img, msk, c):
        if 0 <= py < H and 0 <= px < W:
            img[py][px] = c
            msk[py][px] = 0  # opaque

    def cross(img, msk, cx, cy, arm, c):
        for d in range(-arm, arm + 1):
            put(cx + d, cy, img, msk, c)
            put(cx, cy + d, img, msk, c)

    def diag(img, msk, cx, cy, arm, c):
        for d in range(-arm, arm + 1):
            put(cx + d, cy + d, img, msk, c)
            put(cx + d, cy - d, img, msk, c)

    cx, cy = 7, 7   # centre at (7,7) in 16x16

    frames = []

    # Frame 0: small cross (arm=2), centre white
    img, msk = blank(), blank_mask()
    cross(img, msk, cx, cy, 2, 2)
    put(cx, cy, img, msk, 3)
    frames.append(((cx, cy), PAL, img, msk))

    # Frame 1: medium cross + short diagonals (arm=3 cross, arm=1 diag)
    img, msk = blank(), blank_mask()
    cross(img, msk, cx, cy, 3, 2)
    diag(img, msk, cx, cy, 1, 1)
    put(cx, cy, img, msk, 3)
    frames.append(((cx, cy), PAL, img, msk))

    # Frame 2: short cross (arm=1) + medium diagonals (arm=3)
    img, msk = blank(), blank_mask()
    cross(img, msk, cx, cy, 1, 2)
    diag(img, msk, cx, cy, 3, 2)
    put(cx, cy, img, msk, 3)
    frames.append(((cx, cy), PAL, img, msk))

    # Frame 3: long diagonals only (arm=4), shrinking back
    img, msk = blank(), blank_mask()
    diag(img, msk, cx, cy, 4, 1)
    put(cx, cy, img, msk, 3)
    frames.append(((cx, cy), PAL, img, msk))

    A.write_ani(path, frames, DISPLAY_RATE)
    sz = os.path.getsize(path)
    print(f"  {os.path.basename(path)}  {sz} bytes  ({W}x{H} 4-bit, {len(frames)} frames)")

# ---------------------------------------------------------------------------
# TITLE.BMP  320x60  8-bit
# Palette mirrors Game_SetPalette so indices work with both BMP-loaded
# DAC state and the restored game palette.  CARDS.BAS re-applies
# Game_SetPalette after DrawBmp_Show, making this doubly safe.
# ---------------------------------------------------------------------------
def make_title_bmp(path):
    W, H = 320, 60

    # Build palette matching CARDS.BAS slot layout exactly:
    # indices 32-51 hold the game colours; rest filled black.
    pal = [(0, 0, 0)] * 256
    # VGA DAC uses 6-bit (0-63); BMP palette stores 8-bit (0-255).
    # Scale: 8bit = 6bit * 4 + 3  (round-trip through /4 then *4 ≈ identity)
    def dac(v6): return min(255, v6 * 4)

    pal[32] = (dac(4),  dac(22), dac(8))    # PC_FELT
    pal[33] = (dac(6),  dac(28), dac(10))   # PC_FELTA
    pal[34] = (dac(8),  dac(34), dac(13))   # PC_FELTB
    pal[35] = (dac(62), dac(62), dac(62))   # PC_WHITE
    pal[36] = (dac(18), dac(18), dac(18))   # PC_BORDER
    pal[37] = (dac(60), dac(50), dac(10))   # PC_GLOW (gold)
    pal[38] = (dac(6),  dac(14), dac(28))   # PC_BACK1
    pal[39] = (dac(4),  dac(10), dac(20))   # PC_BACK2
    pal[40] = (dac(58), dac(58), dac(58))   # PC_TXT
    pal[41] = (dac(12), dac(40), dac(16))   # PC_TXTS

    # Additional art-specific palette slots (beyond game range)
    # Deep green for ornamental border fill
    pal[52] = (dac(2),  dac(14), dac(5))
    # Mid gold for inner ornament line
    pal[53] = (dac(45), dac(38), dac(8))
    # Dark shadow for title drop
    pal[54] = (dac(2),  dac(6),  dac(2))
    # Bright gold title highlight
    pal[55] = (dac(63), dac(56), dac(12))

    img = A.canvas(W, H, 32)    # fill with PC_FELT green

    # --- felt gradient top-to-bottom (dark -> lighter) ---
    A.hgrad(img, 0, 0, W - 1, H - 1, 32, 34)

    # --- ornamental border: outer dark line, inner gold line ---
    A.rect(img, 0, 0,   W - 1, H - 1, 52)         # outer dark green fill band
    A.rect(img, 2, 2,   W - 3, H - 3, 32)          # clear interior to felt
    A.hgrad(img, 2, 2,  W - 3, H - 3, 32, 34)      # re-apply gradient inside
    A.rect(img, 0, 0,   W - 1, 0, 37)              # top gold line
    A.rect(img, 0, H-1, W - 1, H-1, 37)            # bottom gold line
    A.rect(img, 0, 0,   0, H - 1, 37)              # left gold line
    A.rect(img, W-1, 0, W-1, H-1, 37)              # right gold line

    # inner gold rule (2px inset)
    A.rect(img, 4, 4, W - 5, 4, 53)
    A.rect(img, 4, H-5, W - 5, H-5, 53)
    A.rect(img, 4, 4, 4, H-5, 53)
    A.rect(img, W-5, 4, W-5, H-5, 53)

    # corner diamonds (3x3 bright gold)
    for cx, cy in [(4, 4), (W-5, 4), (4, H-5), (W-5, H-5)]:
        A.disc(img, cx, cy, 2, 37)

    # --- card suit decorations (♠ ♥ ♦ ♣ represented as filled shapes) ---
    # left side: heart (two discs + triangle)
    hx, hy = 18, H // 2
    A.disc(img, hx - 3, hy - 3, 3, 41)
    A.disc(img, hx + 3, hy - 3, 3, 41)
    # triangle pointing down
    for dy2 in range(8):
        hw = 7 - dy2
        A.rect(img, hx - hw, hy - 1 + dy2, hx + hw, hy - 1 + dy2, 41)

    # right side: spade (inverted heart + stem)
    sx2, sy2 = W - 19, H // 2
    A.disc(img, sx2 - 3, sy2 + 3, 3, 40)
    A.disc(img, sx2 + 3, sy2 + 3, 3, 40)
    for dy2 in range(8):
        hw = 7 - dy2
        A.rect(img, sx2 - hw, sy2 + 1 - dy2, sx2 + hw, sy2 + 1 - dy2, 40)
    # stem
    A.rect(img, sx2, sy2 + 4, sx2, sy2 + 8, 40)
    A.rect(img, sx2 - 3, sy2 + 8, sx2 + 3, sy2 + 8, 40)

    # --- title text: "MEMORY  PAIRS" ---
    title    = "MEMORY  PAIRS"
    scale    = 2
    tw       = len(title) * 8 * scale
    tx       = (W - tw) // 2
    ty       = (H - 8 * scale) // 2 - 1

    # shadow
    A.text(img, tx + 2, ty + 2, title, 54, scale=scale)
    # main: split colour - white for MEMORY, green for PAIRS
    A.text(img, tx,     ty,     "MEMORY", 40,  scale=scale)
    A.text(img, tx + 7 * 8 * scale, ty, "PAIRS",  41,  scale=scale)

    # gold underline beneath title text
    A.rect(img, tx - 4, ty + 8 * scale + 2, tx + tw + 3, ty + 8 * scale + 3, 37)

    A.write_bmp8(path, pal, img)
    sz = os.path.getsize(path)
    print(f"  {os.path.basename(path)}  {sz} bytes  ({W}x{H})")

# ---------------------------------------------------------------------------
if __name__ == '__main__':
    make_arrow_cur(os.path.join(HERE, 'ARROW.CUR'))
    make_spark_ani(os.path.join(HERE, 'SPARK.ANI'))
    make_title_bmp(os.path.join(HERE, 'TITLE.BMP'))
    print("Assets written.")
