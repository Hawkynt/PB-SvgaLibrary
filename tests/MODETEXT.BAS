' =============================================================================
' MODETEXT.TST - tests for MODETEXT.SUB (fake graphics via text-mode half-blocks)
' =============================================================================
' 80x50 text mode renders a 80x100 pixel framebuffer: each character cell holds
' two stacked pixels using the upper-half-block glyph (top = even y / foreground,
' bottom = odd y / background).
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "MODETEXT.SUB"

SUB Svga_InitDispatchTable
END SUB

SUB PutP(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM xv AS WORD, yv AS WORD, cv AS BYTE
    xv = x : yv = y : cv = c
    CALL ModeText_PutPixel(xv, yv, cv)
END SUB
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL ModeText_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

SUB Test_HalfBlock_Independence
    CALL Test_Case("the two pixels in one cell are independent")
    CALL PutP(5, 0, 3)              ' top half (even y)
    CALL PutP(5, 1, 9)              ' bottom half (odd y), same cell
    CALL Assert_IsEqual(GetP(5, 0), 3, "top half holds its colour")
    CALL Assert_IsEqual(GetP(5, 1), 9, "bottom half holds a different colour")
END SUB

SUB Test_AllColors
    CALL Test_Case("every 0..15 colour round-trips")
    DIM i AS INTEGER, bad AS INTEGER
    FOR i = 0 TO 15 : CALL PutP(i + 10, 2, i) : NEXT i
    bad = 0
    FOR i = 0 TO 15 : IF GetP(i + 10, 2) <> i THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "colours 0..15 on the top half")
END SUB

SUB Test_HLine
    CALL Test_Case("HLine fills a row of cells")
    DIM a AS WORD, b AS WORD, yy AS WORD, e AS BYTE
    a = 20 : b = 30 : yy = 10 : e = 4
    CALL ModeText_HLine(a, b, yy, e)
    CALL Assert_IsEqual(GetP(20, 10), 4, "left end")
    CALL Assert_IsEqual(GetP(30, 10), 4, "right end")
    CALL Assert_IsEqual(GetP(19, 10), 0, "no bleed left")
END SUB

SUB Test_VLine_SpansCells
    CALL Test_Case("VLine spans odd+even rows across cells")
    DIM x AS WORD, a AS WORD, b AS WORD, e AS BYTE, i AS INTEGER, bad AS INTEGER
    x = 40 : a = 11 : b = 19 : e = 7
    CALL ModeText_VLine(x, a, b, e)
    bad = 0
    FOR i = 11 TO 19 : IF GetP(40, i) <> 7 THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "all 9 pixels (5 cells) set")
END SUB

SUB Test_FillRect
    CALL Test_Case("FillRect fills a block of cells")
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE
    a = 50 : b = 20 : cc = 60 : d = 25 : e = 6
    CALL ModeText_FillRect(a, b, cc, d, e)
    CALL Assert_IsEqual(GetP(50, 20), 6, "corner")
    CALL Assert_IsEqual(GetP(60, 25), 6, "far corner")
    CALL Assert_IsEqual(GetP(55, 22), 6, "interior")
    CALL Assert_IsEqual(GetP(49, 22), 0, "no bleed")
END SUB

SUB Test_Boundary
    CALL Test_Case("bottom-right of the 80x100 framebuffer")
    CALL PutP(79, 99, 13)
    CALL Assert_IsEqual(GetP(79, 99), 13, "last pixel addresses correctly")
END SUB

' === entry point ===
CALL ModeText_SetMode(50)          ' 80x50 text -> 80x100 pixels
CALL Test_BeginSuite("MODETEXT")
CALL Test_HalfBlock_Independence
CALL Test_AllColors
CALL Test_HLine
CALL Test_VLine_SpansCells
CALL Test_FillRect
CALL Test_Boundary
CALL Test_EndSuite("MODETEXT")
!MOV AX, &H0003
!INT &H10
END
