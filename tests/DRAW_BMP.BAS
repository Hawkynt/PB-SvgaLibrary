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

