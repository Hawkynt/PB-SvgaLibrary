' =============================================================================
' VESAOPT.BAS - tests for VESAOPT.SUB (width-specialized VESA fast paths)
' =============================================================================
' Svga_WireVesaOptimized wires width-specific primitives (320/640/800/1024/
' 1280/1600) into SVGADispatch with the offset inlined and bank switches
' precomputed. Each width is set in a real mode (320 -> 13h, others -> VBE
' 0x101/3/5/7/11C) and a full-height VLine, a boundary-crossing HLine, the far
' corner, a FillRect batch around the 64k bank edge (incl. straddling rows and
' reversed corners) and an exact-shape FillCircle sweep are round-tripped
' through the dispatch table. 1600 is skipped honestly if the emulator lacks
' VBE mode 0x11C.
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VESAOPT.INC"

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
    CALL Test_Case(nm + ": full-height VLine (inlined offset + bank runs)")
    a = wid \ 2 : b = 0 : yy = hgt - 1 : c = 9
    CALL DWORD vp BDECL (a, b, yy, c)
    bad = 0
    FOR i = 0 TO hgt - 1
        a = wid \ 2 : b = i : got = 0
        CALL DWORD gp BDECL (a, b, got)
        IF got <> 9 THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "every scanline of the column reads back")

    ' full-width horizontal line on the row straddling the first 64k boundary
    CALL Test_Case(nm + ": full-width HLine across the 64k bank boundary")
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
    CALL Assert_IsEqual(bad, 0, "5 sample points along the span read back")

    ' far corner round-trip
    CALL Test_Case(nm + ": far-corner pixel round-trip")
    a = wid - 1 : b = hgt - 1 : c = 6
    CALL DWORD pp BDECL (a, b, c)
    a = wid - 1 : b = hgt - 1 : got = 0
    CALL DWORD gp BDECL (a, b, got)
    CALL Assert_IsEqual(got, 6, "bottom-right pixel")

    ' --- FillRect: batched rows around the 64k bank edge -------------------
    ' bx = the column where the boundary falls inside row yc, so the outer
    ' rect's rows exercise the straddle path AND the batched word-fill path.
    DIM rp AS DWORD, fcp AS DWORD, bx AS WORD
    DIM rx1 AS WORD, ry1 AS WORD, rx2 AS WORD, ry2 AS WORD
    DIM dxs AS INTEGER, dys AS INTEGER, inside AS INTEGER
    rp = SVGADispatch.FillRect : fcp = SVGADispatch.FillCircle
    bx = 65536 MOD wid
    IF bx < 24 OR bx > wid - 24 THEN bx = wid \ 2

    CALL Test_Case(nm + ": FillRect batches rows per bank (straddle + word fill)")
    rx1 = bx - 16 : ry1 = yc - 3 : rx2 = bx + 15 : ry2 = yc + 3 : c = 21
    CALL DWORD rp BDECL (rx1, ry1, rx2, ry2, c)         ' outer frame colour
    rx1 = bx - 10 : ry1 = yc - 2 : rx2 = bx + 8 : ry2 = yc + 2 : c = 22
    CALL DWORD rp BDECL (rx1, ry1, rx2, ry2, c)         ' inner: odd width 19
    bad = 0
    FOR dys = -2 TO 2
        FOR dxs = -10 TO 8
            a = bx + dxs : b = yc + dys : got = 0
            CALL DWORD gp BDECL (a, b, got)
            IF got <> 22 THEN bad = bad + 1
        NEXT dxs
    NEXT dys
    CALL Assert_IsEqual(bad, 0, "every inner-rect pixel reads back (95 px)")
    bad = 0
    a = bx - 16 : b = yc : got = 0 : CALL DWORD gp BDECL (a, b, got) : IF got <> 21 THEN bad = bad + 1
    a = bx + 15 : b = yc : got = 0 : CALL DWORD gp BDECL (a, b, got) : IF got <> 21 THEN bad = bad + 1
    a = bx : b = yc - 3 : got = 0 : CALL DWORD gp BDECL (a, b, got) : IF got <> 21 THEN bad = bad + 1
    a = bx : b = yc + 3 : got = 0 : CALL DWORD gp BDECL (a, b, got) : IF got <> 21 THEN bad = bad + 1
    CALL Assert_IsEqual(bad, 0, "the surrounding frame is not bled into")

    CALL Test_Case(nm + ": FillRect normalises reversed corners")
    rx1 = bx + 5 : ry1 = yc + 1 : rx2 = bx - 5 : ry2 = yc - 1 : c = 23
    CALL DWORD rp BDECL (rx1, ry1, rx2, ry2, c)         ' x2<x1, y2<y1
    a = bx : b = yc : got = 0
    CALL DWORD gp BDECL (a, b, got)
    CALL Assert_IsEqual(got, 23, "reversed-corner rect still fills")

    ' --- FillCircle: exact shape, swept across the bank edge ----------------
    CALL Test_Case(nm + ": FillCircle exact shape across the bank edge")
    rx1 = bx - 12 : ry1 = yc - 12 : rx2 = bx + 11 : ry2 = yc + 11 : c = 31
    CALL DWORD rp BDECL (rx1, ry1, rx2, ry2, c)         ' clean background pad
    a = bx : b = yc : yy = 8 : c = 32
    CALL DWORD fcp BDECL (a, b, yy, c)                  ' r = 8 at the boundary
    bad = 0
    FOR dys = -10 TO 10
        FOR dxs = -10 TO 10
            inside = 0
            IF dxs * dxs + dys * dys <= 64 THEN inside = 1
            a = bx + dxs : b = yc + dys : got = 0
            CALL DWORD gp BDECL (a, b, got)
            IF inside = 1 AND got <> 32 THEN bad = bad + 1
            IF inside = 0 AND got <> 31 THEN bad = bad + 1
        NEXT dxs
    NEXT dys
    CALL Assert_IsEqual(bad, 0, "all 441 pixels match dx^2+dy^2<=r^2 exactly")
END SUB

' === entry point ===
CALL Test_BeginSuite("VESAOPT")
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
' 1600x1200x8 (VBE 0x11C) needs a ~2MB adapter - probe the set-mode status and
' skip honestly where the emulator does not offer it
DIM st AS WORD
!MOV AX, &H4F02
!MOV BX, &H011C
!INT &H10
!MOV st, AX
IF st = &H4F THEN
    CALL CheckWidth(1600, 1200, "1600 (VBE 0x11C)")
ELSE
    CALL Test_Skip("1600 (VBE 0x11C): mode not available in this emulator")
END IF
!MOV AX, &H0003
!INT &H10
CALL Test_EndSuite("VESAOPT")
END
