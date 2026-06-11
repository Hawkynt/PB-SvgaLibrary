' SCROLLER.BAS - Side-scrolling shoot-em-up demo for PB-SvgaLibrary
' Mode 13h (320x200), three-layer parallax starfield, player ship,
' enemy waves with sine-bobbing, bullets, explosions, HUD.
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

' ---- numeric constants (PB 3.5 syntax) ----
%SCR_W      = 320
%SCR_H      = 200
%MAX_S1     = 60
%MAX_S2     = 40
%MAX_S3     = 20
%MAX_PB     = 6
%MAX_EB     = 8
%MAX_EN     = 8
%MAX_EX     = 6
%WTAB       = 64
%FVAL       = 0
%TVAL       = 1
%SMK_FR     = 220

' ---- forward declarations for all SUBs ----
DECLARE SUB SetPalette(BYVAL dummy AS INTEGER)
DECLARE SUB BuildSineTbl(BYVAL dummy AS INTEGER)
DECLARE SUB ReadInput(BYVAL isSmoke AS INTEGER, BYVAL fr AS LONG, _
        fireOut AS INTEGER, upOut AS INTEGER, dnOut AS INTEGER, _
        ltOut AS INTEGER, rtOut AS INTEGER, quitOut AS INTEGER)
DECLARE SUB SpawnPBullet(BYVAL sx AS INTEGER, BYVAL sy AS INTEGER)
DECLARE SUB SpawnEnemy(BYVAL slot AS INTEGER)
DECLARE SUB SpawnEBullet(BYVAL sx AS INTEGER, BYVAL sy AS INTEGER)
DECLARE SUB SpawnExpl(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER)
DECLARE SUB EraseAll(BYVAL dummy AS INTEGER)
DECLARE SUB UpdateStars(BYVAL dummy AS INTEGER)
DECLARE SUB UpdatePBullets(BYVAL dummy AS INTEGER)
DECLARE SUB UpdateEnemies(BYVAL fr AS LONG)
DECLARE SUB UpdateEBullets(BYVAL dummy AS INTEGER)
DECLARE SUB UpdateExplosions(BYVAL dummy AS INTEGER)
DECLARE SUB CheckPBvsEN(killed AS INTEGER)
DECLARE SUB CheckEBvsPlayer(lv AS INTEGER, isDead AS INTEGER)
DECLARE SUB CheckENvsPlayer(lv AS INTEGER, isDead AS INTEGER)
DECLARE SUB DrawStars(BYVAL dummy AS INTEGER)
DECLARE SUB DrawPlayer(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER)
DECLARE SUB DrawEnemy(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER)
DECLARE SUB DrawEnemies(BYVAL dummy AS INTEGER)
DECLARE SUB DrawPBullets(BYVAL dummy AS INTEGER)
DECLARE SUB DrawEBullets(BYVAL dummy AS INTEGER)
DECLARE SUB DrawExplosions(BYVAL dummy AS INTEGER)
DECLARE SUB DrawHUD(BYVAL lv AS INTEGER, BYVAL sc AS LONG, BYVAL wv AS INTEGER)

' ---- global shared arrays and vars ----
DIM s1x(60) AS SHARED INTEGER : DIM s1y(60) AS SHARED INTEGER
DIM s2x(40) AS SHARED INTEGER : DIM s2y(40) AS SHARED INTEGER
DIM s3x(20) AS SHARED INTEGER : DIM s3y(20) AS SHARED INTEGER
DIM pbx(6) AS SHARED INTEGER : DIM pby(6) AS SHARED INTEGER
DIM pbact(6) AS SHARED INTEGER
DIM ebx(8) AS SHARED INTEGER : DIM eby(8) AS SHARED INTEGER
DIM ebact(8) AS SHARED INTEGER
DIM enx(8) AS SHARED INTEGER : DIM eny(8) AS SHARED INTEGER
DIM enact(8) AS SHARED INTEGER
DIM enwidx(8) AS SHARED INTEGER : DIM enfcd(8) AS SHARED INTEGER
DIM expx(6) AS SHARED INTEGER : DIM expy(6) AS SHARED INTEGER
DIM expf(6) AS SHARED INTEGER : DIM expact(6) AS SHARED INTEGER
DIM sinetbl(64) AS SHARED INTEGER
DIM plx AS SHARED INTEGER : DIM ply AS SHARED INTEGER
DIM plives AS SHARED INTEGER : DIM pscore AS SHARED LONG
DIM pfcd AS SHARED INTEGER

' ============================================================
' INIT PHASE
' ============================================================
CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)
CALL Fonts_InitFont("FONT8.TXT", 0)
CALL SetPalette(0)
CALL BuildSineTbl(0)

RANDOMIZE 42

DIM tv AS INTEGER, ii AS INTEGER
FOR ii = 0 TO %MAX_S1 - 1
    tv = (RND * %SCR_W) : s1x(ii) = tv
    tv = 10 + (RND * 180) : s1y(ii) = tv
NEXT ii
FOR ii = 0 TO %MAX_S2 - 1
    tv = (RND * %SCR_W) : s2x(ii) = tv
    tv = 10 + (RND * 180) : s2y(ii) = tv
NEXT ii
FOR ii = 0 TO %MAX_S3 - 1
    tv = (RND * %SCR_W) : s3x(ii) = tv
    tv = 10 + (RND * 180) : s3y(ii) = tv
NEXT ii

plx = 30 : ply = 100 : plives = 3 : pscore = 0 : pfcd = 0

FOR ii = 0 TO %MAX_PB - 1 : pbact(ii) = %FVAL : NEXT ii
FOR ii = 0 TO %MAX_EB - 1 : ebact(ii) = %FVAL : NEXT ii
FOR ii = 0 TO %MAX_EN - 1 : enact(ii) = %FVAL : NEXT ii
FOR ii = 0 TO %MAX_EX - 1 : expact(ii) = %FVAL : NEXT ii

DIM frame AS LONG, wave AS INTEGER, wtimer AS INTEGER
DIM spslot AS INTEGER, gmover AS INTEGER, smokeMode AS INTEGER
DIM killed AS INTEGER
frame = 0 : wave = 1 : wtimer = 0 : spslot = 0
gmover = %FVAL : killed = 0

smokeMode = %FVAL
IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN smokeMode = %TVAL

' ---- title splash -----------------------------------------------------------
DIM spfn2 AS STRING, spx2 AS WORD, spy2 AS WORD
DIM sphld2 AS INTEGER, spk2 AS STRING
spfn2 = "TITLE.PCX"
spx2 = 0 : spy2 = 20
CALL DrawPcx_Show(spfn2, spx2, spy2)
IF smokeMode = %TVAL THEN
    sphld2 = 0
    WHILE sphld2 < 20
        sphld2 = sphld2 + 1
    WEND
ELSE
    spk2 = ""
    WHILE spk2 = ""
        spk2 = INKEY$
    WEND
END IF
' restore game palette after image loader replaced it
CALL SetPalette(0)

' ============================================================
' MAIN GAME LOOP
' ============================================================
DO
    DIM fireKey AS INTEGER, upKey AS INTEGER, dnKey AS INTEGER
    DIM ltKey AS INTEGER, rtKey AS INTEGER, quitKey AS INTEGER
    fireKey = %FVAL : upKey = %FVAL : dnKey = %FVAL
    ltKey   = %FVAL : rtKey = %FVAL : quitKey = %FVAL

    CALL ReadInput(smokeMode, frame, fireKey, upKey, dnKey, ltKey, rtKey, quitKey)
    IF quitKey = %TVAL THEN EXIT DO

    IF upKey = %TVAL THEN ply = ply - 2
    IF dnKey = %TVAL THEN ply = ply + 2
    IF ltKey = %TVAL THEN plx = plx - 2
    IF rtKey = %TVAL THEN plx = plx + 2
    IF plx < 5  THEN plx = 5
    IF plx > 90 THEN plx = 90
    IF ply < 12 THEN ply = 12
    IF ply > 185 THEN ply = 185

    IF pfcd > 0 THEN pfcd = pfcd - 1
    IF fireKey = %TVAL AND pfcd = 0 THEN
        CALL SpawnPBullet(plx + 14, ply)
        pfcd = 8
    END IF

    wtimer = wtimer + 1
    IF wtimer >= 60 THEN
        wtimer = 0
        CALL SpawnEnemy(spslot)
        spslot = spslot + 1
        IF spslot >= %MAX_EN THEN spslot = 0
    END IF

    CALL EraseAll(0)
    CALL UpdateStars(0)
    CALL UpdatePBullets(0)
    CALL UpdateEnemies(frame)
    CALL UpdateEBullets(0)
    CALL UpdateExplosions(0)
    CALL CheckPBvsEN(killed)
    IF gmover = %FVAL THEN CALL CheckEBvsPlayer(plives, gmover)
    IF gmover = %FVAL THEN CALL CheckENvsPlayer(plives, gmover)

    IF (frame MOD 500) = 0 AND frame > 0 THEN
        wave = wave + 1
        IF wave > 9 THEN wave = 9
    END IF

    CALL DrawStars(0)
    IF gmover = %FVAL THEN CALL DrawPlayer(plx, ply)
    CALL DrawEnemies(0)
    CALL DrawPBullets(0)
    CALL DrawEBullets(0)
    CALL DrawExplosions(0)
    CALL DrawHUD(plives, pscore, wave)

    frame = frame + 1

    IF smokeMode = %TVAL THEN
        IF frame >= %SMK_FR THEN EXIT DO
    END IF

    IF plives <= 0 THEN gmover = %TVAL

    IF smokeMode = %FVAL THEN
        CALL Timer_Delay10Ms(1)
    END IF
LOOP

CALL Svga_Close(0)

IF smokeMode = %TVAL THEN
    IF killed >= 1 THEN
        OPEN "SMOKE.OK" FOR OUTPUT AS #1
        PRINT #1, "OK " + Svga_Version$
        CLOSE #1
    END IF
END IF

END

' ============================================================
' SUBROUTINES
' ============================================================

SUB SetPalette(BYVAL dummy AS INTEGER)
    CALL Svga_SetPalette(0, 0, 0, 0)
    CALL Svga_SetPalette(1, 4, 6, 20)
    CALL Svga_SetPalette(2, 6, 8, 26)
    CALL Svga_SetPalette(3, 8, 12, 32)
    CALL Svga_SetPalette(4, 10, 15, 40)
    CALL Svga_SetPalette(5, 14, 20, 48)
    CALL Svga_SetPalette(6, 18, 26, 56)
    CALL Svga_SetPalette(7, 40, 48, 63)
    CALL Svga_SetPalette(8, 50, 56, 63)
    CALL Svga_SetPalette(9, 60, 62, 63)
    CALL Svga_SetPalette(10, 25, 30, 42)
    CALL Svga_SetPalette(11, 10, 50, 63)
    CALL Svga_SetPalette(12, 63, 30, 4)
    CALL Svga_SetPalette(13, 14, 18, 28)
    CALL Svga_SetPalette(14, 35, 42, 58)
    CALL Svga_SetPalette(20, 8, 40, 10)
    CALL Svga_SetPalette(21, 4, 22, 6)
    CALL Svga_SetPalette(22, 55, 8, 4)
    CALL Svga_SetPalette(23, 60, 55, 5)
    CALL Svga_SetPalette(30, 63, 63, 10)
    CALL Svga_SetPalette(31, 63, 63, 63)
    CALL Svga_SetPalette(40, 63, 22, 2)
    CALL Svga_SetPalette(41, 63, 5, 2)
    CALL Svga_SetPalette(50, 63, 63, 20)
    CALL Svga_SetPalette(51, 63, 50, 5)
    CALL Svga_SetPalette(52, 63, 35, 2)
    CALL Svga_SetPalette(53, 60, 20, 2)
    CALL Svga_SetPalette(54, 50, 10, 2)
    CALL Svga_SetPalette(55, 35, 5, 2)
    CALL Svga_SetPalette(56, 20, 4, 2)
    CALL Svga_SetPalette(57, 8, 2, 2)
    CALL Svga_SetPalette(60, 63, 63, 63)
    CALL Svga_SetPalette(61, 2, 2, 10)
    CALL Svga_SetPalette(62, 63, 58, 20)
    CALL Svga_SetPalette(63, 63, 60, 5)
END SUB

SUB BuildSineTbl(BYVAL dummy AS INTEGER)
    sinetbl(0)  =  0  : sinetbl(1)  =  3  : sinetbl(2)  =  6  : sinetbl(3)  =  9
    sinetbl(4)  = 11  : sinetbl(5)  = 14  : sinetbl(6)  = 16  : sinetbl(7)  = 18
    sinetbl(8)  = 20  : sinetbl(9)  = 21  : sinetbl(10) = 23  : sinetbl(11) = 24
    sinetbl(12) = 25  : sinetbl(13) = 26  : sinetbl(14) = 27  : sinetbl(15) = 27
    sinetbl(16) = 28  : sinetbl(17) = 28  : sinetbl(18) = 28  : sinetbl(19) = 27
    sinetbl(20) = 27  : sinetbl(21) = 26  : sinetbl(22) = 25  : sinetbl(23) = 24
    sinetbl(24) = 23  : sinetbl(25) = 21  : sinetbl(26) = 20  : sinetbl(27) = 18
    sinetbl(28) = 16  : sinetbl(29) = 14  : sinetbl(30) = 11  : sinetbl(31) =  9
    sinetbl(32) =  6  : sinetbl(33) =  3  : sinetbl(34) =  0  : sinetbl(35) = -3
    sinetbl(36) = -6  : sinetbl(37) = -9  : sinetbl(38) =-11  : sinetbl(39) =-14
    sinetbl(40) =-16  : sinetbl(41) =-18  : sinetbl(42) =-20  : sinetbl(43) =-21
    sinetbl(44) =-23  : sinetbl(45) =-24  : sinetbl(46) =-25  : sinetbl(47) =-26
    sinetbl(48) =-27  : sinetbl(49) =-27  : sinetbl(50) =-28  : sinetbl(51) =-28
    sinetbl(52) =-28  : sinetbl(53) =-27  : sinetbl(54) =-27  : sinetbl(55) =-26
    sinetbl(56) =-25  : sinetbl(57) =-24  : sinetbl(58) =-23  : sinetbl(59) =-21
    sinetbl(60) =-20  : sinetbl(61) =-18  : sinetbl(62) =-16  : sinetbl(63) =-14
END SUB

SUB ReadInput(BYVAL isSmoke AS INTEGER, BYVAL fr AS LONG, _
              fireOut AS INTEGER, upOut AS INTEGER, dnOut AS INTEGER, _
              ltOut AS INTEGER, rtOut AS INTEGER, quitOut AS INTEGER)
    IF isSmoke = %TVAL THEN
        DIM bidx AS INTEGER
        bidx = (fr \ 2) AND 63
        IF sinetbl(bidx) < 0 THEN
            upOut = %TVAL
        ELSE
            dnOut = %TVAL
        END IF
        fireOut = %TVAL
    ELSE
        DIM ky AS STRING
        ky = INKEY$
        IF LEN(ky) = 1 THEN
            IF ky = CHR$(27) THEN quitOut = %TVAL
            IF ky = " "      THEN fireOut  = %TVAL
        END IF
        IF LEN(ky) = 2 THEN
            DIM sc AS STRING
            sc = MID$(ky, 2, 1)
            IF sc = "H" THEN upOut = %TVAL
            IF sc = "P" THEN dnOut = %TVAL
            IF sc = "K" THEN ltOut = %TVAL
            IF sc = "M" THEN rtOut = %TVAL
        END IF
    END IF
END SUB

SUB SpawnPBullet(BYVAL sx AS INTEGER, BYVAL sy AS INTEGER)
    DIM si AS INTEGER
    FOR si = 0 TO %MAX_PB - 1
        IF pbact(si) = %FVAL THEN
            pbx(si) = sx : pby(si) = sy : pbact(si) = %TVAL
            EXIT FOR
        END IF
    NEXT si
END SUB

SUB SpawnEnemy(BYVAL slot AS INTEGER)
    DIM si AS INTEGER
    si = slot AND (%MAX_EN - 1)
    IF enact(si) = %FVAL THEN
        enx(si) = %SCR_W + 4
        DIM ry AS INTEGER
        ry = 20 + (RND * 150)
        eny(si) = ry
        enwidx(si) = (si * 8) AND 63
        DIM rcd AS INTEGER
        rcd = 40 + (RND * 40)
        enfcd(si) = rcd
        enact(si) = %TVAL
    END IF
END SUB

SUB SpawnEBullet(BYVAL sx AS INTEGER, BYVAL sy AS INTEGER)
    DIM si AS INTEGER
    FOR si = 0 TO %MAX_EB - 1
        IF ebact(si) = %FVAL THEN
            ebx(si) = sx : eby(si) = sy : ebact(si) = %TVAL
            EXIT FOR
        END IF
    NEXT si
END SUB

SUB SpawnExpl(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER)
    DIM si AS INTEGER
    FOR si = 0 TO %MAX_EX - 1
        IF expact(si) = %FVAL THEN
            expx(si) = cx : expy(si) = cy
            expf(si) = 0 : expact(si) = %TVAL
            EXIT FOR
        END IF
    NEXT si
END SUB

SUB EraseAll(BYVAL dummy AS INTEGER)
    DIM bv AS BYTE : bv = 0
    ' erase player
    DIM x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD
    x1 = plx - 14 : y1 = ply - 8 : x2 = plx + 15 : y2 = ply + 8
    CALL Svga_FillRect(x1, y1, x2, y2, bv)
    ' erase player bullets
    DIM bi AS INTEGER
    FOR bi = 0 TO %MAX_PB - 1
        IF pbact(bi) = %TVAL THEN
            x1 = pbx(bi) : y1 = pby(bi) - 1 : x2 = pbx(bi) + 5 : y2 = pby(bi) + 1
            CALL Svga_FillRect(x1, y1, x2, y2, bv)
        END IF
    NEXT bi
    ' erase enemies
    FOR bi = 0 TO %MAX_EN - 1
        IF enact(bi) = %TVAL THEN
            x1 = enx(bi) - 14 : y1 = eny(bi) - 8 : x2 = enx(bi) + 8 : y2 = eny(bi) + 8
            CALL Svga_FillRect(x1, y1, x2, y2, bv)
        END IF
    NEXT bi
    ' erase enemy bullets
    FOR bi = 0 TO %MAX_EB - 1
        IF ebact(bi) = %TVAL THEN
            x1 = ebx(bi) : y1 = eby(bi) - 1 : x2 = ebx(bi) + 4 : y2 = eby(bi) + 1
            CALL Svga_FillRect(x1, y1, x2, y2, bv)
        END IF
    NEXT bi
    ' erase explosions
    FOR bi = 0 TO %MAX_EX - 1
        IF expact(bi) = %TVAL THEN
            DIM er AS INTEGER
            er = 3 + expf(bi) * 3
            x1 = expx(bi) - er : y1 = expy(bi) - er
            x2 = expx(bi) + er : y2 = expy(bi) + er
            CALL Svga_FillRect(x1, y1, x2, y2, bv)
        END IF
    NEXT bi
END SUB

SUB UpdateStars(BYVAL dummy AS INTEGER)
    DIM si AS INTEGER
    FOR si = 0 TO %MAX_S1 - 1
        s1x(si) = s1x(si) - 1
        IF s1x(si) < 0 THEN s1x(si) = %SCR_W - 1
    NEXT si
    FOR si = 0 TO %MAX_S2 - 1
        s2x(si) = s2x(si) - 2
        IF s2x(si) < 0 THEN s2x(si) = %SCR_W - 1
    NEXT si
    FOR si = 0 TO %MAX_S3 - 1
        s3x(si) = s3x(si) - 3
        IF s3x(si) < 0 THEN s3x(si) = %SCR_W - 1
    NEXT si
END SUB

SUB UpdatePBullets(BYVAL dummy AS INTEGER)
    DIM bi AS INTEGER
    FOR bi = 0 TO %MAX_PB - 1
        IF pbact(bi) = %TVAL THEN
            pbx(bi) = pbx(bi) + 6
            IF pbx(bi) >= %SCR_W THEN pbact(bi) = %FVAL
        END IF
    NEXT bi
END SUB

SUB UpdateEnemies(BYVAL fr AS LONG)
    DIM ei AS INTEGER
    FOR ei = 0 TO %MAX_EN - 1
        IF enact(ei) = %TVAL THEN
            enx(ei) = enx(ei) - 2
            enwidx(ei) = (enwidx(ei) + 1) AND 63
            DIM newy AS INTEGER
            newy = eny(ei) + (sinetbl(enwidx(ei)) \ 8)
            IF newy < 12  THEN newy = 12
            IF newy > 185 THEN newy = 185
            eny(ei) = newy
            IF enx(ei) < -20 THEN enact(ei) = %FVAL
            IF enact(ei) = %TVAL THEN
                enfcd(ei) = enfcd(ei) - 1
                IF enfcd(ei) <= 0 THEN
                    CALL SpawnEBullet(enx(ei) - 6, eny(ei))
                    DIM ncd AS INTEGER
                    ncd = 50 + (RND * 50)
                    enfcd(ei) = ncd
                END IF
            END IF
        END IF
    NEXT ei
END SUB

SUB UpdateEBullets(BYVAL dummy AS INTEGER)
    DIM bi AS INTEGER
    FOR bi = 0 TO %MAX_EB - 1
        IF ebact(bi) = %TVAL THEN
            ebx(bi) = ebx(bi) - 4
            IF ebx(bi) < 0 THEN ebact(bi) = %FVAL
        END IF
    NEXT bi
END SUB

SUB UpdateExplosions(BYVAL dummy AS INTEGER)
    DIM ei AS INTEGER
    FOR ei = 0 TO %MAX_EX - 1
        IF expact(ei) = %TVAL THEN
            expf(ei) = expf(ei) + 1
            IF expf(ei) >= 8 THEN expact(ei) = %FVAL
        END IF
    NEXT ei
END SUB

SUB CheckPBvsEN(killed AS INTEGER)
    DIM bi AS INTEGER, ei AS INTEGER
    FOR bi = 0 TO %MAX_PB - 1
        IF pbact(bi) = %TVAL THEN
            FOR ei = 0 TO %MAX_EN - 1
                IF enact(ei) = %TVAL THEN
                    DIM adx AS INTEGER, ady AS INTEGER
                    adx = pbx(bi) - enx(ei)
                    ady = pby(bi) - eny(ei)
                    IF adx < 0 THEN adx = -adx
                    IF ady < 0 THEN ady = -ady
                    IF adx < 14 AND ady < 8 THEN
                        enact(ei) = %FVAL
                        pbact(bi) = %FVAL
                        CALL SpawnExpl(enx(ei), eny(ei))
                        pscore = pscore + 100
                        killed = killed + 1
                        EXIT FOR
                    END IF
                END IF
            NEXT ei
        END IF
    NEXT bi
END SUB

SUB CheckEBvsPlayer(lv AS INTEGER, isDead AS INTEGER)
    DIM bi AS INTEGER
    FOR bi = 0 TO %MAX_EB - 1
        IF ebact(bi) = %TVAL THEN
            DIM adx AS INTEGER, ady AS INTEGER
            adx = ebx(bi) - plx
            ady = eby(bi) - ply
            IF adx < 0 THEN adx = -adx
            IF ady < 0 THEN ady = -ady
            IF adx < 12 AND ady < 6 THEN
                ebact(bi) = %FVAL
                lv = lv - 1
                CALL SpawnExpl(plx, ply)
                IF lv <= 0 THEN isDead = %TVAL
            END IF
        END IF
    NEXT bi
    plives = lv
END SUB

SUB CheckENvsPlayer(lv AS INTEGER, isDead AS INTEGER)
    DIM ei AS INTEGER
    FOR ei = 0 TO %MAX_EN - 1
        IF enact(ei) = %TVAL THEN
            DIM adx AS INTEGER, ady AS INTEGER
            adx = enx(ei) - plx
            ady = eny(ei) - ply
            IF adx < 0 THEN adx = -adx
            IF ady < 0 THEN ady = -ady
            IF adx < 20 AND ady < 8 THEN
                enact(ei) = %FVAL
                lv = lv - 1
                CALL SpawnExpl(plx, ply)
                IF lv <= 0 THEN isDead = %TVAL
            END IF
        END IF
    NEXT ei
    plives = lv
END SUB

SUB DrawStars(BYVAL dummy AS INTEGER)
    DIM si AS INTEGER, xw AS WORD, yw AS WORD, cw AS BYTE
    FOR si = 0 TO %MAX_S1 - 1
        IF s1y(si) >= 10 AND s1y(si) <= 190 THEN
            xw = s1x(si) : yw = s1y(si) : cw = 1
            CALL Svga_PutPixel(xw, yw, cw)
        END IF
    NEXT si
    FOR si = 0 TO %MAX_S2 - 1
        IF s2y(si) >= 10 AND s2y(si) <= 190 THEN
            xw = s2x(si) : yw = s2y(si) : cw = 4
            CALL Svga_PutPixel(xw, yw, cw)
            IF s2x(si) + 1 < %SCR_W THEN
                DIM xw2 AS WORD
                xw2 = s2x(si) + 1
                CALL Svga_PutPixel(xw2, yw, cw)
            END IF
        END IF
    NEXT si
    FOR si = 0 TO %MAX_S3 - 1
        IF s3y(si) >= 10 AND s3y(si) <= 190 THEN
            xw = s3x(si) : yw = s3y(si) : cw = 7
            CALL Svga_PutPixel(xw, yw, cw)
            IF s3x(si) + 1 < %SCR_W THEN
                DIM xw3 AS WORD
                xw3 = s3x(si) + 1
                CALL Svga_PutPixel(xw3, yw, cw)
            END IF
        END IF
    NEXT si
END SUB

SUB DrawPlayer(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER)
    DIM x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD, cv AS BYTE
    ' hull
    x1 = cx - 12 : y1 = cy - 3 : x2 = cx + 12 : y2 = cy + 3 : cv = 10
    CALL Svga_FillRect(x1, y1, x2, y2, cv)
    ' top wing
    DIM t1x AS WORD, t1y AS WORD, t2x AS WORD, t2y AS WORD, t3x AS WORD, t3y AS WORD
    t1x = cx - 8 : t1y = cy - 3 : t2x = cx + 5 : t2y = cy - 3 : t3x = cx - 2 : t3y = cy - 7
    cv = 14
    CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, cv)
    ' bottom wing
    t1x = cx - 8 : t1y = cy + 3 : t2x = cx + 5 : t2y = cy + 3 : t3x = cx - 2 : t3y = cy + 7
    cv = 13
    CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, cv)
    ' nose
    DIM n1x AS WORD, n1y AS WORD, n2x AS WORD, n2y AS WORD, n3x AS WORD, n3y AS WORD
    n1x = cx + 12 : n1y = cy : n2x = cx + 4 : n2y = cy - 3 : n3x = cx + 4 : n3y = cy + 3
    cv = 11
    CALL Graphics_FillTriangle(n1x, n1y, n2x, n2y, n3x, n3y, cv)
    ' engine glow
    DIM ecx AS WORD, ecy AS WORD, er AS WORD
    ecx = cx - 13 : ecy = cy : er = 3 : cv = 62
    CALL Svga_FillCircle(ecx, ecy, er, cv)
    ecx = cx - 13 : er = 1 : cv = 31
    CALL Svga_FillCircle(ecx, ecy, er, cv)
END SUB

SUB DrawEnemy(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER)
    DIM x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD, cv AS BYTE
    x1 = cx - 10 : y1 = cy - 3 : x2 = cx + 6 : y2 = cy + 3 : cv = 20
    CALL Svga_FillRect(x1, y1, x2, y2, cv)
    DIM t1x AS WORD, t1y AS WORD, t2x AS WORD, t2y AS WORD, t3x AS WORD, t3y AS WORD
    t1x = cx - 6 : t1y = cy - 3 : t2x = cx + 4 : t2y = cy - 3 : t3x = cx : t3y = cy - 7
    cv = 21
    CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, cv)
    t1x = cx - 6 : t1y = cy + 3 : t2x = cx + 4 : t2y = cy + 3 : t3x = cx : t3y = cy + 7
    cv = 21
    CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, cv)
    DIM n1x AS WORD, n1y AS WORD, n2x AS WORD, n2y AS WORD, n3x AS WORD, n3y AS WORD
    n1x = cx - 12 : n1y = cy : n2x = cx - 4 : n2y = cy - 3 : n3x = cx - 4 : n3y = cy + 3
    cv = 22
    CALL Graphics_FillTriangle(n1x, n1y, n2x, n2y, n3x, n3y, cv)
    DIM ccx AS WORD, ccy AS WORD, cr AS WORD
    ccx = cx + 2 : ccy = cy : cr = 2 : cv = 23
    CALL Svga_FillCircle(ccx, ccy, cr, cv)
END SUB

SUB DrawEnemies(BYVAL dummy AS INTEGER)
    DIM ei AS INTEGER
    FOR ei = 0 TO %MAX_EN - 1
        IF enact(ei) = %TVAL THEN CALL DrawEnemy(enx(ei), eny(ei))
    NEXT ei
END SUB

SUB DrawPBullets(BYVAL dummy AS INTEGER)
    DIM bi AS INTEGER
    FOR bi = 0 TO %MAX_PB - 1
        IF pbact(bi) = %TVAL THEN
            DIM bx1 AS WORD, by1 AS WORD, bx2 AS WORD, bc AS BYTE
            bx1 = pbx(bi) : by1 = pby(bi) : bx2 = pbx(bi) + 4 : bc = 30
            CALL Svga_HLine(bx1, bx2, by1, bc)
            bx2 = pbx(bi) + 4 : bc = 31
            CALL Svga_PutPixel(bx2, by1, bc)
        END IF
    NEXT bi
END SUB

SUB DrawEBullets(BYVAL dummy AS INTEGER)
    DIM bi AS INTEGER
    FOR bi = 0 TO %MAX_EB - 1
        IF ebact(bi) = %TVAL THEN
            DIM bx1 AS WORD, by1 AS WORD, bx2 AS WORD, bc AS BYTE
            bx1 = ebx(bi) : by1 = eby(bi) : bx2 = ebx(bi) + 3 : bc = 40
            CALL Svga_HLine(bx1, bx2, by1, bc)
            bx1 = ebx(bi) : bc = 41
            CALL Svga_PutPixel(bx1, by1, bc)
        END IF
    NEXT bi
END SUB

SUB DrawExplosions(BYVAL dummy AS INTEGER)
    DIM ei AS INTEGER
    FOR ei = 0 TO %MAX_EX - 1
        IF expact(ei) = %TVAL THEN
            DIM ecx AS WORD, ecy AS WORD, er AS WORD, ec AS BYTE, ef AS INTEGER
            ef = expf(ei)
            er = 2 + ef * 3
            ecx = expx(ei) : ecy = expy(ei)
            ec = 50 + ef
            IF ec > 57 THEN ec = 57
            CALL Svga_FillCircle(ecx, ecy, er, ec)
            IF ef < 3 THEN
                er = 1 : ec = 31
                CALL Svga_FillCircle(ecx, ecy, er, ec)
            END IF
        END IF
    NEXT ei
END SUB

SUB DrawHUD(BYVAL lv AS INTEGER, BYVAL sc AS LONG, BYVAL wv AS INTEGER)
    DIM hc AS BYTE : hc = 61
    CALL Svga_FillRect(0, 0, 319, 9, hc)
    DIM sc_s AS STRING
    sc_s = "SCR:" + STR$(sc)
    DIM fx AS WORD, fy AS WORD, fc AS BYTE, bc AS BYTE
    fx = 2 : fy = 1 : fc = 63 : bc = 61
    CALL Fonts_VgaPrint(fx, fy, fc, bc, sc_s, 0)
    DIM lv_s AS STRING
    lv_s = "LIV:" + STR$(lv)
    fx = 120 : fy = 1 : fc = 60 : bc = 61
    CALL Fonts_VgaPrint(fx, fy, fc, bc, lv_s, 0)
    DIM wv_s AS STRING
    wv_s = "WVE:" + STR$(wv)
    fx = 240 : fy = 1 : fc = 60 : bc = 61
    CALL Fonts_VgaPrint(fx, fy, fc, bc, wv_s, 0)
END SUB
