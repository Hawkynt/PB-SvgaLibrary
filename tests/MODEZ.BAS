' =============================================================================
' MODEZ.TST - tests for MODEZ.SUB (Mode-Z: 320x400 unchained planar)
' =============================================================================
' Mode-Z shares Mode-X's unchained planar layout, so it reuses the optimized
' ModeX_* primitives; only the mode set-up (resolution / pages) differs.
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "MODEX.SUB"
$INCLUDE "MODEZ.SUB"

SUB Svga_InitDispatchTable
END SUB
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB

SUB PutP(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM xv AS WORD, yv AS WORD, cv AS BYTE
    xv = x : yv = y : cv = c
    CALL ModeX_PutPixel(xv, yv, cv)
END SUB
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL ModeX_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

SUB Test_SetMode_ConfiguresContext
    CALL Test_Case("SetMode programs 320x400 unchained-planar context")
    CALL Assert_IsEqual(SVGAScreenContext.XRes, 320, "XRes = 320")
    CALL Assert_IsEqual(SVGAScreenContext.YRes, 400, "YRes = 400")
    CALL Assert_IsEqual(ModeXSystemContext.LogicalWidth, 80, "logical width = 80 bytes/line")
    CALL Assert_IsEqual(ModeXSystemContext.PlanarMode, 1, "planar mode flagged")
    CALL Assert_IsEqual(VESASystemContext.CurrentMode, %SVGA_MODEZ, "current mode tag")
END SUB

SUB Test_PutGet_Planes
    CALL Test_Case("PutPixel/GetPixel round-trips across planes")
    DIM i AS INTEGER, bad AS INTEGER
    FOR i = 0 TO 7 : CALL PutP(i, 10, 40 + i) : NEXT i
    bad = 0
    FOR i = 0 TO 7 : IF GetP(i, 10) <> 40 + i THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "8 adjacent pixels round-trip")
END SUB

SUB Test_PutGet_TallBoundary
    CALL Test_Case("PutPixel/GetPixel at the bottom scanline (y=399)")
    CALL PutP(0, 0, 5)
    CALL Assert_IsEqual(GetP(0, 0), 5, "top-left")
    CALL PutP(319, 399, 200)
    CALL Assert_IsEqual(GetP(319, 399), 200, "bottom-right of 320x400")
END SUB

SUB Test_Setup
CALL ModeX_InitTables
CALL ModeZ_SetMode
END SUB

SUB Test_Teardown
!MOV AX, &H0003
!INT &H10
END SUB
