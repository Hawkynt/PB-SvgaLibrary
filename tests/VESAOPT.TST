' =============================================================================
' VESAOPT.TST - tests for VESAOPT.SUB (width-specialized VESA fast paths)
' =============================================================================
' Svga_WireVesaOptimized wires width-specific primitives (320/640/800/1024/1280)
' into SVGADispatch with the offset inlined and bank switches precomputed. Each
' width is set in a real mode (320 -> 13h, others -> VBE 0x101/3/5/7) and a
' full-height VLine, a full-width HLine across a 64k bank boundary, and the far
' corner are round-tripped through the dispatch table.
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VESAOPT.SUB"

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
    DIM a AS WORD, b AS WORD, yy AS WORD, c AS BYTE, got AS BYTE, i AS INTEGER, xs AS WORD, yc AS WORD, bad AS INTEGER
    pp = SVGADispatch.PutPixel : gp = SVGADispatch.GetPixel
    hp = SVGADispatch.HLine : vp = SVGADispatch.VLine

    ' full-height vertical line at x = wid\2 (multi-bank run for the wide modes)
    CALL TCase(nm + ": full-height VLine (inlined offset + bank runs)")
    a = wid \ 2 : b = 0 : yy = hgt - 1 : c = 9
    CALL DWORD vp BDECL (a, b, yy, c)
    bad = 0
    FOR i = 0 TO hgt - 1
        a = wid \ 2 : b = i : got = 0
        CALL DWORD gp BDECL (a, b, got)
        IF got <> 9 THEN bad = bad + 1
    NEXT i
    CALL TChkEq(bad, 0, "every scanline of the column reads back")

    ' full-width horizontal line on the row straddling the first 64k boundary
    CALL TCase(nm + ": full-width HLine across the 64k bank boundary")
    yc = 65536 \ wid
    IF yc >= hgt THEN yc = hgt \ 2
    a = 0 : b = wid - 1 : c = 13
    CALL DWORD hp BDECL (a, b, yc, c)
    bad = 0
    FOR i = 0 TO 4
        xs = i * (wid \ 4)
        IF xs > wid - 1 THEN xs = wid - 1
        b = yc : got = 0
        CALL DWORD gp BDECL (xs, b, got)
        IF got <> 13 THEN bad = bad + 1
    NEXT i
    CALL TChkEq(bad, 0, "5 sample points along the span read back")

    ' far corner round-trip
    CALL TCase(nm + ": far-corner pixel round-trip")
    a = wid - 1 : b = hgt - 1 : c = 6
    CALL DWORD pp BDECL (a, b, c)
    a = wid - 1 : b = hgt - 1 : got = 0
    CALL DWORD gp BDECL (a, b, got)
    CALL TChkEq(got, 6, "bottom-right pixel")
END SUB

' === entry point ===
CALL TBeginSuite("VESAOPT")
!MOV AX, &H0013
!INT &H10
CALL CheckWidth(320, 200, "320 (mode 13h)")
!MOV AX, &H4F02
!MOV BX, &H0101
!INT &H10
CALL CheckWidth(640, 480, "640 (VBE 0x101)")
!MOV AX, &H4F02
!MOV BX, &H0103
!INT &H10
CALL CheckWidth(800, 600, "800 (VBE 0x103)")
!MOV AX, &H4F02
!MOV BX, &H0105
!INT &H10
CALL CheckWidth(1024, 768, "1024 (VBE 0x105)")
!MOV AX, &H4F02
!MOV BX, &H0107
!INT &H10
CALL CheckWidth(1280, 1024, "1280 (VBE 0x107)")
!MOV AX, &H0003
!INT &H10
CALL TEndSuite("VESAOPT")
END
