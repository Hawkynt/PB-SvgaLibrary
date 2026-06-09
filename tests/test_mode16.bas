' =============================================================================
' test_mode16.bas - unit tests for the 800x600 16-colour bit-planed mode
' =============================================================================
' Given mode 0x102 (800x600, 4 bit-planes),
' When pixels/spans are dispatched through SVGADispatch,
' Then each colour (0..15) round-trips, adjacent bits in a byte stay
' independent, byte-crossing spans fill exactly, and the far corner works.
' =============================================================================
$INCLUDE "TYPES.SUB"
$INCLUDE "MODE16.SUB"

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
PRINT #1, "=== Mode 800x600x16 (bit-planed) ==="
CALL Mode16_SetMode

DIM i AS INTEGER, col AS BYTE
DIM hp AS DWORD, vp AS DWORD, rp AS DWORD
DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE

' PutPixel/GetPixel: 18 adjacent pixels (across byte boundaries), colours 1..15
FOR i = 0 TO 17
    col = (i AND 15) : IF col = 0 THEN col = 1
    CALL DispPut(i, 5, col)
NEXT i
FOR i = 0 TO 17
    col = (i AND 15) : IF col = 0 THEN col = 1
    IF DispGet(i, 5) <> col THEN PRINT #1, "FAILED putget x="; i : fail = 1
NEXT i

' HLine 10..25 @ y=20 colour 12 (crosses byte boundaries)
hp = SVGADispatch.HLine
a = 10 : b = 25 : cc = 20 : e = 12
CALL DWORD hp BDECL (a, b, cc, e)
FOR i = 10 TO 25
    IF DispGet(i, 20) <> 12 THEN PRINT #1, "FAILED hline x="; i : fail = 1
NEXT i
IF DispGet(9, 20) = 12 THEN PRINT #1, "FAILED hline bleed L" : fail = 1
IF DispGet(26, 20) = 12 THEN PRINT #1, "FAILED hline bleed R" : fail = 1

' VLine x=40, y 30..37 colour 7
vp = SVGADispatch.VLine
a = 40 : b = 30 : cc = 37 : e = 7
CALL DWORD vp BDECL (a, b, cc, e)
FOR i = 30 TO 37
    IF DispGet(40, i) <> 7 THEN PRINT #1, "FAILED vline y="; i : fail = 1
NEXT i

' FillRect (50,50)-(60,54) colour 3
rp = SVGADispatch.FillRect
a = 50 : b = 50 : cc = 60 : d = 54 : e = 3
CALL DWORD rp BDECL (a, b, cc, d, e)
DIM jx AS INTEGER, jy AS INTEGER
FOR jy = 50 TO 54
    FOR jx = 50 TO 60
        IF DispGet(jx, jy) <> 3 THEN PRINT #1, "FAILED fillrect "; jx; ","; jy : fail = 1
    NEXT jx
NEXT jy
IF DispGet(49, 52) = 3 THEN PRINT #1, "FAILED fillrect bleed" : fail = 1

' far corner
CALL DispPut(799, 599, 14)
IF DispGet(799, 599) <> 14 THEN PRINT #1, "FAILED corner" : fail = 1

!MOV AX, &H0003
!INT &H10
IF fail = 0 THEN PRINT #1, "ALL TESTS PASSED" ELSE PRINT #1, "SOME TESTS FAILED"
CLOSE #1
END

SUB Svga_InitDispatchTable
    SVGADispatch.PutPixel = CODEPTR32(Mode16_PutPixel)
    SVGADispatch.GetPixel = CODEPTR32(Mode16_GetPixel)
    SVGADispatch.HLine = CODEPTR32(Mode16_HLine)
    SVGADispatch.VLine = CODEPTR32(Mode16_VLine)
    SVGADispatch.LineDraw = CODEPTR32(Mode16_LineDraw)
    SVGADispatch.FillRect = CODEPTR32(Mode16_FillRect)
    SVGADispatch.DrawRect = CODEPTR32(Mode16_DrawRect)
    SVGADispatch.ClearScreen = CODEPTR32(Mode16_ClearScreen)
END SUB
