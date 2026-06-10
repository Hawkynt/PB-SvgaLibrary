' =============================================================================
' FLOOD.BAS - tests for FLOOD.SUB (scanline flood fill)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
DECLARE FUNCTION Svga_GetPixel(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
$INCLUDE "FLOOD.SUB"

' --- required stubs (not exercised by this suite) ---
SUB Svga_InitDispatchTable
END SUB
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB

' --- stubs: route Svga_* through real Vga_* in mode 13h ---
SUB Svga_PutPixel(x AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_PutPixel(x, y, c)
END SUB

' test double matches the REAL library shape: FUNCTION(x, y) AS BYTE
FUNCTION Svga_GetPixel(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    Svga_GetPixel = r
END FUNCTION

SUB Svga_HLine(x1 AS WORD, x2 AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_HLine(x1, x2, y, c)
END SUB

' --- helpers ---
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

' Hardware mode reset clears all video memory to 0
SUB HwCls
    !MOV AX, &H0013
    !INT &H10
END SUB

' Draw a hollow rectangle outline (border only, no interior fill)
SUB DrawRect(BYVAL x1 AS WORD, BYVAL y1 AS WORD, BYVAL x2 AS WORD, BYVAL y2 AS WORD, BYVAL c AS BYTE)
    DIM cx AS WORD, cy AS WORD
    FOR cx = x1 TO x2
        CALL Vga_PutPixel(cx, y1, c)
        CALL Vga_PutPixel(cx, y2, c)
    NEXT cx
    FOR cy = y1 TO y2
        CALL Vga_PutPixel(x1, cy, c)
        CALL Vga_PutPixel(x2, cy, c)
    NEXT cy
END SUB

' =============================================================================
' Test_Setup / Test_Teardown
' =============================================================================
SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
    SVGAScreenContext.XRes = 320
    SVGAScreenContext.YRes = 200
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB

' =============================================================================
' HappyPath: fill the interior of a drawn rectangle outline.
' Verifies: interior filled, border intact, outside pixel untouched.
' =============================================================================
SUB Test_FillInsideRect
    CALL Test_Case("Fill inside rectangle: interior filled, border intact, outside untouched")
    CALL HwCls
    ' Hollow 10x6 rectangle; border colour 4
    CALL DrawRect(30, 40, 39, 45, 4)
    CALL Graphics_FloodFill(34, 42, 7)
    CALL Assert_IsEqual(GetP(34, 42), 7, "interior centre filled")
    CALL Assert_IsEqual(GetP(31, 41), 7, "interior top-left area filled")
    CALL Assert_IsEqual(GetP(38, 44), 7, "interior bottom-right area filled")
    CALL Assert_IsEqual(GetP(30, 40), 4, "top-left corner border intact")
    CALL Assert_IsEqual(GetP(39, 45), 4, "bottom-right corner border intact")
    CALL Assert_IsEqual(GetP(34, 40), 4, "top edge border intact")
    CALL Assert_IsEqual(GetP(34, 45), 4, "bottom edge border intact")
    CALL Assert_IsEqual(GetP(30, 42), 4, "left edge border intact")
    CALL Assert_IsEqual(GetP(39, 42), 4, "right edge border intact")
    CALL Assert_IsEqual(GetP(20, 42), 0, "outside left untouched")
    CALL Assert_IsEqual(GetP(50, 42), 0, "outside right untouched")
    CALL Assert_IsZero(FloodDropCount, "no stack overflow for small fill")
END SUB

' =============================================================================
' HappyPath: closed U-shaped cavity (capped on all four sides) fills completely.
' The interior wraps around the bottom of the U and fills on both sides.
' =============================================================================
SUB Test_FillUShaped
    CALL Test_Case("U-shaped cavity fills completely around the bend")
    CALL HwCls
    DIM cx AS WORD, cy AS WORD

    ' Build a fully-closed box with an internal divider that creates a U-shape
    ' inside. Outer box: (100,100)-(120,115), colour 5.
    ' Internal divider: horizontal bar across the middle at row 107,
    ' from col 100 to col 112 (leaving a gap 112..120 for the U to connect).
    ' This produces a U whose left arm is cols 101-111, rows 101-106,
    ' and right arm is cols 101-119, rows 108-114; they connect via cols 113-119.
    '
    ' Simpler: closed rectangle (100,80)-(130,100), colour 2, with a vertical
    ' internal wall at col 115 running from row 80 down to row 94 (leaving
    ' the bottom two rows open). Seed in left chamber at (107, 85).
    ' The fill must travel under the wall and fill the right chamber too.

    ' outer border
    FOR cx = 100 TO 130
        CALL Vga_PutPixel(cx, 80, 2)
        CALL Vga_PutPixel(cx, 100, 2)
    NEXT cx
    FOR cy = 80 TO 100
        CALL Vga_PutPixel(100, cy, 2)
        CALL Vga_PutPixel(130, cy, 2)
    NEXT cy
    ' internal vertical wall col 115, rows 80..94 (open gap rows 95..99)
    FOR cy = 80 TO 94
        CALL Vga_PutPixel(115, cy, 2)
    NEXT cy

    ' seed in left chamber
    CALL Graphics_FloodFill(107, 85, 8)

    ' left chamber filled
    CALL Assert_IsEqual(GetP(107, 85), 8, "left chamber filled")
    CALL Assert_IsEqual(GetP(107, 97), 8, "bottom left area filled")
    ' fill must travel under the wall and reach right chamber
    CALL Assert_IsEqual(GetP(120, 85), 8, "right chamber filled via gap")
    CALL Assert_IsEqual(GetP(120, 97), 8, "right chamber bottom filled")
    ' border intact
    CALL Assert_IsEqual(GetP(100, 80), 2, "outer border top-left intact")
    CALL Assert_IsEqual(GetP(115, 85), 2, "internal wall intact")
    CALL Assert_IsZero(FloodDropCount, "no stack overflow for U shape")
END SUB

' =============================================================================
' Boundary: seed ON a border pixel does not flood the interior.
' targetColor = border colour; interior is background (0) — a different colour.
' =============================================================================
SUB Test_SeedOnBorder
    CALL Test_Case("Seed on border pixel does not flood the interior")
    CALL HwCls
    CALL DrawRect(80, 60, 95, 72, 4)
    ' seed exactly on the left border
    CALL Graphics_FloodFill(80, 66, 9)
    ' interior (colour 0) must remain untouched
    CALL Assert_IsEqual(GetP(87, 66), 0, "interior still background after border seed")
    CALL Assert_IsEqual(GetP(87, 65), 0, "interior row above seed still background")
END SUB

' =============================================================================
' Exception: fill with the same colour as the seed pixel — safe no-op.
' =============================================================================
SUB Test_SameColourNoOp
    CALL Test_Case("Flood fill with fill colour equal to seed colour is a no-op")
    CALL HwCls
    DIM wx AS WORD, wy AS WORD, wc AS BYTE
    wx = 50 : wy = 50 : wc = 6
    CALL Vga_PutPixel(wx, wy, wc)
    CALL Graphics_FloodFill(50, 50, 6)
    CALL Assert_IsEqual(GetP(50, 50), 6, "pixel unchanged after same-colour fill")
    CALL Assert_IsEqual(GetP(51, 50), 0, "neighbour untouched (still background)")
END SUB

' =============================================================================
' Boundary: fill region touching x=0 and y=0 (top-left screen corner).
' Must not wrap when scan hits the left/top screen edge.
' =============================================================================
SUB Test_FillAtScreenEdge
    CALL Test_Case("Fill region touching x=0 and y=0 does not wrap or crash")
    CALL HwCls
    CALL DrawRect(0, 0, 6, 5, 3)
    CALL Graphics_FloodFill(2, 2, 11)
    CALL Assert_IsEqual(GetP(2, 2), 11, "interior at edge filled")
    CALL Assert_IsEqual(GetP(1, 1), 11, "interior near corner filled")
    CALL Assert_IsEqual(GetP(0, 0), 3, "pixel (0,0) border intact")
    CALL Assert_IsEqual(GetP(6, 5), 3, "far corner border intact")
    CALL Assert_IsZero(FloodDropCount, "no stack overflow at screen edge")
END SUB

' =============================================================================
' Boundary: fill region touching the right and bottom screen edges (319,199).
' =============================================================================
SUB Test_FillAtRightBottomEdge
    CALL Test_Case("Fill region touching right/bottom screen edge does not crash")
    CALL HwCls
    CALL DrawRect(314, 195, 319, 199, 3)
    CALL Graphics_FloodFill(316, 197, 12)
    CALL Assert_IsEqual(GetP(316, 197), 12, "interior near right-bottom edge filled")
    CALL Assert_IsEqual(GetP(314, 195), 3, "top-left corner of box intact")
    CALL Assert_IsEqual(GetP(319, 199), 3, "bottom-right corner of box intact")
    CALL Assert_IsZero(FloodDropCount, "no stack overflow at right/bottom edge")
END SUB

' =============================================================================
' Exception: seed outside the screen bounds — silent no-op (no crash).
' x=320 is one beyond the valid range 0..319 for a 320-wide screen.
' =============================================================================
SUB Test_SeedOutOfBounds
    CALL Test_Case("Seed outside screen bounds is a silent no-op")
    CALL HwCls
    DIM ox AS WORD, oy AS WORD
    ox = 320 : oy = 10
    CALL Graphics_FloodFill(ox, oy, 5)
    ' Nothing on this clean screen should have been touched
    CALL Assert_IsEqual(GetP(0, 0), 0, "screen untouched after out-of-bounds seed")
    CALL Assert_IsEqual(GetP(100, 50), 0, "mid-screen untouched")
END SUB
