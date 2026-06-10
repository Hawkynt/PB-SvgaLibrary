' =============================================================================
' DRAW_TGA.BAS - tests for DRAW_TGA.SUB (TGA image loader)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "FILEUTIL.SUB"
DECLARE FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
$INCLUDE "DRAW_TGA.SUB"

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

' LE16 / LE32 helpers
FUNCTION LE16(BYVAL v AS WORD) AS STRING
    LE16 = CHR$(v AND 255) + CHR$((v \ 256) AND 255)
END FUNCTION
FUNCTION LE32(BYVAL v AS LONG) AS STRING
    LE32 = CHR$(v AND 255) + CHR$((v \ 256) AND 255) + _
           CHR$((v \ 65536) AND 255) + CHR$((v \ 16777216) AND 255)
END FUNCTION

' Build an 18-byte TGA header string
' imageType: 2=truecolor, 3=grayscale, 1=colormapped
' cmLen/cmBits: colour-map length and entry size in bits
' w, h: dimensions; bpp: bits per pixel
' descriptor: &H20 = top-down, 0 = bottom-up (default TGA)
FUNCTION MakeTgaHeader(BYVAL imageType AS BYTE, BYVAL cmLen AS WORD, BYVAL cmBits AS BYTE, _
                        BYVAL w AS WORD, BYVAL h AS WORD, BYVAL bpp AS BYTE, _
                        BYVAL descriptor AS BYTE) AS STRING
    DIM cmType AS BYTE
    IF cmLen > 0 THEN cmType = 1 ELSE cmType = 0
    MakeTgaHeader = CHR$(0) + CHR$(cmType) + CHR$(imageType) + _
                    LE16(0) + LE16(cmLen) + CHR$(cmBits) + _
                    LE16(0) + LE16(0) + _
                    LE16(w) + LE16(h) + CHR$(bpp) + CHR$(descriptor)
END FUNCTION

' Write a complete TGA file for an 8-bit grayscale (type=3) 4x4 image
' Pixel at screen(px, py) when loaded at (0,0) = baseVal + py*4 + px
' (values chosen so no two pixels share the same colour index)
SUB MakeTgaGray4x4TopDown(BYVAL fileName AS STRING)
    ' Top-down: descriptor bit5=1 (&H20), row 0 in file = top row on screen
    ' Image row 0 -> screen row 0 (y+0), row 1 -> y+1, etc.
    ' Pixel value at file row r, col c = 10 + r*4 + c
    DIM hdr AS STRING, pix AS STRING
    DIM r AS INTEGER, c AS INTEGER
    hdr = MakeTgaHeader(3, 0, 0, 4, 4, 8, &H20)
    pix = ""
    FOR r = 0 TO 3
        FOR c = 0 TO 4 - 1
            pix = pix + CHR$(10 + r * 4 + c)
        NEXT c
    NEXT r
    OPEN fileName FOR BINARY AS #1
    PUT$ #1, hdr + pix
    CLOSE #1
END SUB

' Write a complete TGA file for an 8-bit grayscale (type=3) 4x4 image, bottom-up
' (descriptor=0, default TGA): row 0 in file = BOTTOM row on screen
' pixel at screen(px, py) when loaded at (0,0) = 10 + py*4 + px
' (same pixel arrangement as above when displayed)
SUB MakeTgaGray4x4BottomUp(BYVAL fileName AS STRING)
    DIM hdr AS STRING, pix AS STRING
    DIM r AS INTEGER, c AS INTEGER
    ' Store rows bottom-to-top: file row 0 = screen row 3
    hdr = MakeTgaHeader(3, 0, 0, 4, 4, 8, 0)
    pix = ""
    FOR r = 3 TO 0 STEP -1
        FOR c = 0 TO 4 - 1
            pix = pix + CHR$(10 + r * 4 + c)
        NEXT c
    NEXT r
    OPEN fileName FOR BINARY AS #1
    PUT$ #1, hdr + pix
    CLOSE #1
END SUB

' Write a 4x4 colour-mapped (type=1) TGA with a 4-entry 24-bit colourmap
' Each entry is BGR 24-bit; entries:
'   index 0: B=20,G=40,R=60  -> grayscale = (60+40+20)\3 = 40
'   index 1: B=0, G=0, R=90  -> grayscale = 30
'   index 2: B=0, G=0, R=30  -> grayscale = 10
'   index 3: B=0, G=60, R=60 -> grayscale = 40
' Pixel layout (top-down, descriptor=&H20):
'   row 0: 0 1 2 3
'   row 1: 1 2 3 0
'   row 2: 2 3 0 1
'   row 3: 3 0 1 2
SUB MakeTgaCmap4x4(BYVAL fileName AS STRING)
    DIM hdr AS STRING, cmap AS STRING, pix AS STRING
    DIM r AS INTEGER, c AS INTEGER
    hdr = MakeTgaHeader(1, 4, 24, 4, 4, 8, &H20)
    ' BGR order for each colour entry
    cmap = CHR$(20) + CHR$(40) + CHR$(60)   ' index 0: b=20 g=40 r=60
    cmap = cmap + CHR$(0)  + CHR$(0)  + CHR$(90)   ' index 1: b=0 g=0 r=90
    cmap = cmap + CHR$(0)  + CHR$(0)  + CHR$(30)   ' index 2: b=0 g=0 r=30
    cmap = cmap + CHR$(0)  + CHR$(60) + CHR$(60)   ' index 3: b=0 g=60 r=60
    pix = ""
    FOR r = 0 TO 3
        FOR c = 0 TO 3
            pix = pix + CHR$((r + c) MOD 4)
        NEXT c
    NEXT r
    OPEN fileName FOR BINARY AS #1
    PUT$ #1, hdr + cmap + pix
    CLOSE #1
END SUB

' Helper: read one pixel from the VGA framebuffer at (x,y)
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, rv AS BYTE
    xv = x : yv = y : rv = 0
    CALL Vga_GetPixel(xv, yv, rv)
    GetP = rv
END FUNCTION

' ---------------------------------------------------------------------------
' Test cases
' ---------------------------------------------------------------------------

SUB Test_GetSize_ReturnsCorrectDimensions
    CALL Test_Case("GetSize returns correct width and height from TGA header")
    DIM w AS WORD, h AS WORD
    CALL MakeTgaGray4x4TopDown("T.TGA")
    CALL DrawTga_GetSize("T.TGA", w, h)
    CALL Assert_IsEqual(w, 4, "width = 4")
    CALL Assert_IsEqual(h, 4, "height = 4")
END SUB

SUB Test_GetSize_ReturnsZeroForMissingFile
    CALL Test_Case("GetSize returns 0 for a non-existent file")
    DIM w AS WORD, h AS WORD
    DIM result AS BYTE
    result = DrawTga_GetSize("NOFILE.TGA", w, h)
    CALL Assert_IsZero(result, "return = 0 for missing file")
END SUB

SUB Test_GetInfo_ReturnsHeaderFields
    CALL Test_Case("GetInfo returns image type and bpp from TGA header")
    DIM w AS WORD, h AS WORD
    DIM bpp AS BYTE, imgType AS BYTE
    CALL MakeTgaGray4x4TopDown("T.TGA")
    CALL DrawTga_GetInfo("T.TGA", w, h, bpp, imgType)
    CALL Assert_IsEqual(w, 4, "info width = 4")
    CALL Assert_IsEqual(h, 4, "info height = 4")
    CALL Assert_IsEqual(bpp, 8, "info bpp = 8")
    CALL Assert_IsEqual(imgType, 3, "info type = 3 (grayscale)")
END SUB

SUB Test_ParseFile_ValidatesZeroDimensions
    CALL Test_Case("ParseFile rejects a TGA with zero width")
    ' Build a header with width=0, height=4
    DIM hdr AS STRING, fh AS INTEGER, ctx AS TGAContextType
    hdr = MakeTgaHeader(3, 0, 0, 0, 4, 8, &H20)
    OPEN "TBAD.TGA" FOR BINARY AS #1
    PUT$ #1, hdr
    CLOSE #1
    fh = FileUtil_OpenBinary("TBAD.TGA")
    DIM ok AS BYTE
    ok = DrawTga_ParseFile(fh, ctx)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsZero(ok, "ParseFile = 0 for zero-width image")
END SUB

SUB Test_ParseFile_RejectsUnknownImageType
    CALL Test_Case("ParseFile rejects unsupported image type 99")
    DIM hdr AS STRING, fh AS INTEGER, ctx AS TGAContextType
    hdr = MakeTgaHeader(99, 0, 0, 4, 4, 8, &H20)
    OPEN "TBAD2.TGA" FOR BINARY AS #1
    PUT$ #1, hdr
    CLOSE #1
    fh = FileUtil_OpenBinary("TBAD2.TGA")
    DIM ok AS BYTE
    ok = DrawTga_ParseFile(fh, ctx)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsZero(ok, "ParseFile = 0 for unknown type 99")
END SUB

SUB Test_Show_TopDown_PixelValues
    CALL Test_Case("Show renders top-down 8-bit grayscale with correct row order")
    ' descriptor=&H20 -> top-down, row 0 in file = top row on screen
    CALL MakeTgaGray4x4TopDown("T.TGA")
    CALL DrawTga_Show("T.TGA", 50, 50)
    ' Pixel(0,0) in file = value 10, should appear at screen (50,50)
    CALL Assert_IsEqual(GetP(50, 50), 10, "top-left = 10")
    ' Pixel(3,0) in file = value 13, screen (53,50)
    CALL Assert_IsEqual(GetP(53, 50), 13, "top-right = 13")
    ' Pixel(0,3) in file = value 22, screen (50,53)
    CALL Assert_IsEqual(GetP(50, 53), 22, "bottom-left = 22")
    ' Pixel(3,3) in file = value 25, screen (53,53)
    CALL Assert_IsEqual(GetP(53, 53), 25, "bottom-right = 25")
    ' Interior pixel(2,1) = 10 + 1*4 + 2 = 16, screen (52,51)
    CALL Assert_IsEqual(GetP(52, 51), 16, "interior(2,1) = 16")
END SUB

SUB Test_Show_BottomUp_PixelValues
    CALL Test_Case("Show renders bottom-up TGA (default) with correct row flip")
    ' descriptor=0 -> bottom-up: row 0 in file = bottom row on screen
    ' MakeTgaGray4x4BottomUp stores rows reversed so same pixel arrangement as top-down
    CALL MakeTgaGray4x4BottomUp("TB.TGA")
    CALL DrawTga_Show("TB.TGA", 60, 60)
    ' Same expected pixel values as top-down test: pixel(col,row) = 10+row*4+col
    CALL Assert_IsEqual(GetP(60, 60), 10, "bottom-up: top-left = 10")
    CALL Assert_IsEqual(GetP(63, 60), 13, "bottom-up: top-right = 13")
    CALL Assert_IsEqual(GetP(60, 63), 22, "bottom-up: bottom-left = 22")
    CALL Assert_IsEqual(GetP(63, 63), 25, "bottom-up: bottom-right = 25")
END SUB

SUB Test_Show_ColorMapped_GrayscaleOutput
    CALL Test_Case("Show renders colour-mapped TGA as grayscale average of map entries")
    ' index 0: r=60 g=40 b=20 -> (60+40+20)\3 = 40
    ' index 1: r=90 g=0  b=0  -> (90+0+0)\3   = 30
    ' index 2: r=30 g=0  b=0  -> (30+0+0)\3   = 10
    ' index 3: r=60 g=60 b=0  -> (60+60+0)\3  = 40
    ' row 0 (top): indices = 0,1,2,3  -> grayscale = 40,30,10,40
    ' row 1: indices = 1,2,3,0 -> 30,10,40,40
    CALL MakeTgaCmap4x4("TC.TGA")
    CALL DrawTga_Show("TC.TGA", 70, 70)
    CALL Assert_IsEqual(GetP(70, 70), 40, "cmap row0 col0 index=0 -> gray=40")
    CALL Assert_IsEqual(GetP(71, 70), 30, "cmap row0 col1 index=1 -> gray=30")
    CALL Assert_IsEqual(GetP(72, 70), 10, "cmap row0 col2 index=2 -> gray=10")
    CALL Assert_IsEqual(GetP(70, 71), 30, "cmap row1 col0 index=1 -> gray=30")
END SUB

SUB Test_GetPalette_ReturnsTrueAndFillsColormap
    CALL Test_Case("GetPalette returns 1 and fills palette array from TGA colourmap")
    CALL MakeTgaCmap4x4("TC.TGA")
    DIM pal(767) AS BYTE
    DIM ok AS BYTE
    ok = DrawTga_GetPalette("TC.TGA", pal(), 8)
    CALL Assert_IsEqual(ok, 1, "GetPalette returns 1")
    ' index 0: r=60, g=40, b=20
    CALL Assert_IsEqual(pal(0 * 3),     60, "palette[0].R = 60")
    CALL Assert_IsEqual(pal(0 * 3 + 1), 40, "palette[0].G = 40")
    CALL Assert_IsEqual(pal(0 * 3 + 2), 20, "palette[0].B = 20")
    ' index 1: r=90, g=0, b=0
    CALL Assert_IsEqual(pal(1 * 3),     90, "palette[1].R = 90")
    CALL Assert_IsEqual(pal(1 * 3 + 1),  0, "palette[1].G = 0")
    CALL Assert_IsEqual(pal(1 * 3 + 2),  0, "palette[1].B = 0")
END SUB

SUB Test_GetPalette_NonColormapped_ReturnsTrueGrayscaleDefaults
    CALL Test_Case("GetPalette returns 1 for grayscale TGA and inits palette to identity")
    CALL MakeTgaGray4x4TopDown("T.TGA")
    DIM pal(767) AS BYTE
    DIM ok AS BYTE
    ok = DrawTga_GetPalette("T.TGA", pal(), 8)
    CALL Assert_IsEqual(ok, 1, "GetPalette returns 1 for grayscale")
    ' No colour map: palette initialised to grayscale identity i->i
    CALL Assert_IsEqual(pal(0),       0,  "palette[0].R = 0 (grayscale init)")
    CALL Assert_IsEqual(pal(10 * 3), 10,  "palette[10].R = 10 (grayscale init)")
    CALL Assert_IsEqual(pal(255 * 3), 255, "palette[255].R = 255 (grayscale init)")
END SUB

SUB Test_Show_FileSizeTooSmall
    CALL Test_Case("Show does nothing when file is smaller than 18-byte TGA header")
    ' Write only 10 bytes - too small for a TGA header
    OPEN "TSMALL.TGA" FOR BINARY AS #1
    PUT$ #1, STRING$(10, CHR$(0))
    CLOSE #1
    ' Just verify no crash; pixel at (0,0) should remain unchanged (0)
    CALL DrawTga_Show("TSMALL.TGA", 0, 0)
    CALL Assert_IsEqual(GetP(0, 0), 0, "no pixel written for truncated file")
END SUB

SUB Test_Show_SinglePixel
    CALL Test_Case("Show renders a 1x1 grayscale TGA correctly")
    DIM hdr AS STRING
    hdr = MakeTgaHeader(3, 0, 0, 1, 1, 8, &H20)
    OPEN "T1.TGA" FOR BINARY AS #1
    PUT$ #1, hdr + CHR$(77)
    CLOSE #1
    CALL DrawTga_Show("T1.TGA", 10, 10)
    CALL Assert_IsEqual(GetP(10, 10), 77, "1x1 pixel value = 77")
END SUB

SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
    CALL Vga_InitMode13h   ' initializes SVGAScreenContext.XRes/YRes for bounds checks
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB
