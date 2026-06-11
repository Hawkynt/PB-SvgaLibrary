# Asset toolkit for the PB-SvgaLibrary demos: writers for every image format
# the library's loaders support, plus pixel-art helpers. Formats mirror the
# green test-suite fixtures exactly (tests/DRAW_*.BAS).
#
# All images are (palette, pixels) where palette = list of 256 (r, g, b) 8-bit
# tuples and pixels = list of rows, each a list of palette indices.
import struct, os

# ---------- pixel-art helpers -------------------------------------------------
def canvas(w, h, fill=0):
    return [[fill] * w for _ in range(h)]

def putpx(img, x, y, c):
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = c

def rect(img, x1, y1, x2, y2, c):
    for y in range(max(0, y1), min(len(img), y2 + 1)):
        for x in range(max(0, x1), min(len(img[0]), x2 + 1)):
            img[y][x] = c

def hgrad(img, x1, y1, x2, y2, c0, c1):
    # vertical gradient over palette range c0..c1
    n = max(1, y2 - y1)
    for y in range(y1, y2 + 1):
        c = c0 + (c1 - c0) * (y - y1) // n
        rect(img, x1, y, x2, y, c)

def disc(img, cx, cy, r, c):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                putpx(img, x, y, c)

def dither(img, x1, y1, x2, y2, c, step=2):
    for y in range(y1, y2 + 1):
        for x in range(x1 + (y % step), x2 + 1, step):
            putpx(img, x, y, c)

_FONT = None
def load_font8(path=r'C:\tmp\PB-SvgaLibrary\demos\MINI\FONT8.TXT'):
    global _FONT
    if _FONT is None:
        rows = open(path).read().split('\n')
        _FONT = [[int(v) for v in r.split()] for r in rows[:256] if r.strip()]
    return _FONT

def text(img, x, y, s, c, scale=1, font=None):
    font = font or load_font8()
    for ch in s:
        g = font[ord(ch) & 255]
        for gy in range(8):
            bits = g[gy]
            for gx in range(8):
                if bits & (0x80 >> gx):
                    for sy in range(scale):
                        for sx in range(scale):
                            putpx(img, x + gx * scale + sx, y + gy * scale + sy, c)
        x += 8 * scale

def grey_ramp(base, n, lo, hi):
    # palette helper: n grey steps -> list of (r,g,b)
    return [(lo + (hi - lo) * i // max(1, n - 1),) * 3 for i in range(n)]

# ---------- BMP (8-bit, uncompressed, bottom-up, rows padded to 4) -------------
def write_bmp8(path, palette, pixels):
    h = len(pixels); w = len(pixels[0])
    stride = (w + 3) & ~3
    data = bytearray()
    for row in reversed(pixels):
        data += bytes(row) + b'\0' * (stride - w)
    pal = bytearray()
    for r, g, b in palette[:256]:
        pal += bytes((b, g, r, 0))
    pal += b'\0' * (1024 - len(pal))
    off = 14 + 40 + 1024
    hdr = b'BM' + struct.pack('<IHHI', off + len(data), 0, 0, off)
    info = struct.pack('<IiiHHIIiiII', 40, w, h, 1, 8, 0, len(data), 0, 0, 256, 0)
    open(path, 'wb').write(hdr + info + pal + data)

# ---------- PCX (8-bit, RLE, palette appended with 0x0C marker) ----------------
def write_pcx8(path, palette, pixels):
    h = len(pixels); w = len(pixels[0])
    bpl = w + (w & 1)               # even bytes-per-line
    hdr = bytearray(128)
    hdr[0] = 10; hdr[1] = 5; hdr[2] = 1; hdr[3] = 8
    struct.pack_into('<HHHH', hdr, 4, 0, 0, w - 1, h - 1)
    struct.pack_into('<HH', hdr, 12, 320, 200)
    hdr[65] = 1                     # one plane
    struct.pack_into('<H', hdr, 66, bpl)
    out = bytearray(hdr)
    for row in pixels:
        line = bytes(row) + b'\0' * (bpl - w)
        i = 0
        while i < len(line):
            v = line[i]; run = 1
            while i + run < len(line) and line[i + run] == v and run < 63:
                run += 1
            if run > 1 or v >= 0xC0:
                out.append(0xC0 | run)
            out.append(v)
            i += run
    out.append(0x0C)
    for r, g, b in palette[:256]:
        out += bytes((r, g, b))
    out += b'\0' * (769 - 1 - 3 * min(256, len(palette)))
    open(path, 'wb').write(out)

# ---------- GIF87a (8-bit, LZW: 9-bit literals with periodic clears) -----------
def write_gif87(path, palette, pixels):
    h = len(pixels); w = len(pixels[0])
    out = bytearray(b'GIF87a')
    out += struct.pack('<HH', w, h) + bytes((0xF7, 0, 0))
    for r, g, b in palette[:256]:
        out += bytes((r, g, b))
    out += b'\0' * (768 - 3 * min(256, len(palette)))
    out += b'\x2C' + struct.pack('<HHHH', 0, 0, w, h) + b'\x00'
    out.append(8)                   # LZW minimum code size
    CLEAR, EOI = 256, 257
    codes = []
    n = 0
    codes.append(CLEAR)
    for row in pixels:
        for px in row:
            if n >= 250:            # keep the decoder at 9-bit codes
                codes.append(CLEAR)
                n = 0
            codes.append(px)
            n += 1
    codes.append(EOI)
    bits = bytearray(); acc = 0; nb = 0
    for c in codes:
        acc |= c << nb
        nb += 9
        while nb >= 8:
            bits.append(acc & 0xFF)
            acc >>= 8
            nb -= 8
    if nb:
        bits.append(acc & 0xFF)
    i = 0
    while i < len(bits):
        chunk = bits[i:i + 255]
        out.append(len(chunk)); out += chunk
        i += 255
    out += b'\x00\x3B'
    open(path, 'wb').write(out)

# ---------- TIFF (8-bit grayscale-index, uncompressed, single strip, LE) -------
def write_tif8(path, pixels):
    h = len(pixels); w = len(pixels[0])
    data = bytearray()
    for row in pixels:
        data += bytes(row)
    entries = [
        (256, 3, 1, w), (257, 3, 1, h), (258, 3, 1, 8), (259, 3, 1, 1),
        (262, 3, 1, 1), (273, 4, 1, 0), (277, 3, 1, 1), (278, 3, 1, h),
        (279, 4, 1, len(data)),
    ]
    ifd_off = 8
    data_off = ifd_off + 2 + 12 * len(entries) + 4
    out = bytearray(b'II*\0') + struct.pack('<I', ifd_off)
    out += struct.pack('<H', len(entries))
    for tag, typ, cnt, val in entries:
        if tag == 273:
            val = data_off
        out += struct.pack('<HHII', tag, typ, cnt, val)
    out += struct.pack('<I', 0)
    out += data
    open(path, 'wb').write(out)

# ---------- ICO (8-bit, doubled-height info header, AND mask) ------------------
def write_ico8(path, images):
    # images: list of (palette, pixels, transparent_mask) where mask rows of
    # 0/1 (1 = transparent); pixels max 256x256
    n = len(images)
    out = bytearray(struct.pack('<HHH', 0, 1, n))
    bodies = []
    off = 6 + 16 * n
    for palette, pixels, mask in images:
        h = len(pixels); w = len(pixels[0])
        xor_stride = (w + 3) & ~3
        and_stride = ((w + 31) // 32) * 4
        body = struct.pack('<IiiHHIIiiII', 40, w, h * 2, 1, 8, 0, 0, 0, 0, 256, 0)
        pal = bytearray()
        for r, g, b in palette[:256]:
            pal += bytes((b, g, r, 0))
        pal += b'\0' * (1024 - len(pal))
        body += pal
        xor = bytearray()
        for row in reversed(pixels):
            xor += bytes(row) + b'\0' * (xor_stride - w)
        body += xor
        andm = bytearray()
        msk = mask or [[0] * w for _ in range(h)]
        for row in reversed(msk):
            line = bytearray(and_stride)
            for x, bit in enumerate(row):
                if bit:
                    line[x // 8] |= 0x80 >> (x % 8)
            andm += line
        body += andm
        out += struct.pack('<BBBBHHII', w % 256, h % 256, 0, 0, 1, 8, len(body), off)
        bodies.append(body)
        off += len(body)
    for b in bodies:
        out += b
    open(path, 'wb').write(out)
