' =============================================================================
' MODEX.TST - tests for MODEX.SUB (unchained planar Mode-X, 320x240x256)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "MODEX.SUB"

' MODEX.SUB collaborators that live in other units:
SUB Svga_InitDispatchTable
END SUB
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB

SUB PutP(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM xv AS WORD, yv AS WORD, cv AS BYTE
    xv = x : yv = y : cv = c
    CALL ModeX_PutPixel(xv, yv, cv)
END SUB
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL ModeX_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

SUB Test_PutGet_AcrossPlanes
    CALL TCase("PutPixel/GetPixel round-trips across all four planes")
    DIM i AS INTEGER, bad AS INTEGER
    FOR i = 0 TO 7 : CALL PutP(i, 10, 50 + i) : NEXT i   ' x%4 selects plane
    bad = 0
    FOR i = 0 TO 7 : IF GetP(i, 10) <> 50 + i THEN bad = bad + 1
    NEXT i
    CALL TChkEq(bad, 0, "8 adjacent pixels (all planes) round-trip")
END SUB

SUB Test_PutGet_Boundary
    CALL TCase("PutPixel/GetPixel at the Mode-X extents (320x240)")
    CALL PutP(0, 0, 11)
    CALL TChkEq(GetP(0, 0), 11, "top-left")
    CALL PutP(319, 239, 22)
    CALL TChkEq(GetP(319, 239), 22, "bottom-right (tall 240-line addressing)")
END SUB

SUB Test_HLine
    CALL TCase("HLine draws its run only")
    DIM a AS WORD, b AS WORD, yy AS WORD, cc AS BYTE
    a = 12 : b = 18 : yy = 20 : cc = 99
    CALL ModeX_HLine(a, b, yy, cc)
    CALL TChkEq(GetP(12, 20), 99, "left end")
    CALL TChkEq(GetP(18, 20), 99, "right end")
    CALL TChkEq(GetP(11, 20), 0, "no bleed left")
    CALL TChkEq(GetP(19, 20), 0, "no bleed right")
END SUB

SUB Test_VLine
    CALL TCase("VLine draws its column only")
    DIM x AS WORD, a AS WORD, b AS WORD, cc AS BYTE
    x = 25 : a = 30 : b = 36 : cc = 88
    CALL ModeX_VLine(x, a, b, cc)
    CALL TChkEq(GetP(25, 30), 88, "top end")
    CALL TChkEq(GetP(25, 36), 88, "bottom end")
    CALL TChkEq(GetP(25, 29), 0, "no bleed top")
    CALL TChkEq(GetP(25, 37), 0, "no bleed bottom")
END SUB

SUB Test_FillRect
    CALL TCase("FillRect fills its interior")
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE
    a = 40 : b = 40 : cc = 45 : d = 43 : e = 66
    CALL ModeX_FillRect(a, b, cc, d, e)
    CALL TChkEq(GetP(40, 40), 66, "corner")
    CALL TChkEq(GetP(45, 43), 66, "far corner")
    CALL TChkEq(GetP(42, 41), 66, "interior")
    CALL TChkEq(GetP(39, 41), 0, "no bleed")
END SUB

SUB Test_DrawRect
    CALL TCase("DrawRect outlines, hollow centre")
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE
    a = 70 : b = 70 : cc = 76 : d = 74 : e = 55
    CALL ModeX_DrawRect(a, b, cc, d, e)
    CALL TChkEq(GetP(73, 70), 55, "top edge")
    CALL TChkEq(GetP(73, 74), 55, "bottom edge")
    CALL TChkEq(GetP(73, 72), 0, "hollow centre")
END SUB

SUB Test_LineDraw
    CALL TCase("LineDraw 45-degree diagonal")
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE, i AS INTEGER, bad AS INTEGER
    a = 60 : b = 60 : cc = 66 : d = 66 : e = 77
    CALL ModeX_LineDraw(a, b, cc, d, e)
    bad = 0
    FOR i = 60 TO 66 : IF GetP(i, i) <> 77 THEN bad = bad + 1
    NEXT i
    CALL TChkEq(bad, 0, "all 7 diagonal pixels set")
END SUB

SUB Test_ClearScreen
    CALL TCase("ClearScreen floods all planes")
    DIM cc AS BYTE
    cc = 33
    CALL ModeX_ClearScreen(cc)
    CALL TChkEq(GetP(0, 0), 33, "corner cleared")
    CALL TChkEq(GetP(317, 200), 33, "interior cleared")
    CALL TChkEq(GetP(318, 239), 33, "far area cleared")
END SUB

' === entry point ===
CALL ModeX_InitTables
CALL ModeX_SetMode(0)              ' 0 = 320x240
CALL TBeginSuite("MODEX")
CALL Test_PutGet_AcrossPlanes
CALL Test_PutGet_Boundary
CALL Test_HLine
CALL Test_VLine
CALL Test_FillRect
CALL Test_DrawRect
CALL Test_LineDraw
CALL Test_ClearScreen
CALL TEndSuite("MODEX")
!MOV AX, &H0003
!INT &H10
END
