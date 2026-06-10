' =============================================================================
' DRAW_CUR.BAS - tests for DRAW_CUR.SUB (Windows CUR cursor loader)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "FILEUTIL.SUB"
DECLARE FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
$INCLUDE "DRAW_CUR.SUB"

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

' LE16 / LE32 binary helpers
FUNCTION LE16(BYVAL v AS WORD) AS STRING
    LE16 = CHR$(v AND 255) + CHR$((v \ 256) AND 255)
END FUNCTION
FUNCTION LE32(BYVAL v AS LONG) AS STRING
    LE32 = CHR$(v AND 255) + CHR$((v \ 256) AND 255) + _
           CHR$((v \ 65536) AND 255) + CHR$((v \ 16777216) AND 255)
END FUNCTION

' Helper: read one pixel from the VGA framebuffer at (x,y)
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, rv AS BYTE
    xv = x : yv = y : rv = 0
    CALL Vga_GetPixel(xv, yv, rv)
    GetP = rv
END FUNCTION

' =============================================================================
' Build a minimal 4x4, 2-colour (1-bit) .CUR fixture
'
' Layout:
'   CUR header (6): reserved=0, kind=2, count=1
'   Entry (16):     wide=4, height=4, colorcount=2, reserved=0,
'                   hotX=LE16(2), hotY=LE16(1),
'                   bytesInRes=LE32(80), imageOffset=LE32(22)
'   BITMAPINFOHEADER (40):
'       biSize=40, biWidth=4, biHeight=8 (doubled for AND mask),
'       biPlanes=1, biBitCount=1, biCompression=0, biSizeImage=0,
'       xPPM=0, yPPM=0, clrUsed=0, clrImportant=0
'   Palette (8):
'       entry 0: B=0 G=0 R=0 A=0   (black = index 0)
'       entry 1: B=255 G=255 R=255 A=0 (white = index 1 → colour 255)
'   XOR pixel data (1bpp, 4px/row, DWORD-padded = 4 bytes/row, 4 rows, 16 bytes)
'       Stored bottom-up.  Row 0 in file = screen row 3 (bottom of image).
'       We want screen pixel (col,row):
'           row 0 top:    0=black, 1=white, 2=black, 3=white  -> bits 0101 = &H50 in MSB-first
'           row 1:        1=white, 0=black, 1=white, 0=black  -> bits 1010 = &HA0
'           row 2:        0=black, 0=black, 1=white, 1=white  -> bits 0011 = &H30
'           row 3 bottom: 1=white, 1=white, 0=black, 0=black  -> bits 1100 = &HC0
'       File order (bottom-up): row3 first, row0 last.
'   AND mask (1bpp, same geometry, 4 bytes/row, 4 rows = 16 bytes, bottom-up)
'       0 = opaque, 1 = transparent
'       All pixels opaque: every byte = &H00 (except padding bits don't matter)
' =============================================================================
SUB MakeCur4x4(BYVAL fileName AS STRING)
    DIM hdr AS STRING, entry AS STRING, bih AS STRING
    DIM pal AS STRING, xorData AS STRING, andData AS STRING
    DIM imageOffset AS LONG, bytesInRes AS LONG

    ' CUR header
    hdr = LE16(0) + LE16(2) + LE16(1)      ' reserved=0, kind=2, count=1

    ' Image data starts right after header (6) + entry (16)
    imageOffset = 22

    ' DIB: 40 (BITMAPINFOHEADER) + 8 (palette 2 entries) + 16 (XOR) + 16 (AND)
    bytesInRes = 80

    ' Directory entry: wide=4, height=4, colorCount=2, reserved=0, hotX=2, hotY=1
    entry = CHR$(4) + CHR$(4) + CHR$(2) + CHR$(0) + _
            LE16(2) + LE16(1) + _
            LE32(bytesInRes) + LE32(imageOffset)

    ' BITMAPINFOHEADER: biHeight=8 (doubled: 4 XOR + 4 AND)
    bih = LE32(40) + LE32(4) + LE32(8) + LE16(1) + LE16(1) + _
          LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    ' Palette: 2 BGRA entries
    pal = CHR$(0) + CHR$(0) + CHR$(0) + CHR$(0)        ' index 0: black
    pal = pal + CHR$(255) + CHR$(255) + CHR$(255) + CHR$(0)  ' index 1: white

    ' XOR data, bottom-up: row3 first, then row2, row1, row0
    ' row3 (screen bottom): 1100.... -> &HC0, padded to 4 bytes
    ' row2:                 0011.... -> &H30
    ' row1:                 1010.... -> &HA0
    ' row0 (screen top):    0101.... -> &H50
    xorData = CHR$(&HC0) + CHR$(0) + CHR$(0) + CHR$(0)
    xorData = xorData + CHR$(&H30) + CHR$(0) + CHR$(0) + CHR$(0)
    xorData = xorData + CHR$(&HA0) + CHR$(0) + CHR$(0) + CHR$(0)
    xorData = xorData + CHR$(&H50) + CHR$(0) + CHR$(0) + CHR$(0)

    ' AND mask, bottom-up: all opaque (0 = opaque)
    andData = STRING$(16, CHR$(0))

    OPEN fileName FOR BINARY AS #1
    PUT$ #1, hdr + entry + bih + pal + xorData + andData
    CLOSE #1
END SUB

' Build a 4x4 8-bit CUR (ColorCount=0 -> colorDepth=8) with hotspot (3,2)
' XOR row data (bottom-up): pixel (col,row) = 10 + row*4 + col
SUB MakeCur4x4_8bit(BYVAL fileName AS STRING)
    DIM hdr AS STRING, entry AS STRING, bih AS STRING
    DIM pal AS STRING, xorData AS STRING, andData AS STRING
    DIM imageOffset AS LONG, bytesInRes AS LONG
    DIM r AS INTEGER, c AS INTEGER

    hdr = LE16(0) + LE16(2) + LE16(1)

    imageOffset = 22
    ' DIB: 40 + 1024 (256-color palette) + 16 (XOR, 4 bytes/row * 4 rows) + 16 (AND)
    bytesInRes = 40 + 1024 + 16 + 16

    ' colorCount=0 -> colorDepth=8 path
    entry = CHR$(4) + CHR$(4) + CHR$(0) + CHR$(0) + _
            LE16(3) + LE16(2) + _
            LE32(bytesInRes) + LE32(imageOffset)

    ' BITMAPINFOHEADER
    bih = LE32(40) + LE32(4) + LE32(8) + LE16(1) + LE16(8) + _
          LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    ' Palette: 256 BGRA entries (identity: entry i = B=i, G=i, R=i, A=0)
    pal = ""
    FOR r = 0 TO 255
        pal = pal + CHR$(r) + CHR$(r) + CHR$(r) + CHR$(0)
    NEXT r

    ' XOR data bottom-up: row3 first, row0 last
    ' pixel (col, row) = 10 + row*4 + col
    xorData = ""
    FOR r = 3 TO 0 STEP -1
        FOR c = 0 TO 3
            xorData = xorData + CHR$(10 + r * 4 + c)
        NEXT c
    NEXT r

    ' AND mask: all opaque
    andData = STRING$(16, CHR$(0))

    OPEN fileName FOR BINARY AS #2
    PUT$ #2, hdr + entry + bih + pal + xorData + andData
    CLOSE #2
END SUB

' =============================================================================
' MakeCur4x4_4bit: 4x4 4-bit CUR fixture (ColorCount=16, hotspot (1,1))
'
' Nibble-packed pixel data (bottom-up rows, each row = 2 nibbles = 1 byte + 1 byte pad to DWORD):
'   scanlineWidth = ((4*4+31)\32)*4 = 4 bytes/row
'   pixel layout (col 0..3): nibble upper=col0, lower=col1; next byte: upper=col2, lower=col3
'   file-row 0 (image row 3): all pixel=0xF -> CHR$(&HFF)+CHR$(&HF0) + 2 pad
'   file-row 1 (image row 2): pixels 0xA,0xB,0xC,0xD -> &HAB, &HCD + 2 pad
'   file-row 2 (image row 1): pixels 1,2,3,4 -> &H12, &H34 + 2 pad
'   file-row 3 (image row 0): pixels 5,6,7,8 -> &H56, &H78 + 2 pad
' =============================================================================
SUB MakeCur4x4_4bit(BYVAL fileName AS STRING)
    DIM hdr AS STRING, entry AS STRING, bih AS STRING
    DIM pal AS STRING, xorData AS STRING, andData AS STRING
    DIM imageOffset AS LONG, bytesInRes AS LONG

    hdr = LE16(0) + LE16(2) + LE16(1)
    imageOffset = 22
    ' DIB: 40 (BIH) + 64 (16-entry palette) + 16 (XOR) + 16 (AND)
    bytesInRes = 40 + 64 + 16 + 16

    ' ColorCount=16 -> 4-bit depth detection
    entry = CHR$(4) + CHR$(4) + CHR$(16) + CHR$(0) + _
            LE16(1) + LE16(1) + _
            LE32(bytesInRes) + LE32(imageOffset)

    ' BITMAPINFOHEADER: height=8 (XOR+AND doubled)
    bih = LE32(40) + LE32(4) + LE32(8) + LE16(1) + LE16(4) + _
          LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    ' 16-entry BGRA palette: entry i = B=i*4 G=i*4 R=i*4 A=0
    pal = ""
    DIM pi AS INTEGER
    FOR pi = 0 TO 15
        pal = pal + CHR$(pi * 4) + CHR$(pi * 4) + CHR$(pi * 4) + CHR$(0)
    NEXT pi

    ' XOR data bottom-up
    ' file-row 0: pixels 0xF,0xF,0xF,0xF -> packed &HFF &HFF
    xorData = CHR$(&HFF) + CHR$(&HFF) + CHR$(0) + CHR$(0)
    ' file-row 1: pixels 0xA,0xB,0xC,0xD -> &HAB &HCD
    xorData = xorData + CHR$(&HAB) + CHR$(&HCD) + CHR$(0) + CHR$(0)
    ' file-row 2: pixels 1,2,3,4 -> &H12 &H34
    xorData = xorData + CHR$(&H12) + CHR$(&H34) + CHR$(0) + CHR$(0)
    ' file-row 3 (image row 0): pixels 5,6,7,8 -> &H56 &H78
    xorData = xorData + CHR$(&H56) + CHR$(&H78) + CHR$(0) + CHR$(0)

    ' AND mask: all opaque
    andData = STRING$(16, CHR$(0))

    OPEN fileName FOR BINARY AS #3
    PUT$ #3, hdr + entry + bih + pal + xorData + andData
    CLOSE #3
END SUB

' =============================================================================
' MakeCur_TwoCursors: two-cursor CUR file
'   cursor 0: 2x2, 1-bit, hotspot (0,0), pixels all = 1 (white=255)
'   cursor 1: 4x4, 8-bit, hotspot (2,2), all pixels = index 7
' =============================================================================
SUB MakeCur_TwoCursors(BYVAL fileName AS STRING)
    DIM hdr AS STRING, e0 AS STRING, e1 AS STRING
    DIM bih0 AS STRING, bih1 AS STRING
    DIM pal0 AS STRING, pal1 AS STRING
    DIM xor0 AS STRING, xor1 AS STRING, and0 AS STRING, and1 AS STRING
    DIM off0 AS LONG, bytes0 AS LONG, off1 AS LONG, bytes1 AS LONG

    hdr = LE16(0) + LE16(2) + LE16(2)

    ' cursor 0: 2x2 1-bit
    ' scanlineWidth = ((2*1+31)\32)*4 = 4 bytes/row; maskScanWidth = 4 bytes/row
    ' palette: 2 entries * 4 = 8 bytes; XOR: 4*2=8; AND: 4*2=8
    bytes0 = 40 + 8 + 8 + 8
    off0 = 6 + 16 * 2  ' CURDIR + 2 entries

    ' cursor 1: 4x4 8-bit (ColorCount=0)
    ' scanlineWidth = ((4*8+31)\32)*4 = 4 bytes/row; 16 bytes XOR + 16 bytes AND
    bytes1 = 40 + 1024 + 16 + 16
    off1 = off0 + bytes0

    e0 = CHR$(2) + CHR$(2) + CHR$(2) + CHR$(0) + _
         LE16(0) + LE16(0) + _
         LE32(bytes0) + LE32(off0)

    e1 = CHR$(4) + CHR$(4) + CHR$(0) + CHR$(0) + _
         LE16(2) + LE16(2) + _
         LE32(bytes1) + LE32(off1)

    ' Cursor 0 BIH + data
    bih0 = LE32(40) + LE32(2) + LE32(4) + LE16(1) + LE16(1) + _
           LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)
    pal0 = CHR$(0)+CHR$(0)+CHR$(0)+CHR$(0) + CHR$(255)+CHR$(255)+CHR$(255)+CHR$(0)
    ' XOR: both rows = 1111 ... -> &HFF pad to 4 bytes (2 rows)
    xor0 = CHR$(&HFF)+CHR$(0)+CHR$(0)+CHR$(0) + CHR$(&HFF)+CHR$(0)+CHR$(0)+CHR$(0)
    and0 = STRING$(8, CHR$(0))

    ' Cursor 1 BIH + data
    bih1 = LE32(40) + LE32(4) + LE32(8) + LE16(1) + LE16(8) + _
           LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)
    pal1 = STRING$(1024, CHR$(0))
    ' all 4x4 pixels = index 7
    xor1 = STRING$(16, CHR$(7))
    and1 = STRING$(16, CHR$(0))

    OPEN fileName FOR BINARY AS #4
    PUT$ #4, hdr + e0 + e1 + bih0 + pal0 + xor0 + and0 + bih1 + pal1 + xor1 + and1
    CLOSE #4
END SUB

' =============================================================================
' MakeCur4x4_ANDMasked: 4x4 8-bit CUR with partial AND mask transparency
'
' AND mask (bottom-up):
'   file-row 0 (drawn at y+3): all transparent = &HF0
'   file-row 1 (drawn at y+2): all opaque = 0x00
'   file-row 2 (drawn at y+1): all opaque = 0x00
'   file-row 3 (drawn at y+0): px0,1 transparent, px2,3 opaque = &HC0
' XOR: all pixels = index 5; hotspot (0,0)
' =============================================================================
SUB MakeCur4x4_ANDMasked(BYVAL fileName AS STRING)
    DIM hdr AS STRING, entry AS STRING, bih AS STRING
    DIM pal AS STRING, xorData AS STRING, andData AS STRING
    DIM imageOffset AS LONG, bytesInRes AS LONG

    hdr = LE16(0) + LE16(2) + LE16(1)
    imageOffset = 22
    bytesInRes = 40 + 1024 + 16 + 16

    entry = CHR$(4) + CHR$(4) + CHR$(0) + CHR$(0) + _
            LE16(0) + LE16(0) + _
            LE32(bytesInRes) + LE32(imageOffset)

    bih = LE32(40) + LE32(4) + LE32(8) + LE16(1) + LE16(8) + _
          LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    pal = STRING$(1024, CHR$(0))
    xorData = STRING$(16, CHR$(5))

    andData = CHR$(&HF0) + CHR$(0) + CHR$(0) + CHR$(0)  ' row 0 (drawn y+3): all transp
    andData = andData + CHR$(0) + CHR$(0) + CHR$(0) + CHR$(0)  ' row 1 (y+2): all opaque
    andData = andData + CHR$(0) + CHR$(0) + CHR$(0) + CHR$(0)  ' row 2 (y+1): all opaque
    andData = andData + CHR$(&HC0) + CHR$(0) + CHR$(0) + CHR$(0)  ' row 3 (y+0): px0,1 transp

    OPEN fileName FOR BINARY AS #5
    PUT$ #5, hdr + entry + bih + pal + xorData + andData
    CLOSE #5
END SUB

' ---------------------------------------------------------------------------
' Test cases
' ---------------------------------------------------------------------------

SUB Test_GetCount_ValidCur
    CALL Test_Case("GetCount returns 1 for single-cursor CUR file")
    CALL MakeCur4x4("T.CUR")
    CALL Assert_IsEqual(DrawCur_GetCount("T.CUR"), 1, "count = 1")
END SUB

SUB Test_GetCount_MissingFile
    CALL Test_Case("GetCount returns 0 for non-existent file")
    CALL Assert_IsZero(DrawCur_GetCount("NOFILE.CUR"), "count = 0 for missing file")
END SUB

SUB Test_GetCount_WrongType
    CALL Test_Case("GetCount returns 0 for ICO file (type=1, not CUR)")
    ' Write a minimal ICO header (kind=1)
    OPEN "T.ICO" FOR BINARY AS #3
    PUT$ #3, LE16(0) + LE16(1) + LE16(1)
    CLOSE #3
    CALL Assert_IsZero(DrawCur_GetCount("T.ICO"), "count = 0 for kind=1")
END SUB

SUB Test_GetSize_ValidCur
    CALL Test_Case("GetSize returns width=4 height=4 for 4x4 cursor")
    DIM w AS WORD, h AS WORD
    CALL MakeCur4x4("T.CUR")
    CALL DrawCur_GetSize("T.CUR", w, h)
    CALL Assert_IsEqual(w, 4, "width = 4")
    CALL Assert_IsEqual(h, 4, "height = 4")
END SUB

SUB Test_GetHotspot_ValidCur
    CALL Test_Case("GetHotspot returns hotX=2 hotY=1 from 1-bit cursor")
    DIM hx AS WORD, hy AS WORD
    CALL MakeCur4x4("T.CUR")
    CALL DrawCur_GetHotspot("T.CUR", 0, hx, hy)
    CALL Assert_IsEqual(hx, 2, "hotX = 2")
    CALL Assert_IsEqual(hy, 1, "hotY = 1")
END SUB

SUB Test_GetHotspot_MissingFile
    CALL Test_Case("GetHotspot returns 0,0 for missing file")
    DIM hx AS WORD, hy AS WORD
    hx = 99 : hy = 99
    CALL DrawCur_GetHotspot("NOFILE.CUR", 0, hx, hy)
    CALL Assert_IsZero(hx, "hotX = 0 for missing file")
    CALL Assert_IsZero(hy, "hotY = 0 for missing file")
END SUB

SUB Test_GetInfo_Dimensions
    CALL Test_Case("GetInfo returns correct dimensions and hotspot")
    DIM w AS WORD, h AS WORD, cd AS WORD, hx AS WORD, hy AS WORD
    CALL MakeCur4x4("T.CUR")
    CALL DrawCur_GetInfo("T.CUR", 0, w, h, cd, hx, hy)
    CALL Assert_IsEqual(w, 4, "info width = 4")
    CALL Assert_IsEqual(h, 4, "info height = 4")
    CALL Assert_IsEqual(hx, 2, "info hotX = 2")
    CALL Assert_IsEqual(hy, 1, "info hotY = 1")
END SUB

SUB Test_GetInfo_ColorDepth_2color
    CALL Test_Case("GetInfo reports colorDepth=1 for 2-colour cursor (ColorCount=2)")
    DIM w AS WORD, h AS WORD, cd AS WORD, hx AS WORD, hy AS WORD
    CALL MakeCur4x4("T.CUR")
    CALL DrawCur_GetInfo("T.CUR", 0, w, h, cd, hx, hy)
    CALL Assert_IsEqual(cd, 1, "colorDepth = 1 for ColorCount=2")
END SUB

SUB Test_GetInfo_8bit
    CALL Test_Case("GetInfo reports colorDepth=8 for 8-bit cursor (ColorCount=0)")
    DIM w AS WORD, h AS WORD, cd AS WORD, hx AS WORD, hy AS WORD
    CALL MakeCur4x4_8bit("T8.CUR")
    CALL DrawCur_GetInfo("T8.CUR", 0, w, h, cd, hx, hy)
    CALL Assert_IsEqual(w, 4, "8bit: width = 4")
    CALL Assert_IsEqual(h, 4, "8bit: height = 4")
    CALL Assert_IsEqual(cd, 8, "8bit: colorDepth = 8")
    CALL Assert_IsEqual(hx, 3, "8bit: hotX = 3")
    CALL Assert_IsEqual(hy, 2, "8bit: hotY = 2")
END SUB

SUB Test_GetPalette_Returns1
    CALL Test_Case("GetPalette always returns 1 (grayscale identity)")
    DIM pal(767) AS BYTE
    DIM ok AS BYTE
    CALL MakeCur4x4("T.CUR")
    ok = DrawCur_GetPalette("T.CUR", pal(), 8)
    CALL Assert_IsEqual(ok, 1, "GetPalette returns 1")
    CALL Assert_IsEqual(pal(0), 0, "palette[0].R = 0")
    CALL Assert_IsEqual(pal(10 * 3), 10, "palette[10].R = 10")
    CALL Assert_IsEqual(pal(255 * 3), 255, "palette[255].R = 255")
END SUB

SUB Test_Show_1bit_OpaquePixels
    CALL Test_Case("Show renders 1-bit cursor XOR pixels at correct positions")
    ' The cursor has hotspot (2,1).  We call Show at position (10,10).
    ' Adjusted origin = (10-2, 10-1) = (8, 9).
    ' Screen row r = 9+r, screen col c = 8+c.
    ' 1-bit pixel: index 0 -> colour 0 (black), index 1 -> colour 255 (white)
    ' Row 0 (screen row 9):  0 1 0 1  -> 0, 255, 0, 255
    ' Row 1 (screen row 10): 1 0 1 0  -> 255, 0, 255, 0
    ' Row 2 (screen row 11): 0 0 1 1  -> 0, 0, 255, 255
    ' Row 3 (screen row 12): 1 1 0 0  -> 255, 255, 0, 0
    CALL MakeCur4x4("T.CUR")
    CALL DrawCur_Show("T.CUR", 10, 10, 0)
    ' Row 0
    CALL Assert_IsEqual(GetP(8,  9),   0, "row0 col0 = 0 (black)")
    CALL Assert_IsEqual(GetP(9,  9), 255, "row0 col1 = 255 (white)")
    CALL Assert_IsEqual(GetP(10, 9),   0, "row0 col2 = 0 (black)")
    CALL Assert_IsEqual(GetP(11, 9), 255, "row0 col3 = 255 (white)")
    ' Row 1
    CALL Assert_IsEqual(GetP(8,  10), 255, "row1 col0 = 255 (white)")
    CALL Assert_IsEqual(GetP(9,  10),   0, "row1 col1 = 0 (black)")
    ' Row 3 spot check
    CALL Assert_IsEqual(GetP(8,  12), 255, "row3 col0 = 255 (white)")
    CALL Assert_IsEqual(GetP(10, 12),   0, "row3 col2 = 0 (black)")
END SUB

SUB Test_Show_8bit_Pixels
    CALL Test_Case("Show renders 8-bit cursor with correct pixel indices (identity palette)")
    ' hotspot (3,2), call Show at (20,20) -> adjusted origin (17,18)
    ' pixel(col,row) = 10 + row*4 + col -> directly is the colour index
    CALL MakeCur4x4_8bit("T8.CUR")
    CALL DrawCur_Show("T8.CUR", 20, 20, 0)
    CALL Assert_IsEqual(GetP(17, 18), 10, "8bit top-left = 10")
    CALL Assert_IsEqual(GetP(20, 18), 13, "8bit top-right = 13")
    CALL Assert_IsEqual(GetP(17, 21), 22, "8bit bottom-left = 22")
    CALL Assert_IsEqual(GetP(20, 21), 25, "8bit bottom-right = 25")
    CALL Assert_IsEqual(GetP(19, 19), 16, "8bit interior(2,1) = 16")
END SUB

SUB Test_Show_MissingFile
    CALL Test_Case("Show does nothing for a missing CUR file")
    ' Screen cleared to 0 in Test_Setup; this pixel should remain 0
    CALL DrawCur_Show("NOFILE.CUR", 50, 50, 0)
    CALL Assert_IsEqual(GetP(50, 50), 0, "no pixel written for missing file")
END SUB

SUB Test_LoadBitmap_1bit
    CALL Test_Case("LoadBitmap returns 1 and correct dimensions and hotspot for 1-bit cursor")
    DIM bmp AS STRING, msk AS STRING
    DIM w AS WORD, h AS WORD, hx AS WORD, hy AS WORD
    DIM ok AS BYTE
    CALL MakeCur4x4("T.CUR")
    ok = DrawCur_LoadBitmap("T.CUR", 0, bmp, msk, w, h, hx, hy)
    CALL Assert_IsEqual(ok, 1, "LoadBitmap returns 1")
    CALL Assert_IsEqual(w, 4, "LoadBitmap width = 4")
    CALL Assert_IsEqual(h, 4, "LoadBitmap height = 4")
    CALL Assert_IsEqual(hx, 2, "LoadBitmap hotX = 2")
    CALL Assert_IsEqual(hy, 1, "LoadBitmap hotY = 1")
    CALL Assert_IsEqual(LEN(bmp), 16, "bitmap buffer is w*h = 16 bytes")
    CALL Assert_IsEqual(LEN(msk), 16, "mask buffer is w*h = 16 bytes")
END SUB

SUB Test_LoadBitmap_1bit_PixelValues
    CALL Test_Case("LoadBitmap decodes 1-bit XOR pixels correctly (0=black 255=white)")
    DIM bmp AS STRING, msk AS STRING
    DIM w AS WORD, h AS WORD, hx AS WORD, hy AS WORD
    DIM ok AS BYTE
    CALL MakeCur4x4("T.CUR")
    ok = DrawCur_LoadBitmap("T.CUR", 0, bmp, msk, w, h, hx, hy)
    ' Row 0 (y=0): 0 1 0 1 -> 0, 255, 0, 255
    CALL Assert_IsEqual(ASC(MID$(bmp, 1, 1)),   0, "bmp(0,0) = 0")
    CALL Assert_IsEqual(ASC(MID$(bmp, 2, 1)), 255, "bmp(1,0) = 255")
    CALL Assert_IsEqual(ASC(MID$(bmp, 3, 1)),   0, "bmp(2,0) = 0")
    CALL Assert_IsEqual(ASC(MID$(bmp, 4, 1)), 255, "bmp(3,0) = 255")
    ' Row 1 (y=1): 1 0 1 0 -> 255, 0, 255, 0
    CALL Assert_IsEqual(ASC(MID$(bmp, 5, 1)), 255, "bmp(0,1) = 255")
    CALL Assert_IsEqual(ASC(MID$(bmp, 6, 1)),   0, "bmp(1,1) = 0")
    ' All mask bits are 0 (opaque)
    CALL Assert_IsEqual(ASC(MID$(msk, 1, 1)), 0, "mask(0,0) = 0 (opaque)")
    CALL Assert_IsEqual(ASC(MID$(msk, 4, 1)), 0, "mask(3,0) = 0 (opaque)")
END SUB

SUB Test_LoadBitmap_MissingFile
    CALL Test_Case("LoadBitmap returns 0 for missing file")
    DIM bmp AS STRING, msk AS STRING
    DIM w AS WORD, h AS WORD, hx AS WORD, hy AS WORD
    DIM ok AS BYTE
    ok = DrawCur_LoadBitmap("NOFILE.CUR", 0, bmp, msk, w, h, hx, hy)
    CALL Assert_IsZero(ok, "LoadBitmap = 0 for missing file")
    CALL Assert_IsZero(w, "width = 0 on failure")
    CALL Assert_IsZero(h, "height = 0 on failure")
END SUB

' =============================================================================
' Test_Show_4bit_Pixels: DrawCur_Show decodes 4-bit nibble-packed pixels correctly
' hotspot (1,1), Show at (10,10) -> origin (9,9)
' image row 0 (screen y=9): pixels 5,6,7,8 (file-row 3)
' image row 1 (screen y=10): pixels 1,2,3,4 (file-row 2)
' =============================================================================
SUB Test_Show_4bit_Pixels
    CALL Test_Case("Show decodes 4-bit cursor nibble-packed pixels correctly")
    CALL MakeCur4x4_4bit("T4.CUR")
    CALL DrawCur_Show("T4.CUR", 10, 10, 0)
    ' image row 0 at screen (9,9): file-row 3 = pixels 5,6,7,8
    CALL Assert_IsEqual(GetP(9,  9), 5, "4bit row0 col0 = 5")
    CALL Assert_IsEqual(GetP(10, 9), 6, "4bit row0 col1 = 6")
    CALL Assert_IsEqual(GetP(11, 9), 7, "4bit row0 col2 = 7")
    CALL Assert_IsEqual(GetP(12, 9), 8, "4bit row0 col3 = 8")
    ' image row 1 at screen (9,10): file-row 2 = pixels 1,2,3,4
    CALL Assert_IsEqual(GetP(9,  10), 1, "4bit row1 col0 = 1")
    CALL Assert_IsEqual(GetP(12, 10), 4, "4bit row1 col3 = 4")
END SUB

' =============================================================================
' Test_GetInfo_Index1_TwoCursors: GetInfo on cursor index=1 returns 4x4 8-bit
' =============================================================================
SUB Test_GetInfo_Index1_TwoCursors
    CALL Test_Case("GetInfo with index=1 returns second cursor info from two-cursor CUR")
    DIM w AS WORD, h AS WORD, cd AS WORD, hx AS WORD, hy AS WORD
    CALL MakeCur_TwoCursors("T2.CUR")
    CALL DrawCur_GetInfo("T2.CUR", 1, w, h, cd, hx, hy)
    CALL Assert_IsEqual(w,  4, "two-cursor index1 width = 4")
    CALL Assert_IsEqual(h,  4, "two-cursor index1 height = 4")
    CALL Assert_IsEqual(cd, 8, "two-cursor index1 colorDepth = 8")
    CALL Assert_IsEqual(hx, 2, "two-cursor index1 hotX = 2")
    CALL Assert_IsEqual(hy, 2, "two-cursor index1 hotY = 2")
END SUB

' =============================================================================
' Test_Show_SecondCursor_TwoCursorFile: Show at index=1 renders the second cursor
' cursor 1: 4x4 8-bit all pixels=7, hotspot (2,2), Show at (20,20) -> origin (18,18)
' =============================================================================
SUB Test_Show_SecondCursor
    CALL Test_Case("Show with index=1 renders the second cursor from a two-cursor file")
    CALL MakeCur_TwoCursors("T2.CUR")
    CALL DrawCur_Show("T2.CUR", 20, 20, 1)
    CALL Assert_IsEqual(GetP(18, 18), 7, "2nd cursor row0 col0 = 7")
    CALL Assert_IsEqual(GetP(21, 18), 7, "2nd cursor row0 col3 = 7")
    CALL Assert_IsEqual(GetP(18, 21), 7, "2nd cursor row3 col0 = 7")
    CALL Assert_IsEqual(GetP(21, 21), 7, "2nd cursor row3 col3 = 7")
END SUB

' =============================================================================
' Test_Show_ANDMask_Transparency: AND mask bit=1 means transparent; those pixels stay at background
' Pre-fill area with 33; opaque pixels must be 5, transparent must remain 33
' =============================================================================
SUB Test_Show_ANDMask_Transparency
    CALL Test_Case("Show does not draw pixels where AND mask bit is 1 (transparent)")
    CALL MakeCur4x4_ANDMasked("TMASK.CUR")
    DIM fx AS WORD, fy AS WORD
    FOR fy = 30 TO 33
        FOR fx = 50 TO 53
            CALL Vga_PutPixel(fx, fy, 33)
        NEXT fx
    NEXT fy
    ' hotspot (0,0) -> Show at (50,30) draws at (50,30)
    CALL DrawCur_Show("TMASK.CUR", 50, 30, 0)
    ' screen y=30 (pixelY=0): file-row 3 mask=&HC0 -> px0,1 transparent, px2,3 opaque
    CALL Assert_IsEqual(GetP(50, 30), 33, "AND-mask: row0 col0 transparent = 33")
    CALL Assert_IsEqual(GetP(51, 30), 33, "AND-mask: row0 col1 transparent = 33")
    CALL Assert_IsEqual(GetP(52, 30),  5, "AND-mask: row0 col2 opaque = 5")
    CALL Assert_IsEqual(GetP(53, 30),  5, "AND-mask: row0 col3 opaque = 5")
    ' screen y=31 (pixelY=1): file-row 2 mask=0x00 -> all opaque
    CALL Assert_IsEqual(GetP(50, 31), 5, "AND-mask: row1 col0 opaque = 5")
    CALL Assert_IsEqual(GetP(53, 31), 5, "AND-mask: row1 col3 opaque = 5")
    ' screen y=33 (pixelY=3): file-row 0 mask=&HF0 -> all transparent
    CALL Assert_IsEqual(GetP(50, 33), 33, "AND-mask: row3 col0 transparent = 33")
    CALL Assert_IsEqual(GetP(53, 33), 33, "AND-mask: row3 col3 transparent = 33")
END SUB

SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
    CALL Vga_InitMode13h
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB
