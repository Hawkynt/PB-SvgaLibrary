' =============================================================================
' DRAW_TIF.BAS - tests for DRAW_TIF.SUB (TIFF image loader)
' Covers: uncompressed 8-bit grayscale TIFF, PackBits decompressor,
'         GetSize / GetInfo / GetPalette helpers, and error cases.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"
$INCLUDE "FILEUTIL.SUB"
DECLARE FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
$INCLUDE "DRAW_TIF.SUB"

' --- stubs required by the module under test --------------------------------
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

' --- helpers ----------------------------------------------------------------
FUNCTION LE16(BYVAL v AS WORD) AS STRING
    LE16 = CHR$(v AND 255) + CHR$((v \ 256) AND 255)
END FUNCTION
FUNCTION LE32(BYVAL v AS LONG) AS STRING
    LE32 = CHR$(v AND 255) + CHR$((v \ 256) AND 255) + _
           CHR$((v \ 65536) AND 255) + CHR$((v \ 16777216) AND 255)
END FUNCTION

' Build one 12-byte IFD directory entry
FUNCTION TifEntry(BYVAL tag AS WORD, BYVAL typ AS WORD, BYVAL cnt AS LONG, BYVAL valOf AS LONG) AS STRING
    TifEntry = LE16(tag) + LE16(typ) + LE32(cnt) + LE32(valOf)
END FUNCTION

' ---------------------------------------------------------------------------
' Build a minimal little-endian TIFF and write it to fileName.
' Format: 4x4 pixels, 8-bit grayscale, uncompressed, single strip.
' Pixel at (col, row) = row*4 + col  (values 0..15).
' IFD offset = 8.  Pixel data starts at offset 110 (= 8 + 2 + 8*12 + 4).
' ---------------------------------------------------------------------------
SUB MakeTifGray4x4(BYVAL fileName AS STRING)
    DIM hdr AS STRING, ifd AS STRING, pix AS STRING
    DIM r AS INTEGER, c AS INTEGER
    ' TIFF header: "II" (0x4949) = CHR$(73)+CHR$(73) + version 42 + IFD offset 8
    hdr = CHR$(73) + CHR$(73) + LE16(42) + LE32(8)
    ' IFD: 8 entries
    ifd = LE16(8)
    ifd = ifd + TifEntry(256, 3, 1, 4)     ' ImageWidth = 4
    ifd = ifd + TifEntry(257, 3, 1, 4)     ' ImageLength = 4
    ifd = ifd + TifEntry(258, 3, 1, 8)     ' BitsPerSample = 8
    ifd = ifd + TifEntry(259, 3, 1, 1)     ' Compression = 1 (none)
    ifd = ifd + TifEntry(262, 3, 1, 1)     ' PhotometricInterp = 1
    ifd = ifd + TifEntry(273, 4, 1, 110)   ' StripOffsets = 110 (pixel data at 0-based 110)
    ifd = ifd + TifEntry(278, 3, 1, 4)     ' RowsPerStrip = 4
    ifd = ifd + TifEntry(279, 4, 1, 16)    ' StripByteCounts = 16
    ifd = ifd + LE32(0)                     ' Next IFD = 0
    ' Pixel data: values 0..15 row-major
    pix = ""
    FOR r = 0 TO 3
        FOR c = 0 TO 3
            pix = pix + CHR$(r * 4 + c)
        NEXT c
    NEXT r
    OPEN fileName FOR BINARY AS #1
    PUT$ #1, hdr + ifd + pix
    CLOSE #1
END SUB

' ---------------------------------------------------------------------------
' Build a TIFF with PackBits compression (type 32773).
' Same 4x4 8-bit grayscale layout.
' PackBits stream: ctrl=15 (literal run of 16 bytes) then bytes 0..15.
' Strip data = 17 bytes. Pixel data starts at offset 110.
' ---------------------------------------------------------------------------
SUB MakeTifPackBits4x4(BYVAL fileName AS STRING)
    DIM hdr AS STRING, ifd AS STRING, pix AS STRING
    DIM c AS INTEGER
    hdr = CHR$(73) + CHR$(73) + LE16(42) + LE32(8)
    ifd = LE16(8)
    ifd = ifd + TifEntry(256, 3, 1, 4)       ' ImageWidth = 4
    ifd = ifd + TifEntry(257, 3, 1, 4)       ' ImageLength = 4
    ifd = ifd + TifEntry(258, 3, 1, 8)       ' BitsPerSample = 8
    ifd = ifd + TifEntry(259, 3, 1, 32773)   ' Compression = PackBits
    ifd = ifd + TifEntry(262, 3, 1, 1)       ' PhotometricInterp = 1
    ifd = ifd + TifEntry(273, 4, 1, 110)     ' StripOffsets = 110
    ifd = ifd + TifEntry(278, 3, 1, 4)       ' RowsPerStrip = 4
    ifd = ifd + TifEntry(279, 4, 1, 17)      ' StripByteCounts = 17
    ifd = ifd + LE32(0)
    ' PackBits stream: ctrl=15 (literal 16 bytes) + pixels 0..15
    pix = CHR$(15)
    FOR c = 0 TO 15
        pix = pix + CHR$(c)
    NEXT c
    OPEN fileName FOR BINARY AS #1
    PUT$ #1, hdr + ifd + pix
    CLOSE #1
END SUB

' Helper: read one pixel from the VGA framebuffer at (x,y)
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, rv AS BYTE
    xv = x : yv = y : rv = 0
    CALL Vga_GetPixel(xv, yv, rv)
    GetP = rv
END FUNCTION

' ===========================================================================
' Test cases
' ===========================================================================

' ---------------------------------------------------------------------------
' GetSize — happy path
' ---------------------------------------------------------------------------
SUB Test_GetSize_ReturnsCorrectDimensions
    CALL Test_Case("GetSize returns correct width and height for 4x4 TIFF")
    DIM w AS WORD, h AS WORD, ok AS BYTE
    CALL MakeTifGray4x4("T.TIF")
    ok = DrawTif_GetSize("T.TIF", w, h)
    CALL Assert_IsEqual(ok, 1, "GetSize returns 1")
    CALL Assert_IsEqual(w, 4, "width = 4")
    CALL Assert_IsEqual(h, 4, "height = 4")
END SUB

' ---------------------------------------------------------------------------
' GetSize — missing file (exception)
' ---------------------------------------------------------------------------
SUB Test_GetSize_ReturnsZeroForMissingFile
    CALL Test_Case("GetSize returns 0 for a non-existent TIFF file")
    DIM w AS WORD, h AS WORD, ok AS BYTE
    ok = DrawTif_GetSize("NO_SUCH.TIF", w, h)
    CALL Assert_IsZero(ok, "GetSize = 0 for missing file")
END SUB

' ---------------------------------------------------------------------------
' GetInfo — happy path
' ---------------------------------------------------------------------------
SUB Test_GetInfo_ReturnsHeaderFields
    CALL Test_Case("GetInfo returns width, height, bits-per-sample, compression")
    DIM w AS WORD, h AS WORD, bps AS WORD, comp AS WORD, ok AS BYTE
    CALL MakeTifGray4x4("T.TIF")
    ok = DrawTif_GetInfo("T.TIF", w, h, bps, comp)
    CALL Assert_IsEqual(ok, 1, "GetInfo returns 1")
    CALL Assert_IsEqual(w, 4, "info width = 4")
    CALL Assert_IsEqual(h, 4, "info height = 4")
    CALL Assert_IsEqual(bps, 8, "info BitsPerSample = 8")
    CALL Assert_IsEqual(comp, 1, "info Compression = 1 (none)")
END SUB

' ---------------------------------------------------------------------------
' ParseFile — bad version (exception: wrong TIFF magic number)
' ---------------------------------------------------------------------------
SUB Test_ParseFile_RejectsBadVersion
    CALL Test_Case("ParseFile returns 0 when TIFF version field is not 42")
    DIM fh AS INTEGER, ctx AS TIFFContextType, ok AS BYTE
    ' Valid ByteOrder "II" but Version = 99 instead of 42
    OPEN "TBAD.TIF" FOR BINARY AS #1
    PUT$ #1, CHR$(73) + CHR$(73) + LE16(99) + LE32(8) + LE16(0) + LE32(0)
    CLOSE #1
    fh = FileUtil_OpenBinary("TBAD.TIF")
    ok = DrawTif_ParseFile(fh, ctx)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsZero(ok, "ParseFile = 0 for version != 42")
END SUB

' ---------------------------------------------------------------------------
' ParseFile — file too short (exception, boundary)
' ---------------------------------------------------------------------------
SUB Test_Show_TruncatedFileDoesNothing
    CALL Test_Case("Show does nothing when file is shorter than 8-byte TIFF header")
    OPEN "TSHORT.TIF" FOR BINARY AS #1
    PUT$ #1, CHR$(73) + CHR$(73) + LE16(42)
    CLOSE #1
    CALL DrawTif_Show("TSHORT.TIF", 0, 0)
    CALL Assert_IsEqual(GetP(0, 0), 0, "no pixel written for truncated file")
END SUB

' ---------------------------------------------------------------------------
' ParseFile — zero dimensions rejected (boundary: valid header, 0 IFD entries)
' ---------------------------------------------------------------------------
SUB Test_ParseFile_RejectsZeroDimensions
    CALL Test_Case("ParseFile returns 0 when image has no width/height tags")
    DIM fh AS INTEGER, ctx AS TIFFContextType, ok AS BYTE
    ' Valid header but IFD with 0 entries -> Wide=0, Height=0 -> IsLoaded=0
    OPEN "TMIN.TIF" FOR BINARY AS #1
    PUT$ #1, CHR$(73) + CHR$(73) + LE16(42) + LE32(8) + LE16(0) + LE32(0)
    CLOSE #1
    fh = FileUtil_OpenBinary("TMIN.TIF")
    ok = DrawTif_ParseFile(fh, ctx)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsZero(ok, "ParseFile = 0 for zero dimensions")
END SUB

' ---------------------------------------------------------------------------
' Show — pixel values from 4x4 8-bit grayscale uncompressed TIFF
' ---------------------------------------------------------------------------
SUB Test_Show_PixelValues_Uncompressed
    CALL Test_Case("Show renders 4x4 8-bit uncompressed TIFF with correct pixel values")
    CALL MakeTifGray4x4("T.TIF")
    CALL DrawTif_Show("T.TIF", 10, 20)
    ' Pixel at file (col=0,row=0) = 0; screen (10+0, 20+0) = (10,20)
    CALL Assert_IsEqual(GetP(10, 20), 0, "pixel(0,0) = 0")
    ' Pixel at (col=3,row=0) = 3; screen (13,20)
    CALL Assert_IsEqual(GetP(13, 20), 3, "pixel(3,0) = 3")
    ' Pixel at (col=0,row=1) = 4; screen (10,21)
    CALL Assert_IsEqual(GetP(10, 21), 4, "pixel(0,1) = 4")
    ' Pixel at (col=3,row=3) = 15; screen (13,23)
    CALL Assert_IsEqual(GetP(13, 23), 15, "pixel(3,3) = 15")
    ' Interior pixel at (col=2,row=2) = 10; screen (12,22)
    CALL Assert_IsEqual(GetP(12, 22), 10, "pixel(2,2) = 10")
END SUB

' ---------------------------------------------------------------------------
' Show — pixel values from 4x4 8-bit PackBits-compressed TIFF
' ---------------------------------------------------------------------------
SUB Test_Show_PixelValues_PackBits
    CALL Test_Case("Show renders 4x4 8-bit PackBits TIFF with correct pixel values")
    CALL MakeTifPackBits4x4("TP.TIF")
    CALL DrawTif_Show("TP.TIF", 30, 40)
    CALL Assert_IsEqual(GetP(30, 40), 0,  "PB pixel(0,0) = 0")
    CALL Assert_IsEqual(GetP(33, 40), 3,  "PB pixel(3,0) = 3")
    CALL Assert_IsEqual(GetP(30, 41), 4,  "PB pixel(0,1) = 4")
    CALL Assert_IsEqual(GetP(33, 43), 15, "PB pixel(3,3) = 15")
END SUB

' ---------------------------------------------------------------------------
' DecompressPackBits — literal run (unit test)
' ---------------------------------------------------------------------------
SUB Test_PackBits_LiteralRun
    CALL Test_Case("DecompressPackBits decodes a literal-run control byte correctly")
    ' ctrl=3 -> copy next 4 bytes literally
    DIM compressed AS STRING, decoded AS STRING
    compressed = CHR$(3) + CHR$(1) + CHR$(2) + CHR$(3) + CHR$(4)
    CALL DrawTif_DecompressPackBits(compressed, decoded)
    CALL Assert_IsEqual(LEN(decoded), 4, "literal: output length = 4")
    CALL Assert_IsEqual(ASC(MID$(decoded, 1, 1)), 1, "literal[0] = 1")
    CALL Assert_IsEqual(ASC(MID$(decoded, 4, 1)), 4, "literal[3] = 4")
END SUB

' ---------------------------------------------------------------------------
' DecompressPackBits — run-length repeat (unit test)
' ---------------------------------------------------------------------------
SUB Test_PackBits_RunLengthRepeat
    CALL Test_Case("DecompressPackBits decodes a run-length encoded sequence correctly")
    ' ctrl=0xFD (-3 signed) -> repeat next byte (-(-3)+1)=4 times
    DIM compressed AS STRING, decoded AS STRING
    compressed = CHR$(253) + CHR$(7)
    CALL DrawTif_DecompressPackBits(compressed, decoded)
    CALL Assert_IsEqual(LEN(decoded), 4, "rle: output length = 4")
    CALL Assert_IsEqual(ASC(MID$(decoded, 1, 1)), 7, "rle[0] = 7")
    CALL Assert_IsEqual(ASC(MID$(decoded, 4, 1)), 7, "rle[3] = 7")
END SUB

' ---------------------------------------------------------------------------
' DecompressPackBits — -128 (0x80) noop byte
' ---------------------------------------------------------------------------
SUB Test_PackBits_NoopByte
    CALL Test_Case("DecompressPackBits treats 0x80 (-128) as a no-op per PackBits spec")
    ' Sequence: [0x80=noop, 0x00=1 literal, 65='A']
    ' Expected output: "A" (1 byte), NOT 129 copies of CHR$(0) followed by A
    DIM compressed AS STRING, decoded AS STRING
    compressed = CHR$(128) + CHR$(0) + CHR$(65)
    CALL DrawTif_DecompressPackBits(compressed, decoded)
    CALL Assert_IsEqual(LEN(decoded), 1, "noop: output length = 1 (not 130)")
    CALL Assert_IsEqual(ASC(MID$(decoded, 1, 1)), 65, "noop: only byte = 65 (A)")
END SUB

' ---------------------------------------------------------------------------
' DecompressPackBits — empty input (boundary)
' ---------------------------------------------------------------------------
SUB Test_PackBits_EmptyInput
    CALL Test_Case("DecompressPackBits produces empty output for empty input")
    DIM compressed AS STRING, decoded AS STRING
    compressed = ""
    CALL DrawTif_DecompressPackBits(compressed, decoded)
    CALL Assert_IsEqual(LEN(decoded), 0, "empty input -> empty output")
END SUB

' ---------------------------------------------------------------------------
' GetPalette — default grayscale init for non-palette image (happy path)
' ---------------------------------------------------------------------------
SUB Test_GetPalette_GrayscaleDefault
    CALL Test_Case("GetPalette initialises palette to grayscale identity for non-palette TIFF")
    CALL MakeTifGray4x4("T.TIF")
    DIM pal(767) AS BYTE, ok AS BYTE
    ok = DrawTif_GetPalette("T.TIF", pal(), 8)
    CALL Assert_IsEqual(ok, 1, "GetPalette returns 1")
    CALL Assert_IsEqual(pal(0),       0,   "palette[0] = 0")
    CALL Assert_IsEqual(pal(10 * 3), 10,   "palette[10].R = 10")
    CALL Assert_IsEqual(pal(255 * 3), 255, "palette[255].R = 255")
END SUB

' ---------------------------------------------------------------------------
' GetPalette — missing file (exception)
' ---------------------------------------------------------------------------
SUB Test_GetPalette_MissingFileReturnsZero
    CALL Test_Case("GetPalette returns 0 for a non-existent TIFF file")
    DIM pal(767) AS BYTE, ok AS BYTE
    ok = DrawTif_GetPalette("NO_SUCH.TIF", pal(), 8)
    CALL Assert_IsZero(ok, "GetPalette = 0 for missing file")
END SUB

' ---------------------------------------------------------------------------
' Build a 4x4 8-bit uncompressed TIFF split into 2 strips of 2 rows each.
'
' File layout (all offsets 0-based, little-endian "II"):
'   0-7:   TIFF header: "II" + LE16(42) + LE32(8)
'   8-9:   IFD entry count = 9
'   10-117: 9 IFD entries x 12 bytes each
'   118-121: IFD next-offset = 0
'   122-129: StripOffsets array = [LE32(138), LE32(146)]
'   130-137: StripByteCounts array = [LE32(8), LE32(8)]
'   138-145: Strip 0 pixel data: rows 0-1 (pixels 0..7)
'   146-153: Strip 1 pixel data: rows 2-3 (pixels 8..15)
' ---------------------------------------------------------------------------
SUB MakeTifMultiStrip4x4(BYVAL fileName AS STRING)
    DIM hdr AS STRING, ifd AS STRING
    DIM offsets AS STRING, bytecounts AS STRING
    DIM pix0 AS STRING, pix1 AS STRING
    DIM r AS INTEGER, c AS INTEGER

    hdr = CHR$(73) + CHR$(73) + LE16(42) + LE32(8)

    ifd = LE16(9)
    ifd = ifd + TifEntry(256, 3, 1, 4)        ' ImageWidth = 4
    ifd = ifd + TifEntry(257, 3, 1, 4)        ' ImageLength = 4
    ifd = ifd + TifEntry(258, 3, 1, 8)        ' BitsPerSample = 8
    ifd = ifd + TifEntry(259, 3, 1, 1)        ' Compression = 1 (none)
    ifd = ifd + TifEntry(262, 3, 1, 1)        ' PhotometricInterp = 1
    ifd = ifd + TifEntry(273, 4, 2, 122)      ' StripOffsets -> array at 122
    ifd = ifd + TifEntry(277, 3, 1, 1)        ' SamplesPerPixel = 1
    ifd = ifd + TifEntry(278, 3, 1, 2)        ' RowsPerStrip = 2
    ifd = ifd + TifEntry(279, 4, 2, 130)      ' StripByteCounts -> array at 130
    ifd = ifd + LE32(0)                        ' Next IFD = 0

    ' Strip offsets: strip0 at 138, strip1 at 146
    offsets = LE32(138) + LE32(146)
    bytecounts = LE32(8) + LE32(8)

    ' Strip 0: rows 0-1, pixels 0..7 (row-major: 0,1,2,3,4,5,6,7)
    pix0 = ""
    FOR r = 0 TO 1
        FOR c = 0 TO 3
            pix0 = pix0 + CHR$(r * 4 + c)
        NEXT c
    NEXT r

    ' Strip 1: rows 2-3, pixels 8..15
    pix1 = ""
    FOR r = 2 TO 3
        FOR c = 0 TO 3
            pix1 = pix1 + CHR$(r * 4 + c)
        NEXT c
    NEXT r

    OPEN fileName FOR BINARY AS #1
    PUT$ #1, hdr + ifd + offsets + bytecounts + pix0 + pix1
    CLOSE #1
END SUB

' ---------------------------------------------------------------------------
' Test: multi-strip TIFF (RowsPerStrip=2, 2 strips) renders all rows correctly
' ---------------------------------------------------------------------------
SUB Test_Show_MultiStrip_PixelValues
    CALL Test_Case("Show renders 4x4 8-bit TIFF with 2 strips (RowsPerStrip=2) correctly")
    CALL MakeTifMultiStrip4x4("TMS.TIF")
    CALL DrawTif_Show("TMS.TIF", 50, 60)
    ' Strip 0: rows 0-1
    CALL Assert_IsEqual(GetP(50, 60),  0, "multi-strip pixel(0,0) = 0")
    CALL Assert_IsEqual(GetP(53, 60),  3, "multi-strip pixel(3,0) = 3")
    CALL Assert_IsEqual(GetP(50, 61),  4, "multi-strip pixel(0,1) = 4")
    CALL Assert_IsEqual(GetP(53, 61),  7, "multi-strip pixel(3,1) = 7")
    ' Strip 1: rows 2-3
    CALL Assert_IsEqual(GetP(50, 62),  8, "multi-strip pixel(0,2) = 8")
    CALL Assert_IsEqual(GetP(53, 62), 11, "multi-strip pixel(3,2) = 11")
    CALL Assert_IsEqual(GetP(50, 63), 12, "multi-strip pixel(0,3) = 12")
    CALL Assert_IsEqual(GetP(53, 63), 15, "multi-strip pixel(3,3) = 15")
END SUB

' ---------------------------------------------------------------------------
' Build a minimal big-endian "MM" TIFF (version=42 stored as 0x2A00 big-endian)
' ---------------------------------------------------------------------------
SUB MakeTifBigEndian(BYVAL fileName AS STRING)
    OPEN fileName FOR BINARY AS #1
    ' "MM" = CHR$(77)+CHR$(77), then version 42 as big-endian = CHR$(0)+CHR$(42), IFD offset
    PUT$ #1, CHR$(77) + CHR$(77) + CHR$(0) + CHR$(42) + CHR$(0) + CHR$(0) + CHR$(0) + CHR$(8)
    ' Minimal IFD with 0 entries (ParseFile will reject zero dims)
    PUT$ #1, CHR$(0) + CHR$(0) + CHR$(0) + CHR$(0) + CHR$(0) + CHR$(0)
    CLOSE #1
END SUB

' ---------------------------------------------------------------------------
' Test: ParseFile rejects big-endian "MM" TIFF (version field reads as 10752, not 42)
' ---------------------------------------------------------------------------
SUB Test_ParseFile_BigEndian_MM_Rejected
    CALL Test_Case("ParseFile rejects big-endian MM TIFF (version reads as LE-10752, not 42)")
    DIM fh AS INTEGER, ctx AS TIFFContextType, ok AS BYTE
    CALL MakeTifBigEndian("TMM.TIF")
    fh = FileUtil_OpenBinary("TMM.TIF")
    ok = DrawTif_ParseFile(fh, ctx)
    CALL FileUtil_CloseBinary(fh)
    CALL Assert_IsZero(ok, "ParseFile = 0 for MM big-endian TIFF")
END SUB

' ---------------------------------------------------------------------------
' Test_Setup / Test_Teardown
' ---------------------------------------------------------------------------
SUB Test_Setup
    !MOV AX, &H0013
    !INT &H10
    ' Initialise SVGAScreenContext (XRes=320,YRes=200) so bounds checks in
    ' DrawTif_DrawStripData don't immediately short-circuit pixel drawing.
    CALL Vga_InitMode13h
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB
