' =============================================================================
' FONTS.BAS - tests for FONTS.SUB (font loading and text rendering)
' =============================================================================
' Font format: text file, 256 lines, each line = 8 space-separated decimal
' byte values describing one row of the 8x8 glyph for that ASCII code.
' VgaPrint reads FontDataStore, extracts glyph rows, calls Svga_PutPixel for
' each bit that is 1 (foreground); if flags AND 2, also draws 0-bit pixels
' (background).  Svga_PutPixel is stubbed to Vga_PutPixel so we can read
' pixels back with Vga_GetPixel in mode 13h.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "PORTGLUE.SUB"
$INCLUDE "FONTS.SUB"

' --- stubs -------------------------------------------------------------------
SUB Svga_InitDispatchTable
END SUB
SUB Memory_ClearVideoMemory(BYVAL c AS BYTE)
    DIM cw AS WORD
    cw = c : SHIFT LEFT cw, 8 : cw = cw OR c
    !MOV AX, &HA000
    !MOV ES, AX
    !XOR DI, DI
    !MOV CX, 32000
    !MOV AX, cw
    !CLD
    !REP STOSW
END SUB
SUB Svga_PutPixel(x AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_PutPixel(x, y, c)
END SUB
SUB Svga_HLine(x1 AS WORD, x2 AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_HLine(x1, x2, y, c)
END SUB

' --- helpers -----------------------------------------------------------------
' GetP: read a pixel from the VGA framebuffer via the Vga_GetPixel helper.
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

' MakeFontFile: write a deterministic test font to disk.
'   All 256 characters share the same row pattern so pixels are predictable.
'   Row bytes alternate: odd rows = 255 (all-foreground), even = 0 (all-bg).
'   This means for any rendered character at (x,y):
'     row 1 (y+0): byte=255 -> 8 foreground pixels
'     row 2 (y+1): byte=0   -> 8 background pixels (if flags AND 2)
'     rows 3..8 alternate likewise.
SUB MakeFontFile(fontPath AS STRING)
    DIM fh AS INTEGER, i AS INTEGER
    fh = FREEFILE
    OPEN "O", #fh, fontPath
    FOR i = 0 TO 255
        PRINT #fh, "255 0 255 0 255 0 255 0"
    NEXT i
    CLOSE fh
END SUB

' ClearScreen helper using mode 13h direct write
SUB ClrScr(BYVAL c AS BYTE)
    DIM cv AS BYTE
    cv = c
    CALL Vga_ClearScreen(cv)
END SUB

' ============================================================================
' Test: Fonts_GetFontInfo - after loading, FontSystemContext reports 8x8
' ============================================================================
SUB Test_GetFontInfo_AfterLoad
    CALL Test_Case("GetFontInfo: CharWidth and CharHeight are 8 after InitFont")
    ' Arrange
    CALL MakeFontFile("TEST.FNT")
    ' Act
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL Fonts_GetFontInfo()
    ' Assert
    CALL Assert_IsEqual(FontSystemContext.CharWidth,  8, "CharWidth = 8")
    CALL Assert_IsEqual(FontSystemContext.CharHeight, 8, "CharHeight = 8")
END SUB

' ============================================================================
' Test: Fonts_InitFont loads FontDataStore with exactly 256*8 = 2048 bytes
' ============================================================================
SUB Test_InitFont_DataStoreSize
    CALL Test_Case("InitFont: FontDataStore holds 256 glyphs * 8 rows = 2048 bytes")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL Assert_IsEqual(LEN(FontDataStore), 2048, "FontDataStore length = 2048")
END SUB

' ============================================================================
' Test: Fonts_InitFont stores the file path in FontLoadPathStore
' ============================================================================
SUB Test_InitFont_StoresPath
    CALL Test_Case("InitFont: FontLoadPathStore records the font file path")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL Assert_AreEqualStr(FontLoadPathStore, "TEST.FNT", "FontLoadPathStore = TEST.FNT")
END SUB

' ============================================================================
' Test: Fonts_InitFont correctly decodes the row bytes
'   Row 1 of every glyph = 255 (all-foreground) -> CHR$(255) in FontDataStore
'   Row 2 of every glyph = 0   (all-background) -> CHR$(0)   in FontDataStore
' ============================================================================
SUB Test_InitFont_GlyphBytes
    CALL Test_Case("InitFont: glyph bytes decoded correctly from text file")
    DIM row1 AS INTEGER, row2 AS INTEGER
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    ' Char 65 'A': offset = 65*8+1 = 521
    row1 = ASC(MID$(FontDataStore, 65 * 8 + 1, 1))   ' should be 255
    row2 = ASC(MID$(FontDataStore, 65 * 8 + 2, 1))   ' should be 0
    CALL Assert_IsEqual(row1, 255, "glyph row1 = 255")
    CALL Assert_IsEqual(row2,   0, "glyph row2 = 0")
END SUB

' ============================================================================
' Test: Fonts_VgaPrint HappyPath - foreground pixels are drawn
'   Render a single 'A' (char 65) at (10,20) with foreColor=15, backColor=0,
'   flags=2 (draw background).  Row 1 = byte 255 = 11111111 -> all 8 pixels
'   on first row are foreground (15).  Row 2 = 0 -> all background (0).
' ============================================================================
SUB Test_VgaPrint_ForegroundPixels
    CALL Test_Case("VgaPrint: foreground pixels set for all-foreground glyph row")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL ClrScr(0)
    ' Act: render 'A' at (10,20) foreColor=15, backColor=0, flags=2
    DIM s AS STRING
    s = "A"
    CALL Fonts_VgaPrint(10, 20, 15, 0, s, 2)
    ' Assert: all 8 pixels in row 1 (y=20) are foreground
    CALL Assert_IsEqual(GetP(10, 20), 15, "row1 pixel x+0 = foreColor")
    CALL Assert_IsEqual(GetP(11, 20), 15, "row1 pixel x+1 = foreColor")
    CALL Assert_IsEqual(GetP(12, 20), 15, "row1 pixel x+2 = foreColor")
    CALL Assert_IsEqual(GetP(17, 20), 15, "row1 pixel x+7 = foreColor")
END SUB

' ============================================================================
' Test: Fonts_VgaPrint - background pixels drawn when flags=2
' ============================================================================
SUB Test_VgaPrint_BackgroundPixels
    CALL Test_Case("VgaPrint: background row pixels filled when flags AND 2")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    ' Arrange: fill screen with sentinel colour 7
    CALL ClrScr(7)
    DIM s AS STRING
    s = "A"
    ' Act: flags=2 -> background pixels use backColor=3
    CALL Fonts_VgaPrint(10, 20, 15, 3, s, 2)
    ' Row 2 = byte 0, all background: y=21, all 8 pixels must be backColor=3
    CALL Assert_IsEqual(GetP(10, 21), 3, "row2 pixel x+0 = backColor")
    CALL Assert_IsEqual(GetP(14, 21), 3, "row2 pixel x+4 = backColor")
    CALL Assert_IsEqual(GetP(17, 21), 3, "row2 pixel x+7 = backColor")
END SUB

' ============================================================================
' Test: Fonts_VgaPrint - background NOT drawn when flag 2 is clear
' ============================================================================
SUB Test_VgaPrint_NoBackground
    CALL Test_Case("VgaPrint: background pixels not drawn when flags AND 2 is clear")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL ClrScr(7)
    DIM s AS STRING
    s = "A"
    ' Act: flags=0 -> background rows must leave screen colour intact (7)
    CALL Fonts_VgaPrint(10, 20, 15, 3, s, 0)
    ' Row 2 = byte 0, no background draw: y=21, pixels stay as 7
    CALL Assert_IsEqual(GetP(10, 21), 7, "row2 pixel unchanged (no bg draw)")
    CALL Assert_IsEqual(GetP(14, 21), 7, "row2 pixel unchanged mid-row")
END SUB

' ============================================================================
' Test: Fonts_VgaPrint - two characters advance by CharWidth (8) pixels
' ============================================================================
SUB Test_VgaPrint_MultiChar_Advance
    CALL Test_Case("VgaPrint: second char starts at x+CharWidth")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL ClrScr(0)
    DIM s AS STRING
    s = "AA"
    CALL Fonts_VgaPrint(10, 20, 15, 0, s, 2)
    ' Second char starts at x+8=18, row1 at y=20 -> pixel(18,20)=15
    CALL Assert_IsEqual(GetP(10, 20), 15, "first char left pixel")
    CALL Assert_IsEqual(GetP(18, 20), 15, "second char starts at x+8")
    CALL Assert_IsEqual(GetP(25, 20), 15, "second char right pixel at x+15")
END SUB

' ============================================================================
' Test: Fonts_VgaPrint - empty string renders nothing
' ============================================================================
SUB Test_VgaPrint_EmptyString
    CALL Test_Case("VgaPrint: empty string leaves screen unchanged")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL ClrScr(0)
    DIM s AS STRING
    s = ""
    CALL Fonts_VgaPrint(10, 20, 15, 0, s, 2)
    ' Screen must remain all-zero
    CALL Assert_IsEqual(GetP(10, 20), 0, "no pixels drawn for empty string")
    CALL Assert_IsEqual(GetP(17, 27), 0, "glyph box area still clear")
END SUB

' ============================================================================
' Test: Fonts_VgaPrint - flag 4 converts text col/row to pixel coordinates
'   col=2, row=2 -> pixel x=(2-1)*8=8, y=(2-1)*8=8
' ============================================================================
SUB Test_VgaPrint_TextCoordinates
    CALL Test_Case("VgaPrint: flag 4 converts text col/row to pixel x,y")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL ClrScr(0)
    DIM s AS STRING
    s = "A"
    ' col=2, row=2 -> pixel (8,8); row1=byte255 -> pixel(8,8)=foreColor
    CALL Fonts_VgaPrint(2, 2, 15, 0, s, 4)
    CALL Assert_IsEqual(GetP(8, 8), 15, "text-coord (2,2) maps to pixel (8,8)")
    CALL Assert_IsEqual(GetP(0, 0), 0, "(0,0) untouched -> text-coord not pixel 0")
END SUB

' ============================================================================
' Test: Fonts_VgaPrint - boundary: render at top-left corner (0,0)
' ============================================================================
SUB Test_VgaPrint_Boundary_TopLeft
    CALL Test_Case("VgaPrint: render at (0,0) stays within screen top-left")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL ClrScr(0)
    DIM s AS STRING
    s = "A"
    CALL Fonts_VgaPrint(0, 0, 15, 0, s, 2)
    CALL Assert_IsEqual(GetP(0, 0), 15, "top-left pixel = foreColor")
    CALL Assert_IsEqual(GetP(7, 0), 15, "rightmost pixel of row1")
    CALL Assert_IsEqual(GetP(0, 6), 15, "row7 (y+6) = byte255 -> foreColor")
END SUB

' ============================================================================
' Test: Fonts_VgaPrint - rendering two adjacent chars don't overlap
' ============================================================================
SUB Test_VgaPrint_NoGlyphOverlap
    CALL Test_Case("VgaPrint: glyph boxes don't overlap - space between chars")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL ClrScr(0)
    DIM s AS STRING
    s = "AA"
    CALL Fonts_VgaPrint(10, 20, 15, 5, s, 2)
    ' Pixel at x=18, y=20 is the first pixel of second char (foreground)
    ' Pixel at x=9, y=20 is just before first char -> stays 0
    CALL Assert_IsEqual(GetP(9,  20), 0,  "before first char unchanged")
    CALL Assert_IsEqual(GetP(18, 20), 15, "start of second char = foreground")
    CALL Assert_IsEqual(GetP(26, 20), 0,  "after second char unchanged")
END SUB

' ============================================================================
' Test: Fonts_BmpPrint routes pixels through DrawBmp_PutBmpPixel (Svga_PutPixel)
'   Since our Svga_PutPixel stub writes to VGA framebuffer, pixels are readable.
' ============================================================================
SUB Test_BmpPrint_Pixels
    CALL Test_Case("BmpPrint: renders glyph pixels to VGA (via stub chain)")
    CALL MakeFontFile("TEST.FNT")
    CALL Fonts_InitFont("TEST.FNT", 0)
    CALL ClrScr(0)
    DIM s AS STRING
    s = "A"
    CALL Fonts_BmpPrint(50, 80, 11, 0, s, 2)
    ' Row1 = byte 255 -> all foreground (11)
    CALL Assert_IsEqual(GetP(50, 80), 11, "BmpPrint row1 foreground pixel")
    CALL Assert_IsEqual(GetP(57, 80), 11, "BmpPrint row1 rightmost pixel")
    ' Row2 = byte 0 -> all background (0) with flags=2
    CALL Assert_IsEqual(GetP(50, 81), 0,  "BmpPrint row2 background pixel")
END SUB

' ============================================================================
' Lifecycle
' ============================================================================
SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
END SUB
SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB
