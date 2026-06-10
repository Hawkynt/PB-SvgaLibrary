' =============================================================================
' MEMORY.TST - tests for MEMORY.SUB (block copy/swap, VRAM clear, VESA window)
' =============================================================================
' EMS routines (Take/Put/GetEmsByte/String, CloseEms) need a real EMS driver +
' page frame and are not exercised here; the deterministic conventional/VRAM
' paths are covered instead.
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "MEMORY.SUB"

FUNCTION PeekVram(BYVAL vofs AS WORD) AS INTEGER
    DIM v AS BYTE
    !PUSH DS
    !MOV AX, &HA000
    !MOV DS, AX
    !MOV BX, vofs
    !MOV AL, [BX]
    !MOV v, AL
    !POP DS
    PeekVram = v
END FUNCTION

SUB Test_MemCopy_HappyPath
    CALL TCase("MemCopy duplicates a byte block")
    DIM src(0 TO 15) AS BYTE, dst(0 TO 15) AS BYTE, i AS INTEGER, bad AS INTEGER
    FOR i = 0 TO 15 : src(i) = i * 3 + 1 : dst(i) = 0 : NEXT i      ' Arrange
    CALL Memory_MemCopy(VARSEG(src(0)), VARPTR(src(0)), 16, VARSEG(dst(0)), VARPTR(dst(0)), 16, 16)  ' Act
    bad = 0                                                          ' Assert
    FOR i = 0 TO 15 : IF dst(i) <> src(i) THEN bad = bad + 1
    NEXT i
    CALL TChkEq(bad, 0, "all 16 bytes copied")
END SUB

SUB Test_MemCopy_Partial
    CALL TCase("MemCopy honours byteCount, leaves the tail")
    DIM src(0 TO 15) AS BYTE, dst(0 TO 15) AS BYTE, i AS INTEGER
    FOR i = 0 TO 15 : src(i) = 200 : dst(i) = 9 : NEXT i
    CALL Memory_MemCopy(VARSEG(src(0)), VARPTR(src(0)), 16, VARSEG(dst(0)), VARPTR(dst(0)), 16, 4)
    CALL TChkEq(dst(0), 200, "byte 0 copied")
    CALL TChkEq(dst(3), 200, "byte 3 copied")
    CALL TChkEq(dst(4), 9, "byte 4 untouched (beyond count)")
END SUB

SUB Test_MemCopy_ZeroCount
    CALL TCase("MemCopy of 0 bytes is a no-op")
    DIM src(0 TO 3) AS BYTE, dst(0 TO 3) AS BYTE
    src(0) = 1 : dst(0) = 77
    CALL Memory_MemCopy(VARSEG(src(0)), VARPTR(src(0)), 4, VARSEG(dst(0)), VARPTR(dst(0)), 4, 0)
    CALL TChkEq(dst(0), 77, "destination unchanged")
END SUB

SUB Test_MemSwap_HappyPath
    CALL TCase("MemSwap exchanges two blocks")
    DIM a(0 TO 7) AS BYTE, b(0 TO 7) AS BYTE, i AS INTEGER, bad AS INTEGER
    FOR i = 0 TO 7 : a(i) = 10 + i : b(i) = 90 + i : NEXT i
    CALL Memory_MemSwap(VARSEG(a(0)), VARPTR(a(0)), 8, VARSEG(b(0)), VARPTR(b(0)), 8, 8)
    bad = 0
    FOR i = 0 TO 7
        IF a(i) <> 90 + i THEN bad = bad + 1
        IF b(i) <> 10 + i THEN bad = bad + 1
    NEXT i
    CALL TChkEq(bad, 0, "blocks fully exchanged")
END SUB

SUB Test_ClearVideoMemory
    CALL TCase("ClearVideoMemory floods mode-13h VRAM")
    !MOV AX, &H0013
    !INT &H10
    CALL Memory_ClearVideoMemory(55)
    CALL TChkEq(PeekVram(0), 55, "first pixel")
    CALL TChkEq(PeekVram(32000), 55, "mid VRAM")
    CALL TChkEq(PeekVram(63999), 55, "last pixel")
    !MOV AX, &H0003
    !INT &H10
END SUB

SUB Test_SetVesaWindow_UpdatesContext
    CALL TCase("SetVesaWindow records the window number")
    CALL Memory_SetVesaWindow(7)
    CALL TChkEq(VESASystemContext.VWnd, 7, "VWnd updated even without a VESA BIOS")
END SUB

' === entry point ===
CALL TBeginSuite("MEMORY")
CALL Test_MemCopy_HappyPath
CALL Test_MemCopy_Partial
CALL Test_MemCopy_ZeroCount
CALL Test_MemSwap_HappyPath
CALL Test_ClearVideoMemory
CALL Test_SetVesaWindow_UpdatesContext
CALL TEndSuite("MEMORY")
END
