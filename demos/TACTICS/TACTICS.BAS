' Tactical RPG grid battle demo for PB-SvgaLibrary
' 14x10 battlefield, two teams of 3 units each
' Blue = player (arrows+A+Tab+ESC) or AI in smoke mode
' Red = AI always
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

%MAP_W = 14 : %MAP_H = 10
%MAP_SZ = 140
%SMOKE_LIM = 40
%T_GRASS = 0 : %T_FOREST = 1 : %T_WATER = 2 : %T_ROCK = 3
%C_KNIGHT = 0 : %C_ARCHER = 1 : %C_MAGE = 2

' Unit parallel arrays (indices 0..5): alive, team, class, hp, maxhp, cx, cy
DIM gUAlive(5) AS SHARED INTEGER
DIM gUTeam(5)  AS SHARED INTEGER
DIM gUCls(5)   AS SHARED INTEGER
DIM gUHp(5)    AS SHARED INTEGER
DIM gUMaxHp(5) AS SHARED INTEGER
DIM gUCx(5)    AS SHARED INTEGER
DIM gUCy(5)    AS SHARED INTEGER

' Flat-mapped 2D arrays: index = row*MAP_W + col
DIM gMap(139)    AS SHARED INTEGER
DIM gRange(139)  AS SHARED INTEGER
DIM gBQ(299)     AS SHARED INTEGER
DIM gBC(139)     AS SHARED INTEGER
DIM gTerrCost(3) AS SHARED INTEGER
DIM gTerrDef(3)  AS SHARED INTEGER
DIM gDX0(3)      AS SHARED INTEGER
DIM gDY0(3)      AS SHARED INTEGER

DIM gWin   AS SHARED INTEGER
DIM gTurns AS SHARED INTEGER
DIM gTeam  AS SHARED INTEGER
DIM gUID   AS SHARED INTEGER
DIM gCX    AS SHARED INTEGER
DIM gCY    AS SHARED INTEGER
DIM gSmoke AS SHARED INTEGER
DIM gFontF AS SHARED STRING

gDX0(0)=1 : gDX0(1)=-1 : gDX0(2)=0  : gDX0(3)=0
gDY0(0)=0 : gDY0(1)=0  : gDY0(2)=1  : gDY0(3)=-1

IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN gSmoke = 1

CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)

IF gSmoke = 0 THEN CALL SetPalette

gTerrCost(0)=1 : gTerrCost(1)=2 : gTerrCost(2)=0 : gTerrCost(3)=0
gTerrDef(0)=0  : gTerrDef(1)=1  : gTerrDef(2)=0  : gTerrDef(3)=0
CALL LoadMap
CALL InitUnits

gWin=-1 : gTurns=0 : gTeam=0
CALL StartTeam(0)

IF gSmoke = 0 THEN
    gFontF = "FONT8.TXT"
    CALL Fonts_InitFont(gFontF, 0)
END IF

DO WHILE gWin < 0
    IF gSmoke = 0 THEN
        CALL Render
        CALL HandleInput
    ELSE
        CALL AiTurn
        CALL CheckWin
    END IF
LOOP

CALL Vesa_Close(0)

IF gSmoke = 0 THEN CALL ShowBanner

IF gSmoke > 0 THEN
    OPEN "SMOKE.OK" FOR OUTPUT AS #1
    PRINT #1, "SMOKE-OK win=" + STR$(gWin)
    CLOSE #1
END IF
END

' -----------------------------------------------------------------------
SUB LoadMap
    DIM ln AS STRING, row AS INTEGER, col AS INTEGER
    DIM ch AS STRING, idx AS INTEGER
    OPEN "BATTLE.MAP" FOR INPUT AS #4
    row = 0
    DO WHILE NOT EOF(4) AND row < %MAP_H
        LINE INPUT #4, ln
        FOR col = 0 TO %MAP_W - 1
            IF col < LEN(ln) THEN ch = MID$(ln,col+1,1) ELSE ch = "G"
            idx = row * %MAP_W + col
            SELECT CASE ch
                CASE "F" : gMap(idx) = %T_FOREST
                CASE "W" : gMap(idx) = %T_WATER
                CASE "R" : gMap(idx) = %T_ROCK
                CASE ELSE: gMap(idx) = %T_GRASS
            END SELECT
        NEXT col
        row = row + 1
    LOOP
    CLOSE #4
END SUB

' -----------------------------------------------------------------------
SUB InitUnits
    gUAlive(0)=1:gUTeam(0)=0:gUCls(0)=%C_KNIGHT:gUHp(0)=12:gUMaxHp(0)=12:gUCx(0)=1:gUCy(0)=2
    gUAlive(1)=1:gUTeam(1)=0:gUCls(1)=%C_ARCHER:gUHp(1)= 8:gUMaxHp(1)= 8:gUCx(1)=1:gUCy(1)=5
    gUAlive(2)=1:gUTeam(2)=0:gUCls(2)=%C_MAGE  :gUHp(2)= 6:gUMaxHp(2)= 6:gUCx(2)=1:gUCy(2)=8
    gUAlive(3)=1:gUTeam(3)=1:gUCls(3)=%C_KNIGHT:gUHp(3)=12:gUMaxHp(3)=12:gUCx(3)=12:gUCy(3)=2
    gUAlive(4)=1:gUTeam(4)=1:gUCls(4)=%C_ARCHER:gUHp(4)= 8:gUMaxHp(4)= 8:gUCx(4)=12:gUCy(4)=5
    gUAlive(5)=1:gUTeam(5)=1:gUCls(5)=%C_MAGE  :gUHp(5)= 6:gUMaxHp(5)= 6:gUCx(5)=12:gUCy(5)=8
END SUB

' -----------------------------------------------------------------------
SUB StartTeam(BYVAL tm AS INTEGER)
    DIM i AS INTEGER
    gTeam = tm
    FOR i = 0 TO 5
        IF gUAlive(i)=1 AND gUTeam(i)=tm THEN
            gUID=i : gCX=gUCx(i) : gCY=gUCy(i)
            CALL CalcRange
            EXIT FOR
        END IF
    NEXT i
END SUB

' -----------------------------------------------------------------------
SUB CalcRange
    DIM mx AS INTEGER, utm AS INTEGER
    DIM qh AS INTEGER, qt AS INTEGER
    DIM qx AS INTEGER, qy AS INTEGER
    DIM ci AS INTEGER, nx AS INTEGER, ny AS INTEGER
    DIM nc AS INTEGER, newc AS INTEGER, j AS INTEGER

    utm = gUTeam(gUID)
    SELECT CASE gUCls(gUID)
        CASE %C_KNIGHT : mx = 3
        CASE %C_ARCHER : mx = 4
        CASE %C_MAGE   : mx = 3
        CASE ELSE      : mx = 3
    END SELECT

    FOR j = 0 TO %MAP_SZ - 1
        gRange(j) = 0 : gBC(j) = 9999
    NEXT j

    qx = gUCx(gUID) : qy = gUCy(gUID)
    gBC(qy * %MAP_W + qx) = 0
    gBQ(0) = qx : gBQ(1) = qy
    qh = 0 : qt = 1

    DO WHILE qh < qt
        qx = gBQ(qh*2) : qy = gBQ(qh*2+1) : qh = qh + 1
        FOR ci = 0 TO 3
            nx = qx + gDX0(ci) : ny = qy + gDY0(ci)
            IF nx>=0 AND nx<%MAP_W AND ny>=0 AND ny<%MAP_H THEN
                nc = gTerrCost(gMap(ny * %MAP_W + nx))
                IF nc > 0 THEN
                    newc = gBC(qy * %MAP_W + qx) + nc
                    IF newc < gBC(ny * %MAP_W + nx) AND newc <= mx THEN
                        IF NOT HasEnemy(nx, ny, utm) THEN
                            gBC(ny * %MAP_W + nx) = newc
                            gRange(ny * %MAP_W + nx) = 1
                            IF qt < 149 THEN
                                gBQ(qt*2) = nx : gBQ(qt*2+1) = ny
                                qt = qt + 1
                            END IF
                        END IF
                    END IF
                END IF
            END IF
        NEXT ci
    LOOP
    gRange(gUCy(gUID) * %MAP_W + gUCx(gUID)) = 1
END SUB

' -----------------------------------------------------------------------
FUNCTION HasEnemy(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER, BYVAL utm AS INTEGER) AS INTEGER
    DIM i AS INTEGER
    HasEnemy = 0
    FOR i = 0 TO 5
        IF gUAlive(i)=1 AND gUTeam(i)<>utm THEN
            IF gUCx(i)=cx AND gUCy(i)=cy THEN
                HasEnemy = 1 : EXIT FUNCTION
            END IF
        END IF
    NEXT i
END FUNCTION

' -----------------------------------------------------------------------
FUNCTION HasFriend(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER, BYVAL utm AS INTEGER, BYVAL skip AS INTEGER) AS INTEGER
    DIM i AS INTEGER
    HasFriend = 0
    FOR i = 0 TO 5
        IF i<>skip AND gUAlive(i)=1 AND gUTeam(i)=utm THEN
            IF gUCx(i)=cx AND gUCy(i)=cy THEN
                HasFriend = 1 : EXIT FUNCTION
            END IF
        END IF
    NEXT i
END FUNCTION

' -----------------------------------------------------------------------
FUNCTION DoAttack(BYVAL uid AS INTEGER) AS INTEGER
    DIM rng AS INTEGER, i AS INTEGER, best AS INTEGER, bestd AS INTEGER
    DIM adx AS INTEGER, ady AS INTEGER, dist AS INTEGER
    DIM atk AS INTEGER, tdf AS INTEGER, dmg AS INTEGER
    DIM j AS INTEGER, edx AS INTEGER, edy AS INTEGER, sp AS INTEGER

    SELECT CASE gUCls(uid)
        CASE %C_KNIGHT : rng=1 : atk=3
        CASE %C_ARCHER : rng=3 : atk=2
        CASE %C_MAGE   : rng=2 : atk=3
        CASE ELSE      : rng=1 : atk=2
    END SELECT

    best=-1 : bestd=9999
    FOR i = 0 TO 5
        IF gUAlive(i)=1 AND gUTeam(i)<>gUTeam(uid) THEN
            adx=gUCx(i)-gUCx(uid) : ady=gUCy(i)-gUCy(uid)
            IF adx<0 THEN adx=-adx
            IF ady<0 THEN ady=-ady
            dist=adx+ady
            IF dist<=rng AND dist<bestd THEN bestd=dist : best=i
        END IF
    NEXT i

    IF best < 0 THEN DoAttack = 0 : EXIT FUNCTION

    tdf = gTerrDef(gMap(gUCy(best) * %MAP_W + gUCx(best)))
    dmg = atk - tdf
    IF dmg < 1 THEN dmg = 1

    IF gUCls(uid) = %C_MAGE THEN
        FOR j = 0 TO 5
            IF j<>best AND gUAlive(j)=1 AND gUTeam(j)<>gUTeam(uid) THEN
                edx=gUCx(j)-gUCx(best) : edy=gUCy(j)-gUCy(best)
                IF edx<0 THEN edx=-edx
                IF edy<0 THEN edy=-edy
                IF edx+edy<=1 THEN
                    sp=dmg-1 : IF sp<1 THEN sp=1
                    gUHp(j)=gUHp(j)-sp
                    IF gUHp(j)<=0 THEN gUAlive(j)=0
                END IF
            END IF
        NEXT j
    END IF

    gUHp(best)=gUHp(best)-dmg
    IF gUHp(best)<=0 THEN gUAlive(best)=0
    DoAttack = dmg
END FUNCTION

' -----------------------------------------------------------------------
SUB AdvanceTurn
    DIM i AS INTEGER, found AS INTEGER
    gTurns = gTurns + 1
    gTeam = 1 - gTeam
    found = 0
    FOR i = 0 TO 5
        IF gUAlive(i)=1 AND gUTeam(i)=gTeam THEN found=1 : EXIT FOR
    NEXT i
    IF found = 0 THEN
        gTeam = 1 - gTeam
        FOR i = 0 TO 5
            IF gUAlive(i)=1 AND gUTeam(i)=gTeam THEN found=1 : EXIT FOR
        NEXT i
    END IF
    IF found = 1 THEN CALL StartTeam(gTeam)
END SUB

' -----------------------------------------------------------------------
SUB CheckWin
    DIM a AS INTEGER, b AS INTEGER, i AS INTEGER
    a=0 : b=0
    FOR i = 0 TO 5
        IF gUAlive(i)=1 THEN
            IF gUTeam(i)=0 THEN a=a+1
            IF gUTeam(i)=1 THEN b=b+1
        END IF
    NEXT i
    IF a=0 THEN gWin=1
    IF b=0 THEN gWin=0
    IF gTurns>=%SMOKE_LIM AND gWin<0 THEN gWin=2
END SUB

' -----------------------------------------------------------------------
SUB AiTurn
    DIM utm AS INTEGER, bi AS INTEGER, i AS INTEGER
    DIM bx AS INTEGER, by AS INTEGER
    DIM bestd AS INTEGER, d AS INTEGER
    DIM ddx AS INTEGER, ddy AS INTEGER
    DIM tx AS INTEGER, ty AS INTEGER
    DIM cx AS INTEGER, cy AS INTEGER
    DIM rdx AS INTEGER, rdy AS INTEGER
    DIM res AS INTEGER

    utm = gUTeam(gUID)
    bi=-1 : bestd=9999
    FOR i = 0 TO 5
        IF gUAlive(i)=1 AND gUTeam(i)<>utm THEN
            ddx=gUCx(i)-gUCx(gUID) : ddy=gUCy(i)-gUCy(gUID)
            IF ddx<0 THEN ddx=-ddx
            IF ddy<0 THEN ddy=-ddy
            d=ddx+ddy
            IF d<bestd THEN bestd=d : bi=i
        END IF
    NEXT i

    IF bi >= 0 THEN
        tx=gUCx(bi) : ty=gUCy(bi)
        bx=gUCx(gUID) : by=gUCy(gUID)
        bestd=9999
        FOR cy = 0 TO %MAP_H - 1
            FOR cx = 0 TO %MAP_W - 1
                IF gRange(cy * %MAP_W + cx) = 1 THEN
                    IF NOT HasFriend(cx, cy, utm, gUID) THEN
                        rdx=cx-tx : rdy=cy-ty
                        IF rdx<0 THEN rdx=-rdx
                        IF rdy<0 THEN rdy=-rdy
                        d=rdx+rdy
                        IF d<bestd THEN bestd=d : bx=cx : by=cy
                    END IF
                END IF
            NEXT cx
        NEXT cy
        gUCx(gUID)=bx : gUCy(gUID)=by
        gCX=bx : gCY=by
    END IF

    res = DoAttack(gUID)
    CALL AdvanceTurn
END SUB

' -----------------------------------------------------------------------
SUB HandleInput
    DIM k AS STRING, nx AS INTEGER, ny AS INTEGER
    DIM res AS INTEGER
    k = INKEY$
    IF k = "" THEN EXIT SUB
    IF k = CHR$(27) THEN
        gWin = 3
    ELSEIF k = CHR$(9) THEN
        CALL AdvanceTurn
        CALL CheckWin
    ELSEIF k = "a" OR k = "A" THEN
        res = DoAttack(gUID)
        CALL AdvanceTurn
        CALL CheckWin
    ELSEIF k = CHR$(0) + CHR$(77) THEN
        nx = gCX + 1 : ny = gCY
        IF nx >= 0 AND nx < %MAP_W AND ny >= 0 AND ny < %MAP_H THEN
            IF gRange(ny * %MAP_W + nx) = 1 THEN
                gUCx(gUID) = nx : gUCy(gUID) = ny
                gCX = nx : gCY = ny
            END IF
        END IF
    ELSEIF k = CHR$(0) + CHR$(75) THEN
        nx = gCX - 1 : ny = gCY
        IF nx >= 0 AND nx < %MAP_W AND ny >= 0 AND ny < %MAP_H THEN
            IF gRange(ny * %MAP_W + nx) = 1 THEN
                gUCx(gUID) = nx : gUCy(gUID) = ny
                gCX = nx : gCY = ny
            END IF
        END IF
    ELSEIF k = CHR$(0) + CHR$(80) THEN
        nx = gCX : ny = gCY + 1
        IF nx >= 0 AND nx < %MAP_W AND ny >= 0 AND ny < %MAP_H THEN
            IF gRange(ny * %MAP_W + nx) = 1 THEN
                gUCx(gUID) = nx : gUCy(gUID) = ny
                gCX = nx : gCY = ny
            END IF
        END IF
    ELSEIF k = CHR$(0) + CHR$(72) THEN
        nx = gCX : ny = gCY - 1
        IF nx >= 0 AND nx < %MAP_W AND ny >= 0 AND ny < %MAP_H THEN
            IF gRange(ny * %MAP_W + nx) = 1 THEN
                gUCx(gUID) = nx : gUCy(gUID) = ny
                gCX = nx : gCY = ny
            END IF
        END IF
    ELSEIF k = CHR$(13) THEN
        CALL AiTurn
        CALL CheckWin
    END IF
END SUB

' -----------------------------------------------------------------------
SUB SetPalette
    ' Terrain palette entries 16..19
    CALL Svga_SetPalette(16, 4, 20, 4)
    CALL Svga_SetPalette(17, 2, 12, 2)
    CALL Svga_SetPalette(18, 2, 8, 30)
    CALL Svga_SetPalette(19, 20, 20, 20)
    ' Unit colours: 20=blue team, 21=red team
    CALL Svga_SetPalette(20, 4, 12, 40)
    CALL Svga_SetPalette(21, 40, 6, 4)
    ' HP bars: 22=healthy, 23=wounded
    CALL Svga_SetPalette(22, 4, 40, 4)
    CALL Svga_SetPalette(23, 40, 4, 4)
    ' UI: 24=range-highlight, 25=white, 26=HUD-bg, 27=cursor
    CALL Svga_SetPalette(24, 50, 50, 4)
    CALL Svga_SetPalette(25, 63, 63, 63)
    CALL Svga_SetPalette(26, 8, 8, 8)
    CALL Svga_SetPalette(27, 63, 63, 0)
END SUB

' -----------------------------------------------------------------------
SUB DrawTile(BYVAL tx AS INTEGER, BYVAL ty AS INTEGER)
    DIM px AS INTEGER, py AS INTEGER
    DIM idx AS INTEGER, tc AS INTEGER
    DIM px1 AS WORD, py1 AS WORD, px2 AS WORD, py2 AS WORD, cv AS BYTE
    px = 8 + tx * 16 : py = ty * 16
    idx = ty * %MAP_W + tx
    tc = gMap(idx)
    IF tc = %T_GRASS THEN
        cv = 16
    ELSEIF tc = %T_FOREST THEN
        cv = 17
    ELSEIF tc = %T_WATER THEN
        cv = 18
    ELSE
        cv = 19
    END IF
    px1=px : py1=py : px2=px+15 : py2=py+15
    CALL Svga_FillRect(px1, py1, px2, py2, cv)
    IF gRange(idx) = 1 THEN
        cv = 24
        CALL Svga_DrawRect(px1, py1, px2, py2, cv)
    END IF
END SUB

' -----------------------------------------------------------------------
SUB DrawUnit(BYVAL uid AS INTEGER)
    DIM px AS INTEGER, py AS INTEGER
    DIM bw AS INTEGER, hfw AS INTEGER
    DIM px1 AS WORD, py1 AS WORD, px2 AS WORD, py2 AS WORD, cv AS BYTE
    px = 8 + gUCx(uid) * 16 + 2
    py = gUCy(uid) * 16
    IF gUTeam(uid) = 0 THEN cv = 20 ELSE cv = 21
    ' Body
    px1=px : py1=py+4 : px2=px+11 : py2=py+13
    CALL Svga_FillRect(px1, py1, px2, py2, cv)
    ' Head
    px1=px+3 : py1=py+1 : px2=px+8 : py2=py+4
    CALL Svga_FillRect(px1, py1, px2, py2, cv)
    ' Class marker: knight=none, archer=top-dot, mage=top-stripe
    IF gUCls(uid) = %C_ARCHER THEN
        cv = 25
        px1=px+5 : py1=py+2 : px2=px+6 : py2=py+2
        CALL Svga_FillRect(px1, py1, px2, py2, cv)
    ELSEIF gUCls(uid) = %C_MAGE THEN
        cv = 25
        px1=px+3 : py1=py+2 : px2=px+8 : py2=py+2
        CALL Svga_FillRect(px1, py1, px2, py2, cv)
    END IF
    ' HP bar background (red)
    cv = 23
    px1=px : py1=py : px2=px+11 : py2=py
    CALL Svga_HLine(px1, px2, py1, cv)
    ' HP bar foreground (green)
    bw = 12
    IF gUMaxHp(uid) > 0 THEN
        hfw = (gUHp(uid) * bw) / gUMaxHp(uid)
    ELSE
        hfw = 0
    END IF
    IF hfw > 0 THEN
        cv = 22
        px1=px : py2=py
        px2 = px + hfw - 1
        CALL Svga_HLine(px1, px2, py2, cv)
    END IF
END SUB

' -----------------------------------------------------------------------
SUB DrawCursor
    DIM px AS INTEGER, py AS INTEGER
    DIM px1 AS WORD, py1 AS WORD, px2 AS WORD, py2 AS WORD, cv AS BYTE
    px = 8 + gCX * 16 : py = gCY * 16
    px1=px : py1=py : px2=px+15 : py2=py+15 : cv=27
    CALL Svga_DrawRect(px1, py1, px2, py2, cv)
END SUB

' -----------------------------------------------------------------------
SUB DrawHUD
    DIM i AS INTEGER
    DIM px1 AS WORD, py1 AS WORD, px2 AS WORD, py2 AS WORD, cv AS BYTE
    DIM xw AS WORD, yw AS WORD, fc AS BYTE, bc AS BYTE, fl AS BYTE
    DIM ts AS STRING
    px1=232 : py1=0 : px2=319 : py2=159 : cv=26
    CALL Svga_FillRect(px1, py1, px2, py2, cv)
    i = gUID
    IF i < 0 OR i > 5 THEN EXIT SUB
    IF gUAlive(i) = 0 THEN EXIT SUB
    xw=234 : yw=4 : fc=25 : bc=26 : fl=0
    IF gUTeam(i) = 0 THEN ts = "BLUE" ELSE ts = "RED "
    CALL Fonts_VgaPrint(xw, yw, fc, bc, ts, fl)
    SELECT CASE gUCls(i)
        CASE %C_KNIGHT : ts = "KNGHT"
        CASE %C_ARCHER : ts = "ARCHR"
        CASE %C_MAGE   : ts = "MAGE "
        CASE ELSE      : ts = "???  "
    END SELECT
    yw=14
    CALL Fonts_VgaPrint(xw, yw, fc, bc, ts, fl)
    ts = "HP" + STR$(gUHp(i)) + "/" + STR$(gUMaxHp(i))
    yw=24
    CALL Fonts_VgaPrint(xw, yw, fc, bc, ts, fl)
    ts = "TURN" + STR$(gTurns)
    yw=34
    CALL Fonts_VgaPrint(xw, yw, fc, bc, ts, fl)
END SUB

' -----------------------------------------------------------------------
SUB ShowBanner
    DIM px1 AS WORD, py1 AS WORD, px2 AS WORD, py2 AS WORD, cv AS BYTE
    DIM xw AS WORD, yw AS WORD, fc AS BYTE, bc AS BYTE, fl AS BYTE
    DIM ts AS STRING, dly AS INTEGER
    px1=60 : py1=60 : px2=179 : py2=99 : cv=0
    CALL Svga_FillRect(px1, py1, px2, py2, cv)
    cv=25
    CALL Svga_DrawRect(px1, py1, px2, py2, cv)
    IF gWin = 0 THEN
        ts = "  BLUE WINS!  "
    ELSEIF gWin = 1 THEN
        ts = "  RED  WINS!  "
    ELSE
        ts = "    DRAW!     "
    END IF
    xw=70 : yw=75 : fc=25 : bc=0 : fl=0
    CALL Fonts_VgaPrint(xw, yw, fc, bc, ts, fl)
    FOR dly = 1 TO 100
        CALL Timer_Delay10Ms(5)
    NEXT dly
END SUB

' -----------------------------------------------------------------------
SUB Render
    DIM i AS INTEGER, j AS INTEGER
    DIM px1 AS WORD, py1 AS WORD, px2 AS WORD, py2 AS WORD, cv AS BYTE
    px1=0 : py1=0 : px2=319 : py2=159 : cv=0
    CALL Svga_FillRect(px1, py1, px2, py2, cv)
    FOR j = 0 TO %MAP_H - 1
        FOR i = 0 TO %MAP_W - 1
            CALL DrawTile(i, j)
        NEXT i
    NEXT j
    FOR i = 0 TO 5
        IF gUAlive(i) = 1 THEN CALL DrawUnit(i)
    NEXT i
    CALL DrawCursor
    CALL DrawHUD
END SUB
