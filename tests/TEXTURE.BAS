' =============================================================================
' TEXTURE.BAS - tests for TEXTURE.SUB (TexRect / TexCircle)
' =============================================================================
' Mode 13h is set in Test_Setup; Svga_PutPixel is routed to Vga_PutPixel and
' pixels are read back via Vga_GetPixel. Textures are built as CHR$ strings.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "TEXTURE.SUB"

' Stubs required by VGA.SUB and TEXTURE.SUB dependencies.
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB
SUB Svga_InitDispatchTable
END SUB

' Route Svga_PutPixel to the real VGA writer.
SUB Svga_PutPixel(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    CALL Vga_PutPixel(x, y, c)
END SUB

' Read back a pixel.
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, rv AS BYTE
    xv = x : yv = y : rv = 0
    CALL Vga_GetPixel(xv, yv, rv)
    GetP = rv
END FUNCTION

' Clear the screen to color c.
SUB ClsTo(BYVAL c AS BYTE)
    DIM i AS WORD, j AS WORD
    FOR j = 0 TO 199
        FOR i = 0 TO 319
            CALL Vga_PutPixel(i, j, c)
        NEXT i
    NEXT j
END SUB

' ---------------------------------------------------------------------------
' Build the standard 4x4 checkerboard used across most tests:
'   top-left 2x2 = color 10, top-right 2x2 = color 20, etc.
'   indices are (u<2 XOR v<2)*10 + 10 - simplest: hardcode the 16 bytes
' Row 0: 10 10 20 20
' Row 1: 10 10 20 20
' Row 2: 20 20 10 10
' Row 3: 20 20 10 10
' ---------------------------------------------------------------------------
FUNCTION MakeChecker4() AS STRING
    DIM s AS STRING
    s = CHR$(10) + CHR$(10) + CHR$(20) + CHR$(20)
    s = s + CHR$(10) + CHR$(10) + CHR$(20) + CHR$(20)
    s = s + CHR$(20) + CHR$(20) + CHR$(10) + CHR$(10)
    s = s + CHR$(20) + CHR$(20) + CHR$(10) + CHR$(10)
    MakeChecker4 = s
END FUNCTION

' ---------------------------------------------------------------------------
' TexRect tests
' ---------------------------------------------------------------------------

SUB Test_TexRect_CornerTexels
    CALL Test_Case("TexRect: corner pixels map to correct texel u,v")
    DIM tex AS STRING
    tex = MakeChecker4()
    CALL ClsTo(0)
    ' Draw at (50,80) to (53,83) - exact 4x4 rect, one tile
    CALL Graphics_TexRect(50, 80, 53, 83, tex, 4, 4, -1)
    ' (50,80) -> u=0, v=0 -> color 10
    CALL Assert_IsEqual(GetP(50, 80), 10, "top-left corner (u=0,v=0) = 10")
    ' (51,80) -> u=1, v=0 -> color 10
    CALL Assert_IsEqual(GetP(51, 80), 10, "top (u=1,v=0) = 10")
    ' (52,80) -> u=2, v=0 -> color 20
    CALL Assert_IsEqual(GetP(52, 80), 20, "top-right area (u=2,v=0) = 20")
    ' (50,82) -> u=0, v=2 -> color 20
    CALL Assert_IsEqual(GetP(50, 82), 20, "bottom-left area (u=0,v=2) = 20")
    ' (52,82) -> u=2, v=2 -> color 10
    CALL Assert_IsEqual(GetP(52, 82), 10, "bottom-right area (u=2,v=2) = 10")
END SUB

SUB Test_TexRect_Tiling
    CALL Test_Case("TexRect: texture tiles correctly across a 10x6 rect")
    DIM tex AS STRING
    tex = MakeChecker4()
    CALL ClsTo(0)
    ' Draw 10 wide x 6 tall starting at (60,90). texW=4 -> tiles at x=60,64,68...
    CALL Graphics_TexRect(60, 90, 69, 95, tex, 4, 4, -1)
    ' At x=60 u=0,v=0 -> 10; at x=64 (60+4) u=0,v=0 -> 10 (tile repeat)
    CALL Assert_IsEqual(GetP(60, 90), 10, "x=60 u=0 -> 10")
    CALL Assert_IsEqual(GetP(64, 90), 10, "x=64 u=0 again (tiled) -> 10")
    CALL Assert_IsEqual(GetP(68, 90), 10, "x=68 u=0 again (tiled) -> 10")
    ' At x=62 u=2 -> 20
    CALL Assert_IsEqual(GetP(62, 90), 20, "x=62 u=2 -> 20")
    ' At x=66 (66-60=6, 6 MOD 4=2) u=2 -> 20
    CALL Assert_IsEqual(GetP(66, 90), 20, "x=66 u=2 (tiled) -> 20")
    ' v=4 wraps to 0: y=94 v=4 MOD 4=0 same as y=90
    CALL Assert_IsEqual(GetP(60, 94), GetP(60, 90), "row v=4 wraps to v=0")
END SUB

SUB Test_TexRect_Transparency
    CALL Test_Case("TexRect: transparent index leaves background intact")
    DIM tex AS STRING
    tex = MakeChecker4()
    CALL ClsTo(33)                          ' background = color 33
    ' Use transparentIdx = 10; pixels with color 10 must not overwrite bg
    CALL Graphics_TexRect(100, 100, 103, 103, tex, 4, 4, 10)
    ' u=0,v=0 -> texel 10 = transparent -> background 33 survives
    CALL Assert_IsEqual(GetP(100, 100), 33, "transparent texel leaves bg=33")
    ' u=2,v=0 -> texel 20 != 10 -> drawn
    CALL Assert_IsEqual(GetP(102, 100), 20, "opaque texel (20) is drawn")
    ' u=0,v=2 -> texel 20 != 10 -> drawn
    CALL Assert_IsEqual(GetP(100, 102), 20, "opaque texel (20) at v=2 drawn")
    ' u=2,v=2 -> texel 10 = transparent -> bg survives
    CALL Assert_IsEqual(GetP(102, 102), 33, "transparent texel at (2,2) leaves bg")
END SUB

SUB Test_TexRect_1x1
    CALL Test_Case("TexRect: 1x1 rectangle draws exactly one texel")
    DIM tex AS STRING
    tex = MakeChecker4()
    CALL ClsTo(0)
    CALL Graphics_TexRect(150, 150, 150, 150, tex, 4, 4, -1)
    ' u=0,v=0 -> texel 10
    CALL Assert_IsEqual(GetP(150, 150), 10, "single pixel = first texel (10)")
    ' Neighbors untouched
    CALL Assert_IsEqual(GetP(151, 150), 0, "pixel to the right untouched")
    CALL Assert_IsEqual(GetP(150, 151), 0, "pixel below untouched")
END SUB

SUB Test_TexRect_OpaqueCoversAll
    CALL Test_Case("TexRect: opaque fill (transparentIdx=-1) covers every pixel")
    DIM tex AS STRING, i AS WORD, j AS WORD, bad AS INTEGER
    tex = MakeChecker4()
    CALL ClsTo(99)
    CALL Graphics_TexRect(10, 10, 17, 13, tex, 4, 4, -1)
    bad = 0
    FOR j = 10 TO 13
        FOR i = 10 TO 17
            IF GetP(i, j) = 99 THEN bad = bad + 1
        NEXT i
    NEXT j
    CALL Assert_IsZero(bad, "no background pixels survive opaque fill")
END SUB

' ---------------------------------------------------------------------------
' TexCircle tests
' ---------------------------------------------------------------------------

SUB Test_TexCircle_CentreTexel
    CALL Test_Case("TexCircle: centre pixel maps to correct bounding-box texel")
    DIM tex AS STRING
    tex = MakeChecker4()
    ' r=4 -> bbLeft=cx-4, bbTop=cy-4; centre: u=(cx-bbLeft)=4, 4 MOD 4=0; v=4 MOD 4=0 -> texel(0,0)=10
    CALL ClsTo(0)
    CALL Graphics_TexCircle(50, 50, 4, tex, 4, 4, -1)
    CALL Assert_IsEqual(GetP(50, 50), 10, "centre texel (u=0,v=0) = 10")
END SUB

SUB Test_TexCircle_InsideTextured
    CALL Test_Case("TexCircle: pixels inside circle are textured, outside untouched")
    DIM tex AS STRING
    DIM i AS INTEGER, j AS INTEGER, bad AS INTEGER
    DIM dxs AS INTEGER, dys AS INTEGER
    DIM inside AS INTEGER, got AS INTEGER
    tex = MakeChecker4()
    ' r=5, cx=80, cy=80
    CALL ClsTo(77)
    CALL Graphics_TexCircle(80, 80, 5, tex, 4, 4, -1)
    bad = 0
    FOR dys = -7 TO 7
        FOR dxs = -7 TO 7
            inside = 0
            IF dxs * dxs + dys * dys <= 25 THEN inside = 1
            got = GetP(80 + dxs, 80 + dys)
            IF inside = 1 AND got = 77 THEN bad = bad + 1
            IF inside = 0 AND got <> 77 THEN bad = bad + 1
        NEXT dxs
    NEXT dys
    CALL Assert_IsZero(bad, "all pixels inside/outside circle correct")
END SUB

SUB Test_TexCircle_ExactShape
    CALL Test_Case("TexCircle: exact dx^2+dy^2<=r^2 shape for r=8 (full scan 17x17)")
    DIM tex AS STRING
    DIM dxs AS INTEGER, dys AS INTEGER
    DIM inside AS INTEGER, got AS INTEGER, bad AS INTEGER
    tex = MakeChecker4()
    CALL ClsTo(31)
    CALL Graphics_TexCircle(120, 100, 8, tex, 4, 4, -1)
    bad = 0
    FOR dys = -10 TO 10
        FOR dxs = -10 TO 10
            inside = 0
            IF dxs * dxs + dys * dys <= 64 THEN inside = 1
            got = GetP(120 + dxs, 100 + dys)
            IF inside = 1 AND got = 31 THEN bad = bad + 1
            IF inside = 0 AND got <> 31 THEN bad = bad + 1
        NEXT dxs
    NEXT dys
    CALL Assert_IsZero(bad, "all 441 pixels match dx^2+dy^2<=64 exactly")
END SUB

SUB Test_TexCircle_Transparency
    CALL Test_Case("TexCircle: transparent index leaves background pixels")
    DIM tex AS STRING
    DIM cx AS WORD, cy AS WORD
    tex = MakeChecker4()
    ' r=4, cx=160, cy=100. u=(x-(160-4)) MOD 4, v=(y-(100-4)) MOD 4
    ' Centre: u=4 MOD 4=0, v=4 MOD 4=0 -> texel(0,0) = 10 = transparentIdx
    CALL ClsTo(55)
    CALL Graphics_TexCircle(160, 100, 4, tex, 4, 4, 10)
    ' Centre maps to transparent texel 10 -> background survives
    CALL Assert_IsEqual(GetP(160, 100), 55, "centre transparent texel leaves bg=55")
    ' Pixel at (162,100): u=(162-156) MOD 4=6 MOD 4=2, v=(100-96) MOD 4=4 MOD 4=0 -> texel(2,0)=20 (opaque)
    CALL Assert_IsEqual(GetP(162, 100), 20, "opaque texel at (162,100) drawn")
END SUB

SUB Test_TexCircle_Radius1
    CALL Test_Case("TexCircle: radius=1 draws exactly the 3-pixel cross (dx^2+dy^2<=1)")
    DIM tex AS STRING
    DIM dxs AS INTEGER, dys AS INTEGER, bad AS INTEGER, inside AS INTEGER, got AS INTEGER
    tex = MakeChecker4()
    CALL ClsTo(0)
    CALL Graphics_TexCircle(200, 100, 1, tex, 4, 4, -1)
    bad = 0
    FOR dys = -2 TO 2
        FOR dxs = -2 TO 2
            inside = 0
            IF dxs * dxs + dys * dys <= 1 THEN inside = 1
            got = GetP(200 + dxs, 100 + dys)
            IF inside = 1 AND got = 0 THEN bad = bad + 1
            IF inside = 0 AND got <> 0 THEN bad = bad + 1
        NEXT dxs
    NEXT dys
    CALL Assert_IsZero(bad, "r=1 circle has exactly 5 textured pixels")
END SUB

' ---------------------------------------------------------------------------
' Lifecycle
' ---------------------------------------------------------------------------

SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
    SVGAScreenContext.XRes = 320
    SVGAScreenContext.YRes = 200
    VESASystemContext.CurrentMode = %SVGA_MODE13
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB
