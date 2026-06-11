' FPS3D - Wolfenstein-style raycaster demo for PB-SvgaLibrary
' Mode 13h 320x200, 160 rays (2px columns), integer DDA, 8.8 fixed-point grid
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"
$STACK 8192

' ---- constants ---------------------------------------------------------------
' Player position: 8.8 fixed-point; 1 map cell = 256 units
%CELLSZ  = 256
' Screen dimensions
%SCRH    = 200
%SCRW    = 320
' Angle table: 1024 entries spanning 0..2*PI; 256 = 90 deg
%ANG360  = 1024
%ANG32   = 32
' Sin/cos table scale: 16-bit fraction (cos * 256 stored as INTEGER, range -256..256)
%TRIGSC  = 256
' FOV half-width in angle units (64 = about 22.5 deg each side -> ~45 deg FOV)
%HALF_FOV = 32
' Palette base indices
%PAL_WALL  = 64
%PAL_CEIL  = 96
%PAL_FLOOR = 112
%PAL_GUN   = 32
%PAL_FLASH = 40
%PAL_HUD   = 48
' Wall slice height constant: at dist=CELLSZ, slice=SLICEK pixels
%SLICEK  = 12800

' ---- trig tables (INTEGER, scale 256) ----------------------------------------
' SHARED makes these visible to all SUBs within this program
DIM gSin(1023) AS SHARED INTEGER
DIM gCos(1023) AS SHARED INTEGER

' ---- map ---------------------------------------------------------------------
DIM gMap(15,15) AS SHARED BYTE   ' 16x16 grid

' ---- game state SHARED (visible to all SUBs in this file) --------------------
DIM gPX      AS SHARED INTEGER   ' player X in 8.8 units
DIM gPY      AS SHARED INTEGER   ' player Y in 8.8 units
DIM gAng     AS SHARED INTEGER   ' angle 0..1023
DIM gFrame   AS SHARED INTEGER
DIM gKey     AS SHARED STRING
DIM gMoved   AS SHARED INTEGER
DIM gSmoke   AS SHARED INTEGER
DIM gSmFrm   AS SHARED INTEGER
DIM gVictWait AS SHARED INTEGER
DIM gMapBig  AS SHARED INTEGER
DIM gBobPh   AS SHARED INTEGER
DIM gFlash   AS SHARED INTEGER
DIM gRecoil  AS SHARED INTEGER
DIM gWon     AS SHARED INTEGER
DIM gExitCX  AS SHARED INTEGER
DIM gExitCY  AS SHARED INTEGER
' smoke-test walk temporaries
DIM gSdx    AS SHARED LONG
DIM gSdy    AS SHARED LONG
DIM gSnx    AS SHARED LONG
DIM gSny    AS SHARED LONG
DIM gScx    AS SHARED INTEGER
DIM gScy    AS SHARED INTEGER

' ---- forward declarations ----------------------------------------------------
DECLARE SUB LoadMap(BYVAL dummy AS INTEGER)
DECLARE SUB SetupPalette(BYVAL dummy AS INTEGER)
DECLARE SUB DrawFrame(BYVAL dummy AS INTEGER)
DECLARE SUB DrawCeilFloor(BYVAL dummy AS INTEGER)
DECLARE SUB DrawWalls(BYVAL dummy AS INTEGER)
DECLARE SUB DrawGun(BYVAL dummy AS INTEGER)
DECLARE SUB DrawMinimap(BYVAL dummy AS INTEGER)
DECLARE SUB DrawHUD(BYVAL dummy AS INTEGER)
DECLARE SUB DrawVictory(BYVAL dummy AS INTEGER)
DECLARE SUB DoMove(BYVAL dummy AS INTEGER)
DECLARE FUNCTION WallAt(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER) AS BYTE

' ==============================================================================
' MAIN
' ==============================================================================
CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)

' Build sin/cos tables inline (SINGLE math only; stored as INTEGER scaled *256)
DIM tbI   AS INTEGER
DIM tbAng AS SINGLE
DIM tbSv  AS SINGLE
FOR tbI = 0 TO 1023
    tbAng = tbI * 6.283185 / 1024.0
    tbSv = SIN(tbAng) * 256.0
    IF tbSv >= 0.0 THEN
        gSin(tbI) = INT(tbSv + 0.5)
    ELSE
        gSin(tbI) = -INT(-tbSv + 0.5)
    END IF
    tbSv = COS(tbAng) * 256.0
    IF tbSv >= 0.0 THEN
        gCos(tbI) = INT(tbSv + 0.5)
    ELSE
        gCos(tbI) = -INT(-tbSv + 0.5)
    END IF
NEXT tbI

CALL LoadMap(0)
CALL SetupPalette(0)
CALL Fonts_InitFont("FONT8.TXT", 0)

gSmoke = 0
IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN gSmoke = 1

DO
    CALL DrawFrame(0)
    IF gSmoke THEN
        gSmFrm = gSmFrm + 1
        IF gSmFrm <= 64 THEN
            ' rotate full sweep
            gAng = (gAng + 16) AND 1023
        ELSEIF gSmFrm <= 100 THEN
            ' walk forward (use module-level temps to avoid DIM inside loop)
            gSdx = gCos(gAng)
            gSdy = gSin(gAng)
            gSnx = gPX + gSdx * 4 \ 256
            gSny = gPY + gSdy * 4 \ 256
            gScx = gSnx \ 256
            gScy = gSny \ 256
            IF WallAt(gScx, gScy) = 0 THEN
                gPX = gSnx
                gPY = gSny
            END IF
        ELSEIF gSmFrm = 110 THEN
            gFlash = 4
            gRecoil = 6
        ELSEIF gSmFrm = 130 THEN
            gFlash = 4
            gRecoil = 6
        END IF
        IF gSmFrm >= 150 THEN EXIT DO
    ELSE
        gKey = INKEY$
        IF LEN(gKey) = 1 THEN
            IF ASC(gKey) = 27 THEN EXIT DO
        END IF
        IF LEN(gKey) > 0 THEN CALL DoMove(0)
        IF gWon THEN
            gVictWait = gVictWait + 1
            IF gVictWait > 60 THEN EXIT DO
        END IF
    END IF
LOOP

CALL Vesa_Close(0)

IF gSmoke THEN
    OPEN "SMOKE.OK" FOR OUTPUT AS #1
    PRINT #1, "OK " + Svga_Version$
    CLOSE #1
END IF
END

' ==============================================================================
SUB LoadMap(BYVAL dummy AS INTEGER)
' Read LEVEL.MAP: 1-4=wall hue, .=floor, P=player start, X=exit
    DIM fh  AS INTEGER
    DIM row AS INTEGER
    DIM col AS INTEGER
    DIM ch  AS STRING * 1
    DIM ln  AS STRING
    fh = FREEFILE
    OPEN "LEVEL.MAP" FOR INPUT AS #fh
    row = 0
    DO WHILE NOT EOF(fh) AND row < 16
        LINE INPUT #fh, ln
        FOR col = 0 TO 15
            IF col + 1 <= LEN(ln) THEN
                ch = MID$(ln, col + 1, 1)
            ELSE
                ch = "."
            END IF
            SELECT CASE ch
                CASE "1"
                    gMap(col, row) = 1
                CASE "2"
                    gMap(col, row) = 2
                CASE "3"
                    gMap(col, row) = 3
                CASE "4"
                    gMap(col, row) = 4
                CASE "P"
                    gMap(col, row) = 0
                    ' centre of cell, facing east
                    gPX = col * 256 + 128
                    gPY = row * 256 + 128
                    gAng = 0
                CASE "X"
                    gMap(col, row) = 0
                    gExitCX = col
                    gExitCY = row
                CASE ELSE
                    gMap(col, row) = 0
            END SELECT
        NEXT col
        row = row + 1
    LOOP
    CLOSE #fh
END SUB

' ==============================================================================
SUB SetupPalette(BYVAL dummy AS INTEGER)
' 4 wall hues x 8 distance bands (32 entries at PAL_WALL)
' Bands 0-3 = E/W face (brighter), 4-7 = N/S face (darker)
    DIM i   AS INTEGER
    DIM bnd AS INTEGER
    DIM hue AS INTEGER
    DIM br  AS INTEGER
    DIM hr  AS INTEGER
    DIM hg  AS INTEGER
    DIM hb  AS INTEGER

    ' four wall hues x eight distance bands
    FOR hue = 0 TO 3
        SELECT CASE hue
            CASE 0
                hr = 48 : hg = 48 : hb = 52
            CASE 1
                hr = 52 : hg = 32 : hb = 16
            CASE 2
                hr = 20 : hg = 48 : hb = 20
            CASE 3
                hr = 20 : hg = 28 : hb = 52
        END SELECT
        FOR bnd = 0 TO 7
            br = 8 - bnd
            CALL Svga_SetPalette(%PAL_WALL + hue * 8 + bnd, (hr * br) \ 8, (hg * br) \ 8, (hb * br) \ 8)
        NEXT bnd
    NEXT hue

    ' ceiling gradient: 16 shades dark grey-blue
    FOR i = 0 TO 15
        br = i
        CALL Svga_SetPalette(%PAL_CEIL + i, br \ 4, br \ 4, br \ 3)
    NEXT i

    ' floor gradient: 16 shades dark brown
    FOR i = 0 TO 15
        br = i
        CALL Svga_SetPalette(%PAL_FLOOR + i, br \ 3, br \ 4, 0)
    NEXT i

    ' gun: grey shades
    FOR i = 0 TO 7
        br = 12 + i * 4
        CALL Svga_SetPalette(%PAL_GUN + i, br, br, br)
    NEXT i

    ' muzzle flash: yellow-orange
    FOR i = 0 TO 7
        CALL Svga_SetPalette(%PAL_FLASH + i, 60 + i * 2, 40 + i * 3, 0)
    NEXT i

    ' HUD minimap colours
    CALL Svga_SetPalette(%PAL_HUD + 0, 40, 30, 10)
    CALL Svga_SetPalette(%PAL_HUD + 1, 30, 30, 30)
    CALL Svga_SetPalette(%PAL_HUD + 2, 0, 50, 0)
    CALL Svga_SetPalette(%PAL_HUD + 3, 60, 60, 0)
    CALL Svga_SetPalette(%PAL_HUD + 4, 0, 20, 60)
    CALL Svga_SetPalette(%PAL_HUD + 5, 10, 10, 10)
    CALL Svga_SetPalette(%PAL_HUD + 6, 20, 20, 20)
    CALL Svga_SetPalette(%PAL_HUD + 7, 50, 50, 50)
END SUB

' ==============================================================================
FUNCTION WallAt(BYVAL cx AS INTEGER, BYVAL cy AS INTEGER) AS BYTE
    IF cx < 0 OR cx > 15 OR cy < 0 OR cy > 15 THEN
        WallAt = 1
    ELSE
        WallAt = gMap(cx, cy)
    END IF
END FUNCTION

' ==============================================================================
SUB DrawCeilFloor(BYVAL dummy AS INTEGER)
' Horizontal gradient bands for ceiling (top half) and floor (bottom half)
    DIM y   AS INTEGER
    DIM cv  AS BYTE
    DIM yv  AS WORD
    DIM x1v AS WORD
    DIM x2v AS WORD
    x1v = 0 : x2v = 319
    FOR y = 0 TO 99
        cv = %PAL_CEIL + (y * 15 \ 100)
        yv = y
        CALL Svga_HLine(x1v, x2v, yv, cv)
    NEXT y
    FOR y = 100 TO 199
        cv = %PAL_FLOOR + ((199 - y) * 15 \ 100)
        yv = y
        CALL Svga_HLine(x1v, x2v, yv, cv)
    NEXT y
END SUB

' ==============================================================================
SUB DrawWalls(BYVAL dummy AS INTEGER)
' DDA raycaster: 160 rays, 2px columns, 8.8 fixed-point
' Delta distances use INTEGER arithmetic scaled to CELLSZ=256
' No floating point; one integer division per column (slice height)
    DIM col    AS INTEGER
    DIM rayAng AS INTEGER
    DIM sinV   AS INTEGER   ' cos/sin scaled *256, range -256..256
    DIM cosV   AS INTEGER
    DIM mapX   AS INTEGER
    DIM mapY   AS INTEGER
    DIM fracX  AS INTEGER   ' fractional pos within cell 0..255
    DIM fracY  AS INTEGER
    DIM stepX  AS INTEGER
    DIM stepY  AS INTEGER
    DIM sideX  AS LONG      ' DDA side distances (can reach ~65536 * 255)
    DIM sideY  AS LONG
    DIM dDX    AS LONG      ' delta dist per cell: 65536/|cos| capped at 32767
    DIM dDY    AS LONG
    DIM hit    AS INTEGER
    DIM side   AS BYTE
    DIM wtype  AS BYTE
    DIM distV  AS LONG      ' perpendicular distance
    DIM sliceH AS INTEGER
    DIM y1     AS INTEGER
    DIM y2     AS INTEGER
    DIM x1v    AS WORD
    DIM x2v    AS WORD
    DIM y1w    AS WORD
    DIM y2w    AS WORD
    DIM bnd    AS INTEGER
    DIM palIdx AS BYTE
    DIM startA AS INTEGER
    DIM absCos AS INTEGER
    DIM absSin AS INTEGER

    ' FOV = 64 angle units (about 22.5 deg each side)
    startA = (gAng - %HALF_FOV + 1024) AND 1023

    FOR col = 0 TO 159
        ' step angle: 64 units across 160 columns
        rayAng = (startA + col * 64 \ 160) AND 1023
        cosV = gCos(rayAng)
        sinV = gSin(rayAng)

        mapX = gPX \ 256
        mapY = gPY \ 256
        fracX = gPX AND 255
        fracY = gPY AND 255

        ' delta distance = 256 / |dir|  (distance to cross one cell in each axis)
        ' cosV in range -256..256; absCos in 1..256
        absCos = cosV
        IF absCos < 0 THEN absCos = -absCos
        IF absCos < 1 THEN absCos = 1
        absSin = sinV
        IF absSin < 0 THEN absSin = -absSin
        IF absSin < 1 THEN absSin = 1

        ' dDX/dDY: cells in units of 1/256 per step; cap at 4095 for near-perpendicular
        dDX = 65536 \ absCos
        dDY = 65536 \ absSin
        IF dDX > 4095 THEN dDX = 4095
        IF dDY > 4095 THEN dDY = 4095

        ' initial side distances: distance to first grid boundary
        ' cast to LONG to avoid INTEGER overflow in multiply
        IF cosV >= 0 THEN
            stepX = 1
            sideX = (256 - fracX) * (dDX \ 256)
        ELSE
            stepX = -1
            sideX = fracX * (dDX \ 256)
        END IF
        IF sinV >= 0 THEN
            stepY = 1
            sideY = (256 - fracY) * (dDY \ 256)
        ELSE
            stepY = -1
            sideY = fracY * (dDY \ 256)
        END IF

        ' DDA loop: step until hitting a wall
        hit = 0 : side = 0 : wtype = 1
        DO WHILE hit = 0
            IF sideX < sideY THEN
                sideX = sideX + dDX
                mapX = mapX + stepX
                side = 0
            ELSE
                sideY = sideY + dDY
                mapY = mapY + stepY
                side = 1
            END IF
            IF mapX < 0 OR mapX > 15 OR mapY < 0 OR mapY > 15 THEN
                hit = 1
            ELSEIF gMap(mapX, mapY) > 0 THEN
                hit = 1
                wtype = gMap(mapX, mapY)
            END IF
        LOOP

        ' perpendicular distance: step back one delta from the hit boundary
        IF side = 0 THEN
            distV = sideX - dDX
        ELSE
            distV = sideY - dDY
        END IF
        IF distV < 2 THEN distV = 2

        ' slice height: SLICEK / dist; SLICEK chosen so at dist=128 (half cell)
        ' slice = 100 pixels (fills screen half)
        sliceH = %SLICEK \ distV
        IF sliceH > 198 THEN sliceH = 198

        y1 = 100 - sliceH \ 2
        y2 = 100 + sliceH \ 2
        IF y1 < 0 THEN y1 = 0
        IF y2 > 199 THEN y2 = 199

        ' distance band for shading: 0=near, 7=far
        bnd = distV \ 64
        IF bnd > 7 THEN bnd = 7

        ' N/S face (side=1) is darker: offset by 4 into the 8-band hue block
        IF side = 1 THEN
            palIdx = %PAL_WALL + (wtype - 1) * 8 + 4 + bnd \ 2
        ELSE
            palIdx = %PAL_WALL + (wtype - 1) * 8 + bnd \ 2
        END IF

        x1v = col * 2
        x2v = col * 2 + 1
        y1w = y1
        y2w = y2
        CALL Svga_VLine(x1v, y1w, y2w, palIdx)
        CALL Svga_VLine(x2v, y1w, y2w, palIdx)
    NEXT col
END SUB

' ==============================================================================
SUB DrawGun(BYVAL dummy AS INTEGER)
' Gun silhouette at bottom-centre; bobs when moving; muzzle flash on fire
    DIM bx  AS INTEGER
    DIM by  AS INTEGER
    DIM x1v AS WORD
    DIM y1v AS WORD
    DIM x2v AS WORD
    DIM y2v AS WORD
    DIM cv  AS BYTE

    bx = 140
    by = 170 + gRecoil
    IF gMoved THEN
        gBobPh = (gBobPh + 1) AND 7
        by = by + (gBobPh AND 3) - 1
    END IF
    IF by > 190 THEN by = 190
    IF by < 160 THEN by = 160

    cv = %PAL_GUN + 2
    x1v = bx - 12 : y1v = by + 4 : x2v = bx + 12 : y2v = by + 18
    CALL Svga_FillRect(x1v, y1v, x2v, y2v, cv)
    cv = %PAL_GUN + 1
    x1v = bx - 3 : y1v = by - 2 : x2v = bx + 3 : y2v = by + 5
    CALL Svga_FillRect(x1v, y1v, x2v, y2v, cv)
    cv = %PAL_GUN + 5
    x1v = bx - 10 : y1v = by + 5 : x2v = bx - 7 : y2v = by + 10
    CALL Svga_FillRect(x1v, y1v, x2v, y2v, cv)

    IF gFlash > 0 THEN
        cv = %PAL_FLASH + 6
        x1v = bx - 6 : y1v = by - 14 : x2v = bx + 6 : y2v = by - 2
        CALL Svga_FillRect(x1v, y1v, x2v, y2v, cv)
        cv = %PAL_FLASH + 7
        x1v = bx - 3 : y1v = by - 20 : x2v = bx + 3 : y2v = by - 14
        CALL Svga_FillRect(x1v, y1v, x2v, y2v, cv)
        gFlash = gFlash - 1
    END IF
    IF gRecoil > 0 THEN
        gRecoil = gRecoil - 2
        IF gRecoil < 0 THEN gRecoil = 0
    END IF
END SUB

' ==============================================================================
SUB DrawMinimap(BYVAL dummy AS INTEGER)
' Minimap top-right: cell rects, player dot, facing line
    DIM cs  AS INTEGER
    DIM ox  AS INTEGER
    DIM oy  AS INTEGER
    DIM mx  AS INTEGER
    DIM my  AS INTEGER
    DIM x1v AS WORD
    DIM y1v AS WORD
    DIM x2v AS WORD
    DIM y2v AS WORD
    DIM cv  AS BYTE
    DIM psx AS INTEGER
    DIM psy AS INTEGER
    DIM fex AS INTEGER
    DIM fey AS INTEGER

    IF gMapBig THEN cs = 8 ELSE cs = 4
    ox = 319 - 16 * cs
    oy = 1

    FOR my = 0 TO 15
        FOR mx = 0 TO 15
            x1v = ox + mx * cs
            y1v = oy + my * cs
            x2v = x1v + cs - 1
            y2v = y1v + cs - 1
            IF mx = gExitCX AND my = gExitCY THEN
                cv = %PAL_HUD + 4
            ELSEIF gMap(mx, my) > 0 THEN
                cv = %PAL_HUD + 1
            ELSE
                cv = %PAL_HUD
            END IF
            CALL Svga_FillRect(x1v, y1v, x2v, y2v, cv)
        NEXT mx
    NEXT my

    ' player dot
    psx = ox + (gPX \ 256) * cs + cs \ 2
    psy = oy + (gPY \ 256) * cs + cs \ 2
    IF psx < 1 THEN psx = 1
    IF psx > 318 THEN psx = 318
    IF psy < 1 THEN psy = 1
    IF psy > 198 THEN psy = 198
    x1v = psx - 1 : y1v = psy - 1
    x2v = psx + 1 : y2v = psy + 1
    cv = %PAL_HUD + 2
    CALL Svga_FillRect(x1v, y1v, x2v, y2v, cv)

    ' facing direction indicator
    fex = psx + gCos(gAng) * cs \ 256
    fey = psy + gSin(gAng) * cs \ 256
    IF fex < 0 THEN fex = 0
    IF fex > 319 THEN fex = 319
    IF fey < 0 THEN fey = 0
    IF fey > 199 THEN fey = 199
    x1v = fex : y1v = fey
    cv = %PAL_HUD + 3
    CALL Svga_PutPixel(x1v, y1v, cv)
END SUB

' ==============================================================================
SUB DrawHUD(BYVAL dummy AS INTEGER)
' Compass heading and status line at top-left
    DIM headTxt AS STRING
    DIM hudStr  AS STRING
    DIM xv  AS WORD
    DIM yv  AS WORD
    DIM cv  AS BYTE
    DIM bv  AS BYTE
    DIM fv  AS BYTE

    ' angle 0=East, 256=South, 512=West, 768=North
    IF gAng < 32 OR gAng >= 992 THEN
        headTxt = "E"
    ELSEIF gAng < 160 THEN
        headTxt = "SE"
    ELSEIF gAng < 352 THEN
        headTxt = "S"
    ELSEIF gAng < 416 THEN
        headTxt = "SW"
    ELSEIF gAng < 544 THEN
        headTxt = "W"
    ELSEIF gAng < 672 THEN
        headTxt = "NW"
    ELSEIF gAng < 800 THEN
        headTxt = "N"
    ELSE
        headTxt = "NE"
    END IF

    cv = 15 : bv = 0 : fv = 0
    xv = 2  : yv = 2
    hudStr = "FIND THE EXIT"
    CALL Fonts_VgaPrint(xv, yv, cv, bv, hudStr, fv)
    xv = 2  : yv = 12
    CALL Fonts_VgaPrint(xv, yv, cv, bv, headTxt, fv)
    xv = 2  : yv = 22
    hudStr = "M=MAP SPC=FIRE"
    CALL Fonts_VgaPrint(xv, yv, cv, bv, hudStr, fv)
END SUB

' ==============================================================================
SUB DrawVictory(BYVAL dummy AS INTEGER)
' Victory overlay banner
    DIM x1v AS WORD
    DIM y1v AS WORD
    DIM x2v AS WORD
    DIM y2v AS WORD
    DIM cv  AS BYTE
    DIM xv  AS WORD
    DIM yv  AS WORD
    cv = 3
    x1v = 60 : y1v = 80 : x2v = 260 : y2v = 120
    CALL Svga_FillRect(x1v, y1v, x2v, y2v, cv)
    cv = 15
    x1v = 61 : y1v = 81 : x2v = 259 : y2v = 119
    CALL Svga_DrawRect(x1v, y1v, x2v, y2v, cv)
    xv = 100 : yv = 92
    CALL Fonts_VgaPrint(xv, yv, cv, 3, "YOU FOUND THE EXIT!", 0)
    xv = 110 : yv = 104
    CALL Fonts_VgaPrint(xv, yv, cv, 3, "PRESS ESC TO QUIT", 0)
END SUB

' ==============================================================================
SUB DrawFrame(BYVAL dummy AS INTEGER)
    CALL DrawCeilFloor(0)
    CALL DrawWalls(0)
    CALL DrawGun(0)
    CALL DrawMinimap(0)
    CALL DrawHUD(0)
    IF gWon THEN CALL DrawVictory(0)
    gFrame = gFrame + 1
END SUB

' ==============================================================================
SUB DoMove(BYVAL dummy AS INTEGER)
' Keyboard handler: arrow keys (ext), Space, M
    DIM spd    AS INTEGER
    DIM nnx    AS LONG
    DIM nny    AS LONG
    DIM ncx    AS INTEGER
    DIM ncy    AS INTEGER
    DIM rotAmt AS INTEGER
    DIM sc     AS INTEGER
    DIM klen   AS INTEGER
    DIM k1     AS INTEGER
    DIM mvdx   AS LONG
    DIM mvdy   AS LONG

    gMoved = 0
    spd    = 4         ' movement delta: 4/256 of a cell per frame
    rotAmt = 24        ' rotation per frame in 1024-angle units

    klen = LEN(gKey)
    IF klen = 0 THEN EXIT SUB
    k1 = ASC(LEFT$(gKey, 1))

    ' Space: fire
    IF klen = 1 AND k1 = 32 THEN
        gFlash  = 5
        gRecoil = 8
        EXIT SUB
    END IF
    ' M: toggle minimap size
    IF klen = 1 AND (k1 = 109 OR k1 = 77) THEN
        IF gMapBig THEN gMapBig = 0 ELSE gMapBig = 1
        EXIT SUB
    END IF
    ' extended key: CHR$(0) + scancode
    IF klen <> 2 THEN EXIT SUB
    IF k1 <> 0 THEN EXIT SUB
    sc = ASC(MID$(gKey, 2, 1))

    IF sc = 72 THEN
        ' up arrow: move forward
        mvdx = gCos(gAng)
        mvdy = gSin(gAng)
        nnx = gPX + mvdx * spd \ 256
        nny = gPY + mvdy * spd \ 256
        ncx = nnx \ 256
        ncy = nny \ 256
        IF WallAt(ncx, ncy) = 0 THEN
            gPX = nnx : gPY = nny
            gMoved = 1
            IF ncx = gExitCX AND ncy = gExitCY THEN gWon = 1
        END IF
    ELSEIF sc = 80 THEN
        ' down arrow: move backward
        mvdx = gCos(gAng)
        mvdy = gSin(gAng)
        nnx = gPX - mvdx * spd \ 256
        nny = gPY - mvdy * spd \ 256
        ncx = nnx \ 256
        ncy = nny \ 256
        IF WallAt(ncx, ncy) = 0 THEN
            gPX = nnx : gPY = nny
            gMoved = 1
        END IF
    ELSEIF sc = 75 THEN
        ' left arrow: rotate counter-clockwise
        gAng = (gAng - rotAmt + 1024) AND 1023
    ELSEIF sc = 77 THEN
        ' right arrow: rotate clockwise
        gAng = (gAng + rotAmt) AND 1023
    END IF
END SUB
