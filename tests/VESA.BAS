' =============================================================================
' VESA.TST - tests for VESA.SUB (generic banked linear-framebuffer primitives)
' =============================================================================
' Drives the arbitrary-width VESA primitives in a real VBE 640x480x256 mode
' (0x101), exercising bank switching across the 64k window boundary, plus the
' Vesa_GetMode resolution->mode lookup.
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VESA.SUB"

SUB Svga_InitDispatchTable
END SUB
SUB ModeX_SetFallback(BYVAL XRes AS WORD, BYVAL YRes AS WORD, BYVAL Colors AS WORD)
END SUB
SUB Memory_SetVesaWindow(BYVAL windowNumber AS WORD)
    !MOV AX, &H4F05
    !XOR BX, BX
    !MOV DX, windowNumber
    !INT &H10
    VESASystemContext.VWnd = windowNumber
END SUB

SUB EnterMode640
    !MOV AX, &H4F02
    !MOV BX, &H0101
    !INT &H10
    SVGAScreenContext.XRes = 640
    SVGAScreenContext.YRes = 480
    SVGAScreenContext.ColorDepth = 8
    SVGAScreenContext.BytesPerLine = 640
    SVGAScreenContext.WindowNumber = 0
    CALL Memory_SetVesaWindow(0)
END SUB

SUB PutP(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM xv AS WORD, yv AS WORD, cv AS BYTE
    xv = x : yv = y : cv = c
    CALL VESA_PutPixel(xv, yv, cv)
END SUB
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL VESA_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

SUB Test_PutGet_AcrossBank
    CALL Test_Case("PutPixel/GetPixel below and above the first 64k bank")
    CALL PutP(10, 10, 42)               ' bank 0 (offset 6410)
    CALL Assert_IsEqual(GetP(10, 10), 42, "low offset (bank 0)")
    CALL PutP(300, 200, 77)             ' offset 128300 -> bank 1
    CALL Assert_IsEqual(GetP(300, 200), 77, "high offset (bank 1)")
END SUB

SUB Test_PutGet_Corners
    CALL Test_Case("PutPixel/GetPixel at the screen corners")
    CALL PutP(0, 0, 5)
    CALL Assert_IsEqual(GetP(0, 0), 5, "top-left")
    CALL PutP(639, 479, 200)            ' offset 306959 -> bank 4
    CALL Assert_IsEqual(GetP(639, 479), 200, "bottom-right (bank 4)")
END SUB

SUB Test_HLine_AcrossBankBoundary
    CALL Test_Case("HLine spanning the row that straddles a 64k boundary")
    DIM a AS WORD, b AS WORD, yy AS WORD, e AS BYTE
    yy = 102 : a = 0 : b = 639 : e = 13   ' y*640 crosses 65536 at x=256
    CALL VESA_HLine(a, b, yy, e)
    CALL Assert_IsEqual(GetP(0, 102), 13, "before boundary")
    CALL Assert_IsEqual(GetP(255, 102), 13, "just before boundary")
    CALL Assert_IsEqual(GetP(256, 102), 13, "just after boundary")
    CALL Assert_IsEqual(GetP(639, 102), 13, "end of span")
END SUB

SUB Test_VLine
    CALL Test_Case("VLine fills a tall column across banks")
    DIM x AS WORD, a AS WORD, b AS WORD, e AS BYTE, i AS INTEGER, bad AS INTEGER
    x = 500 : a = 0 : b = 300 : e = 8
    CALL VESA_VLine(x, a, b, e)
    bad = 0
    FOR i = 0 TO 300 STEP 30 : IF GetP(500, i) <> 8 THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "sampled column pixels read back")
END SUB

SUB Test_FillRect
    CALL Test_Case("FillRect fills its interior")
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE
    a = 100 : b = 100 : cc = 130 : d = 120 : e = 6
    CALL VESA_FillRect(a, b, cc, d, e)
    CALL Assert_IsEqual(GetP(100, 100), 6, "corner")
    CALL Assert_IsEqual(GetP(130, 120), 6, "far corner")
    CALL Assert_IsEqual(GetP(115, 110), 6, "interior")
    CALL Assert_IsEqual(GetP(99, 100), 0, "no bleed")
END SUB

SUB Test_GetMode_Lookup
    CALL Test_Case("Vesa_GetMode maps 640x480x256 to a real VBE mode number")
    DIM m AS WORD
    m = Vesa_GetMode(640, 480, 256)
    CALL Assert_IsTrue(m <> 0, "a non-zero VBE mode is returned (regression: used to always return 0)")
    m = Vesa_GetMode(12345, 6789, 256)
    CALL Assert_IsEqual(m, 0, "an impossible resolution returns 0")
END SUB

' === entry point ===
CALL EnterMode640
CALL Test_BeginSuite("VESA")
CALL Test_PutGet_AcrossBank
CALL Test_PutGet_Corners
CALL Test_HLine_AcrossBankBoundary
CALL Test_VLine
CALL Test_FillRect
CALL Test_GetMode_Lookup
CALL Test_EndSuite("VESA")
!MOV AX, &H0003
!INT &H10
END
