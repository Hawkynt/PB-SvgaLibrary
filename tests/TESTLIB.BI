' =============================================================================
' TESTLIB.BI - tiny xUnit-style test framework for the SVGA library suites
' =============================================================================
' Each <MODULE>.TST is a self-contained PowerBASIC program: it $INCLUDEs this
' file plus the module(s) under test, defines one SUB per test case in the
' Arrange-Act-Assert shape, and a main that opens the suite, calls each test and
' closes it. Results are appended to UNITTEST.LOG in a parseable form that
' scripts/run-pb-tests.sh renders as an NUnit/xUnit-style summary:
'   [SUITE] <name>
'     [PASS] <case> :: <assertion>
'     [FAIL] <case> :: <assertion> (expected=.. actual=..)
'   [RESULT] <name> assertions=N failed=M
' =============================================================================
DIM tCount AS SHARED INTEGER       ' assertions made in the current suite
DIM tFail  AS SHARED INTEGER       ' assertions failed in the current suite
DIM tCaseName  AS SHARED STRING        ' current test-case name

SUB TBeginSuite(suiteName AS STRING)
    OPEN "UNITTEST.LOG" FOR APPEND AS #9
    PRINT #9, "[SUITE] "; suiteName
    tCount = 0 : tFail = 0
END SUB

SUB TCase(caseName AS STRING)
    tCaseName = caseName
END SUB

' boolean assertion
SUB TChk(BYVAL cond AS INTEGER, what AS STRING)
    tCount = tCount + 1
    IF cond <> 0 THEN
        PRINT #9, "  [PASS] "; tCaseName; " :: "; what
    ELSE
        tFail = tFail + 1
        PRINT #9, "  [FAIL] "; tCaseName; " :: "; what
    END IF
END SUB

' numeric equality (WORD/BYTE/INTEGER widen to LONG)
SUB TChkEq(BYVAL actual AS LONG, BYVAL expected AS LONG, what AS STRING)
    tCount = tCount + 1
    IF actual = expected THEN
        PRINT #9, "  [PASS] "; tCaseName; " :: "; what
    ELSE
        tFail = tFail + 1
        PRINT #9, "  [FAIL] "; tCaseName; " :: "; what; " (expected="; expected; " actual="; actual; ")"
    END IF
END SUB

SUB TEndSuite(suiteName AS STRING)
    PRINT #9, "[RESULT] "; suiteName; " assertions="; tCount; " failed="; tFail
    CLOSE #9
END SUB
