' =============================================================================
' SVGA.BAS - xUnit tests for SVGA.SUB (top-level dispatch engine)
' =============================================================================
' Tests: Svga_Init context defaults, Svga_SetDispatchDefaults (all slots non-zero),
' Svga_InitDispatchTable (MODE13 wires real Vga_* handlers), and the thin
' Svga_PutPixel/Svga_GetPixel/Svga_HLine/Svga_FillRect/Svga_DrawRect/
' Svga_ClearScreen wrappers round-tripping through the dispatch table.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"

' --- stubs required by VGA.SUB (Vga_ClearScreen calls this) ---
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

' --- stubs for Svga_Init collaborators ---
SUB Timer_Init
END SUB
SUB Cursor_Init
END SUB
SUB Sprite_Init
END SUB
SUB Scroll_Init
END SUB
SUB ModeX_InitTables
END SUB

' --- stubs for Svga_Cleanup collaborators ---
SUB DrawAni_StopAnimation(BYVAL animHandle AS BYTE)
END SUB
SUB DrawAni_FreeAnimation(BYVAL animHandle AS BYTE)
END SUB
SUB DrawIcl_CloseIcoLib(BYVAL libHandle AS BYTE)
END SUB
SUB Sprite_Cleanup
END SUB
SUB Scroll_Cleanup
END SUB
SUB Cursor_Cleanup
END SUB
SUB Timer_Cleanup
END SUB
SUB Memory_CloseEms(BYVAL handle AS WORD)
END SUB
SUB Vga_CloseVga
END SUB

' --- stubs for Virtual coordinate system (pass-through for testing) ---
SUB Virtual_ToPhysical(BYVAL vx AS WORD, BYVAL vy AS WORD, px AS WORD, py AS WORD)
    px = vx : py = vy
END SUB
FUNCTION Virtual_IsVisible(BYVAL vx AS WORD, BYVAL vy AS WORD) AS BYTE
    Virtual_IsVisible = 1
END FUNCTION
SUB Virtual_SetScale(BYVAL xs AS WORD, BYVAL ys AS WORD)
    ScaleSystemContext.XScale = xs
    ScaleSystemContext.YScale = ys
END SUB
FUNCTION Virtual_GetScale(BYVAL st AS BYTE, BYVAL unused AS BYTE) AS WORD
    SELECT CASE st
        CASE 0 : Virtual_GetScale = ScaleSystemContext.XScale
        CASE 1 : Virtual_GetScale = ScaleSystemContext.YScale
        CASE ELSE : Virtual_GetScale = 1
    END SELECT
END FUNCTION
SUB Virtual_SetWindow(BYVAL maxX AS WORD, BYVAL maxY AS WORD)
END SUB
SUB Virtual_SetViewport(BYVAL x1 AS WORD, BYVAL y1 AS WORD, BYVAL x2 AS WORD, BYVAL y2 AS WORD)
END SUB

' --- stubs for all other CODEPTR32 targets (ModeX / VESA / Mode16 / ModeText) ---
' ModeX (arity matches dispatch: PutPixel=3, GetPixel=3, HLine=4, VLine=4,
'        LineDraw=5, FillRect=5, DrawRect=5, DrawCircle=4, FillCircle=4,
'        ClearScreen=1, CopyBlock=6)
SUB ModeX_PutPixel(a AS WORD, b AS WORD, c AS BYTE)
END SUB
SUB ModeX_GetPixel(a AS WORD, b AS WORD, c AS BYTE)
END SUB
SUB ModeX_HLine(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB ModeX_VLine(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB ModeX_LineDraw(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB ModeX_FillRect(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB ModeX_DrawRect(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB ModeX_DrawCircle(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB ModeX_FillCircle(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB ModeX_ClearScreen(a AS BYTE)
END SUB
SUB ModeX_CopyBlock(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS WORD, f AS WORD)
END SUB

' VESA (same arity pattern)
SUB Vesa_PutPixel(a AS WORD, b AS WORD, c AS BYTE)
END SUB
SUB Vesa_GetPixel(a AS WORD, b AS WORD, c AS BYTE)
END SUB
SUB Vesa_HLine(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB Vesa_VLine(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB Vesa_LineDraw(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB Vesa_FillRect(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB Vesa_DrawRect(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB Vesa_ClearScreen(a AS BYTE)
END SUB
SUB Vesa_CopyBlock(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS WORD, f AS WORD)
END SUB
SUB Svga_WireVesaOptimized
END SUB

' Mode16
SUB Mode16_PutPixel(a AS WORD, b AS WORD, c AS BYTE)
END SUB
SUB Mode16_GetPixel(a AS WORD, b AS WORD, c AS BYTE)
END SUB
SUB Mode16_HLine(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB Mode16_VLine(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB Mode16_LineDraw(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB Mode16_FillRect(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB Mode16_DrawRect(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB Mode16_ClearScreen(a AS BYTE)
END SUB

' ModeText
SUB ModeText_PutPixel(a AS WORD, b AS WORD, c AS BYTE)
END SUB
SUB ModeText_GetPixel(a AS WORD, b AS WORD, c AS BYTE)
END SUB
SUB ModeText_HLine(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB ModeText_VLine(a AS WORD, b AS WORD, c AS WORD, d AS BYTE)
END SUB
SUB ModeText_LineDraw(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB ModeText_FillRect(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB ModeText_DrawRect(a AS WORD, b AS WORD, c AS WORD, d AS WORD, e AS BYTE)
END SUB
SUB ModeText_ClearScreen(a AS BYTE)
END SUB

$INCLUDE "SVGAENG.SUB"

' --- typed helpers (wrappers take BYVAL so we can pass literals directly) ---
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

' =============================================================================
' Test cases
' =============================================================================

' --- Test 1: Svga_Init sets sane context defaults ---
SUB Test_Version
    CALL Test_Case("Svga_Version$ reports the version constants")
    DIM v AS STRING
    v = Svga_Version$
    CALL Assert_AreEqualStr(v, LTRIM$(STR$(%SVGA_VERSION_MAJOR)) + "." + LTRIM$(STR$(%SVGA_VERSION_MINOR)) + "." + LTRIM$(STR$(%SVGA_VERSION_PATCH)), "matches the constants")
    CALL Assert_IsTrue(INSTR(v, ".") > 1, "has a dotted form")
END SUB

SUB Test_Init_Defaults
    CALL Test_Case("Svga_Init sets default context values")
    ' Given: Svga_Init has been called in Test_Setup
    ' When:  we inspect context fields set by Svga_Init
    ' Then:  screen context resets to zero; scale to 1; font dims to 8
    CALL Assert_IsEqual(SVGAScreenContext.XRes, 0, "XRes zeroed")
    CALL Assert_IsEqual(SVGAScreenContext.YRes, 0, "YRes zeroed")
    CALL Assert_IsEqual(SVGAScreenContext.ColorDepth, 0, "ColorDepth zeroed")
    CALL Assert_IsEqual(VESASystemContext.XRes, 0, "VESAContext.XRes zeroed")
    CALL Assert_IsEqual(VESASystemContext.YRes, 0, "VESAContext.YRes zeroed")
    CALL Assert_IsEqual(VESASystemContext.OneLoadOnly, 0, "OneLoadOnly zeroed")
    CALL Assert_IsEqual(VESASystemContext.TransparentColor, 0, "TransparentColor zeroed")
    CALL Assert_IsEqual(WindowSystemContext.Current, 0, "WindowCurrent zeroed")
    CALL Assert_IsEqual(ScaleSystemContext.XScale, 1, "XScale=1 after init")
    CALL Assert_IsEqual(ScaleSystemContext.YScale, 1, "YScale=1 after init")
    CALL Assert_IsEqual(ScaleSystemContext.KScale, 1, "KScale=1 after init")
    CALL Assert_IsEqual(FontSystemContext.CharWidth, 8, "CharWidth=8 default")
    CALL Assert_IsEqual(FontSystemContext.CharHeight, 8, "CharHeight=8 default")
END SUB

' --- Test 2: Svga_SetDispatchDefaults fills every slot ---
SUB Test_SetDispatchDefaults_AllSlotsNonZero
    CALL Test_Case("Svga_SetDispatchDefaults: all 11 slots non-zero")
    ' Given: dispatch table freshly seeded with defaults
    CALL Svga_SetDispatchDefaults
    ' When/Then: every slot must be non-zero (points at a dummy proc)
    CALL Assert_IsNotZero(SVGADispatch.PutPixel,   "PutPixel slot set")
    CALL Assert_IsNotZero(SVGADispatch.GetPixel,   "GetPixel slot set")
    CALL Assert_IsNotZero(SVGADispatch.HLine,      "HLine slot set")
    CALL Assert_IsNotZero(SVGADispatch.VLine,      "VLine slot set")
    CALL Assert_IsNotZero(SVGADispatch.LineDraw,   "LineDraw slot set")
    CALL Assert_IsNotZero(SVGADispatch.FillRect,   "FillRect slot set")
    CALL Assert_IsNotZero(SVGADispatch.DrawRect,   "DrawRect slot set")
    CALL Assert_IsNotZero(SVGADispatch.DrawCircle, "DrawCircle slot set")
    CALL Assert_IsNotZero(SVGADispatch.FillCircle, "FillCircle slot set")
    CALL Assert_IsNotZero(SVGADispatch.ClearScreen,"ClearScreen slot set")
    CALL Assert_IsNotZero(SVGADispatch.CopyBlock,  "CopyBlock slot set")
END SUB

' --- Test 3: Svga_InitDispatchTable in MODE13 wires real Vga_* handlers ---
SUB Test_InitDispatchTable_Mode13_PointsAtVga
    CALL Test_Case("InitDispatchTable(MODE13) wires Vga_* pointers")
    ' Given: mode 13h active, dispatch table reset to dummies
    CALL Svga_SetDispatchDefaults
    DIM ppBefore AS DWORD
    ppBefore = SVGADispatch.PutPixel          ' dummy value

    ' When: set MODE13 and re-initialise dispatch table
    VESASystemContext.CurrentMode = %SVGA_MODE13
    CALL Svga_InitDispatchTable

    ' Then: PutPixel/GetPixel slots must have changed from the dummy
    CALL Assert_AreNotEqual(SVGADispatch.PutPixel,  ppBefore, "PutPixel -> Vga_PutPixel")
    CALL Assert_AreNotEqual(SVGADispatch.GetPixel,  ppBefore, "GetPixel -> Vga_GetPixel")
    ' All slots must still be non-zero
    CALL Assert_IsNotZero(SVGADispatch.PutPixel,   "PutPixel non-zero")
    CALL Assert_IsNotZero(SVGADispatch.GetPixel,   "GetPixel non-zero")
    CALL Assert_IsNotZero(SVGADispatch.HLine,      "HLine non-zero")
    CALL Assert_IsNotZero(SVGADispatch.VLine,      "VLine non-zero")
    CALL Assert_IsNotZero(SVGADispatch.FillRect,   "FillRect non-zero")
    CALL Assert_IsNotZero(SVGADispatch.DrawRect,   "DrawRect non-zero")
    CALL Assert_IsNotZero(SVGADispatch.ClearScreen,"ClearScreen non-zero")
    CALL Assert_IsNotZero(SVGADispatch.CopyBlock,  "CopyBlock non-zero")
END SUB

' --- Test 4: Svga_PutPixel / Svga_GetPixel round-trip via dispatch ---
SUB Test_PutGet_Dispatch_RoundTrip
    CALL Test_Case("Svga_PutPixel/Svga_GetPixel round-trip in MODE13")
    ' Arrange: clear VRAM
    DIM cv AS BYTE
    cv = 0
    CALL Vga_ClearScreen(cv)

    ' Act: write via Svga wrapper, read back via raw Vga_GetPixel
    CALL Svga_PutPixel(160, 100, 42)
    CALL Assert_IsEqual(GetP(160, 100), 42, "centre pixel dispatched correctly")

    ' Also verify Svga_GetPixel wrapper returns the same value
    DIM got AS BYTE
    got = Svga_GetPixel(160, 100)
    CALL Assert_IsEqual(got, 42, "Svga_GetPixel wrapper returns written value")
END SUB

' --- Test 5: PutPixel/GetPixel at corners ---
SUB Test_PutGet_Boundary
    CALL Test_Case("Svga_PutPixel/GetPixel at MODE13 boundaries")
    CALL Svga_PutPixel(0, 0, 7)
    CALL Assert_IsEqual(GetP(0, 0), 7, "top-left (0,0)")
    CALL Svga_PutPixel(319, 199, 13)
    CALL Assert_IsEqual(GetP(319, 199), 13, "bottom-right (319,199)")
END SUB

' --- Test 6: Svga_PutPixel preserves all 256 colour indices ---
SUB Test_PutPixel_AllColors
    CALL Test_Case("Svga_PutPixel dispatches all 256 colour values")
    DIM i AS INTEGER
    FOR i = 0 TO 255
        CALL Svga_PutPixel(i, 10, i)
    NEXT i
    DIM bad AS INTEGER
    bad = 0
    FOR i = 0 TO 255
        IF GetP(i, 10) <> i THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "all 256 colour values round-trip via dispatch")
END SUB

' --- Test 7: Svga_HLine draws via dispatch ---
SUB Test_HLine_Dispatch
    CALL Test_Case("Svga_HLine dispatches to Vga_HLine")
    DIM cv AS BYTE
    cv = 0 : CALL Vga_ClearScreen(cv)
    CALL Svga_HLine(20, 30, 50, 9)
    CALL Assert_IsEqual(GetP(20, 50), 9, "HLine left end")
    CALL Assert_IsEqual(GetP(25, 50), 9, "HLine middle")
    CALL Assert_IsEqual(GetP(30, 50), 9, "HLine right end")
    CALL Assert_IsEqual(GetP(19, 50), 0, "HLine: no bleed left")
    CALL Assert_IsEqual(GetP(31, 50), 0, "HLine: no bleed right")
END SUB

' --- Test 8: Svga_ClearScreen dispatches via table ---
SUB Test_ClearScreen_Dispatch
    CALL Test_Case("Svga_ClearScreen dispatches to Vga_ClearScreen")
    ' Write some pixels first
    CALL Svga_PutPixel(0,   0,   5)
    CALL Svga_PutPixel(160, 100, 5)
    CALL Svga_PutPixel(319, 199, 5)
    ' Clear to colour 11
    CALL Svga_ClearScreen(11)
    CALL Assert_IsEqual(GetP(0,   0),   11, "top-left cleared to 11")
    CALL Assert_IsEqual(GetP(160, 100), 11, "centre cleared to 11")
    CALL Assert_IsEqual(GetP(319, 199), 11, "bottom-right cleared to 11")
END SUB

' --- Test 9: Svga_FillRect dispatches via table ---
SUB Test_FillRect_Dispatch
    CALL Test_Case("Svga_FillRect dispatches to Vga_FillRect")
    DIM cv AS BYTE
    cv = 0 : CALL Vga_ClearScreen(cv)
    CALL Svga_FillRect(50, 60, 55, 65, 17)
    CALL Assert_IsEqual(GetP(50, 60), 17, "top-left of rect")
    CALL Assert_IsEqual(GetP(55, 65), 17, "bottom-right of rect")
    CALL Assert_IsEqual(GetP(52, 62), 17, "interior")
    CALL Assert_IsEqual(GetP(49, 60), 0,  "no bleed left of rect")
END SUB

' --- Test 10: Svga_DrawRect dispatches via table ---
SUB Test_DrawRect_Dispatch
    CALL Test_Case("Svga_DrawRect dispatches to Vga_DrawRect")
    DIM cv AS BYTE
    cv = 0 : CALL Vga_ClearScreen(cv)
    CALL Svga_DrawRect(70, 80, 80, 88, 3)
    CALL Assert_IsEqual(GetP(75, 80), 3, "top edge")
    CALL Assert_IsEqual(GetP(75, 88), 3, "bottom edge")
    CALL Assert_IsEqual(GetP(70, 84), 3, "left edge")
    CALL Assert_IsEqual(GetP(80, 84), 3, "right edge")
    CALL Assert_IsEqual(GetP(75, 84), 0, "hollow centre")
END SUB

' --- Test 11: DispUnset dummy sets gSvgaNoMode flag ---
SUB Test_DispUnset_SetsNoModeFlag
    CALL Test_Case("Svga_DispUnset3 dummy sets gSvgaNoMode flag")
    ' Given: a clean flag and defaults installed
    gSvgaNoMode = 0
    CALL Svga_SetDispatchDefaults
    ' When: trigger an unset slot via a MODEX init (no pixel op needed;
    '       just call the unset dummy directly through the table)
    ' We call Svga_SetDispatchDefaults and then switch to an unused mode
    ' so the ClearScreen slot holds Svga_DispUnset1; call it via wrapper
    VESASystemContext.CurrentMode = 99       ' force CASE ELSE -> mode13 branch
    CALL Svga_InitDispatchTable              ' fills with Vga_* (real mode)
    ' For the unset-dummy path: re-seed defaults (all -> dummies) and trigger ClearScreen
    CALL Svga_SetDispatchDefaults
    CALL Svga_ClearScreen(0)                 ' calls DispUnset1 -> sets gSvgaNoMode
    CALL Assert_IsNotZero(gSvgaNoMode, "DispUnset dummy marks gSvgaNoMode")
END SUB

' =============================================================================
' Setup / Teardown
' =============================================================================
SUB Test_Setup
    ' Enter mode 13h
    !MOV AX, &H0013
    !INT &H10
    ' Initialise SVGA engine for MODE13
    CALL Svga_Init
    VESASystemContext.CurrentMode = %SVGA_MODE13
    CALL Svga_InitDispatchTable
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB
