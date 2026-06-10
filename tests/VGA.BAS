' =============================================================================
' VGA.TST - tests for VGA.SUB (mode 13h drawing primitives)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"

' --- test doubles for VGA.SUB's cross-module calls ---
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
SUB Svga_InitDispatchTable
END SUB

' --- typed helpers so cases can pass literals to the by-ref handlers ---
SUB PutP(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM xv AS WORD, yv AS WORD, cv AS BYTE
    xv = x : yv = y : cv = c
    CALL Vga_PutPixel(xv, yv, cv)
END SUB
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION
SUB ClrScr(BYVAL c AS BYTE)
    DIM cv AS BYTE
    cv = c
    CALL Vga_ClearScreen(cv)
END SUB

SUB Test_PutGet_HappyPath
    CALL Test_Case("PutPixel/GetPixel happy path")
    DIM got AS INTEGER                       ' Arrange
    CALL PutP(160, 100, 42)                  ' Act
    got = GetP(160, 100)
    CALL Assert_IsEqual(got, 42, "centre pixel round-trips")   ' Assert
END SUB

SUB Test_PutGet_Boundary
    CALL Test_Case("PutPixel/GetPixel boundaries")
    CALL PutP(0, 0, 7)
    CALL Assert_IsEqual(GetP(0, 0), 7, "top-left (0,0)")
    CALL PutP(319, 199, 13)
    CALL Assert_IsEqual(GetP(319, 199), 13, "bottom-right (319,199)")
END SUB

SUB Test_PutGet_AllColors
    CALL Test_Case("PutPixel preserves all 256 colour values")
    DIM i AS INTEGER, c AS BYTE
    FOR i = 0 TO 255
        c = i
        CALL PutP(i, 5, c)
    NEXT i
    DIM bad AS INTEGER
    bad = 0
    FOR i = 0 TO 255
        IF GetP(i, 5) <> i THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "all 256 colours round-trip")
END SUB

SUB Test_ClearScreen_HappyPath
    CALL Test_Case("ClearScreen fills the screen")
    CALL ClrScr(99)
    CALL Assert_IsEqual(GetP(0, 0), 99, "corner cleared to 99")
    CALL Assert_IsEqual(GetP(319, 199), 99, "far corner cleared to 99")
    CALL Assert_IsEqual(GetP(160, 100), 99, "centre cleared to 99")
END SUB

SUB Test_HLine_HappyPath
    CALL Test_Case("HLine draws the run, leaves neighbours")
    DIM a AS WORD, b AS WORD, yy AS WORD, cc AS BYTE
    CALL ClrScr(0)
    a = 10 : b = 20 : yy = 30 : cc = 5
    CALL Vga_HLine(a, b, yy, cc)
    CALL Assert_IsEqual(GetP(10, 30), 5, "left end")
    CALL Assert_IsEqual(GetP(15, 30), 5, "middle")
    CALL Assert_IsEqual(GetP(20, 30), 5, "right end")
    CALL Assert_IsEqual(GetP(9, 30), 0, "no bleed left")
    CALL Assert_IsEqual(GetP(21, 30), 0, "no bleed right")
END SUB

SUB Test_HLine_SwapAndSingle
    CALL Test_Case("HLine reversed endpoints + single pixel")
    DIM a AS WORD, b AS WORD, yy AS WORD, cc AS BYTE
    CALL ClrScr(0)
    a = 40 : b = 30 : yy = 50 : cc = 6       ' x1 > x2 -> must swap
    CALL Vga_HLine(a, b, yy, cc)
    CALL Assert_IsEqual(GetP(35, 50), 6, "reversed range still drawn")
    a = 70 : b = 70 : yy = 50 : cc = 8       ' single pixel
    CALL Vga_HLine(a, b, yy, cc)
    CALL Assert_IsEqual(GetP(70, 50), 8, "single-pixel hline")
END SUB

SUB Test_VLine_HappyPath
    CALL Test_Case("VLine draws a column")
    DIM x AS WORD, y1 AS WORD, y2 AS WORD, cc AS BYTE
    CALL ClrScr(0)
    x = 80 : y1 = 20 : y2 = 28 : cc = 4
    CALL Vga_VLine(x, y1, y2, cc)
    CALL Assert_IsEqual(GetP(80, 20), 4, "top end")
    CALL Assert_IsEqual(GetP(80, 24), 4, "middle")
    CALL Assert_IsEqual(GetP(80, 28), 4, "bottom end")
    CALL Assert_IsEqual(GetP(80, 19), 0, "no bleed above")
    CALL Assert_IsEqual(GetP(81, 24), 0, "no bleed sideways")
END SUB

SUB Test_FillRect_HappyAndDegenerate
    CALL Test_Case("FillRect fills interior incl. 1x1")
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE
    CALL ClrScr(0)
    a = 100 : b = 60 : cc = 105 : d = 65 : e = 3
    CALL Vga_FillRect(a, b, cc, d, e)
    CALL Assert_IsEqual(GetP(100, 60), 3, "top-left of rect")
    CALL Assert_IsEqual(GetP(105, 65), 3, "bottom-right of rect")
    CALL Assert_IsEqual(GetP(102, 62), 3, "interior")
    CALL Assert_IsEqual(GetP(99, 60), 0, "no bleed")
    a = 120 : b = 70 : cc = 120 : d = 70 : e = 9   ' degenerate 1x1
    CALL Vga_FillRect(a, b, cc, d, e)
    CALL Assert_IsEqual(GetP(120, 70), 9, "1x1 fillrect")
END SUB

SUB Test_DrawRect_Outline
    CALL Test_Case("DrawRect draws edges, hollow centre")
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE
    CALL ClrScr(0)
    a = 130 : b = 80 : cc = 140 : d = 88 : e = 2
    CALL Vga_DrawRect(a, b, cc, d, e)
    CALL Assert_IsEqual(GetP(135, 80), 2, "top edge")
    CALL Assert_IsEqual(GetP(135, 88), 2, "bottom edge")
    CALL Assert_IsEqual(GetP(130, 84), 2, "left edge")
    CALL Assert_IsEqual(GetP(140, 84), 2, "right edge")
    CALL Assert_IsEqual(GetP(135, 84), 0, "hollow centre")
END SUB

SUB Test_LineDraw_Diagonal
    CALL Test_Case("LineDraw 45-degree diagonal")
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE, i AS INTEGER, bad AS INTEGER
    CALL ClrScr(0)
    a = 200 : b = 100 : cc = 210 : d = 110 : e = 11
    CALL Vga_LineDraw(a, b, cc, d, e)
    bad = 0
    FOR i = 0 TO 10
        IF GetP(200 + i, 100 + i) <> 11 THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "all 11 diagonal pixels set")
END SUB

SUB Test_PatternFill_SingleByte
    CALL Test_Case("PatternFill with 1-byte pattern fills uniformly")
    DIM p AS STRING, a AS WORD, b AS WORD, cc AS WORD, d AS WORD
    CALL ClrScr(0)
    p = CHR$(7)
    a = 10 : b = 40 : cc = 15 : d = 42
    CALL Vga_PatternFill(a, b, cc, d, p)
    CALL Assert_IsEqual(GetP(10, 40), 7, "top-left corner = pattern byte")
    CALL Assert_IsEqual(GetP(15, 42), 7, "bottom-right corner = pattern byte")
    CALL Assert_IsEqual(GetP(12, 41), 7, "interior = pattern byte")
    CALL Assert_IsEqual(GetP(9,  40), 0, "no bleed left")
    CALL Assert_IsEqual(GetP(16, 40), 0, "no bleed right")
END SUB

SUB Test_PatternFill_MultiBytePattern
    CALL Test_Case("PatternFill tiles a multi-byte pattern correctly")
    DIM p AS STRING, a AS WORD, b AS WORD, cc AS WORD, d AS WORD
    CALL ClrScr(0)
    ' Two-byte pattern: [3, 5, 3, 5, ...]
    p = CHR$(3) + CHR$(5)
    a = 20 : b = 80 : cc = 25 : d = 82
    CALL Vga_PatternFill(a, b, cc, d, p)
    ' x=20 -> pattern[0]=3, x=21 -> pattern[1]=5, x=22 -> pattern[0]=3
    CALL Assert_IsEqual(GetP(20, 80), 3, "col0 = pattern[0]")
    CALL Assert_IsEqual(GetP(21, 80), 5, "col1 = pattern[1]")
    CALL Assert_IsEqual(GetP(22, 80), 3, "col2 = pattern[0] (wrap)")
    CALL Assert_IsEqual(GetP(23, 80), 5, "col3 = pattern[1] (wrap)")
    ' Each row restarts pattern from index 0
    CALL Assert_IsEqual(GetP(20, 81), 3, "row1 col0 = pattern[0]")
    CALL Assert_IsEqual(GetP(21, 81), 5, "row1 col1 = pattern[1]")
END SUB

SUB Test_PatternFill_EmptyPatternDefault
    CALL Test_Case("PatternFill with empty string defaults to CHR$(0) fill")
    DIM p AS STRING, a AS WORD, b AS WORD, cc AS WORD, d AS WORD
    CALL ClrScr(99)
    p = ""
    a = 30 : b = 90 : cc = 35 : d = 92
    CALL Vga_PatternFill(a, b, cc, d, p)
    CALL Assert_IsEqual(GetP(30, 90), 0, "empty pattern -> CHR$(0) fill")
    CALL Assert_IsEqual(GetP(35, 92), 0, "corner also zero")
END SUB

SUB Test_Setup
!MOV AX, &H0013
!INT &H10
END SUB

SUB Test_Teardown
!MOV AX, &H0003
!INT &H10
END SUB
