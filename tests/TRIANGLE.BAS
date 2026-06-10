' =============================================================================
' TRIANGLE.BAS - tests for TRIANGLE.SUB
' =============================================================================
' Mode 13h is set up by Test_Setup; Svga_* calls route to the real Vga_*
' implementations in VGA.SUB so pixels can be verified via Vga_GetPixel.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"

' Forward declarations for Svga_* wrappers used by TRIANGLE.SUB
DECLARE SUB Svga_LineDraw(BYVAL x1 AS WORD, BYVAL y1 AS WORD, BYVAL x2 AS WORD, BYVAL y2 AS WORD, BYVAL c AS BYTE)
DECLARE SUB Svga_HLine(BYVAL x1 AS WORD, BYVAL x2 AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
DECLARE SUB Svga_PutPixel(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)

$INCLUDE "TRIANGLE.SUB"

' --- stubs / routing wrappers -------------------------------------------------
SUB Memory_ClearVideoMemory(c AS BYTE)
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
SUB Svga_InitDispatchTable
END SUB
SUB Svga_LineDraw(BYVAL x1 AS WORD, BYVAL y1 AS WORD, BYVAL x2 AS WORD, BYVAL y2 AS WORD, BYVAL c AS BYTE)
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE
    a = x1 : b = y1 : cc = x2 : d = y2 : e = c
    CALL Vga_LineDraw(a, b, cc, d, e)
END SUB
SUB Svga_HLine(BYVAL x1 AS WORD, BYVAL x2 AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM a AS WORD, b AS WORD, yy AS WORD, e AS BYTE
    a = x1 : b = x2 : yy = y : e = c
    CALL Vga_HLine(a, b, yy, e)
END SUB
SUB Svga_PutPixel(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM a AS WORD, b AS WORD, e AS BYTE
    a = x : b = y : e = c
    CALL Vga_PutPixel(a, b, e)
END SUB

' --- test helpers -------------------------------------------------------------
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION
SUB ClrScr
    DIM e AS BYTE
    e = 0
    CALL Vga_ClearScreen(e)
END SUB

' =============================================================================
' Tests: Graphics_DrawTriangle (outline)
' =============================================================================

SUB Test_DrawTriangle_EdgesPresent
    CALL Test_Case("DrawTriangle draws all three edges")
    CALL ClrScr
    ' Right triangle with vertices (10,10), (40,10), (10,40)
    CALL Graphics_DrawTriangle(10, 10, 40, 10, 10, 40, 5)
    ' Top edge y=10: pixels at x=10 and x=40 must be set
    CALL Assert_IsEqual(GetP(10, 10), 5, "top-left corner")
    CALL Assert_IsEqual(GetP(40, 10), 5, "top-right corner")
    ' Left vertical edge x=10, midpoint
    CALL Assert_IsEqual(GetP(10, 25), 5, "left vertical midpoint")
    ' Hypotenuse: a point near (25,25) should be set (45-degree diagonal)
    CALL Assert_IsEqual(GetP(25, 25), 5, "hypotenuse midpoint")
END SUB

SUB Test_DrawTriangle_HollowCentre
    CALL Test_Case("DrawTriangle interior remains empty")
    CALL ClrScr
    CALL Graphics_DrawTriangle(50, 50, 90, 50, 70, 80, 6)
    ' Interior sample must stay background (0)
    CALL Assert_IsEqual(GetP(70, 60), 0, "interior is hollow")
END SUB

' =============================================================================
' Tests: Graphics_FillTriangle
' =============================================================================

SUB Test_FillTriangle_RightTriangle_Rows
    CALL Test_Case("FillTriangle right triangle: exact span endpoints per row")
    CALL ClrScr
    ' Right triangle: (100,50), (130,50), (100,70)
    ' Sorted: (100,50),(130,50),(100,70) -> ay=50,by=50,cy=70
    ' This is a flat-top degenerate that flips to flat-bottom:
    ' vertices: A=(100,50) B=(130,50) C=(100,70)
    ' After sort by Y: ay=50 for both A and B, cy=70
    ' Use a simpler right triangle: (10,20), (10,40), (30,40) - flat top at y=40 no
    ' Let's use (10,20),(30,40),(10,40) so top=(10,20), bottom-left=(10,40), bottom-right=(30,40)
    CALL Graphics_FillTriangle(10, 20, 30, 40, 10, 40, 3)
    ' At y=20: only pixel x=10 should be set
    CALL Assert_IsEqual(GetP(10, 20), 3, "tip of triangle at (10,20)")
    ' At y=40 (base): span from x=10 to x=30
    CALL Assert_IsEqual(GetP(10, 40), 3, "base left (10,40)")
    CALL Assert_IsEqual(GetP(30, 40), 3, "base right (30,40)")
    CALL Assert_IsEqual(GetP(20, 40), 3, "base midpoint (20,40)")
    ' At y=30 (midpoint): left edge stays at x=10, right edge is at x=20
    CALL Assert_IsEqual(GetP(10, 30), 3, "left edge at y=30")
    CALL Assert_IsEqual(GetP(20, 30), 3, "right edge at y=30")
    ' Outside the triangle: pixel to the right of hypotenuse at y=30
    CALL Assert_IsEqual(GetP(25, 30), 0, "outside right of hypotenuse at y=30")
END SUB

SUB Test_FillTriangle_FlatBottom
    CALL Test_Case("FillTriangle flat-bottom triangle filled correctly")
    CALL ClrScr
    ' Flat-bottom: vertices (60,10),(80,10),(70,30)
    ' After sort by Y: ay=10, by=10, cy=30 -> both upper vertices share y=10
    CALL Graphics_FillTriangle(60, 10, 80, 10, 70, 30, 4)
    ' Top flat edge at y=10
    CALL Assert_IsEqual(GetP(60, 10), 4, "flat-top left at y=10")
    CALL Assert_IsEqual(GetP(80, 10), 4, "flat-top right at y=10")
    CALL Assert_IsEqual(GetP(70, 10), 4, "flat-top midpoint at y=10")
    ' Apex at y=30
    CALL Assert_IsEqual(GetP(70, 30), 4, "apex at (70,30)")
    ' Interior at y=20 (midpoint): span should contain x=65..75
    CALL Assert_IsEqual(GetP(65, 20), 4, "interior left at y=20")
    CALL Assert_IsEqual(GetP(75, 20), 4, "interior right at y=20")
    ' Outside
    CALL Assert_IsEqual(GetP(59, 10), 0, "outside left of flat top")
    CALL Assert_IsEqual(GetP(81, 10), 0, "outside right of flat top")
END SUB

SUB Test_FillTriangle_FlatTop
    CALL Test_Case("FillTriangle flat-top triangle filled correctly")
    CALL ClrScr
    ' Flat-top: apex at top, flat base at bottom
    ' Vertices (110,30),(130,30),(120,50)
    ' Sort: ay=30(110), by=30(130), cy=50(120)
    CALL Graphics_FillTriangle(110, 30, 130, 30, 120, 50, 7)
    ' Flat top edge at y=30
    CALL Assert_IsEqual(GetP(110, 30), 7, "flat top left")
    CALL Assert_IsEqual(GetP(130, 30), 7, "flat top right")
    CALL Assert_IsEqual(GetP(120, 30), 7, "flat top midpoint")
    ' Apex at y=50
    CALL Assert_IsEqual(GetP(120, 50), 7, "apex at bottom")
    ' Interior at y=40
    CALL Assert_IsEqual(GetP(115, 40), 7, "interior left at y=40")
    CALL Assert_IsEqual(GetP(125, 40), 7, "interior right at y=40")
END SUB

SUB Test_FillTriangle_General
    CALL Test_Case("FillTriangle general (non-flat) triangle filled throughout")
    CALL ClrScr
    ' General triangle: (150,10),(190,50),(160,70)
    CALL Graphics_FillTriangle(150, 10, 190, 50, 160, 70, 8)
    ' Top vertex
    CALL Assert_IsEqual(GetP(150, 10), 8, "top vertex")
    ' Bottom vertex
    CALL Assert_IsEqual(GetP(160, 70), 8, "bottom vertex")
    ' Middle scan should have interior pixels
    CALL Assert_IsEqual(GetP(165, 40), 8, "interior at y=40")
    ' Above and below should be empty
    CALL Assert_IsEqual(GetP(150, 9), 0, "above top vertex")
    CALL Assert_IsEqual(GetP(160, 71), 0, "below bottom vertex")
END SUB

SUB Test_FillTriangle_VertexOrder
    CALL Test_Case("FillTriangle vertex order permutations give same pixels")
    DIM i AS INTEGER, bad AS INTEGER

    ' Reference: vertices in order 1
    CALL ClrScr
    CALL Graphics_FillTriangle(200, 20, 230, 20, 215, 50, 9)
    DIM ref AS INTEGER
    ref = GetP(215, 35)     ' interior sample

    CALL ClrScr
    CALL Graphics_FillTriangle(230, 20, 215, 50, 200, 20, 9)
    CALL Assert_IsEqual(GetP(215, 35), ref, "permutation 2 same interior pixel")

    CALL ClrScr
    CALL Graphics_FillTriangle(215, 50, 200, 20, 230, 20, 9)
    CALL Assert_IsEqual(GetP(215, 35), ref, "permutation 3 same interior pixel")

    CALL ClrScr
    CALL Graphics_FillTriangle(215, 50, 230, 20, 200, 20, 9)
    CALL Assert_IsEqual(GetP(215, 35), ref, "permutation 4 same interior pixel")
END SUB

SUB Test_FillTriangle_Degenerate_ZeroArea
    CALL Test_Case("FillTriangle zero-area (collinear) draws its line")
    CALL ClrScr
    ' Three collinear points: (10,80),(20,80),(30,80)  -> flat horizontal line
    CALL Graphics_FillTriangle(10, 80, 20, 80, 30, 80, 2)
    CALL Assert_IsEqual(GetP(10, 80), 2, "left collinear point")
    CALL Assert_IsEqual(GetP(20, 80), 2, "mid collinear point")
    CALL Assert_IsEqual(GetP(30, 80), 2, "right collinear point")
    CALL Assert_IsEqual(GetP(9,  80), 0, "outside left")
    CALL Assert_IsEqual(GetP(31, 80), 0, "outside right")
END SUB

SUB Test_FillTriangle_Degenerate_ZeroHeight
    CALL Test_Case("FillTriangle zero-height (single point) draws one pixel")
    CALL ClrScr
    CALL Graphics_FillTriangle(100, 100, 100, 100, 100, 100, 11)
    CALL Assert_IsEqual(GetP(100, 100), 11, "single degenerate pixel")
    CALL Assert_IsEqual(GetP(101, 100), 0, "neighbour untouched")
END SUB

' =============================================================================
' Tests: Graphics_TexTriangle
' =============================================================================

' Build a 4x4 checkerboard: even cells=colour 5, odd cells=colour 10
' Layout (row-major, y*4+x): (x+y) MOD 2 = 0 -> 5 else 10
FUNCTION MakeChecker4x4() AS STRING
    DIM s AS STRING
    DIM x AS INTEGER, y AS INTEGER, idx AS INTEGER
    s = STRING$(16, 0)
    FOR y = 0 TO 3
        FOR x = 0 TO 3
            idx = y * 4 + x + 1
            IF (x + y) MOD 2 = 0 THEN
                MID$(s, idx, 1) = CHR$(5)
            ELSE
                MID$(s, idx, 1) = CHR$(10)
            END IF
        NEXT x
    NEXT y
    MakeChecker4x4 = s
END FUNCTION

SUB Test_TexTriangle_Checkerboard
    CALL Test_Case("TexTriangle maps checkerboard texture onto a right-triangle")
    CALL ClrScr
    DIM tex AS STRING
    tex = MakeChecker4x4()
    ' Map a 4x4 screen right-triangle to the full 4x4 texture.
    ' One texel per screen pixel so U steps of exactly 65536 (no rounding).
    '   vertex A = screen(20,10) uv(0,0)
    '   vertex B = screen(24,10) uv(4,0)  (clamped to uInt=3 at the boundary)
    '   vertex C = screen(20,14) uv(0,4)  (clamped to vInt=3 at the boundary)
    CALL Graphics_TexTriangle(20, 10, 0, 0, 24, 10, 4, 0, 20, 14, 0, 4, tex, 4, 4, -1)
    ' At y=10, x=20: uv(0,0) -> (0+0)%2=0 -> colour 5
    CALL Assert_IsEqual(GetP(20, 10), 5, "x=20 uv(0,0) -> colour 5")
    ' At y=10, x=21: uv(1,0) -> (1+0)%2=1 -> colour 10
    CALL Assert_IsEqual(GetP(21, 10), 10, "x=21 uv(1,0) -> colour 10")
    ' At y=10, x=22: uv(2,0) -> (2+0)%2=0 -> colour 5
    CALL Assert_IsEqual(GetP(22, 10), 5, "x=22 uv(2,0) -> colour 5")
    ' At y=10, x=23: uv(3,0) -> (3+0)%2=1 -> colour 10
    CALL Assert_IsEqual(GetP(23, 10), 10, "x=23 uv(3,0) -> colour 10")
    ' At y=11, x=20: uv(0,1) -> (0+1)%2=1 -> colour 10
    CALL Assert_IsEqual(GetP(20, 11), 10, "x=20,y=11 uv(0,1) -> colour 10")
    ' At y=12, x=20: uv(0,2) -> (0+2)%2=0 -> colour 5
    CALL Assert_IsEqual(GetP(20, 12), 5, "x=20,y=12 uv(0,2) -> colour 5")
END SUB

SUB Test_TexTriangle_Transparency
    CALL Test_Case("TexTriangle transparency skips texels equal to transparentIdx")
    CALL ClrScr
    ' Fill background with colour 99 under the test area
    DIM bg AS BYTE
    bg = 99
    DIM bx1 AS WORD, by1 AS WORD, bx2 AS WORD, by2 AS WORD
    bx1 = 18 : by1 = 18 : bx2 = 28 : by2 = 28
    CALL Vga_FillRect(bx1, by1, bx2, by2, bg)

    DIM tex AS STRING
    tex = MakeChecker4x4()
    ' Same 4x4 triangle, transparentIdx=5: even-cell colour skipped, background shows through
    CALL Graphics_TexTriangle(20, 20, 0, 0, 24, 20, 4, 0, 20, 24, 0, 4, tex, 4, 4, 5)
    ' x=20: uv(0,0) -> texel=5 -> transparent -> background 99
    CALL Assert_IsEqual(GetP(20, 20), 99, "uv(0,0) transparent leaves background 99")
    ' x=21: uv(1,0) -> texel=10 -> drawn
    CALL Assert_IsEqual(GetP(21, 20), 10, "uv(1,0) opaque drawn as 10")
    ' x=22: uv(2,0) -> texel=5 -> transparent -> background 99
    CALL Assert_IsEqual(GetP(22, 20), 99, "uv(2,0) transparent leaves background 99")
    ' x=23: uv(3,0) -> texel=10 -> drawn
    CALL Assert_IsEqual(GetP(23, 20), 10, "uv(3,0) opaque drawn as 10")
END SUB

SUB Test_TexTriangle_NoTransparency
    CALL Test_Case("TexTriangle with transparentIdx=-1 draws every texel")
    CALL ClrScr
    DIM tex AS STRING
    tex = MakeChecker4x4()
    ' transparentIdx=-1: colour 5 must be drawn (not skipped)
    CALL Graphics_TexTriangle(20, 10, 0, 0, 24, 10, 4, 0, 20, 14, 0, 4, tex, 4, 4, -1)
    ' x=20: uv(0,0) -> colour 5 -> must be drawn
    CALL Assert_IsEqual(GetP(20, 10), 5, "colour 5 drawn when transparentIdx=-1")
    ' x=21: uv(1,0) -> colour 10 -> must be drawn
    CALL Assert_IsEqual(GetP(21, 10), 10, "colour 10 drawn when transparentIdx=-1")
END SUB

' =============================================================================
' Lifecycle
' =============================================================================

SUB Test_Setup
!MOV AX, &H0013
!INT &H10
VESASystemContext.CurrentMode = %SVGA_MODE13
END SUB

SUB Test_Teardown
!MOV AX, &H0003
!INT &H10
END SUB
