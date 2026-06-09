' =============================================================================
' test_modetext.bas - unit tests for the text-mode half-block framebuffer
' =============================================================================
' Given an 80x50 text mode driven as an 80x100 pixel framebuffer,
' When two pixels share a cell (even y = top/FG, odd y = bottom/BG),
' Then they hold independent colours; and spans/round-trips work via dispatch.
' =============================================================================
$INCLUDE "TYPES.SUB"
$INCLUDE "MODETEXT.SUB"

DIM fail AS SHARED INTEGER
fail = 0

SUB DispPut(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM p AS DWORD, xv AS WORD, yv AS WORD, cv AS BYTE
    xv = x : yv = y : cv = c : p = SVGADispatch.PutPixel
    CALL DWORD p BDECL (xv, yv, cv)
END SUB
FUNCTION DispGet(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
    DIM p AS DWORD, xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0 : p = SVGADispatch.GetPixel
    CALL DWORD p BDECL (xv, yv, r)
    DispGet = r
END FUNCTION

OPEN "UNITTEST.LOG" FOR OUTPUT AS #1
PRINT #1, "=== text-mode half-block framebuffer (80x100) ==="
CALL ModeText_SetMode(50)

DIM i AS INTEGER
DIM hp AS DWORD, vp AS DWORD, rp AS DWORD, a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE

' top (even y) and bottom (odd y) of the SAME cell are independent
CALL DispPut(5, 0, 3)
CALL DispPut(5, 1, 9)
IF DispGet(5, 0) <> 3 THEN PRINT #1, "FAILED top half" : fail = 1
IF DispGet(5, 1) <> 9 THEN PRINT #1, "FAILED bottom half" : fail = 1

' every colour round-trips on the top half
FOR i = 0 TO 15
    CALL DispPut(i + 10, 2, i)
NEXT i
FOR i = 0 TO 15
    IF DispGet(i + 10, 2) <> i THEN PRINT #1, "FAILED colour "; i : fail = 1
NEXT i

' HLine
hp = SVGADispatch.HLine
a = 20 : b = 30 : cc = 10 : e = 4
CALL DWORD hp BDECL (a, b, cc, e)
FOR i = 20 TO 30
    IF DispGet(i, 10) <> 4 THEN PRINT #1, "FAILED hline x="; i : fail = 1
NEXT i
IF DispGet(19, 10) = 4 THEN PRINT #1, "FAILED hline bleed" : fail = 1

' VLine spanning several cells (odd+even rows)
vp = SVGADispatch.VLine
a = 40 : b = 11 : cc = 19 : e = 7
CALL DWORD vp BDECL (a, b, cc, e)
FOR i = 11 TO 19
    IF DispGet(40, i) <> 7 THEN PRINT #1, "FAILED vline y="; i : fail = 1
NEXT i

' FillRect
rp = SVGADispatch.FillRect
a = 50 : b = 20 : cc = 60 : d = 25 : e = 6
CALL DWORD rp BDECL (a, b, cc, d, e)
DIM jx AS INTEGER, jy AS INTEGER
FOR jy = 20 TO 25
    FOR jx = 50 TO 60
        IF DispGet(jx, jy) <> 6 THEN PRINT #1, "FAILED fillrect "; jx; ","; jy : fail = 1
    NEXT jx
NEXT jy

' bottom-right pixel of an 80x100 framebuffer
CALL DispPut(79, 99, 12)
IF DispGet(79, 99) <> 12 THEN PRINT #1, "FAILED corner" : fail = 1

!MOV AX, &H0003
!INT &H10
IF fail = 0 THEN PRINT #1, "ALL TESTS PASSED" ELSE PRINT #1, "SOME TESTS FAILED"
CLOSE #1
END

SUB Svga_InitDispatchTable
    SVGADispatch.PutPixel = CODEPTR32(ModeText_PutPixel)
    SVGADispatch.GetPixel = CODEPTR32(ModeText_GetPixel)
    SVGADispatch.HLine = CODEPTR32(ModeText_HLine)
    SVGADispatch.VLine = CODEPTR32(ModeText_VLine)
    SVGADispatch.LineDraw = CODEPTR32(ModeText_LineDraw)
    SVGADispatch.FillRect = CODEPTR32(ModeText_FillRect)
    SVGADispatch.DrawRect = CODEPTR32(ModeText_DrawRect)
    SVGADispatch.ClearScreen = CODEPTR32(ModeText_ClearScreen)
END SUB
