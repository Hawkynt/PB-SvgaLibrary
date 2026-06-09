' =============================================================================
' test_vesa_widths.bas - unit tests for the width-specialized VESA fast paths
' =============================================================================
' Given each common width set in a real mode (320 -> mode 13h, 640/800/1024/1280
' -> VBE 0x101/0x103/0x105/0x107), wired via Svga_WireVesaOptimized,
' When a full-height VLine, a wide HLine and a corner pixel are dispatched,
' Then every pixel reads back - exercising the inlined offset, the loop-free
' HLine (with its one bank switch) and the VLine fast-path / multi-bank runs.
' Provides the fixed Memory_SetVesaWindow locally.
' =============================================================================
$INCLUDE "TYPES.SUB"
$INCLUDE "VESAOPT.SUB"

DIM fail AS SHARED INTEGER
fail = 0

SUB Memory_SetVesaWindow(BYVAL windowNumber AS WORD)
    !MOV AX, &H4F05
    !XOR BX, BX
    !MOV DX, windowNumber
    !INT &H10
    VESASystemContext.VWnd = windowNumber
END SUB

SUB CheckWidth(BYVAL wid AS WORD, BYVAL hgt AS WORD, nm AS STRING)
    SVGAScreenContext.XRes = wid
    SVGAScreenContext.BytesPerLine = wid
    VESASystemContext.VWnd = 0
    CALL Svga_WireVesaOptimized
    DIM pp AS DWORD, gp AS DWORD, hp AS DWORD, vp AS DWORD
    DIM a AS WORD, b AS WORD, yy AS WORD, c AS BYTE, got AS BYTE, i AS INTEGER, xs AS WORD, yc AS WORD
    pp = SVGADispatch.PutPixel : gp = SVGADispatch.GetPixel
    hp = SVGADispatch.HLine : vp = SVGADispatch.VLine

    ' full-height vertical line at x = wid\2 (single-bank fast path for 320, multi-bank otherwise)
    a = wid \ 2 : b = 0 : yy = hgt - 1 : c = 9
    CALL DWORD vp BDECL (a, b, yy, c)
    FOR i = 0 TO hgt - 1
        a = wid \ 2 : b = i : got = 0
        CALL DWORD gp BDECL (a, b, got)
        IF got <> 9 THEN PRINT #1, "FAILED "; nm; " vline y="; i : fail = 1
    NEXT i

    ' full-width horizontal line on the row where the first 64k boundary falls
    yc = 65536 \ wid
    IF yc >= hgt THEN yc = hgt \ 2
    a = 0 : b = wid - 1 : c = 13
    CALL DWORD hp BDECL (a, b, yc, c)
    FOR i = 0 TO 4
        xs = i * (wid \ 4)
        IF xs > wid - 1 THEN xs = wid - 1
        b = yc : got = 0
        CALL DWORD gp BDECL (xs, b, got)
        IF got <> 13 THEN PRINT #1, "FAILED "; nm; " hline x="; xs : fail = 1
    NEXT i

    ' far corner round-trip
    a = wid - 1 : b = hgt - 1 : c = 6
    CALL DWORD pp BDECL (a, b, c)
    a = wid - 1 : b = hgt - 1 : got = 0
    CALL DWORD gp BDECL (a, b, got)
    IF got <> 6 THEN PRINT #1, "FAILED "; nm; " corner" : fail = 1

    PRINT #1, "PASS "; nm
END SUB

OPEN "UNITTEST.LOG" FOR OUTPUT AS #1
PRINT #1, "=== VESA per-width fast paths (round-trip in real modes) ==="

' 320-wide 256-colour is mode 13h (single 64k bank; offset = y*320 + x)
!MOV AX, &H0013
!INT &H10
CALL CheckWidth(320, 200, "320 (mode 13h)")

!MOV AX, &H4F02
!MOV BX, &H0101
!INT &H10
CALL CheckWidth(640, 480, "640 (0x101)")

!MOV AX, &H4F02
!MOV BX, &H0103
!INT &H10
CALL CheckWidth(800, 600, "800 (0x103)")

!MOV AX, &H4F02
!MOV BX, &H0105
!INT &H10
CALL CheckWidth(1024, 768, "1024 (0x105)")

!MOV AX, &H4F02
!MOV BX, &H0107
!INT &H10
CALL CheckWidth(1280, 1024, "1280 (0x107)")

!MOV AX, &H0003
!INT &H10
IF fail = 0 THEN PRINT #1, "ALL TESTS PASSED" ELSE PRINT #1, "SOME TESTS FAILED"
CLOSE #1
END
