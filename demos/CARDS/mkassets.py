"""
Generate ARROW.CUR and SPARK.ANI binary assets for the CARDS demo.
Run once from the demos/CARDS directory (or anywhere - output goes next to this script).
"""
import struct, os

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def le16(v): return struct.pack('<H', v & 0xFFFF)
def le32(v): return struct.pack('<I', v & 0xFFFFFFFF)

# ---------------------------------------------------------------------------
# ARROW.CUR  --  16x16, 1-bit, hotspot (0,0)
# Layout mirrors the fixture in tests/DRAW_CUR.BAS:
#   CUR header (6) + entry (16) + BITMAPINFOHEADER (40)
#   + palette (2 x 4 = 8) + XOR rows (16 x 4 = 64) + AND rows (16 x 4 = 64)
# ---------------------------------------------------------------------------
def make_arrow_cur(path):
    W, H = 16, 16
    hotX, hotY = 0, 0

    # --- XOR bitmap: arrow shape (1=white/visible, 0=black/fill) ---
    # We draw a classic top-left arrow.  1bpp, MSB first, DWORD-padded (4 bytes/row).
    # Rows stored bottom-up in file.
    # Arrow rows (screen top-down):
    arrow_rows = [
        0b1000000000000000,  # row  0  *
        0b1100000000000000,  # row  1  **
        0b1110000000000000,  # row  2  ***
        0b1111000000000000,  # row  3  ****
        0b1111100000000000,  # row  4  *****
        0b1111110000000000,  # row  5  ******
        0b1111111000000000,  # row  6  *******
        0b1111111100000000,  # row  7  ********
        0b1111111110000000,  # row  8  *********
        0b1111100000000000,  # row  9  *****
        0b1101100000000000,  # row 10  ** **
        0b1001110000000000,  # row 11  *  ***
        0b0000110000000000,  # row 12     **
        0b0000110000000000,  # row 13     **
        0b0000011000000000,  # row 14      **
        0b0000000000000000,  # row 15
    ]
    # AND mask: 0=opaque where XOR has pixel, 1=transparent elsewhere
    # Invert XOR to get mask (transparent = no pixel)
    and_rows = [r ^ 0xFFFF for r in arrow_rows]

    def row_to_bytes_1bpp(val_16):
        # pack 16 bits MSB-first into 4 bytes (DWORD-padded)
        hi = (val_16 >> 8) & 0xFF
        lo = val_16 & 0xFF
        return bytes([hi, lo, 0, 0])

    xor_data = b''.join(row_to_bytes_1bpp(r) for r in reversed(arrow_rows))
    and_data = b''.join(row_to_bytes_1bpp(r) for r in reversed(and_rows))

    bytes_per_row = 4
    bih_height = H * 2   # doubled for AND+XOR

    palette  = b'\x00\x00\x00\x00' + b'\xff\xff\xff\x00'   # black, white
    dib_size = 40 + len(palette) + len(xor_data) + len(and_data)

    image_offset = 6 + 16   # right after header + one entry

    cur_hdr  = le16(0) + le16(2) + le16(1)           # reserved=0, kind=2, count=1
    entry    = (bytes([W, H, 2, 0])                   # wide, height, colorCount, reserved
                + le16(hotX) + le16(hotY)             # stored in Planes / BitCount
                + le32(dib_size)
                + le32(image_offset))
    bih      = (le32(40)           # biSize
                + le32(W)          # biWidth
                + le32(bih_height) # biHeight  (doubled)
                + le16(1)          # biPlanes
                + le16(1)          # biBitCount
                + le32(0)          # biCompression
                + le32(0)          # biSizeImage
                + le32(0) + le32(0) + le32(0) + le32(0))

    data = cur_hdr + entry + bih + palette + xor_data + and_data
    with open(path, 'wb') as f:
        f.write(data)
    print(f"  {os.path.basename(path)}  {len(data)} bytes")

# ---------------------------------------------------------------------------
# SPARK.ANI  --  4-frame sparkle, 8x8, RIFF ACON
# DrawAni_ShowFrame ignores actual pixel data and draws coloured rects,
# so we only need valid RIFF/ACON/anih chunks so LoadAnimation succeeds.
# ---------------------------------------------------------------------------
def make_spark_ani(path):
    FRAME_COUNT = 4
    W, H = 8, 8
    DISPLAY_RATE = 6    # ~100ms per frame (6/60 sec)

    # anih chunk: 36 bytes of ANIHeaderType
    anih_payload = (le32(36)           # Size
                    + le32(FRAME_COUNT)# FrameCount
                    + le32(FRAME_COUNT)# StepCount
                    + le32(W)          # Wide
                    + le32(H)          # Height
                    + le32(1)          # BitCount
                    + le32(1)          # PlaneCount
                    + le32(DISPLAY_RATE)
                    + le32(0))         # Flags
    anih_chunk = b'anih' + le32(36) + anih_payload

    # rate chunk: 4 WORDs (but stored as LONGs per spec - 4 longs)
    rate_payload = b''.join(le32(DISPLAY_RATE) for _ in range(FRAME_COUNT))
    rate_chunk   = b'rate' + le32(len(rate_payload)) + rate_payload

    # LIST fram chunk with minimal placeholder icon data
    # ParseFrameList reads the LIST type tag ("fram") then iterates using
    # the frame count; it stores approximate offsets but ShowFrame only
    # draws a coloured rect -- so we just need the chunk to be parseable.
    # Each frame nominally has some bytes; we stuff 40-byte placeholders.
    frame_blobs = b'\x00' * 40 * FRAME_COUNT
    list_payload = b'fram' + frame_blobs
    list_chunk   = b'LIST' + le32(len(list_payload)) + list_payload

    # Assemble RIFF body
    riff_body = b'ACON' + anih_chunk + rate_chunk + list_chunk
    riff = b'RIFF' + le32(len(riff_body)) + riff_body

    with open(path, 'wb') as f:
        f.write(riff)
    print(f"  {os.path.basename(path)}  {len(riff)} bytes")

# ---------------------------------------------------------------------------
if __name__ == '__main__':
    make_arrow_cur(os.path.join(HERE, 'ARROW.CUR'))
    make_spark_ani(os.path.join(HERE, 'SPARK.ANI'))
    print("Assets written.")
