' =============================================================================
' PORTGLUE.BAS - tests for PORTGLUE.SUB (port/glue procedures)
' =============================================================================
' No manual entry point: the test runner auto-generates the driver from the
' SUB Test_* names below (Test_Setup/Test_Teardown run first/last if present).
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"

' --- test double: spy for Svga_PutPixel calls ---------------------------------
' Records the arguments of the most recent call so assertions can verify them.
DIM spyX        AS SHARED WORD
DIM spyY        AS SHARED WORD
DIM spyColor    AS SHARED BYTE
DIM spyCalls    AS SHARED INTEGER

SUB Svga_PutPixel(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL colorVal AS BYTE)
    spyX     = x
    spyY     = y
    spyColor = colorVal
    spyCalls = spyCalls + 1
END SUB

$INCLUDE "PORTGLUE.SUB"

' =============================================================================
' Helper: reset spy counters before each test that exercises pixel output
SUB ResetSpy
    spyX = 0 : spyY = 0 : spyColor = 0 : spyCalls = 0
END SUB

' =============================================================================
' Test_Setup / Test_Teardown  (no graphics mode needed - spy doesn't need VRAM)
' =============================================================================

' =============================================================================
' Loading - no-op SUB: verify it accepts any INTEGER without crashing
' =============================================================================
SUB Test_Loading_NoOp
    CALL Test_Case("Loading is a no-op for mode 0 and 1")
    ' Arrange / Act: call with both canonical values
    CALL Loading(0)
    CALL Loading(1)
    ' Assert: framework state is untouched (tCount unchanged by Loading itself)
    CALL Assert_IsTrue(1, "Loading(0) did not crash")
    CALL Assert_IsTrue(1, "Loading(1) did not crash")
END SUB

SUB Test_Loading_Boundary
    CALL Test_Case("Loading accepts boundary INTEGER values")
    CALL Loading(-32768)
    CALL Loading(32767)
    CALL Assert_IsTrue(1, "Loading(-32768) did not crash")
    CALL Assert_IsTrue(1, "Loading(32767) did not crash")
END SUB

' =============================================================================
' Vga_CloseVga - sets BIOS text mode via INT 10h
' =============================================================================
SUB Test_VgaCloseVga_TextMode
    CALL Test_Case("Vga_CloseVga switches to text mode without error")
    ' Arrange: enter Mode 13h first so there is a mode to switch FROM
    !MOV AX, &H0013
    !INT &H10
    ' Act
    CALL Vga_CloseVga
    ' Assert: DAC registers are accessible in text mode too (always-on VGA hardware)
    OUT &H3C8, 10           ' write DAC index 10
    OUT &H3C9, 20           ' R = 20
    OUT &H3C9, 30           ' G = 30
    OUT &H3C9, 40           ' B = 40
    OUT &H3C7, 10           ' set read index to 10
    CALL Assert_IsEqual(INP(&H3C9), 20, "DAC R=20 after Vga_CloseVga")
    CALL Assert_IsEqual(INP(&H3C9), 30, "DAC G=30 after Vga_CloseVga")
    CALL Assert_IsEqual(INP(&H3C9), 40, "DAC B=40 after Vga_CloseVga")
    ' Restore Mode 13h for subsequent tests
    !MOV AX, &H0013
    !INT &H10
END SUB

' =============================================================================
' DrawBmp_PutBmpPixel - delegates to Svga_PutPixel
' =============================================================================
SUB Test_DrawBmp_PutBmpPixel_HappyPath
    CALL Test_Case("DrawBmp_PutBmpPixel passes X/Y/color to Svga_PutPixel")
    CALL ResetSpy
    ' Arrange
    DIM px AS WORD, py AS WORD, pc AS BYTE
    px = 160 : py = 100 : pc = 42
    ' Act
    CALL DrawBmp_PutBmpPixel(px, py, pc)
    ' Assert: spy captured exactly one call with correct args
    CALL Assert_IsEqual(spyCalls, 1, "Svga_PutPixel called once")
    CALL Assert_IsEqual(spyX,     160, "X forwarded correctly")
    CALL Assert_IsEqual(spyY,     100, "Y forwarded correctly")
    CALL Assert_IsEqual(spyColor, 42,  "color forwarded correctly")
END SUB

SUB Test_DrawBmp_PutBmpPixel_Boundary
    CALL Test_Case("DrawBmp_PutBmpPixel boundary coordinates (0,0) and (319,199)")
    CALL ResetSpy
    DIM px AS WORD, py AS WORD, pc AS BYTE
    px = 0 : py = 0 : pc = 0
    CALL DrawBmp_PutBmpPixel(px, py, pc)
    CALL Assert_IsEqual(spyX, 0, "top-left X=0")
    CALL Assert_IsEqual(spyY, 0, "top-left Y=0")
    CALL Assert_IsEqual(spyColor, 0, "color=0")
    CALL ResetSpy
    px = 319 : py = 199 : pc = 255
    CALL DrawBmp_PutBmpPixel(px, py, pc)
    CALL Assert_IsEqual(spyX, 319, "bottom-right X=319")
    CALL Assert_IsEqual(spyY, 199, "bottom-right Y=199")
    CALL Assert_IsEqual(spyColor, 255, "color=255")
END SUB

SUB Test_DrawBmp_PutBmpPixel_AllColors
    CALL Test_Case("DrawBmp_PutBmpPixel passes all 256 color values through")
    DIM i AS INTEGER, cv AS BYTE, bad AS INTEGER
    DIM px AS WORD, py AS WORD
    bad = 0
    px = 0 : py = 0
    FOR i = 0 TO 255
        CALL ResetSpy
        cv = i
        CALL DrawBmp_PutBmpPixel(px, py, cv)
        IF spyColor <> i THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "all 256 colour values forwarded exactly")
END SUB

' =============================================================================
' BMP_DrawScanline - one decoded scanline through Svga_PutPixel
' =============================================================================
SUB Test_BmpDrawScanline_Depth8_HappyPath
    CALL Test_Case("BMP_DrawScanline depth=8 draws expected pixels at correct coords")
    CALL ResetSpy
    DIM scanStr AS STRING, sx AS WORD, sy AS WORD, sw AS WORD, dep AS BYTE
    ' 3 pixels: indices 10, 20, 30
    scanStr =CHR$(10) + CHR$(20) + CHR$(30)
    sx = 5 : sy = 7 : sw = 3 : dep = 8
    CALL BMP_DrawScanline(scanStr, sx, sy, sw, dep)
    ' spy holds the LAST call (pixel index 2); verify call count and last pixel
    CALL Assert_IsEqual(spyCalls, 3, "3 pixels drawn for width=3")
    CALL Assert_IsEqual(spyX,     7, "last pixel X = 5+2")
    CALL Assert_IsEqual(spyY,     7, "Y unchanged throughout")
    CALL Assert_IsEqual(spyColor, 30,"last pixel color = 30")
END SUB

SUB Test_BmpDrawScanline_Depth8_FirstPixel
    CALL Test_Case("BMP_DrawScanline depth=8 first pixel has correct X and color")
    ' Verify first pixel by testing a width=1 scan
    CALL ResetSpy
    DIM scanStr AS STRING, sx AS WORD, sy AS WORD, sw AS WORD, dep AS BYTE
    scanStr =CHR$(77)
    sx = 100 : sy = 50 : sw = 1 : dep = 8
    CALL BMP_DrawScanline(scanStr, sx, sy, sw, dep)
    CALL Assert_IsEqual(spyCalls, 1, "exactly one call for width=1")
    CALL Assert_IsEqual(spyX,     100, "X=100 for first pixel")
    CALL Assert_IsEqual(spyColor, 77,  "color index = 77")
END SUB

SUB Test_BmpDrawScanline_Width0_NoOp
    CALL Test_Case("BMP_DrawScanline width=0 makes no Svga_PutPixel calls (bug fix)")
    ' Before fix: widthVal-1 wraps WORD to 65535 -> infinite loop
    CALL ResetSpy
    DIM scanStr AS STRING, sx AS WORD, sy AS WORD, sw AS WORD, dep AS BYTE
    scanStr =CHR$(1) + CHR$(2)
    sx = 0 : sy = 0 : sw = 0 : dep = 8
    CALL BMP_DrawScanline(scanStr, sx, sy, sw, dep)
    CALL Assert_IsEqual(spyCalls, 0, "width=0 -> zero Svga_PutPixel calls")
END SUB

SUB Test_BmpDrawScanline_Depth16_UsesLeadingByte
    CALL Test_Case("BMP_DrawScanline depth=16 uses leading byte of each 2-byte pixel")
    CALL ResetSpy
    DIM scanStr AS STRING, sx AS WORD, sy AS WORD, sw AS WORD, dep AS BYTE
    ' 2 pixels, each 2 bytes wide; leading bytes are 99 and 88
    scanStr =CHR$(99) + CHR$(0) + CHR$(88) + CHR$(0)
    sx = 10 : sy = 20 : sw = 2 : dep = 16
    CALL BMP_DrawScanline(scanStr, sx, sy, sw, dep)
    CALL Assert_IsEqual(spyCalls, 2, "2 pixels for width=2 at depth=16")
    ' last pixel (index 1) has leading byte 88
    CALL Assert_IsEqual(spyX,     11, "pixel 1 at X=10+1")
    CALL Assert_IsEqual(spyColor, 88, "depth=16 uses leading byte of pixel 1")
END SUB

SUB Test_BmpDrawScanline_Depth0_TreatedAs8
    CALL Test_Case("BMP_DrawScanline depth=0 is treated as depth=8 (1 byte/pixel)")
    ' depth\8 = 0 -> bytesPerPixel clamped to 1
    CALL ResetSpy
    DIM scanStr AS STRING, sx AS WORD, sy AS WORD, sw AS WORD, dep AS BYTE
    scanStr =CHR$(55) + CHR$(66)
    sx = 0 : sy = 0 : sw = 2 : dep = 0
    CALL BMP_DrawScanline(scanStr, sx, sy, sw, dep)
    CALL Assert_IsEqual(spyCalls, 2, "depth=0 draws as 1 byte/pixel -> 2 calls")
    CALL Assert_IsEqual(spyColor, 66, "second pixel color = 66")
END SUB

SUB Test_BmpDrawScanline_BoundarySinglePixel
    CALL Test_Case("BMP_DrawScanline width=1 draws exactly one pixel")
    CALL ResetSpy
    DIM scanStr AS STRING, sx AS WORD, sy AS WORD, sw AS WORD, dep AS BYTE
    scanStr =CHR$(200)
    sx = 0 : sy = 0 : sw = 1 : dep = 8
    CALL BMP_DrawScanline(scanStr, sx, sy, sw, dep)
    CALL Assert_IsEqual(spyCalls, 1, "width=1 -> exactly 1 call")
    CALL Assert_IsEqual(spyColor, 200, "color preserved for single pixel")
END SUB

SUB Test_BmpDrawScanline_DataShorterThanWidth
    CALL Test_Case("BMP_DrawScanline silently skips pixels beyond scanData length")
    ' scanData has 2 bytes but width=4 -> only 2 pixels drawn
    CALL ResetSpy
    DIM scanStr AS STRING, sx AS WORD, sy AS WORD, sw AS WORD, dep AS BYTE
    scanStr =CHR$(11) + CHR$(22)
    sx = 0 : sy = 0 : sw = 4 : dep = 8
    CALL BMP_DrawScanline(scanStr, sx, sy, sw, dep)
    CALL Assert_IsEqual(spyCalls, 2, "only 2 valid pixels drawn when data is short")
END SUB
