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

SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
    CALL Vga_InitMode13h
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB
