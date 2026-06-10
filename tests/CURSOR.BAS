' =============================================================================
' CURSOR.BAS - tests for CURSOR.SUB (software mouse-cursor state + save/restore).
'              Cursor_Set (ICO/CUR file loading) is covered by the DRAW_CUR/ICO
'              suites; here a synthetic cursor drives show/hide/move in mode 13h.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "CURSOR.SUB"

SUB Svga_InitDispatchTable
END SUB
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB
' CURSOR draws/saves through the Svga_* dispatch entry points -> route to VGA:
SUB Svga_PutPixel(x AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_PutPixel(x, y, c)
END SUB
SUB Svga_GetPixel(x AS WORD, y AS WORD, r AS BYTE)
    CALL Vga_GetPixel(x, y, r)
END SUB

SUB PutBg(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM xv AS WORD, yv AS WORD, cv AS BYTE
    xv = x : yv = y : cv = c
    CALL Vga_PutPixel(xv, yv, cv)
END SUB
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r) : GetP = r
END FUNCTION
FUNCTION CGX() AS INTEGER
    DIM x AS WORD, y AS WORD
    CALL Cursor_GetPos(x, y) : CGX = x
END FUNCTION
FUNCTION CGY() AS INTEGER
    DIM x AS WORD, y AS WORD
    CALL Cursor_GetPos(x, y) : CGY = y
END FUNCTION

SUB MakeCursor(BYVAL w AS WORD, BYVAL h AS WORD)
    CursorSystemContext.Wide = w
    CursorSystemContext.Height = h
    CursorDataStore = STRING$(w * h, CHR$(9))     ' solid colour-9 cursor
    CursorMaskStore = STRING$(w * h, CHR$(0))     ' fully opaque
END SUB

SUB Test_Init_Defaults
    CALL Test_Case("Init clears the cursor state")
    CALL Cursor_Init
    CALL Assert_IsNotZero(CursorSystemContext.IsInitialized, "initialized flag set")
    CALL Assert_IsZero(CursorSystemContext.IsVisible, "starts hidden")
    CALL Assert_IsEqual(CGX(), 0, "X starts at 0")
    CALL Assert_IsEqual(CGY(), 0, "Y starts at 0")
END SUB

SUB Test_SetGetPos_NoHotspot
    CALL Test_Case("SetPos/GetPos round-trip with no hotspot")
    CALL Cursor_Init
    CALL Cursor_SetPos(50, 60)
    CALL Assert_IsEqual(CGX(), 50, "X set") : CALL Assert_IsEqual(CGY(), 60, "Y set")
    CALL Assert_IsEqual(CursorSystemContext.CurrentX, 50, "internal X matches (hotspot 0)")
END SUB

SUB Test_GetPos_Hotspot
    CALL Test_Case("GetPos reports the hotspot-adjusted position")
    CALL Cursor_Init
    CursorSystemContext.HotspotX = 2
    CursorSystemContext.HotspotY = 3
    CALL Cursor_SetPos(50, 60)
    CALL Assert_IsEqual(CursorSystemContext.CurrentX, 48, "internal X = pos - hotspot")
    CALL Assert_IsEqual(CursorSystemContext.CurrentY, 57, "internal Y = pos - hotspot")
    CALL Assert_IsEqual(CGX(), 50, "GetPos adds the hotspot back")
    CALL Assert_IsEqual(CGY(), 60, "GetPos adds the hotspot back (Y)")
END SUB

SUB Test_IsVisible_Tracks
    CALL Test_Case("Cursor_IsVisible reflects the visible flag (regression: was always 0)")
    CALL Cursor_Init
    CALL Assert_IsZero(Cursor_IsVisible, "hidden after init")
    CursorSystemContext.IsVisible = 1
    CALL Assert_IsNotZero(Cursor_IsVisible, "reports visible when the flag is set")
END SUB

SUB Test_ShowHide_BackgroundRoundTrip
    CALL Test_Case("Show draws the cursor; Hide restores the saved background")
    !MOV AX, &H0013
    !INT &H10
    CALL Cursor_Init
    CALL MakeCursor(4, 4)
    ' paint a known background under where the cursor will sit
    DIM ix AS INTEGER, iy AS INTEGER
    FOR iy = 100 TO 103
        FOR ix = 100 TO 103
            CALL PutBg(ix, iy, 5)
        NEXT ix
    NEXT iy
    CALL Cursor_SetPos(100, 100)
    CALL Cursor_Show
    CALL Assert_IsNotZero(Cursor_IsVisible, "visible after Show")
    CALL Assert_IsEqual(GetP(100, 100), 9, "cursor pixel drawn over the background")
    CALL Cursor_Hide
    CALL Assert_IsZero(Cursor_IsVisible, "hidden after Hide")
    CALL Assert_IsEqual(GetP(100, 100), 5, "original background restored (relies on the GetPixel save fix)")
    !MOV AX, &H0003
    !INT &H10
END SUB

' === entry point ===
SVGAScreenContext.XRes = 320
SVGAScreenContext.YRes = 200
CALL Test_BeginSuite("CURSOR")
Test_Init_Defaults
Test_SetGetPos_NoHotspot
Test_GetPos_Hotspot
Test_IsVisible_Tracks
Test_ShowHide_BackgroundRoundTrip
CALL Test_EndSuite("CURSOR")
END
