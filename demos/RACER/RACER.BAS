$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

' ---- screen constants -------------------------------------------------------
%SCR_W    = 320
%SCR_H    = 200
%HORIZON  = 80
%ROAD_ROWS = 80

' ---- track dimensions -------------------------------------------------------
%MAX_SEG  = 200
%SEG_LEN  = 200

' ---- fixed-point scale: use 256 to stay in 16-bit constants ----------------
%FP16     = 256

' ---- palette indices --------------------------------------------------------
%C_SKY0   = 16
%C_GRASS1 = 24
%C_GRASS2 = 25
%C_RUMBLE1 = 26
%C_RUMBLE2 = 27
%C_ASPH1  = 28
%C_ASPH2  = 29
%C_STRIPE = 30
%C_TREE   = 31
%C_SIGN   = 32
%C_CARG   = 33
%C_CARB   = 34
%C_CARC   = 35
%C_CARW   = 36
%C_HUDBAR = 37
%C_WHITE  = 38
%C_YELLOW = 39
%C_HORIZ  = 40
%C_AICAR  = 41
%C_AICW   = 42

' ---- action flags -----------------------------------------------------------
%ACT_UP   = 1
%ACT_DOWN = 2
%ACT_LEFT = 4
%ACT_RIGHT = 8
%ACT_QUIT = 16

' forward declarations
DECLARE FUNCTION NextTok$(s AS STRING, p AS INTEGER)
DECLARE FUNCTION GetInput() AS INTEGER
DECLARE SUB SetupPalette()
DECLARE SUB LoadTrack()
DECLARE SUB InitGame()
DECLARE SUB UpdateGame(BYVAL act AS INTEGER)
DECLARE SUB DrawFrame()
DECLARE SUB DrawSky()
DECLARE SUB DrawRoad()
DECLARE SUB DrawObj(BYVAL osx AS INTEGER, BYVAL osy AS INTEGER, _
                    BYVAL osc AS INTEGER, BYVAL otyp AS INTEGER)
DECLARE SUB DrawAICar(BYVAL asx AS INTEGER, BYVAL asy AS INTEGER, _
                      BYVAL ascl AS INTEGER)
DECLARE SUB DrawCar()
DECLARE SUB DrawHUD()

' ============================================================================
' Global state (AS SHARED so SUBs can read AND write them)
' ============================================================================
DIM smokeMode  AS SHARED INTEGER
DIM running    AS SHARED INTEGER
DIM frameCount AS SHARED INTEGER

DIM numSeg        AS SHARED INTEGER
DIM trkCurve(199) AS SHARED INTEGER
DIM trkHill(199)  AS SHARED INTEGER
DIM trkObjT(199)  AS SHARED INTEGER
DIM trkObjX(199)  AS SHARED INTEGER

DIM plPos     AS SHARED LONG
DIM plSpeed   AS SHARED LONG
DIM plX       AS SHARED LONG
DIM lapNum    AS SHARED INTEGER
DIM lapTime   AS SHARED INTEGER
DIM totalTime AS SHARED INTEGER
DIM raceOver  AS SHARED INTEGER
DIM racePos   AS SHARED INTEGER
DIM finSecs   AS SHARED INTEGER

DIM aiPos(1)    AS SHARED LONG
DIM aiXoff(1)   AS SHARED INTEGER
DIM aiPassed(1) AS SHARED INTEGER
DIM overtakes   AS SHARED INTEGER
DIM smokeOvt    AS SHARED INTEGER

' scratch arrays for DrawRoad (avoid stack pressure)
DIM rdObjSX(7)  AS SHARED INTEGER
DIM rdObjSY(7)  AS SHARED INTEGER
DIM rdObjSc(7)  AS SHARED INTEGER
DIM rdObjTy(7)  AS SHARED INTEGER
DIM rdAiSX(1)   AS SHARED INTEGER
DIM rdAiSY(1)   AS SHARED INTEGER
DIM rdAiSc(1)   AS SHARED INTEGER
DIM rdAiVis(1)  AS SHARED INTEGER

' ============================================================================
' HARNESS SETUP
' ============================================================================
CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)

smokeMode = 0
IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN smokeMode = 1

CALL SetupPalette()

DIM fontNm AS STRING
fontNm = "FONT8.TXT"
CALL Fonts_InitFont(fontNm, 0)

CALL LoadTrack()
CALL InitGame()

' ============================================================================
' MAIN LOOP
' ============================================================================
running    = 1
frameCount = 0
DIM act AS INTEGER

DO WHILE running = 1
    act = GetInput()
    IF (act AND %ACT_QUIT) THEN running = 0

    IF raceOver = 0 THEN
        CALL UpdateGame(act)
    END IF

    CALL DrawFrame()

    IF smokeMode = 1 THEN
        frameCount = frameCount + 1
        IF frameCount >= 300 THEN running = 0
        IF smokeOvt >= 1 AND frameCount >= 200 THEN running = 0
    END IF
LOOP

' ============================================================================
' SHUTDOWN
' ============================================================================
CALL Vesa_Close(0)
IF smokeMode = 1 THEN
    OPEN "SMOKE.OK" FOR OUTPUT AS #1
    PRINT #1, "OK"
    CLOSE #1
END IF
END

' ============================================================================
' SetupPalette
' ============================================================================
SUB SetupPalette()
    DIM i AS INTEGER
    DIM rv AS INTEGER, gv AS INTEGER, bv AS INTEGER

    FOR i = 0 TO 7
        rv = 4 + i * 5
        gv = 10 + i * 5
        bv = 40 + i * 3
        CALL Svga_SetPalette(16 + i, rv, gv, bv)
    NEXT i

    CALL Svga_SetPalette(24, 2, 32, 4)
    CALL Svga_SetPalette(25, 4, 44, 6)
    CALL Svga_SetPalette(26, 56, 4, 4)
    CALL Svga_SetPalette(27, 60, 60, 60)
    CALL Svga_SetPalette(28, 24, 24, 26)
    CALL Svga_SetPalette(29, 30, 30, 32)
    CALL Svga_SetPalette(30, 60, 60, 60)
    CALL Svga_SetPalette(31, 6, 38, 6)
    CALL Svga_SetPalette(32, 8, 16, 50)
    CALL Svga_SetPalette(33, 55, 6, 6)
    CALL Svga_SetPalette(34, 4, 4, 4)
    CALL Svga_SetPalette(35, 28, 28, 28)
    CALL Svga_SetPalette(36, 10, 10, 10)
    CALL Svga_SetPalette(37, 6, 6, 6)
    CALL Svga_SetPalette(38, 63, 63, 63)
    CALL Svga_SetPalette(39, 63, 55, 0)
    CALL Svga_SetPalette(40, 18, 30, 18)
    CALL Svga_SetPalette(41, 60, 50, 0)
    CALL Svga_SetPalette(42, 8, 8, 8)
END SUB

' ============================================================================
' LoadTrack
' ============================================================================
SUB LoadTrack()
    DIM fh  AS INTEGER
    DIM cv  AS INTEGER
    DIM hv  AS INTEGER
    DIM ot  AS INTEGER
    DIM ox  AS INTEGER
    DIM ltN AS INTEGER

    ltN = 0
    fh  = FREEFILE
    OPEN "TRACK.DAT" FOR INPUT AS #fh
    DO WHILE NOT EOF(fh) AND ltN < %MAX_SEG
        INPUT #fh, cv, hv, ot, ox
        trkCurve(ltN) = cv
        trkHill(ltN)  = hv
        trkObjT(ltN)  = ot
        trkObjX(ltN)  = ox
        ltN = ltN + 1
    LOOP
    CLOSE #fh
    IF ltN < 1 THEN ltN = 1
    numSeg = ltN
END SUB

' ============================================================================
' NextTok: next space-delimited token from string s starting at pos p
' ============================================================================
FUNCTION NextTok$(s AS STRING, p AS INTEGER)
    DIM nlen AS INTEGER
    DIM st   AS INTEGER
    nlen = LEN(s)
    DO WHILE p <= nlen AND MID$(s, p, 1) = " "
        p = p + 1
    LOOP
    IF p > nlen THEN NextTok$ = "" : EXIT FUNCTION
    st = p
    DO WHILE p <= nlen AND MID$(s, p, 1) <> " "
        p = p + 1
    LOOP
    NextTok$ = MID$(s, st, p - st)
END FUNCTION

' ============================================================================
' InitGame
' ============================================================================
SUB InitGame()
    DIM fp16v AS LONG
    fp16v = %FP16

    plPos     = 0
    plSpeed   = 0
    plX       = 0
    lapNum    = 1
    lapTime   = 0
    totalTime = 0
    raceOver  = 0
    finSecs   = 0
    racePos   = 3
    overtakes = 0
    smokeOvt  = 0

    aiPos(0)    = 2 * %SEG_LEN
    aiPos(0)    = aiPos(0) * fp16v
    aiPos(1)    = 4 * %SEG_LEN
    aiPos(1)    = aiPos(1) * fp16v
    aiXoff(0)   = 30
    aiXoff(1)   = -25
    aiPassed(0) = 0
    aiPassed(1) = 0
END SUB

' ============================================================================
' GetInput
' ============================================================================
FUNCTION GetInput() AS INTEGER
    DIM act  AS INTEGER
    DIM giSi AS INTEGER
    DIM giCv AS INTEGER
    DIM k    AS STRING

    act = 0

    IF smokeMode = 1 THEN
        act  = %ACT_UP
        giSi = (plPos \ %FP16 \ %SEG_LEN) MOD numSeg
        giCv = trkCurve(giSi)
        IF giCv > 4 THEN
            act = act OR %ACT_LEFT
        ELSEIF giCv < -4 THEN
            act = act OR %ACT_RIGHT
        END IF
        GetInput = act
        EXIT FUNCTION
    END IF

    k = INKEY$
    IF LEN(k) = 0 THEN GetInput = 0 : EXIT FUNCTION
    IF k = CHR$(27) THEN
        act = %ACT_QUIT
    ELSEIF k = CHR$(0) + CHR$(72) THEN
        act = %ACT_UP
    ELSEIF k = CHR$(0) + CHR$(80) THEN
        act = %ACT_DOWN
    ELSEIF k = CHR$(0) + CHR$(75) THEN
        act = %ACT_LEFT
    ELSEIF k = CHR$(0) + CHR$(77) THEN
        act = %ACT_RIGHT
    END IF
    GetInput = act
END FUNCTION

' ============================================================================
' UpdateGame
' ============================================================================
SUB UpdateGame(BYVAL act AS INTEGER)
    ' FP16 = 256 (8.8 fixed-point)
    ' plSpeed in FP units/frame (max = 18*256 = 4608 -> ~18 seg-units/frame)
    ' plPos in FP units (track distance * 256)
    ' halfRd = 100*256 = 25600 (100 pixels lateral)
    DIM ugI      AS INTEGER
    DIM diff     AS LONG
    DIM maxSpd   AS INTEGER
    DIM trackLen AS LONG
    DIM steerAmt AS INTEGER
    DIM ugSi     AS INTEGER
    DIM drift    AS LONG
    DIM halfRd   AS INTEGER

    maxSpd = 4608   ' 18 * 256
    halfRd = 25600  ' 100 * 256

    ' throttle/brake
    IF (act AND %ACT_UP) THEN
        plSpeed = plSpeed + 80
        IF plSpeed > maxSpd THEN plSpeed = maxSpd
    ELSEIF (act AND %ACT_DOWN) THEN
        plSpeed = plSpeed - 160
        IF plSpeed < 0 THEN plSpeed = 0
    ELSE
        plSpeed = plSpeed - 30
        IF plSpeed < 0 THEN plSpeed = 0
    END IF

    ' steering: amount proportional to speed
    steerAmt = 150 + plSpeed \ 64
    IF (act AND %ACT_LEFT) THEN
        plX = plX - steerAmt
    ELSEIF (act AND %ACT_RIGHT) THEN
        plX = plX + steerAmt
    END IF

    ' curvature drift
    ugSi  = (plPos \ %FP16 \ %SEG_LEN) MOD numSeg
    drift = trkCurve(ugSi)
    drift = drift * (plSpeed \ 256)
    plX   = plX + drift

    IF plX > halfRd  THEN
        plX     = halfRd
        plSpeed = plSpeed * 3 \ 4
    END IF
    IF plX < -halfRd THEN
        plX     = -halfRd
        plSpeed = plSpeed * 3 \ 4
    END IF

    plPos    = plPos + plSpeed
    trackLen = numSeg * %SEG_LEN
    trackLen = trackLen * %FP16
    IF plPos >= trackLen THEN
        plPos     = plPos - trackLen
        lapNum    = lapNum + 1
        totalTime = totalTime + lapTime
        lapTime   = 0
        IF lapNum > 2 THEN
            raceOver = 1
            finSecs  = totalTime \ 60
        END IF
    END IF
    lapTime = lapTime + 1

    FOR ugI = 0 TO 1
        aiPos(ugI) = aiPos(ugI) + 2560  ' 10 * 256
        IF aiPos(ugI) >= trackLen THEN
            aiPos(ugI) = aiPos(ugI) - trackLen
        END IF
        IF aiPassed(ugI) = 0 THEN
            diff = aiPos(ugI) - plPos
            IF diff < 0 THEN
                IF diff > -2560 THEN  ' within 10 segments
                    aiPassed(ugI) = 1
                    smokeOvt      = smokeOvt + 1
                    racePos       = racePos - 1
                    IF racePos < 1 THEN racePos = 1
                END IF
            END IF
        END IF
    NEXT ugI
END SUB

' ============================================================================
' DrawFrame
' ============================================================================
SUB DrawFrame()
    CALL DrawSky()
    CALL DrawRoad()
    CALL DrawCar()
    CALL DrawHUD()
END SUB

' ============================================================================
' DrawSky
' ============================================================================
SUB DrawSky()
    DIM sky_y  AS INTEGER
    DIM sky_ci AS INTEGER
    DIM x1w AS WORD, y1w AS WORD, x2w AS WORD, y2w AS WORD, cw AS BYTE

    FOR sky_y = 0 TO %HORIZON - 2
        sky_ci = sky_y * 8 \ %HORIZON
        IF sky_ci > 7 THEN sky_ci = 7
        x1w = 0 : y1w = sky_y : x2w = 319 : y2w = sky_y
        cw  = %C_SKY0 + sky_ci
        CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)
    NEXT sky_y

    x1w = 0 : y1w = %HORIZON - 1 : x2w = 319 : y2w = %HORIZON + 1 : cw = %C_HORIZ
    CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)
END SUB

' ============================================================================
' DrawRoad: segment-projected road with objects and AI cars
' ============================================================================
SUB DrawRoad()
    DIM playerSeg AS LONG
    DIM xcc       AS LONG
    DIM dr        AS INTEGER
    DIM rowY      AS INTEGER
    DIM pw        AS INTEGER
    DIM roadCx    AS INTEGER
    DIM depthSeg  AS INTEGER
    DIM segIdx    AS INTEGER
    DIM bandPhase AS INTEGER
    DIM rawSeg    AS LONG
    DIM grassC    AS BYTE
    DIM rumbleC   AS BYTE
    DIM asphC     AS BYTE
    DIM stripeC   AS BYTE
    DIM rumW      AS INTEGER
    DIM strW      AS INTEGER
    DIM lG2       AS INTEGER
    DIM lR1       AS INTEGER
    DIM lR2       AS INTEGER
    DIM aL1       AS INTEGER
    DIM aL2       AS INTEGER
    DIM sX1       AS INTEGER
    DIM sX2       AS INTEGER
    DIM aR1       AS INTEGER
    DIM aR2       AS INTEGER
    DIM rR1       AS INTEGER
    DIM rR2       AS INTEGER
    DIM rG1       AS INTEGER
    DIM x1w       AS WORD
    DIM x2w       AS WORD
    DIM yw        AS WORD
    DIM cob       AS BYTE
    DIM chkSeg    AS INTEGER
    DIM oLat      AS INTEGER
    DIM oscale    AS INTEGER
    DIM osx       AS INTEGER
    DIM objCnt    AS INTEGER
    DIM drAi      AS INTEGER
    DIM aiRel     AS LONG
    DIM aiSgD     AS LONG
    DIM aiTgtRow  AS INTEGER
    DIM oi        AS INTEGER

    playerSeg     = plPos \ %FP16 \ %SEG_LEN
    xcc           = plX
    objCnt        = 0
    rdAiVis(0)    = 0
    rdAiVis(1)    = 0
    stripeC       = %C_STRIPE

    FOR dr = 1 TO %ROAD_ROWS
        rowY = %HORIZON + dr - 1

        ' project: road half-width grows with depth (row number)
        pw = 130 * dr \ %ROAD_ROWS
        IF pw < 2 THEN pw = 2

        ' screen x centre shifted by accumulated curve
        roadCx = 160 + (xcc \ %FP16)
        IF roadCx < 10 THEN roadCx = 10
        IF roadCx > 309 THEN roadCx = 309

        ' segment at this depth level
        depthSeg = dr * 2 \ %ROAD_ROWS
        segIdx   = (playerSeg + depthSeg) MOD numSeg
        IF segIdx < 0 THEN segIdx = segIdx + numSeg

        ' accumulate curve offset toward vanishing point
        xcc = xcc + trkCurve(segIdx) * (dr \ 4 + 1)

        ' band alternation based on track position + depth
        rawSeg    = (plPos \ %FP16 \ %SEG_LEN) + dr \ 6
        bandPhase = rawSeg MOD 2
        IF bandPhase = 0 THEN
            grassC  = %C_GRASS1
            rumbleC = %C_RUMBLE1
            asphC   = %C_ASPH1
        ELSE
            grassC  = %C_GRASS2
            rumbleC = %C_RUMBLE2
            asphC   = %C_ASPH2
        END IF

        rumW = pw \ 8
        IF rumW < 2 THEN rumW = 2
        strW = pw \ 8
        IF strW < 1 THEN strW = 1

        ' --- left grass ---
        lG2 = roadCx - pw - rumW
        IF lG2 > 0 THEN
            x1w = 0 : x2w = lG2 : yw = rowY : cob = grassC
            CALL Svga_HLine(x1w, x2w, yw, cob)
        END IF

        ' --- left rumble ---
        lR1 = roadCx - pw - rumW
        lR2 = roadCx - pw
        IF lR1 < 0 THEN lR1 = 0
        IF lR2 > 319 THEN lR2 = 319
        IF lR1 <= lR2 THEN
            x1w = lR1 : x2w = lR2 : yw = rowY : cob = rumbleC
            CALL Svga_HLine(x1w, x2w, yw, cob)
        END IF

        ' --- asphalt left ---
        aL1 = roadCx - pw
        aL2 = roadCx - strW
        IF aL1 < 0 THEN aL1 = 0
        IF aL2 > 319 THEN aL2 = 319
        IF aL1 < aL2 THEN
            x1w = aL1 : x2w = aL2 : yw = rowY : cob = asphC
            CALL Svga_HLine(x1w, x2w, yw, cob)
        END IF

        ' --- centre stripe ---
        sX1 = roadCx - strW
        sX2 = roadCx + strW
        IF sX1 < 0 THEN sX1 = 0
        IF sX2 > 319 THEN sX2 = 319
        IF sX1 <= sX2 THEN
            x1w = sX1 : x2w = sX2 : yw = rowY : cob = stripeC
            CALL Svga_HLine(x1w, x2w, yw, cob)
        END IF

        ' --- asphalt right ---
        aR1 = roadCx + strW
        aR2 = roadCx + pw
        IF aR1 < 0 THEN aR1 = 0
        IF aR2 > 319 THEN aR2 = 319
        IF aR1 < aR2 THEN
            x1w = aR1 : x2w = aR2 : yw = rowY : cob = asphC
            CALL Svga_HLine(x1w, x2w, yw, cob)
        END IF

        ' --- right rumble ---
        rR1 = roadCx + pw
        rR2 = roadCx + pw + rumW
        IF rR1 < 0 THEN rR1 = 0
        IF rR2 > 319 THEN rR2 = 319
        IF rR1 <= rR2 THEN
            x1w = rR1 : x2w = rR2 : yw = rowY : cob = rumbleC
            CALL Svga_HLine(x1w, x2w, yw, cob)
        END IF

        ' --- right grass ---
        rG1 = roadCx + pw + rumW
        IF rG1 <= 319 THEN
            x1w = rG1 : x2w = 319 : yw = rowY : cob = grassC
            CALL Svga_HLine(x1w, x2w, yw, cob)
        END IF

        ' --- roadside objects (every 8 rows) ---
        IF dr MOD 8 = 0 THEN
            IF objCnt < 8 THEN
                chkSeg = (playerSeg + dr \ 4) MOD numSeg
                IF chkSeg < 0 THEN chkSeg = 0
                IF trkObjT(chkSeg) > 0 THEN
                    oLat   = trkObjX(chkSeg) - 128
                    oscale = dr \ 16 + 1
                    IF oscale > 8 THEN oscale = 8
                    osx               = roadCx + oLat * pw \ 80
                    rdObjSX(objCnt)   = osx
                    rdObjSY(objCnt)   = rowY
                    rdObjSc(objCnt)   = oscale
                    rdObjTy(objCnt)   = trkObjT(chkSeg)
                    objCnt            = objCnt + 1
                END IF
            END IF
        END IF

        ' --- AI car position lookup ---
        FOR drAi = 0 TO 1
            IF rdAiVis(drAi) = 0 THEN
                aiRel = aiPos(drAi) - plPos
                IF aiRel < 0 THEN aiRel = 0
                aiSgD    = aiRel \ %FP16 \ %SEG_LEN
                aiTgtRow = aiSgD * %ROAD_ROWS \ numSeg
                IF aiTgtRow < 1 THEN aiTgtRow = 1
                IF aiTgtRow > %ROAD_ROWS THEN aiTgtRow = %ROAD_ROWS
                IF dr = aiTgtRow THEN
                    rdAiSX(drAi)  = roadCx + aiXoff(drAi) * pw \ 80
                    rdAiSY(drAi)  = rowY
                    rdAiSc(drAi)  = dr \ 20 + 1
                    IF rdAiSc(drAi) > 6 THEN rdAiSc(drAi) = 6
                    rdAiVis(drAi) = 1
                END IF
            END IF
        NEXT drAi
    NEXT dr

    FOR oi = 0 TO objCnt - 1
        CALL DrawObj(rdObjSX(oi), rdObjSY(oi), rdObjSc(oi), rdObjTy(oi))
    NEXT oi

    FOR drAi = 0 TO 1
        IF rdAiVis(drAi) = 1 THEN
            CALL DrawAICar(rdAiSX(drAi), rdAiSY(drAi), rdAiSc(drAi))
        END IF
    NEXT drAi
END SUB

' ============================================================================
' DrawObj: tree or sign billboard
' ============================================================================
SUB DrawObj(BYVAL osx AS INTEGER, BYVAL osy AS INTEGER, _
            BYVAL osc AS INTEGER, BYVAL otyp AS INTEGER)
    DIM x1w AS WORD, y1w AS WORD, x2w AS WORD, y2w AS WORD, cw AS BYTE
    DIM ohw AS INTEGER
    DIM ohh AS INTEGER
    DIM ox1 AS INTEGER
    DIM oy1 AS INTEGER
    DIM ox2 AS INTEGER
    DIM oy2 AS INTEGER
    DIM tty AS INTEGER

    ohw = osc * 3
    ohh = osc * 6

    IF otyp = 1 THEN
        ox1 = osx - ohw : oy1 = osy - ohh : ox2 = osx + ohw : oy2 = osy
        IF ox1 < 0   THEN ox1 = 0
        IF ox2 > 319 THEN ox2 = 319
        IF oy1 < 0   THEN oy1 = 0
        IF oy2 > 185 THEN oy2 = 185
        IF ox1 < ox2 THEN
            IF oy1 < oy2 THEN
                x1w = ox1 : y1w = oy1 : x2w = ox2 : y2w = oy2 : cw = %C_TREE
                CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)
                tty = oy1 + ohh \ 3
                IF tty < oy2 THEN
                    y2w = tty : cw = %C_GRASS2
                    CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)
                END IF
            END IF
        END IF
    ELSEIF otyp = 2 THEN
        ox1 = osx - ohw : oy1 = osy - osc * 4 : ox2 = osx + ohw : oy2 = osy - osc
        IF ox1 < 0   THEN ox1 = 0
        IF ox2 > 319 THEN ox2 = 319
        IF oy1 < 0   THEN oy1 = 0
        IF oy2 > 185 THEN oy2 = 185
        IF ox1 < ox2 THEN
            IF oy1 < oy2 THEN
                x1w = ox1 : y1w = oy1 : x2w = ox2 : y2w = oy2 : cw = %C_SIGN
                CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)
            END IF
        END IF
    END IF
END SUB

' ============================================================================
' DrawAICar: yellow AI car billboard
' ============================================================================
SUB DrawAICar(BYVAL asx AS INTEGER, BYVAL asy AS INTEGER, BYVAL ascl AS INTEGER)
    DIM x1w AS WORD, y1w AS WORD, x2w AS WORD, y2w AS WORD, cw AS BYTE
    DIM abw AS INTEGER
    DIM abh AS INTEGER
    DIM ax1 AS INTEGER
    DIM ay1 AS INTEGER
    DIM ax2 AS INTEGER
    DIM ay2 AS INTEGER
    DIM cpy AS INTEGER

    abw = ascl * 5
    abh = ascl * 3

    ax1 = asx - abw : ay1 = asy - abh : ax2 = asx + abw : ay2 = asy
    IF ax1 < 0   THEN ax1 = 0
    IF ax2 > 319 THEN ax2 = 319
    IF ay1 < 0   THEN ay1 = 0
    IF ay2 > 185 THEN ay2 = 185
    IF ax1 < ax2 THEN
        IF ay1 < ay2 THEN
            x1w = ax1 : y1w = ay1 : x2w = ax2 : y2w = ay2 : cw = %C_AICAR
            CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)
            cpy = ay1 + abh \ 3
            IF cpy < ay2 THEN
                x1w = ax1 + abw \ 3
                x2w = ax2 - abw \ 3
                y2w = cpy
                cw  = %C_AICW
                CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)
            END IF
        END IF
    END IF
END SUB

' ============================================================================
' DrawCar: player car at bottom centre
' ============================================================================
SUB DrawCar()
    DIM x1w AS WORD, y1w AS WORD, x2w AS WORD, y2w AS WORD, cw AS BYTE
    DIM carCx AS INTEGER
    carCx = 160

    ' spoiler
    x1w = carCx - 32 : y1w = 163 : x2w = carCx + 32 : y2w = 165 : cw = %C_CARB
    CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)

    ' body
    x1w = carCx - 28 : y1w = 165 : x2w = carCx + 28 : y2w = 180 : cw = %C_CARG
    CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)

    ' cockpit
    x1w = carCx - 14 : y1w = 162 : x2w = carCx + 14 : y2w = 167 : cw = %C_CARC
    CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)

    ' front bumper
    x1w = carCx - 22 : y1w = 180 : x2w = carCx + 22 : y2w = 183 : cw = %C_CARB
    CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)

    ' left wheel
    x1w = carCx - 30 : y1w = 176 : x2w = carCx - 20 : y2w = 184 : cw = %C_CARW
    CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)

    ' right wheel
    x1w = carCx + 20 : y1w = 176 : x2w = carCx + 30 : y2w = 184 : cw = %C_CARW
    CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)
END SUB

' ============================================================================
' DrawHUD
' ============================================================================
SUB DrawHUD()
    DIM x1w AS WORD, y1w AS WORD, x2w AS WORD, y2w AS WORD, cw AS BYTE
    DIM s   AS STRING
    DIM fx  AS WORD
    DIM fy  AS WORD
    DIM ff  AS BYTE
    DIM fb  AS BYTE
    DIM fl  AS BYTE
    DIM spdKmh AS INTEGER
    DIM secs   AS INTEGER
    DIM sStr   AS STRING
    DIM pStr   AS STRING

    x1w = 0 : y1w = 186 : x2w = 319 : y2w = 199 : cw = %C_HUDBAR
    CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)

    spdKmh = (plSpeed \ %FP16) * 6
    sStr   = STR$(spdKmh)
    s      = "SPD:" + sStr
    fx = 2 : fy = 188 : ff = %C_WHITE : fb = %C_HUDBAR : fl = 0
    CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)

    sStr = STR$(lapNum)
    s    = "LAP:" + sStr
    fx = 110 : fy = 188 : ff = %C_YELLOW : fb = %C_HUDBAR : fl = 0
    CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)

    secs = lapTime \ 60
    sStr = STR$(secs)
    s    = "T:" + sStr
    fx = 180 : fy = 188 : ff = %C_WHITE : fb = %C_HUDBAR : fl = 0
    CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)

    pStr = STR$(racePos)
    s    = "P" + pStr
    fx = 280 : fy = 188 : ff = %C_YELLOW : fb = %C_HUDBAR : fl = 0
    CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)

    IF raceOver = 1 THEN
        x1w = 40 : y1w = 88 : x2w = 280 : y2w = 112 : cw = %C_HUDBAR
        CALL Svga_FillRect(x1w, y1w, x2w, y2w, cw)
        sStr = STR$(finSecs)
        s    = "FINISH " + sStr + "s"
        fx = 50 : fy = 94 : ff = %C_YELLOW : fb = %C_HUDBAR : fl = 0
        CALL Fonts_VgaPrint(fx, fy, ff, fb, s, fl)
    END IF
END SUB
