' =============================================================================
' DRAW_PCX.BAS - tests for DRAW_PCX.SUB (8-bit RLE-compressed PCX loader)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "FILEUTIL.SUB"
DECLARE FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
$INCLUDE "DRAW_BMP.SUB"
$INCLUDE "DRAW_PCX.SUB"

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

' --- Helper: read pixel from VGA framebuffer ---------------------------------
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r) : GetP = r
END FUNCTION

' --- LE16 helper for building fixture ----------------------------------------
FUNCTION LE16(BYVAL v AS WORD) AS STRING
    LE16 = CHR$(v AND 255) + CHR$((v \ 256) AND 255)
END FUNCTION

' =============================================================================
' Build a 4x3, 8-bit PCX fixture in T.PCX.
'
' Image pixels (row, col) -> colour index:
'   row 0: 10 11 12 13   (4 literal bytes, all < 192 so stored as-is)
'   row 1: 20 20 20 21   (RLE: 0xC3 20, then literal 21)
'   row 2: 30 30 30 30   (RLE: 0xC4 30)
'
' Palette: entry 10 = R=200 G=100 B=50  -> DAC values R=50 G=25 B=12
'
' PCX structure (0-based byte offsets):
'   0-127  : header (128 bytes)
'   128-... : RLE image data
'   last 769: CHR$(12) + 768 RGB palette bytes
' =============================================================================
SUB MakePcx
    DIM hdr AS STRING, imgData AS STRING, pal AS STRING
    DIM i AS INTEGER

    ' --- 128-byte header ---
    hdr = CHR$(10)          ' manufacturer = 0x0A
    hdr = hdr + CHR$(5)     ' version = 5
    hdr = hdr + CHR$(1)     ' encoding = 1 (RLE)
    hdr = hdr + CHR$(8)     ' bits per pixel = 8
    hdr = hdr + LE16(0)     ' XMin = 0
    hdr = hdr + LE16(0)     ' YMin = 0
    hdr = hdr + LE16(3)     ' XMax = 3  -> width  = 4
    hdr = hdr + LE16(2)     ' YMax = 2  -> height = 3
    ' pad to 128 bytes
    hdr = hdr + STRING$(128 - LEN(hdr), CHR$(0))

    ' --- RLE-encoded scanlines ---
    ' row 0: four literal pixels 10,11,12,13 (all < 192, written as-is)
    imgData = CHR$(10) + CHR$(11) + CHR$(12) + CHR$(13)
    ' row 1: run of 3 x 20 then 1 x 21
    '   0xC3 = 192+3 = 195 -> run of 3
    imgData = imgData + CHR$(195) + CHR$(20) + CHR$(21)
    ' row 2: run of 4 x 30
    '   0xC4 = 192+4 = 196 -> run of 4
    imgData = imgData + CHR$(196) + CHR$(30)

    ' --- 769-byte palette block: marker + 256 * RGB ---
    pal = CHR$(12)                          ' palette marker = 0x0C
    pal = pal + STRING$(10 * 3, CHR$(0))    ' entries 0-9: black
    ' entry 10: R=200 G=100 B=50
    pal = pal + CHR$(200) + CHR$(100) + CHR$(50)
    ' entries 11-255: pad to complete 768 bytes of palette data
    pal = pal + STRING$(768 - (11 * 3), CHR$(0))

    ' Write file
    OPEN "T.PCX" FOR BINARY AS #1
    PUT$ #1, hdr + imgData + pal
    CLOSE #1
END SUB

' =============================================================================
' Test_Setup: switch to mode 13h (320x200 256-colour)
' =============================================================================
SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
END SUB

' =============================================================================
' Test_Teardown: restore text mode
' =============================================================================
SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB

' =============================================================================
' Test_ReadHeader: DrawPcx_ReadHeader returns correct width and height
' =============================================================================
SUB Test_ReadHeader
    CALL Test_Case("ReadHeader extracts width and height from PCX bounding box")
    DIM fh AS INTEGER, w AS WORD, h AS WORD
    CALL MakePcx
    fh = FileUtil_OpenBinary("T.PCX")
    CALL DrawPcx_ReadHeader(fh, w, h)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsEqual(w, 4, "width = 4")
    CALL Assert_IsEqual(h, 3, "height = 3")
END SUB

' =============================================================================
' Test_GetSize: DrawPcx_GetSize returns correct width and height
' =============================================================================
SUB Test_GetSize
    CALL Test_Case("GetSize reads PCX width and height from the header")
    DIM w AS WORD, h AS WORD
    CALL MakePcx
    CALL DrawPcx_GetSize("T.PCX", w, h)
    CALL Assert_IsEqual(w, 4, "GetSize: width = 4")
    CALL Assert_IsEqual(h, 3, "GetSize: height = 3")
END SUB

' =============================================================================
' Test_ReadScanline_Literal: all four bytes in row 0 are < 192 (literals)
' =============================================================================
SUB Test_ReadScanline_Literal
    CALL Test_Case("ReadScanline decodes a row of literal (non-RLE) bytes correctly")
    DIM fh AS INTEGER, sl AS STRING
    CALL MakePcx
    fh = FileUtil_OpenBinary("T.PCX")
    ' row 0 data starts at byte 128 (0-based)
    SEEK fh, 128
    CALL DrawPcx_ReadScanline(fh, sl, 4)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsEqual(LEN(sl), 4, "scanline length = 4")
    CALL Assert_IsEqual(ASC(MID$(sl, 1, 1)), 10, "sl[0] = 10")
    CALL Assert_IsEqual(ASC(MID$(sl, 2, 1)), 11, "sl[1] = 11")
    CALL Assert_IsEqual(ASC(MID$(sl, 3, 1)), 12, "sl[2] = 12")
    CALL Assert_IsEqual(ASC(MID$(sl, 4, 1)), 13, "sl[3] = 13")
END SUB

' =============================================================================
' Test_ReadScanline_Rle: row 1 has a run of 3 then a literal
' =============================================================================
SUB Test_ReadScanline_Rle
    CALL Test_Case("ReadScanline expands RLE run and appends trailing literal")
    DIM fh AS INTEGER, sl AS STRING
    CALL MakePcx
    fh = FileUtil_OpenBinary("T.PCX")
    ' row 0 occupies 4 bytes (128-131), row 1 starts at 132
    SEEK fh, 132
    CALL DrawPcx_ReadScanline(fh, sl, 4)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsEqual(LEN(sl), 4, "scanline length = 4")
    CALL Assert_IsEqual(ASC(MID$(sl, 1, 1)), 20, "sl[0] = 20")
    CALL Assert_IsEqual(ASC(MID$(sl, 2, 1)), 20, "sl[1] = 20")
    CALL Assert_IsEqual(ASC(MID$(sl, 3, 1)), 20, "sl[2] = 20")
    CALL Assert_IsEqual(ASC(MID$(sl, 4, 1)), 21, "sl[3] = 21")
END SUB

' =============================================================================
' Test_ReadScanline_RleFullRow: row 2 is a single RLE run for the entire row
' =============================================================================
SUB Test_ReadScanline_RleFullRow
    CALL Test_Case("ReadScanline handles RLE run spanning the entire scanline")
    DIM fh AS INTEGER, sl AS STRING
    CALL MakePcx
    fh = FileUtil_OpenBinary("T.PCX")
    ' row 0: 4 bytes (128-131), row 1: 3 bytes (132-134), row 2 starts at 135
    SEEK fh, 135
    CALL DrawPcx_ReadScanline(fh, sl, 4)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsEqual(LEN(sl), 4, "scanline length = 4")
    CALL Assert_IsEqual(ASC(MID$(sl, 1, 1)), 30, "sl[0] = 30")
    CALL Assert_IsEqual(ASC(MID$(sl, 2, 1)), 30, "sl[1] = 30")
    CALL Assert_IsEqual(ASC(MID$(sl, 3, 1)), 30, "sl[2] = 30")
    CALL Assert_IsEqual(ASC(MID$(sl, 4, 1)), 30, "sl[3] = 30")
END SUB

' =============================================================================
' Test_LoadPalette: palette entry 10 should appear in VGA DAC after load
' =============================================================================
SUB Test_LoadPalette
    CALL Test_Case("LoadPalette writes RGB values for entry 10 to the VGA DAC (6-bit scaled)")
    DIM fh AS INTEGER
    CALL MakePcx
    fh = FileUtil_OpenBinary("T.PCX")
    CALL DrawPcx_LoadPalette(fh)
    CALL FileUtil_CloseBinary(fh)
    ' Entry 10: R=200->50, G=100->25, B=50->12 (integer division by 4)
    OUT &H3C7, 10
    CALL Assert_IsEqual(INP(&H3C9), 50, "DAC entry 10 Red = 50")
    CALL Assert_IsEqual(INP(&H3C9), 25, "DAC entry 10 Green = 25")
    CALL Assert_IsEqual(INP(&H3C9), 12, "DAC entry 10 Blue = 12")
END SUB

' =============================================================================
' Test_Show_Pixels: full DrawPcx_Show writes correct pixel indices to VGA
' =============================================================================
SUB Test_Show_Pixels
    CALL Test_Case("Show decodes the 8-bit image and plots correct colour indices")
    CALL MakePcx
    CALL DrawPcx_Show("T.PCX", 50, 80)
    ' row 0
    CALL Assert_IsEqual(GetP(50, 80), 10, "pixel(0,0) = 10")
    CALL Assert_IsEqual(GetP(51, 80), 11, "pixel(1,0) = 11")
    CALL Assert_IsEqual(GetP(52, 80), 12, "pixel(2,0) = 12")
    CALL Assert_IsEqual(GetP(53, 80), 13, "pixel(3,0) = 13")
    ' row 1 (RLE run of 3 x 20 + literal 21)
    CALL Assert_IsEqual(GetP(50, 81), 20, "pixel(0,1) = 20")
    CALL Assert_IsEqual(GetP(51, 81), 20, "pixel(1,1) = 20")
    CALL Assert_IsEqual(GetP(52, 81), 20, "pixel(2,1) = 20")
    CALL Assert_IsEqual(GetP(53, 81), 21, "pixel(3,1) = 21")
    ' row 2 (full RLE run of 4 x 30)
    CALL Assert_IsEqual(GetP(50, 82), 30, "pixel(0,2) = 30")
    CALL Assert_IsEqual(GetP(53, 82), 30, "pixel(3,2) = 30")
END SUB

' =============================================================================
' Test_Show_Palette: DrawPcx_Show sets the DAC for palette entry 10
' =============================================================================
SUB Test_Show_Palette
    CALL Test_Case("Show loads the PCX palette into the VGA DAC (RGB, 6-bit scaled)")
    CALL MakePcx
    CALL DrawPcx_Show("T.PCX", 50, 80)
    OUT &H3C7, 10
    CALL Assert_IsEqual(INP(&H3C9), 50, "Show: DAC entry 10 Red = 50")
    CALL Assert_IsEqual(INP(&H3C9), 25, "Show: DAC entry 10 Green = 25")
    CALL Assert_IsEqual(INP(&H3C9), 12, "Show: DAC entry 10 Blue = 12")
END SUB

' =============================================================================
' Test_DrawScanline_Direct: DrawPcx_DrawScanline renders pixels via Svga_PutPixel
' =============================================================================
SUB Test_DrawScanline_Direct
    CALL Test_Case("DrawScanline draws 8-bit pixels directly to VGA at given coordinates")
    DIM sl AS STRING
    sl = CHR$(40) + CHR$(41) + CHR$(42) + CHR$(43)
    CALL DrawPcx_DrawScanline(sl, 10, 20, 4)
    CALL Assert_IsEqual(GetP(10, 20), 40, "DrawScanline pixel 0 = 40")
    CALL Assert_IsEqual(GetP(11, 20), 41, "DrawScanline pixel 1 = 41")
    CALL Assert_IsEqual(GetP(12, 20), 42, "DrawScanline pixel 2 = 42")
    CALL Assert_IsEqual(GetP(13, 20), 43, "DrawScanline pixel 3 = 43")
END SUB

' =============================================================================
' Test_ReadScanline_MaxLiteralByte: a byte value of 191 (0xBF) is the largest
' value that is treated as a literal pixel (< 192).  It must NOT be decoded
' as an RLE header and must be stored directly as pixel index 191.
' =============================================================================
SUB Test_ReadScanline_MaxLiteralByte
    CALL Test_Case("ReadScanline treats byte 191 as literal pixel (boundary: max non-RLE byte)")
    ' Build a minimal PCX: 1-pixel wide, 1 row, data = CHR$(191)
    ' Header: manufacturer=0x0A, version=5, enc=1, bpp=8
    ' XMin=0,YMin=0,XMax=0,YMax=0 -> width=1, height=1
    DIM hdr AS STRING, imgData AS STRING, pal AS STRING
    hdr = CHR$(10) + CHR$(5) + CHR$(1) + CHR$(8)
    hdr = hdr + LE16(0) + LE16(0) + LE16(0) + LE16(0)
    hdr = hdr + STRING$(128 - LEN(hdr), CHR$(0))
    imgData = CHR$(191)    ' 0xBF = 191 < 192 -> literal
    pal = CHR$(12) + STRING$(768, CHR$(0))
    OPEN "TLIT.PCX" FOR BINARY AS #1
    PUT$ #1, hdr + imgData + pal
    CLOSE #1

    DIM fh AS INTEGER, sl AS STRING
    fh = FileUtil_OpenBinary("TLIT.PCX")
    SEEK fh, 128
    CALL DrawPcx_ReadScanline(fh, sl, 1)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsEqual(LEN(sl), 1, "max-literal: scanline length = 1")
    CALL Assert_IsEqual(ASC(MID$(sl, 1, 1)), 191, "max-literal: sl[0] = 191")
END SUB

' =============================================================================
' Test_ReadScanline_RleClippedAtBoundary: an RLE run that is larger than the
' remaining pixels in the scanline must be clipped.  The code already has the
' EXIT FOR guard; this test verifies it actually fires.
'
' Setup: width=3, stream = CHR$(0xC5)=197 (run of 5) CHR$(88)
' The run of 5 should fill exactly 3 pixels (width=3) and stop.
' =============================================================================
SUB Test_ReadScanline_RleClippedAtBoundary
    CALL Test_Case("ReadScanline clips an over-long RLE run at the scanline boundary")
    DIM fh AS INTEGER, sl AS STRING
    ' Write just the compressed bytes to a temp file and seek there
    OPEN "TCLIP.TMP" FOR BINARY AS #1
    PUT$ #1, CHR$(197) + CHR$(88)   ' run of 5 x 88, but width=3
    CLOSE #1
    fh = FileUtil_OpenBinary("TCLIP.TMP")
    SEEK fh, 0
    CALL DrawPcx_ReadScanline(fh, sl, 3)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsEqual(LEN(sl), 3, "clipped run: scanline length = 3")
    CALL Assert_IsEqual(ASC(MID$(sl, 1, 1)), 88, "clipped sl[0] = 88")
    CALL Assert_IsEqual(ASC(MID$(sl, 2, 1)), 88, "clipped sl[1] = 88")
    CALL Assert_IsEqual(ASC(MID$(sl, 3, 1)), 88, "clipped sl[2] = 88")
END SUB

' =============================================================================
' Test_Show_OddWidthBytesPerLine: PCX image whose width is not a multiple of
' the BytesPerLine (which is typically the same as width for 8-bit PCX, but
' the GetSize/ReadHeader path still reports the correct pixel count).
'
' We build a 5x1 PCX with 5 literal bytes (all < 192) and verify GetSize
' returns width=5 and that Show plots exactly 5 correct pixels.
' =============================================================================
SUB Test_Show_OddWidthBytesPerLine
    CALL Test_Case("Show handles PCX with odd width correctly (5-pixel wide image)")
    DIM hdr AS STRING, imgData AS STRING, pal AS STRING
    hdr = CHR$(10) + CHR$(5) + CHR$(1) + CHR$(8)
    hdr = hdr + LE16(0) + LE16(0) + LE16(4) + LE16(0)  ' XMax=4 -> width=5
    hdr = hdr + STRING$(128 - LEN(hdr), CHR$(0))
    ' 5 literal pixels: 11,22,33,44,55  (all < 192)
    imgData = CHR$(11) + CHR$(22) + CHR$(33) + CHR$(44) + CHR$(55)
    pal = CHR$(12) + STRING$(768, CHR$(0))
    OPEN "TODD.PCX" FOR BINARY AS #1
    PUT$ #1, hdr + imgData + pal
    CLOSE #1

    DIM w AS WORD, h AS WORD
    CALL DrawPcx_GetSize("TODD.PCX", w, h)
    CALL Assert_IsEqual(w, 5, "odd-width GetSize: width = 5")
    CALL Assert_IsEqual(h, 1, "odd-width GetSize: height = 1")

    CALL DrawPcx_Show("TODD.PCX", 70, 90)
    CALL Assert_IsEqual(GetP(70, 90), 11, "odd-width px0 = 11")
    CALL Assert_IsEqual(GetP(71, 90), 22, "odd-width px1 = 22")
    CALL Assert_IsEqual(GetP(72, 90), 33, "odd-width px2 = 33")
    CALL Assert_IsEqual(GetP(73, 90), 44, "odd-width px3 = 44")
    CALL Assert_IsEqual(GetP(74, 90), 55, "odd-width px4 = 55")
END SUB
