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
