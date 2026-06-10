' =============================================================================
' GRAPHICS.TST - tests for GRAPHICS.SUB (Bar/Bar3d/Box/Frame/CircleDraw)
' =============================================================================
' The high-level shapes delegate to Svga_LineDraw (generic path) or ModeX_*
' (Mode-X path). Here the generic path is exercised in mode 13h with
' Svga_LineDraw routed to the real Vga_LineDraw, reading pixels back via VGA.
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "GRAPHICS.SUB"

SUB Svga_InitDispatchTable
END SUB
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB
' Mode-X branch of GRAPHICS.SUB is not exercised here (mode 13h forces the
' generic path) but its calls must still resolve at compile time:
SUB ModeX_HLine(x1 AS WORD, x2 AS WORD, y AS WORD, c AS BYTE)
END SUB
SUB ModeX_VLine(x AS WORD, y1 AS WORD, y2 AS WORD, c AS BYTE)
END SUB
SUB Svga_LineDraw(x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD, c AS BYTE)
    CALL Vga_LineDraw(x1, y1, x2, y2, c)
END SUB

FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION
SUB Cls0
    DIM e AS BYTE
    e = 0
    CALL Vga_ClearScreen(e)
END SUB

SUB Test_Bar_FillAndBorder
    CALL TCase("Bar fills the interior and frames it with the border colour")
    CALL Cls0
    CALL Graphics_Bar(50, 50, 70, 60, 4, 2)      ' border=4, fill=2
    CALL TChkEq(GetP(60, 55), 2, "interior is fill colour")
    CALL TChkEq(GetP(50, 55), 4, "left edge is border colour")
    CALL TChkEq(GetP(70, 55), 4, "right edge is border colour")
    CALL TChkEq(GetP(60, 50), 4, "top edge is border colour")
    CALL TChkEq(GetP(60, 60), 4, "bottom edge is border colour")
END SUB

SUB Test_Bar_SwappedCorners
    CALL TCase("Bar normalises reversed corners")
    CALL Cls0
    CALL Graphics_Bar(70, 60, 50, 50, 4, 2)      ' x2<x1, y2<y1
    CALL TChkEq(GetP(60, 55), 2, "interior still filled")
    CALL TChkEq(GetP(50, 55), 4, "edge still bordered")
END SUB

SUB Test_Box_SolidFill
    CALL TCase("Box fills border and interior with one colour")
    CALL Cls0
    CALL Graphics_Box(100, 80, 110, 90, 7)
    CALL TChkEq(GetP(105, 85), 7, "interior")
    CALL TChkEq(GetP(100, 85), 7, "edge same colour")
    CALL TChkEq(GetP(99, 85), 0, "outside untouched")
END SUB

SUB Test_Frame_HollowOutline
    CALL TCase("Frame draws only the outline")
    CALL Cls0
    CALL Graphics_Frame(150, 100, 170, 115, 6)
    CALL TChkEq(GetP(150, 107), 6, "left edge")
    CALL TChkEq(GetP(170, 107), 6, "right edge")
    CALL TChkEq(GetP(160, 100), 6, "top edge")
    CALL TChkEq(GetP(160, 115), 6, "bottom edge")
    CALL TChkEq(GetP(160, 107), 0, "hollow interior")
END SUB

SUB Test_Bar3d_FaceAndBorder
    CALL TCase("Bar3d fills the main face and borders it")
    CALL Cls0
    CALL Graphics_Bar3d(100, 100, 120, 110, 8, 5, 3)   ' depth=8 border=5 fill=3
    CALL TChkEq(GetP(110, 105), 3, "main face fill")
    CALL TChkEq(GetP(100, 105), 5, "main face left border")
    CALL TChkEq(GetP(110, 100), 5, "main face top border")
END SUB

SUB Test_CircleDraw_Outline
    CALL TCase("CircleDraw (outline) sets the rightmost point")
    CALL Cls0
    CALL Graphics_CircleDraw(200, 100, 20, 20, 0, 360, 9, 0)
    CALL TChkEq(GetP(220, 100), 9, "point at angle 0 (centerX+radiusX)")
END SUB

SUB Test_CircleDraw_Filled
    CALL TCase("CircleDraw (filled) fills the centre row")
    CALL Cls0
    CALL Graphics_CircleDraw(200, 150, 15, 15, 0, 360, 11, 1)
    CALL TChkEq(GetP(200, 150), 11, "centre filled")
    CALL TChkEq(GetP(212, 150), 11, "inside on the centre row")
    CALL TChkEq(GetP(200, 134), 0, "outside the circle above")
END SUB

' === entry point ===
!MOV AX, &H0013
!INT &H10
VESASystemContext.CurrentMode = %SVGA_MODE13      ' force the generic Svga_LineDraw path
CALL TBeginSuite("GRAPHICS")
CALL Test_Bar_FillAndBorder
CALL Test_Bar_SwappedCorners
CALL Test_Box_SolidFill
CALL Test_Frame_HollowOutline
CALL Test_Bar3d_FaceAndBorder
CALL Test_CircleDraw_Outline
CALL Test_CircleDraw_Filled
CALL TEndSuite("GRAPHICS")
!MOV AX, &H0003
!INT &H10
END
