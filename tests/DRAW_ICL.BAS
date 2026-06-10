' =============================================================================
' DRAW_ICL.BAS - tests for DRAW_ICL.SUB (Windows DLL/EXE icon library loader)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "FILEUTIL.SUB"
DECLARE FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
' Forward-declare functions called before their definition inside DRAW_ICL.SUB
DECLARE FUNCTION DrawIcl_GetLibIconGroupName$(BYVAL libHandle AS BYTE, BYVAL groupIndex AS WORD)
DECLARE FUNCTION DrawIcl_ParsePEHeader(BYVAL fileHandle AS INTEGER, BYVAL libHandle AS BYTE) AS BYTE
DECLARE FUNCTION DrawIcl_ExtractIcon(BYVAL libHandle AS BYTE, BYVAL groupIndex AS WORD, BYVAL iconIndex AS WORD, iconData AS STRING, widthVal AS WORD, height AS WORD) AS BYTE
$INCLUDE "DRAW_ICL.SUB"

' ---------------------------------------------------------------------------
' Stubs
' ---------------------------------------------------------------------------
SUB Svga_InitDispatchTable
END SUB
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB
SUB Svga_PutPixel(x AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_PutPixel(x, y, c)
END SUB
SUB Svga_HLine(x1 AS WORD, x2 AS WORD, y AS WORD, c AS BYTE)
    CALL Vga_HLine(x1, x2, y, c)
END SUB
SUB Virtual_ToPhysical(x AS WORD, y AS WORD, px AS WORD, py AS WORD)
    px = x : py = y
END SUB
FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
    Virtual_IsVisible = 1
END FUNCTION

' ---------------------------------------------------------------------------
' LE16 / LE32 helpers
' ---------------------------------------------------------------------------
FUNCTION LE16(BYVAL v AS WORD) AS STRING
    LE16 = CHR$(v AND 255) + CHR$((v \ 256) AND 255)
END FUNCTION
FUNCTION LE32(BYVAL v AS LONG) AS STRING
    LE32 = CHR$(v AND 255) + CHR$((v \ 256) AND 255) + _
           CHR$((v \ 65536) AND 255) + CHR$((v \ 16777216) AND 255)
END FUNCTION

' ---------------------------------------------------------------------------
' MakeMzLib: write a minimal non-PE MZ executable (64 bytes).
'
' Layout (PB3.5 BINARY is 1-based):
'   Byte  0- 1 (PB pos 1): MZ signature  = 0x4D 0x5A
'   Byte  2- 3 (PB pos 3): BytesOnLastPage = 0
'   Byte  4- 5 (PB pos 5): PagesInFile     = 0
'   Byte  6-59 (PB pos 7): padding zeros (54 bytes)
'   Byte 60-63 (PB pos 61): AddressNewEXE  = 0  (skips PE path)
'
' With IsPE=0, DrawIcl_ScanIconGroups sets:
'   IconGroupCount = 1
'   ICOLIBIconGroupNamesStore(h, 0) = "Default"
'   ICOLIBIconGroupIDsStore(h, 0)   = 1
' ---------------------------------------------------------------------------
SUB MakeMzLib(BYVAL fileName AS STRING)
    DIM hdr AS STRING
    ' 2 bytes MZ sig + 2 bytes BytesOnLastPage + 2 bytes PagesInFile
    ' + 54 bytes pad (bytes 6..59) + 4 bytes AddressNewEXE=0
    ' Total = 64 bytes
    hdr = CHR$(&H4D) + CHR$(&H5A) + _
          CHR$(0) + CHR$(0) + _
          CHR$(0) + CHR$(0) + _
          STRING$(54, CHR$(0)) + _
          LE32(0)
    OPEN fileName FOR BINARY AS #1
    PUT$ #1, hdr
    CLOSE #1
END SUB

' ---------------------------------------------------------------------------
' GetP: read one pixel from VGA framebuffer
' ---------------------------------------------------------------------------
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, rv AS BYTE
    xv = x : yv = y : rv = 0
    CALL Vga_GetPixel(xv, yv, rv)
    GetP = rv
END FUNCTION

' ===========================================================================
' Test lifecycle
' ===========================================================================

SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
    CALL Vga_InitMode13h
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB

' ===========================================================================
' Test cases
' ===========================================================================

' ---------------------------------------------------------------------------
' Happy path: load a valid 16-bit (non-PE) MZ library
' ---------------------------------------------------------------------------
SUB Test_LoadIcoLib_Returns_ValidHandle
    CALL Test_Case("LoadIcoLib returns a handle 0-3 for a valid MZ file")
    DIM h AS BYTE
    CALL MakeMzLib("T.ICL")
    h = DrawIcl_LoadIcoLib("T.ICL")
    CALL Assert_IsTrue(h <= 3, "handle in range 0-3")
    IF h <= 3 THEN CALL DrawIcl_CloseIcoLib(h)
END SUB

' ---------------------------------------------------------------------------
' Missing file
' ---------------------------------------------------------------------------
SUB Test_LoadIcoLib_MissingFile_Returns255
    CALL Test_Case("LoadIcoLib returns 255 for a non-existent file")
    DIM h AS BYTE
    h = DrawIcl_LoadIcoLib("NOFILE.ICL")
    CALL Assert_IsEqual(h, 255, "handle = 255 for missing file")
END SUB

' ---------------------------------------------------------------------------
' File too small (< 64 bytes)
' ---------------------------------------------------------------------------
SUB Test_LoadIcoLib_TooSmall_Returns255
    CALL Test_Case("LoadIcoLib returns 255 when file is smaller than 64 bytes")
    DIM h AS BYTE
    OPEN "TSMALL.ICL" FOR BINARY AS #1
    PUT$ #1, STRING$(10, CHR$(0))
    CLOSE #1
    h = DrawIcl_LoadIcoLib("TSMALL.ICL")
    CALL Assert_IsEqual(h, 255, "handle = 255 for too-small file")
END SUB

' ---------------------------------------------------------------------------
' Bad signature (not MZ)
' ---------------------------------------------------------------------------
SUB Test_LoadIcoLib_BadSig_Returns255
    CALL Test_Case("LoadIcoLib returns 255 when MZ signature is absent")
    DIM h AS BYTE
    OPEN "TBAD.ICL" FOR BINARY AS #1
    PUT$ #1, STRING$(64, CHR$(0))  ' all zeros, sig=0x0000 != MZ
    CLOSE #1
    h = DrawIcl_LoadIcoLib("TBAD.ICL")
    CALL Assert_IsEqual(h, 255, "handle = 255 for bad signature")
END SUB

' ---------------------------------------------------------------------------
' Icon group count for 16-bit non-PE file
' ---------------------------------------------------------------------------
SUB Test_GetLibIconGroupCount_NonPE
    CALL Test_Case("GetLibIconGroupCount returns 1 for 16-bit non-PE MZ library")
    DIM h AS BYTE
    DIM cnt AS WORD
    CALL MakeMzLib("T.ICL")
    h = DrawIcl_LoadIcoLib("T.ICL")
    cnt = DrawIcl_GetLibIconGroupCount(h)
    CALL Assert_IsEqual(cnt, 1, "icon group count = 1")
    IF h <= 3 THEN CALL DrawIcl_CloseIcoLib(h)
END SUB

' ---------------------------------------------------------------------------
' GetLibIconGroupCount for invalid handle
' ---------------------------------------------------------------------------
SUB Test_GetLibIconGroupCount_InvalidHandle
    CALL Test_Case("GetLibIconGroupCount returns 0 for invalid handle 255")
    DIM cnt AS WORD
    cnt = DrawIcl_GetLibIconGroupCount(255)
    CALL Assert_IsZero(cnt, "count = 0 for handle 255")
END SUB

' ---------------------------------------------------------------------------
' GetLibIconGroupName for 16-bit non-PE file (group 0 = "Default")
' ---------------------------------------------------------------------------
SUB Test_GetLibIconGroupName_NonPE_Group0
    CALL Test_Case("GetLibIconGroupName returns Default for 16-bit non-PE group 0")
    DIM h AS BYTE
    DIM s AS STRING
    CALL MakeMzLib("T.ICL")
    h = DrawIcl_LoadIcoLib("T.ICL")
    s = DrawIcl_GetLibIconGroupName$(h, 0)
    CALL Assert_AreEqualStr(s, "Default", "group 0 name = Default")
    IF h <= 3 THEN CALL DrawIcl_CloseIcoLib(h)
END SUB

' ---------------------------------------------------------------------------
' GetLibIconGroupName out-of-range index returns empty string
' ---------------------------------------------------------------------------
SUB Test_GetLibIconGroupName_OutOfRange
    CALL Test_Case("GetLibIconGroupName returns empty string for out-of-range index")
    DIM h AS BYTE
    DIM s AS STRING
    CALL MakeMzLib("T.ICL")
    h = DrawIcl_LoadIcoLib("T.ICL")
    s = DrawIcl_GetLibIconGroupName$(h, 99)
    CALL Assert_IsEmpty(s, "group 99 name = empty")
    IF h <= 3 THEN CALL DrawIcl_CloseIcoLib(h)
END SUB

' ---------------------------------------------------------------------------
' GetLibIconGroupName for invalid handle returns empty string
' ---------------------------------------------------------------------------
SUB Test_GetLibIconGroupName_InvalidHandle
    CALL Test_Case("GetLibIconGroupName returns empty string for invalid handle")
    DIM s AS STRING
    s = DrawIcl_GetLibIconGroupName$(255, 0)
    CALL Assert_IsEmpty(s, "name = empty for handle 255")
END SUB

' ---------------------------------------------------------------------------
' GetLibInfo: returns file name, isPE flag and group count
' ---------------------------------------------------------------------------
SUB Test_GetLibInfo_NonPE
    CALL Test_Case("GetLibInfo returns file name, isPE=0, groupCount=1 for 16-bit MZ")
    DIM h AS BYTE
    DIM libFn AS STRING, isPE AS BYTE, gc AS WORD, ok AS BYTE
    CALL MakeMzLib("T.ICL")
    h = DrawIcl_LoadIcoLib("T.ICL")
    ok = DrawIcl_GetLibInfo(h, libFn, isPE, gc)
    CALL Assert_IsEqual(ok, 1, "GetLibInfo returns 1")
    CALL Assert_AreEqualStr(libFn, "T.ICL", "filename = T.ICL")
    CALL Assert_IsZero(isPE, "isPE = 0 for non-PE MZ")
    CALL Assert_IsEqual(gc, 1, "groupCount = 1")
    IF h <= 3 THEN CALL DrawIcl_CloseIcoLib(h)
END SUB

' ---------------------------------------------------------------------------
' GetLibInfo for invalid handle returns failure
' ---------------------------------------------------------------------------
SUB Test_GetLibInfo_InvalidHandle
    CALL Test_Case("GetLibInfo returns 0 and blanks for invalid handle 255")
    DIM libFn2 AS STRING, isPE2 AS BYTE, gc2 AS WORD, ok2 AS BYTE
    ok2 = DrawIcl_GetLibInfo(255, libFn2, isPE2, gc2)
    CALL Assert_IsZero(ok2, "GetLibInfo returns 0 for invalid handle")
    CALL Assert_IsEmpty(libFn2, "filename empty for invalid handle")
    CALL Assert_IsZero(gc2, "groupCount = 0 for invalid handle")
END SUB

' ---------------------------------------------------------------------------
' CloseIcoLib: after close, IsLoaded=0 -> GetLibIconGroupCount returns 0
' ---------------------------------------------------------------------------
SUB Test_CloseIcoLib_MarksUnloaded
    CALL Test_Case("CloseIcoLib marks library unloaded so count returns 0 afterwards")
    DIM h AS BYTE
    CALL MakeMzLib("T.ICL")
    h = DrawIcl_LoadIcoLib("T.ICL")
    CALL DrawIcl_CloseIcoLib(h)
    CALL Assert_IsZero(DrawIcl_GetLibIconGroupCount(h), "count = 0 after close")
END SUB

' ---------------------------------------------------------------------------
' CloseIcoLib with out-of-range handle (255) must not crash
' ---------------------------------------------------------------------------
SUB Test_CloseIcoLib_InvalidHandle_NoCrash
    CALL Test_Case("CloseIcoLib with handle 255 does not crash")
    CALL DrawIcl_CloseIcoLib(255)
    CALL Assert_IsTrue(1, "no crash on CloseIcoLib(255)")
END SUB

' ---------------------------------------------------------------------------
' GetLibIconGroupCount with unloaded slot
' ---------------------------------------------------------------------------
SUB Test_GetLibIconGroupCount_UnloadedSlot
    CALL Test_Case("GetLibIconGroupCount returns 0 for unloaded slot")
    ' Slot 0 must be unloaded at the start of this isolated case
    ' (Test_Setup/Teardown do NOT reset SHARED state, so close first if open)
    IF ICOLIBContexts(0).IsLoaded <> 0 THEN CALL DrawIcl_CloseIcoLib(0)
    DIM cnt AS WORD
    cnt = DrawIcl_GetLibIconGroupCount(0)
    CALL Assert_IsZero(cnt, "count = 0 for freshly-unloaded slot 0")
END SUB

' ---------------------------------------------------------------------------
' Multiple libraries: two open at same time use different handles
' ---------------------------------------------------------------------------
SUB Test_LoadIcoLib_TwoLibsIndependent
    CALL Test_Case("Two simultaneously open libraries get distinct handles")
    DIM h1 AS BYTE, h2 AS BYTE
    CALL MakeMzLib("T1.ICL")
    CALL MakeMzLib("T2.ICL")
    h1 = DrawIcl_LoadIcoLib("T1.ICL")
    h2 = DrawIcl_LoadIcoLib("T2.ICL")
    CALL Assert_IsTrue(h1 <= 3, "h1 in range 0-3")
    CALL Assert_IsTrue(h2 <= 3, "h2 in range 0-3")
    CALL Assert_IsTrue(h1 <> h2, "h1 and h2 are distinct")
    IF h1 <= 3 THEN CALL DrawIcl_CloseIcoLib(h1)
    IF h2 <= 3 THEN CALL DrawIcl_CloseIcoLib(h2)
END SUB

' ---------------------------------------------------------------------------
' Four libraries fill all slots; fifth returns 255
' ---------------------------------------------------------------------------
SUB Test_LoadIcoLib_FourSlotsFull_Returns255
    CALL Test_Case("LoadIcoLib returns 255 when all 4 slots are occupied")
    DIM ha AS BYTE, hb AS BYTE, hc AS BYTE, hd AS BYTE, he AS BYTE
    ' Ensure all slots start clean
    CALL DrawIcl_CloseIcoLib(0)
    CALL DrawIcl_CloseIcoLib(1)
    CALL DrawIcl_CloseIcoLib(2)
    CALL DrawIcl_CloseIcoLib(3)
    CALL MakeMzLib("T.ICL")
    ha = DrawIcl_LoadIcoLib("T.ICL")
    hb = DrawIcl_LoadIcoLib("T.ICL")
    hc = DrawIcl_LoadIcoLib("T.ICL")
    hd = DrawIcl_LoadIcoLib("T.ICL")
    he = DrawIcl_LoadIcoLib("T.ICL")
    CALL Assert_IsEqual(he, 255, "fifth load returns 255 when all slots full")
    CALL DrawIcl_CloseIcoLib(ha)
    CALL DrawIcl_CloseIcoLib(hb)
    CALL DrawIcl_CloseIcoLib(hc)
    CALL DrawIcl_CloseIcoLib(hd)
END SUB

' ---------------------------------------------------------------------------
' DrawIcl_Show: no crash for valid MZ file (pixel at 10,10 may be 0 or 255)
' ---------------------------------------------------------------------------
SUB Test_Show_NoCrash_ValidFile
    CALL Test_Case("DrawIcl_Show does not crash for a valid MZ file")
    CALL MakeMzLib("T.ICL")
    CALL DrawIcl_Show("T.ICL", 10, 10)
    CALL Assert_IsTrue(1, "DrawIcl_Show returned without crash")
END SUB

' ---------------------------------------------------------------------------
' DrawIcl_Show: no crash for missing file
' ---------------------------------------------------------------------------
SUB Test_Show_NoCrash_MissingFile
    CALL Test_Case("DrawIcl_Show does nothing for a non-existent file")
    CALL DrawIcl_Show("NOFILE.ICL", 0, 0)
    CALL Assert_IsTrue(1, "no crash on Show with missing file")
END SUB

' ---------------------------------------------------------------------------
' DrawIcl_GetSize: always returns 32x32 (documented default)
' ---------------------------------------------------------------------------
SUB Test_GetSize_Returns32x32
    CALL Test_Case("DrawIcl_GetSize returns width=32 height=32")
    DIM w AS WORD, h AS WORD
    CALL DrawIcl_GetSize("ANY.ICL", w, h)
    CALL Assert_IsEqual(w, 32, "width = 32")
    CALL Assert_IsEqual(h, 32, "height = 32")
END SUB

' ---------------------------------------------------------------------------
' DrawIcl_GetPalette: returns 1 and fills grayscale palette
' ---------------------------------------------------------------------------
SUB Test_GetPalette_GrayscaleInit
    CALL Test_Case("DrawIcl_GetPalette returns 1 and fills grayscale identity palette")
    DIM pal(767) AS BYTE
    DIM ok AS BYTE
    ok = DrawIcl_GetPalette("ANY.ICL", pal(), 8)
    CALL Assert_IsEqual(ok, 1, "GetPalette returns 1")
    CALL Assert_IsEqual(pal(0),       0,   "palette[0].R = 0")
    CALL Assert_IsEqual(pal(10 * 3), 10,   "palette[10].R = 10")
    CALL Assert_IsEqual(pal(255 * 3), 255, "palette[255].R = 255")
END SUB

' ---------------------------------------------------------------------------
' DrawIcl_ExtractAllIcons: returns 1 for a loaded library (SaveLibIcon stub = 1)
' ---------------------------------------------------------------------------
SUB Test_ExtractAllIcons_NonPE
    CALL Test_Case("ExtractAllIcons returns groupCount for a loaded 16-bit MZ library")
    DIM h AS BYTE
    DIM extracted AS WORD
    CALL MakeMzLib("T.ICL")
    h = DrawIcl_LoadIcoLib("T.ICL")
    extracted = DrawIcl_ExtractAllIcons(h, ".")
    CALL Assert_IsEqual(extracted, 1, "extracted = 1 (one group)")
    IF h <= 3 THEN CALL DrawIcl_CloseIcoLib(h)
END SUB

' ---------------------------------------------------------------------------
' DrawIcl_ExtractAllIcons: invalid handle returns 0
' ---------------------------------------------------------------------------
SUB Test_ExtractAllIcons_InvalidHandle
    CALL Test_Case("ExtractAllIcons returns 0 for invalid handle")
    DIM extracted AS WORD
    extracted = DrawIcl_ExtractAllIcons(255, ".")
    CALL Assert_IsZero(extracted, "extracted = 0 for invalid handle")
END SUB
