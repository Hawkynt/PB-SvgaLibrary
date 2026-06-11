$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

%MAP_W   = 62
%MAP_H   = 12
%TILE    = 16
%VIEW_W  = 20
%VIEW_H  = 12
%SCR_W   = 320
%HUD_Y   = 192
%FP_ONE  = 256
%GRAV    = 18
%JV      = -700
%WSPD    = 160
%TE = 0 : %TS = 1 : %TP = 2 : %TC = 3 : %TEN = 4 : %TPL = 5 : %TF = 6

' ---- all module-level variables declared first --------------------------------
DIM sMode   AS INTEGER
DIM gRun    AS INTEGER
DIM frm     AS INTEGER
DIM mdat(743) AS BYTE
DIM camX    AS INTEGER
DIM pX      AS LONG
DIM pY      AS LONG
DIM pVX     AS LONG
DIM pVY     AS LONG
DIM pGnd    AS INTEGER
DIM pFace   AS INTEGER
DIM pLive   AS INTEGER
DIM pScore  AS INTEGER
DIM eX(1)   AS LONG
DIM eY(1)   AS LONG
DIM eVX(1)  AS LONG
DIM eOn(1)  AS INTEGER
DIM cgone(743) AS BYTE
DIM stim    AS INTEGER
DIM ccnt    AS INTEGER
' main-loop temps
DIM actv    AS INTEGER
DIM plpx    AS INTEGER
DIM mcam    AS INTEGER
DIM mk      AS STRING
' setup temps
DIM pi      AS INTEGER
DIM fh      AS INTEGER
DIM sr      AS INTEGER
DIM sc      AS INTEGER
DIM idx     AS INTEGER
DIM ln      AS STRING
DIM ch      AS STRING
DIM ei      AS INTEGER

' ---- harness ----------------------------------------------------------------
CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)
RANDOMIZE 42

sMode = 0
IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN sMode = 1

' ---- palette ----------------------------------------------------------------
FOR pi = 0 TO 15
    CALL Svga_SetPalette(16 + pi, pi, 20 + pi * 2, 38 + pi)
NEXT pi
CALL Svga_SetPalette(32, 20, 12, 4)
CALL Svga_SetPalette(33, 30, 20, 6)
CALL Svga_SetPalette(34, 28, 18, 8)
CALL Svga_SetPalette(35, 40, 28, 10)
CALL Svga_SetPalette(36, 50, 42, 0)
CALL Svga_SetPalette(37, 63, 55, 8)
CALL Svga_SetPalette(38, 0, 50, 8)
CALL Svga_SetPalette(39, 32, 32, 32)
CALL Svga_SetPalette(48, 0, 20, 50)
CALL Svga_SetPalette(49, 55, 35, 20)
CALL Svga_SetPalette(50, 8, 8, 30)
CALL Svga_SetPalette(52, 50, 8, 4)
CALL Svga_SetPalette(53, 35, 3, 2)
CALL Svga_SetPalette(56, 4, 25, 4)
CALL Svga_SetPalette(57, 8, 35, 8)
CALL Svga_SetPalette(58, 8, 8, 8)
CALL Svga_SetPalette(59, 60, 60, 60)

' ---- font -------------------------------------------------------------------
CALL Fonts_InitFont("FONT8.TXT", 0)

' ---- load map ---------------------------------------------------------------
fh = FREEFILE
OPEN "LEVEL1.MAP" FOR INPUT AS #fh
FOR sr = 0 TO %MAP_H - 1
    IF EOF(fh) THEN
        ln = STRING$(%MAP_W, 35)
    ELSE
        LINE INPUT #fh, ln
    END IF
    FOR sc = 0 TO %MAP_W - 1
        idx = sr * %MAP_W + sc
        IF sc < LEN(ln) THEN
            ch = MID$(ln, sc + 1, 1)
        ELSE
            ch = "."
        END IF
        IF ch = "#" THEN
            mdat(idx) = %TS
        ELSEIF ch = "=" THEN
            mdat(idx) = %TP
        ELSEIF ch = "C" THEN
            mdat(idx) = %TC
        ELSEIF ch = "E" THEN
            mdat(idx) = %TEN
        ELSEIF ch = "P" THEN
            mdat(idx) = %TPL
            pX = CLNG(sc) * %TILE * %FP_ONE
            pY = CLNG(sr) * %TILE * %FP_ONE
        ELSEIF ch = "F" THEN
            mdat(idx) = %TF
        ELSE
            mdat(idx) = %TE
        END IF
    NEXT sc
NEXT sr
CLOSE #fh

' ---- place enemies ----------------------------------------------------------
ei = 0
FOR sr = 0 TO %MAP_H - 1
    FOR sc = 0 TO %MAP_W - 1
        idx = sr * %MAP_W + sc
        IF mdat(idx) = %TEN AND ei <= 1 THEN
            eX(ei) = CLNG(sc) * %TILE * %FP_ONE
            eY(ei) = CLNG(sr) * %TILE * %FP_ONE
            eVX(ei) = -80
            eOn(ei) = 1
            mdat(idx) = %TE
            ei = ei + 1
        END IF
    NEXT sc
NEXT sr

IF pX <= 0 THEN pX = CLNG(2) * %TILE * %FP_ONE
IF pY <= 0 THEN pY = CLNG(8) * %TILE * %FP_ONE
pVX = 0 : pVY = 0 : pGnd = 0 : pFace = 1
pLive = 3 : pScore = 0 : camX = 0

' ============================================================================
' MAIN LOOP
' ============================================================================
gRun = 1 : frm = 0 : stim = 0 : ccnt = 0

WHILE gRun = 1

    ' -- input ----------------------------------------------------------------
    actv = 0
    IF sMode = 1 THEN
        stim = stim + 1
        actv = 2
        IF (stim MOD 40) = 0 THEN actv = actv OR 4
    ELSE
        mk = INKEY$
        IF mk = CHR$(27) THEN actv = 8
        IF mk = CHR$(0) + CHR$(75) THEN actv = 1
        IF mk = CHR$(0) + CHR$(77) THEN actv = 2
        IF mk = " " OR mk = CHR$(0) + CHR$(72) THEN actv = 4
    END IF
    IF (actv AND 8) THEN gRun = 0

    ' -- physics player -------------------------------------------------------
    CALL DoPhys(actv)

    ' -- enemies --------------------------------------------------------------
    CALL DoEnemy()

    ' -- items ----------------------------------------------------------------
    CALL DoItems()

    ' -- camera ---------------------------------------------------------------
    plpx = pX \ %FP_ONE
    camX = plpx - (%VIEW_W * %TILE) \ 2
    IF camX < 0 THEN camX = 0
    mcam = (%MAP_W - %VIEW_W) * %TILE
    IF camX > mcam THEN camX = mcam

    ' -- render ---------------------------------------------------------------
    CALL DoRender()

    ' -- smoke exit -----------------------------------------------------------
    frm = frm + 1
    IF sMode = 1 THEN
        IF frm >= 200 THEN gRun = 0
        IF ccnt >= 1 AND frm >= 150 THEN gRun = 0
    END IF
WEND

' ============================================================================
' SHUTDOWN
' ============================================================================
CALL Vesa_Close(0)
IF sMode = 1 THEN
    OPEN "SMOKE.OK" FOR OUTPUT AS #1
    PRINT #1, "OK"
    CLOSE #1
END IF
END

' ============================================================================
' DoPhys: player physics with tile collision
' ============================================================================
SUB DoPhys(BYVAL actv AS INTEGER)
    DIM px AS INTEGER, py AS INTEGER
    DIM cL AS INTEGER, cR AS INTEGER, rT AS INTEGER, rB AS INTEGER
    DIM tfL AS INTEGER, tfR AS INTEGER
    DIM pb AS LONG, mpx AS LONG

    IF (actv AND 1) THEN pVX = -%WSPD : pFace = -1
    IF (actv AND 2) THEN pVX = %WSPD : pFace = 1
    IF NOT (actv AND 1) AND NOT (actv AND 2) THEN pVX = 0
    IF (actv AND 4) AND pGnd = 1 THEN pVY = %JV : pGnd = 0

    pVY = pVY + %GRAV
    IF pVY > 1024 THEN pVY = 1024

    pX = pX + pVX
    px = pX \ %FP_ONE
    py = pY \ %FP_ONE
    cL = px \ %TILE : cR = (px + 11) \ %TILE
    rT = py \ %TILE : rB = (py + 15) \ %TILE

    IF pVX > 0 THEN
        IF TAt(cR, rT) = %TS OR TAt(cR, rB) = %TS THEN
            pX = CLNG(cR * %TILE - 12) * %FP_ONE : pVX = 0
        END IF
    ELSEIF pVX < 0 THEN
        IF TAt(cL, rT) = %TS OR TAt(cL, rB) = %TS THEN
            pX = CLNG((cL + 1) * %TILE) * %FP_ONE : pVX = 0
        END IF
    END IF

    pY = pY + pVY
    px = pX \ %FP_ONE
    py = pY \ %FP_ONE
    cL = px \ %TILE : cR = (px + 11) \ %TILE
    rT = py \ %TILE : rB = (py + 15) \ %TILE

    pGnd = 0
    IF pVY > 0 THEN
        tfL = TAt(cL, rB) : tfR = TAt(cR, rB)
        IF tfL = %TS OR tfR = %TS THEN
            pY = CLNG(rB * %TILE - 16) * %FP_ONE : pVY = 0 : pGnd = 1
        ELSEIF tfL = %TP OR tfR = %TP THEN
            pb = (pY - pVY) \ %FP_ONE + 15
            IF pb <= CLNG(rB * %TILE) THEN
                pY = CLNG(rB * %TILE - 16) * %FP_ONE : pVY = 0 : pGnd = 1
            END IF
        END IF
    ELSEIF pVY < 0 THEN
        IF TAt(cL, rT) = %TS OR TAt(cR, rT) = %TS THEN
            pY = CLNG((rT + 1) * %TILE) * %FP_ONE : pVY = 0
        END IF
    END IF

    IF pX < 0 THEN pX = 0 : pVX = 0
    mpx = CLNG(%MAP_W * %TILE - 12) * %FP_ONE
    IF pX > mpx THEN pX = mpx : pVX = 0

    IF (pY \ %FP_ONE) > %MAP_H * %TILE + 32 THEN
        pLive = pLive - 1
        IF pLive <= 0 THEN pLive = 3 : pScore = 0
        pX = CLNG(2) * %TILE * %FP_ONE
        pY = CLNG(8) * %TILE * %FP_ONE
        pVX = 0 : pVY = 0
    END IF
END SUB

' ============================================================================
' TAt: tile type with boundary clamping
' ============================================================================
FUNCTION TAt(BYVAL tc AS INTEGER, BYVAL tr AS INTEGER) AS INTEGER
    IF tc < 0 OR tc >= %MAP_W THEN TAt = %TS : EXIT FUNCTION
    IF tr < 0 THEN TAt = %TE : EXIT FUNCTION
    IF tr >= %MAP_H THEN TAt = %TS : EXIT FUNCTION
    TAt = mdat(tr * %MAP_W + tc)
END FUNCTION

' ============================================================================
' DoEnemy: enemy patrol, gravity, reversal, player contact
' ============================================================================
SUB DoEnemy()
    DIM i AS INTEGER
    DIM ex AS INTEGER, ey AS INTEGER
    DIM fb AS INTEGER, ft AS INTEGER
    DIM wc AS INTEGER, nc AS INTEGER, nf AS INTEGER
    DIM dx AS INTEGER, dy AS INTEGER

    FOR i = 0 TO 1
        IF eOn(i) = 1 THEN
            eX(i) = eX(i) + eVX(i)
            eY(i) = eY(i) + CLNG(%GRAV) * 2
            ex = eX(i) \ %FP_ONE
            ey = eY(i) \ %FP_ONE

            fb = (ey + 15) \ %TILE
            ft = TAt(ex \ %TILE, fb)
            IF ft = %TS OR ft = %TP THEN
                eY(i) = CLNG(fb * %TILE - 16) * %FP_ONE
                ey = eY(i) \ %FP_ONE
            END IF

            IF eVX(i) > 0 THEN wc = (ex + 15) \ %TILE ELSE wc = ex \ %TILE
            IF TAt(wc, ey \ %TILE) = %TS THEN eVX(i) = -eVX(i)

            IF eVX(i) > 0 THEN
                nc = (ex + 16) \ %TILE
            ELSE
                nc = (ex - 1) \ %TILE
                IF nc < 0 THEN nc = 0
            END IF
            nf = (ey + 17) \ %TILE
            IF TAt(nc, nf) <> %TS AND TAt(nc, nf) <> %TP THEN
                eVX(i) = -eVX(i)
            END IF

            dx = ABS((pX \ %FP_ONE) - ex)
            dy = ABS((pY \ %FP_ONE) - ey)
            IF dx < 14 AND dy < 14 THEN
                eOn(i) = 0
                pLive = pLive - 1
                IF pLive <= 0 THEN pLive = 3 : pScore = 0
            END IF
        END IF
    NEXT i
END SUB

' ============================================================================
' DoItems: collect coins and reach flag
' ============================================================================
SUB DoItems()
    DIM cpx AS INTEGER, cpy AS INTEGER
    DIM tc AS INTEGER, tr AS INTEGER, ii AS INTEGER

    cpx = (pX \ %FP_ONE) + 6
    cpy = (pY \ %FP_ONE) + 8
    tc = cpx \ %TILE : tr = cpy \ %TILE
    IF tc < 0 OR tc >= %MAP_W THEN EXIT SUB
    IF tr < 0 OR tr >= %MAP_H THEN EXIT SUB
    ii = tr * %MAP_W + tc
    IF mdat(ii) = %TC AND cgone(ii) = 0 THEN
        cgone(ii) = 1 : pScore = pScore + 100 : ccnt = ccnt + 1
    END IF
    IF mdat(ii) = %TF THEN pScore = pScore + 1000
END SUB

' ============================================================================
' DoRender: all rendering for one frame
' ============================================================================
SUB DoRender()
    DIM tsc AS INTEGER, tmc AS INTEGER, tro AS INTEGER, tco AS INTEGER
    DIM tt AS INTEGER, tidx AS INTEGER
    DIM tpx AS INTEGER, tpy AS INTEGER, tdx AS INTEGER
    DIM tsx AS WORD, tsy AS WORD, tex AS WORD, tey AS WORD, tcl AS BYTE
    DIM tcx AS INTEGER, tcy AS INTEGER, tfx AS INTEGER
    DIM i AS INTEGER, lx AS INTEGER
    DIM ex AS INTEGER, ey AS INTEGER
    DIM exx AS WORD, eyy AS WORD
    DIM px AS INTEGER, py AS INTEGER
    DIM hof1 AS INTEGER, hof2 AS INTEGER
    DIM hx AS INTEGER, hy AS INTEGER, hbh AS INTEGER
    DIM hsx AS WORD, hsy AS WORD, hex AS WORD, hey AS WORD
    DIM s AS STRING
    DIM fx AS WORD, fy AS WORD, ff AS BYTE, fb AS BYTE, fl AS BYTE

    ' -- sky gradient (8 bands) -----------------------------------------------
    hsx = 0 : hex = 319
    hsy = 0 : hey = 23 : tcl = 16
    CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)
    hsy = 24 : hey = 47 : tcl = 18
    CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)
    hsy = 48 : hey = 71 : tcl = 20
    CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)
    hsy = 72 : hey = 95 : tcl = 22
    CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)
    hsy = 96 : hey = 119 : tcl = 24
    CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)
    hsy = 120 : hey = 143 : tcl = 26
    CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)
    hsy = 144 : hey = 167 : tcl = 28
    CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)
    hsy = 168 : hey = 191 : tcl = 30
    CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)

    ' -- parallax hills layer 1 (far) -----------------------------------------
    hof1 = ((camX \ 4) MOD 80 + 80) MOD 80
    FOR hx = 0 TO 319 STEP 4
        hy = ((hx + hof1) MOD 80 + 80) MOD 80
        IF hy < 40 THEN hbh = hy * 12 \ 40 ELSE hbh = (80 - hy) * 12 \ 40
        hsy = 100 - hbh
        IF hsy < 0 THEN hsy = 0
        hsx = hx : hey = 118
        hex = hx + 3 : IF hex > 319 THEN hex = 319
        tcl = 56
        CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)
    NEXT hx

    ' -- parallax hills layer 2 (near) ----------------------------------------
    hof2 = ((camX \ 2) MOD 80 + 80) MOD 80
    FOR hx = 0 TO 319 STEP 4
        hy = ((hx + hof2) MOD 80 + 80) MOD 80
        IF hy < 40 THEN hbh = hy * 10 \ 40 ELSE hbh = (80 - hy) * 10 \ 40
        hsy = 110 - hbh
        IF hsy < 0 THEN hsy = 0
        hsx = hx : hey = 128
        hex = hx + 3 : IF hex > 319 THEN hex = 319
        tcl = 57
        CALL Svga_FillRect(hsx, hsy, hex, hey, tcl)
    NEXT hx

    ' -- tiles ----------------------------------------------------------------
    tsc = camX \ %TILE
    FOR tro = 0 TO %VIEW_H - 1
        FOR tco = 0 TO %VIEW_W + 1
            tmc = tsc + tco
            IF tmc >= 0 AND tmc < %MAP_W THEN
                tidx = tro * %MAP_W + tmc
                tt = mdat(tidx)
                IF tt = %TC AND cgone(tidx) = 1 THEN tt = %TE
                IF tt <> %TE THEN
                    tpx = tmc * %TILE - camX
                    tpy = tro * %TILE
                    IF tpx > -16 AND tpx < %SCR_W THEN
                        IF tpy >= 0 AND tpy < %HUD_Y THEN
                            tdx = tpx
                            IF tdx < 0 THEN tdx = 0
                            IF tt = %TS THEN
                                tsx = tdx : tsy = tpy
                                tex = tpx + 15
                                IF tex > 319 THEN tex = 319
                                tey = tpy + 15 : tcl = 32
                                CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
                                tey = tpy + 2 : tcl = 33
                                CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
                            ELSEIF tt = %TP THEN
                                tsx = tdx : tsy = tpy + 12
                                tex = tpx + 15
                                IF tex > 319 THEN tex = 319
                                tey = tpy + 15 : tcl = 34
                                CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
                                tey = tpy + 13 : tcl = 35
                                CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
                            ELSEIF tt = %TC THEN
                                tcx = tpx + 5 : tcy = tpy + 4
                                IF tcx >= 0 AND tcx < 315 THEN
                                    IF tcy >= 0 AND tcy < %HUD_Y THEN
                                        tsx = tcx : tsy = tcy
                                        tex = tcx + 5 : tey = tcy + 7
                                        IF tex > 319 THEN tex = 319
                                        tcl = 36
                                        CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
                                        tsx = tcx + 1 : tsy = tcy + 1
                                        tex = tcx + 4 : tey = tcy + 6
                                        tcl = 37
                                        CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
                                    END IF
                                END IF
                            ELSEIF tt = %TF THEN
                                tfx = tpx + 8
                                IF tfx >= 0 AND tfx < 319 THEN
                                    tsx = tfx : tsy = tpy : tex = tfx : tey = tpy + 15
                                    tcl = 39
                                    CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
                                    tex = tfx + 6
                                    IF tex < 320 THEN
                                        tey = tpy + 5 : tcl = 38
                                        CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
                                    END IF
                                END IF
                            END IF
                        END IF
                    END IF
                END IF
            END IF
        NEXT tco
    NEXT tro

    ' -- enemies --------------------------------------------------------------
    FOR i = 0 TO 1
        IF eOn(i) = 1 THEN
            ex = (eX(i) \ %FP_ONE) - camX
            ey = eY(i) \ %FP_ONE
            IF ex > -16 AND ex < 320 AND ey >= 0 AND ey < %HUD_Y THEN
                lx = ex + 1
                IF lx >= 0 AND lx < 320 THEN
                    tsx = lx : tsy = ey + 4 : exx = ex + 14 : eyy = ey + 13
                    IF exx > 319 THEN exx = 319
                    tcl = 52
                    CALL Svga_FillRect(tsx, tsy, exx, eyy, tcl)
                END IF
                lx = ex + 3
                IF lx >= 0 AND lx < 320 THEN
                    tsx = lx : tsy = ey : exx = ex + 12 : eyy = ey + 5
                    IF exx > 319 THEN exx = 319
                    tcl = 53
                    CALL Svga_FillRect(tsx, tsy, exx, eyy, tcl)
                END IF
            END IF
        END IF
    NEXT i

    ' -- player ---------------------------------------------------------------
    px = (pX \ %FP_ONE) - camX
    py = pY \ %FP_ONE
    IF px > -16 AND px < 320 AND py >= 0 AND py < %HUD_Y THEN
        lx = px + 3
        IF lx >= 0 AND lx < 320 AND py >= 0 THEN
            tsx = lx : tsy = py : tex = px + 12 : tey = py + 6
            IF tex > 319 THEN tex = 319
            tcl = 49
            CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
        END IF
        lx = px + 2
        IF lx >= 0 AND lx < 320 THEN
            tsx = lx : tex = px + 13
            IF tex > 319 THEN tex = 319
            tsy = py + 5 : tey = py + 11 : tcl = 48
            IF tsy < %HUD_Y THEN CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
        END IF
        lx = px + 2
        IF lx >= 0 AND lx < 320 THEN
            tsx = lx : tex = px + 6
            IF tex > 319 THEN tex = 319
            tsy = py + 12 : tey = py + 15 : tcl = 50
            IF tsy < %HUD_Y THEN CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
        END IF
        lx = px + 7
        IF lx >= 0 AND lx < 320 THEN
            tsx = lx : tex = px + 12
            IF tex > 319 THEN tex = 319
            tsy = py + 12 : tey = py + 15 : tcl = 50
            IF tsy < %HUD_Y THEN CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
        END IF
    END IF

    ' -- HUD ------------------------------------------------------------------
    tsx = 0 : tsy = %HUD_Y : tex = 319 : tey = 199 : tcl = 58
    CALL Svga_FillRect(tsx, tsy, tex, tey, tcl)
    s = "SCORE:" + STR$(pScore)
    fx = 4 : fy = 193 : ff = 59 : fb = 58 : fl = 0
    CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)
    s = "LIVES:" + STR$(pLive)
    fx = 160 : fy = 193 : ff = 37 : fb = 58 : fl = 0
    CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)
END SUB
