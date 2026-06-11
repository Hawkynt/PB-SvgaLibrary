$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

%GRID_W = 26
%GRID_H = 14
%MAX_CARS = 32
%PATH_SZ  = 50
%BFS_SZ   = 300

' tile type, growth stage, congestion, road-access
DIM gT(363)  AS SHARED BYTE
DIM gS(363)  AS SHARED BYTE
DIM gC(363)  AS SHARED BYTE
DIM gA(363)  AS SHARED BYTE
' cars: active, grid-col, grid-row, path-length, path-step, delay
DIM caA(31)  AS SHARED BYTE
DIM caX(31)  AS SHARED INTEGER
DIM caY(31)  AS SHARED INTEGER
DIM caL(31)  AS SHARED INTEGER
DIM caP(31)  AS SHARED INTEGER
DIM caD(31)  AS SHARED INTEGER
' path cache [car*PATH_SZ + step] = col / row
DIM pBC(1599) AS SHARED BYTE
DIM pBR(1599) AS SHARED BYTE
' BFS work buffers
DIM bQC(299)  AS SHARED BYTE
DIM bQR(299)  AS SHARED BYTE
DIM bVs(363)  AS SHARED BYTE
DIM bPv(363)  AS SHARED INTEGER
' direction table (E W S N)
DIM bDx(3)   AS SHARED INTEGER
DIM bDy(3)   AS SHARED INTEGER
' global counters
DIM funds    AS SHARED LONG
DIM popul    AS SHARED LONG
DIM jbs      AS SHARED LONG
DIM frm      AS SHARED INTEGER
DIM nSpw     AS SHARED INTEGER
DIM nMov     AS SHARED INTEGER

CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)
RANDOMIZE 12345

DIM smk AS INTEGER
smk = 0
IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN smk = 1

DIM i AS INTEGER
FOR i = 0 TO 363
    gT(i) = 0 : gS(i) = 0 : gC(i) = 0 : gA(i) = 0
NEXT i
FOR i = 0 TO 31
    caA(i) = 0 : caP(i) = 0 : caL(i) = 0 : caD(i) = 0 : caX(i) = 0 : caY(i) = 0
NEXT i
FOR i = 0 TO 1599
    pBC(i) = 0 : pBR(i) = 0
NEXT i
FOR i = 0 TO 299
    bQC(i) = 0 : bQR(i) = 0
NEXT i
FOR i = 0 TO 363
    bVs(i) = 0 : bPv(i) = -1
NEXT i
bDx(0) =  1 : bDy(0) =  0
bDx(1) = -1 : bDy(1) =  0
bDx(2) =  0 : bDy(2) =  1
bDx(3) =  0 : bDy(3) = -1
funds = 5000 : popul = 0 : jbs = 0 : frm = 0 : nSpw = 0 : nMov = 0

' palette (6-bit components)
' 32=grass 33=grass speckle 34=road 35=lane dash
' 36-38=res stage 1-3  39=res no-road
' 40-42=com stage 1-3  43=com no-road
' 44=HUD bg  45=HUD text  46=cursor  47=mild cong  48=heavy cong
' 50-53=car colours
DIM pr AS BYTE, pg AS BYTE, pb2 AS BYTE
pr = 5  : pg = 22 : pb2 = 5  : CALL Svga_SetPalette(32, pr, pg, pb2)
pr = 8  : pg = 28 : pb2 = 8  : CALL Svga_SetPalette(33, pr, pg, pb2)
pr = 18 : pg = 18 : pb2 = 18 : CALL Svga_SetPalette(34, pr, pg, pb2)
pr = 42 : pg = 42 : pb2 = 42 : CALL Svga_SetPalette(35, pr, pg, pb2)
pr = 8  : pg = 38 : pb2 = 8  : CALL Svga_SetPalette(36, pr, pg, pb2)
pr = 4  : pg = 48 : pb2 = 4  : CALL Svga_SetPalette(37, pr, pg, pb2)
pr = 2  : pg = 58 : pb2 = 2  : CALL Svga_SetPalette(38, pr, pg, pb2)
pr = 14 : pg = 30 : pb2 = 14 : CALL Svga_SetPalette(39, pr, pg, pb2)
pr = 8  : pg = 8  : pb2 = 42 : CALL Svga_SetPalette(40, pr, pg, pb2)
pr = 4  : pg = 4  : pb2 = 52 : CALL Svga_SetPalette(41, pr, pg, pb2)
pr = 2  : pg = 2  : pb2 = 62 : CALL Svga_SetPalette(42, pr, pg, pb2)
pr = 14 : pg = 14 : pb2 = 30 : CALL Svga_SetPalette(43, pr, pg, pb2)
pr = 8  : pg = 8  : pb2 = 8  : CALL Svga_SetPalette(44, pr, pg, pb2)
pr = 62 : pg = 62 : pb2 = 62 : CALL Svga_SetPalette(45, pr, pg, pb2)
pr = 62 : pg = 62 : pb2 = 0  : CALL Svga_SetPalette(46, pr, pg, pb2)
pr = 40 : pg = 22 : pb2 = 4  : CALL Svga_SetPalette(47, pr, pg, pb2)
pr = 48 : pg = 8  : pb2 = 4  : CALL Svga_SetPalette(48, pr, pg, pb2)
pr = 28 : pg = 22 : pb2 = 8  : CALL Svga_SetPalette(49, pr, pg, pb2)
pr = 62 : pg = 10 : pb2 = 10 : CALL Svga_SetPalette(50, pr, pg, pb2)
pr = 62 : pg = 62 : pb2 = 10 : CALL Svga_SetPalette(51, pr, pg, pb2)
pr = 10 : pg = 10 : pb2 = 62 : CALL Svga_SetPalette(52, pr, pg, pb2)
pr = 62 : pg = 10 : pb2 = 62 : CALL Svga_SetPalette(53, pr, pg, pb2)

DIM fh AS INTEGER, row AS INTEGER, col AS INTEGER, idx AS INTEGER
DIM ln AS STRING, ch AS STRING
fh = FREEFILE
OPEN "START.MAP" FOR INPUT AS #fh
FOR row = 0 TO %GRID_H - 1
    IF EOF(fh) THEN
        ln = STRING$(%GRID_W, ".")
    ELSE
        LINE INPUT #fh, ln
    END IF
    FOR col = 0 TO %GRID_W - 1
        idx = row * %GRID_W + col
        IF col < LEN(ln) THEN ch = MID$(ln, col + 1, 1) ELSE ch = "."
        IF ch = "R" THEN gT(idx) = 1
        IF ch = "H" THEN gT(idx) = 2 : gS(idx) = 1
        IF ch = "C" THEN gT(idx) = 3 : gS(idx) = 1
    NEXT col
NEXT row
CLOSE #fh

IF smk = 1 THEN
    CALL DoSmoke()
ELSE
    CALL DoPlay()
END IF
CALL Vesa_Close(0)
END

' =========================================================
FUNCTION Gi(BYVAL c AS INTEGER, BYVAL r AS INTEGER) AS INTEGER
    IF c < 0 OR c >= %GRID_W OR r < 0 OR r >= %GRID_H THEN
        Gi = -1
    ELSE
        Gi = r * %GRID_W + c
    END IF
END FUNCTION

' =========================================================
SUB CmpAcc()
    DIM r AS INTEGER, c AS INTEGER, ii AS INTEGER
    DIM n AS INTEGER, ha AS INTEGER
    FOR r = 0 TO %GRID_H - 1
        FOR c = 0 TO %GRID_W - 1
            ii = r * %GRID_W + c
            ha = 0
            IF gT(ii) = 2 OR gT(ii) = 3 THEN
                n = Gi(c, r - 1)
                IF n >= 0 THEN IF gT(n) = 1 THEN ha = 1
                IF ha = 0 THEN
                    n = Gi(c, r + 1)
                    IF n >= 0 THEN IF gT(n) = 1 THEN ha = 1
                END IF
                IF ha = 0 THEN
                    n = Gi(c - 1, r)
                    IF n >= 0 THEN IF gT(n) = 1 THEN ha = 1
                END IF
                IF ha = 0 THEN
                    n = Gi(c + 1, r)
                    IF n >= 0 THEN IF gT(n) = 1 THEN ha = 1
                END IF
            END IF
            gA(ii) = ha
        NEXT c
    NEXT r
END SUB

' =========================================================
FUNCTION CngPct() AS INTEGER
    DIM ii AS INTEGER, tot AS INTEGER, cng AS INTEGER
    tot = 0 : cng = 0
    FOR ii = 0 TO 363
        IF gT(ii) = 1 THEN
            tot = tot + 1
            IF gC(ii) > 2 THEN cng = cng + 1
        END IF
    NEXT ii
    IF tot = 0 THEN CngPct = 0 : EXIT FUNCTION
    CngPct = cng * 100 \ tot
END FUNCTION

' =========================================================
' BFS road graph from (sc,sr) to any commercial tile.
' Stores path steps in pBC/pBR[ci*PATH_SZ..].
' Returns step count, or 0 if unreachable.
FUNCTION BfsRun(BYVAL sc AS INTEGER, BYVAL sr AS INTEGER, _
                BYVAL ci AS INTEGER) AS INTEGER
    DIM head AS INTEGER, tail AS INTEGER
    DIM qc AS INTEGER, qr AS INTEGER
    DIM nc AS INTEGER, nr AS INTEGER
    DIM nidx AS INTEGER, cur AS INTEGER
    DIM d AS INTEGER, prev AS INTEGER
    DIM plen AS INTEGER, pb AS INTEGER
    DIM stp AS INTEGER, tidx AS INTEGER
    DIM stk(49) AS INTEGER

    tidx = Gi(sc, sr)
    IF tidx < 0 THEN BfsRun = 0 : EXIT FUNCTION
    IF gT(tidx) <> 1 THEN BfsRun = 0 : EXIT FUNCTION

    FOR cur = 0 TO 363
        bVs(cur) = 0 : bPv(cur) = -1
    NEXT cur

    head = 0 : tail = 0
    bQC(tail) = sc : bQR(tail) = sr
    tail = tail + 1
    bVs(tidx) = 1
    BfsRun = 0

    DO WHILE head < tail
        qc = bQC(head) : qr = bQR(head)
        head = head + 1
        cur = Gi(qc, qr)
        IF cur < 0 THEN
        ELSEIF gT(cur) = 3 THEN
            ' Commercial reached - trace back
            plen = 0 : prev = cur
            DO WHILE prev >= 0 AND plen < %PATH_SZ
                stk(plen) = prev
                plen = plen + 1
                prev = bPv(prev)
            LOOP
            IF plen >= 2 THEN
                pb = ci * %PATH_SZ
                ' write path forward: skip origin (index plen-1), stop at 0
                FOR stp = plen - 2 TO 0 STEP -1
                    IF pb - ci * %PATH_SZ < %PATH_SZ THEN
                        pBC(pb) = stk(stp) MOD %GRID_W
                        pBR(pb) = stk(stp) \ %GRID_W
                        pb = pb + 1
                    END IF
                NEXT stp
                BfsRun = pb - ci * %PATH_SZ
            END IF
            EXIT FUNCTION
        ELSE
            FOR d = 0 TO 3
                nc = qc + bDx(d) : nr = qr + bDy(d)
                nidx = Gi(nc, nr)
                IF nidx >= 0 THEN
                    IF bVs(nidx) = 0 THEN
                        IF gT(nidx) = 1 OR gT(nidx) = 3 THEN
                            bVs(nidx) = 1
                            bPv(nidx) = cur
                            IF tail < %BFS_SZ - 1 THEN
                                bQC(tail) = nc : bQR(tail) = nr
                                tail = tail + 1
                            END IF
                        END IF
                    END IF
                END IF
            NEXT d
        END IF
    LOOP
END FUNCTION

' =========================================================
SUB SpawnCars()
    DIM c AS INTEGER, r AS INTEGER, ii AS INTEGER
    DIM spRoll AS INTEGER, ci AS INTEGER, found AS INTEGER
    DIM rc AS INTEGER, rr AS INTEGER, rf AS INTEGER
    DIM nbr AS INTEGER, pl AS INTEGER, cri AS INTEGER

    FOR r = 0 TO %GRID_H - 1
        FOR c = 0 TO %GRID_W - 1
            ii = r * %GRID_W + c
            IF gT(ii) = 2 AND gS(ii) >= 1 AND gA(ii) = 1 THEN
                spRoll = INT(RND * 4)
                IF spRoll < 2 THEN
                    found = 0
                    FOR ci = 0 TO %MAX_CARS - 1
                        IF found = 0 AND caA(ci) = 0 THEN
                            rc = 0 : rr = 0 : rf = 0
                            nbr = Gi(c, r - 1)
                            IF nbr >= 0 AND rf = 0 THEN
                                IF gT(nbr) = 1 THEN rc = c : rr = r - 1 : rf = 1
                            END IF
                            nbr = Gi(c, r + 1)
                            IF nbr >= 0 AND rf = 0 THEN
                                IF gT(nbr) = 1 THEN rc = c : rr = r + 1 : rf = 1
                            END IF
                            nbr = Gi(c - 1, r)
                            IF nbr >= 0 AND rf = 0 THEN
                                IF gT(nbr) = 1 THEN rc = c - 1 : rr = r : rf = 1
                            END IF
                            nbr = Gi(c + 1, r)
                            IF nbr >= 0 AND rf = 0 THEN
                                IF gT(nbr) = 1 THEN rc = c + 1 : rr = r : rf = 1
                            END IF
                            IF rf = 1 THEN
                                pl = BfsRun(rc, rr, ci)
                                IF pl > 0 THEN
                                    caA(ci) = 1
                                    caX(ci) = rc : caY(ci) = rr
                                    caL(ci) = pl : caP(ci) = 0 : caD(ci) = 0
                                    nSpw = nSpw + 1
                                    cri = Gi(rc, rr)
                                    IF cri >= 0 THEN
                                        IF gC(cri) < 10 THEN gC(cri) = gC(cri) + 1
                                    END IF
                                    found = 1
                                END IF
                            END IF
                            found = 1
                        END IF
                    NEXT ci
                END IF
            END IF
        NEXT c
    NEXT r
END SUB

' =========================================================
SUB MoveCar(BYVAL ci AS INTEGER)
    DIM ct AS INTEGER, pb AS INTEGER
    DIM nx AS INTEGER, ny AS INTEGER, nt AS INTEGER

    ct = Gi(caX(ci), caY(ci))
    IF ct >= 0 THEN
        IF gC(ct) > 2 THEN
            caD(ci) = caD(ci) + 1
            IF (caD(ci) MOD 2) = 1 THEN EXIT SUB
        END IF
    END IF

    IF caP(ci) < caL(ci) THEN
        pb = ci * %PATH_SZ + caP(ci)
        nx = pBC(pb) : ny = pBR(pb)
        IF ct >= 0 THEN
            IF gC(ct) > 0 THEN gC(ct) = gC(ct) - 1
        END IF
        caX(ci) = nx : caY(ci) = ny
        caP(ci) = caP(ci) + 1
        nMov = nMov + 1
        nt = Gi(nx, ny)
        IF nt >= 0 THEN
            IF gC(nt) < 10 THEN gC(nt) = gC(nt) + 1
        END IF
    ELSE
        IF ct >= 0 THEN
            IF gC(ct) > 0 THEN gC(ct) = gC(ct) - 1
        END IF
        caA(ci) = 0
    END IF
END SUB

' =========================================================
SUB DoTick()
    DIM c AS INTEGER, r AS INTEGER, ii AS INTEGER, cp AS INTEGER
    DIM sv AS INTEGER, gr AS INTEGER, sv2 AS INTEGER, gr2 AS INTEGER
    DIM ci AS INTEGER

    CALL CmpAcc()
    cp = CngPct()
    FOR ii = 0 TO 363
        IF gC(ii) > 0 THEN gC(ii) = gC(ii) - 1
    NEXT ii
    popul = 0 : jbs = 0
    FOR r = 0 TO %GRID_H - 1
        FOR c = 0 TO %GRID_W - 1
            ii = r * %GRID_W + c
            IF gT(ii) = 2 AND gA(ii) = 1 THEN
                sv = gS(ii)
                popul = popul + sv * 10
                IF sv < 3 AND cp < 60 THEN
                    gr = INT(RND * 20)
                    IF gr = 0 THEN gS(ii) = sv + 1
                END IF
            END IF
            IF gT(ii) = 3 AND gA(ii) = 1 THEN
                sv2 = gS(ii)
                jbs = jbs + sv2 * 8
                IF sv2 < 3 AND cp < 70 THEN
                    gr2 = INT(RND * 22)
                    IF gr2 = 0 THEN gS(ii) = sv2 + 1
                END IF
            END IF
        NEXT c
    NEXT r
    funds = funds + (popul \ 20) + (jbs \ 30)
    CALL SpawnCars()
    FOR ci = 0 TO %MAX_CARS - 1
        IF caA(ci) = 1 THEN CALL MoveCar(ci)
    NEXT ci
END SUB

' =========================================================
SUB DrawMap()
    DIM c AS INTEGER, r AS INTEGER, ii AS INTEGER
    DIM px AS WORD, py AS WORD, p2 AS WORD, q2 AS WORD, cl AS BYTE
    DIM ci AS INTEGER, cpx AS WORD, cpy AS WORD

    FOR r = 0 TO %GRID_H - 1
        FOR c = 0 TO %GRID_W - 1
            ii = r * %GRID_W + c
            px = c * 12 : py = 14 + r * 12
            p2 = px + 11 : q2 = py + 11
            cl = 32
            IF gT(ii) = 1 THEN
                cl = 34
                IF gC(ii) > 4 THEN cl = 48
                IF gC(ii) > 2 AND gC(ii) <= 4 THEN cl = 47
            ELSEIF gT(ii) = 2 THEN
                IF gA(ii) = 1 THEN
                    cl = 35 + gS(ii)
                ELSE
                    cl = 49
                END IF
            ELSEIF gT(ii) = 3 THEN
                IF gA(ii) = 1 THEN
                    cl = 39 + gS(ii)
                ELSE
                    cl = 49
                END IF
            END IF
            CALL Svga_FillRect(px, py, p2, q2, cl)
        NEXT c
    NEXT r

    FOR ci = 0 TO %MAX_CARS - 1
        IF caA(ci) = 1 THEN
            cpx = caX(ci) * 12 + 4
            cpy = 14 + caY(ci) * 12 + 5
            cl = 50 + (ci MOD 4)
            CALL Svga_FillRect(cpx, cpy, cpx + 2, cpy + 1, cl)
        END IF
    NEXT ci
END SUB

' =========================================================
SUB PlaceTile(BYVAL cX AS INTEGER, BYVAL cY AS INTEGER, BYVAL tool AS INTEGER)
    DIM ii AS INTEGER
    ii = Gi(cX, cY)
    IF ii < 0 THEN EXIT SUB
    IF tool = 1 THEN
        IF funds >= 10 AND gT(ii) <> 1 THEN
            gT(ii) = 1 : gS(ii) = 0 : funds = funds - 10
        END IF
    ELSEIF tool = 2 THEN
        IF funds >= 100 AND gT(ii) = 0 THEN
            gT(ii) = 2 : gS(ii) = 1 : funds = funds - 100
        END IF
    ELSEIF tool = 3 THEN
        IF funds >= 100 AND gT(ii) = 0 THEN
            gT(ii) = 3 : gS(ii) = 1 : funds = funds - 100
        END IF
    ELSE
        gT(ii) = 0 : gS(ii) = 0
    END IF
END SUB

' =========================================================
' Smoke-test run: scripted build + 250 sim frames + validation
SUB DoSmoke()
    DIM sfr AS INTEGER

    CALL Fonts_InitFont("FONT8.TXT", 0)

    ' Connect existing residential zones to commercial via new roads and zones
    CALL PlaceTile(3,  2, 1)
    CALL PlaceTile(4,  2, 1)
    CALL PlaceTile(5,  2, 1)
    CALL PlaceTile(9,  1, 3)
    CALL PlaceTile(14, 1, 3)
    CALL PlaceTile(15, 1, 1)
    CALL PlaceTile(16, 1, 1)
    CALL PlaceTile(17, 1, 1)
    CALL PlaceTile(18, 1, 1)
    CALL PlaceTile(19, 1, 1)
    CALL PlaceTile(20, 1, 1)
    CALL PlaceTile(21, 1, 3)
    CALL PlaceTile(22, 1, 1)
    CALL PlaceTile(23, 1, 1)
    CALL PlaceTile(23, 2, 3)
    CALL PlaceTile(1,  3, 1)
    CALL PlaceTile(1,  4, 1)
    CALL PlaceTile(0,  3, 3)
    CALL PlaceTile(0,  5, 1)
    CALL PlaceTile(0,  6, 3)

    CALL CmpAcc()

    FOR sfr = 1 TO 250
        frm = frm + 1
        IF (frm MOD 15) = 0 THEN CALL DoTick()
        CALL DrawMap()
    NEXT sfr

    IF nSpw >= 3 AND nMov >= 3 THEN
        DIM smokeF AS INTEGER
        smokeF = FREEFILE
        OPEN "SMOKE.OK" FOR OUTPUT AS #smokeF
        PRINT #smokeF, "OK spw=" + LTRIM$(STR$(nSpw)) + _
              " mov=" + LTRIM$(STR$(nMov)) + _
              " pop=" + LTRIM$(STR$(popul))
        CLOSE #smokeF
    END IF
END SUB

' =========================================================
SUB DoPlay()
    DIM goRun AS INTEGER, goPaus AS INTEGER
    DIM cX AS INTEGER, cY AS INTEGER, tool AS INTEGER
    DIM k AS STRING, s AS STRING
    DIM hcl AS BYTE, ff AS BYTE, fb AS BYTE, fl AS BYTE
    DIM fx AS WORD, fy AS WORD
    DIM cpx AS WORD, cpy AS WORD, ccl AS BYTE

    CALL Fonts_InitFont("FONT8.TXT", 0)
    goRun = 1 : goPaus = 0 : cX = 5 : cY = 5 : tool = 1

    DO WHILE goRun = 1
        k = INKEY$
        IF LEN(k) > 0 THEN
            IF k = CHR$(27) THEN
                goRun = 0
            ELSEIF k = CHR$(0) + CHR$(72) THEN
                IF cY > 0 THEN cY = cY - 1
            ELSEIF k = CHR$(0) + CHR$(80) THEN
                IF cY < %GRID_H - 1 THEN cY = cY + 1
            ELSEIF k = CHR$(0) + CHR$(75) THEN
                IF cX > 0 THEN cX = cX - 1
            ELSEIF k = CHR$(0) + CHR$(77) THEN
                IF cX < %GRID_W - 1 THEN cX = cX + 1
            ELSEIF k = " " THEN
                CALL PlaceTile(cX, cY, tool)
            ELSEIF k = "1" THEN
                tool = 1
            ELSEIF k = "2" THEN
                tool = 2
            ELSEIF k = "3" THEN
                tool = 3
            ELSEIF k = "4" THEN
                tool = 4
            ELSEIF UCASE$(k) = "P" THEN
                IF goPaus = 0 THEN goPaus = 1 ELSE goPaus = 0
            END IF
        END IF

        IF goPaus = 0 THEN
            frm = frm + 1
            IF (frm MOD 15) = 0 THEN CALL DoTick()
        END IF

        CALL DrawMap()

        cpx = cX * 12 : cpy = 14 + cY * 12 : ccl = 46
        CALL Svga_DrawRect(cpx, cpy, cpx + 11, cpy + 11, ccl)

        hcl = 44
        CALL Svga_FillRect(0, 0, 319, 13, hcl)
        ff = 45 : fb = 44 : fl = 0 : fy = 3
        s = "$" + LTRIM$(STR$(funds)) : fx = 0
        CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)
        s = "P:" + LTRIM$(STR$(popul)) : fx = 60
        CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)
        s = "J:" + LTRIM$(STR$(jbs)) : fx = 110
        CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)
        s = "C:" + LTRIM$(STR$(CngPct())) + "%" : fx = 158
        CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)
    LOOP
END SUB
