' =============================================================================
' DRAW_ICO.BAS - tests for DRAW_ICO.SUB (Windows ICO loader)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "FILEUTIL.SUB"
DECLARE FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
$INCLUDE "DRAW_ICO.SUB"

' --- Collaborator stubs -------------------------------------------------------
SUB Svga_InitDispatchTable
END SUB
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB
SUB Svga_PutPixel(x AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_PutPixel(x, y, c)
END SUB
SUB Svga_HLine(x1 AS WORD, x2 AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_HLine(x1, x2, y, c)
END SUB
SUB Virtual_ToPhysical(x AS WORD, y AS WORD, px AS WORD, py AS WORD)
    px = x : py = y
END SUB
FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
    Virtual_IsVisible = 1
END FUNCTION

' --- LE16/LE32 helpers --------------------------------------------------------
FUNCTION LE16(BYVAL v AS WORD) AS STRING
    LE16 = CHR$(v AND 255) + CHR$((v \ 256) AND 255)
END FUNCTION
FUNCTION LE32(BYVAL v AS LONG) AS STRING
    LE32 = CHR$(v AND 255) + CHR$((v \ 256) AND 255) + CHR$((v \ 65536) AND 255) + CHR$((v \ 16777216) AND 255)
END FUNCTION

' --- GetP: read pixel from VGA framebuffer ------------------------------------
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r) : GetP = r
END FUNCTION

' =============================================================================
' MakeIco8: build a 4x4 single-icon 8-bit ICO file as T.ICO
'
' Layout:
'   ICONDIR  : reserved=0, type=1, count=1
'   ICONDIRENTRY[0]: wide=4, height=4, colorcount=0, reserved=0,
'                    planes=1, bitcount=8, bytesInRes, imageoffset=22
'   BITMAPINFOHEADER: size=40, width=4, height=8 (2x because AND mask),
'                     planes=1, bitcount=8, compression=0, ...
'   Palette (256 entries BGRA):
'       entry 5: B=50 G=100 R=200 A=0  (so Draw sets DAC R=200>>2=50 G=25 B=12)
'       entry 7: B=255 G=0   R=0   A=0
'       all others: 0
'   XOR bitmap (bottom-up rows):
'       file-row 0 (= image row 3): 7,5,7,5
'       file-row 1 (= image row 2): 5,7,5,7
'       file-row 2 (= image row 1): 7,7,7,7
'       file-row 3 (= image row 0): 5,5,5,5
'   AND mask (bottom-up, 1bpp, 4-byte padded rows):
'       all zero = fully opaque
'
' Expected pixels after DrawIco_Show at (10,20):
'   (10,20)=5  (13,20)=5  (screen-row 20 = image row 0 = file-row 3)
'   (10,21)=7  (13,21)=7
'   (10,22)=5  (13,22)=7
'   (10,23)=7  (13,23)=5
' =============================================================================
SUB MakeIco8
    DIM hdr AS STRING, entry AS STRING, bih AS STRING
    DIM pal AS STRING, xorBmp AS STRING, andMask AS STRING
    DIM imageOffset AS LONG, bytesInRes AS LONG

    ' ICONDIR: 6 bytes
    hdr = LE16(0) + LE16(1) + LE16(1)

    ' imageOffset (0-based): 6 (ICONDIR) + 16 (1 entry) = 22
    imageOffset = 22

    ' palette: 256 * 4 = 1024 bytes, all zero
    pal = STRING$(1024, CHR$(0))
    ' entry 5 (BGRA): B=50 G=100 R=200 A=0
    MID$(pal, 5 * 4 + 1, 1) = CHR$(50)
    MID$(pal, 5 * 4 + 2, 1) = CHR$(100)
    MID$(pal, 5 * 4 + 3, 1) = CHR$(200)
    ' entry 7 (BGRA): B=255 G=0 R=0 A=0
    MID$(pal, 7 * 4 + 1, 1) = CHR$(255)

    ' XOR bitmap: 4 rows x 4 bytes (scanlineWidth = 4, bottom-up)
    ' file-row 0 = image-row 3
    xorBmp = CHR$(7) + CHR$(5) + CHR$(7) + CHR$(5)
    ' file-row 1 = image-row 2
    xorBmp = xorBmp + CHR$(5) + CHR$(7) + CHR$(5) + CHR$(7)
    ' file-row 2 = image-row 1
    xorBmp = xorBmp + CHR$(7) + CHR$(7) + CHR$(7) + CHR$(7)
    ' file-row 3 = image-row 0
    xorBmp = xorBmp + CHR$(5) + CHR$(5) + CHR$(5) + CHR$(5)

    ' AND mask: 4 rows x 4 bytes (maskScanlineWidth=4, bottom-up), all opaque=0
    andMask = STRING$(16, CHR$(0))

    bytesInRes = 40 + 1024 + 16 + 16

    ' ICONDIRENTRY: wide=4, height=4, colorcount=0, reserved=0,
    '              planes=1, bitcount=8, bytesInRes, imageOffset
    entry = CHR$(4) + CHR$(4) + CHR$(0) + CHR$(0)
    entry = entry + LE16(1) + LE16(8) + LE32(bytesInRes) + LE32(imageOffset)

    ' BITMAPINFOHEADER: 40 bytes
    ' height = 8 (2 * icon height, includes AND mask)
    bih = LE32(40) + LE32(4) + LE32(8) + LE16(1) + LE16(8)
    bih = bih + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    OPEN "T.ICO" FOR BINARY AS #1
    PUT$ #1, hdr + entry + bih + pal + xorBmp + andMask
    CLOSE #1
END SUB

' =============================================================================
' MakeIco8Two: two-icon ICO, first is 2x2 8-bit, second is 4x4 8-bit
' Used to test icon index selection in GetCount and GetInfo
' =============================================================================
SUB MakeIco8Two
    DIM hdr AS STRING
    DIM entry0 AS STRING, entry1 AS STRING
    DIM bih0 AS STRING, pal0 AS STRING, xor0 AS STRING, and0 AS STRING
    DIM bih1 AS STRING, pal1 AS STRING, xor1 AS STRING, and1 AS STRING
    DIM off0 AS LONG, off1 AS LONG
    DIM bytes0 AS LONG, bytes1 AS LONG

    hdr = LE16(0) + LE16(1) + LE16(2)

    ' Icon 0: 2x2 8-bit
    ' scanlineWidth = ((2*8+31)\32)*4 = (47\32)*4 = 1*4 = 4 bytes
    ' maskScanWidth  = ((2+31)\32)*4   = 4 bytes
    bytes0 = 40 + 256 * 4 + 2 * 4 + 2 * 4  ' bih + pal + xor + and
    off0 = 6 + 16 * 2  ' ICONDIR + 2 entries

    ' Icon 1: 4x4 8-bit
    bytes1 = 40 + 256 * 4 + 4 * 4 + 4 * 4
    off1 = off0 + bytes0

    entry0 = CHR$(2) + CHR$(2) + CHR$(0) + CHR$(0)
    entry0 = entry0 + LE16(1) + LE16(8) + LE32(bytes0) + LE32(off0)

    entry1 = CHR$(4) + CHR$(4) + CHR$(0) + CHR$(0)
    entry1 = entry1 + LE16(1) + LE16(8) + LE32(bytes1) + LE32(off1)

    pal0 = STRING$(1024, CHR$(0))
    pal1 = STRING$(1024, CHR$(0))

    ' Icon 0 pixels: 2x2, entry 3 = opaque solid
    xor0 = CHR$(3) + CHR$(3) + CHR$(0) + CHR$(0) + _
           CHR$(3) + CHR$(3) + CHR$(0) + CHR$(0)
    and0 = STRING$(8, CHR$(0))

    ' Icon 1 pixels: 4x4 entry 9
    xor1 = STRING$(16, CHR$(9))
    and1 = STRING$(16, CHR$(0))

    bih0 = LE32(40) + LE32(2) + LE32(4) + LE16(1) + LE16(8) + _
           LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)
    bih1 = LE32(40) + LE32(4) + LE32(8) + LE16(1) + LE16(8) + _
           LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    OPEN "T2.ICO" FOR BINARY AS #1
    PUT$ #1, hdr + entry0 + entry1 + bih0 + pal0 + xor0 + and0 + bih1 + pal1 + xor1 + and1
    CLOSE #1
END SUB

' =============================================================================
' MakeIcoBad: ICO with wrong type field (type=2 = cursor, not icon)
' =============================================================================
SUB MakeIcoBad
    DIM hdr AS STRING
    hdr = LE16(0) + LE16(2) + LE16(1)
    OPEN "TBAD.ICO" FOR BINARY AS #1
    PUT$ #1, hdr + STRING$(16, CHR$(0))
    CLOSE #1
END SUB

' =============================================================================
' MakeIco4: 4x4 4-bit ICO for bit-depth coverage
' palette: entry 0 = black, entry 1 = B=0 G=128 R=255 A=0
' pixels (image row 0 = file row 3): nibbles 1,0,1,0 per row
' all AND mask = 0 (opaque)
' =============================================================================
SUB MakeIco4
    DIM hdr AS STRING, entry AS STRING, bih AS STRING
    DIM pal AS STRING, xorBmp AS STRING, andMask AS STRING
    DIM imageOffset AS LONG, bytesInRes AS LONG
    DIM i AS INTEGER

    hdr = LE16(0) + LE16(1) + LE16(1)
    imageOffset = 22

    ' 4-bit palette: 16 entries * 4 bytes = 64 bytes
    pal = STRING$(64, CHR$(0))
    ' entry 1: B=0 G=128 R=255
    MID$(pal, 1 * 4 + 1, 1) = CHR$(0)    ' B
    MID$(pal, 1 * 4 + 2, 1) = CHR$(128)  ' G
    MID$(pal, 1 * 4 + 3, 1) = CHR$(255)  ' R

    ' 4-bit scanlineWidth = ((4*4+31)\32)*4 = ((16+31)\32)*4 = (47\32)*4 = 4 bytes
    ' Each row is 2 nibble-packed bytes + 2 padding bytes
    ' image rows bottom-up: row 0..3 all = 1,0,1,0 -> packed: &H10, &H10
    ' packed nibble: upper=left pixel
    ' pixel 0=1 pixel 1=0 -> byte = &H10; pixel 2=1 pixel 3=0 -> byte = &H10
    xorBmp = ""
    FOR i = 0 TO 3
        xorBmp = xorBmp + CHR$(&H10) + CHR$(&H10) + CHR$(0) + CHR$(0)
    NEXT i

    ' AND mask: 4 rows x 4 bytes, all 0 (opaque)
    andMask = STRING$(16, CHR$(0))

    bytesInRes = 40 + 64 + 16 + 16

    entry = CHR$(4) + CHR$(4) + CHR$(0) + CHR$(0)
    entry = entry + LE16(1) + LE16(4) + LE32(bytesInRes) + LE32(imageOffset)

    ' biHeight = 8 (includes AND mask)
    bih = LE32(40) + LE32(4) + LE32(8) + LE16(1) + LE16(4)
    bih = bih + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    OPEN "T4.ICO" FOR BINARY AS #1
    PUT$ #1, hdr + entry + bih + pal + xorBmp + andMask
    CLOSE #1
END SUB

' =============================================================================
' Test lifecycle
' =============================================================================
SUB Test_Setup
    ' Mode 13h: 320x200x256
    !MOV AX, &H0013
    !INT &H10
    ' Mode 13h gives XRes=320 YRes=200
    SVGAScreenContext.XRes = 320
    SVGAScreenContext.YRes = 200
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB

' =============================================================================
' Test_GetCount_SingleIcon: count = 1 for a single-icon file
' =============================================================================
SUB Test_GetCount_SingleIcon
    CALL Test_Case("GetCount returns 1 for a valid single-icon ICO file")
    DIM cnt AS WORD
    CALL MakeIco8
    cnt = DrawIco_GetCount("T.ICO")
    CALL Assert_IsEqual(cnt, 1, "count = 1")
END SUB

' =============================================================================
' Test_GetCount_TwoIcons: count = 2 for a two-icon file
' =============================================================================
SUB Test_GetCount_TwoIcons
    CALL Test_Case("GetCount returns 2 for a two-icon ICO file")
    DIM cnt AS WORD
    CALL MakeIco8Two
    cnt = DrawIco_GetCount("T2.ICO")
    CALL Assert_IsEqual(cnt, 2, "count = 2")
END SUB

' =============================================================================
' Test_GetCount_BadType: count = 0 when type field is wrong
' =============================================================================
SUB Test_GetCount_BadType
    CALL Test_Case("GetCount returns 0 when ICO type field is not 1")
    DIM cnt AS WORD
    CALL MakeIcoBad
    cnt = DrawIco_GetCount("TBAD.ICO")
    CALL Assert_IsEqual(cnt, 0, "count = 0 for bad type")
END SUB

' =============================================================================
' Test_GetCount_MissingFile: count = 0 when file does not exist
' =============================================================================
SUB Test_GetCount_MissingFile
    CALL Test_Case("GetCount returns 0 when file does not exist")
    DIM cnt AS WORD
    cnt = DrawIco_GetCount("NOFILE.ICO")
    CALL Assert_IsEqual(cnt, 0, "count = 0 for missing file")
END SUB

' =============================================================================
' Test_GetSize_8bit: GetSize reads 4x4 from first icon entry
' =============================================================================
SUB Test_GetSize_8bit
    CALL Test_Case("GetSize reads width=4 and height=4 from 8-bit ICO")
    DIM w AS WORD, h AS WORD
    CALL MakeIco8
    CALL DrawIco_GetSize("T.ICO", w, h)
    CALL Assert_IsEqual(w, 4, "width = 4")
    CALL Assert_IsEqual(h, 4, "height = 4")
END SUB

' =============================================================================
' Test_GetInfo_Index0: GetInfo on index 0 of two-icon file -> 2x2, 8-bit
' =============================================================================
SUB Test_GetInfo_Index0
    CALL Test_Case("GetInfo index 0 of two-icon ICO returns 2x2 at 8-bit depth")
    DIM w AS WORD, h AS WORD, d AS WORD
    CALL MakeIco8Two
    CALL DrawIco_GetInfo("T2.ICO", 0, w, h, d)
    CALL Assert_IsEqual(w, 2, "width = 2")
    CALL Assert_IsEqual(h, 2, "height = 2")
    CALL Assert_IsEqual(d, 8, "depth = 8")
END SUB

' =============================================================================
' Test_GetInfo_Index1: GetInfo on index 1 of two-icon file -> 4x4, 8-bit
' =============================================================================
SUB Test_GetInfo_Index1
    CALL Test_Case("GetInfo index 1 of two-icon ICO returns 4x4 at 8-bit depth")
    DIM w AS WORD, h AS WORD, d AS WORD
    CALL MakeIco8Two
    CALL DrawIco_GetInfo("T2.ICO", 1, w, h, d)
    CALL Assert_IsEqual(w, 4, "width = 4")
    CALL Assert_IsEqual(h, 4, "height = 4")
    CALL Assert_IsEqual(d, 8, "depth = 8")
END SUB

' =============================================================================
' Test_GetInfo_OutOfRange: out-of-range index -> zero-initialized output
' =============================================================================
SUB Test_GetInfo_OutOfRange
    CALL Test_Case("GetInfo with out-of-range index leaves dimensions zeroed")
    DIM w AS WORD, h AS WORD, d AS WORD
    CALL MakeIco8
    CALL DrawIco_GetInfo("T.ICO", 5, w, h, d)
    CALL Assert_IsEqual(w, 0, "width = 0 for out-of-range")
    CALL Assert_IsEqual(h, 0, "height = 0 for out-of-range")
END SUB

' =============================================================================
' Test_Show_Pixels_8bit: DrawIco_Show plots correct 8-bit indices on screen
' Image row 0 (top of display at y=20): file-row 3 = pixels 5,5,5,5
' Image row 1 (y=21): file-row 2 = pixels 7,7,7,7
' Image row 2 (y=22): file-row 1 = pixels 5,7,5,7
' Image row 3 (y=23): file-row 0 = pixels 7,5,7,5
' =============================================================================
SUB Test_Show_Pixels_8bit
    CALL Test_Case("Show plots correct 8-bit pixel indices onto VGA (bottom-up decode)")
    CALL MakeIco8
    CALL DrawIco_Show("T.ICO", 10, 20, 0)
    CALL Assert_IsEqual(GetP(10, 20), 5, "row0 col0 = 5")
    CALL Assert_IsEqual(GetP(11, 20), 5, "row0 col1 = 5")
    CALL Assert_IsEqual(GetP(12, 20), 5, "row0 col2 = 5")
    CALL Assert_IsEqual(GetP(13, 20), 5, "row0 col3 = 5")
    CALL Assert_IsEqual(GetP(10, 21), 7, "row1 col0 = 7")
    CALL Assert_IsEqual(GetP(13, 21), 7, "row1 col3 = 7")
    CALL Assert_IsEqual(GetP(10, 22), 5, "row2 col0 = 5")
    CALL Assert_IsEqual(GetP(11, 22), 7, "row2 col1 = 7")
    CALL Assert_IsEqual(GetP(12, 22), 5, "row2 col2 = 5")
    CALL Assert_IsEqual(GetP(13, 22), 7, "row2 col3 = 7")
    CALL Assert_IsEqual(GetP(10, 23), 7, "row3 col0 = 7")
    CALL Assert_IsEqual(GetP(11, 23), 5, "row3 col1 = 5")
END SUB

' =============================================================================
' Test_Show_IndexOutOfRange_ClampToZero: icon index >= count -> clamped to 0
' Still draws the icon (icon 0 exists in T.ICO)
' =============================================================================
SUB Test_Show_IndexOutOfRange_ClampToZero
    CALL Test_Case("Show clamps out-of-range index to 0 and still draws")
    CALL MakeIco8
    CALL DrawIco_Show("T.ICO", 10, 20, 99)
    CALL Assert_IsEqual(GetP(10, 20), 5, "row0 col0 = 5 after index clamp")
END SUB

' =============================================================================
' Test_Show_BadType_NoDrawing: bad ICO type field -> nothing drawn
' Use coordinates far from any other test to avoid contamination.
' =============================================================================
SUB Test_Show_BadType_NoDrawing
    CALL Test_Case("Show with wrong ICO type does nothing (pixels stay 0)")
    CALL MakeIcoBad
    CALL DrawIco_Show("TBAD.ICO", 200, 100, 0)
    CALL Assert_IsEqual(GetP(200, 100), 0, "pixel untouched when type invalid")
END SUB

' =============================================================================
' Test_Show_MissingFile_NoDrawing: missing file -> nothing drawn
' Use coordinates far from any other test to avoid contamination.
' =============================================================================
SUB Test_Show_MissingFile_NoDrawing
    CALL Test_Case("Show with non-existent file does nothing (pixels stay 0)")
    CALL DrawIco_Show("NOFILE.ICO", 210, 100, 0)
    CALL Assert_IsEqual(GetP(210, 100), 0, "pixel untouched for missing file")
END SUB

' =============================================================================
' Test_Show_4bit_Pixels: DrawIco_Show plots correct 4-bit pixel indices
' All rows are nibble pairs 1,0,1,0 -> display row y has pixels 1,0,1,0
' =============================================================================
SUB Test_Show_4bit_Pixels
    CALL Test_Case("Show decodes 4-bit nibble-packed pixels correctly")
    CALL MakeIco4
    CALL DrawIco_Show("T4.ICO", 30, 40, 0)
    CALL Assert_IsEqual(GetP(30, 40), 1, "4-bit row0 col0 = 1")
    CALL Assert_IsEqual(GetP(31, 40), 0, "4-bit row0 col1 = 0")
    CALL Assert_IsEqual(GetP(32, 40), 1, "4-bit row0 col2 = 1")
    CALL Assert_IsEqual(GetP(33, 40), 0, "4-bit row0 col3 = 0")
    CALL Assert_IsEqual(GetP(30, 43), 1, "4-bit row3 col0 = 1")
    CALL Assert_IsEqual(GetP(31, 43), 0, "4-bit row3 col1 = 0")
END SUB

' =============================================================================
' Test_Extract_8bit: DrawIco_Extract returns correct pixel buffer and dims
' =============================================================================
SUB Test_Extract_8bit
    CALL Test_Case("Extract returns success=1, correct dims and pixel buffer")
    DIM buf AS STRING, w AS WORD, h AS WORD, rc AS BYTE
    CALL MakeIco8
    rc = DrawIco_Extract("T.ICO", 0, buf, w, h)
    CALL Assert_IsEqual(rc, 1, "Extract returns 1 on success")
    CALL Assert_IsEqual(w, 4, "Extract width = 4")
    CALL Assert_IsEqual(h, 4, "Extract height = 4")
    CALL Assert_IsEqual(LEN(buf), 16, "Extract buffer length = 16")
    ' image row 0 (top) = buffer positions 1..4 (y=0 * 4 + x+1)
    ' file-row 3 = pixels 5,5,5,5
    CALL Assert_IsEqual(ASC(MID$(buf, 1, 1)), 5, "Extract buf[0,0] = 5")
    CALL Assert_IsEqual(ASC(MID$(buf, 4, 1)), 5, "Extract buf[0,3] = 5")
    ' image row 1 = buffer positions 5..8, file-row 2 = 7,7,7,7
    CALL Assert_IsEqual(ASC(MID$(buf, 5, 1)), 7, "Extract buf[1,0] = 7")
    ' image row 2 = buffer positions 9..12, file-row 1 = 5,7,5,7
    CALL Assert_IsEqual(ASC(MID$(buf, 9, 1)),  5, "Extract buf[2,0] = 5")
    CALL Assert_IsEqual(ASC(MID$(buf, 10, 1)), 7, "Extract buf[2,1] = 7")
    ' image row 3 = buffer positions 13..16, file-row 0 = 7,5,7,5
    CALL Assert_IsEqual(ASC(MID$(buf, 13, 1)), 7, "Extract buf[3,0] = 7")
    CALL Assert_IsEqual(ASC(MID$(buf, 14, 1)), 5, "Extract buf[3,1] = 5")
END SUB

' =============================================================================
' Test_Extract_MissingFile: Extract returns 0 for non-existent file
' =============================================================================
SUB Test_Extract_MissingFile
    CALL Test_Case("Extract returns 0 for a non-existent file")
    DIM buf AS STRING, w AS WORD, h AS WORD, rc AS BYTE
    rc = DrawIco_Extract("NOFILE.ICO", 0, buf, w, h)
    CALL Assert_IsEqual(rc, 0, "Extract returns 0 for missing file")
END SUB

' =============================================================================
' Test_GetPalette_8bit: GetPalette reads BGRA palette and converts to RGB
' entry 5: B=50 G=100 R=200 -> paletteV(5*3)=200 [R], (5*3+1)=100 [G], (5*3+2)=50 [B]
' =============================================================================
SUB Test_GetPalette_8bit
    CALL Test_Case("GetPalette reads BGRA palette from file and converts to RGB order")
    DIM pal(767) AS BYTE
    CALL MakeIco8
    CALL DrawIco_GetPalette("T.ICO", pal(), 8)
    CALL Assert_IsEqual(pal(5 * 3),     200, "palette[5].R = 200")
    CALL Assert_IsEqual(pal(5 * 3 + 1), 100, "palette[5].G = 100")
    CALL Assert_IsEqual(pal(5 * 3 + 2),  50, "palette[5].B = 50")
    CALL Assert_IsEqual(pal(7 * 3),       0, "palette[7].R = 0")
    CALL Assert_IsEqual(pal(7 * 3 + 2), 255, "palette[7].B = 255")
END SUB
