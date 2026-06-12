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

def write_gif_pil(path, palette, pixels):
    """Save an indexed-colour GIF via PIL (real LZW).

    PIL is called with optimize=False so it does not reorder the palette.
    After saving, the file is reloaded to verify that no index remapping
    occurred.  If PIL did remap indices, the function falls back to
    write_gif87 (uncompressed-style, index-exact).

    palette  -- list of (r, g, b) tuples, max 256 entries
    pixels   -- list of rows, each a list of palette index integers
    """
    try:
        from PIL import Image
    except ImportError:
        write_gif87(path, palette, pixels)
        return

    h = len(pixels); w = len(pixels[0])
    # Build a flat palette padded to 768 bytes (256 * 3)
    flat = bytearray()
    for r, g, b in palette[:256]:
        flat += bytes((r, g, b))
    flat += b'\x00' * (768 - len(flat))

    # Create a P-mode image and assign the pixel data row by row
    img = Image.new('P', (w, h))
    img.putpalette(bytes(flat))
    flat_pixels = []
    for row in pixels:
        flat_pixels.extend(row)
    img.putdata(flat_pixels)

    img.save(path, format='GIF', optimize=False)

    # Verify index preservation: reload and spot-check a handful of pixels
    try:
        chk = Image.open(path)
        chk_data = list(chk.getdata())
        ok = True
        for y, row in enumerate(pixels):
            for x, idx in enumerate(row):
                if chk_data[y * w + x] != idx:
                    ok = False
                    break
            if not ok:
                break
        if not ok:
            write_gif87(path, palette, pixels)
    except Exception:
        write_gif87(path, palette, pixels)

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

# ---------- CUR (Windows cursor, type 2, hotspot in directory entry) -----------
def write_cur(path, hotspot, palette, pixels, mask):
    """Write a Windows .CUR file.

    hotspot  -- (x, y) hotspot coordinates stored in the directory entry
    palette  -- list of (r, g, b) tuples; len <= 16 -> 4-bit, else 8-bit
    pixels   -- list of rows (top-down), each a list of palette indices
    mask     -- list of rows (top-down), each a list of bits: 0=opaque, 1=transparent
    """
    h = len(pixels)
    w = len(pixels[0])
    hot_x, hot_y = hotspot

    ncolors = len(palette)
    if ncolors <= 2:
        bpp = 1
    elif ncolors <= 16:
        bpp = 4
    else:
        bpp = 8

    # Palette padded to 2^bpp entries
    pal_entries = 1 << bpp
    pal_bytes = bytearray()
    for i in range(pal_entries):
        if i < len(palette):
            r, g, b = palette[i]
        else:
            r, g, b = 0, 0, 0
        pal_bytes += bytes((b, g, r, 0))   # BGRA

    # XOR bitmap rows (bottom-up, DWORD-padded per row)
    xor_stride = ((w * bpp + 31) // 32) * 4
    xor_bytes = bytearray()
    for row in reversed(pixels):
        line = bytearray(xor_stride)
        if bpp == 1:
            for x, idx in enumerate(row):
                if idx:
                    line[x // 8] |= 0x80 >> (x % 8)
        elif bpp == 4:
            for x, idx in enumerate(row):
                if x % 2 == 0:
                    line[x // 2] = (idx & 0xF) << 4
                else:
                    line[x // 2] |= idx & 0xF
        else:
            for x, idx in enumerate(row):
                line[x] = idx & 0xFF
        xor_bytes += line

    # AND mask rows (bottom-up, 1 bit per pixel, DWORD-padded)
    and_stride = ((w + 31) // 32) * 4
    and_bytes = bytearray()
    msk = mask or [[0] * w for _ in range(h)]
    for row in reversed(msk):
        line = bytearray(and_stride)
        for x, bit in enumerate(row):
            if bit:
                line[x // 8] |= 0x80 >> (x % 8)
        and_bytes += line

    bih = struct.pack('<IiiHHIIiiII',
        40,        # biSize
        w,         # biWidth
        h * 2,     # biHeight doubled (XOR + AND stacked)
        1,         # biPlanes
        bpp,       # biBitCount
        0, 0, 0, 0, pal_entries, 0)

    dib = bih + bytes(pal_bytes) + bytes(xor_bytes) + bytes(and_bytes)
    image_offset = 6 + 16   # header(6) + one directory entry(16)

    cur_hdr = struct.pack('<HHH', 0, 2, 1)
    color_count = min(ncolors, 255)
    entry = struct.pack('<BBBBHHII',
        w % 256, h % 256, color_count, 0,
        hot_x, hot_y,       # Planes=hotX, BitCount=hotY for CUR
        len(dib), image_offset)

    open(path, 'wb').write(cur_hdr + entry + dib)


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


# ---------- ANI (Windows Animated Cursor, RIFF ACON) ---------------------------
def write_ani(path, frames, rate_jiffies=6):
    """Write a spec-correct Windows .ANI file.

    frames        -- list of (hotspot, palette, pixels, mask) tuples;
                     each element is passed directly to write_cur to produce
                     the embedded CUR bytes stored as an 'icon' chunk.
    rate_jiffies  -- default display rate in 1/60 s units (written to 'anih'
                     and a 'rate' chunk); can be a list of per-frame values.

    RIFF ACON layout:
      RIFF('ACON')
        anih  (36 bytes)
        rate  (nFrames * 4 bytes)
        LIST('fram')
          icon  (full CUR bytes for frame 0)
          icon  (full CUR bytes for frame 1)
          ...
    """
    nframes = len(frames)

    # Build the embedded CUR bytes for each frame.
    icon_chunks = []
    for hotspot, palette, pixels, mask in frames:
        h = len(pixels)
        w = len(pixels[0])
        hot_x, hot_y = hotspot
        ncolors = len(palette)
        if ncolors <= 2:
            bpp = 1
        elif ncolors <= 16:
            bpp = 4
        else:
            bpp = 8
        pal_entries = 1 << bpp
        pal_bytes = bytearray()
        for i in range(pal_entries):
            if i < len(palette):
                r, g, b = palette[i]
            else:
                r, g, b = 0, 0, 0
            pal_bytes += bytes((b, g, r, 0))
        xor_stride = ((w * bpp + 31) // 32) * 4
        xor_bytes = bytearray()
        for row in reversed(pixels):
            line = bytearray(xor_stride)
            if bpp == 1:
                for x, idx in enumerate(row):
                    if idx:
                        line[x // 8] |= 0x80 >> (x % 8)
            elif bpp == 4:
                for x, idx in enumerate(row):
                    if x % 2 == 0:
                        line[x // 2] = (idx & 0xF) << 4
                    else:
                        line[x // 2] |= idx & 0xF
            else:
                for x, idx in enumerate(row):
                    line[x] = idx & 0xFF
            xor_bytes += line
        and_stride = ((w + 31) // 32) * 4
        and_bytes = bytearray()
        msk = mask or [[0] * w for _ in range(h)]
        for row in reversed(msk):
            line = bytearray(and_stride)
            for x, bit in enumerate(row):
                if bit:
                    line[x // 8] |= 0x80 >> (x % 8)
            and_bytes += line
        bih = struct.pack('<IiiHHIIiiII',
            40, w, h * 2, 1, bpp, 0, 0, 0, 0, pal_entries, 0)
        dib = bih + bytes(pal_bytes) + bytes(xor_bytes) + bytes(and_bytes)
        # Full CUR file bytes (header + 1 directory entry + dib)
        image_offset = 6 + 16
        color_count = min(ncolors, 255)
        cur_hdr = struct.pack('<HHH', 0, 2, 1)
        entry = struct.pack('<BBBBHHII',
            w % 256, h % 256, color_count, 0,
            hot_x, hot_y, len(dib), image_offset)
        icon_payload = cur_hdr + entry + dib
        icon_chunks.append(bytes(icon_payload))

    def riff_chunk(tag, data):
        """Build a RIFF chunk: tag(4) + size(4,LE) + data [+ pad if odd]."""
        assert len(tag) == 4
        chunk = tag.encode('ascii') if isinstance(tag, str) else tag
        chunk += struct.pack('<I', len(data))
        chunk += data
        if len(data) & 1:
            chunk += b'\x00'
        return chunk

    # anih payload: 36 bytes
    if isinstance(rate_jiffies, (list, tuple)):
        default_rate = rate_jiffies[0] if rate_jiffies else 6
    else:
        default_rate = rate_jiffies
    anih_payload = struct.pack('<IIIIIIIII',
        36,           # cbSize
        nframes,      # nFrames
        nframes,      # nSteps
        len(pixels),  # iWidth  (use last frame's dims; all identical for simple ANI)
        len(pixels) // len(pixels[0]) * len(pixels[0]),  # placeholder -- recalc below
        bpp,          # iBitCount
        1,            # nPlanes
        default_rate, # iDispRate
        0,            # bfAttributes
    )
    # Recalculate using first frame's dimensions
    h0 = len(frames[0][2])
    w0 = len(frames[0][2][0])
    anih_payload = struct.pack('<IIIIIIIII',
        36, nframes, nframes, w0, h0,
        (4 if len(frames[0][1]) <= 16 else 8),
        1, default_rate, 0)

    anih_chunk = riff_chunk(b'anih', anih_payload)

    # rate chunk: nFrames DWORDs
    if isinstance(rate_jiffies, (list, tuple)):
        rates = list(rate_jiffies) + [default_rate] * (nframes - len(rate_jiffies))
    else:
        rates = [rate_jiffies] * nframes
    rate_payload = b''.join(struct.pack('<I', r) for r in rates[:nframes])
    rate_chunk = riff_chunk(b'rate', rate_payload)

    # LIST 'fram' chunk: each icon chunk inside
    list_inner = b'fram'
    for ic in icon_chunks:
        list_inner += riff_chunk(b'icon', ic)
    list_chunk = riff_chunk(b'LIST', list_inner)

    riff_body = b'ACON' + anih_chunk + rate_chunk + list_chunk
    riff = b'RIFF' + struct.pack('<I', len(riff_body)) + riff_body
    open(path, 'wb').write(riff)
