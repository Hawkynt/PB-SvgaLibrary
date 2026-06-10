' =============================================================================
' VIRTUAL.TST - tests for VIRTUAL.SUB (virtual coordinate system / viewports)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VIRTUAL.SUB"

' Arrange a known physical screen so the scale math is deterministic.
SUB SetPhys
    SVGAScreenContext.XRes = 320
    SVGAScreenContext.YRes = 200
END SUB

SUB Test_Reset_GivesIdentity
    CALL Test_Case("Reset -> 1:1 mapping, no offset, no viewport")
    CALL SetPhys
    CALL Virtual_Reset
    CALL Assert_IsEqual(Virtual_GetScale(0, 0), 1, "XScale = 1")
    CALL Assert_IsEqual(Virtual_GetScale(1, 0), 1, "YScale = 1")
    CALL Assert_IsEqual(Virtual_GetScale(2, 0), 320, "XScaleMax = XRes")
    CALL Assert_IsEqual(Virtual_GetScale(3, 0), 200, "YScaleMax = YRes")
    CALL Assert_IsEqual(Virtual_IsVisible(999, 999), 1, "no viewport -> everything visible")
END SUB

SUB Test_SetScale_UpdatesMax
    CALL Test_Case("SetScale recomputes max coordinates")
    CALL SetPhys
    CALL Virtual_SetScale(2, 4)
    CALL Assert_IsEqual(Virtual_GetScale(0, 0), 2, "XScale stored")
    CALL Assert_IsEqual(Virtual_GetScale(1, 0), 4, "YScale stored")
    CALL Assert_IsEqual(Virtual_GetScale(2, 0), 160, "XScaleMax = 320\2")
    CALL Assert_IsEqual(Virtual_GetScale(3, 0), 50, "YScaleMax = 200\4")
END SUB

SUB Test_GetScale_BadTypeDefaultsToOne
    CALL Test_Case("GetScale with unknown type returns 1")
    CALL SetPhys
    CALL Virtual_SetScale(2, 2)
    CALL Assert_IsEqual(Virtual_GetScale(7, 0), 1, "unknown scaleType -> 1")
END SUB

SUB Test_ToPhysical_Identity
    CALL Test_Case("ToPhysical is identity at scale 1, offset 0")
    DIM px AS WORD, py AS WORD
    CALL SetPhys : CALL Virtual_Reset
    CALL Virtual_ToPhysical(50, 60, px, py)
    CALL Assert_IsEqual(px, 50, "physicalX = virtualX")
    CALL Assert_IsEqual(py, 60, "physicalY = virtualY")
END SUB

SUB Test_ToPhysical_Scaled
    CALL Test_Case("ToPhysical multiplies by scale")
    DIM px AS WORD, py AS WORD
    CALL SetPhys : CALL Virtual_Reset
    CALL Virtual_SetScale(2, 3)
    CALL Virtual_ToPhysical(10, 10, px, py)
    CALL Assert_IsEqual(px, 20, "physicalX = 10*2")
    CALL Assert_IsEqual(py, 30, "physicalY = 10*3")
END SUB

SUB Test_RoundTrip_PhysicalVirtual
    CALL Test_Case("ToVirtual reverses ToPhysical")
    DIM px AS WORD, py AS WORD, vx AS WORD, vy AS WORD
    CALL SetPhys : CALL Virtual_Reset
    CALL Virtual_SetScale(2, 2)
    CALL Virtual_ToPhysical(40, 25, px, py)
    CALL Virtual_ToVirtual(px, py, vx, vy)
    CALL Assert_IsEqual(vx, 40, "virtualX round-trips")
    CALL Assert_IsEqual(vy, 25, "virtualY round-trips")
END SUB

SUB Test_Offset_RoundTrip
    CALL Test_Case("SetOffset / GetOffset (signed) round-trip")
    DIM ox AS INTEGER, oy AS INTEGER
    CALL SetPhys : CALL Virtual_Reset
    CALL Virtual_SetOffset(-12, 7)
    CALL Virtual_GetOffset(ox, oy)
    CALL Assert_IsEqual(ox, -12, "negative X offset")
    CALL Assert_IsEqual(oy, 7, "positive Y offset")
END SUB

SUB Test_Viewport_Clipping
    CALL Test_Case("Viewport clips, boundaries inclusive, disable reopens")
    CALL SetPhys : CALL Virtual_Reset
    CALL Virtual_SetViewport(10, 20, 100, 120)
    CALL Assert_IsEqual(Virtual_IsVisible(50, 60), 1, "inside viewport")
    CALL Assert_IsEqual(Virtual_IsVisible(10, 20), 1, "top-left edge inclusive")
    CALL Assert_IsEqual(Virtual_IsVisible(100, 120), 1, "bottom-right edge inclusive")
    CALL Assert_IsEqual(Virtual_IsVisible(9, 60), 0, "just left of viewport")
    CALL Assert_IsEqual(Virtual_IsVisible(50, 121), 0, "just below viewport")
    CALL Virtual_DisableViewport
    CALL Assert_IsEqual(Virtual_IsVisible(9, 60), 1, "disabled viewport -> visible again")
END SUB

SUB Test_GetViewport_GetDimensions
    CALL Test_Case("GetViewport / GetDimensions report state")
    DIM x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD, vw AS WORD, vh AS WORD
    CALL SetPhys : CALL Virtual_Reset
    CALL Virtual_SetViewport(5, 6, 7, 8)
    CALL Virtual_GetViewport(x1, y1, x2, y2)
    CALL Assert_IsEqual(x1, 5, "viewport X1") : CALL Assert_IsEqual(y1, 6, "viewport Y1")
    CALL Assert_IsEqual(x2, 7, "viewport X2") : CALL Assert_IsEqual(y2, 8, "viewport Y2")
    CALL Virtual_SetScale(2, 2)
    CALL Virtual_GetDimensions(vw, vh)
    CALL Assert_IsEqual(vw, 160, "virtual width = XScaleMax")
    CALL Assert_IsEqual(vh, 100, "virtual height = YScaleMax")
END SUB

' === entry point (no video mode needed - pure coordinate logic) ===
CALL Test_BeginSuite("VIRTUAL")
CALL Test_Reset_GivesIdentity
CALL Test_SetScale_UpdatesMax
CALL Test_GetScale_BadTypeDefaultsToOne
CALL Test_ToPhysical_Identity
CALL Test_ToPhysical_Scaled
CALL Test_RoundTrip_PhysicalVirtual
CALL Test_Offset_RoundTrip
CALL Test_Viewport_Clipping
CALL Test_GetViewport_GetDimensions
CALL Test_EndSuite("VIRTUAL")
END
