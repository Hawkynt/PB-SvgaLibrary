' =============================================================================
' SPRITE.BAS - tests for SPRITE.SUB
'   - Sprite state machine: create / move / collision / info / free
'   - Sprite_Draw real pixel blit: opaque pixels, transparency, clipping,
'     Sprite_DrawAll priority ordering
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "SPRITE.SUB"

' collaborators: DrawAni_* are no-op stubs (animated code paths not tested here).
' Svga_PutPixel and Svga_HLine route to the real VGA implementations so that
' Sprite_Draw's generic path actually writes VRAM we can read back.
SUB DrawAni_GetAnimationInfo(a AS BYTE, w AS WORD, h AS WORD, fc AS WORD, hx AS WORD, hy AS WORD)
END SUB
SUB DrawAni_PlayAnimation(a AS BYTE, x AS INTEGER, y AS INTEGER, lp AS INTEGER)
END SUB
SUB DrawAni_ShowFrame(a AS BYTE, x AS INTEGER, y AS INTEGER, fr AS INTEGER)
END SUB
SUB DrawAni_StopAnimation(a AS BYTE)
END SUB
SUB Svga_FillRect(x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER, c AS BYTE)
    DIM wx1 AS WORD, wy1 AS WORD, wx2 AS WORD, wy2 AS WORD, wc AS BYTE
    wx1 = x1 : wy1 = y1 : wx2 = x2 : wy2 = y2 : wc = c
    CALL Vga_FillRect(wx1, wy1, wx2, wy2, wc)
END SUB
SUB Svga_PutPixel(x AS WORD, y AS WORD, c AS BYTE)
    DIM lx AS WORD, ly AS WORD, lc AS BYTE
    lx = x : ly = y : lc = c
    CALL Vga_PutPixel(lx, ly, lc)
END SUB
SUB Svga_HLine(x1 AS WORD, x2 AS WORD, y AS WORD, c AS BYTE)
    DIM lx1 AS WORD, lx2 AS WORD, ly AS WORD, lc AS BYTE
    lx1 = x1 : lx2 = x2 : ly = y : lc = c
    CALL Vga_HLine(lx1, lx2, ly, lc)
END SUB

' Memory_ClearVideoMemory stub used by Vga_ClearScreen
SUB Memory_ClearVideoMemory(BYVAL c AS BYTE)
    DIM cw AS WORD
    cw = c : SHIFT LEFT cw, 8 : cw = cw OR c
    !MOV AX, &HA000
    !MOV ES, AX
    !XOR DI, DI
    !MOV CX, 32000
    !MOV AX, cw
    !CLD
    !REP STOSW
END SUB

' Vga_InitMode13h calls Svga_InitDispatchTable; stub it out
SUB Svga_InitDispatchTable
END SUB

' ---------------------------------------------------------------------------
' Helpers
' ---------------------------------------------------------------------------
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

SUB ClrScr(BYVAL c AS BYTE)
    DIM cv AS BYTE : cv = c
    CALL Vga_ClearScreen(cv)
END SUB

FUNCTION CreateS(BYVAL x AS INTEGER, BYVAL y AS INTEGER, BYVAL w AS WORD, BYVAL h AS WORD) AS BYTE
    CreateS = Sprite_Create(x, y, w, h, "X")
END FUNCTION
FUNCTION GX(BYVAL h AS BYTE) AS INTEGER
    DIM x AS INTEGER, y AS INTEGER, w AS WORD, ht AS WORD, fl AS WORD
    CALL Sprite_GetInfo(h, x, y, w, ht, fl) : GX = x
END FUNCTION
FUNCTION GY(BYVAL h AS BYTE) AS INTEGER
    DIM x AS INTEGER, y AS INTEGER, w AS WORD, ht AS WORD, fl AS WORD
    CALL Sprite_GetInfo(h, x, y, w, ht, fl) : GY = y
END FUNCTION
FUNCTION GFL(BYVAL h AS BYTE) AS INTEGER
    DIM x AS INTEGER, y AS INTEGER, w AS WORD, ht AS WORD, fl AS WORD
    CALL Sprite_GetInfo(h, x, y, w, ht, fl) : GFL = fl
END FUNCTION

' ---------------------------------------------------------------------------
' 4x4 test image with a diagonal of transparent (colour 0) holes:
'   Row 0: 0  1  2  3
'   Row 1: 4  0  6  7
'   Row 2: 8  9  0 11
'   Row 3: 12 13 14  0
' ---------------------------------------------------------------------------
FUNCTION Make4x4Image AS STRING
    Make4x4Image = CHR$(0)  + CHR$(1)  + CHR$(2)  + CHR$(3)  + _
                   CHR$(4)  + CHR$(0)  + CHR$(6)  + CHR$(7)  + _
                   CHR$(8)  + CHR$(9)  + CHR$(0)  + CHR$(11) + _
                   CHR$(12) + CHR$(13) + CHR$(14) + CHR$(0)
END FUNCTION

' =============================================================================
' State-machine tests
' =============================================================================

SUB Test_Create_HappyPath
    CALL Test_Case("Create returns slot 0 and records geometry + default flags")
    DIM h AS BYTE, x AS INTEGER, y AS INTEGER, w AS WORD, ht AS WORD, fl AS WORD
    CALL Sprite_Init
    h = CreateS(10, 20, 16, 24)
    CALL Assert_IsEqual(h, 0, "first sprite gets handle 0")
    CALL Sprite_GetInfo(h, x, y, w, ht, fl)
    CALL Assert_IsEqual(x, 10, "X stored") : CALL Assert_IsEqual(y, 20, "Y stored")
    CALL Assert_IsEqual(w, 16, "width stored") : CALL Assert_IsEqual(ht, 24, "height stored")
    CALL Assert_IsNotZero(fl AND %SPRITE_VISIBLE, "VISIBLE flag set by default")
    CALL Assert_IsNotZero(fl AND %SPRITE_COLLISION, "COLLISION flag set by default")
END SUB

SUB Test_Create_MultipleHandles
    CALL Test_Case("Create hands out ascending free slots")
    CALL Sprite_Init
    CALL Assert_IsEqual(CreateS(0, 0, 8, 8), 0, "1st -> 0")
    CALL Assert_IsEqual(CreateS(0, 0, 8, 8), 1, "2nd -> 1")
    CALL Assert_IsEqual(CreateS(0, 0, 8, 8), 2, "3rd -> 2")
    CALL Assert_IsEqual(SpriteCount, 3, "SpriteCount tracks live sprites")
END SUB

SUB Test_SetPosition
    CALL Test_Case("SetPosition updates the live position")
    DIM h AS BYTE
    CALL Sprite_Init : h = CreateS(0, 0, 8, 8)
    CALL Sprite_SetPosition(h, 50, 60)
    CALL Assert_IsEqual(GX(h), 50, "X moved") : CALL Assert_IsEqual(GY(h), 60, "Y moved")
END SUB

SUB Test_Move_Bounce
    CALL Test_Case("Move bounces off a boundary and reverses velocity")
    DIM h AS BYTE
    CALL Sprite_Init : h = CreateS(0, 0, 10, 10)
    CALL Sprite_SetBounds(h, 0, 0, 60, 60, %MOVE_BOUNCE)
    CALL Sprite_SetPosition(h, 58, 30)
    CALL Sprite_SetVelocity(h, 5, 0)
    CALL Sprite_Move(h)
    CALL Assert_IsEqual(GX(h), 53, "crossing the right edge reflects: 58 + (-5)")
    CALL Sprite_Move(h)
    CALL Assert_IsEqual(GX(h), 48, "velocity stays reversed on the next step")
END SUB

SUB Test_Move_Wrap
    CALL Test_Case("Move wraps from one edge to the other")
    DIM h AS BYTE
    CALL Sprite_Init : h = CreateS(0, 0, 10, 10)
    CALL Sprite_SetBounds(h, 10, 10, 100, 100, %MOVE_WRAP)
    CALL Sprite_SetPosition(h, 12, 50)
    CALL Sprite_SetVelocity(h, -5, 0)
    CALL Sprite_Move(h)
    CALL Assert_IsEqual(GX(h), 100, "going past the left edge wraps to the right bound")
END SUB

SUB Test_Move_Stop
    CALL Test_Case("Move clamps at a boundary and halts")
    DIM h AS BYTE
    CALL Sprite_Init : h = CreateS(0, 0, 10, 10)
    CALL Sprite_SetBounds(h, 0, 0, 100, 100, %MOVE_STOP)
    CALL Sprite_SetPosition(h, 98, 50)
    CALL Sprite_SetVelocity(h, 10, 0)
    CALL Sprite_Move(h)
    CALL Assert_IsEqual(GX(h), 100, "clamped to the right bound")
    CALL Sprite_Move(h)
    CALL Assert_IsEqual(GX(h), 100, "velocity zeroed -> stays put")
END SUB

SUB Test_CollisionRect
    CALL Test_Case("Rect collision: overlap=1, separate=0, edge-touch=0")
    DIM a AS BYTE, b AS BYTE
    CALL Sprite_Init
    a = CreateS(10, 10, 20, 20)
    b = CreateS(25, 25, 20, 20)
    CALL Assert_IsEqual(Sprite_CollisionRect(a, b), 1, "overlapping rectangles collide")
    CALL Sprite_SetPosition(b, 40, 40)
    CALL Assert_IsEqual(Sprite_CollisionRect(a, b), 0, "separated rectangles do not")
    CALL Sprite_SetPosition(b, 30, 10)
    CALL Assert_IsEqual(Sprite_CollisionRect(a, b), 0, "edge-touching (A.right == B.left) does not")
END SUB

SUB Test_CollisionCircle
    CALL Test_Case("Circle collision uses centre distance vs radius sum")
    DIM a AS BYTE, b AS BYTE
    CALL Sprite_Init
    a = CreateS(10, 10, 20, 20)
    b = CreateS(20, 20, 20, 20)
    CALL Assert_IsEqual(Sprite_CollisionCircle(a, b), 1, "near centres collide")
    CALL Sprite_SetPosition(b, 100, 100)
    CALL Assert_IsEqual(Sprite_CollisionCircle(a, b), 0, "far centres do not")
END SUB

SUB Test_Collision_RespectsFlagAndHandle
    CALL Test_Case("Collision honours the COLLISION flag and rejects bad handles")
    DIM a AS BYTE, b AS BYTE
    CALL Sprite_Init
    a = CreateS(10, 10, 20, 20)
    b = CreateS(15, 15, 20, 20)
    CALL Assert_IsEqual(Sprite_Collision(a, b), 1, "overlapping collidable sprites collide")
    CALL Sprite_SetFlags(a, %SPRITE_VISIBLE)          ' clears COLLISION
    CALL Assert_IsEqual(Sprite_Collision(a, b), 0, "clearing the COLLISION flag suppresses it")
    CALL Assert_IsEqual(Sprite_Collision(40, b), 0, "out-of-range handle returns 0")
END SUB

SUB Test_Free
    CALL Test_Case("Free deactivates the slot and decrements the count")
    DIM h AS BYTE
    CALL Sprite_Init
    h = CreateS(10, 10, 8, 8)
    CALL Assert_IsEqual(SpriteCount, 1, "one live sprite")
    CALL Sprite_Free(h)
    CALL Assert_IsEqual(SpriteCount, 0, "count back to zero")
    CALL Assert_IsEqual(GFL(h), 0, "GetInfo reports inactive (flags=0)")
END SUB

' =============================================================================
' Drawing tests - mode 13h, VRAM is live (Test_Setup sets up video hardware)
' =============================================================================

SUB Test_Draw_OpaquePixels
    CALL Test_Case("Sprite_Draw blits opaque pixels to VRAM")
    DIM h AS BYTE, img AS STRING
    CALL Sprite_Init
    CALL ClrScr(0)
    img = Make4x4Image
    h = Sprite_Create(10, 20, 4, 4, img)
    CALL Sprite_Draw(h)
    ' Row 0 at y=20: col1..3 opaque at x=11,12,13
    CALL Assert_IsEqual(GetP(11, 20), 1,  "row0 col1 opaque=1")
    CALL Assert_IsEqual(GetP(12, 20), 2,  "row0 col2 opaque=2")
    CALL Assert_IsEqual(GetP(13, 20), 3,  "row0 col3 opaque=3")
    ' Row 1 at y=21: col0, col2, col3 opaque
    CALL Assert_IsEqual(GetP(10, 21), 4,  "row1 col0 opaque=4")
    CALL Assert_IsEqual(GetP(12, 21), 6,  "row1 col2 opaque=6")
    CALL Assert_IsEqual(GetP(13, 21), 7,  "row1 col3 opaque=7")
    ' Row 3 at y=23: col0, col1, col2 opaque
    CALL Assert_IsEqual(GetP(10, 23), 12, "row3 col0 opaque=12")
    CALL Assert_IsEqual(GetP(11, 23), 13, "row3 col1 opaque=13")
    CALL Assert_IsEqual(GetP(12, 23), 14, "row3 col2 opaque=14")
END SUB

SUB Test_Draw_TransparentHoles
    CALL Test_Case("Sprite_Draw leaves colour-0 pixels (transparent) untouched")
    DIM h AS BYTE, img AS STRING
    CALL Sprite_Init
    CALL ClrScr(99)
    img = Make4x4Image
    h = Sprite_Create(10, 20, 4, 4, img)
    CALL Sprite_Draw(h)
    ' Diagonal holes must remain background colour 99
    CALL Assert_IsEqual(GetP(10, 20), 99, "row0 col0 transparent -> bg")
    CALL Assert_IsEqual(GetP(11, 21), 99, "row1 col1 transparent -> bg")
    CALL Assert_IsEqual(GetP(12, 22), 99, "row2 col2 transparent -> bg")
    CALL Assert_IsEqual(GetP(13, 23), 99, "row3 col3 transparent -> bg")
END SUB

SUB Test_Draw_ClipRight
    CALL Test_Case("Sprite_Draw clips at right screen edge without wrap or crash")
    DIM h AS BYTE, img AS STRING
    CALL Sprite_Init
    CALL ClrScr(0)
    img = Make4x4Image
    ' col0 transparent (x=318), col1 opaque=1 (x=319), col2/3 off-screen
    h = Sprite_Create(318, 50, 4, 4, img)
    CALL Sprite_Draw(h)
    CALL Assert_IsEqual(GetP(319, 50), 1, "clip-right: last on-screen opaque pixel drawn")
    CALL Assert_IsNotZero(1, "clip-right draw completed without crash")
END SUB

SUB Test_Draw_ClipLeft
    CALL Test_Case("Sprite_Draw clips at left screen edge (negative X)")
    DIM h AS BYTE, img AS STRING
    CALL Sprite_Init
    CALL ClrScr(0)
    img = Make4x4Image
    ' Sprite X=-2: cols 0-1 off-screen; col2=2 at x=0, col3=3 at x=1
    h = Sprite_Create(-2, 50, 4, 4, img)
    CALL Sprite_Draw(h)
    CALL Assert_IsEqual(GetP(0, 50), 2, "clip-left: col2 appears at x=0")
    CALL Assert_IsEqual(GetP(1, 50), 3, "clip-left: col3 appears at x=1")
END SUB

SUB Test_Draw_ClipTop
    CALL Test_Case("Sprite_Draw clips at top screen edge (negative Y)")
    DIM h AS BYTE, img AS STRING
    CALL Sprite_Init
    CALL ClrScr(0)
    img = Make4x4Image
    ' Sprite Y=-2: rows 0-1 off-screen; row2 at y=0, row3 at y=1
    ' Row2: 8 9 [0] 11  -> x=50:8, x=51:9, x=52 transparent, x=53:11
    h = Sprite_Create(50, -2, 4, 4, img)
    CALL Sprite_Draw(h)
    CALL Assert_IsEqual(GetP(50, 0), 8,  "clip-top: row2 col0 at y=0")
    CALL Assert_IsEqual(GetP(51, 0), 9,  "clip-top: row2 col1 at y=0")
    CALL Assert_IsEqual(GetP(53, 0), 11, "clip-top: row2 col3 at y=0")
END SUB

SUB Test_Draw_ClipBottom
    CALL Test_Case("Sprite_Draw clips at bottom screen edge")
    DIM h AS BYTE, img AS STRING
    CALL Sprite_Init
    CALL ClrScr(0)
    img = Make4x4Image
    ' Sprite Y=198: row0 at y=198, row1 at y=199; rows 2-3 off-screen
    h = Sprite_Create(50, 198, 4, 4, img)
    CALL Sprite_Draw(h)
    CALL Assert_IsEqual(GetP(51, 198), 1, "clip-bottom: row0 col1 at y=198")
    CALL Assert_IsEqual(GetP(50, 199), 4, "clip-bottom: row1 col0 at y=199")
END SUB

SUB Test_DrawAll_PriorityOrder
    CALL Test_Case("Sprite_DrawAll draws sprites in ascending priority (higher wins)")
    DIM ha AS BYTE, hb AS BYTE
    CALL Sprite_Init
    CALL ClrScr(0)
    ' Sprite A (priority 200, colour 1) and B (priority 10, colour 2) at same position
    ha = Sprite_Create(60, 60, 2, 2, CHR$(1) + CHR$(1) + CHR$(1) + CHR$(1))
    CALL Sprite_SetPriority(ha, 200)
    hb = Sprite_Create(60, 60, 2, 2, CHR$(2) + CHR$(2) + CHR$(2) + CHR$(2))
    CALL Sprite_SetPriority(hb, 10)
    CALL Sprite_DrawAll
    ' DrawAll sorts ascending: B(10) drawn first, A(200) drawn on top
    CALL Assert_IsEqual(GetP(60, 60), 1, "higher-priority sprite drawn on top")
END SUB

SUB Test_Setup
SVGAScreenContext.XRes = 320
SVGAScreenContext.YRes = 200
VESASystemContext.CurrentMode = %SVGA_MODE13
!MOV AX, &H0013
!INT &H10
END SUB

SUB Test_Teardown
!MOV AX, &H0003
!INT &H10
END SUB
