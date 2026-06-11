' ACTION-RPG demo for PB-SvgaLibrary - mode 13h Zelda-style top-down
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

' ---- numeric constants -----------------------------------------------
%TILE_W = 16 : %TILE_H = 16
%MAP_COLS = 20 : %MAP_ROWS = 11 : %MAP_SIZE = 220
%SCREEN_W = 320 : %SCREEN_H = 200
%HUD_H = 24 : %PLAY_H = 176
%MAX_ENE = 12 : %MAX_PICK = 8
%DIR_UP = 0 : %DIR_DN = 1 : %DIR_LT = 2 : %DIR_RT = 3
%TILE_FLOOR = 0 : %TILE_WALL = 1 : %TILE_BUSH = 2 : %TILE_WATER = 3
%TILE_DOOR_R = 4 : %TILE_DOOR_D = 5 : %TILE_KEY = 6 : %TILE_CHEST = 7
%ENE_SLIME = 1 : %ENE_BAT = 2
%PICK_HEART = 1 : %PICK_GEM = 2
%PAL_GRASS1 = 32 : %PAL_GRASS2 = 33 : %PAL_GRASS3 = 52
%PAL_WALL1 = 34 : %PAL_WALL2 = 35
%PAL_WATER1 = 36 : %PAL_WATER2 = 37
%PAL_BUSH = 38 : %PAL_FLOOR = 39
%PAL_HERO = 40 : %PAL_SWORD = 41
%PAL_SLIME = 42 : %PAL_BAT = 43
%PAL_HEART = 44 : %PAL_GEM = 45 : %PAL_HUD = 46 : %PAL_DOOR = 47
%PAL_KEY = 48 : %PAL_CHEST = 49 : %PAL_OUTLINE = 50
%PAL_SKIN = 53 : %PAL_BLACK = 0 : %PAL_WHITE = 15

' ---- enemy parallel arrays -------------------------------------------
DIM eType(1 TO %MAX_ENE) AS SHARED BYTE
DIM eX(1 TO %MAX_ENE) AS SHARED INTEGER
DIM eY(1 TO %MAX_ENE) AS SHARED INTEGER
DIM eVX(1 TO %MAX_ENE) AS SHARED INTEGER
DIM eVY(1 TO %MAX_ENE) AS SHARED INTEGER
DIM eHP(1 TO %MAX_ENE) AS SHARED BYTE
DIM eTimer(1 TO %MAX_ENE) AS SHARED INTEGER
DIM eRoom(1 TO %MAX_ENE) AS SHARED BYTE

' ---- pickup arrays ---------------------------------------------------
DIM pType(1 TO %MAX_PICK) AS SHARED BYTE
DIM pX(1 TO %MAX_PICK) AS SHARED INTEGER
DIM pY(1 TO %MAX_PICK) AS SHARED INTEGER
DIM pRoom(1 TO %MAX_PICK) AS SHARED BYTE

' ---- map strings (one per room) -------------------------------------
DIM mRoom0 AS SHARED STRING
DIM mRoom1 AS SHARED STRING
DIM mRoom2 AS SHARED STRING
DIM mRoom3 AS SHARED STRING

' ---- player state ---------------------------------------------------
DIM heroX AS SHARED INTEGER
DIM heroY AS SHARED INTEGER
DIM heroDir AS SHARED BYTE
DIM heroHP AS SHARED BYTE
DIM heroMaxHP AS SHARED BYTE
DIM heroGems AS SHARED INTEGER
DIM heroKey AS SHARED BYTE
DIM curRoom AS SHARED BYTE
DIM invTimer AS SHARED INTEGER
DIM swordTimer AS SHARED BYTE
DIM swordDir AS SHARED BYTE
DIM questDone AS SHARED BYTE
DIM bannerTimer AS SHARED INTEGER

' ---- frame counters --------------------------------------------------
DIM frameCnt AS SHARED INTEGER
DIM waterPhase AS SHARED BYTE

' ---- smoke-test state -----------------------------------------------
DIM smokeMode AS SHARED BYTE
DIM smokeStep AS SHARED INTEGER
DIM smokeFrames AS SHARED INTEGER

' ---- initialize shared vars -----------------------------------------
heroX = 64 : heroY = 64 : heroDir = %DIR_DN
heroHP = 3 : heroMaxHP = 3 : heroGems = 0 : heroKey = 0
curRoom = 0 : invTimer = 0 : swordTimer = 0 : swordDir = 0
questDone = 0 : bannerTimer = 0
frameCnt = 0 : waterPhase = 0
smokeMode = 0 : smokeStep = 0 : smokeFrames = 0

' ====================================================================
' STARTUP
' ====================================================================
CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)

IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN
    smokeMode = 1
    RANDOMIZE 42
ELSE
    RANDOMIZE TIMER
END IF

CALL SetupPalette(0)
CALL LoadMap(0)
CALL InitEnemies(0)
CALL Fonts_InitFont("FONT8.TXT", 0)

' ====================================================================
' MAIN LOOP
' ====================================================================
DIM running AS BYTE : running = 1
DIM moveDir AS BYTE : moveDir = 255

DO WHILE running = 1
    IF smokeMode = 0 THEN
        CALL HandleInput(moveDir, running)
    ELSE
        CALL SmokeScript(moveDir)
        smokeFrames = smokeFrames + 1
        IF smokeFrames >= 250 THEN running = 0
    END IF

    CALL DoMove(moveDir)

    IF swordTimer > 0 THEN
        swordTimer = swordTimer - 1
        CALL SwordHitCheck(0)
    END IF
    IF invTimer > 0 THEN invTimer = invTimer - 1
    CALL UpdateEnemies(0)
    CALL UpdatePickups(0)
    IF bannerTimer > 0 THEN bannerTimer = bannerTimer - 1

    frameCnt = frameCnt + 1
    IF (frameCnt MOD 10) = 0 THEN
        waterPhase = 1 - waterPhase
        CALL CycleWater(0)
    END IF

    CALL DrawRoom(0)
    CALL DrawPickups(0)
    CALL DrawEnemies(0)
    CALL DrawHero(0)
    IF swordTimer > 0 THEN CALL DrawSword(0)
    CALL DrawHUD(0)
    IF bannerTimer > 0 THEN CALL DrawBanner(0)

    IF smokeMode = 0 THEN
        DIM dlyv AS WORD : dlyv = 1
        CALL Timer_Delay10Ms(dlyv)
    END IF
LOOP

CALL Vesa_Close(0)

IF smokeMode = 1 THEN
    OPEN "SMOKE.OK" FOR OUTPUT AS #1
    PRINT #1, "OK " + Svga_Version$
    CLOSE #1
END IF
END

' ====================================================================
' SUB SetupPalette
' ====================================================================
SUB SetupPalette (BYVAL dummy AS BYTE)
    CALL SetPalEntry(32,  4, 28,  4)
    CALL SetPalEntry(33,  6, 32,  6)
    CALL SetPalEntry(52,  5, 24,  5)
    CALL SetPalEntry(34, 24, 22, 18)
    CALL SetPalEntry(35, 30, 28, 24)
    CALL SetPalEntry(36,  2, 14, 32)
    CALL SetPalEntry(37,  4, 18, 38)
    CALL SetPalEntry(38,  2, 20,  2)
    CALL SetPalEntry(39, 20, 16, 12)
    CALL SetPalEntry(40, 30, 22,  8)
    CALL SetPalEntry(41, 63, 63, 63)
    CALL SetPalEntry(42,  8, 40,  8)
    CALL SetPalEntry(43, 20,  8, 28)
    CALL SetPalEntry(44, 48,  4,  4)
    CALL SetPalEntry(45,  4, 40, 48)
    CALL SetPalEntry(46, 12, 10, 10)
    CALL SetPalEntry(47, 28, 18,  8)
    CALL SetPalEntry(48, 52, 44,  4)
    CALL SetPalEntry(49, 36, 24,  8)
    CALL SetPalEntry(50,  0,  0,  0)
    CALL SetPalEntry(53, 40, 28, 18)
END SUB

' ====================================================================
' SUB SetPalEntry
' ====================================================================
SUB SetPalEntry (BYVAL pidx AS BYTE, BYVAL pr AS BYTE, BYVAL pg AS BYTE, BYVAL pb AS BYTE)
    CALL Svga_SetPalette(pidx, pr, pg, pb)
END SUB

' ====================================================================
' SUB CycleWater
' ====================================================================
SUB CycleWater (BYVAL dummy AS BYTE)
    IF waterPhase = 0 THEN
        CALL SetPalEntry(36,  2, 14, 32)
        CALL SetPalEntry(37,  4, 18, 38)
    ELSE
        CALL SetPalEntry(36,  4, 18, 38)
        CALL SetPalEntry(37,  2, 14, 32)
    END IF
END SUB

' ====================================================================
' SUB LoadMap
' ====================================================================
SUB LoadMap (BYVAL dummy AS BYTE)
    DIM fh AS INTEGER : fh = FREEFILE
    OPEN "I", #fh, "WORLD.MAP"
    DIM lineStr AS STRING
    DIM curRm AS BYTE : curRm = 0
    DIM curRow AS BYTE : curRow = 0
    DIM colIdx AS BYTE
    DIM chTile AS STRING * 1
    DIM tileCode AS BYTE
    DIM initStr AS STRING : initStr = STRING$(220, " ")
    mRoom0 = initStr
    mRoom1 = initStr
    mRoom2 = initStr
    mRoom3 = initStr

    DO WHILE NOT EOF(fh) AND curRm <= 3
        LINE INPUT #fh, lineStr
        IF LEN(lineStr) >= %MAP_COLS THEN
            FOR colIdx = 0 TO %MAP_COLS - 1
                chTile = MID$(lineStr, colIdx + 1, 1)
                SELECT CASE chTile
                    CASE "#" : tileCode = %TILE_WALL
                    CASE "W" : tileCode = %TILE_WATER
                    CASE "B" : tileCode = %TILE_BUSH
                    CASE "D" : tileCode = %TILE_DOOR_R
                    CASE "V" : tileCode = %TILE_DOOR_D
                    CASE "K" : tileCode = %TILE_KEY
                    CASE "C" : tileCode = %TILE_CHEST
                    CASE ELSE : tileCode = %TILE_FLOOR
                END SELECT
                DIM moffs AS INTEGER
                moffs = curRow * %MAP_COLS + colIdx + 1
                SELECT CASE curRm
                    CASE 0 : MID$(mRoom0, moffs, 1) = CHR$(tileCode)
                    CASE 1 : MID$(mRoom1, moffs, 1) = CHR$(tileCode)
                    CASE 2 : MID$(mRoom2, moffs, 1) = CHR$(tileCode)
                    CASE ELSE : MID$(mRoom3, moffs, 1) = CHR$(tileCode)
                END SELECT
            NEXT colIdx
            curRow = curRow + 1
            IF curRow >= %MAP_ROWS THEN
                curRow = 0
                curRm = curRm + 1
            END IF
        END IF
    LOOP
    CLOSE #fh
END SUB

' ====================================================================
' FUNCTION GetTile
' ====================================================================
FUNCTION GetTile (BYVAL rm AS BYTE, BYVAL col AS BYTE, BYVAL row AS BYTE) AS BYTE
    DIM gtOffs AS INTEGER : gtOffs = row * %MAP_COLS + col + 1
    DIM gtStr AS STRING
    SELECT CASE rm
        CASE 0 : gtStr = mRoom0
        CASE 1 : gtStr = mRoom1
        CASE 2 : gtStr = mRoom2
        CASE ELSE : gtStr = mRoom3
    END SELECT
    GetTile = ASC(MID$(gtStr, gtOffs, 1))
END FUNCTION

' ====================================================================
' SUB SetTile
' ====================================================================
SUB SetTile (BYVAL rm AS BYTE, BYVAL col AS BYTE, BYVAL row AS BYTE, BYVAL tcode AS BYTE)
    DIM stOffs AS INTEGER : stOffs = row * %MAP_COLS + col + 1
    SELECT CASE rm
        CASE 0 : MID$(mRoom0, stOffs, 1) = CHR$(tcode)
        CASE 1 : MID$(mRoom1, stOffs, 1) = CHR$(tcode)
        CASE 2 : MID$(mRoom2, stOffs, 1) = CHR$(tcode)
        CASE ELSE : MID$(mRoom3, stOffs, 1) = CHR$(tcode)
    END SELECT
END SUB

' ====================================================================
' FUNCTION TileSolid - walls + water block movement
' ====================================================================
FUNCTION TileSolid (BYVAL tc AS BYTE) AS BYTE
    IF tc = %TILE_WALL OR tc = %TILE_WATER THEN TileSolid = 1 ELSE TileSolid = 0
END FUNCTION

' ====================================================================
' FUNCTION TileSolidAll - walls + water + bush block movement
' ====================================================================
FUNCTION TileSolidAll (BYVAL tc AS BYTE) AS BYTE
    IF tc = %TILE_WALL OR tc = %TILE_WATER OR tc = %TILE_BUSH THEN
        TileSolidAll = 1
    ELSE
        TileSolidAll = 0
    END IF
END FUNCTION

' ====================================================================
' SUB InitEnemies
' ====================================================================
SUB InitEnemies (BYVAL dummy AS BYTE)
    DIM ei AS BYTE
    FOR ei = 1 TO %MAX_ENE
        eType(ei) = 0
    NEXT ei
    eType(1)=%ENE_SLIME : eX(1)=80  : eY(1)=80  : eHP(1)=2 : eRoom(1)=0 : eTimer(1)=0
    eType(2)=%ENE_SLIME : eX(2)=140 : eY(2)=100 : eHP(2)=2 : eRoom(2)=0 : eTimer(2)=15
    eType(3)=%ENE_SLIME : eX(3)=60  : eY(3)=60  : eHP(3)=2 : eRoom(3)=1 : eTimer(3)=5
    eType(4)=%ENE_SLIME : eX(4)=160 : eY(4)=120 : eHP(4)=2 : eRoom(4)=1 : eTimer(4)=20
    eType(5)=%ENE_SLIME : eX(5)=100 : eY(5)=90  : eHP(5)=2 : eRoom(5)=1 : eTimer(5)=10
    eType(6)=%ENE_BAT   : eX(6)=200 : eY(6)=70  : eHP(6)=1 : eRoom(6)=1 : eTimer(6)=0
    eType(7)=%ENE_SLIME : eX(7)=50  : eY(7)=70  : eHP(7)=2 : eRoom(7)=2 : eTimer(7)=8
    eType(8)=%ENE_SLIME : eX(8)=160 : eY(8)=130 : eHP(8)=2 : eRoom(8)=2 : eTimer(8)=0
    eType(9)=%ENE_SLIME  : eX(9)=80  : eY(9)=80  : eHP(9)=2  : eRoom(9)=3  : eTimer(9)=12
    eType(10)=%ENE_SLIME : eX(10)=180: eY(10)=100: eHP(10)=2 : eRoom(10)=3 : eTimer(10)=0
    eType(11)=%ENE_BAT   : eX(11)=150: eY(11)=60 : eHP(11)=1 : eRoom(11)=3 : eTimer(11)=0
    eType(12)=%ENE_SLIME : eX(12)=100: eY(12)=140: eHP(12)=2 : eRoom(12)=3 : eTimer(12)=6
END SUB

' ====================================================================
' SUB SpawnPickup
' ====================================================================
SUB SpawnPickup (BYVAL spRm AS BYTE, BYVAL spPx AS INTEGER, BYVAL spPy AS INTEGER, BYVAL spPt AS BYTE)
    DIM spi AS BYTE
    FOR spi = 1 TO %MAX_PICK
        IF pType(spi) = 0 THEN
            pType(spi) = spPt : pX(spi) = spPx : pY(spi) = spPy : pRoom(spi) = spRm
            EXIT FOR
        END IF
    NEXT spi
END SUB

' ====================================================================
' SUB HandleInput - read keyboard scancode and set moveDir
' ====================================================================
SUB HandleInput (moveDir AS BYTE, running AS BYTE)
    DIM ik AS STRING : ik = INKEY$
    IF ik = CHR$(27) THEN running = 0 : moveDir = 255 : EXIT SUB
    DIM sc AS BYTE
    !IN AL, &H60
    !MOV sc, AL
    moveDir = 255
    SELECT CASE sc
        CASE 72 : moveDir = %DIR_UP
        CASE 80 : moveDir = %DIR_DN
        CASE 75 : moveDir = %DIR_LT
        CASE 77 : moveDir = %DIR_RT
        CASE 57
            IF swordTimer = 0 THEN
                swordTimer = 3
                swordDir = heroDir
            END IF
    END SELECT
END SUB

' ====================================================================
' SUB DoMove - apply movement based on moveDir
' ====================================================================
SUB DoMove (BYVAL md AS BYTE)
    IF md = 255 THEN EXIT SUB
    DIM mnx AS INTEGER : mnx = heroX
    DIM mny AS INTEGER : mny = heroY
    SELECT CASE md
        CASE %DIR_UP  : heroDir = %DIR_UP  : mny = heroY - 2
        CASE %DIR_DN  : heroDir = %DIR_DN  : mny = heroY + 2
        CASE %DIR_LT  : heroDir = %DIR_LT  : mnx = heroX - 2
        CASE %DIR_RT  : heroDir = %DIR_RT  : mnx = heroX + 2
    END SELECT
    CALL TryMoveHero(mnx, mny)
END SUB

' ====================================================================
' SUB TryMoveHero
' ====================================================================
SUB TryMoveHero (BYVAL nx AS INTEGER, BYVAL ny AS INTEGER)
    ' room transitions
    IF nx > 303 THEN
        IF curRoom = 0 OR curRoom = 2 THEN
            curRoom = curRoom + 1
            heroX = 8 : heroY = ny
            IF heroY < 0 THEN heroY = 0
            IF heroY > %PLAY_H - 16 THEN heroY = %PLAY_H - 16
            EXIT SUB
        END IF
    END IF
    IF nx < 0 THEN
        IF curRoom = 1 OR curRoom = 3 THEN
            curRoom = curRoom - 1
            heroX = 288 : heroY = ny
            EXIT SUB
        END IF
    END IF
    IF ny > %PLAY_H - 16 THEN
        IF curRoom = 0 OR curRoom = 1 THEN
            curRoom = curRoom + 2
            heroX = nx : heroY = 8
            EXIT SUB
        END IF
    END IF
    IF ny < 0 THEN
        IF curRoom = 2 OR curRoom = 3 THEN
            curRoom = curRoom - 2
            heroX = nx : heroY = %PLAY_H - 24
            EXIT SUB
        END IF
    END IF
    ' clamp
    IF nx < 0 THEN nx = 0
    IF ny < 0 THEN ny = 0
    IF nx > %SCREEN_W - 16 THEN nx = %SCREEN_W - 16
    IF ny > %PLAY_H - 16 THEN ny = %PLAY_H - 16
    ' tile collision at 4 corners
    DIM ct1 AS BYTE, ct2 AS BYTE, ct3 AS BYTE, ct4 AS BYTE
    DIM htx1 AS BYTE : htx1 = nx \ %TILE_W
    DIM hty1 AS BYTE : hty1 = ny \ %TILE_H
    DIM htx2 AS BYTE : htx2 = (nx + 13) \ %TILE_W
    DIM hty2 AS BYTE : hty2 = (ny + 13) \ %TILE_H
    IF htx2 >= %MAP_COLS THEN htx2 = %MAP_COLS - 1
    IF hty2 >= %MAP_ROWS THEN hty2 = %MAP_ROWS - 1
    ct1 = GetTile(curRoom, htx1, hty1)
    ct2 = GetTile(curRoom, htx2, hty1)
    ct3 = GetTile(curRoom, htx1, hty2)
    ct4 = GetTile(curRoom, htx2, hty2)
    IF TileSolidAll(ct1) = 1 OR TileSolidAll(ct2) = 1 THEN EXIT SUB
    IF TileSolidAll(ct3) = 1 OR TileSolidAll(ct4) = 1 THEN EXIT SUB
    heroX = nx : heroY = ny
    ' tile interaction at hero center
    DIM htmx AS BYTE : htmx = (nx + 8) \ %TILE_W
    DIM htmy AS BYTE : htmy = (ny + 8) \ %TILE_H
    IF htmx >= %MAP_COLS THEN htmx = %MAP_COLS - 1
    IF htmy >= %MAP_ROWS THEN htmy = %MAP_ROWS - 1
    DIM tcMid AS BYTE : tcMid = GetTile(curRoom, htmx, htmy)
    IF tcMid = %TILE_KEY THEN
        heroKey = 1
        CALL SetTile(curRoom, htmx, htmy, %TILE_FLOOR)
    END IF
    IF tcMid = %TILE_CHEST THEN
        IF heroKey = 1 THEN
            questDone = 1
            bannerTimer = 180
            heroKey = 0
            CALL SetTile(curRoom, htmx, htmy, %TILE_FLOOR)
        END IF
    END IF
END SUB

' ====================================================================
' SUB SwordHitCheck
' ====================================================================
SUB SwordHitCheck (BYVAL dummy AS BYTE)
    DIM shcx AS INTEGER : shcx = heroX + 8
    DIM shcy AS INTEGER : shcy = heroY + 8
    DIM hx1 AS INTEGER, hx2 AS INTEGER, hy1 AS INTEGER, hy2 AS INTEGER
    SELECT CASE swordDir
        CASE %DIR_UP  : hx1=shcx-8 : hx2=shcx+8 : hy1=shcy-20 : hy2=shcy-4
        CASE %DIR_DN  : hx1=shcx-8 : hx2=shcx+8 : hy1=shcy+4  : hy2=shcy+20
        CASE %DIR_LT  : hx1=shcx-20: hx2=shcx-4 : hy1=shcy-8  : hy2=shcy+8
        CASE %DIR_RT  : hx1=shcx+4 : hx2=shcx+20: hy1=shcy-8  : hy2=shcy+8
    END SELECT
    ' bush cutting
    DIM sbx AS INTEGER : sbx = (hx1 + hx2) \ 2
    DIM sby AS INTEGER : sby = (hy1 + hy2) \ 2
    IF sbx < 0 THEN sbx = 0
    IF sby < 0 THEN sby = 0
    DIM stx AS BYTE : stx = sbx \ %TILE_W
    DIM sty AS BYTE : sty = sby \ %TILE_H
    IF stx >= %MAP_COLS THEN stx = %MAP_COLS - 1
    IF sty >= %MAP_ROWS THEN sty = %MAP_ROWS - 1
    DIM stc AS BYTE : stc = GetTile(curRoom, stx, sty)
    IF stc = %TILE_BUSH THEN
        CALL SetTile(curRoom, stx, sty, %TILE_FLOOR)
        DIM brv AS BYTE : brv = (RND * 4) AND 3
        IF brv = 0 THEN
            DIM bpx2 AS INTEGER : bpx2 = stx * %TILE_W + 4
            DIM bpy2 AS INTEGER : bpy2 = sty * %TILE_H + 4
            CALL SpawnPickup(curRoom, bpx2, bpy2, %PICK_HEART)
        ELSEIF brv = 1 THEN
            DIM gpx2 AS INTEGER : gpx2 = stx * %TILE_W + 4
            DIM gpy2 AS INTEGER : gpy2 = sty * %TILE_H + 4
            CALL SpawnPickup(curRoom, gpx2, gpy2, %PICK_GEM)
        END IF
    END IF
    ' enemy hits
    DIM si AS BYTE
    FOR si = 1 TO %MAX_ENE
        IF eType(si) > 0 AND eRoom(si) = curRoom THEN
            DIM sex AS INTEGER : sex = eX(si) + 4
            DIM sey AS INTEGER : sey = eY(si) + 4
            IF sex >= hx1 AND sex <= hx2 AND sey >= hy1 AND sey <= hy2 THEN
                eHP(si) = eHP(si) - 1
                IF eHP(si) = 0 THEN
                    DIM drv AS BYTE : drv = (RND * 4) AND 3
                    IF drv = 0 THEN
                        CALL SpawnPickup(curRoom, eX(si)+4, eY(si)+4, %PICK_HEART)
                    ELSEIF drv = 1 THEN
                        CALL SpawnPickup(curRoom, eX(si)+4, eY(si)+4, %PICK_GEM)
                    END IF
                    eType(si) = 0
                END IF
            END IF
        END IF
    NEXT si
END SUB

' ====================================================================
' SUB UpdateEnemies
' ====================================================================
SUB UpdateEnemies (BYVAL dummy AS BYTE)
    DIM ui AS BYTE
    FOR ui = 1 TO %MAX_ENE
        IF eType(ui) > 0 AND eRoom(ui) = curRoom THEN
            eTimer(ui) = eTimer(ui) + 1
            IF eType(ui) = %ENE_SLIME THEN
                IF (eTimer(ui) MOD 30) = 0 THEN
                    DIM srv AS BYTE : srv = (RND * 4) AND 3
                    SELECT CASE srv
                        CASE 0 : eVX(ui)= 0 : eVY(ui)=-1
                        CASE 1 : eVX(ui)= 0 : eVY(ui)= 1
                        CASE 2 : eVX(ui)=-1 : eVY(ui)= 0
                        CASE 3 : eVX(ui)= 1 : eVY(ui)= 0
                    END SELECT
                END IF
                DIM senx AS INTEGER : senx = eX(ui) + eVX(ui)
                DIM seny AS INTEGER : seny = eY(ui) + eVY(ui)
                IF senx < 0 THEN senx = 0 : eVX(ui) = 1
                IF seny < 0 THEN seny = 0 : eVY(ui) = 1
                IF senx > %SCREEN_W - 10 THEN senx = %SCREEN_W - 10 : eVX(ui) = -1
                IF seny > %PLAY_H - 10 THEN seny = %PLAY_H - 10 : eVY(ui) = -1
                DIM setx AS BYTE : setx = (senx + 4) \ %TILE_W
                DIM sety AS BYTE : sety = (seny + 4) \ %TILE_H
                IF setx >= %MAP_COLS THEN setx = %MAP_COLS - 1
                IF sety >= %MAP_ROWS THEN sety = %MAP_ROWS - 1
                DIM setc AS BYTE : setc = GetTile(curRoom, setx, sety)
                IF TileSolid(setc) = 0 THEN
                    eX(ui) = senx : eY(ui) = seny
                END IF
            ELSEIF eType(ui) = %ENE_BAT THEN
                DIM bdx AS INTEGER : bdx = heroX - eX(ui)
                DIM bdy AS INTEGER : bdy = heroY - eY(ui)
                DIM bdist AS LONG : bdist = bdx * bdx + bdy * bdy
                DIM bnx AS INTEGER : bnx = eX(ui)
                DIM bny AS INTEGER : bny = eY(ui)
                DIM bsine AS INTEGER
                bsine = (((eTimer(ui) * 3) MOD 100) - 50) \ 12
                bny = bny + bsine
                IF bdist < 4900 THEN
                    IF bdx > 0 THEN bnx = bnx + 1 ELSE IF bdx < 0 THEN bnx = bnx - 1
                    IF bdy > 0 THEN bny = bny + 1 ELSE IF bdy < 0 THEN bny = bny - 1
                END IF
                IF bnx < 4 THEN bnx = 4
                IF bny < 4 THEN bny = 4
                IF bnx > %SCREEN_W - 12 THEN bnx = %SCREEN_W - 12
                IF bny > %PLAY_H - 12 THEN bny = %PLAY_H - 12
                eX(ui) = bnx : eY(ui) = bny
            END IF
            ' hero collision
            IF invTimer = 0 THEN
                DIM ehdx AS INTEGER : ehdx = ABS(eX(ui) - heroX)
                DIM ehdy AS INTEGER : ehdy = ABS(eY(ui) - heroY)
                IF ehdx < 10 AND ehdy < 10 THEN
                    IF heroHP > 0 THEN heroHP = heroHP - 1
                    invTimer = 45
                END IF
            END IF
        END IF
    NEXT ui
END SUB

' ====================================================================
' SUB UpdatePickups
' ====================================================================
SUB UpdatePickups (BYVAL dummy AS BYTE)
    DIM upi AS BYTE
    FOR upi = 1 TO %MAX_PICK
        IF pType(upi) > 0 AND pRoom(upi) = curRoom THEN
            DIM updx AS INTEGER : updx = ABS(pX(upi) - heroX - 8)
            DIM updy AS INTEGER : updy = ABS(pY(upi) - heroY - 8)
            IF updx < 10 AND updy < 10 THEN
                IF pType(upi) = %PICK_HEART THEN
                    IF heroHP < heroMaxHP THEN heroHP = heroHP + 1
                ELSEIF pType(upi) = %PICK_GEM THEN
                    heroGems = heroGems + 1
                END IF
                pType(upi) = 0
            END IF
        END IF
    NEXT upi
END SUB

' ====================================================================
' SUB DrawRoom
' ====================================================================
SUB DrawRoom (BYVAL dummy AS BYTE)
    DIM drcol AS BYTE, drrow AS BYTE, drtc AS BYTE
    DIM drpx1 AS WORD, drpy1 AS WORD, drpx2 AS WORD, drpy2 AS WORD

    FOR drrow = 0 TO %MAP_ROWS - 1
        FOR drcol = 0 TO %MAP_COLS - 1
            drpx1 = drcol * %TILE_W
            drpy1 = drrow * %TILE_H + %HUD_H
            drpx2 = drpx1 + %TILE_W - 1
            drpy2 = drpy1 + %TILE_H - 1
            drtc = GetTile(curRoom, drcol, drrow)
            SELECT CASE drtc
                CASE %TILE_FLOOR
                    CALL Svga_FillRect(drpx1, drpy1, drpx2, drpy2, %PAL_FLOOR)
                CASE %TILE_WALL
                    CALL Svga_FillRect(drpx1, drpy1, drpx2, drpy2, %PAL_WALL1)
                    CALL Svga_HLine(drpx1, drpx2, drpy1, %PAL_WALL2)
                    CALL Svga_VLine(drpx1, drpy1, drpy2, %PAL_WALL2)
                CASE %TILE_WATER
                    CALL Svga_FillRect(drpx1, drpy1, drpx2, drpy2, %PAL_WATER1)
                    DIM wc1 AS WORD : wc1 = drpx1 + 4
                    DIM wr1 AS WORD : wr1 = drpy1 + 4
                    DIM wc2 AS WORD : wc2 = drpx1 + 11
                    DIM wr2 AS WORD : wr2 = drpy1 + 11
                    CALL Svga_FillRect(wc1, wr1, wc2, wr2, %PAL_WATER2)
                CASE %TILE_BUSH
                    CALL Svga_FillRect(drpx1, drpy1, drpx2, drpy2, %PAL_GRASS1)
                    DIM bb1x AS WORD : bb1x = drpx1 + 4
                    DIM bb1y AS WORD : bb1y = drpy1 + 6
                    DIM bb2x AS WORD : bb2x = drpx1 + 11
                    DIM bbr AS WORD : bbr = 4
                    CALL Svga_FillCircle(bb1x, bb1y, bbr, %PAL_BUSH)
                    CALL Svga_FillCircle(bb2x, bb1y, bbr, %PAL_BUSH)
                CASE %TILE_DOOR_R, %TILE_DOOR_D
                    CALL Svga_FillRect(drpx1, drpy1, drpx2, drpy2, %PAL_DOOR)
                    CALL Svga_DrawRect(drpx1, drpy1, drpx2, drpy2, %PAL_OUTLINE)
                CASE %TILE_KEY
                    CALL Svga_FillRect(drpx1, drpy1, drpx2, drpy2, %PAL_FLOOR)
                    DIM kyx AS WORD : kyx = drpx1 + 5
                    DIM kyy AS WORD : kyy = drpy1 + 6
                    DIM kyr AS WORD : kyr = 3
                    CALL Svga_FillCircle(kyx, kyy, kyr, %PAL_KEY)
                    DIM kxs AS WORD : kxs = drpx1 + 8
                    DIM kxe AS WORD : kxe = drpx1 + 13
                    DIM kyl AS WORD : kyl = drpy1 + 6
                    CALL Svga_HLine(kxs, kxe, kyl, %PAL_KEY)
                CASE %TILE_CHEST
                    CALL Svga_FillRect(drpx1, drpy1, drpx2, drpy2, %PAL_FLOOR)
                    DIM chx1 AS WORD : chx1 = drpx1 + 2
                    DIM chy1 AS WORD : chy1 = drpy1 + 4
                    DIM chx2 AS WORD : chx2 = drpx1 + 13
                    DIM chy2 AS WORD : chy2 = drpy1 + 12
                    CALL Svga_FillRect(chx1, chy1, chx2, chy2, %PAL_CHEST)
                    CALL Svga_DrawRect(chx1, chy1, chx2, chy2, %PAL_OUTLINE)
                    DIM chly AS WORD : chly = chy1 + 3
                    CALL Svga_HLine(chx1, chx2, chly, %PAL_OUTLINE)
                CASE ELSE
                    ' grass with two-tone + speckle
                    DIM gcol AS BYTE
                    IF (drcol + drrow) MOD 2 = 0 THEN gcol = %PAL_GRASS1 ELSE gcol = %PAL_GRASS2
                    CALL Svga_FillRect(drpx1, drpy1, drpx2, drpy2, gcol)
                    IF (drcol * 3 + drrow * 7) MOD 5 = 0 THEN
                        DIM spx AS WORD : spx = drpx1 + ((drcol * 5 + drrow * 3) MOD 10) + 2
                        DIM spy AS WORD : spy = drpy1 + ((drcol * 7 + drrow * 2) MOD 8) + 2
                        CALL Svga_PutPixel(spx, spy, %PAL_GRASS3)
                    END IF
            END SELECT
        NEXT drcol
    NEXT drrow
END SUB

' ====================================================================
' SUB DrawHero
' ====================================================================
SUB DrawHero (BYVAL dummy AS BYTE)
    IF invTimer > 0 THEN
        IF (invTimer MOD 4) < 2 THEN EXIT SUB
    END IF
    DIM dhx AS WORD : dhx = heroX
    DIM dhy AS WORD : dhy = heroY + %HUD_H
    ' body
    DIM hbx1 AS WORD : hbx1 = dhx + 3
    DIM hby1 AS WORD : hby1 = dhy + 6
    DIM hbx2 AS WORD : hbx2 = dhx + 12
    DIM hby2 AS WORD : hby2 = dhy + 14
    CALL Svga_FillRect(hbx1, hby1, hbx2, hby2, %PAL_HERO)
    CALL Svga_DrawRect(hbx1, hby1, hbx2, hby2, %PAL_OUTLINE)
    ' head
    DIM hhcx AS WORD : hhcx = dhx + 8
    DIM hhcy AS WORD : hhcy = dhy + 4
    DIM hhr AS WORD : hhr = 4
    CALL Svga_FillCircle(hhcx, hhcy, hhr, %PAL_SKIN)
    CALL Svga_DrawCircle(hhcx, hhcy, hhr, %PAL_OUTLINE)
    ' hat/direction indicator
    SELECT CASE heroDir
        CASE %DIR_UP
            DIM hux1 AS WORD : hux1 = dhx + 4
            DIM huy1 AS WORD : huy1 = dhy
            DIM hux2 AS WORD : hux2 = dhx + 11
            DIM huy2 AS WORD : huy2 = dhy + 3
            CALL Svga_FillRect(hux1, huy1, hux2, huy2, %PAL_HERO)
        CASE %DIR_DN
            DIM hdx1 AS WORD : hdx1 = dhx + 6
            DIM hdy1 AS WORD : hdy1 = dhy + 5
            DIM hdx2 AS WORD : hdx2 = dhx + 9
            DIM hdy2 AS WORD : hdy2 = dhy + 7
            CALL Svga_FillRect(hdx1, hdy1, hdx2, hdy2, %PAL_OUTLINE)
        CASE %DIR_LT
            DIM hlx AS WORD : hlx = dhx + 3
            DIM hly AS WORD : hly = dhy + 3
            CALL Svga_PutPixel(hlx, hly, %PAL_OUTLINE)
        CASE %DIR_RT
            DIM hrx AS WORD : hrx = dhx + 12
            DIM hry AS WORD : hry = dhy + 3
            CALL Svga_PutPixel(hrx, hry, %PAL_OUTLINE)
    END SELECT
END SUB

' ====================================================================
' SUB DrawSword
' ====================================================================
SUB DrawSword (BYVAL dummy AS BYTE)
    DIM dsx AS WORD : dsx = heroX + 8
    DIM dsy AS WORD : dsy = heroY + 8 + %HUD_H
    DIM dsex AS WORD, dsey AS WORD
    SELECT CASE swordDir
        CASE %DIR_UP  : dsex = dsx     : dsey = dsy - 16
        CASE %DIR_DN  : dsex = dsx     : dsey = dsy + 16
        CASE %DIR_LT  : dsex = dsx - 16: dsey = dsy
        CASE %DIR_RT  : dsex = dsx + 16: dsey = dsy
    END SELECT
    DIM dsv AS LONG : dsv = %PAL_SWORD
    CALL Svga_LineDraw(dsx, dsy, dsex, dsey, dsv)
    DIM ds2x AS WORD, ds2y AS WORD, ds3x AS WORD, ds3y AS WORD
    SELECT CASE swordDir
        CASE %DIR_UP, %DIR_DN
            ds2x = dsx - 1 : ds2y = dsy
            CALL Svga_LineDraw(ds2x, ds2y, dsex - 1, dsey, dsv)
            ds3x = dsx + 1 : ds3y = dsy
            CALL Svga_LineDraw(ds3x, ds3y, dsex + 1, dsey, dsv)
        CASE %DIR_LT, %DIR_RT
            ds2x = dsx : ds2y = dsy - 1
            CALL Svga_LineDraw(ds2x, ds2y, dsex, dsey - 1, dsv)
            ds3x = dsx : ds3y = dsy + 1
            CALL Svga_LineDraw(ds3x, ds3y, dsex, dsey + 1, dsv)
    END SELECT
END SUB

' ====================================================================
' SUB DrawEnemies
' ====================================================================
SUB DrawEnemies (BYVAL dummy AS BYTE)
    DIM dei AS BYTE
    FOR dei = 1 TO %MAX_ENE
        IF eType(dei) > 0 AND eRoom(dei) = curRoom THEN
            DIM deex AS WORD : deex = eX(dei)
            DIM deey AS WORD : deey = eY(dei) + %HUD_H
            IF eType(dei) = %ENE_SLIME THEN
                DIM sscx AS WORD : sscx = deex + 5
                DIM sscy AS WORD : sscy = deey + 5
                DIM ssr AS WORD : ssr = 5
                CALL Svga_FillCircle(sscx, sscy, ssr, %PAL_SLIME)
                CALL Svga_DrawCircle(sscx, sscy, ssr, %PAL_OUTLINE)
                DIM se1x AS WORD : se1x = deex + 3
                DIM se1y AS WORD : se1y = deey + 4
                DIM se2x AS WORD : se2x = deex + 7
                CALL Svga_PutPixel(se1x, se1y, %PAL_WHITE)
                CALL Svga_PutPixel(se2x, se1y, %PAL_WHITE)
            ELSEIF eType(dei) = %ENE_BAT THEN
                DIM bbcx AS WORD : bbcx = deex + 6
                DIM bbcy AS WORD : bbcy = deey + 5
                DIM bbr AS WORD : bbr = 4
                CALL Svga_FillCircle(bbcx, bbcy, bbr, %PAL_BAT)
                ' left wing
                DIM lw1x AS WORD : lw1x = deex
                DIM lw1y AS WORD : lw1y = deey + 5
                DIM lw2x AS WORD : lw2x = deex + 4
                DIM lw2y AS WORD : lw2y = deey + 2
                DIM lw3y AS WORD : lw3y = deey + 8
                CALL Graphics_FillTriangle(lw1x, lw1y, lw2x, lw2y, lw2x, lw3y, %PAL_BAT)
                ' right wing
                DIM rw1x AS WORD : rw1x = deex + 12
                DIM rw2x AS WORD : rw2x = deex + 8
                CALL Graphics_FillTriangle(rw1x, lw1y, rw2x, lw2y, rw2x, lw3y, %PAL_BAT)
                CALL Svga_DrawCircle(bbcx, bbcy, bbr, %PAL_OUTLINE)
            END IF
        END IF
    NEXT dei
END SUB

' ====================================================================
' SUB DrawPickups
' ====================================================================
SUB DrawPickups (BYVAL dummy AS BYTE)
    DIM dpi AS BYTE
    FOR dpi = 1 TO %MAX_PICK
        IF pType(dpi) > 0 AND pRoom(dpi) = curRoom THEN
            DIM dpx AS WORD : dpx = pX(dpi)
            DIM dpy AS WORD : dpy = pY(dpi) + %HUD_H
            IF pType(dpi) = %PICK_HEART THEN
                DIM ph1x AS WORD : ph1x = dpx + 2
                DIM ph1y AS WORD : ph1y = dpy + 2
                DIM ph2x AS WORD : ph2x = dpx + 5
                DIM phr AS WORD : phr = 2
                CALL Svga_FillCircle(ph1x, ph1y, phr, %PAL_HEART)
                CALL Svga_FillCircle(ph2x, ph1y, phr, %PAL_HEART)
                DIM pht1x AS WORD : pht1x = dpx
                DIM pht1y AS WORD : pht1y = dpy + 2
                DIM pht2x AS WORD : pht2x = dpx + 7
                DIM pht3x AS WORD : pht3x = dpx + 4
                DIM pht3y AS WORD : pht3y = dpy + 7
                CALL Graphics_FillTriangle(pht1x, pht1y, pht2x, pht1y, pht3x, pht3y, %PAL_HEART)
            ELSEIF pType(dpi) = %PICK_GEM THEN
                DIM pgmx AS WORD : pgmx = dpx + 4
                DIM pgty AS WORD : pgty = dpy
                DIM pglx AS WORD : pglx = dpx
                DIM pgmy AS WORD : pgmy = dpy + 4
                DIM pgrx AS WORD : pgrx = dpx + 7
                DIM pgby AS WORD : pgby = dpy + 8
                CALL Graphics_FillTriangle(pgmx, pgty, pglx, pgmy, pgrx, pgmy, %PAL_GEM)
                CALL Graphics_FillTriangle(pglx, pgmy, pgrx, pgmy, pgmx, pgby, %PAL_GEM)
            END IF
        END IF
    NEXT dpi
END SUB

' ====================================================================
' SUB DrawHUD
' ====================================================================
SUB DrawHUD (BYVAL dummy AS BYTE)
    DIM hudw AS WORD : hudw = %SCREEN_W - 1
    DIM hudh AS WORD : hudh = %HUD_H - 1
    DIM hudz AS WORD : hudz = 0
    CALL Svga_FillRect(hudz, hudz, hudw, hudh, %PAL_HUD)
    ' hearts
    DIM hhi AS BYTE
    FOR hhi = 1 TO heroMaxHP
        DIM hhpx AS WORD : hhpx = 4 + (hhi - 1) * 12
        DIM hhpy AS WORD : hhpy = 4
        IF hhi <= heroHP THEN
            DIM hfc1x AS WORD : hfc1x = hhpx + 2
            DIM hfc1y AS WORD : hfc1y = hhpy + 2
            DIM hfc2x AS WORD : hfc2x = hhpx + 5
            DIM hfr AS WORD : hfr = 2
            CALL Svga_FillCircle(hfc1x, hfc1y, hfr, %PAL_HEART)
            CALL Svga_FillCircle(hfc2x, hfc1y, hfr, %PAL_HEART)
            DIM hft1x AS WORD : hft1x = hhpx
            DIM hft1y AS WORD : hft1y = hhpy + 2
            DIM hft2x AS WORD : hft2x = hhpx + 7
            DIM hft3x AS WORD : hft3x = hhpx + 4
            DIM hft3y AS WORD : hft3y = hhpy + 7
            CALL Graphics_FillTriangle(hft1x, hft1y, hft2x, hft1y, hft3x, hft3y, %PAL_HEART)
        ELSE
            DIM herx1 AS WORD : herx1 = hhpx
            DIM hery1 AS WORD : hery1 = hhpy + 1
            DIM herx2 AS WORD : herx2 = hhpx + 7
            DIM hery2 AS WORD : hery2 = hhpy + 7
            CALL Svga_DrawRect(herx1, hery1, herx2, hery2, %PAL_HEART)
        END IF
    NEXT hhi
    ' gem icon + count
    DIM gix AS WORD : gix = 46
    DIM giy1 AS WORD : giy1 = 2
    DIM giym AS WORD : giym = 6
    DIM giyb AS WORD : giyb = 14
    DIM gixl AS WORD : gixl = 42
    DIM gixr AS WORD : gixr = 50
    CALL Graphics_FillTriangle(gix, giy1, gixl, giym, gixr, giym, %PAL_GEM)
    CALL Graphics_FillTriangle(gixl, giym, gixr, giym, gix, giyb, %PAL_GEM)
    DIM gemStr AS STRING : gemStr = STR$(heroGems)
    DIM gstx AS WORD : gstx = 52
    DIM gsty AS WORD : gsty = 4
    DIM gstc AS BYTE : gstc = %PAL_WHITE
    DIM gstb AS BYTE : gstb = %PAL_HUD
    CALL Fonts_VgaPrint(gstx, gsty, gstc, gstb, gemStr, 0)
    ' key icon
    IF heroKey = 1 THEN
        DIM kicx2 AS WORD : kicx2 = 100
        DIM kicy2 AS WORD : kicy2 = 8
        DIM kirad AS WORD : kirad = 3
        CALL Svga_FillCircle(kicx2, kicy2, kirad, %PAL_KEY)
        DIM kisx AS WORD : kisx = 103
        DIM kiex AS WORD : kiex = 110
        DIM kily AS WORD : kily = 8
        CALL Svga_HLine(kisx, kiex, kily, %PAL_KEY)
    END IF
    ' room indicator
    DIM rms AS STRING : rms = "R" + STR$(curRoom)
    DIM rmx AS WORD : rmx = 280
    DIM rmy AS WORD : rmy = 2
    DIM rmc AS BYTE : rmc = %PAL_WHITE
    DIM rmb AS BYTE : rmb = %PAL_HUD
    CALL Fonts_VgaPrint(rmx, rmy, rmc, rmb, rms, 0)
END SUB

' ====================================================================
' SUB DrawBanner
' ====================================================================
SUB DrawBanner (BYVAL dummy AS BYTE)
    DIM bnx1 AS WORD : bnx1 = 60
    DIM bny1 AS WORD : bny1 = 80
    DIM bnx2 AS WORD : bnx2 = 259
    DIM bny2 AS WORD : bny2 = 119
    CALL Svga_FillRect(bnx1, bny1, bnx2, bny2, %PAL_KEY)
    CALL Svga_DrawRect(bnx1, bny1, bnx2, bny2, %PAL_OUTLINE)
    DIM bnfc AS BYTE : bnfc = %PAL_OUTLINE
    DIM bnbc AS BYTE : bnbc = %PAL_KEY
    CALL Fonts_VgaPrint(80, 90, bnfc, bnbc, "QUEST COMPLETE!", 0)
    CALL Fonts_VgaPrint(80, 102, bnfc, bnbc, "TREASURE FOUND!", 0)
END SUB

' ====================================================================
' SUB SmokeScript - scripted movement sequence
' ====================================================================
SUB SmokeScript (moveDir AS BYTE)
    moveDir = 255
    smokeStep = smokeStep + 1
    IF smokeStep <= 30 THEN
        ' walk right
        heroDir = %DIR_RT
        DIM ss1x AS INTEGER : ss1x = heroX + 2
        DIM ss1y AS INTEGER : ss1y = heroY
        CALL TryMoveHero(ss1x, ss1y)
    ELSEIF smokeStep <= 45 THEN
        ' swing sword right
        IF swordTimer = 0 THEN
            swordTimer = 3 : swordDir = %DIR_RT
        END IF
        IF swordTimer > 0 THEN CALL SwordHitCheck(0)
    ELSEIF smokeStep <= 80 THEN
        ' walk down
        heroDir = %DIR_DN
        DIM ss2x AS INTEGER : ss2x = heroX
        DIM ss2y AS INTEGER : ss2y = heroY + 2
        CALL TryMoveHero(ss2x, ss2y)
    ELSEIF smokeStep <= 140 THEN
        ' walk right to transition room 0->1
        heroDir = %DIR_RT
        DIM ss3x AS INTEGER : ss3x = heroX + 2
        DIM ss3y AS INTEGER : ss3y = heroY
        CALL TryMoveHero(ss3x, ss3y)
    ELSEIF smokeStep <= 170 THEN
        ' in room 1: walk left + swing at bushes
        heroDir = %DIR_LT
        DIM ss4x AS INTEGER : ss4x = heroX - 2
        DIM ss4y AS INTEGER : ss4y = heroY
        CALL TryMoveHero(ss4x, ss4y)
        IF swordTimer = 0 THEN
            swordTimer = 3 : swordDir = %DIR_LT
        END IF
        IF swordTimer > 0 THEN CALL SwordHitCheck(0)
    ELSEIF smokeStep <= 200 THEN
        ' walk down to pick up items
        heroDir = %DIR_DN
        DIM ss5x AS INTEGER : ss5x = heroX
        DIM ss5y AS INTEGER : ss5y = heroY + 2
        CALL TryMoveHero(ss5x, ss5y)
    ELSEIF smokeStep <= 250 THEN
        ' walk right + swing to clear enemies
        heroDir = %DIR_RT
        DIM ss6x AS INTEGER : ss6x = heroX + 2
        DIM ss6y AS INTEGER : ss6y = heroY
        CALL TryMoveHero(ss6x, ss6y)
        IF swordTimer = 0 THEN
            swordTimer = 3 : swordDir = %DIR_RT
        END IF
        IF swordTimer > 0 THEN CALL SwordHitCheck(0)
    END IF
END SUB
