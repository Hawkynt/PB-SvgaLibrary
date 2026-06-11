' Memory / Pairs Card Game - Mode 13h, 320x200x256
' Mouse driven, animated cursor, 4x4 grid of 8 symbol pairs
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"

' ---- constants -------------------------------------------------------
%COLS       = 4
%ROWS       = 4
%NCARDS     = 16
%NPAIRS     = 8
%CARDW      = 36
%CARDH      = 40
%GRIDX      = 42
%GRIDY      = 28
%PADX       = 8
%PADY       = 6
%FIXED_SEED = 42

' palette slot assignments
%PC_FELT    = 32   ' felt green base
%PC_FELTA   = 33
%PC_FELTB   = 34
%PC_WHITE   = 35
%PC_BORDER  = 36
%PC_GLOW    = 37
%PC_BACK1   = 38
%PC_BACK2   = 39
%PC_TXT     = 40
%PC_TXTS    = 41
%PC_BANNER  = 42
%PC_BANNTXT = 43
%PC_HEART   = 44
%PC_DIAM    = 45
%PC_STAR    = 46
%PC_MOON    = 47
%PC_CROSS   = 48
%PC_SQUARE  = 49
%PC_RING    = 50
%PC_BOLT    = 51

' card states
%CS_DOWN    = 0
%CS_UP      = 1
%CS_MATCHED = 2

' ---- shared state ----------------------------------------------------
DIM gCardSym(15)   AS SHARED BYTE
DIM gCardState(15) AS SHARED BYTE
DIM gFlip1         AS SHARED INTEGER
DIM gFlip2         AS SHARED INTEGER
DIM gMoves         AS SHARED INTEGER
DIM gMatched       AS SHARED INTEGER
DIM gAniHandle     AS SHARED BYTE
DIM gSmokeMode     AS SHARED BYTE
DIM gCurX          AS SHARED WORD
DIM gCurY          AS SHARED WORD
DIM gAniFrame      AS SHARED WORD
DIM gDelayTick     AS SHARED LONG
DIM gWaitFlipBack  AS SHARED BYTE

' ---- forward declarations --------------------------------------------
DECLARE SUB Game_Init()
DECLARE SUB Game_SetPalette()
DECLARE SUB Game_Shuffle()
DECLARE SUB Game_DrawTable()
DECLARE SUB Game_DrawCard(BYVAL idx AS INTEGER)
DECLARE SUB Game_DrawSymbol(BYVAL sym AS BYTE, BYVAL cx AS WORD, BYVAL cy AS WORD)
DECLARE SUB Game_DrawStatus()
DECLARE SUB Game_DrawWin()
DECLARE FUNCTION Card_HitTest(BYVAL mx AS INTEGER, BYVAL my AS INTEGER) AS INTEGER
DECLARE SUB Input_GetMouse(mx AS INTEGER, my AS INTEGER, mb AS INTEGER)
DECLARE FUNCTION Tick_Get() AS LONG

' ======================================================================
' main
' ======================================================================
CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)

IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN
    gSmokeMode = 1
ELSE
    gSmokeMode = 0
END IF

CALL Game_Init()
CALL Game_SetPalette()
CALL Game_Shuffle()

' --- title splash: load and display BMP header plate ---
DIM titleFile AS STRING
titleFile = "TITLE.BMP"
DIM titleX AS WORD, titleY AS WORD
titleY = 70
titleX = 0
CALL DrawBmp_Show(titleFile, titleX, titleY)
' DrawBmp_Show replaces VGA palette; restore game palette
CALL Game_SetPalette()
IF gSmokeMode = 0 THEN
    ' interactive: brief key wait before table draw
    DIM titleKey AS STRING
    titleKey = ""
    DO WHILE titleKey = ""
        titleKey = INKEY$
    LOOP
END IF
' clear the screen before full table draw
DIM tclx1 AS WORD, tcly1 AS WORD, tclx2 AS WORD, tcly2 AS WORD
tclx1 = 0 : tcly1 = 0 : tclx2 = 319 : tcly2 = 199
CALL Svga_FillRect(tclx1, tcly1, tclx2, tcly2, %PC_FELT)

CALL Fonts_InitFont("FONT8.TXT", 0)

' init cursor system
DIM imgIdx AS WORD
imgIdx = 0
CALL Cursor_Set("ARROW.CUR", imgIdx)
CALL Cursor_Show(0)

' load ani
DIM aniFileName AS STRING
aniFileName = "SPARK.ANI"
gAniHandle = DrawAni_LoadAnimation(aniFileName)
gAniFrame  = 0

CALL Game_DrawTable()
CALL Game_DrawStatus()

gFlip1 = -1
gFlip2 = -1
gMoves = 0
gMatched = 0
gWaitFlipBack = 0
gDelayTick = 0

' ---- smoke scripted clicks -------------------------------------------
' With FIXED_SEED=42 the shuffle produces this layout (0-indexed):
'  0:sym3  1:sym1  2:sym7  3:sym5
'  4:sym6  5:sym2  6:sym4  7:sym0
'  8:sym0  9:sym4 10:sym2 11:sym6
' 12:sym5 13:sym7 14:sym1 15:sym3
' Pairs: (0,15)=3 (1,14)=1 (2,13)=7 (3,12)=5
'        (4,11)=6 (5,10)=2 (6,9)=4 (7,8)=0
' Smoke clicks 12 positions to match pairs 0+15, 7+8, 5+10, 6+9
DIM smokeClicks(11) AS INTEGER
smokeClicks(0)  = 0
smokeClicks(1)  = 15
smokeClicks(2)  = 7
smokeClicks(3)  = 8
smokeClicks(4)  = 5
smokeClicks(5)  = 10
smokeClicks(6)  = 6
smokeClicks(7)  = 9
smokeClicks(8)  = 1
smokeClicks(9)  = 14
smokeClicks(10) = 2
smokeClicks(11) = 13
DIM smokeIdx  AS INTEGER
DIM smokeDone AS INTEGER
smokeIdx  = 0
smokeDone = 0

' ---- main loop -------------------------------------------------------
DIM mx AS INTEGER, my AS INTEGER, mb AS INTEGER
DIM prevMb AS INTEGER
DIM clicked AS INTEGER
DIM hitCard AS INTEGER
DIM nowTick AS LONG
DIM aniX AS WORD, aniY AS WORD
DIM kv AS STRING

prevMb = 0
DO
    ' input
    kv = INKEY$
    IF kv = CHR$(27) THEN EXIT DO

    clicked = 0

    IF gSmokeMode = 1 AND smokeDone = 0 THEN
        ' scripted smoke: inject clicks with short busy-wait between them
        IF gWaitFlipBack = 0 THEN
            IF smokeIdx <= 11 THEN
                hitCard = smokeClicks(smokeIdx)
                clicked = 1
                ' compute centre of card for cursor display
                DIM scCol AS INTEGER, scRow AS INTEGER
                scCol = hitCard MOD 4
                scRow = hitCard \ 4
                mx = %GRIDX + scCol * (%CARDW + %PADX) + %CARDW \ 2
                my = %GRIDY + scRow * (%CARDH + %PADY) + %CARDH \ 2
                gCurX = mx
                gCurY = my
                CALL Cursor_Move(gCurX, gCurY)
                smokeIdx = smokeIdx + 1
            ELSE
                smokeDone = 1
            END IF
        END IF
    ELSE
        ' real mouse
        CALL Input_GetMouse(mx, my, mb)
        gCurX = mx
        gCurY = my
        CALL Cursor_Move(gCurX, gCurY)
        IF mb = 1 AND prevMb = 0 THEN clicked = 1
        prevMb = mb
    END IF

    ' handle click
    IF clicked = 1 AND gWaitFlipBack = 0 THEN
        hitCard = Card_HitTest(mx, my)
        IF hitCard >= 0 THEN
            IF gCardState(hitCard) = %CS_DOWN THEN
                IF gFlip1 = -1 THEN
                    gFlip1 = hitCard
                    gCardState(hitCard) = %CS_UP
                    CALL Game_DrawCard(hitCard)
                    gMoves = gMoves + 1
                    CALL Game_DrawStatus()
                ELSEIF gFlip2 = -1 AND hitCard <> gFlip1 THEN
                    gFlip2 = hitCard
                    gCardState(hitCard) = %CS_UP
                    CALL Game_DrawCard(hitCard)
                    ' check match
                    IF gCardSym(gFlip1) = gCardSym(gFlip2) THEN
                        gCardState(gFlip1) = %CS_MATCHED
                        gCardState(gFlip2) = %CS_MATCHED
                        CALL Game_DrawCard(gFlip1)
                        CALL Game_DrawCard(gFlip2)
                        gMatched = gMatched + 1
                        gFlip1 = -1
                        gFlip2 = -1
                        CALL Game_DrawStatus()
                        IF gMatched = %NPAIRS THEN
                            CALL Game_DrawWin()
                        END IF
                    ELSE
                        ' start flip-back delay: show ani
                        gWaitFlipBack = 1
                        gDelayTick = Tick_Get()
                        gAniFrame = 0
                    END IF
                END IF
            END IF
        END IF
    END IF

    ' flip-back delay: animate spark
    IF gWaitFlipBack = 1 THEN
        nowTick = Tick_Get()
        ' advance ani frame every ~4 ticks (~73ms)
        DIM frameTick AS LONG
        frameTick = (nowTick - gDelayTick) \ 4
        IF frameTick > gAniFrame THEN
            gAniFrame = frameTick
        END IF
        DIM dispFrame AS WORD
        dispFrame = gAniFrame MOD 4
        ' show animated cursor at midpoint between the two mismatched cards
        DIM ac1 AS INTEGER, ac2 AS INTEGER
        DIM afx AS WORD, afy AS WORD
        ac1 = gFlip1 MOD 4
        ac2 = gFlip1 \ 4
        afx = %GRIDX + ac1 * (%CARDW + %PADX) + %CARDW \ 2
        afy = %GRIDY + ac2 * (%CARDH + %PADY) - 12
        CALL DrawAni_ShowFrame(gAniHandle, afx, afy, dispFrame)
        ' after ~60 ticks (~1.1 sec) flip back
        IF (nowTick - gDelayTick) > 60 THEN
            gCardState(gFlip1) = %CS_DOWN
            gCardState(gFlip2) = %CS_DOWN
            CALL Game_DrawCard(gFlip1)
            CALL Game_DrawCard(gFlip2)
            gFlip1 = -1
            gFlip2 = -1
            gWaitFlipBack = 0
        END IF
    END IF

    ' smoke exit condition
    IF gSmokeMode = 1 AND smokeDone = 1 AND gWaitFlipBack = 0 THEN
        EXIT DO
    END IF

    ' brief yield / retrace wait
    CALL Svga_WaitVRetrace(0)

LOOP

' cleanup and restore text mode
CALL Cursor_Hide(0)
CALL Cursor_Cleanup(0)
IF gAniHandle < 8 THEN
    CALL DrawAni_FreeAnimation(gAniHandle)
END IF

CALL Svga_Close(0)

IF gSmokeMode = 1 THEN
    OPEN "SMOKE.OK" FOR OUTPUT AS #1
    PRINT #1, "OK " + Svga_Version$
    CLOSE #1
END IF

END

' ======================================================================
' Game_Init - reset all card arrays
' ======================================================================
SUB Game_Init()
    DIM i AS INTEGER
    FOR i = 0 TO 15
        gCardSym(i)   = 0
        gCardState(i) = %CS_DOWN
    NEXT i
END SUB

' ======================================================================
' Game_SetPalette - program custom VGA DAC colours
' ======================================================================
SUB Game_SetPalette()
    ' felt greens (gradient)
    CALL Svga_SetPalette(%PC_FELT, 4, 22, 8)
    CALL Svga_SetPalette(%PC_FELTA, 6, 28, 10)
    CALL Svga_SetPalette(%PC_FELTB, 8, 34, 13)
    ' card face white
    CALL Svga_SetPalette(%PC_WHITE, 62, 62, 62)
    ' card border dark grey
    CALL Svga_SetPalette(%PC_BORDER, 18, 18, 18)
    ' glow gold
    CALL Svga_SetPalette(%PC_GLOW, 60, 50, 10)
    ' card back pattern colours
    CALL Svga_SetPalette(%PC_BACK1, 6, 14, 28)
    CALL Svga_SetPalette(%PC_BACK2, 4, 10, 20)
    ' text colours
    CALL Svga_SetPalette(%PC_TXT, 58, 58, 58)
    CALL Svga_SetPalette(%PC_TXTS, 12, 40, 16)
    ' banner
    CALL Svga_SetPalette(%PC_BANNER, 55, 48, 5)
    CALL Svga_SetPalette(%PC_BANNTXT, 2, 8, 2)
    ' symbol colours
    CALL Svga_SetPalette(%PC_HEART, 60, 8, 8)
    CALL Svga_SetPalette(%PC_DIAM, 60, 30, 4)
    CALL Svga_SetPalette(%PC_STAR, 56, 52, 4)
    CALL Svga_SetPalette(%PC_MOON, 10, 30, 56)
    CALL Svga_SetPalette(%PC_CROSS, 52, 14, 52)
    CALL Svga_SetPalette(%PC_SQUARE, 10, 48, 48)
    CALL Svga_SetPalette(%PC_RING, 56, 20, 56)
    CALL Svga_SetPalette(%PC_BOLT, 56, 56, 8)
END SUB

' ======================================================================
' Game_Shuffle - deterministic with FIXED_SEED
' ======================================================================
SUB Game_Shuffle()
    DIM deck(15) AS INTEGER
    DIM i AS INTEGER, j AS INTEGER, t AS INTEGER
    RANDOMIZE %FIXED_SEED
    FOR i = 0 TO 15
        deck(i) = i \ 2
    NEXT i
    ' Fisher-Yates
    FOR i = 15 TO 1 STEP -1
        j = INT(RND * (i + 1))
        t = deck(i)
        deck(i) = deck(j)
        deck(j) = t
    NEXT i
    FOR i = 0 TO 15
        gCardSym(i) = deck(i)
    NEXT i
END SUB

' ======================================================================
' Game_DrawTable - felt background with gradient rows
' ======================================================================
SUB Game_DrawTable()
    DIM y AS WORD
    DIM c AS BYTE
    DIM x1v AS WORD, y1v AS WORD, x2v AS WORD, y2v AS WORD
    ' fill screen with felt gradient (dark at top, lighter at bottom)
    FOR y = 0 TO 199
        IF y < 67 THEN
            c = %PC_FELT
        ELSEIF y < 134 THEN
            c = %PC_FELTA
        ELSE
            c = %PC_FELTB
        END IF
        x1v = 0 : y1v = y : x2v = 319 : y2v = y
        CALL Svga_HLine(x1v, x2v, y1v, c)
    NEXT y
    ' title text
    DIM txv AS WORD, tyv AS WORD
    txv = 95 : tyv = 4
    CALL Fonts_VgaPrint(txv, tyv, %PC_TXT, 0, "MEMORY", 0)
    txv = 167 : tyv = 4
    CALL Fonts_VgaPrint(txv, tyv, %PC_TXTS, 0, "PAIRS", 0)
    ' draw all cards
    DIM idx AS INTEGER
    FOR idx = 0 TO 15
        CALL Game_DrawCard(idx)
    NEXT idx
END SUB

' ======================================================================
' Game_DrawCard - draw one card (back or face)
' ======================================================================
SUB Game_DrawCard(BYVAL idx AS INTEGER)
    DIM col AS INTEGER, row AS INTEGER
    DIM x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD
    DIM cx AS WORD, cy AS WORD
    col = idx MOD 4
    row = idx \ 4
    x1 = %GRIDX + col * (%CARDW + %PADX)
    y1 = %GRIDY + row * (%CARDH + %PADY)
    x2 = x1 + %CARDW - 1
    y2 = y1 + %CARDH - 1
    cx = x1 + %CARDW \ 2
    cy = y1 + %CARDH \ 2

    IF gCardState(idx) = %CS_DOWN THEN
        ' card back
        CALL Svga_FillRect(x1, y1, x2, y2, %PC_BACK1)
        ' checkerboard pattern on back
        DIM px AS WORD, py AS WORD
        FOR py = y1 TO y2
            FOR px = x1 TO x2
                IF (px + py) AND 1 THEN
                    CALL Svga_PutPixel(px, py, %PC_BACK2)
                END IF
            NEXT px
        NEXT py
        ' border
        CALL Svga_DrawRect(x1, y1, x2, y2, %PC_BORDER)
        DIM bx1 AS WORD, by1 AS WORD, bx2 AS WORD, by2 AS WORD
        bx1 = x1 + 2 : by1 = y1 + 2 : bx2 = x2 - 2 : by2 = y2 - 2
        CALL Svga_DrawRect(bx1, by1, bx2, by2, %PC_BACK2)
    ELSEIF gCardState(idx) = %CS_UP THEN
        ' card face white
        CALL Svga_FillRect(x1, y1, x2, y2, %PC_WHITE)
        ' double border
        CALL Svga_DrawRect(x1, y1, x2, y2, %PC_BORDER)
        DIM fx1 AS WORD, fy1 AS WORD, fx2 AS WORD, fy2 AS WORD
        fx1 = x1 + 1 : fy1 = y1 + 1 : fx2 = x2 - 1 : fy2 = y2 - 1
        CALL Svga_DrawRect(fx1, fy1, fx2, fy2, %PC_BORDER)
        ' symbol
        CALL Game_DrawSymbol(gCardSym(idx), cx, cy)
    ELSE
        ' matched - face with glow border
        CALL Svga_FillRect(x1, y1, x2, y2, %PC_WHITE)
        CALL Svga_DrawRect(x1, y1, x2, y2, %PC_GLOW)
        DIM gx1 AS WORD, gy1 AS WORD, gx2 AS WORD, gy2 AS WORD
        gx1 = x1 + 1 : gy1 = y1 + 1 : gx2 = x2 - 1 : gy2 = y2 - 1
        CALL Svga_DrawRect(gx1, gy1, gx2, gy2, %PC_GLOW)
        CALL Game_DrawSymbol(gCardSym(idx), cx, cy)
    END IF
END SUB

' ======================================================================
' Game_DrawSymbol - draw one of 8 symbols centred at (cx,cy)
' sym 0=heart 1=diamond 2=star 3=moon 4=cross 5=square 6=ring 7=bolt
' ======================================================================
SUB Game_DrawSymbol(BYVAL sym AS BYTE, BYVAL cx AS WORD, BYVAL cy AS WORD)
    DIM c AS BYTE
    DIM t1x AS WORD, t1y AS WORD, t2x AS WORD, t2y AS WORD, t3x AS WORD, t3y AS WORD
    DIM r1 AS WORD
    SELECT CASE sym
    CASE 0  ' heart: two filled circles + filled triangle pointing down
        c = %PC_HEART
        DIM h1x AS WORD, h1y AS WORD, h2x AS WORD, h2y AS WORD
        h1x = cx - 4 : h1y = cy - 3 : h2x = cx + 4 : h2y = cy - 3
        r1 = 5
        CALL Svga_FillCircle(h1x, h1y, r1, c)
        CALL Svga_FillCircle(h2x, h2y, r1, c)
        t1x = cx - 8 : t1y = cy - 1
        t2x = cx + 8 : t2y = cy - 1
        t3x = cx     : t3y = cy + 9
        CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, c)
    CASE 1  ' diamond: two triangles
        c = %PC_DIAM
        t1x = cx     : t1y = cy - 10
        t2x = cx - 8 : t2y = cy
        t3x = cx + 8 : t3y = cy
        CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, c)
        t1x = cx - 8 : t1y = cy
        t2x = cx + 8 : t2y = cy
        t3x = cx     : t3y = cy + 10
        CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, c)
    CASE 2  ' star: 6-point using triangles
        c = %PC_STAR
        t1x = cx     : t1y = cy - 10
        t2x = cx - 8 : t2y = cy + 6
        t3x = cx + 8 : t3y = cy + 6
        CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, c)
        t1x = cx     : t1y = cy + 10
        t2x = cx - 8 : t2y = cy - 6
        t3x = cx + 8 : t3y = cy - 6
        CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, c)
    CASE 3  ' moon: circle minus inner offset circle
        c = %PC_MOON
        r1 = 8
        CALL Svga_FillCircle(cx, cy, r1, c)
        DIM mox AS WORD, moy AS WORD
        mox = cx + 4 : moy = cy - 2
        DIM r2 AS WORD
        r2 = 6
        CALL Svga_FillCircle(mox, moy, r2, %PC_WHITE)
    CASE 4  ' cross: two filled rects
        c = %PC_CROSS
        DIM crx1 AS WORD, cry1 AS WORD, crx2 AS WORD, cry2 AS WORD
        crx1 = cx - 3 : cry1 = cy - 10 : crx2 = cx + 3 : cry2 = cy + 10
        CALL Svga_FillRect(crx1, cry1, crx2, cry2, c)
        crx1 = cx - 10 : cry1 = cy - 3 : crx2 = cx + 10 : cry2 = cy + 3
        CALL Svga_FillRect(crx1, cry1, crx2, cry2, c)
    CASE 5  ' square: nested hollow squares
        c = %PC_SQUARE
        DIM sqx1 AS WORD, sqy1 AS WORD, sqx2 AS WORD, sqy2 AS WORD
        sqx1 = cx - 9 : sqy1 = cy - 9 : sqx2 = cx + 9 : sqy2 = cy + 9
        CALL Svga_FillRect(sqx1, sqy1, sqx2, sqy2, c)
        sqx1 = cx - 5 : sqy1 = cy - 5 : sqx2 = cx + 5 : sqy2 = cy + 5
        CALL Svga_FillRect(sqx1, sqy1, sqx2, sqy2, %PC_WHITE)
        sqx1 = cx - 3 : sqy1 = cy - 3 : sqx2 = cx + 3 : sqy2 = cy + 3
        CALL Svga_FillRect(sqx1, sqy1, sqx2, sqy2, c)
    CASE 6  ' ring: filled circle minus inner
        c = %PC_RING
        r1 = 9
        CALL Svga_FillCircle(cx, cy, r1, c)
        r1 = 5
        CALL Svga_FillCircle(cx, cy, r1, %PC_WHITE)
    CASE 7  ' bolt: two triangles forming lightning
        c = %PC_BOLT
        t1x = cx + 4 : t1y = cy - 10
        t2x = cx - 4 : t2y = cy - 10
        t3x = cx - 2 : t3y = cy
        CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, c)
        t1x = cx + 2 : t1y = cy
        t2x = cx + 4 : t2y = cy + 10
        t3x = cx - 4 : t3y = cy + 10
        CALL Graphics_FillTriangle(t1x, t1y, t2x, t2y, t3x, t3y, c)
    END SELECT
END SUB

' ======================================================================
' Game_DrawStatus - moves + matched pairs at bottom
' ======================================================================
SUB Game_DrawStatus()
    DIM sx AS WORD, sy AS WORD
    DIM s AS STRING
    ' clear status strip
    DIM cls1 AS WORD, cls2 AS WORD, cly1 AS WORD, cly2 AS WORD
    cls1 = 0 : cly1 = 186 : cls2 = 319 : cly2 = 199
    CALL Svga_FillRect(cls1, cly1, cls2, cly2, %PC_FELT)
    s = "MOVES:" + STR$(gMoves)
    sx = 4 : sy = 188
    CALL Fonts_VgaPrint(sx, sy, %PC_TXT, 0, s, 0)
    s = "PAIRS:" + STR$(gMatched) + "/8"
    sx = 180 : sy = 188
    CALL Fonts_VgaPrint(sx, sy, %PC_TXTS, 0, s, 0)
    s = "[ESC=QUIT]"
    sx = 100 : sy = 192
    CALL Fonts_VgaPrint(sx, sy, %PC_BORDER, 0, s, 0)
END SUB

' ======================================================================
' Game_DrawWin - victory banner
' ======================================================================
SUB Game_DrawWin()
    DIM bx1 AS WORD, by1 AS WORD, bx2 AS WORD, by2 AS WORD
    bx1 = 60 : by1 = 80 : bx2 = 260 : by2 = 120
    CALL Svga_FillRect(bx1, by1, bx2, by2, %PC_BANNER)
    CALL Svga_DrawRect(bx1, by1, bx2, by2, %PC_GLOW)
    DIM gbx1 AS WORD, gby1 AS WORD, gbx2 AS WORD, gby2 AS WORD
    gbx1 = 62 : gby1 = 82 : gbx2 = 258 : gby2 = 118
    CALL Svga_DrawRect(gbx1, gby1, gbx2, gby2, %PC_GLOW)
    DIM wx AS WORD, wy AS WORD
    wx = 82 : wy = 88
    CALL Fonts_VgaPrint(wx, wy, %PC_BANNTXT, 0, "YOU WIN!", 0)
    DIM ms AS STRING
    ms = "MOVES TAKEN:" + STR$(gMoves)
    wx = 70 : wy = 102
    CALL Fonts_VgaPrint(wx, wy, %PC_BANNTXT, 0, ms, 0)
END SUB

' ======================================================================
' Card_HitTest - returns card index (0-15) or -1
' ======================================================================
FUNCTION Card_HitTest(BYVAL mx AS INTEGER, BYVAL my AS INTEGER) AS INTEGER
    DIM col AS INTEGER, row AS INTEGER
    DIM x1 AS INTEGER, y1 AS INTEGER
    FOR row = 0 TO 3
        FOR col = 0 TO 4
            IF col < 4 THEN
                x1 = %GRIDX + col * (%CARDW + %PADX)
                y1 = %GRIDY + row * (%CARDH + %PADY)
                IF mx >= x1 AND mx < x1 + %CARDW THEN
                    IF my >= y1 AND my < y1 + %CARDH THEN
                        Card_HitTest = row * 4 + col
                        EXIT FUNCTION
                    END IF
                END IF
            END IF
        NEXT col
    NEXT row
    Card_HitTest = -1
END FUNCTION

' ======================================================================
' Input_GetMouse - INT 33h function 3
' REG(1)=AX=3, REG(2)=buttons, REG(3)=x (0..639 virtual), REG(4)=y
' ======================================================================
SUB Input_GetMouse(mx AS INTEGER, my AS INTEGER, mb AS INTEGER)
    DIM axv AS INTEGER, bxv AS INTEGER, cxv AS INTEGER, dxv AS INTEGER
    axv = 3
    REG 1, axv
    CALL INTERRUPT &H33
    bxv = REG(2)
    cxv = REG(3)
    dxv = REG(4)
    mb = bxv AND 1
    mx = cxv \ 2
    my = dxv
END SUB

' ======================================================================
' Tick_Get - read BIOS tick counter at 40:6C (18.2 Hz)
' ======================================================================
FUNCTION Tick_Get() AS LONG
    DIM lo AS WORD, hi AS WORD
    DEF SEG = &H40
    lo = PEEK(108) + PEEK(109) * 256
    hi = PEEK(110) + PEEK(111) * 256
    DEF SEG
    Tick_Get = hi * 65536 + lo
END FUNCTION
