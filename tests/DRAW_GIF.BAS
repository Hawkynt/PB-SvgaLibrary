' =============================================================================
' DRAW_GIF.BAS - tests for DRAW_GIF.SUB (GIF87a/GIF89a with LZW decompression)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "FILEUTIL.SUB"
DECLARE FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
$INCLUDE "DRAW_GIF.SUB"

' --- Stubs ---
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

' --- Read a screen pixel via Vga_GetPixel ---
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Vga_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

' --- Build a minimal 2x2 GIF87a fixture file ---
' Structure:
'   signature   "GIF87a"         6 bytes
'   screen desc width=2, ht=2, packed=0x81 (GCT present, 4 colors), bg=0, asp=0  7 bytes
'   global CT   4 x RGB = 12 bytes
'     index 0 = red   (255, 0, 0)
'     index 1 = green (0, 255, 0)
'     index 2 = blue  (0, 0, 255)
'     index 3 = white (255,255,255)
'   image desc  0x2C, left=0, top=0, w=2, h=2, packed=0   10 bytes
'   LZW min code size = 3                                    1 byte
'   sub-block   len=3, bytes: 0x08 0x21 0x93               4 bytes (3 + terminator 0x00)
'   trailer     0x3B                                         1 byte
' LZW codes (4-bit each, minCodeSize=3, ClearCode=8, EndCode=9, initial codeSize=4):
'   clear(8), 0, 1, 2, 3, end(9)  -- all at 4 bits, no code-size increase (NextCode max=13 < MaxCode=15)
' Resulting pixel order (row-major, top-left first): 0, 1, 2, 3
SUB MakeGif87
    DIM gifData AS STRING
    gifData = CHR$(71)+CHR$(73)+CHR$(70)+CHR$(56)+CHR$(55)+CHR$(97)+CHR$(2) _
             +CHR$(0)+CHR$(2)+CHR$(0)+CHR$(129)+CHR$(0)+CHR$(0)+CHR$(255) _
             +CHR$(0)+CHR$(0)+CHR$(0)+CHR$(255)+CHR$(0)+CHR$(0)+CHR$(0) _
             +CHR$(255)+CHR$(255)+CHR$(255)+CHR$(255)+CHR$(44)+CHR$(0) _
             +CHR$(0)+CHR$(0)+CHR$(0)+CHR$(2)+CHR$(0)+CHR$(2)+CHR$(0) _
             +CHR$(0)+CHR$(3)+CHR$(3)+CHR$(8)+CHR$(33)+CHR$(147)+CHR$(0) _
             +CHR$(59)
    OPEN "T.GIF" FOR BINARY AS #1
    PUT$ #1, gifData
    CLOSE #1
END SUB

' --- Build a minimal 2x2 GIF89a fixture (same image, version byte = "89a") ---
SUB MakeGif89
    DIM gifData AS STRING
    gifData = CHR$(71)+CHR$(73)+CHR$(70)+CHR$(56)+CHR$(57)+CHR$(97)+CHR$(2) _
             +CHR$(0)+CHR$(2)+CHR$(0)+CHR$(129)+CHR$(0)+CHR$(0)+CHR$(255) _
             +CHR$(0)+CHR$(0)+CHR$(0)+CHR$(255)+CHR$(0)+CHR$(0)+CHR$(0) _
             +CHR$(255)+CHR$(255)+CHR$(255)+CHR$(255)+CHR$(44)+CHR$(0) _
             +CHR$(0)+CHR$(0)+CHR$(0)+CHR$(2)+CHR$(0)+CHR$(2)+CHR$(0) _
             +CHR$(0)+CHR$(3)+CHR$(3)+CHR$(8)+CHR$(33)+CHR$(147)+CHR$(0) _
             +CHR$(59)
    OPEN "T89.GIF" FOR BINARY AS #1
    PUT$ #1, gifData
    CLOSE #1
END SUB

' --- Build a file with bad signature (>= 13 bytes but first 3 bytes != "GIF") ---
SUB MakeBadSig
    DIM badData AS STRING
    badData = CHR$(66)+CHR$(65)+CHR$(68)+CHR$(83)+CHR$(73)+CHR$(71) _
             +CHR$(0)+CHR$(0)+CHR$(0)+CHR$(0)+CHR$(0)+CHR$(0)+CHR$(0)
    OPEN "TBAD.GIF" FOR BINARY AS #1
    PUT$ #1, badData
    CLOSE #1
END SUB

' --- Build a too-short file (< 13 bytes) ---
SUB MakeTooShort
    DIM shortData AS STRING
    shortData = CHR$(71)+CHR$(73)+CHR$(70)+CHR$(56)+CHR$(55)+CHR$(97)
    OPEN "TSHORT.GIF" FOR BINARY AS #1
    PUT$ #1, shortData
    CLOSE #1
END SUB

' =============================================================================
' Test: GetSize parses width and height from GIF87a header
' Given a valid 2x2 GIF87a file
' When  DrawGif_GetSize is called
' Then  widthVal=2 and height=2 are returned, function returns 1
' =============================================================================
SUB Test_GetSize_GIF87a
    CALL Test_Case("GetSize reads width and height from GIF87a")
    DIM w AS WORD, h AS WORD, ok AS BYTE
    CALL MakeGif87
    ok = DrawGif_GetSize("T.GIF", w, h)
    CALL Assert_IsEqual(ok, 1, "GetSize returns success")
    CALL Assert_IsEqual(w, 2, "width = 2")
    CALL Assert_IsEqual(h, 2, "height = 2")
END SUB

' =============================================================================
' Test: GetSize parses width and height from GIF89a header
' Given a valid 2x2 GIF89a file
' When  DrawGif_GetSize is called
' Then  widthVal=2 and height=2 are returned, function returns 1
' =============================================================================
SUB Test_GetSize_GIF89a
    CALL Test_Case("GetSize reads width and height from GIF89a")
    DIM w AS WORD, h AS WORD, ok AS BYTE
    CALL MakeGif89
    ok = DrawGif_GetSize("T89.GIF", w, h)
    CALL Assert_IsEqual(ok, 1, "GetSize89 returns success")
    CALL Assert_IsEqual(w, 2, "GIF89a width = 2")
    CALL Assert_IsEqual(h, 2, "GIF89a height = 2")
END SUB

' =============================================================================
' Test: ParseFile rejects a bad signature
' Given a file whose first 3 bytes are not "GIF"
' When  DrawGif_ParseFile is called
' Then  it returns 0 (failure)
' =============================================================================
SUB Test_ParseFile_BadSignature
    CALL Test_Case("ParseFile rejects bad signature")
    DIM fh AS INTEGER, ctx AS GIFContextType, ok AS BYTE
    CALL MakeBadSig
    fh = FREEFILE
    OPEN "TBAD.GIF" FOR BINARY ACCESS READ AS fh
    ok = DrawGif_ParseFile(fh, ctx)
    CLOSE fh
    CALL Assert_IsEqual(ok, 0, "ParseFile returns 0 for bad sig")
    CALL Assert_IsEqual(ctx.IsLoaded, 0, "IsLoaded = 0 for bad sig")
END SUB

' =============================================================================
' Test: GetSize rejects a too-short file
' Given a file shorter than 13 bytes
' When  DrawGif_GetSize is called
' Then  it returns 0 (failure) and width/height stay 0
' =============================================================================
SUB Test_GetSize_TooShort
    CALL Test_Case("GetSize returns 0 for file shorter than 13 bytes")
    DIM w AS WORD, h AS WORD, ok AS BYTE
    CALL MakeTooShort
    ok = DrawGif_GetSize("TSHORT.GIF", w, h)
    CALL Assert_IsEqual(ok, 0, "GetSize returns 0 for short file")
    CALL Assert_IsEqual(w, 0, "width stays 0")
    CALL Assert_IsEqual(h, 0, "height stays 0")
END SUB

' =============================================================================
' Test: ParseFile populates the global colour table from a GIF87a file
' Given a valid 2x2 GIF87a with a 4-entry global CT
' When  DrawGif_ParseFile is called
' Then  context flags are set and GIFGlobalPaletteStore holds the expected RGB triples
' NOTE: GlobalColorTable is set by (packed AND &H80) <> 0 which returns -1 (INTEGER)
'       truncated to BYTE = 255; we test IsNotZero rather than IsEqual to 1
' =============================================================================
SUB Test_ParseFile_GlobalColorTable
    CALL Test_Case("ParseFile loads global colour table into GIFGlobalPaletteStore")
    DIM fh AS INTEGER, ctx AS GIFContextType, ok AS BYTE
    CALL MakeGif87
    fh = FREEFILE
    OPEN "T.GIF" FOR BINARY ACCESS READ AS fh
    ok = DrawGif_ParseFile(fh, ctx)
    CLOSE fh
    CALL Assert_IsEqual(ok, 1, "ParseFile succeeds")
    CALL Assert_IsNotZero(ctx.GlobalColorTable, "GlobalColorTable flag is non-zero")
    CALL Assert_IsEqual(ctx.GlobalColorTableSize, 4, "4 colour entries")
    ' index 0 = red (255,0,0)
    CALL Assert_IsEqual(GIFGlobalPaletteStore(0), 255, "CT[0].R = 255")
    CALL Assert_IsEqual(GIFGlobalPaletteStore(1), 0,   "CT[0].G = 0")
    CALL Assert_IsEqual(GIFGlobalPaletteStore(2), 0,   "CT[0].B = 0")
    ' index 1 = green (0,255,0)
    CALL Assert_IsEqual(GIFGlobalPaletteStore(3), 0,   "CT[1].R = 0")
    CALL Assert_IsEqual(GIFGlobalPaletteStore(4), 255, "CT[1].G = 255")
    CALL Assert_IsEqual(GIFGlobalPaletteStore(5), 0,   "CT[1].B = 0")
    ' index 2 = blue (0,0,255)
    CALL Assert_IsEqual(GIFGlobalPaletteStore(6), 0,   "CT[2].R = 0")
    CALL Assert_IsEqual(GIFGlobalPaletteStore(7), 0,   "CT[2].G = 0")
    CALL Assert_IsEqual(GIFGlobalPaletteStore(8), 255, "CT[2].B = 255")
    ' index 3 = white (255,255,255)
    CALL Assert_IsEqual(GIFGlobalPaletteStore(9),  255, "CT[3].R = 255")
    CALL Assert_IsEqual(GIFGlobalPaletteStore(10), 255, "CT[3].G = 255")
    CALL Assert_IsEqual(GIFGlobalPaletteStore(11), 255, "CT[3].B = 255")
END SUB

' =============================================================================
' Test: ParseFile stores GIF version string correctly
' Given a valid GIF87a
' When  DrawGif_ParseFile is called
' Then  GIFVersionStore = "87a"
' =============================================================================
SUB Test_ParseFile_VersionString
    CALL Test_Case("ParseFile stores GIF version string")
    DIM fh AS INTEGER, ctx AS GIFContextType
    CALL MakeGif87
    fh = FREEFILE
    OPEN "T.GIF" FOR BINARY ACCESS READ AS fh
    CALL DrawGif_ParseFile(fh, ctx)
    CLOSE fh
    CALL Assert_AreEqualStr(GIFVersionStore, "87a", "version = 87a")
END SUB

' =============================================================================
' Test: ParseFile accepts GIF89a and stores "89a"
' =============================================================================
SUB Test_ParseFile_Version89a
    CALL Test_Case("ParseFile accepts GIF89a and stores version 89a")
    DIM fh AS INTEGER, ctx AS GIFContextType
    CALL MakeGif89
    fh = FREEFILE
    OPEN "T89.GIF" FOR BINARY ACCESS READ AS fh
    CALL DrawGif_ParseFile(fh, ctx)
    CLOSE fh
    CALL Assert_AreEqualStr(GIFVersionStore, "89a", "version = 89a")
END SUB

' =============================================================================
' Test: GetPalette extracts GIF global colour table into a flat palette array
' Given a valid 2x2 GIF87a
' When  DrawGif_GetPalette is called
' Then  paletteV(0..11) holds expected RGB bytes
' =============================================================================
SUB Test_GetPalette
    CALL Test_Case("GetPalette copies global colour table into output array")
    DIM pal(767) AS BYTE, ok AS BYTE
    CALL MakeGif87
    ok = DrawGif_GetPalette("T.GIF", pal(), 8)
    CALL Assert_IsEqual(ok, 1, "GetPalette returns 1")
    CALL Assert_IsEqual(pal(0), 255, "pal[0].R = 255")
    CALL Assert_IsEqual(pal(1), 0,   "pal[0].G = 0")
    CALL Assert_IsEqual(pal(2), 0,   "pal[0].B = 0")
    CALL Assert_IsEqual(pal(9),  255, "pal[3].R = 255")
    CALL Assert_IsEqual(pal(10), 255, "pal[3].G = 255")
    CALL Assert_IsEqual(pal(11), 255, "pal[3].B = 255")
END SUB

' =============================================================================
' Test: GetPalette fails for a too-short file
' =============================================================================
SUB Test_GetPalette_TooShort
    CALL Test_Case("GetPalette returns 0 for too-short file")
    DIM pal(767) AS BYTE, ok AS BYTE
    CALL MakeTooShort
    ok = DrawGif_GetPalette("TSHORT.GIF", pal(), 8)
    CALL Assert_IsEqual(ok, 0, "GetPalette returns 0 for short file")
END SUB

' =============================================================================
' Test: LZW decompression produces correct pixel sequence
' Given a stream for minCodeSize=3 (ClearCode=8, EndCode=9, CodeSize=4):
'   bytes: CHR$(8)+CHR$(33)+CHR$(147)
'   4-bit codes: 8(clear), 0, 1, 2, 3, 9(end)
' When  DrawGif_DecompressLZW is called with minimumCodeSize=3
' Then  decodedData = CHR$(0)+CHR$(1)+CHR$(2)+CHR$(3)
' =============================================================================
SUB Test_DecompressLZW_FourPixels
    CALL Test_Case("DecompressLZW decodes clear+4 literal codes+end correctly")
    DIM compressed AS STRING
    DIM decoded AS STRING
    compressed = CHR$(8)+CHR$(33)+CHR$(147)
    CALL DrawGif_DecompressLZW(compressed, 3, decoded)
    CALL Assert_IsEqual(LEN(decoded), 4, "decoded length = 4")
    CALL Assert_IsEqual(ASC(MID$(decoded,1,1)), 0, "pixel[0] = 0")
    CALL Assert_IsEqual(ASC(MID$(decoded,2,1)), 1, "pixel[1] = 1")
    CALL Assert_IsEqual(ASC(MID$(decoded,3,1)), 2, "pixel[2] = 2")
    CALL Assert_IsEqual(ASC(MID$(decoded,4,1)), 3, "pixel[3] = 3")
END SUB

' =============================================================================
' Test: DecompressLZW handles empty input without crashing
' Boundary: empty compressed string; loop runs once (bitPos=0 <= 0*8=0) and reads
' code 0 from beyond-end (returns 0), which is a literal pixel index -- 1 byte out.
' We test that it does not crash and returns a defined (short) result.
' =============================================================================
SUB Test_DecompressLZW_Empty
    CALL Test_Case("DecompressLZW handles empty input without crashing")
    DIM decoded AS STRING
    CALL DrawGif_DecompressLZW("", 2, decoded)
    CALL Assert_IsTrue(LEN(decoded) <= 1, "decoded is at most 1 byte for empty input")
END SUB

' =============================================================================
' Test: DrawGif_Show renders 2x2 image at given position with correct indices
' Given a valid 2x2 GIF87a (minCodeSize=3; pixels 0,1,2,3 top-left, top-right, bot-left, bot-right)
' When  DrawGif_Show("T.GIF", 10, 20) is called
' Then  screen pixels at (10,20)=0, (11,20)=1, (10,21)=2, (11,21)=3
' Pixel values are colour indices
' =============================================================================
SUB Test_Show_PixelIndices
    CALL Test_Case("Show renders correct palette indices for 2x2 GIF87a")
    CALL MakeGif87
    CALL DrawGif_Show("T.GIF", 10, 20)
    CALL Assert_IsEqual(GetP(10, 20), 0, "pixel(0,0) = index 0")
    CALL Assert_IsEqual(GetP(11, 20), 1, "pixel(1,0) = index 1")
    CALL Assert_IsEqual(GetP(10, 21), 2, "pixel(0,1) = index 2")
    CALL Assert_IsEqual(GetP(11, 21), 3, "pixel(1,1) = index 3")
END SUB

' =============================================================================
' Test: DrawGif_Show renders GIF89a image
' =============================================================================
SUB Test_Show_GIF89a
    CALL Test_Case("Show renders correct palette indices for 2x2 GIF89a")
    CALL MakeGif89
    CALL DrawGif_Show("T89.GIF", 50, 60)
    CALL Assert_IsEqual(GetP(50, 60), 0, "GIF89a pixel(0,0) = index 0")
    CALL Assert_IsEqual(GetP(51, 61), 3, "GIF89a pixel(1,1) = index 3")
END SUB

' =============================================================================
' Test: DrawGif_Show silently ignores a bad-signature file
' =============================================================================
SUB Test_Show_BadSig_NoOp
    CALL Test_Case("Show is a no-op for bad-signature file")
    DIM px AS INTEGER
    CALL MakeBadSig
    CALL Vga_PutPixel(0, 0, 42)
    CALL DrawGif_Show("TBAD.GIF", 0, 0)
    px = GetP(0, 0)
    CALL Assert_IsEqual(px, 42, "bad-sig show leaves screen unchanged")
END SUB

' =============================================================================
' MakeGifMinCode2: 2x2 GIF87a with minCodeSize=2 (different from existing tests)
'
' Global CT: 4 colours
' minCodeSize = 2  -> ClearCode=4, EndCode=5, initial codeSize=3, MaxCode=7
' Proper LZW encoding for pixels [0,1,2,3]:
'   At codeSize=3: emit clear(4), code0(0), code1(1)  [after code1: NextCode=8>7, bump to codeSize=4]
'   At codeSize=4: emit code2(2), code3(3), end(5)
' Bytes: 0x44 0x64 0x0A
' Pixels decoded: 0,1,2,3
' =============================================================================
SUB MakeGifMinCode2
    DIM gifData AS STRING
    ' "GIF87a" 6 bytes
    gifData = CHR$(71) + CHR$(73) + CHR$(70) + CHR$(56) + CHR$(55) + CHR$(97)
    ' Screen descriptor: w=2 h=2 packed=0x81 bg=0 asp=0
    gifData = gifData + CHR$(2) + CHR$(0) + CHR$(2) + CHR$(0) + CHR$(129) + CHR$(0) + CHR$(0)
    ' Global CT: 4 RGB triples (R,G,B order in file)
    gifData = gifData + CHR$(255) + CHR$(0)   + CHR$(0)    ' index 0 red
    gifData = gifData + CHR$(0)   + CHR$(255) + CHR$(0)    ' index 1 green
    gifData = gifData + CHR$(0)   + CHR$(0)   + CHR$(255)  ' index 2 blue
    gifData = gifData + CHR$(255) + CHR$(255) + CHR$(255)  ' index 3 white
    ' Image descriptor: 0x2C left=0 top=0 w=2 h=2 packed=0
    gifData = gifData + CHR$(44) + CHR$(0) + CHR$(0) + CHR$(0) + CHR$(0)
    gifData = gifData + CHR$(2) + CHR$(0) + CHR$(2) + CHR$(0) + CHR$(0)
    ' LZW min code size = 2
    gifData = gifData + CHR$(2)
    ' Sub-block: size=3, data=0x44,0x64,0x0A, then terminator 0x00
    gifData = gifData + CHR$(3) + CHR$(&H44) + CHR$(&H64) + CHR$(&H0A) + CHR$(0)
    ' Trailer
    gifData = gifData + CHR$(59)
    OPEN "TMC2.GIF" FOR BINARY AS #1
    PUT$ #1, gifData
    CLOSE #1
END SUB

' =============================================================================
' MakeGif89aGCE: GIF89a with a Graphic Control Extension before the image block.
'
' GCE block (0x21 0xF9): label=0xF9, blockSize=4, packed=0x00,
'                         delayLow=0x0A, delayHigh=0x00, transparentIdx=0x00,
'                         block terminator=0x00
' This is followed by the normal 2x2 image (same LZW as MakeGif89).
' The extension parser must consume the GCE and then find the image block.
' =============================================================================
SUB MakeGif89aGCE
    DIM gifData AS STRING
    ' "GIF89a" header + screen descriptor + global CT (same as MakeGif89)
    gifData = CHR$(71) + CHR$(73) + CHR$(70) + CHR$(56) + CHR$(57) + CHR$(97)
    gifData = gifData + CHR$(2) + CHR$(0) + CHR$(2) + CHR$(0) + CHR$(129) + CHR$(0) + CHR$(0)
    gifData = gifData + CHR$(255) + CHR$(0)   + CHR$(0)
    gifData = gifData + CHR$(0)   + CHR$(255) + CHR$(0)
    gifData = gifData + CHR$(0)   + CHR$(0)   + CHR$(255)
    gifData = gifData + CHR$(255) + CHR$(255) + CHR$(255)
    ' GCE block: 0x21 (extension) 0xF9 (graphic control) size=4 packed=0 delayLo=10 delayHi=0 transpIdx=0 terminator=0
    gifData = gifData + CHR$(&H21) + CHR$(&HF9)
    gifData = gifData + CHR$(4) + CHR$(0) + CHR$(10) + CHR$(0) + CHR$(0) + CHR$(0)
    ' Image block (same LZW as MakeGif89: minCodeSize=3 -> bytes 0x08,0x21,0x93)
    gifData = gifData + CHR$(44) + CHR$(0) + CHR$(0) + CHR$(0) + CHR$(0)
    gifData = gifData + CHR$(2) + CHR$(0) + CHR$(2) + CHR$(0) + CHR$(0)
    gifData = gifData + CHR$(3)
    gifData = gifData + CHR$(3) + CHR$(8) + CHR$(33) + CHR$(147) + CHR$(0)
    gifData = gifData + CHR$(59)
    OPEN "TGCE.GIF" FOR BINARY AS #1
    PUT$ #1, gifData
    CLOSE #1
END SUB

' =============================================================================
' Test_DecompressLZW_MinCodeSize2: use minCodeSize=2 (different from existing tests)
' ClearCode=4, EndCode=5, initial codeSize=3, MaxCode=7
' Proper encoding for pixels [0,1,2,3]:
'   codeSize=3: clear(4), code0(0), code1(1)  -> after code1: NextCode=8>7, bump to codeSize=4
'   codeSize=4: code2(2), code3(3), end(5)
' Stream bytes: 0x44, 0x64, 0x0A
' =============================================================================
SUB Test_DecompressLZW_MinCodeSize2
    CALL Test_Case("DecompressLZW with minCodeSize=2 (code-size bumps 3->4 mid-stream) decodes 4 pixels")
    DIM compressed AS STRING, decoded AS STRING
    compressed = CHR$(&H44) + CHR$(&H64) + CHR$(&H0A)
    CALL DrawGif_DecompressLZW(compressed, 2, decoded)
    CALL Assert_IsEqual(LEN(decoded), 4, "minCS2 decoded length = 4")
    CALL Assert_IsEqual(ASC(MID$(decoded, 1, 1)), 0, "minCS2 pixel[0] = 0")
    CALL Assert_IsEqual(ASC(MID$(decoded, 2, 1)), 1, "minCS2 pixel[1] = 1")
    CALL Assert_IsEqual(ASC(MID$(decoded, 3, 1)), 2, "minCS2 pixel[2] = 2")
    CALL Assert_IsEqual(ASC(MID$(decoded, 4, 1)), 3, "minCS2 pixel[3] = 3")
END SUB

' =============================================================================
' Test_Show_MinCodeSize2: full round-trip with minCodeSize=2 GIF
' =============================================================================
SUB Test_Show_MinCodeSize2
    CALL Test_Case("Show renders correct pixels for GIF with minCodeSize=2")
    CALL MakeGifMinCode2
    CALL DrawGif_Show("TMC2.GIF", 30, 40)
    CALL Assert_IsEqual(GetP(30, 40), 0, "minCS2: pixel(0,0) = 0")
    CALL Assert_IsEqual(GetP(31, 40), 1, "minCS2: pixel(1,0) = 1")
    CALL Assert_IsEqual(GetP(30, 41), 2, "minCS2: pixel(0,1) = 2")
    CALL Assert_IsEqual(GetP(31, 41), 3, "minCS2: pixel(1,1) = 3")
END SUB

' =============================================================================
' Test_Show_GCE_ExtensionSkipped: a GIF89a with a Graphic Control Extension
' block (0x21 0xF9) before the image must still render the image correctly.
' =============================================================================
SUB Test_Show_GCE_ExtensionSkipped
    CALL Test_Case("Show correctly renders image after skipping GCE extension block")
    CALL MakeGif89aGCE
    CALL DrawGif_Show("TGCE.GIF", 60, 70)
    CALL Assert_IsEqual(GetP(60, 70), 0, "GCE-skip: pixel(0,0) = 0")
    CALL Assert_IsEqual(GetP(61, 70), 1, "GCE-skip: pixel(1,0) = 1")
    CALL Assert_IsEqual(GetP(60, 71), 2, "GCE-skip: pixel(0,1) = 2")
    CALL Assert_IsEqual(GetP(61, 71), 3, "GCE-skip: pixel(1,1) = 3")
END SUB

' =============================================================================
' Test_ParseFile_GCE_PopulatesContext: after parsing a file with a GCE block,
' gifContext fields set by ProcessExtension (DelayTime, HasTransparentColor) are
' tested via DrawGif_ParseFile on the header portion.  We test that ParseFile
' returns 1 (success) for the GCE file.
' =============================================================================
SUB Test_ParseFile_GCE_ContextSet
    CALL Test_Case("ParseFile returns success for GIF89a file containing a GCE extension")
    CALL MakeGif89aGCE
    DIM fh AS INTEGER, ctx AS GIFContextType, ok AS BYTE
    fh = FREEFILE
    OPEN "TGCE.GIF" FOR BINARY ACCESS READ AS fh
    ok = DrawGif_ParseFile(fh, ctx)
    CLOSE fh
    CALL Assert_IsEqual(ok, 1, "ParseFile returns 1 for GCE file")
    CALL Assert_IsNotZero(ctx.GlobalColorTable, "GlobalColorTable set for GCE file")
END SUB

' --- Mode 13h setup / teardown ---
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
