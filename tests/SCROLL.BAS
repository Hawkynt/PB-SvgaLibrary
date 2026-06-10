' =============================================================================
' SCROLL.BAS - tests for SCROLL.SUB (virtual-screen scrolling state machine).
'              Hardware register scrolls (Scroll_HardwareHorizontal/Vertical)
'              and parallax drawing need VRAM and are not exercised here.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "SCROLL.SUB"

SUB Svga_FillRect(x1 AS INTEGER, y1 AS INTEGER, x2 AS INTEGER, y2 AS INTEGER, c AS INTEGER)
END SUB

FUNCTION SX() AS INTEGER
    DIM x AS INTEGER, y AS INTEGER
    CALL Scroll_GetPosition(x, y) : SX = x
END FUNCTION
FUNCTION SY() AS INTEGER
    DIM x AS INTEGER, y AS INTEGER
    CALL Scroll_GetPosition(x, y) : SY = y
END FUNCTION

SUB Test_SetVirtualScreen
    CALL Test_Case("SetVirtualScreen sets dimensions, max offsets and activates")
    CALL Scroll_Init
    CALL Scroll_SetVirtualScreen(640, 400)
    CALL Assert_IsEqual(VirtualScreen.Wide, 640, "virtual width")
    CALL Assert_IsEqual(VirtualScreen.Height, 400, "virtual height")
    CALL Assert_IsEqual(VirtualScreen.MaxOffsetX, 320, "max X offset = virtual - screen")
    CALL Assert_IsEqual(VirtualScreen.MaxOffsetY, 200, "max Y offset = virtual - screen")
    CALL Assert_IsNotZero(VirtualScreen.IsActive, "marked active")
END SUB

SUB Test_SetPosition_Clamp
    CALL Test_Case("SetPosition (NORMAL) clamps to [0, maxOffset]")
    CALL Scroll_Init
    CALL Scroll_SetVirtualScreen(640, 400)
    CALL Scroll_SetMode(%SCROLL_MODE_NORMAL)
    CALL Scroll_SetPosition(100, 50)
    CALL Assert_IsEqual(SX(), 100, "in-range X kept")
    CALL Assert_IsEqual(SY(), 50, "in-range Y kept")
    CALL Scroll_SetPosition(-30, -30)
    CALL Assert_IsEqual(SX(), 0, "negative X clamps to 0")
    CALL Assert_IsEqual(SY(), 0, "negative Y clamps to 0")
    CALL Scroll_SetPosition(5000, 5000)
    CALL Assert_IsEqual(SX(), 320, "huge X clamps to maxOffset")
    CALL Assert_IsEqual(SY(), 200, "huge Y clamps to maxOffset")
END SUB

SUB Test_Screen_Relative
    CALL Test_Case("Scroll_Screen moves relative to the current offset")
    CALL Scroll_Init
    CALL Scroll_SetVirtualScreen(640, 400)
    CALL Scroll_SetPosition(100, 50)
    CALL Scroll_Screen(10, -20)
    CALL Assert_IsEqual(SX(), 110, "X += 10")
    CALL Assert_IsEqual(SY(), 30, "Y -= 20")
END SUB

SUB Test_Direction
    CALL Test_Case("Scroll_Direction maps directions to clamped deltas")
    CALL Scroll_Init
    CALL Scroll_SetVirtualScreen(640, 400)
    CALL Scroll_SetPosition(100, 100)
    CALL Scroll_Direction(%SCROLL_RIGHT, 5)
    CALL Assert_IsEqual(SX(), 105, "RIGHT advances X")
    CALL Scroll_Direction(%SCROLL_UP, 5)
    CALL Assert_IsEqual(SY(), 95, "UP decreases Y")
END SUB

SUB Test_Wrap_Mode
    CALL Test_Case("SetPosition (WRAP) wraps around the virtual extent")
    CALL Scroll_Init
    CALL Scroll_SetVirtualScreen(640, 400)
    CALL Scroll_SetMode(%SCROLL_MODE_WRAP)
    CALL Scroll_SetPosition(-5, 0)
    CALL Assert_IsEqual(SX(), 635, "negative X wraps to Wide-5")
END SUB

SUB Test_SmoothTo
    CALL Test_Case("SmoothTo steps toward the target and reports completion")
    DIM r AS INTEGER, guard AS INTEGER
    CALL Scroll_Init
    CALL Scroll_SetVirtualScreen(640, 400)
    CALL Scroll_SetMode(%SCROLL_MODE_NORMAL)
    CALL Scroll_SetPosition(0, 0)
    r = Scroll_SmoothTo(100, 0, 30)
    CALL Assert_IsEqual(SX(), 30, "first step advances by speed")
    CALL Assert_IsEqual(r, 0, "not complete yet")
    guard = 0
    WHILE Scroll_SmoothTo(100, 0, 30) = 0 AND guard < 20
        guard = guard + 1
    WEND
    CALL Assert_IsEqual(SX(), 100, "eventually reaches the target")
END SUB

SUB Test_SmoothTo_Inactive
    CALL Test_Case("SmoothTo reports complete when no virtual screen is active")
    CALL Scroll_Init                       ' IsActive stays 0 until SetVirtualScreen
    CALL Assert_IsEqual(Scroll_SmoothTo(50, 50, 10), 1, "inactive -> already complete")
END SUB

SUB Test_Parallax_CreateFree
    CALL Test_Case("Parallax layer create/free toggles the slot")
    CALL Scroll_Init
    CALL Scroll_CreateParallaxLayer(2, 64, 48, 128, 200, 5)
    CALL Assert_IsNotZero(ParallaxLayers(2).IsActive, "layer 2 active")
    CALL Assert_IsEqual(ParallaxLayers(2).Wide, 64, "layer width")
    CALL Assert_IsEqual(ParallaxLayers(2).ScrollRateX, 128, "layer scroll rate X")
    CALL Assert_IsEqual(ParallaxLayers(2).Priority, 5, "layer priority")
    CALL Scroll_FreeParallaxLayer(2)
    CALL Assert_IsZero(ParallaxLayers(2).IsActive, "layer 2 freed")
    CALL Scroll_CreateParallaxLayer(9, 8, 8, 1, 1, 1)   ' out of range -> no-op, no crash
    CALL Assert_IsTrue(-1, "out-of-range layer id is ignored safely")
END SUB

SUB Test_ScreenShake_ZeroIntensity
    CALL Test_Case("ScreenShake with zero intensity keeps the position and ends")
    CALL Scroll_Init
    CALL Scroll_SetVirtualScreen(640, 400)
    CALL Scroll_SetPosition(100, 50)
    CALL Scroll_ScreenShake(0, 1)
    CALL Assert_IsNotZero(shakeActive, "shake started")
    CALL Scroll_UpdateScreenShake                 ' frame 1: offset 0 -> stays
    CALL Assert_IsEqual(SX(), 100, "zero-intensity shake leaves X put")
    CALL Scroll_UpdateScreenShake                 ' frames exhausted -> restore + stop
    CALL Assert_IsEqual(SX(), 100, "position restored")
    CALL Assert_IsZero(shakeActive, "shake finished")
END SUB

' === entry point ===
SVGAScreenContext.XRes = 320
SVGAScreenContext.YRes = 200
CALL Test_BeginSuite("SCROLL")
Test_SetVirtualScreen
Test_SetPosition_Clamp
Test_Screen_Relative
Test_Direction
Test_Wrap_Mode
Test_SmoothTo
Test_SmoothTo_Inactive
Test_Parallax_CreateFree
Test_ScreenShake_ZeroIntensity
CALL Test_EndSuite("SCROLL")
END
