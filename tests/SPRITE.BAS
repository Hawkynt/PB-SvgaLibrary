' =============================================================================
' SPRITE.BAS - tests for SPRITE.SUB (sprite state machine: create / move /
'              collision / info / free). Drawing (Sprite_Draw) needs VRAM +
'              the Ani_*/Svga_FillRect collaborators and is not exercised here.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "SPRITE.SUB"

' collaborators referenced by SPRITE.SUB (only needed to satisfy the compiler;
' the code paths that call them - animated sprites, drawing - are not tested):
SUB Ani_GetAnimationInfo(a AS BYTE, w AS WORD, h AS WORD, fc AS WORD, hx AS WORD, hy AS WORD)
END SUB
SUB Ani_PlayAnimation(a AS BYTE, x AS INTEGER, y AS INTEGER, lp AS INTEGER)
END SUB
SUB Ani_ShowFrame(a AS BYTE, x AS INTEGER, y AS INTEGER, fr AS INTEGER)
END SUB
SUB Ani_StopAnimation(a AS BYTE)
END SUB
SUB Svga_FillRect(x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER, c AS BYTE)
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

' === entry point ===
SVGAScreenContext.XRes = 320
SVGAScreenContext.YRes = 200
CALL Test_BeginSuite("SPRITE")
Test_Create_HappyPath
Test_Create_MultipleHandles
Test_SetPosition
Test_Move_Bounce
Test_Move_Wrap
Test_Move_Stop
Test_CollisionRect
Test_CollisionCircle
Test_Collision_RespectsFlagAndHandle
Test_Free
CALL Test_EndSuite("SPRITE")
END
