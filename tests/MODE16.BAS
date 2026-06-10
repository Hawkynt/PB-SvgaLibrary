' =============================================================================
' MODE16.TST - tests for MODE16.SUB (800x600x16 bit-planed VGA mode 6Ah)
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "MODE16.SUB"

SUB Svga_InitDispatchTable
END SUB

SUB PutP(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM xv AS WORD, yv AS WORD, cv AS BYTE
    xv = x : yv = y : cv = c
    CALL Mode16_PutPixel(xv, yv, cv)
END SUB
FUNCTION GetP(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    CALL Mode16_GetPixel(xv, yv, r)
    GetP = r
END FUNCTION

SUB Test_PutGet_AdjacentBits
    CALL Test_Case("PutPixel keeps adjacent bits in a byte independent (colours 1..15)")
    DIM i AS INTEGER, col AS BYTE, bad AS INTEGER
    FOR i = 0 TO 17
        col = (i AND 15) : IF col = 0 THEN col = 1
        CALL PutP(i, 5, col)
    NEXT i
    bad = 0
    FOR i = 0 TO 17
        col = (i AND 15) : IF col = 0 THEN col = 1
        IF GetP(i, 5) <> col THEN bad = bad + 1
    NEXT i
    CALL Assert_IsEqual(bad, 0, "18 pixels across byte boundaries round-trip")
END SUB

SUB Test_PutGet_AllColors
    CALL Test_Case("PutPixel covers the full 16-colour range")
    DIM c AS INTEGER, bad AS INTEGER
    FOR c = 0 TO 15 : CALL PutP(100 + c, 8, c) : NEXT c
    bad = 0
    FOR c = 0 TO 15 : IF GetP(100 + c, 8) <> c THEN bad = bad + 1
    NEXT c
    CALL Assert_IsEqual(bad, 0, "colours 0..15 round-trip")
END SUB

SUB Test_HLine_CrossesBytes
    CALL Test_Case("HLine fills a byte-crossing span exactly")
    DIM a AS WORD, b AS WORD, yy AS WORD, e AS BYTE
    a = 10 : b = 25 : yy = 20 : e = 12
    CALL Mode16_HLine(a, b, yy, e)
    CALL Assert_IsEqual(GetP(10, 20), 12, "left end")
    CALL Assert_IsEqual(GetP(17, 20), 12, "mid (next byte)")
    CALL Assert_IsEqual(GetP(25, 20), 12, "right end")
    CALL Assert_IsEqual(GetP(9, 20), 0, "no bleed left")
    CALL Assert_IsEqual(GetP(26, 20), 0, "no bleed right")
END SUB

SUB Test_VLine
    CALL Test_Case("VLine fills a column")
    DIM x AS WORD, a AS WORD, b AS WORD, e AS BYTE
    x = 40 : a = 30 : b = 37 : e = 7
    CALL Mode16_VLine(x, a, b, e)
    CALL Assert_IsEqual(GetP(40, 30), 7, "top")
    CALL Assert_IsEqual(GetP(40, 37), 7, "bottom")
    CALL Assert_IsEqual(GetP(40, 29), 0, "no bleed top")
END SUB

SUB Test_FillRect
    CALL Test_Case("FillRect fills interior, leaves the border")
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, e AS BYTE
    a = 50 : b = 50 : cc = 60 : d = 54 : e = 3
    CALL Mode16_FillRect(a, b, cc, d, e)
    CALL Assert_IsEqual(GetP(50, 50), 3, "corner")
    CALL Assert_IsEqual(GetP(60, 54), 3, "far corner")
    CALL Assert_IsEqual(GetP(55, 52), 3, "interior")
    CALL Assert_IsEqual(GetP(49, 52), 0, "no bleed")
END SUB

SUB Test_Corner
    CALL Test_Case("Far corner of 800x600 addresses correctly")
    CALL PutP(799, 599, 14)
    CALL Assert_IsEqual(GetP(799, 599), 14, "bottom-right pixel")
END SUB

SUB Test_Setup
CALL Mode16_SetMode
END SUB

SUB Test_Teardown
!MOV AX, &H0003
!INT &H10
END SUB
