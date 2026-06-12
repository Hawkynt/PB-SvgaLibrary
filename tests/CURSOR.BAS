' =============================================================================
' CURSOR.BAS - tests for CURSOR.SUB (software mouse-cursor state + save/restore).
'              Cursor_Set (ICO/CUR file loading) is covered by the DRAW_CUR/ICO
'              suites; here a synthetic cursor drives show/hide/move in mode 13h.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
DECLARE FUNCTION Svga_GetPixel(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
$INCLUDE "CURSOR.SUB"

SUB Svga_InitDispatchTable
END SUB
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB
' CURSOR draws/saves through the Svga_* dispatch entry points -> route to VGA:
SUB Svga_PutPixel(x AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_PutPixel(x, y, c)
END SUB
' test double matches the REAL library shape: a FUNCTION(x, y) AS BYTE
FUNCTION Svga_GetPixel(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    Svga_GetPixel = r
END FUNCTION

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
    CALL Test_Case("Cursor_IsVisible reflects the visible flag")
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
    CALL Assert_IsEqual(GetP(100, 100), 5, "original background restored")
    !MOV AX, &H0003
    !INT &H10
END SUB

' =============================================================================
' CUR fixture builders (mirrors the pattern in DRAW_CUR.BAS)
' =============================================================================
FUNCTION CLE16(BYVAL v AS WORD) AS STRING
    CLE16 = CHR$(v AND 255) + CHR$((v \ 256) AND 255)
END FUNCTION
FUNCTION CLE32(BYVAL v AS LONG) AS STRING
    CLE32 = CHR$(v AND 255) + CHR$((v \ 256) AND 255) + _
            CHR$((v \ 65536) AND 255) + CHR$((v \ 16777216) AND 255)
END FUNCTION

' Build a 4x4 1-bit CUR: hotspot (1,2), all XOR pixels = 1 (white=255), all mask opaque.
' Entry ColorCount=2; BIH biBitCount=1; biHeight=8 (doubled).
' XOR scanlineWidth = ((4*1+31)/32)*4 = 4 bytes/row; 4 rows = 16 bytes.
' AND scanlineWidth = ((4+31)/32)*4 = 4 bytes/row; 4 rows = 16 bytes.
' Palette: 2 BGRA entries: black + white.
SUB MakeCset1bit(BYVAL fileName AS STRING)
    DIM hdr AS STRING, entry AS STRING, bih AS STRING
    DIM pal AS STRING, xorData AS STRING, andData AS STRING
    hdr = CLE16(0) + CLE16(2) + CLE16(1)
    ' imageOffset = 6 (header) + 16 (entry) = 22
    entry = CHR$(4) + CHR$(4) + CHR$(2) + CHR$(0) + _
            CLE16(1) + CLE16(2) + _
            CLE32(80) + CLE32(22)
    ' BIH: biHeight=8 (doubled), biBitCount=1
    bih = CLE32(40) + CLE32(4) + CLE32(8) + CLE16(1) + CLE16(1) + _
          CLE32(0) + CLE32(0) + CLE32(0) + CLE32(0) + CLE32(0) + CLE32(0)
    pal = CHR$(0)+CHR$(0)+CHR$(0)+CHR$(0) + CHR$(255)+CHR$(255)+CHR$(255)+CHR$(0)
    ' All pixels = 1 (white): 4 pixels = &HF0 (MSB-first 1111...); pad to 4 bytes.
    ' 4 rows bottom-up, all identical.
    xorData = STRING$(16, CHR$(&HF0))
    andData = STRING$(16, CHR$(0))
    OPEN fileName FOR BINARY AS #11
    PUT$ #11, hdr + entry + bih + pal + xorData + andData
    CLOSE #11
END SUB

' Build a 4x4 4-bit CUR: hotspot (0,0), all XOR pixels = 5 (index 5), all mask opaque.
' Entry ColorCount=16; BIH biBitCount=4; biHeight=8 (doubled).
' XOR scanlineWidth = ((4*4+31)/32)*4 = 4 bytes/row; packed: 2 nibbles per byte.
' Palette: 16 BGRA entries (entry i = B=i*4, G=i*4, R=i*4, A=0).
' All pixels = index 5 -> packed &H55 per 2 pixels; 2 bytes for 4 pixels + 2 pad.
SUB MakeCset4bit(BYVAL fileName AS STRING)
    DIM hdr AS STRING, entry AS STRING, bih AS STRING
    DIM pal AS STRING, xorData AS STRING, andData AS STRING
    DIM pi AS INTEGER
    hdr = CLE16(0) + CLE16(2) + CLE16(1)
    ' DIB: 40 + 64 (palette) + 16 (XOR) + 16 (AND) = 136
    entry = CHR$(4) + CHR$(4) + CHR$(16) + CHR$(0) + _
            CLE16(0) + CLE16(0) + _
            CLE32(136) + CLE32(22)
    bih = CLE32(40) + CLE32(4) + CLE32(8) + CLE16(1) + CLE16(4) + _
          CLE32(0) + CLE32(0) + CLE32(0) + CLE32(0) + CLE32(0) + CLE32(0)
    pal = ""
    FOR pi = 0 TO 15
        pal = pal + CHR$(pi*4) + CHR$(pi*4) + CHR$(pi*4) + CHR$(0)
    NEXT pi
    ' All pixels = 5: nibbles &H55; 4 pixels = 2 bytes (&H55 &H55); 2 pad bytes.
    ' 4 rows, all the same.
    xorData = STRING$(16, CHR$(&H55))
    andData = STRING$(16, CHR$(0))
    OPEN fileName FOR BINARY AS #12
    PUT$ #12, hdr + entry + bih + pal + xorData + andData
    CLOSE #12
END SUB

' =============================================================================
' Cursor_Set tests: real CUR file parsing (1-bit and 4-bit)
' =============================================================================

SUB Test_CursorSet_1bit_Dimensions
    CALL Test_Case("Cursor_Set loads 1-bit CUR: Wide/Height/hotspot set correctly")
    !MOV AX, &H0013
    !INT &H10
    CALL Cursor_Init
    CALL MakeCset1bit("CS1.CUR")
    CALL Cursor_Set("CS1.CUR", 0)
    CALL Assert_IsEqual(CursorSystemContext.Wide,     4, "1bit: Wide = 4")
    CALL Assert_IsEqual(CursorSystemContext.Height,   4, "1bit: Height = 4")
    CALL Assert_IsEqual(CursorSystemContext.HotspotX, 1, "1bit: HotspotX = 1")
    CALL Assert_IsEqual(CursorSystemContext.HotspotY, 2, "1bit: HotspotY = 2")
    CALL Assert_IsNotZero(LEN(CursorDataStore),  "1bit: CursorDataStore non-empty")
    CALL Assert_IsNotZero(LEN(CursorMaskStore),  "1bit: CursorMaskStore non-empty")
    CALL Assert_IsEqual(LEN(CursorDataStore), 16, "1bit: CursorDataStore = w*h = 16")
    !MOV AX, &H0003
    !INT &H10
END SUB

SUB Test_CursorSet_1bit_Show
    CALL Test_Case("Cursor_Set+Show: 1-bit cursor pixels land on screen")
    !MOV AX, &H0013
    !INT &H10
    CALL Cursor_Init
    CALL MakeCset1bit("CS1.CUR")
    ' Paint background with colour 7 under the cursor area
    DIM bgx AS INTEGER, bgy AS INTEGER
    FOR bgy = 20 TO 23
        FOR bgx = 30 TO 33
            CALL PutBg(bgx, bgy, 7)
        NEXT bgx
    NEXT bgy
    ' hotspot (1,2); SetPos at (31,22) -> internal pos (30,20); cursor covers (30-33, 20-23)
    CALL Cursor_Set("CS1.CUR", 0)
    CALL Cursor_SetPos(31, 22)
    CALL Cursor_Show
    ' All pixels are index 1 (white -> 255) and mask=0 (opaque): must draw 255
    CALL Assert_IsEqual(GetP(30, 20), 255, "1bit show: top-left pixel = 255")
    CALL Assert_IsEqual(GetP(33, 23), 255, "1bit show: bottom-right pixel = 255")
    !MOV AX, &H0003
    !INT &H10
END SUB

SUB Test_CursorSet_4bit_Dimensions
    CALL Test_Case("Cursor_Set loads 4-bit CUR: Wide/Height/hotspot set correctly")
    !MOV AX, &H0013
    !INT &H10
    CALL Cursor_Init
    CALL MakeCset4bit("CS4.CUR")
    CALL Cursor_Set("CS4.CUR", 0)
    CALL Assert_IsEqual(CursorSystemContext.Wide,     4, "4bit: Wide = 4")
    CALL Assert_IsEqual(CursorSystemContext.Height,   4, "4bit: Height = 4")
    CALL Assert_IsEqual(CursorSystemContext.HotspotX, 0, "4bit: HotspotX = 0")
    CALL Assert_IsEqual(CursorSystemContext.HotspotY, 0, "4bit: HotspotY = 0")
    CALL Assert_IsEqual(LEN(CursorDataStore), 16, "4bit: CursorDataStore = w*h = 16")
    !MOV AX, &H0003
    !INT &H10
END SUB

SUB Test_CursorSet_4bit_Show
    CALL Test_Case("Cursor_Set+Show: 4-bit cursor pixels (index 5) land on screen")
    !MOV AX, &H0013
    !INT &H10
    CALL Cursor_Init
    CALL MakeCset4bit("CS4.CUR")
    DIM bgx AS INTEGER, bgy AS INTEGER
    FOR bgy = 40 TO 43
        FOR bgx = 50 TO 53
            CALL PutBg(bgx, bgy, 9)
        NEXT bgx
    NEXT bgy
    ' hotspot (0,0); SetPos at (50,40) -> draws at (50,40)
    CALL Cursor_Set("CS4.CUR", 0)
    CALL Cursor_SetPos(50, 40)
    CALL Cursor_Show
    ' All opaque pixels = index 5
    CALL Assert_IsEqual(GetP(50, 40), 5, "4bit show: top-left pixel = 5")
    CALL Assert_IsEqual(GetP(53, 43), 5, "4bit show: bottom-right pixel = 5")
    !MOV AX, &H0003
    !INT &H10
END SUB

SUB Test_CursorSet_MissingFile
    CALL Test_Case("Cursor_Set ignores missing file, leaves context unchanged")
    CALL Cursor_Init
    CursorSystemContext.Wide = 99
    CursorSystemContext.Height = 88
    CALL Cursor_Set("NOFILE.CUR", 0)
    ' Width/Height come from the file; on failure Wide stays 99 (no modification)
    CALL Assert_IsEqual(CursorSystemContext.Wide, 99, "missing file: Wide unchanged")
END SUB

SUB Test_Setup
SVGAScreenContext.XRes = 320
SVGAScreenContext.YRes = 200
END SUB
