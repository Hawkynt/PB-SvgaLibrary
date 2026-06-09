' =============================================================================
' test_planar_modes.bas - unit tests for the unchained planar modes X / Y / Z
' =============================================================================
' Self-contained PowerBASIC 3.5 test runner. Sets each planar mode, then drives
' the optimized primitives THROUGH the SVGADispatch function-pointer table
' (exactly as the library does) and verifies pixels via GetPixel. Results go to
' UNITTEST.LOG; any "FAILED" line makes scripts/run-pb-tests.sh fail the build.
'
' Given a freshly set planar mode (X=320x240, Y=320x200, Z=320x400),
' When primitives are dispatched via SVGADispatch,
' Then the pixels they touch (and only those) read back with the drawn colour.
' =============================================================================
$INCLUDE "TYPES.SUB"
$INCLUDE "MODEX.SUB"
$INCLUDE "MODEY.SUB"
$INCLUDE "MODEZ.SUB"

DIM fail AS SHARED INTEGER
fail = 0

SUB Assert(BYVAL cond AS INTEGER, msg AS STRING)
    IF cond = 0 THEN
        PRINT #1, "FAILED: "; msg
        fail = 1
    END IF
END SUB

SUB DispPut(BYVAL x AS WORD, BYVAL y AS WORD, BYVAL c AS BYTE)
    DIM p AS DWORD, xv AS WORD, yv AS WORD, cv AS BYTE
    xv = x : yv = y : cv = c
    p = SVGADispatch.PutPixel
    CALL DWORD p BDECL (xv, yv, cv)
END SUB
FUNCTION DispGet(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
    DIM p AS DWORD, xv AS WORD, yv AS WORD, r AS BYTE
    xv = x : yv = y : r = 0
    p = SVGADispatch.GetPixel
    CALL DWORD p BDECL (xv, yv, r)
    DispGet = r
END FUNCTION

SUB CheckMode(modeName AS STRING, BYVAL hiY AS WORD)
    DIM i AS INTEGER, jx AS INTEGER, jy AS INTEGER
    DIM hp AS DWORD, vp AS DWORD, rp AS DWORD, lp AS DWORD, dp AS DWORD
    DIM a AS WORD, b AS WORD, cc AS WORD, d AS WORD, col AS BYTE

    ' --- PutPixel / GetPixel across all four planes ---
    FOR i = 0 TO 7
        CALL DispPut(i, 10, 50 + i)
    NEXT i
    FOR i = 0 TO 7
        CALL Assert(DispGet(i, 10) = 50 + i, modeName + " putget plane")
    NEXT i
    ' top-of-mode scanline (tall-mode addressing)
    CALL DispPut(100, hiY, 123)
    CALL Assert(DispGet(100, hiY) = 123, modeName + " tall scanline")

    ' --- HLine 12..18 @ y=20, colour 99 ---
    hp = SVGADispatch.HLine
    a = 12 : b = 18 : cc = 20 : col = 99
    CALL DWORD hp BDECL (a, b, cc, col)
    FOR i = 12 TO 18
        CALL Assert(DispGet(i, 20) = 99, modeName + " hline run")
    NEXT i
    CALL Assert(DispGet(11, 20) <> 99, modeName + " hline no bleed left")
    CALL Assert(DispGet(19, 20) <> 99, modeName + " hline no bleed right")

    ' --- VLine x=25, y 30..36, colour 88 ---
    vp = SVGADispatch.VLine
    a = 25 : b = 30 : cc = 36 : col = 88
    CALL DWORD vp BDECL (a, b, cc, col)
    FOR i = 30 TO 36
        CALL Assert(DispGet(25, i) = 88, modeName + " vline run")
    NEXT i
    CALL Assert(DispGet(25, 29) <> 88, modeName + " vline no bleed top")
    CALL Assert(DispGet(25, 37) <> 88, modeName + " vline no bleed bottom")

    ' --- FillRect (40,40)-(45,43), colour 66 ---
    rp = SVGADispatch.FillRect
    a = 40 : b = 40 : cc = 45 : d = 43 : col = 66
    CALL DWORD rp BDECL (a, b, cc, d, col)
    FOR jy = 40 TO 43
        FOR jx = 40 TO 45
            CALL Assert(DispGet(jx, jy) = 66, modeName + " fillrect interior")
        NEXT jx
    NEXT jy
    CALL Assert(DispGet(39, 41) <> 66, modeName + " fillrect no bleed left")
    CALL Assert(DispGet(46, 41) <> 66, modeName + " fillrect no bleed right")

    ' --- LineDraw 45-degree diagonal (60,60)-(66,66), colour 77 ---
    lp = SVGADispatch.LineDraw
    a = 60 : b = 60 : cc = 66 : d = 66 : col = 77
    CALL DWORD lp BDECL (a, b, cc, d, col)
    FOR i = 60 TO 66
        CALL Assert(DispGet(i, i) = 77, modeName + " linedraw diagonal")
    NEXT i

    ' --- DrawRect outline (70,70)-(76,74), colour 55 ---
    dp = SVGADispatch.DrawRect
    a = 70 : b = 70 : cc = 76 : d = 74 : col = 55
    CALL DWORD dp BDECL (a, b, cc, d, col)
    FOR i = 70 TO 76
        CALL Assert(DispGet(i, 70) = 55, modeName + " drawrect top edge")
        CALL Assert(DispGet(i, 74) = 55, modeName + " drawrect bottom edge")
    NEXT i
    CALL Assert(DispGet(73, 72) <> 55, modeName + " drawrect hollow centre")

    PRINT #1, "PASS "; modeName
END SUB

OPEN "UNITTEST.LOG" FOR OUTPUT AS #1
PRINT #1, "=== planar mode dispatch tests ==="
CALL ModeX_InitTables
CALL ModeX_SetMode(0) : CALL CheckMode("MODE-X", 235)
CALL ModeY_SetMode    : CALL CheckMode("MODE-Y", 195)
CALL ModeZ_SetMode    : CALL CheckMode("MODE-Z", 395)
!MOV AX, &H0003
!INT &H10
IF fail = 0 THEN PRINT #1, "ALL TESTS PASSED" ELSE PRINT #1, "SOME TESTS FAILED"
CLOSE #1
END

' --- test doubles: the real ones live in SVGA.SUB (which is >64k to include) ---
SUB Svga_InitDispatchTable
    SVGADispatch.PutPixel = CODEPTR32(ModeX_PutPixel)
    SVGADispatch.GetPixel = CODEPTR32(ModeX_GetPixel)
    SVGADispatch.HLine = CODEPTR32(ModeX_HLine)
    SVGADispatch.VLine = CODEPTR32(ModeX_VLine)
    SVGADispatch.LineDraw = CODEPTR32(ModeX_LineDraw)
    SVGADispatch.FillRect = CODEPTR32(ModeX_FillRect)
    SVGADispatch.DrawRect = CODEPTR32(ModeX_DrawRect)
    SVGADispatch.ClearScreen = CODEPTR32(ModeX_ClearScreen)
    SVGADispatch.CopyBlock = CODEPTR32(ModeX_CopyBlock)
END SUB
SUB Memory_ClearVideoMemory(c AS BYTE)
END SUB
