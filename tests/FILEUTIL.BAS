' =============================================================================
' FILEUTIL.BAS - tests for FILEUTIL.SUB (shared binary file I/O + palette load)
' =============================================================================
' No manual entry point: the test runner auto-generates the driver from the
' SUB Test_* names below (Test_Setup/Test_Teardown run first/last if present).
$INCLUDE "TESTLIB.BI"
$INCLUDE "FILEUTIL.SUB"

' Build a 12-byte fixture: "BM" | word 0x1234 | dword 0x12345678 | "WXYZ"
SUB MakeFixture
    OPEN "TT.DAT" FOR BINARY AS #1
    PUT$ #1, "BM" + CHR$(&H34) + CHR$(&H12) + _
             CHR$(&H78) + CHR$(&H56) + CHR$(&H34) + CHR$(&H12) + "WXYZ"
    CLOSE #1
END SUB

SUB Test_Open_Size_Signature
    CALL Test_Case("OpenBinary / GetSize / ValidateSignature on a known file")
    DIM h AS INTEGER
    CALL MakeFixture
    h = FileUtil_OpenBinary("TT.DAT")
    CALL Assert_IsTrue(h >= 1, "valid handle for a non-empty file")
    CALL Assert_IsEqual(FileUtil_GetSize(h), 12, "size = 12 bytes")
    CALL Assert_IsEqual(FileUtil_ValidateSignature(h, "BM"), 1, "matching signature at the start")
    CALL Assert_IsEqual(FileUtil_ValidateSignature(h, "GIF"), 0, "non-matching signature")
    CALL FileUtil_CloseBinary(h)
END SUB

SUB Test_Open_Errors
    CALL Test_Case("OpenBinary fails on missing and empty files")
    CALL Assert_IsEqual(FileUtil_OpenBinary("NOPE.DAT"), -1, "missing file -> -1")
    OPEN "EMPTY.DAT" FOR OUTPUT AS #1 : CLOSE #1
    CALL Assert_IsEqual(FileUtil_OpenBinary("EMPTY.DAT"), -1, "empty file -> -1")
END SUB

SUB Test_ReadWord_DWord_Bytes
    CALL Test_Case("Read little-endian WORD/DWORD and raw bytes in sequence")
    DIM h AS INTEGER, w AS WORD, d AS LONG, s AS STRING, ok AS BYTE
    CALL MakeFixture
    h = FileUtil_OpenBinary("TT.DAT")
    CALL Assert_IsEqual(FileUtil_Seek(h, 3), 1, "seek (1-based) to the word field")
    ok = FileUtil_ReadWord(h, w)
    CALL Assert_IsEqual(ok, 1, "ReadWord succeeds")
    CALL Assert_IsEqual(w, &H1234, "WORD is little-endian 0x1234")
    ok = FileUtil_ReadDWord(h, d)
    CALL Assert_IsEqual(ok, 1, "ReadDWord succeeds")
    CALL Assert_IsEqual(d, &H12345678, "DWORD is little-endian 0x12345678")
    ok = FileUtil_ReadBytes(h, 4, s)
    CALL Assert_IsEqual(ok, 1, "ReadBytes succeeds")
    CALL Assert_AreEqualStr(s, "WXYZ", "trailing 4 bytes")
    CALL FileUtil_CloseBinary(h)
END SUB

SUB Test_Seek_Skip_CanRead
    CALL Test_Case("Seek / Skip / CanRead bounds (1-based API)")
    DIM h AS INTEGER
    CALL MakeFixture
    h = FileUtil_OpenBinary("TT.DAT")
    CALL Assert_IsEqual(FileUtil_Seek(h, 0), 0, "seek before start fails")
    CALL Assert_IsEqual(FileUtil_Seek(h, 13), 0, "seek past EOF fails")
    CALL Assert_IsEqual(FileUtil_Seek(h, 1), 1, "seek to first byte succeeds")
    CALL Assert_IsEqual(FileUtil_CanRead(h, 12), 1, "can read the whole file")
    CALL Assert_IsEqual(FileUtil_CanRead(h, 13), 0, "cannot read past EOF")
    CALL Assert_IsEqual(FileUtil_Skip(h, 4), 1, "skip within bounds")
    CALL Assert_IsEqual(FileUtil_Skip(h, 100), 0, "skip past EOF fails")
    CALL FileUtil_CloseBinary(h)
END SUB

SUB Test_LoadPalette
    CALL Test_Case("LoadPalette / LoadPaletteBGRA program the VGA DAC (6-bit, scaled)")
    !MOV AX, &H0013
    !INT &H10
    CALL FileUtil_LoadPalette(CHR$(252) + CHR$(128) + CHR$(64), 100, 1, 1)
    OUT &H3C7, 100
    CALL Assert_IsEqual(INP(&H3C9), 63, "R 252\4 = 63")
    CALL Assert_IsEqual(INP(&H3C9), 32, "G 128\4 = 32")
    CALL Assert_IsEqual(INP(&H3C9), 16, "B 64\4 = 16")
    CALL FileUtil_LoadPaletteBGRA(CHR$(64) + CHR$(128) + CHR$(252) + CHR$(0), 101, 1)
    OUT &H3C7, 101
    CALL Assert_IsEqual(INP(&H3C9), 63, "R from BGRA 252\4 = 63")
    CALL Assert_IsEqual(INP(&H3C9), 32, "G from BGRA 128\4 = 32")
    CALL Assert_IsEqual(INP(&H3C9), 16, "B from BGRA 64\4 = 16")
    !MOV AX, &H0003
    !INT &H10
END SUB
