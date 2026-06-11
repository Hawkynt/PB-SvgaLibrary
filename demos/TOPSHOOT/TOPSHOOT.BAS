' Top-down arena shooter demo for PB-SvgaLibrary
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

' --- constants ---
%SCR_W  = 320
%SCR_H  = 200
%ARENA_X1 = 8
%ARENA_Y1 = 8
%ARENA_X2 = 311
%ARENA_Y2 = 159
%HUD_Y    = 160
%MAX_ENE  = 8
%MAX_BUL  = 12
%MAX_PKP  = 4

' palette indices (custom, set via OUT)
%C_BLACK  = 0
%C_WALL   = 1
%C_FLOOR1 = 2
%C_FLOOR2 = 3
%C_PLAYER = 4
%C_BARREL = 5
%C_ENEMY  = 6
%C_CORPSE = 7
%C_BULLET = 8
%C_FLASH  = 9
%C_HEALTH = 10
%C_HBKGND = 11
%C_MEDKIT = 12
%C_RAPID  = 13
%C_HUDTXT = 14
%C_SCORE  = 15
%C_DARK1  = 16
%C_DARK2  = 17
%C_OBST   = 18
%C_OBSTHI = 19
%C_WHITE  = 20

' directions
%DIR_N = 0 : %DIR_S = 1 : %DIR_E = 2 : %DIR_W = 3
%DIR_NE = 4 : %DIR_NW = 5 : %DIR_SE = 6 : %DIR_SW = 7

' --- game state ---
DIM smoke AS INTEGER
DIM frame AS INTEGER
DIM gameOver AS INTEGER
DIM quitGame AS INTEGER

' player
DIM pX AS INTEGER
DIM pY AS INTEGER
DIM pDir AS INTEGER
DIM pHP AS INTEGER
DIM pScore AS LONG
DIM pWave AS INTEGER
DIM pRapid AS INTEGER
DIM pFireDelay AS INTEGER

' arrays
DIM eX(7) AS INTEGER
DIM eY(7) AS INTEGER
DIM eHP(7) AS INTEGER
DIM eAlive(7) AS INTEGER
DIM eCorpse(7) AS INTEGER
DIM eCX(7) AS INTEGER
DIM eCY(7) AS INTEGER

DIM bX(11) AS INTEGER
DIM bY(11) AS INTEGER
DIM bDX(11) AS INTEGER
DIM bDY(11) AS INTEGER
DIM bAlive(11) AS INTEGER

DIM pkX(3) AS INTEGER
DIM pkY(3) AS INTEGER
DIM pkType(3) AS INTEGER
DIM pkAlive(3) AS INTEGER

' spawn state
DIM waveTimer AS INTEGER
DIM spawnCount AS INTEGER
DIM enemiesToSpawn AS INTEGER
DIM flashTimer AS INTEGER

' --- obstacle blocks (4 fixed) ---
DIM obX(3) AS INTEGER
DIM obY(3) AS INTEGER

' smoke scripting
DIM smokeStep AS INTEGER
DIM smokeFireCnt AS INTEGER
DIM enemyDied AS INTEGER

' init graphics
CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)

CALL SetPalette(0)
CALL Fonts_InitFont("FONT8.TXT", 0)

smoke = 0
IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN smoke = 1

' --- title splash ---
DIM splashFile AS STRING
splashFile = "TITLE.BMP"
DIM splashX AS WORD, splashY AS WORD
splashX = 0 : splashY = 20
CALL DrawBmp_Show(splashFile, splashX, splashY)
' DrawBmp_Show replaces VGA palette; restore game palette immediately
CALL SetPalette(0)
IF smoke = 0 THEN
    ' interactive: wait for any key
    DIM splashKey AS STRING
    splashKey = ""
    DO WHILE splashKey = ""
        splashKey = INKEY$
    LOOP
END IF
' clear screen before drawing arena
DIM clrx1 AS WORD, clry1 AS WORD, clrx2 AS WORD, clry2 AS WORD
clrx1 = 0 : clry1 = 0 : clrx2 = 319 : clry2 = 199
CALL Svga_FillRect(clrx1, clry1, clrx2, clry2, %C_BLACK)

RANDOMIZE 42

CALL InitGame(0)
CALL DrawArena(0)

gameOver = 0
quitGame = 0
frame = 0
smokeStep = 0
smokeFireCnt = 0
enemyDied = 0

DO
    CALL GetInput(smoke, smokeStep, frame)
    IF quitGame <> 0 THEN GOTO GameExit

    CALL UpdateBullets(0)
    CALL UpdateEnemies(0)
    CALL UpdatePickups(0)
    CALL CheckWave(0)

    IF flashTimer > 0 THEN
        flashTimer = flashTimer - 1
    END IF

    IF pHP <= 0 THEN gameOver = 1 : GOTO GameExit

    CALL DrawFrame(0)

    frame = frame + 1
    IF smoke <> 0 THEN
        IF frame >= 200 THEN GOTO GameExit
        IF enemyDied > 0 AND frame >= 60 THEN GOTO GameExit
    END IF
LOOP

GameExit:
' --- game over plate (shown on player death or smoke exercise) ---
IF gameOver <> 0 OR smoke <> 0 THEN
    DIM goFile AS STRING
    goFile = "GAMEOVER.BMP"
    DIM goX AS WORD, goY AS WORD
    goX = 60 : goY = 70
    CALL DrawBmp_Show(goFile, goX, goY)
    ' DrawBmp_Show replaces VGA palette; restore game palette
    CALL SetPalette(0)
    IF smoke = 0 THEN
        ' interactive: wait for any key before closing
        DIM goKey AS STRING
        goKey = ""
        DO WHILE goKey = ""
            goKey = INKEY$
        LOOP
    END IF
END IF

CALL Svga_Close(0)
IF smoke <> 0 THEN
    OPEN "SMOKE.OK" FOR OUTPUT AS #1
    PRINT #1, "OK " + Svga_Version$
    CLOSE #1
END IF
END

' =====================================================================
SUB SetPalette(dummy AS INTEGER)
    ' 0 black
    CALL Svga_SetPalette(0, 0, 0, 0)
    ' 1 wall grey-blue
    CALL Svga_SetPalette(1, 10, 12, 18)
    ' 2 floor dark olive
    CALL Svga_SetPalette(2, 8, 9, 6)
    ' 3 floor darker olive
    CALL Svga_SetPalette(3, 6, 7, 4)
    ' 4 player green
    CALL Svga_SetPalette(4, 0, 40, 10)
    ' 5 barrel brown
    CALL Svga_SetPalette(5, 30, 20, 5)
    ' 6 enemy red-orange
    CALL Svga_SetPalette(6, 50, 15, 0)
    ' 7 corpse dark red
    CALL Svga_SetPalette(7, 20, 5, 0)
    ' 8 bullet bright yellow
    CALL Svga_SetPalette(8, 63, 63, 0)
    ' 9 flash white
    CALL Svga_SetPalette(9, 63, 63, 63)
    ' 10 health green
    CALL Svga_SetPalette(10, 0, 50, 0)
    ' 11 health bar background dark red
    CALL Svga_SetPalette(11, 30, 0, 0)
    ' 12 medkit cross green
    CALL Svga_SetPalette(12, 10, 63, 10)
    ' 13 rapid-fire blue
    CALL Svga_SetPalette(13, 10, 30, 63)
    ' 14 hud text light grey
    CALL Svga_SetPalette(14, 55, 55, 55)
    ' 15 score yellow
    CALL Svga_SetPalette(15, 63, 55, 0)
    ' 16 hud background dark
    CALL Svga_SetPalette(16, 4, 4, 8)
    ' 17 dark2
    CALL Svga_SetPalette(17, 5, 6, 4)
    ' 18 obstacle dark grey
    CALL Svga_SetPalette(18, 18, 18, 22)
    ' 19 obstacle highlight
    CALL Svga_SetPalette(19, 28, 28, 35)
    ' 20 white
    CALL Svga_SetPalette(20, 63, 63, 63)
END SUB

' =====================================================================
SUB InitGame(dummy AS INTEGER)
    DIM i AS INTEGER
    pX = 155 : pY = 80
    pDir = %DIR_E
    pHP = 100
    pScore = 0
    pWave = 1
    pRapid = 0
    pFireDelay = 0
    waveTimer = 60
    spawnCount = 0
    enemiesToSpawn = 3 + pWave
    flashTimer = 0

    FOR i = 0 TO 7
        eAlive(i) = 0 : eCorpse(i) = 0 : eHP(i) = 0
        eCX(i) = 0 : eCY(i) = 0
    NEXT i
    FOR i = 0 TO 11
        bAlive(i) = 0
    NEXT i
    FOR i = 0 TO 3
        pkAlive(i) = 0
    NEXT i

    obX(0) = 60  : obY(0) = 50
    obX(1) = 200 : obY(1) = 50
    obX(2) = 60  : obY(2) = 100
    obX(3) = 200 : obY(3) = 100
END SUB

' =====================================================================
SUB DrawArena(dummy AS INTEGER)
    DIM x AS WORD, y AS WORD
    DIM c AS BYTE
    DIM xi AS INTEGER, yi AS INTEGER

    ' floor checkerboard
    FOR yi = %ARENA_Y1 TO %ARENA_Y2 - 1 STEP 8
        FOR xi = %ARENA_X1 TO %ARENA_X2 - 1 STEP 8
            IF ((xi \ 8) + (yi \ 8)) AND 1 THEN
                c = %C_FLOOR1
            ELSE
                c = %C_FLOOR2
            END IF
            x = xi : y = yi
            DIM x2 AS WORD, y2 AS WORD
            x2 = xi + 7 : y2 = yi + 7
            IF x2 > %ARENA_X2 - 1 THEN x2 = %ARENA_X2 - 1
            IF y2 > %ARENA_Y2 - 1 THEN y2 = %ARENA_Y2 - 1
            CALL Svga_FillRect(x, y, x2, y2, c)
        NEXT xi
    NEXT yi

    ' wall border
    DIM wx1 AS WORD, wy1 AS WORD, wx2 AS WORD, wy2 AS WORD
    wx1 = 0 : wy1 = 0 : wx2 = 319 : wy2 = 159
    CALL Svga_FillRect(wx1, wy1, wx2, 7, %C_WALL)
    CALL Svga_FillRect(wx1, 152, wx2, wy2, %C_WALL)
    CALL Svga_FillRect(wx1, wy1, 7, wy2, %C_WALL)
    CALL Svga_FillRect(312, wy1, wx2, wy2, %C_WALL)

    ' HUD background
    DIM hudx1 AS WORD, hudy1 AS WORD, hudx2 AS WORD, hudy2 AS WORD
    hudx1 = 0 : hudy1 = 160 : hudx2 = 319 : hudy2 = 199
    CALL Svga_FillRect(hudx1, hudy1, hudx2, hudy2, %C_DARK1)

    ' Draw obstacles
    CALL DrawObstacles(0)
END SUB

' =====================================================================
SUB DrawObstacles(dummy AS INTEGER)
    DIM i AS INTEGER
    DIM ox1 AS WORD, oy1 AS WORD, ox2 AS WORD, oy2 AS WORD
    FOR i = 0 TO 3
        ox1 = obX(i) - 10
        oy1 = obY(i) - 8
        ox2 = obX(i) + 10
        oy2 = obY(i) + 8
        CALL Svga_FillRect(ox1, oy1, ox2, oy2, %C_OBST)
        CALL Svga_DrawRect(ox1, oy1, ox2, oy2, %C_OBSTHI)
    NEXT i
END SUB

' =====================================================================
SUB GetInput(isSm AS INTEGER, BYVAL sStep AS INTEGER, BYVAL fr AS INTEGER)
    DIM k AS STRING
    DIM moved AS INTEGER
    DIM nx AS INTEGER, ny AS INTEGER

    moved = 0
    IF isSm <> 0 THEN
        ' scripted smoke input: circle and fire
        DIM phase AS INTEGER
        phase = fr MOD 40
        IF phase < 10 THEN
            nx = pX + 2 : ny = pY
            IF nx > %ARENA_X2 - 6 THEN nx = %ARENA_X2 - 6
            pX = nx : pDir = %DIR_E : moved = 1
        ELSEIF phase < 20 THEN
            nx = pX : ny = pY + 2
            IF ny > %ARENA_Y2 - 6 THEN ny = %ARENA_Y2 - 6
            pY = ny : pDir = %DIR_S : moved = 1
        ELSEIF phase < 30 THEN
            nx = pX - 2 : ny = pY
            IF nx < %ARENA_X1 + 4 THEN nx = %ARENA_X1 + 4
            pX = nx : pDir = %DIR_W : moved = 1
        ELSE
            nx = pX : ny = pY - 2
            IF ny < %ARENA_Y1 + 4 THEN ny = %ARENA_Y1 + 4
            pY = ny : pDir = %DIR_N : moved = 1
        END IF
        ' fire every 8 frames
        IF (fr MOD 8) = 0 THEN
            CALL FireBullet(0)
            smokeFireCnt = smokeFireCnt + 1
        END IF
        EXIT SUB
    END IF

    k = INKEY$
    IF k = "" THEN EXIT SUB
    IF k = CHR$(27) THEN quitGame = 1 : EXIT SUB

    DIM spd AS INTEGER
    spd = 2
    IF LEN(k) = 2 THEN
        DIM sc AS INTEGER
        sc = ASC(RIGHT$(k, 1))
        IF sc = 72 THEN  ' up
            ny = pY - spd
            IF ny >= %ARENA_Y1 + 4 THEN pY = ny
            pDir = %DIR_N : moved = 1
        ELSEIF sc = 80 THEN  ' down
            ny = pY + spd
            IF ny <= %ARENA_Y2 - 6 THEN pY = ny
            pDir = %DIR_S : moved = 1
        ELSEIF sc = 75 THEN  ' left
            nx = pX - spd
            IF nx >= %ARENA_X1 + 4 THEN pX = nx
            pDir = %DIR_W : moved = 1
        ELSEIF sc = 77 THEN  ' right
            nx = pX + spd
            IF nx <= %ARENA_X2 - 6 THEN pX = nx
            pDir = %DIR_E : moved = 1
        END IF
    END IF

    IF k = " " THEN
        IF pFireDelay <= 0 THEN
            CALL FireBullet(0)
            IF pRapid > 0 THEN
                pFireDelay = 3
            ELSE
                pFireDelay = 8
            END IF
        END IF
    END IF

    IF pFireDelay > 0 THEN pFireDelay = pFireDelay - 1
END SUB

' =====================================================================
SUB FireBullet(dummy AS INTEGER)
    DIM i AS INTEGER
    DIM slot AS INTEGER
    slot = -1
    FOR i = 0 TO 11
        IF bAlive(i) = 0 THEN slot = i : i = 11
    NEXT i
    IF slot < 0 THEN EXIT SUB

    bX(slot) = pX : bY(slot) = pY
    bAlive(slot) = 1
    IF pDir = %DIR_N THEN
        bDX(slot) = 0 : bDY(slot) = -4
    ELSEIF pDir = %DIR_S THEN
        bDX(slot) = 0 : bDY(slot) = 4
    ELSEIF pDir = %DIR_E THEN
        bDX(slot) = 4 : bDY(slot) = 0
    ELSEIF pDir = %DIR_W THEN
        bDX(slot) = -4 : bDY(slot) = 0
    ELSEIF pDir = %DIR_NE THEN
        bDX(slot) = 3 : bDY(slot) = -3
    ELSEIF pDir = %DIR_NW THEN
        bDX(slot) = -3 : bDY(slot) = -3
    ELSEIF pDir = %DIR_SE THEN
        bDX(slot) = 3 : bDY(slot) = 3
    ELSEIF pDir = %DIR_SW THEN
        bDX(slot) = -3 : bDY(slot) = 3
    END IF
END SUB

' =====================================================================
SUB EraseBullet(BYVAL idx AS INTEGER)
    DIM bx1 AS WORD, by1 AS WORD, bx2 AS WORD, by2 AS WORD
    DIM fx AS INTEGER, fy AS INTEGER, c AS BYTE
    fx = bX(idx) : fy = bY(idx)
    IF fx >= %ARENA_X1 AND fx <= %ARENA_X2 - 2 AND fy >= %ARENA_Y1 AND fy <= %ARENA_Y2 - 2 THEN
        IF ((fx \ 8) + (fy \ 8)) AND 1 THEN c = %C_FLOOR1 ELSE c = %C_FLOOR2
        bx1 = fx - 1 : by1 = fy - 1 : bx2 = fx + 2 : by2 = fy + 2
        CALL Svga_FillRect(bx1, by1, bx2, by2, c)
    END IF
END SUB

' =====================================================================
SUB UpdateBullets(dummy AS INTEGER)
    DIM i AS INTEGER, j AS INTEGER
    DIM hit AS INTEGER
    DIM bx1 AS WORD, by1 AS WORD, bx2 AS WORD, by2 AS WORD

    FOR i = 0 TO 11
        IF bAlive(i) = 0 THEN GOTO NextBul

        CALL EraseBullet(i)

        bX(i) = bX(i) + bDX(i)
        bY(i) = bY(i) + bDY(i)

        ' wall check
        IF bX(i) < %ARENA_X1 OR bX(i) > %ARENA_X2 - 2 OR _
           bY(i) < %ARENA_Y1 OR bY(i) > %ARENA_Y2 - 2 THEN
            bAlive(i) = 0 : GOTO NextBul
        END IF

        ' obstacle check
        hit = 0
        FOR j = 0 TO 3
            IF ABS(bX(i) - obX(j)) < 12 AND ABS(bY(i) - obY(j)) < 10 THEN
                hit = 1 : j = 3
            END IF
        NEXT j
        IF hit <> 0 THEN bAlive(i) = 0 : GOTO NextBul

        ' enemy hit check
        FOR j = 0 TO 7
            IF eAlive(j) = 0 THEN GOTO NextEneCheck
            IF ABS(bX(i) - eX(j)) < 8 AND ABS(bY(i) - eY(j)) < 8 THEN
                eHP(j) = eHP(j) - 1
                IF eHP(j) <= 0 THEN
                    CALL KillEnemy(j)
                    enemyDied = enemyDied + 1
                    pScore = pScore + 100
                END IF
                bAlive(i) = 0
                flashTimer = 4
                j = 7
            END IF
            NextEneCheck:
        NEXT j

        NextBul:
    NEXT i
END SUB

' =====================================================================
SUB KillEnemy(BYVAL idx AS INTEGER)
    eAlive(idx) = 0
    eCX(idx) = eX(idx) : eCY(idx) = eY(idx)
    eCorpse(idx) = 1
    ' draw corpse splat
    DIM cx AS WORD, cy AS WORD
    cx = eCX(idx) : cy = eCY(idx)
    CALL Svga_FillCircle(cx, cy, 4, %C_CORPSE)
END SUB

' =====================================================================
SUB SpawnEnemy(dummy AS INTEGER)
    DIM slot AS INTEGER, i AS INTEGER
    slot = -1
    FOR i = 0 TO 7
        IF eAlive(i) = 0 THEN slot = i : i = 7
    NEXT i
    IF slot < 0 THEN EXIT SUB

    DIM edge AS INTEGER
    edge = INT(RND * 4)
    IF edge = 0 THEN
        eX(slot) = %ARENA_X1 + 4
        eY(slot) = %ARENA_Y1 + 4 + INT(RND * (%ARENA_Y2 - %ARENA_Y1 - 10))
    ELSEIF edge = 1 THEN
        eX(slot) = %ARENA_X2 - 4
        eY(slot) = %ARENA_Y1 + 4 + INT(RND * (%ARENA_Y2 - %ARENA_Y1 - 10))
    ELSEIF edge = 2 THEN
        eX(slot) = %ARENA_X1 + 4 + INT(RND * (%ARENA_X2 - %ARENA_X1 - 10))
        eY(slot) = %ARENA_Y1 + 4
    ELSE
        eX(slot) = %ARENA_X1 + 4 + INT(RND * (%ARENA_X2 - %ARENA_X1 - 10))
        eY(slot) = %ARENA_Y2 - 4
    END IF
    eHP(slot) = 2 + pWave
    eAlive(slot) = 1
    eCorpse(slot) = 0
    spawnCount = spawnCount + 1
END SUB

' =====================================================================
SUB EraseEntity(BYVAL ex AS INTEGER, BYVAL ey AS INTEGER, BYVAL rad AS INTEGER)
    DIM ex1 AS WORD, ey1 AS WORD, ex2 AS WORD, ey2 AS WORD
    DIM xi AS INTEGER, yi AS INTEGER, c AS BYTE
    ex1 = ex - rad : ey1 = ey - rad : ex2 = ex + rad : ey2 = ey + rad
    IF ex1 < %ARENA_X1 THEN ex1 = %ARENA_X1
    IF ey1 < %ARENA_Y1 THEN ey1 = %ARENA_Y1
    IF ex2 > %ARENA_X2 - 1 THEN ex2 = %ARENA_X2 - 1
    IF ey2 > %ARENA_Y2 - 1 THEN ey2 = %ARENA_Y2 - 1
    ' redraw floor tiles under entity
    FOR yi = ex1 TO ex2 STEP 8
        FOR xi = ey1 TO ey2 STEP 8
            IF ((yi \ 8) + (xi \ 8)) AND 1 THEN c = %C_FLOOR1 ELSE c = %C_FLOOR2
            DIM tx1 AS WORD, ty1 AS WORD, tx2 AS WORD, ty2 AS WORD
            tx1 = yi : ty1 = xi
            tx2 = yi + 7 : ty2 = xi + 7
            IF tx2 > ex2 THEN tx2 = ex2
            IF ty2 > ey2 THEN ty2 = ey2
            CALL Svga_FillRect(tx1, ty1, tx2, ty2, c)
        NEXT xi
    NEXT yi
END SUB

' =====================================================================
SUB UpdateEnemies(dummy AS INTEGER)
    DIM i AS INTEGER
    DIM dx AS INTEGER, dy AS INTEGER
    DIM ax AS INTEGER, ay AS INTEGER
    DIM moved AS INTEGER

    FOR i = 0 TO 7
        IF eAlive(i) = 0 THEN GOTO NextEnemy

        CALL EraseEntity(eX(i), eY(i), 6)

        ' chase player
        dx = pX - eX(i) : dy = pY - eY(i)
        ax = 0 : ay = 0
        IF dx > 0 THEN ax = 1
        IF dx < 0 THEN ax = -1
        IF dy > 0 THEN ay = 1
        IF dy < 0 THEN ay = -1

        moved = 0
        DIM tnx AS INTEGER, tny AS INTEGER
        tnx = eX(i) + ax : tny = eY(i) + ay

        ' obstacle slide
        DIM j AS INTEGER, blocked AS INTEGER
        blocked = 0
        FOR j = 0 TO 3
            IF ABS(tnx - obX(j)) < 13 AND ABS(tny - obY(j)) < 11 THEN
                blocked = 1 : j = 3
            END IF
        NEXT j

        IF blocked = 0 AND tnx >= %ARENA_X1 + 4 AND tnx <= %ARENA_X2 - 4 AND _
           tny >= %ARENA_Y1 + 4 AND tny <= %ARENA_Y2 - 4 THEN
            eX(i) = tnx : eY(i) = tny
        ELSE
            ' try horizontal only
            DIM tnx2 AS INTEGER
            tnx2 = eX(i) + ax
            blocked = 0
            FOR j = 0 TO 3
                IF ABS(tnx2 - obX(j)) < 13 AND ABS(eY(i) - obY(j)) < 11 THEN
                    blocked = 1 : j = 3
                END IF
            NEXT j
            IF blocked = 0 AND tnx2 >= %ARENA_X1 + 4 AND tnx2 <= %ARENA_X2 - 4 THEN
                eX(i) = tnx2
            ELSE
                ' try vertical only
                DIM tny2 AS INTEGER
                tny2 = eY(i) + ay
                blocked = 0
                FOR j = 0 TO 3
                    IF ABS(eX(i) - obX(j)) < 13 AND ABS(tny2 - obY(j)) < 11 THEN
                        blocked = 1 : j = 3
                    END IF
                NEXT j
                IF blocked = 0 AND tny2 >= %ARENA_Y1 + 4 AND tny2 <= %ARENA_Y2 - 4 THEN
                    eY(i) = tny2
                END IF
            END IF
        END IF

        ' player touch damage
        IF ABS(eX(i) - pX) < 8 AND ABS(eY(i) - pY) < 8 THEN
            pHP = pHP - 1
        END IF

        NextEnemy:
    NEXT i
END SUB

' =====================================================================
SUB UpdatePickups(dummy AS INTEGER)
    DIM i AS INTEGER
    FOR i = 0 TO 3
        IF pkAlive(i) = 0 THEN GOTO NextPkp
        ' player picks up
        IF ABS(pkX(i) - pX) < 8 AND ABS(pkY(i) - pY) < 8 THEN
            IF pkType(i) = 0 THEN
                pHP = pHP + 25
                IF pHP > 100 THEN pHP = 100
            ELSE
                pRapid = 180
            END IF
            CALL EraseEntity(pkX(i), pkY(i), 6)
            pkAlive(i) = 0
        END IF
        NextPkp:
    NEXT i
END SUB

' =====================================================================
SUB CheckWave(dummy AS INTEGER)
    DIM i AS INTEGER, alive AS INTEGER

    IF pRapid > 0 THEN pRapid = pRapid - 1

    waveTimer = waveTimer - 1
    IF waveTimer > 0 THEN EXIT SUB

    ' count alive enemies
    alive = 0
    FOR i = 0 TO 7
        IF eAlive(i) <> 0 THEN alive = alive + 1
    NEXT i

    IF alive < enemiesToSpawn AND spawnCount < enemiesToSpawn THEN
        CALL SpawnEnemy(0)
        waveTimer = 30
    ELSEIF alive = 0 AND spawnCount >= enemiesToSpawn THEN
        ' wave complete
        pWave = pWave + 1
        pScore = pScore + 500
        spawnCount = 0
        enemiesToSpawn = 3 + pWave
        waveTimer = 90
        ' maybe drop pickup
        IF (pWave MOD 2) = 0 THEN
            CALL DropPickup(0)
        END IF
    ELSE
        waveTimer = 30
    END IF
END SUB

' =====================================================================
SUB DropPickup(dummy AS INTEGER)
    DIM i AS INTEGER, slot AS INTEGER
    slot = -1
    FOR i = 0 TO 3
        IF pkAlive(i) = 0 THEN slot = i : i = 3
    NEXT i
    IF slot < 0 THEN EXIT SUB

    pkX(slot) = 80 + INT(RND * 160)
    pkY(slot) = 30 + INT(RND * 100)
    pkType(slot) = INT(RND * 2)
    pkAlive(slot) = 1
    CALL DrawPickup(slot)
END SUB

' =====================================================================
SUB DrawPickup(BYVAL idx AS INTEGER)
    DIM px AS WORD, py AS WORD
    DIM px1 AS WORD, py1 AS WORD, px2 AS WORD, py2 AS WORD
    px = pkX(idx) : py = pkY(idx)
    IF pkType(idx) = 0 THEN
        ' medkit: green cross
        px1 = px - 4 : py1 = py - 1 : px2 = px + 4 : py2 = py + 1
        CALL Svga_FillRect(px1, py1, px2, py2, %C_MEDKIT)
        px1 = px - 1 : py1 = py - 4 : px2 = px + 1 : py2 = py + 4
        CALL Svga_FillRect(px1, py1, px2, py2, %C_MEDKIT)
    ELSE
        ' rapid-fire: blue diamond
        DIM bx1 AS WORD, by1 AS WORD, bx2 AS WORD, by2 AS WORD
        bx1 = px - 3 : by1 = py : bx2 = px + 3 : by2 = py
        CALL Svga_DrawRect(bx1, py - 3, bx2, py + 3, %C_RAPID)
        CALL Svga_FillRect(bx1, by1, bx2, by2, %C_RAPID)
    END IF
END SUB

' =====================================================================
SUB DrawPlayer(dummy AS INTEGER)
    DIM cx AS WORD, cy AS WORD
    DIM tx1 AS WORD, ty1 AS WORD, tx2 AS WORD, ty2 AS WORD
    DIM tx3 AS WORD, ty3 AS WORD
    cx = pX : cy = pY

    ' body circle
    CALL Svga_FillCircle(cx, cy, 5, %C_PLAYER)
    CALL Svga_DrawCircle(cx, cy, 5, %C_WHITE)

    ' direction indicator triangle
    IF pDir = %DIR_N THEN
        tx1 = cx : ty1 = cy - 8
        tx2 = cx - 3 : ty2 = cy - 3
        tx3 = cx + 3 : ty3 = cy - 3
    ELSEIF pDir = %DIR_S THEN
        tx1 = cx : ty1 = cy + 8
        tx2 = cx - 3 : ty2 = cy + 3
        tx3 = cx + 3 : ty3 = cy + 3
    ELSEIF pDir = %DIR_E THEN
        tx1 = cx + 8 : ty1 = cy
        tx2 = cx + 3 : ty2 = cy - 3
        tx3 = cx + 3 : ty3 = cy + 3
    ELSEIF pDir = %DIR_W THEN
        tx1 = cx - 8 : ty1 = cy
        tx2 = cx - 3 : ty2 = cy - 3
        tx3 = cx - 3 : ty3 = cy + 3
    ELSEIF pDir = %DIR_NE THEN
        tx1 = cx + 6 : ty1 = cy - 6
        tx2 = cx + 2 : ty2 = cy - 2
        tx3 = cx + 2 : ty3 = cy - 6
    ELSEIF pDir = %DIR_NW THEN
        tx1 = cx - 6 : ty1 = cy - 6
        tx2 = cx - 2 : ty2 = cy - 2
        tx3 = cx - 6 : ty3 = cy - 2
    ELSEIF pDir = %DIR_SE THEN
        tx1 = cx + 6 : ty1 = cy + 6
        tx2 = cx + 2 : ty2 = cy + 2
        tx3 = cx + 6 : ty3 = cy + 2
    ELSE
        tx1 = cx - 6 : ty1 = cy + 6
        tx2 = cx - 2 : ty2 = cy + 2
        tx3 = cx - 2 : ty3 = cy + 6
    END IF
    CALL Graphics_FillTriangle(tx1, ty1, tx2, ty2, tx3, ty3, %C_WHITE)
END SUB

' =====================================================================
SUB DrawEnemies(dummy AS INTEGER)
    DIM i AS INTEGER
    DIM cx AS WORD, cy AS WORD
    FOR i = 0 TO 7
        IF eAlive(i) = 0 THEN GOTO SkipEnemy
        cx = eX(i) : cy = eY(i)
        CALL Svga_FillCircle(cx, cy, 5, %C_ENEMY)
        CALL Svga_DrawCircle(cx, cy, 5, %C_DARK1)
        ' health pip above enemy
        DIM px1 AS WORD, py1 AS WORD, px2 AS WORD, py2 AS WORD
        px1 = cx - 4 : py1 = cy - 8 : px2 = cx + 4 : py2 = cy - 7
        CALL Svga_FillRect(px1, py1, px2, py2, %C_HEALTH)
        SkipEnemy:
    NEXT i
END SUB

' =====================================================================
SUB DrawBullets(dummy AS INTEGER)
    DIM i AS INTEGER
    DIM bpx AS WORD, bpy AS WORD
    FOR i = 0 TO 11
        IF bAlive(i) = 0 THEN GOTO SkipBullet
        bpx = bX(i) : bpy = bY(i)
        CALL Svga_FillRect(bpx, bpy, bpx + 2, bpy + 2, %C_BULLET)
        SkipBullet:
    NEXT i
END SUB

' =====================================================================
SUB DrawHUD(dummy AS INTEGER)
    DIM hpw AS INTEGER
    DIM hx1 AS WORD, hy1 AS WORD, hx2 AS WORD, hy2 AS WORD

    ' health bar background
    hx1 = 4 : hy1 = 163 : hx2 = 103 : hy2 = 171
    CALL Svga_FillRect(hx1, hy1, hx2, hy2, %C_HBKGND)
    ' health bar fill
    hpw = pHP
    IF hpw > 100 THEN hpw = 100
    IF hpw < 0 THEN hpw = 0
    hx2 = 4 + hpw : hy2 = 171
    CALL Svga_FillRect(hx1, hy1, hx2, hy2, %C_HEALTH)

    CALL Fonts_VgaPrint(4, 174, %C_HUDTXT, %C_DARK1, "HP", 0)

    ' score
    DIM scTxt AS STRING
    scTxt = STR$(pScore)
    CALL Fonts_VgaPrint(110, 163, %C_SCORE, %C_DARK1, "SCR" + scTxt, 0)

    ' wave
    DIM wvTxt AS STRING
    wvTxt = STR$(pWave)
    CALL Fonts_VgaPrint(220, 163, %C_HUDTXT, %C_DARK1, "WV" + wvTxt, 0)

    ' rapid indicator
    IF pRapid > 0 THEN
        CALL Fonts_VgaPrint(220, 174, %C_RAPID, %C_DARK1, "RAPID", 0)
    ELSE
        CALL Svga_FillRect(220, 174, 269, 182, %C_DARK1)
    END IF
END SUB

' =====================================================================
SUB DrawFlash(dummy AS INTEGER)
    IF flashTimer <= 0 THEN EXIT SUB
    DIM fv AS BYTE
    fv = flashTimer * 2
    IF fv > 8 THEN fv = 8
    CALL Svga_FillRect(0, 0, 319, 159, %C_FLASH)
END SUB

' =====================================================================
SUB DrawFrame(dummy AS INTEGER)
    ' erase player old pos then redraw arena section
    CALL EraseEntity(pX, pY, 7)
    CALL DrawPlayer(0)
    CALL DrawEnemies(0)
    CALL DrawBullets(0)
    CALL DrawHUD(0)
    IF flashTimer > 0 THEN
        ' brief flash overlay around kill area only - skip full flash to avoid flicker
    END IF
END SUB

END
