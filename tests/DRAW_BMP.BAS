' =============================================================================
' DRAW_BMP.BAS - tests for DRAW_BMP.SUB (uncompressed 8-bit Windows BMP loader)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "FILEUTIL.SUB"
DECLARE FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
$INCLUDE "DRAW_BMP.SUB"

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

FUNCTION LE16(BYVAL v AS WORD) AS STRING
    LE16 = CHR$(v AND 255) + CHR$((v \ 256) AND 255)
END FUNCTION
FUNCTION LE32(BYVAL v AS LONG) AS STRING
    LE32 = CHR$(v AND 255) + CHR$((v \ 256) AND 255) + CHR$((v \ 65536) AND 255) + CHR$((v \ 16777216) AND 255)
END FUNCTION

' Build a 4x4 8-bit BMP: pixel(px,iy) index = 10 + iy*4 + px; palette[22] -> a
' known colour so the palette-seek path can be checked via the DAC.
SUB MakeBmp
    DIM pal AS STRING, pix AS STRING, hdr AS STRING, iy AS INTEGER, px AS INTEGER
    pal = STRING$(1024, CHR$(0))
    MID$(pal, 22 * 4 + 1, 1) = CHR$(64)     ' blue  8-bit -> 6-bit 16
    MID$(pal, 22 * 4 + 2, 1) = CHR$(128)    ' green -> 32
    MID$(pal, 22 * 4 + 3, 1) = CHR$(252)    ' red   -> 63
    pix = ""
    FOR iy = 3 TO 0 STEP -1                  ' BMP is bottom-up
        FOR px = 0 TO 3
            pix = pix + CHR$(10 + iy * 4 + px)
        NEXT px
    NEXT iy
    hdr = "BM" + LE32(1094) + LE32(0) + LE32(1078)
    hdr = hdr + LE32(40) + LE32(4) + LE32(4) + LE16(1) + LE16(8) + _
                LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)
    OPEN "T.BMP" FOR BINARY AS #1
    PUT$ #1, hdr + pal + pix
    CLOSE #1
END SUB

FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r) : GetP = r
END FUNCTION

SUB Test_GetSize
    CALL Test_Case("GetSize reads the BMP width and height from the header")
    DIM w AS WORD, h AS WORD
    CALL MakeBmp
    CALL DrawBmp_GetSize("T.BMP", w, h)
    CALL Assert_IsEqual(w, 4, "width = 4")
    CALL Assert_IsEqual(h, 4, "height = 4")
END SUB

SUB Test_Show_Pixels
    CALL Test_Case("Show decodes the 8-bit image upright with correct indices")
    CALL MakeBmp
    CALL DrawBmp_Show("T.BMP", 100, 100)
    CALL Assert_IsEqual(GetP(100, 100), 10, "top-left = image(0,0)")
    CALL Assert_IsEqual(GetP(103, 100), 13, "top-right = image(3,0)")
    CALL Assert_IsEqual(GetP(100, 103), 22, "bottom-left = image(0,3)")
    CALL Assert_IsEqual(GetP(103, 103), 25, "bottom-right = image(3,3)")
    CALL Assert_IsEqual(GetP(102, 101), 16, "interior = image(2,1)")
END SUB

SUB Test_Show_Palette
    CALL Test_Case("Show loads the BMP palette into the VGA DAC (BGR->RGB, 6-bit)")
    CALL MakeBmp
    CALL DrawBmp_Show("T.BMP", 100, 100)
    OUT &H3C7, 22
    CALL Assert_IsEqual(INP(&H3C9), 63, "R of palette entry 22")
    CALL Assert_IsEqual(INP(&H3C9), 32, "G of palette entry 22")
    CALL Assert_IsEqual(INP(&H3C9), 16, "B of palette entry 22")
END SUB

SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
END SUB
SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB

SUB Test_DrawScanline_Direct
    CALL Test_Case("DrawScanline draws one 8-bit row directly")
    DIM sl AS STRING
    sl = CHR$(30) + CHR$(31) + CHR$(32) + CHR$(33)
    CALL DrawBmp_DrawScanline(sl, 50, 60, 4, 8)
    CALL Assert_IsEqual(GetP(50, 60), 30, "pixel 0")
    CALL Assert_IsEqual(GetP(51, 60), 31, "pixel 1")
    CALL Assert_IsEqual(GetP(53, 60), 33, "pixel 3")
END SUB

SUB Test_ReadHeader_Values
    CALL Test_Case("ReadHeader parses offset/size/depth")
    DIM fh AS INTEGER, dofs AS LONG, iw AS LONG, ih AS LONG, cd AS WORD, nc AS WORD
    CALL MakeBmp
    fh = FileUtil_OpenBinary("T.BMP")
    CALL DrawBmp_ReadHeader(fh, dofs, iw, ih, cd, nc)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsEqual(dofs, 1078, "data offset = 1078")
    CALL Assert_IsEqual(iw, 4, "width = 4")
    CALL Assert_IsEqual(ih, 4, "height = 4")
    CALL Assert_IsEqual(cd, 8, "colour depth = 8")
END SUB

' =============================================================================
' Build a 4x2 4-bit BMP fixture (T4.BMP).
'
' Pixel layout (image coords, col 0..3, row 0..1 top-to-bottom):
'   row 0: indices 3, 5, 7, 9
'   row 1: indices 1, 2, 4, 6
'
' 4-bit BMP scanline: two pixels per byte, upper nibble = left pixel.
'   row 0 packed (image bottom-up -> file row 0 = image row 1):
'     file-row 0 (image row 1): 1,2,4,6 -> CHR$(&H12)+CHR$(&H46)+2 pad bytes
'     file-row 1 (image row 0): 3,5,7,9 -> CHR$(&H35)+CHR$(&H79)+2 pad bytes
'
' bytesPerLine for 4-bit = ((width+7)\8)*4 = ((4+7)\8)*4 = 1*4 = 4
' dataOffset  = 14 (file header) + 40 (dib header) + 16*4 (16-colour palette) = 118
' =============================================================================
SUB MakeBmp4bit
    DIM pal AS STRING, pix AS STRING, hdr AS STRING
    pal = STRING$(64, CHR$(0))   ' 16 palette entries BGRA (all zeros)

    ' file-row 0 = image row 1: 1,2,4,6  +  2 padding
    pix = CHR$(&H12) + CHR$(&H46) + CHR$(0) + CHR$(0)
    ' file-row 1 = image row 0: 3,5,7,9  +  2 padding
    pix = pix + CHR$(&H35) + CHR$(&H79) + CHR$(0) + CHR$(0)

    ' File header: "BM", fileSize, reserved, dataOffset=118
    hdr = "BM" + LE32(118 + 8) + LE32(0) + LE32(118)
    ' DIB header: size=40, width=4, height=2, planes=1, bitcount=4, rest=0
    hdr = hdr + LE32(40) + LE32(4) + LE32(2) + LE16(1) + LE16(4) + _
                LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    OPEN "T4.BMP" FOR BINARY AS #1
    PUT$ #1, hdr + pal + pix
    CLOSE #1
END SUB

' =============================================================================
' Build a 5x1 4-bit BMP (T4ODD.BMP) to test odd-width handling.
'
' Image has 1 row, 5 pixels: indices 1,2,3,4,5
' bytesPerLine for 4-bit 5-wide = ((5+7)\8)*4 = ((12)\8)*4 = 1*4 = 4
' Packed scanline: byte0=&H12 (px0=1,px1=2), byte1=&H34 (px2=3,px3=4),
'                  byte2=&H50 (px4=5, pad nibble=0), byte3=pad=0
' BMP is bottom-up so single row: file-row 0 = image row 0.
' dataOffset = 14 + 40 + 16*4 = 118
' =============================================================================
SUB MakeBmp4bitOdd
    DIM pal AS STRING, pix AS STRING, hdr AS STRING
    pal = STRING$(64, CHR$(0))
    ' scanline: px0=1 px1=2 -> &H12; px2=3 px3=4 -> &H34; px4=5 pad=0 -> &H50; pad byte
    pix = CHR$(&H12) + CHR$(&H34) + CHR$(&H50) + CHR$(0)

    hdr = "BM" + LE32(118 + 4) + LE32(0) + LE32(118)
    hdr = hdr + LE32(40) + LE32(5) + LE32(1) + LE16(1) + LE16(4) + _
                LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    OPEN "T4ODD.BMP" FOR BINARY AS #1
    PUT$ #1, hdr + pal + pix
    CLOSE #1
END SUB

' =============================================================================
' Build a 5x1 8-bit BMP with width not divisible by 4 (T8ODD.BMP).
'
' Image has 1 row, 5 pixels: indices 10,20,30,40,50
' bytesPerLine for 8-bit 5-wide = ((5+3)\4)*4 = (8\4)*4 = 8
' Scanline = 10 20 30 40 50 0 0 0  (3 padding bytes to reach 8)
' dataOffset = 14 + 40 + 256*4 = 1078
' =============================================================================
SUB MakeBmp8bitOdd
    DIM pal AS STRING, pix AS STRING, hdr AS STRING
    pal = STRING$(1024, CHR$(0))
    pix = CHR$(10) + CHR$(20) + CHR$(30) + CHR$(40) + CHR$(50) + CHR$(0) + CHR$(0) + CHR$(0)

    hdr = "BM" + LE32(1078 + 8) + LE32(0) + LE32(1078)
    hdr = hdr + LE32(40) + LE32(5) + LE32(1) + LE16(1) + LE16(8) + _
                LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0) + LE32(0)

    OPEN "T8ODD.BMP" FOR BINARY AS #1
    PUT$ #1, hdr + pal + pix
    CLOSE #1
END SUB

' =============================================================================
' Test_DrawScanline_4bit_EvenWidth: 4-bit scanline, all nibbles used (width=4)
' =============================================================================
SUB Test_DrawScanline_4bit_EvenWidth
    CALL Test_Case("DrawScanline decodes 4-bit even-width scanline (nibble unpacking)")
    ' Two bytes: &H35 -> high nibble=3, low nibble=5;  &H79 -> high=7, low=9
    DIM sl AS STRING
    sl = CHR$(&H35) + CHR$(&H79) + CHR$(0) + CHR$(0)
    CALL DrawBmp_DrawScanline(sl, 10, 30, 4, 4)
    CALL Assert_IsEqual(GetP(10, 30), 3, "4-bit px0 = 3 (high nibble byte0)")
    CALL Assert_IsEqual(GetP(11, 30), 5, "4-bit px1 = 5 (low nibble byte0)")
    CALL Assert_IsEqual(GetP(12, 30), 7, "4-bit px2 = 7 (high nibble byte1)")
    CALL Assert_IsEqual(GetP(13, 30), 9, "4-bit px3 = 9 (low nibble byte1)")
END SUB

' =============================================================================
' Test_DrawScanline_4bit_OddWidth: 4-bit scanline with odd pixel count (width=5)
' The 5th pixel is the high nibble of the second byte; low nibble is padding.
' =============================================================================
SUB Test_DrawScanline_4bit_OddWidth
    CALL Test_Case("DrawScanline decodes 4-bit odd-width scanline (last pixel = high nibble)")
    ' px0=1 px1=2 -> &H12; px2=3 px3=4 -> &H34; px4=5 pad=0 -> &H50; pad byte
    DIM sl AS STRING
    sl = CHR$(&H12) + CHR$(&H34) + CHR$(&H50) + CHR$(0)
    CALL DrawBmp_DrawScanline(sl, 20, 35, 5, 4)
    CALL Assert_IsEqual(GetP(20, 35), 1, "4-bit odd px0 = 1")
    CALL Assert_IsEqual(GetP(21, 35), 2, "4-bit odd px1 = 2")
    CALL Assert_IsEqual(GetP(22, 35), 3, "4-bit odd px2 = 3")
    CALL Assert_IsEqual(GetP(23, 35), 4, "4-bit odd px3 = 4")
    CALL Assert_IsEqual(GetP(24, 35), 5, "4-bit odd px4 = 5 (odd last pixel)")
END SUB

' =============================================================================
' Test_Show_4bit: full DrawBmp_Show round-trip for a 4-bit BMP
' =============================================================================
SUB Test_Show_4bit
    CALL Test_Case("Show decodes a 4-bit BMP image upright with correct nibble indices")
    CALL MakeBmp4bit
    CALL DrawBmp_Show("T4.BMP", 60, 70)
    ' Image row 0 (top) = screen y=70: pixels 3,5,7,9
    CALL Assert_IsEqual(GetP(60, 70), 3, "4bpp row0 col0 = 3")
    CALL Assert_IsEqual(GetP(61, 70), 5, "4bpp row0 col1 = 5")
    CALL Assert_IsEqual(GetP(62, 70), 7, "4bpp row0 col2 = 7")
    CALL Assert_IsEqual(GetP(63, 70), 9, "4bpp row0 col3 = 9")
    ' Image row 1 = screen y=71: pixels 1,2,4,6
    CALL Assert_IsEqual(GetP(60, 71), 1, "4bpp row1 col0 = 1")
    CALL Assert_IsEqual(GetP(61, 71), 2, "4bpp row1 col1 = 2")
    CALL Assert_IsEqual(GetP(62, 71), 4, "4bpp row1 col2 = 4")
    CALL Assert_IsEqual(GetP(63, 71), 6, "4bpp row1 col3 = 6")
END SUB

' =============================================================================
' Test_Show_8bit_DwordPadding: 8-bit BMP with width=5 (not DWORD-aligned)
' Only the 5 valid pixels should be drawn; 3 padding bytes must not appear.
' =============================================================================
SUB Test_Show_8bit_DwordPadding
    CALL Test_Case("Show reads only valid pixels for 8-bit width-5 BMP (DWORD padding)")
    CALL MakeBmp8bitOdd
    CALL DrawBmp_Show("T8ODD.BMP", 80, 90)
    CALL Assert_IsEqual(GetP(80, 90), 10, "odd-width px0 = 10")
    CALL Assert_IsEqual(GetP(81, 90), 20, "odd-width px1 = 20")
    CALL Assert_IsEqual(GetP(82, 90), 30, "odd-width px2 = 30")
    CALL Assert_IsEqual(GetP(83, 90), 40, "odd-width px3 = 40")
    CALL Assert_IsEqual(GetP(84, 90), 50, "odd-width px4 = 50")
END SUB

