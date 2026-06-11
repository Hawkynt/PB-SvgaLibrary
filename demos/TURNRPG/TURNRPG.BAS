' Turn-Based RPG Demo - JRPG style, Mode 13h 320x200
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

' ---- Global game state ----
DIM gScene        AS INTEGER
DIM gSmoke        AS INTEGER
DIM gFrame        AS INTEGER
DIM gQuit         AS INTEGER

' ---- Map layout constants ----
%MAP_COLS = 20
%MAP_ROWS = 12
%TILE_W   = 12
%TILE_H   = 13

' ---- Player position ----
DIM gPX AS INTEGER
DIM gPY AS INTEGER

' ---- Hero stats (Knight=0, Mage=1) ----
DIM gHeroHP(1)    AS INTEGER
DIM gHeroMaxHP(1) AS INTEGER
DIM gHeroMP(1)    AS INTEGER
DIM gHeroMaxMP(1) AS INTEGER
DIM gHeroXP       AS INTEGER
DIM gHeroGold     AS INTEGER
DIM gHeroAtk(1)   AS INTEGER
DIM gHeroDef(1)   AS INTEGER
DIM gHName0 AS STRING : PUBLIC gHName0
DIM gHName1 AS STRING : PUBLIC gHName1

' ---- Monster stats (up to 2) ----
DIM gMonHP(1)    AS INTEGER
DIM gMonMaxHP(1) AS INTEGER
DIM gMonAtk(1)   AS INTEGER
DIM gMonDef(1)   AS INTEGER
DIM gMName0 AS STRING : PUBLIC gMName0
DIM gMName1 AS STRING : PUBLIC gMName1
DIM gMonCount    AS INTEGER
DIM gMonAlive(1) AS INTEGER
DIM gIsBoss      AS INTEGER

' ---- Battle state ----
DIM gBattleTurn   AS INTEGER
DIM gMenuSel      AS INTEGER
DIM gBattlePhase  AS INTEGER
DIM gBattleMsg AS STRING : PUBLIC gBattleMsg
DIM gBattleMsgTmr AS INTEGER
DIM gAnimTmr      AS INTEGER
DIM gAnimHero     AS INTEGER
DIM gAnimLunge    AS INTEGER
DIM gDmgNum(1)    AS INTEGER
DIM gDmgY(1)      AS INTEGER
DIM gDmgShow(1)   AS INTEGER
DIM gBattleOver   AS INTEGER
DIM gXPGain       AS INTEGER
DIM gGoldGain     AS INTEGER
DIM gBossDefeated AS INTEGER
DIM gDef0 AS INTEGER
DIM gDef1 AS INTEGER

' ---- Smoke / progress ----
DIM gSmokeSteps  AS INTEGER
DIM gSmokePhase  AS INTEGER
DIM gStepsEnc    AS INTEGER

' ---- Forward declarations ----
DECLARE SUB InitGame(BYVAL d AS INTEGER)
DECLARE SUB SetupPalette(BYVAL d AS INTEGER)
DECLARE SUB DrawWindow(BYVAL x1 AS INTEGER, BYVAL y1 AS INTEGER, _
                       BYVAL x2 AS INTEGER, BYVAL y2 AS INTEGER)
DECLARE SUB DrawHPBar(BYVAL bx AS INTEGER, BYVAL by AS INTEGER, _
                      BYVAL cur AS INTEGER, BYVAL maxv AS INTEGER, _
                      BYVAL barW AS INTEGER)
DECLARE SUB DrawMPBar(BYVAL bx AS INTEGER, BYVAL by AS INTEGER, _
                      BYVAL cur AS INTEGER, BYVAL maxv AS INTEGER, _
                      BYVAL barW AS INTEGER)
DECLARE SUB PrintTxt(BYVAL tx AS INTEGER, BYVAL ty AS INTEGER, _
                     BYVAL tc AS BYTE, BYVAL ts AS STRING)
DECLARE SUB DoOverworld(BYVAL d AS INTEGER)
DECLARE FUNCTION CanWalk(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER) AS INTEGER
DECLARE FUNCTION GetTile(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER) AS STRING
DECLARE SUB DrawOverworld(BYVAL d AS INTEGER)
DECLARE SUB DrawTile(BYVAL tx AS WORD, BYVAL ty AS WORD, _
                     BYVAL tx2 AS WORD, BYVAL ty2 AS WORD, _
                     BYVAL tch AS STRING)
DECLARE SUB DrawHeroSprite(BYVAL spx AS WORD, BYVAL spy AS WORD, _
                            BYVAL hi AS INTEGER)
DECLARE SUB StartBattle(BYVAL isBoss AS INTEGER)
DECLARE SUB DoBattle(BYVAL d AS INTEGER)
DECLARE SUB BattleMenuInput(BYVAL d AS INTEGER)
DECLARE SUB ExecuteHeroAction(BYVAL d AS INTEGER)
DECLARE SUB DoSpellDamage(BYVAL d AS INTEGER)
DECLARE SUB BattleAnimation(BYVAL d AS INTEGER)
DECLARE SUB CheckAllDead(BYVAL d AS INTEGER)
DECLARE SUB AdvanceTurn(BYVAL d AS INTEGER)
DECLARE SUB EnemyTurn(BYVAL d AS INTEGER)
DECLARE SUB DrawBattleScene(BYVAL d AS INTEGER)
DECLARE SUB DrawHeroBig(BYVAL hbx AS WORD, BYVAL hby AS WORD, _
                         BYVAL hi AS INTEGER)
DECLARE SUB DrawMonster(BYVAL mx AS WORD, BYVAL my AS WORD, _
                         BYVAL mi AS INTEGER)
DECLARE SUB DrawBossMonster(BYVAL bx AS WORD, BYVAL by AS WORD)
DECLARE SUB DrawBattleHUD(BYVAL d AS INTEGER)
DECLARE SUB DrawBattleMenu(BYVAL d AS INTEGER)
DECLARE SUB DoGameOver(BYVAL d AS INTEGER)
DECLARE SUB DoVictory(BYVAL d AS INTEGER)

' ============================================================
' MAIN
' ============================================================
CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)

IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN gSmoke = 1

CALL SetupPalette(0)
CALL Fonts_InitFont("FONT8.TXT", 0)
CALL InitGame(0)

DO
    gFrame = gFrame + 1
    IF gFrame > 30000 THEN gFrame = 1
    IF gSmoke = 1 AND gFrame >= 400 THEN gQuit = 1

    IF gScene = 0 THEN
        CALL DoOverworld(0)
    ELSEIF gScene = 1 THEN
        CALL DoBattle(0)
    ELSEIF gScene = 2 THEN
        CALL DoGameOver(0)
    ELSEIF gScene = 3 THEN
        CALL DoVictory(0)
    END IF

    IF gSmoke = 0 THEN
        DIM kv AS INTEGER
        kv = INP(&H60)
        IF kv = 1 THEN gQuit = 1
    END IF

    IF gQuit = 1 THEN EXIT LOOP
LOOP

CALL Vesa_Close(0)

IF gSmoke = 1 THEN
    OPEN "SMOKE.OK" FOR OUTPUT AS #1
    PRINT #1, "OK " + Svga_Version$
    CLOSE #1
END IF
END

' ============================================================
SUB InitGame(BYVAL d AS INTEGER)
' ============================================================
    gScene       = 0
    gFrame       = 0
    gQuit        = 0
    gPX          = 3
    gPY          = 4
    gStepsEnc    = 0
    gBossDefeated = 0
    gSmokeSteps  = 0
    gSmokePhase  = 0

    gHName0 = "KNIGHT"
    gHName1 = "MAGE  "
    gHeroHP(0)    = 60 : gHeroMaxHP(0) = 60
    gHeroHP(1)    = 40 : gHeroMaxHP(1) = 40
    gHeroMP(0)    = 0  : gHeroMaxMP(0) = 0
    gHeroMP(1)    = 20 : gHeroMaxMP(1) = 20
    gHeroAtk(0)   = 12 : gHeroDef(0) = 6
    gHeroAtk(1)   = 8  : gHeroDef(1) = 3
    gHeroXP       = 0
    gHeroGold     = 0
    gDef0 = 0 : gDef1 = 0
END SUB

' ============================================================
SUB SetupPalette(BYVAL d AS INTEGER)
' ============================================================
    DIM i AS INTEGER
    DIM wgi AS INTEGER
    DIM bgi AS INTEGER

    ' Greens 16-20
    CALL Svga_SetPalette(16, 0, 22, 0)
    CALL Svga_SetPalette(17, 0, 30, 0)
    CALL Svga_SetPalette(18, 8, 34, 4)
    CALL Svga_SetPalette(19, 0, 14, 0)
    CALL Svga_SetPalette(20, 20, 10, 0)
    ' Path 21-22
    CALL Svga_SetPalette(21, 34, 28, 14)
    CALL Svga_SetPalette(22, 26, 20, 8)
    ' Mountain 23-24
    CALL Svga_SetPalette(23, 28, 26, 26)
    CALL Svga_SetPalette(24, 18, 16, 18)
    ' Town 25-26
    CALL Svga_SetPalette(25, 38, 8, 8)
    CALL Svga_SetPalette(26, 34, 30, 18)
    ' Cave 27-28
    CALL Svga_SetPalette(27, 6, 6, 8)
    CALL Svga_SetPalette(28, 16, 14, 16)
    ' Player 29-30
    CALL Svga_SetPalette(29, 4, 10, 38)
    CALL Svga_SetPalette(30, 18, 26, 61)
    ' Spare 31
    CALL Svga_SetPalette(31, 0, 0, 0)

    ' Blue window gradient 32-39
    FOR wgi = 0 TO 7
        CALL Svga_SetPalette(32 + wgi, wgi * 2, wgi * 3, 10 + wgi * 6)
    NEXT wgi

    ' Parchment/gold 40-44
    CALL Svga_SetPalette(40, 63, 58, 30)
    CALL Svga_SetPalette(41, 63, 50, 10)
    CALL Svga_SetPalette(42, 50, 40, 10)
    CALL Svga_SetPalette(43, 63, 63, 40)
    CALL Svga_SetPalette(44, 10, 10, 30)

    ' Skin / armor 48-55
    CALL Svga_SetPalette(48, 55, 35, 20)
    CALL Svga_SetPalette(49, 40, 25, 12)
    CALL Svga_SetPalette(50, 18, 18, 50)
    CALL Svga_SetPalette(51, 30, 30, 63)
    CALL Svga_SetPalette(52, 50, 50, 50)
    CALL Svga_SetPalette(53, 35, 10, 35)
    CALL Svga_SetPalette(54, 55, 20, 55)
    CALL Svga_SetPalette(55, 63, 63, 10)

    ' Monster colors 56-63
    CALL Svga_SetPalette(56, 20, 50, 20)
    CALL Svga_SetPalette(57, 10, 35, 10)
    CALL Svga_SetPalette(58, 40, 30, 10)
    CALL Svga_SetPalette(59, 25, 18, 5)
    CALL Svga_SetPalette(60, 63, 5, 5)
    CALL Svga_SetPalette(61, 40, 0, 0)
    CALL Svga_SetPalette(62, 63, 0, 40)
    CALL Svga_SetPalette(63, 10, 0, 0)

    ' Battle/damage colors 64-71
    CALL Svga_SetPalette(64, 63, 10, 10)
    CALL Svga_SetPalette(65, 63, 40, 0)
    CALL Svga_SetPalette(66, 30, 60, 30)
    CALL Svga_SetPalette(67, 63, 63, 63)
    CALL Svga_SetPalette(68, 63, 63, 0)
    CALL Svga_SetPalette(69, 60, 55, 10)
    CALL Svga_SetPalette(70, 0, 20, 50)
    CALL Svga_SetPalette(71, 0, 4, 8)

    ' Sky gradient 72-79
    FOR bgi = 0 TO 7
        CALL Svga_SetPalette(72 + bgi, bgi * 2, bgi * 3 + 4, bgi * 5 + 8)
    NEXT bgi
END SUB

' ============================================================
SUB DrawWindow(BYVAL x1 AS INTEGER, BYVAL y1 AS INTEGER, _
               BYVAL x2 AS INTEGER, BYVAL y2 AS INTEGER)
' ============================================================
    DIM xw AS WORD, yw AS WORD, xw2 AS WORD, yw2 AS WORD
    DIM row AS INTEGER
    DIM totalH AS INTEGER
    DIM bIdx AS INTEGER
    DIM bc AS BYTE

    xw = x1 + 3 : yw = y1 + 3 : xw2 = x2 + 3 : yw2 = y2 + 3
    CALL Svga_FillRect(xw, yw, xw2, yw2, 44)

    totalH = y2 - y1 - 2
    IF totalH < 1 THEN totalH = 1
    FOR row = 0 TO totalH - 1
        bIdx = (row * 8) \ (totalH + 1)
        IF bIdx > 7 THEN bIdx = 7
        bc = 32 + bIdx
        xw = x1 + 2 : yw = y1 + 2 + row : xw2 = x2 - 2
        CALL Svga_HLine(xw, xw2, yw, bc)
    NEXT row

    xw = x1 : yw = y1 : xw2 = x2 : yw2 = y2
    CALL Svga_DrawRect(xw, yw, xw2, yw2, 44)
    xw = x1 + 1 : yw = y1 + 1 : xw2 = x2 - 1 : yw2 = y2 - 1
    CALL Svga_DrawRect(xw, yw, xw2, yw2, 39)
END SUB

' ============================================================
SUB DrawHPBar(BYVAL bx AS INTEGER, BYVAL by AS INTEGER, _
              BYVAL cur AS INTEGER, BYVAL maxv AS INTEGER, _
              BYVAL barW AS INTEGER)
' ============================================================
    DIM bxw AS WORD, byw AS WORD, bxw2 AS WORD, byw2 AS WORD
    DIM fW AS INTEGER
    DIM fc AS BYTE

    bxw = bx : byw = by : bxw2 = bx + barW : byw2 = by + 3
    CALL Svga_FillRect(bxw, byw, bxw2, byw2, 71)
    IF cur > 0 AND maxv > 0 THEN
        fW = (cur * barW) \ maxv
        IF fW < 1 THEN fW = 1
        IF cur > (maxv \ 2) THEN
            fc = 66
        ELSEIF cur > (maxv \ 4) THEN
            fc = 65
        ELSE
            fc = 64
        END IF
        bxw2 = bx + fW
        CALL Svga_FillRect(bxw, byw, bxw2, byw2, fc)
    END IF
    bxw = bx : byw = by : bxw2 = bx + barW : byw2 = by + 3
    CALL Svga_DrawRect(bxw, byw, bxw2, byw2, 40)
END SUB

' ============================================================
SUB DrawMPBar(BYVAL bx AS INTEGER, BYVAL by AS INTEGER, _
              BYVAL cur AS INTEGER, BYVAL maxv AS INTEGER, _
              BYVAL barW AS INTEGER)
' ============================================================
    DIM bxw AS WORD, byw AS WORD, bxw2 AS WORD, byw2 AS WORD
    DIM fW AS INTEGER

    bxw = bx : byw = by : bxw2 = bx + barW : byw2 = by + 3
    CALL Svga_FillRect(bxw, byw, bxw2, byw2, 71)
    IF cur > 0 AND maxv > 0 THEN
        fW = (cur * barW) \ maxv
        IF fW < 1 THEN fW = 1
        bxw2 = bx + fW
        CALL Svga_FillRect(bxw, byw, bxw2, byw2, 70)
    END IF
    bxw = bx : byw = by : bxw2 = bx + barW : byw2 = by + 3
    CALL Svga_DrawRect(bxw, byw, bxw2, byw2, 40)
END SUB

' ============================================================
SUB PrintTxt(BYVAL tx AS INTEGER, BYVAL ty AS INTEGER, _
             BYVAL tc AS BYTE, BYVAL ts AS STRING)
' ============================================================
    DIM txw AS WORD, tyw AS WORD
    txw = tx : tyw = ty
    CALL Fonts_VgaPrint(txw, tyw, tc, 0, ts, 0)
END SUB

' ============================================================
SUB DoOverworld(BYVAL d AS INTEGER)
' ============================================================
    DIM moved AS INTEGER
    DIM kraw  AS INTEGER
    DIM chance AS INTEGER
    DIM tc AS STRING
    DIM sd AS INTEGER

    moved = 0

    IF gSmoke = 0 THEN
        kraw = INP(&H60)
        SELECT CASE kraw
            CASE 72
                IF gPY > 0 THEN
                    IF CanWalk(gPX, gPY - 1) THEN
                        gPY = gPY - 1 : moved = 1
                    END IF
                END IF
            CASE 80
                IF gPY < %MAP_ROWS - 1 THEN
                    IF CanWalk(gPX, gPY + 1) THEN
                        gPY = gPY + 1 : moved = 1
                    END IF
                END IF
            CASE 75
                IF gPX > 0 THEN
                    IF CanWalk(gPX - 1, gPY) THEN
                        gPX = gPX - 1 : moved = 1
                    END IF
                END IF
            CASE 77
                IF gPX < %MAP_COLS - 1 THEN
                    IF CanWalk(gPX + 1, gPY) THEN
                        gPX = gPX + 1 : moved = 1
                    END IF
                END IF
        END SELECT
    ELSE
        sd = gFrame MOD 3
        IF gSmokePhase = 0 THEN
            IF gPX < %MAP_COLS - 1 THEN
                IF CanWalk(gPX + 1, gPY) THEN
                    gPX = gPX + 1 : moved = 1
                END IF
            END IF
            IF moved = 0 THEN
                IF gPY < %MAP_ROWS - 1 THEN
                    IF CanWalk(gPX, gPY + 1) THEN
                        gPY = gPY + 1 : moved = 1
                    END IF
                END IF
            END IF
        ELSEIF gSmokePhase = 2 THEN
            IF gSmokeSteps < 5 THEN
                IF gPX < %MAP_COLS - 1 THEN
                    IF CanWalk(gPX + 1, gPY) THEN
                        gPX = gPX + 1 : moved = 1
                    END IF
                END IF
                IF moved = 0 THEN
                    IF gPY > 0 THEN
                        IF CanWalk(gPX, gPY - 1) THEN
                            gPY = gPY - 1 : moved = 1
                        END IF
                    END IF
                END IF
            ELSE
                gQuit = 1
            END IF
        END IF
    END IF

    IF moved = 1 THEN
        gStepsEnc = gStepsEnc + 1
        IF gSmokePhase = 2 THEN gSmokeSteps = gSmokeSteps + 1
        tc = GetTile(gPX, gPY)
        IF tc = "K" THEN
            CALL StartBattle(1)
        ELSEIF tc = "G" THEN
            IF gSmoke = 1 THEN
                IF gStepsEnc >= 3 THEN CALL StartBattle(0)
            ELSE
                chance = INT(RND * 100)
                IF chance < 25 THEN CALL StartBattle(0)
            END IF
        END IF
    END IF

    CALL DrawOverworld(0)
END SUB

' ============================================================
FUNCTION CanWalk(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER) AS INTEGER
' ============================================================
    DIM tc AS STRING
    tc = GetTile(cx, cy)
    IF tc = "M" OR tc = "T" THEN
        CanWalk = 0
    ELSE
        CanWalk = 1
    END IF
END FUNCTION

' ============================================================
FUNCTION GetTile(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER) AS STRING
' Tile codes: G=grass P=path M=mountain T=tree K=cave
' ============================================================
    DIM tpos AS INTEGER
    DIM ms AS STRING
    ms = "MMMMMMMTTTTTTTTTTMM" + _
         "MTTTTTTPTTTTTTTTTTM" + _
         "MTTTTTGPTTTTGTTTTTT" + _
         "MPPPPPGPGGGGGTTTGTT" + _
         "TGGGGGPGGGGGGGGGGTT" + _
         "TGGGGGPGGGGGGGPPPPM" + _
         "TGKGGGPGGGTTGGPGGMT" + _
         "TGGGGPPGGTTTGGPGGMT" + _
         "TGGPPPGGGTTTGGPGGMT" + _
         "TGGPTTGGGGTGGPPGGMT" + _
         "TGGPTTTGGGGGGGGGPMT" + _
         "MMMPTTTTGGGGGGGPMMM"
    tpos = cy * %MAP_COLS + cx + 1
    GetTile = MID$(ms, tpos, 1)
END FUNCTION

' ============================================================
SUB DrawOverworld(BYVAL d AS INTEGER)
' ============================================================
    DIM tx AS INTEGER, ty AS INTEGER
    DIM px AS WORD, py AS WORD, px2 AS WORD, py2 AS WORD
    DIM tc AS STRING
    DIM spx AS WORD, spy AS WORD
    DIM sv AS STRING

    CALL Svga_FillRect(0, 0, 319, 199, 71)

    FOR ty = 0 TO %MAP_ROWS - 1
        FOR tx = 0 TO %MAP_COLS - 1
            tc = GetTile(tx, ty)
            px  = tx * %TILE_W
            py  = ty * %TILE_H + 8
            px2 = px + %TILE_W - 1
            py2 = py + %TILE_H - 1
            CALL DrawTile(px, py, px2, py2, tc)
        NEXT tx
    NEXT ty

    spx = gPX * %TILE_W + 2
    spy = gPY * %TILE_H + 8 + 1
    CALL DrawHeroSprite(spx, spy, 0)

    CALL DrawWindow(0, 0, 319, 7)
    sv = gHName0 + " HP:" + LTRIM$(STR$(gHeroHP(0)))
    sv = sv + "  " + gHName1 + " HP:" + LTRIM$(STR$(gHeroHP(1)))
    CALL PrintTxt(4, 1, 40, sv)
END SUB

' ============================================================
SUB DrawTile(BYVAL tx AS WORD, BYVAL ty AS WORD, _
             BYVAL tx2 AS WORD, BYVAL ty2 AS WORD, _
             BYVAL tch AS STRING)
' ============================================================
    DIM c1 AS BYTE, c2 AS BYTE
    DIM gx AS WORD, gy AS WORD
    DIM hx1 AS WORD, hx2 AS WORD, hy AS WORD
    DIM mx1 AS WORD, mx2 AS WORD, mx3 AS WORD
    DIM my1 AS WORD, my2 AS WORD
    DIM fcx AS WORD, fcy AS WORD, fcr AS WORD
    DIM vx AS WORD, vy1 AS WORD, vy2 AS WORD
    DIM cax AS WORD, cay AS WORD, car AS WORD
    DIM ch AS STRING

    ch = LEFT$(tch, 1)
    IF ch = "G" THEN
        c1 = 17 : c2 = 18
        CALL Svga_FillRect(tx, ty, tx2, ty2, c1)
        gx = tx + 2 : gy = ty + 3  : CALL Svga_PutPixel(gx, gy, c2)
        gx = tx + 6 : gy = ty + 7  : CALL Svga_PutPixel(gx, gy, c2)
        gx = tx + 9 : gy = ty + 2  : CALL Svga_PutPixel(gx, gy, c2)
    ELSEIF ch = "P" THEN
        c1 = 21 : c2 = 22
        CALL Svga_FillRect(tx, ty, tx2, ty2, c1)
        hx1 = tx : hx2 = tx2 : hy = ty2
        CALL Svga_HLine(hx1, hx2, hy, c2)
    ELSEIF ch = "M" THEN
        c1 = 23 : c2 = 24
        CALL Svga_FillRect(tx, ty, tx2, ty2, c2)
        mx1 = tx + %TILE_W \ 2 : my1 = ty
        mx2 = tx : my2 = ty2 : mx3 = tx2
        CALL Svga_LineDraw(mx1, my1, mx2, my2, c1)
        CALL Svga_LineDraw(mx1, my1, mx3, my2, c1)
    ELSEIF ch = "T" THEN
        c1 = 19 : c2 = 20
        CALL Svga_FillRect(tx, ty, tx2, ty2, 17)
        fcx = tx + %TILE_W \ 2
        fcy = ty + %TILE_H \ 3
        fcr = %TILE_W \ 2 - 1
        CALL Svga_FillCircle(fcx, fcy, fcr, c1)
        CALL Svga_DrawCircle(fcx, fcy, fcr, c2)
        vx = tx + %TILE_W \ 2
        vy1 = ty + %TILE_H \ 2 : vy2 = ty2
        CALL Svga_VLine(vx, vy1, vy2, c2)
    ELSEIF ch = "K" THEN
        c1 = 27 : c2 = 28
        CALL Svga_FillRect(tx, ty, tx2, ty2, c2)
        cax = tx + %TILE_W \ 2
        cay = ty + %TILE_H - 3
        car = %TILE_W \ 2 - 1
        CALL Svga_FillCircle(cax, cay, car, c1)
    ELSE
        CALL Svga_FillRect(tx, ty, tx2, ty2, 17)
    END IF
END SUB

' ============================================================
SUB DrawHeroSprite(BYVAL spx AS WORD, BYVAL spy AS WORD, _
                   BYVAL hi AS INTEGER)
' ============================================================
    DIM skin AS BYTE, arm AS BYTE, arm2 AS BYTE
    DIM hx AS WORD, hy AS WORD, hx2 AS WORD, hy2 AS WORD

    IF hi = 0 THEN
        skin = 48 : arm = 50 : arm2 = 51
    ELSE
        skin = 48 : arm = 53 : arm2 = 54
    END IF
    hx = spx + 3 : hy = spy : hx2 = hx + 2 : hy2 = hy + 2
    CALL Svga_FillRect(hx, hy, hx2, hy2, skin)
    hx = spx + 2 : hy = spy + 3 : hx2 = hx + 4 : hy2 = hy + 3
    CALL Svga_FillRect(hx, hy, hx2, hy2, arm)
    hx = spx + 3 : hy = spy + 3
    CALL Svga_PutPixel(hx, hy, arm2)
    hx = spx + 2 : hy = spy + 7 : hx2 = hx + 1 : hy2 = hy + 2
    CALL Svga_FillRect(hx, hy, hx2, hy2, arm)
    hx = spx + 5 : hy = spy + 7 : hx2 = hx + 1 : hy2 = hy + 2
    CALL Svga_FillRect(hx, hy, hx2, hy2, arm)
END SUB

' ============================================================
SUB StartBattle(BYVAL isBoss AS INTEGER)
' ============================================================
    DIM rmon AS INTEGER

    gScene        = 1
    gIsBoss       = isBoss
    gBattleTurn   = 0
    gMenuSel      = 0
    gBattlePhase  = 0
    gBattleMsg    = ""
    gBattleMsgTmr = 0
    gAnimTmr      = 0
    gAnimLunge    = 0
    gAnimHero     = 0
    gBattleOver   = 0
    gDmgShow(0)   = 0 : gDmgShow(1) = 0
    gDef0 = 0 : gDef1 = 0
    gStepsEnc     = 0

    IF gSmoke = 1 THEN gSmokePhase = 1

    RANDOMIZE 42
    IF isBoss = 1 THEN
        gMonCount    = 1
        gMName0      = "DEMON "
        gMonHP(0)    = 80
        gMonMaxHP(0) = 80
        gMonAtk(0)   = 18
        gMonDef(0)   = 8
        gMonAlive(0) = 1
    ELSE
        rmon = INT(RND * 2) + 1
        gMonCount    = rmon
        gMName0      = "SLIME "
        gMonHP(0)    = 20
        gMonMaxHP(0) = 20
        gMonAtk(0)   = 6
        gMonDef(0)   = 2
        gMonAlive(0) = 1
        IF rmon = 2 THEN
            gMName1      = "WOLF  "
            gMonHP(1)    = 28
            gMonMaxHP(1) = 28
            gMonAtk(1)   = 9
            gMonDef(1)   = 3
            gMonAlive(1) = 1
        END IF
    END IF

    gXPGain   = 0
    gGoldGain = 0
    DIM mi AS INTEGER
    FOR mi = 0 TO gMonCount - 1
        gXPGain   = gXPGain   + gMonMaxHP(mi) \ 2
        gGoldGain = gGoldGain + gMonMaxHP(mi) \ 3
    NEXT mi
    IF isBoss = 1 THEN
        gXPGain   = gXPGain   + 50
        gGoldGain = gGoldGain + 30
    END IF
END SUB

' ============================================================
SUB DoBattle(BYVAL d AS INTEGER)
' ============================================================
    DIM ddi AS INTEGER

    CALL DrawBattleScene(0)

    SELECT CASE gBattlePhase
        CASE 0
            CALL BattleMenuInput(0)
        CASE 1
            CALL BattleAnimation(0)
        CASE 2
            gBattleMsgTmr = gBattleMsgTmr + 1
            IF gBattleMsgTmr > 40 OR gSmoke = 1 THEN
                gBattleMsg    = ""
                gBattleMsgTmr = 0
                CALL AdvanceTurn(0)
            END IF
        CASE 3
            CALL EnemyTurn(0)
    END SELECT

    FOR ddi = 0 TO 1
        IF gDmgShow(ddi) = 1 THEN
            gDmgY(ddi) = gDmgY(ddi) - 1
            IF gDmgY(ddi) < -20 THEN gDmgShow(ddi) = 0
        END IF
    NEXT ddi

    IF gBattleOver = 1 THEN
        gHeroXP   = gHeroXP   + gXPGain
        gHeroGold = gHeroGold + gGoldGain
        IF gIsBoss = 1 THEN
            gBossDefeated = 1
            gScene = 3
        ELSE
            gScene = 0
            IF gSmoke = 1 THEN
                gSmokePhase = 2
                gSmokeSteps = 0
            END IF
        END IF
    ELSEIF gBattleOver = 2 THEN
        gScene = 2
    END IF
END SUB

' ============================================================
SUB BattleMenuInput(BYVAL d AS INTEGER)
' ============================================================
    DIM kv AS INTEGER

    IF gBattleTurn >= 2 THEN
        gBattlePhase = 3
        EXIT SUB
    END IF

    IF gSmoke = 1 THEN
        IF gBattleTurn = 0 THEN
            gMenuSel = 0
        ELSE
            IF gHeroMP(1) >= 5 THEN
                gMenuSel = 1
            ELSE
                gMenuSel = 0
            END IF
        END IF
        CALL ExecuteHeroAction(0)
        EXIT SUB
    END IF

    kv = INP(&H60)
    SELECT CASE kv
        CASE 72
            gMenuSel = gMenuSel - 1
            IF gMenuSel < 0 THEN gMenuSel = 3
        CASE 80
            gMenuSel = gMenuSel + 1
            IF gMenuSel > 3 THEN gMenuSel = 0
        CASE 28
            CALL ExecuteHeroAction(0)
    END SELECT
END SUB

' ============================================================
SUB ExecuteHeroAction(BYVAL d AS INTEGER)
' ============================================================
    DIM hi AS INTEGER
    DIM tg AS INTEGER

    hi = gBattleTurn
    gAnimHero = hi

    SELECT CASE gMenuSel
        CASE 0
            gBattlePhase = 1
            gAnimTmr     = 0
            gAnimLunge   = 0
            IF hi = 0 THEN gDef0 = 0 ELSE gDef1 = 0
        CASE 1
            IF hi = 1 THEN
                IF gHeroMP(1) >= 5 THEN
                    gHeroMP(1) = gHeroMP(1) - 5
                    CALL DoSpellDamage(0)
                    gBattlePhase  = 2
                    gBattleMsg    = "FIRE! Hits all foes!"
                    gBattleMsgTmr = 0
                ELSE
                    gBattleMsg    = "Not enough MP!"
                    gBattleMsgTmr = 0
                    gBattlePhase  = 2
                END IF
            ELSE
                gHeroHP(0) = gHeroHP(0) + 15
                IF gHeroHP(0) > gHeroMaxHP(0) THEN _
                    gHeroHP(0) = gHeroMaxHP(0)
                gBattleMsg    = "KNIGHT uses Potion!"
                gBattleMsgTmr = 0
                gBattlePhase  = 2
            END IF
            IF hi = 0 THEN gDef0 = 0 ELSE gDef1 = 0
        CASE 2
            IF hi = 0 THEN gDef0 = 1 ELSE gDef1 = 1
            IF hi = 0 THEN
                gBattleMsg = gHName0 + " defends!"
            ELSE
                gBattleMsg = gHName1 + " defends!"
            END IF
            gBattleMsgTmr = 0
            gBattlePhase  = 2
        CASE 3
            tg = 1 - hi
            gHeroHP(tg) = gHeroHP(tg) + 12
            IF gHeroHP(tg) > gHeroMaxHP(tg) THEN _
                gHeroHP(tg) = gHeroMaxHP(tg)
            gBattleMsg    = "Used Herb! +12HP"
            gBattleMsgTmr = 0
            gBattlePhase  = 2
            IF hi = 0 THEN gDef0 = 0 ELSE gDef1 = 0
    END SELECT
END SUB

' ============================================================
SUB DoSpellDamage(BYVAL d AS INTEGER)
' Fire: Mage ATK*2 - monDef, minimum 1
' ============================================================
    DIM mi AS INTEGER
    DIM dmg AS INTEGER
    DIM rv AS INTEGER

    FOR mi = 0 TO gMonCount - 1
        IF gMonAlive(mi) = 1 THEN
            dmg = gHeroAtk(1) * 2 - gMonDef(mi)
            IF dmg < 1 THEN dmg = 1
            rv = INT(RND * 5) - 2
            dmg = dmg + rv
            IF dmg < 1 THEN dmg = 1
            gMonHP(mi)   = gMonHP(mi) - dmg
            gDmgNum(mi)  = dmg
            gDmgY(mi)    = 0
            gDmgShow(mi) = 1
            IF gMonHP(mi) <= 0 THEN
                gMonHP(mi)    = 0
                gMonAlive(mi) = 0
            END IF
        END IF
    NEXT mi
    CALL CheckAllDead(0)
END SUB

' ============================================================
SUB BattleAnimation(BYVAL d AS INTEGER)
' Lunge-and-strike: hero advances, hits, retracts
' ============================================================
    DIM tgt AS INTEGER
    DIM dmg AS INTEGER
    DIM rv AS INTEGER

    tgt = 0
    gAnimTmr = gAnimTmr + 1

    IF gAnimTmr <= 6 THEN
        gAnimLunge = gAnimTmr * 8
    ELSEIF gAnimTmr = 7 THEN
        dmg = gHeroAtk(gAnimHero) - gMonDef(tgt)
        IF dmg < 1 THEN dmg = 1
        rv = INT(RND * 5) - 2
        dmg = dmg + rv
        IF dmg < 1 THEN dmg = 1
        gMonHP(tgt)  = gMonHP(tgt) - dmg
        gDmgNum(0)   = dmg
        gDmgY(0)     = 0
        gDmgShow(0)  = 1
        IF gMonHP(tgt) <= 0 THEN
            gMonHP(tgt)    = 0
            gMonAlive(tgt) = 0
        END IF
        CALL CheckAllDead(0)
    ELSEIF gAnimTmr <= 12 THEN
        gAnimLunge = (12 - gAnimTmr) * 8
    ELSE
        gAnimLunge    = 0
        gAnimTmr      = 0
        gBattlePhase  = 2
        IF gAnimHero = 0 THEN
            gBattleMsg = gHName0 + " attacks!"
        ELSE
            gBattleMsg = gHName1 + " attacks!"
        END IF
        gBattleMsgTmr = 0
    END IF
END SUB

' ============================================================
SUB CheckAllDead(BYVAL d AS INTEGER)
' ============================================================
    DIM allDead AS INTEGER
    DIM ci AS INTEGER

    allDead = 1
    FOR ci = 0 TO gMonCount - 1
        IF gMonAlive(ci) = 1 THEN allDead = 0
    NEXT ci
    IF allDead = 1 THEN gBattleOver = 1
END SUB

' ============================================================
SUB AdvanceTurn(BYVAL d AS INTEGER)
' ============================================================
    IF gBattleOver <> 0 THEN EXIT SUB

    gBattleTurn = gBattleTurn + 1
    IF gBattleTurn = 2 THEN
        IF gMonAlive(0) = 0 THEN gBattleTurn = 3
    END IF
    IF gBattleTurn = 3 THEN
        IF gMonCount < 2 THEN
            gBattleTurn = 4
        ELSEIF gMonAlive(1) = 0 THEN
            gBattleTurn = 4
        END IF
    END IF
    IF gBattleTurn >= 4 THEN
        gBattleTurn = 0
        gDef0 = 0 : gDef1 = 0
    END IF

    IF gBattleTurn >= 2 THEN
        gBattlePhase = 3
    ELSE
        gBattlePhase = 0
        gMenuSel     = 0
    END IF
END SUB

' ============================================================
SUB EnemyTurn(BYVAL d AS INTEGER)
' ============================================================
    DIM mi AS INTEGER
    DIM tg AS INTEGER
    DIM dmg AS INTEGER
    DIM rv AS INTEGER
    DIM isdef AS INTEGER
    DIM mns AS STRING
    DIM hns AS STRING

    mi = gBattleTurn - 2
    IF mi < 0 THEN mi = 0
    IF mi >= gMonCount THEN
        CALL AdvanceTurn(0)
        EXIT SUB
    END IF
    IF gMonAlive(mi) = 0 THEN
        CALL AdvanceTurn(0)
        EXIT SUB
    END IF

    tg = INT(RND * 2)
    IF gHeroHP(tg) <= 0 THEN tg = 1 - tg
    IF gHeroHP(tg) <= 0 THEN
        gBattleOver = 2
        EXIT SUB
    END IF

    dmg = gMonAtk(mi) - gHeroDef(tg)
    IF tg = 0 THEN isdef = gDef0 ELSE isdef = gDef1
    IF isdef = 1 THEN dmg = dmg \ 2
    IF dmg < 1 THEN dmg = 1
    rv = INT(RND * 4) - 1
    dmg = dmg + rv
    IF dmg < 1 THEN dmg = 1

    gHeroHP(tg) = gHeroHP(tg) - dmg
    IF gHeroHP(tg) < 0 THEN gHeroHP(tg) = 0

    IF mi = 0 THEN mns = gMName0 ELSE mns = gMName1
    IF tg = 0 THEN hns = gHName0 ELSE hns = gHName1
    gBattleMsg = mns + " hits " + hns + "!"
    gBattleMsgTmr = 0
    gBattlePhase  = 2

    IF gHeroHP(0) <= 0 AND gHeroHP(1) <= 0 THEN gBattleOver = 2
END SUB

' ============================================================
SUB DrawBattleScene(BYVAL d AS INTEGER)
' ============================================================
    DIM r AS INTEGER
    DIM bgc AS INTEGER
    DIM lx1 AS WORD, lx2 AS WORD, ly AS WORD
    DIM g1 AS WORD, g2 AS WORD, g3 AS WORD, g4 AS WORD
    DIM hx AS WORD, hy AS WORD
    DIM lng0 AS INTEGER, lng1 AS INTEGER
    DIM mi AS INTEGER
    DIM mox AS WORD, moy AS WORD
    DIM bob AS INTEGER
    DIM dmx AS WORD, dmy AS WORD
    DIM dyb AS INTEGER
    DIM dms AS STRING

    ' Sky gradient
    FOR r = 0 TO 199
        bgc = 72 + (r * 8) \ 200
        IF bgc > 79 THEN bgc = 79
        lx1 = 0 : lx2 = 319 : ly = r
        CALL Svga_HLine(lx1, lx2, ly, bgc)
    NEXT r

    ' Ground strip
    g1 = 0 : g2 = 130 : g3 = 319 : g4 = 145
    CALL Svga_FillRect(g1, g2, g3, g4, 18)

    ' Heroes right side
    lng0 = 0
    IF gBattlePhase = 1 AND gAnimHero = 0 THEN lng0 = gAnimLunge
    hx = 210 - lng0 : hy = 88
    CALL DrawHeroBig(hx, hy, 0)
    lng1 = 0
    IF gBattlePhase = 1 AND gAnimHero = 1 THEN lng1 = gAnimLunge
    hx = 248 - lng1 : hy = 95
    CALL DrawHeroBig(hx, hy, 1)

    ' Monsters left side
    FOR mi = 0 TO gMonCount - 1
        IF gMonAlive(mi) = 1 THEN
            mox = 60 + mi * 55
            bob = gFrame MOD 60
            IF bob > 30 THEN bob = 60 - bob
            moy = 75 + bob \ 10
            CALL DrawMonster(mox, moy, mi)
        END IF
    NEXT mi

    CALL DrawBattleHUD(0)

    IF gBattleMsg <> "" THEN
        CALL DrawWindow(60, 148, 259, 160)
        CALL PrintTxt(65, 151, 40, gBattleMsg)
    END IF

    ' Floating damage numbers
    FOR mi = 0 TO 1
        IF gDmgShow(mi) = 1 THEN
            dmx = 45 + mi * 55
            dyb = 75 + gDmgY(mi)
            IF dyb < 5 THEN dyb = 5
            dmy = dyb
            dms = "-" + LTRIM$(STR$(gDmgNum(mi)))
            CALL PrintTxt(dmx, dmy, 65, dms)
        END IF
    NEXT mi

    IF gBattlePhase = 0 AND gBattleTurn < 2 THEN
        CALL DrawBattleMenu(0)
    END IF
END SUB

' ============================================================
SUB DrawHeroBig(BYVAL hbx AS WORD, BYVAL hby AS WORD, _
                BYVAL hi AS INTEGER)
' ============================================================
    DIM skin AS BYTE, arm AS BYTE, arm2 AS BYTE, armD AS BYTE
    DIM s1 AS WORD, s2 AS WORD, s3 AS WORD, s4 AS WORD
    DIM stx AS WORD, st1 AS WORD, st2 AS WORD
    DIM hcol AS BYTE

    IF hi = 0 THEN
        skin = 48 : arm = 50 : arm2 = 51 : armD = 52
    ELSE
        skin = 48 : arm = 53 : arm2 = 54 : armD = 44
    END IF

    ' Shadow
    s1 = hbx + 2 : s2 = hby + 31 : s3 = hbx + 16 : s4 = hby + 32
    CALL Svga_FillRect(s1, s2, s3, s4, 44)
    ' Head
    s1 = hbx + 6 : s2 = hby : s3 = hbx + 13 : s4 = hby + 7
    CALL Svga_FillRect(s1, s2, s3, s4, skin)
    ' Helmet/hat
    s1 = hbx + 5 : s2 = hby - 2 : s3 = hbx + 14 : s4 = hby
    IF hi = 0 THEN hcol = arm ELSE hcol = arm2
    CALL Svga_FillRect(s1, s2, s3, s4, hcol)
    ' Body
    s1 = hbx + 4 : s2 = hby + 8 : s3 = hbx + 16 : s4 = hby + 18
    CALL Svga_FillRect(s1, s2, s3, s4, arm)
    ' Armor shine
    s1 = hbx + 6 : s2 = hby + 9 : s3 = hbx + 9 : s4 = hby + 12
    CALL Svga_FillRect(s1, s2, s3, s4, arm2)
    ' Arms
    s1 = hbx + 1 : s2 = hby + 8 : s3 = hbx + 3 : s4 = hby + 16
    CALL Svga_FillRect(s1, s2, s3, s4, arm)
    s1 = hbx + 17 : s2 = hby + 8 : s3 = hbx + 19 : s4 = hby + 16
    CALL Svga_FillRect(s1, s2, s3, s4, arm)
    ' Legs
    s1 = hbx + 5 : s2 = hby + 19 : s3 = hbx + 9 : s4 = hby + 29
    CALL Svga_FillRect(s1, s2, s3, s4, armD)
    s1 = hbx + 11 : s2 = hby + 19 : s3 = hbx + 15 : s4 = hby + 29
    CALL Svga_FillRect(s1, s2, s3, s4, armD)
    ' Weapon
    IF hi = 0 THEN
        s1 = hbx + 17 : s2 = hby + 3 : s3 = hbx + 19 : s4 = hby + 14
        CALL Svga_FillRect(s1, s2, s3, s4, 67)
    ELSE
        stx = hbx + 1 : st1 = hby - 4 : st2 = hby + 16
        CALL Svga_VLine(stx, st1, st2, 55)
        CALL Svga_FillCircle(stx, st1, 3, arm2)
    END IF
END SUB

' ============================================================
SUB DrawMonster(BYVAL mx AS WORD, BYVAL my AS WORD, _
                BYVAL mi AS INTEGER)
' ============================================================
    DIM c1 AS BYTE, c2 AS BYTE, c3 AS BYTE
    DIM b1 AS WORD, b2 AS WORD, b3 AS WORD, b4 AS WORD
    DIM shi AS INTEGER
    DIM sx1 AS WORD, sx2 AS WORD, sy AS WORD
    DIM ox AS WORD, oy AS WORD
    DIM t1 AS WORD, t2 AS WORD, t3 AS WORD, t4 AS WORD

    IF gIsBoss = 1 THEN
        CALL DrawBossMonster(mx, my)
        EXIT SUB
    END IF

    IF mi = 0 THEN
        c1 = 56 : c2 = 57 : c3 = 44
        b1 = mx : b2 = my + 12
        CALL Svga_FillCircle(b1, b2, 15, c3)
        CALL Svga_FillCircle(b1, b2, 14, c1)
        FOR shi = 0 TO 8
            sx1 = mx - 13 + shi : sx2 = mx + 13 - shi
            sy = my + 12 + 5 + shi
            IF sy <= my + 26 THEN CALL Svga_HLine(sx1, sx2, sy, c2)
        NEXT shi
        ox = mx - 4 : oy = my + 7
        CALL Svga_FillCircle(ox, oy, 3, 67)
        CALL Svga_PutPixel(mx - 3, my + 10, c3)
        CALL Svga_PutPixel(mx + 3, my + 10, c3)
    ELSE
        c1 = 58 : c2 = 59 : c3 = 44
        b1 = mx - 15 : b2 = my + 4 : b3 = mx + 15 : b4 = my + 22
        CALL Svga_FillRect(b1, b2, b3, b4, c3)
        b1 = mx - 14 : b2 = my + 5 : b3 = mx + 14 : b4 = my + 21
        CALL Svga_FillRect(b1, b2, b3, b4, c1)
        b1 = mx + 2 : b2 = my + 6 : b3 = mx + 14 : b4 = my + 20
        CALL Svga_FillRect(b1, b2, b3, b4, c2)
        b1 = mx - 18 : b2 = my : b3 = mx - 8 : b4 = my + 10
        CALL Svga_FillRect(b1, b2, b3, b4, c1)
        b1 = mx - 22 : b2 = my + 4 : b3 = mx - 14 : b4 = my + 8
        CALL Svga_FillRect(b1, b2, b3, b4, c1)
        CALL Svga_PutPixel(mx - 15, my + 3, c3)
        b1 = mx - 10 : b2 = my + 22 : b3 = mx - 7 : b4 = my + 30
        CALL Svga_FillRect(b1, b2, b3, b4, c2)
        b1 = mx : b2 = my + 22 : b3 = mx + 3 : b4 = my + 30
        CALL Svga_FillRect(b1, b2, b3, b4, c2)
        t1 = mx + 12 : t2 = my : t3 = mx + 18 : t4 = my + 8
        CALL Svga_LineDraw(t1, t2, t3, t4, c1)
    END IF
END SUB

' ============================================================
SUB DrawBossMonster(BYVAL bx AS WORD, BYVAL by AS WORD)
' ============================================================
    DIM b1 AS WORD, b2 AS WORD, b3 AS WORD, b4 AS WORD
    DIM gr AS INTEGER
    DIM gox AS WORD, goy AS WORD, gorw AS WORD
    DIM h1 AS WORD, h2 AS WORD, h3 AS WORD, h4 AS WORD

    b1 = bx - 22 : b2 = by : b3 = bx + 22 : b4 = by + 40
    CALL Svga_FillRect(b1, b2, b3, b4, 63)
    b1 = bx - 20 : b2 = by + 1 : b3 = bx + 20 : b4 = by + 39
    CALL Svga_FillRect(b1, b2, b3, b4, 60)
    b1 = bx + 8 : b2 = by + 2 : b3 = bx + 19 : b4 = by + 38
    CALL Svga_FillRect(b1, b2, b3, b4, 61)

    gr = 22 + (gFrame MOD 8)
    gox = bx : goy = by + 20 : gorw = gr
    CALL Svga_DrawCircle(gox, goy, gorw, 62)

    b1 = bx - 14 : b2 = by - 15 : b3 = bx + 14 : b4 = by + 1
    CALL Svga_FillRect(b1, b2, b3, b4, 60)

    h1 = bx - 12 : h2 = by - 15 : h3 = bx - 18 : h4 = by - 25
    CALL Svga_LineDraw(h1, h2, h3, h4, 60)
    h1 = bx + 12 : h3 = bx + 18
    CALL Svga_LineDraw(h1, h2, h3, h4, 60)

    DIM ecx AS WORD, ecy AS WORD
    ecx = bx - 6 : ecy = by - 8
    CALL Svga_FillCircle(ecx, ecy, 3, 62)
    ecx = bx + 6
    CALL Svga_FillCircle(ecx, ecy, 3, 62)

    b1 = bx - 30 : b2 = by + 5 : b3 = bx - 22 : b4 = by + 20
    CALL Svga_FillRect(b1, b2, b3, b4, 60)
    b1 = bx + 22 : b2 = by + 5 : b3 = bx + 30 : b4 = by + 20
    CALL Svga_FillRect(b1, b2, b3, b4, 60)
    b1 = bx - 16 : b2 = by + 40 : b3 = bx - 8 : b4 = by + 52
    CALL Svga_FillRect(b1, b2, b3, b4, 61)
    b1 = bx + 8 : b2 = by + 40 : b3 = bx + 16 : b4 = by + 52
    CALL Svga_FillRect(b1, b2, b3, b4, 61)
END SUB

' ============================================================
SUB DrawBattleHUD(BYVAL d AS INTEGER)
' ============================================================
    DIM s0 AS STRING, s1 AS STRING, sm AS STRING
    DIM hp0s AS STRING, hp1s AS STRING
    DIM mi AS INTEGER
    DIM mstr AS STRING, mhps AS STRING
    DIM yoff AS INTEGER

    CALL DrawWindow(0, 162, 158, 199)

    s0 = gHName0 + " HP"
    s1 = gHName1 + " HP"
    CALL PrintTxt(4, 165, 43, s0)
    CALL DrawHPBar(4, 173, gHeroHP(0), gHeroMaxHP(0), 70)
    hp0s = LTRIM$(STR$(gHeroHP(0))) + "/" + LTRIM$(STR$(gHeroMaxHP(0)))
    CALL PrintTxt(4, 177, 40, hp0s)

    CALL PrintTxt(4, 184, 43, s1)
    CALL DrawHPBar(4, 192, gHeroHP(1), gHeroMaxHP(1), 70)
    hp1s = LTRIM$(STR$(gHeroHP(1))) + "/" + LTRIM$(STR$(gHeroMaxHP(1)))
    CALL PrintTxt(4, 196, 40, hp1s)

    sm = "MP:" + LTRIM$(STR$(gHeroMP(1)))
    CALL PrintTxt(80, 184, 70, sm)
    CALL DrawMPBar(80, 192, gHeroMP(1), gHeroMaxMP(1), 40)

    CALL DrawWindow(161, 162, 319, 199)
    FOR mi = 0 TO gMonCount - 1
        yoff = mi * 18
        IF mi = 0 THEN mstr = gMName0 ELSE mstr = gMName1
        IF gMonAlive(mi) = 1 THEN
            CALL PrintTxt(165, 165 + yoff, 43, mstr)
            CALL DrawHPBar(165, 173 + yoff, gMonHP(mi), gMonMaxHP(mi), 60)
            mhps = LTRIM$(STR$(gMonHP(mi))) + "/" + _
                   LTRIM$(STR$(gMonMaxHP(mi)))
            CALL PrintTxt(165, 177 + yoff, 40, mhps)
        ELSE
            CALL PrintTxt(165, 165 + yoff, 44, mstr + " DEAD")
        END IF
    NEXT mi
END SUB

' ============================================================
SUB DrawBattleMenu(BYVAL d AS INTEGER)
' ============================================================
    DIM hi AS INTEGER
    DIM ns AS STRING
    DIM mi AS INTEGER
    DIM ic AS BYTE
    DIM m0 AS STRING, m1 AS STRING, m2 AS STRING, m3 AS STRING

    hi = gBattleTurn
    CALL DrawWindow(160, 98, 319, 160)

    IF hi = 0 THEN ns = gHName0 + " TURN" ELSE ns = gHName1 + " TURN"
    CALL PrintTxt(165, 101, 41, ns)

    m0 = "ATTACK" : m2 = "DEFEND" : m3 = "ITEM  "
    IF hi = 0 THEN m1 = "POTION" ELSE m1 = "FIRE  "

    FOR mi = 0 TO 3
        ic = 40
        IF mi = gMenuSel THEN
            CALL PrintTxt(162, 112 + mi * 10, 41, ">")
            ic = 43
        END IF
        IF mi = 0 THEN CALL PrintTxt(170, 112 + mi * 10, ic, m0)
        IF mi = 1 THEN CALL PrintTxt(170, 112 + mi * 10, ic, m1)
        IF mi = 2 THEN CALL PrintTxt(170, 112 + mi * 10, ic, m2)
        IF mi = 3 THEN CALL PrintTxt(170, 112 + mi * 10, ic, m3)
    NEXT mi
END SUB

' ============================================================
SUB DoGameOver(BYVAL d AS INTEGER)
' ============================================================
    DIM kv AS INTEGER
    CALL Svga_FillRect(0, 0, 319, 199, 63)
    CALL DrawWindow(60, 70, 259, 130)
    CALL PrintTxt(95, 82, 64, "GAME  OVER")
    CALL PrintTxt(70, 100, 40, "Your party was defeated...")
    CALL PrintTxt(80, 116, 42, "Press ESC to quit")
    IF gSmoke = 1 THEN
        gQuit = 1
    ELSE
        kv = INP(&H60)
        IF kv = 1 THEN gQuit = 1
    END IF
END SUB

' ============================================================
SUB DoVictory(BYVAL d AS INTEGER)
' ============================================================
    DIM kv AS INTEGER
    DIM xs AS STRING, gs AS STRING, ts AS STRING

    CALL Svga_FillRect(0, 0, 319, 199, 71)
    CALL DrawWindow(40, 20, 279, 90)
    CALL PrintTxt(95, 30, 41, "VICTORY!")
    IF gBossDefeated = 1 THEN
        CALL PrintTxt(55, 45, 43, "The Demon is vanquished!")
        CALL PrintTxt(55, 58, 43, "The kingdom is saved!")
    END IF

    CALL DrawWindow(60, 95, 259, 155)
    xs = "XP gained:   " + LTRIM$(STR$(gXPGain))
    gs = "Gold gained: " + LTRIM$(STR$(gGoldGain))
    CALL PrintTxt(70, 105, 68, xs)
    CALL PrintTxt(70, 118, 69, gs)
    ts = "Total XP:    " + LTRIM$(STR$(gHeroXP))
    CALL PrintTxt(70, 131, 43, ts)
    CALL PrintTxt(70, 144, 40, "Press any key")

    IF gSmoke = 1 THEN
        gQuit = 1
    ELSE
        kv = INP(&H60)
        IF kv <> 0 AND kv <> 128 THEN gQuit = 1
    END IF
END SUB
