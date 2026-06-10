' =============================================================================
' TIMER.BAS - tests for TIMER.SUB (timer state machine)
' Covers: Init/Reset flags, named timer create/check/destroy, anim timer,
'         OnTimer/OffTimer install/uninstall bookkeeping (state only, no ISR
'         tick-wait), HrTimer divisor math, GetTimerFrequency, boundary &
'         exception cases.
' ISR-firing paths (Timer_WaitTicks, Timer_Delay10Ms) are deliberately NOT
' exercised because they block on real hardware ticks which are unreliable
' (and potentially infinite) in headless DOSBox-X.
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "TIMER.SUB"

' ---- Reset helper so each test starts from a known state --------------------
' Calls Timer_Init so LastSystemTick is seeded from the real BIOS clock;
' subsequent Timer_GetTimerTick calls will see a near-zero difference and
' will not inflate TickCount unpredictably.
SUB ResetTimerState
    ' Ensure no ISR is flagged as installed (avoids DOS int calls in OffTimer)
    TimerInterrupt.IsInstalled = 0
    TimerInterrupt.OldVector = 0
    TimerInterrupt.IntervalTicks = 0
    TimerInterrupt.HandlerAddress = 0
    TimerInterrupt.UserRoutine = 0
    TimerTickCounter = 0
    ' Use Timer_Init to correctly seed LastSystemTick from the BIOS clock
    CALL Timer_Init       ' sets IsInitialized=1, zeros TickCount, peeks real clock
    ' Destroy all named timers
    DIM I AS INTEGER
    FOR I = 0 TO 7
        TimerSystemContext.NamedTimers(I).Active = 0
        TimerSystemContext.NamedTimers(I).DlyUnits = 0
        TimerSystemContext.NamedTimers(I).NextTick = 0
    NEXT I
END SUB

' ==============================================================================
' Suite 1 — Timer_Init: sets IsInitialized, zeros counters
' ==============================================================================
SUB Test_Init_SetsInitializedFlag
    CALL Test_Case("Timer_Init sets IsInitialized=1")
    CALL ResetTimerState
    CALL Assert_IsEqual(TimerSystemContext.IsInitialized, 1, "IsInitialized flag set")
END SUB

SUB Test_Init_ZerosTickCount
    CALL Test_Case("Timer_Init zeros TickCount")
    TimerSystemContext.TickCount = 9999
    CALL Timer_Init
    CALL Assert_IsEqual(TimerSystemContext.TickCount, 0, "TickCount zeroed by Init")
END SUB

SUB Test_Init_ZerosAnimFields
    CALL Test_Case("Timer_Init zeros AnimTimer and AnimDelay")
    TimerSystemContext.AnimTimer = 777
    TimerSystemContext.AnimDelay = 42
    CALL Timer_Init
    CALL Assert_IsEqual(TimerSystemContext.AnimTimer, 0, "AnimTimer zeroed")
    CALL Assert_IsEqual(TimerSystemContext.AnimDelay, 0, "AnimDelay zeroed")
END SUB

' ==============================================================================
' Suite 2 — Timer_Reset: zeros tick and anim fields without re-init
' ==============================================================================
SUB Test_Reset_ZerosTickCount
    CALL Test_Case("Timer_Reset clears TickCount")
    CALL ResetTimerState
    TimerSystemContext.TickCount = 500
    CALL Timer_Reset
    CALL Assert_IsEqual(TimerSystemContext.TickCount, 0, "TickCount reset to 0")
END SUB

SUB Test_Reset_ZerosAnimTimer
    CALL Test_Case("Timer_Reset clears AnimTimer")
    CALL ResetTimerState
    TimerSystemContext.AnimTimer = 123
    CALL Timer_Reset
    CALL Assert_IsEqual(TimerSystemContext.AnimTimer, 0, "AnimTimer reset to 0")
END SUB

' ==============================================================================
' Suite 3 — Named timer: Create/Destroy/boundary/exception
' ==============================================================================
SUB Test_NamedTimer_Create_HappyPath
    CALL Test_Case("Timer_Create activates slot and stores delay")
    CALL ResetTimerState
    CALL Timer_Create(3, 50)
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(3).Active, 1, "timer 3 active")
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(3).DlyUnits, 50, "delay stored")
END SUB

SUB Test_NamedTimer_Create_FirstSlot
    CALL Test_Case("Timer_Create slot 0 works")
    CALL ResetTimerState
    CALL Timer_Create(0, 20)
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(0).Active, 1, "slot 0 active")
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(0).DlyUnits, 20, "slot 0 delay=20")
END SUB

SUB Test_NamedTimer_Create_LastSlot
    CALL Test_Case("Timer_Create slot 7 (max) works")
    CALL ResetTimerState
    CALL Timer_Create(7, 5)
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(7).Active, 1, "slot 7 active")
END SUB

SUB Test_NamedTimer_Create_BoundaryReject
    CALL Test_Case("Timer_Create index 8 (out of range) is silently ignored")
    CALL ResetTimerState
    ' Slot 8 must NOT be activated (guard: IF TimerName >= 8 THEN EXIT SUB)
    CALL Timer_Create(8, 99)
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(7).Active, 0, "slot 7 unchanged")
END SUB

SUB Test_NamedTimer_Destroy_HappyPath
    CALL Test_Case("Timer_Destroy deactivates slot and zeros fields")
    CALL ResetTimerState
    CALL Timer_Create(2, 30)
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(2).Active, 1, "pre: active")
    CALL Timer_Destroy(2)
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(2).Active, 0, "post: inactive")
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(2).DlyUnits, 0, "DlyUnits cleared")
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(2).NextTick, 0, "NextTick cleared")
END SUB

SUB Test_NamedTimer_Destroy_BoundaryIgnored
    CALL Test_Case("Timer_Destroy index 8 is silently ignored")
    CALL ResetTimerState
    ' Just ensuring it doesn't crash and slot 7 stays untouched
    TimerSystemContext.NamedTimers(7).Active = 1
    CALL Timer_Destroy(8)
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(7).Active, 1, "slot 7 unchanged")
    ' Clean up
    TimerSystemContext.NamedTimers(7).Active = 0
END SUB

SUB Test_NamedTimer_IsReady_ReturnsFalseWhenInactive
    CALL Test_Case("Timer_IsTimerReady returns 0 for inactive slot")
    CALL ResetTimerState
    ' slot 5 not created -> Active=0
    DIM r AS BYTE
    r = Timer_IsTimerReady(5)
    CALL Assert_IsEqual(r, 0, "inactive slot returns 0")
END SUB

SUB Test_NamedTimer_IsReady_ReturnsFalseForOOB
    CALL Test_Case("Timer_IsTimerReady returns 0 for out-of-range index")
    CALL ResetTimerState
    DIM r AS BYTE
    r = Timer_IsTimerReady(8)
    CALL Assert_IsEqual(r, 0, "index 8 returns 0")
END SUB

SUB Test_NamedTimer_IsReady_ReturnsTrueWhenExpired
    CALL Test_Case("Timer_IsTimerReady returns 1 when NextTick <= current tick")
    CALL ResetTimerState
    ' Get the current tick value so we can plant an already-expired NextTick
    ' Timer_GetTimerTick updates TickCount from LastSystemTick (just seeded)
    DIM curTick AS LONG
    curTick = Timer_GetTimerTick
    ' Plant timer with NextTick well in the past
    TimerSystemContext.NamedTimers(4).Active = 1
    TimerSystemContext.NamedTimers(4).DlyUnits = 10
    TimerSystemContext.NamedTimers(4).NextTick = curTick - 50
    DIM r AS BYTE
    r = Timer_IsTimerReady(4)
    CALL Assert_IsEqual(r, 1, "expired timer reports ready")
END SUB

SUB Test_NamedTimer_IsReady_ReturnsFalseWhenNotExpired
    CALL Test_Case("Timer_IsTimerReady returns 0 when NextTick > current tick")
    CALL ResetTimerState
    ' Plant timer with NextTick far in the future relative to current tick
    DIM curTick AS LONG
    curTick = Timer_GetTimerTick
    TimerSystemContext.NamedTimers(1).Active = 1
    TimerSystemContext.NamedTimers(1).DlyUnits = 20
    TimerSystemContext.NamedTimers(1).NextTick = curTick + 50000
    DIM r AS BYTE
    r = Timer_IsTimerReady(1)
    CALL Assert_IsEqual(r, 0, "not-yet-expired timer returns 0")
END SUB

SUB Test_NamedTimer_IsReady_AutoReschedule
    CALL Test_Case("Timer_IsTimerReady reschedules NextTick after firing")
    CALL ResetTimerState
    DIM curTick AS LONG
    curTick = Timer_GetTimerTick
    TimerSystemContext.NamedTimers(6).Active = 1
    TimerSystemContext.NamedTimers(6).DlyUnits = 25
    TimerSystemContext.NamedTimers(6).NextTick = curTick - 20   ' expired
    DIM r AS BYTE
    r = Timer_IsTimerReady(6)
    ' NextTick must be >= curTick + 25 (GetTimerTick may add a tiny increment)
    DIM newNext AS LONG
    newNext = TimerSystemContext.NamedTimers(6).NextTick
    CALL Assert_IsTrue(newNext > curTick, "NextTick rescheduled beyond curTick")
    CALL Assert_IsTrue(newNext >= curTick + 25, "NextTick includes delay interval")
END SUB

' ==============================================================================
' Suite 4 — Anim timer
' ==============================================================================
SUB Test_AnimTimer_SetAnimTimer_StoresDelay
    CALL Test_Case("Timer_SetAnimTimer stores AnimDelay")
    CALL ResetTimerState
    CALL Timer_SetAnimTimer(15)
    CALL Assert_IsEqual(TimerSystemContext.AnimDelay, 15, "AnimDelay stored as 15")
END SUB

SUB Test_AnimTimer_Ready_ZeroDelayReturnsFalse
    CALL Test_Case("Timer_AnimTimerReady returns 0 when AnimDelay=0")
    CALL ResetTimerState
    TimerSystemContext.AnimDelay = 0
    DIM r AS BYTE
    r = Timer_AnimTimerReady
    CALL Assert_IsEqual(r, 0, "zero delay returns 0")
END SUB

SUB Test_AnimTimer_Ready_ReturnsTrueWhenExpired
    CALL Test_Case("Timer_AnimTimerReady returns 1 when AnimTimer <= TickCount")
    CALL ResetTimerState
    DIM curTick AS LONG
    curTick = Timer_GetTimerTick
    TimerSystemContext.AnimDelay = 10
    TimerSystemContext.AnimTimer = curTick - 50    ' already past
    DIM r AS BYTE
    r = Timer_AnimTimerReady
    CALL Assert_IsEqual(r, 1, "expired anim timer reports ready")
END SUB

SUB Test_AnimTimer_Ready_AutoReschedule
    CALL Test_Case("Timer_AnimTimerReady reschedules AnimTimer after firing")
    CALL ResetTimerState
    DIM curTick AS LONG
    curTick = Timer_GetTimerTick
    TimerSystemContext.AnimDelay = 10
    TimerSystemContext.AnimTimer = curTick - 50
    CALL Timer_AnimTimerReady
    ' AnimTimer must be >= curTick + 10
    CALL Assert_IsTrue(TimerSystemContext.AnimTimer >= curTick + 10, "AnimTimer rescheduled beyond curTick+delay")
END SUB

' ==============================================================================
' Suite 5 — Timer_Cleanup: zeros context, does NOT need ISR installed
' ==============================================================================
SUB Test_Cleanup_ZerosContext
    CALL Test_Case("Timer_Cleanup zeros all context fields")
    CALL ResetTimerState
    TimerSystemContext.TickCount = 42
    TimerSystemContext.AnimDelay = 7
    TimerSystemContext.AnimTimer = 99
    ' Ensure no ISR installed (OffTimer/Restore harmless when IsInstalled=0)
    TimerInterrupt.IsInstalled = 0
    CALL Timer_Cleanup
    CALL Assert_IsEqual(TimerSystemContext.IsInitialized, 0, "IsInitialized cleared")
    CALL Assert_IsEqual(TimerSystemContext.TickCount, 0, "TickCount cleared")
    CALL Assert_IsEqual(TimerSystemContext.AnimDelay, 0, "AnimDelay cleared")
    CALL Assert_IsEqual(TimerSystemContext.AnimTimer, 0, "AnimTimer cleared")
END SUB

SUB Test_Cleanup_DestroysAllNamedTimers
    CALL Test_Case("Timer_Cleanup deactivates all named timer slots")
    CALL ResetTimerState
    TimerInterrupt.IsInstalled = 0
    ' Activate a few named timers manually
    TimerSystemContext.NamedTimers(0).Active = 1
    TimerSystemContext.NamedTimers(3).Active = 1
    TimerSystemContext.NamedTimers(7).Active = 1
    CALL Timer_Cleanup
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(0).Active, 0, "slot 0 cleared")
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(3).Active, 0, "slot 3 cleared")
    CALL Assert_IsEqual(TimerSystemContext.NamedTimers(7).Active, 0, "slot 7 cleared")
END SUB

' ==============================================================================
' Suite 6 — Timer_IsTimerInstalled (pure state reader)
' ==============================================================================
SUB Test_IsInstalled_ReturnsFalseInitially
    CALL Test_Case("Timer_IsTimerInstalled returns 0 when not installed")
    CALL ResetTimerState
    CALL Assert_IsEqual(Timer_IsTimerInstalled, 0, "not installed -> 0")
END SUB

SUB Test_IsInstalled_ReturnsTrueWhenFlagSet
    CALL Test_Case("Timer_IsTimerInstalled returns 1 when flag planted")
    CALL ResetTimerState
    TimerInterrupt.IsInstalled = 1      ' plant flag directly -- no real ISR
    CALL Assert_IsEqual(Timer_IsTimerInstalled, 1, "planted flag -> 1")
    ' Clean up
    TimerInterrupt.IsInstalled = 0
END SUB

' ==============================================================================
' Suite 7 — Timer_GetTimerFrequency
' frequency = 18 \ IntervalTicks (integer Hz of the 18.2 Hz system clock)
' ==============================================================================
SUB Test_GetTimerFrequency_NotInstalledReturnsZero
    CALL Test_Case("Timer_GetTimerFrequency returns 0 when not installed")
    CALL ResetTimerState
    CALL Assert_IsEqual(Timer_GetTimerFrequency, 0, "not installed -> 0")
END SUB

SUB Test_GetTimerFrequency_OneTickInterval
    CALL Test_Case("Timer_GetTimerFrequency: IntervalTicks=1 -> 18 Hz")
    CALL ResetTimerState
    TimerInterrupt.IsInstalled = 1
    TimerInterrupt.IntervalTicks = 1
    ' 18 \ 1 = 18
    CALL Assert_IsEqual(Timer_GetTimerFrequency, 18, "1 tick -> 18 Hz")
    TimerInterrupt.IsInstalled = 0
END SUB

SUB Test_GetTimerFrequency_EighteenTickInterval
    CALL Test_Case("Timer_GetTimerFrequency: IntervalTicks=18 -> 1 Hz")
    CALL ResetTimerState
    TimerInterrupt.IsInstalled = 1
    TimerInterrupt.IntervalTicks = 18
    ' 18 \ 18 = 1
    CALL Assert_IsEqual(Timer_GetTimerFrequency, 1, "18 ticks -> 1 Hz")
    TimerInterrupt.IsInstalled = 0
END SUB

SUB Test_GetTimerFrequency_NineTicks
    CALL Test_Case("Timer_GetTimerFrequency: IntervalTicks=9 -> 2 Hz")
    CALL ResetTimerState
    TimerInterrupt.IsInstalled = 1
    TimerInterrupt.IntervalTicks = 9
    ' 18 \ 9 = 2
    CALL Assert_IsEqual(Timer_GetTimerFrequency, 2, "9 ticks -> 2 Hz")
    TimerInterrupt.IsInstalled = 0
END SUB

' ==============================================================================
' Suite 8 — OnTimer/OffTimer state bookkeeping
' We call the real Timer_OnTimer / Timer_OffTimer to test the IsInstalled flag,
' UserRoutine storage, and double-uninstall guard.  The routines also issue
' DOS int &H21 AX=3508/2508 to get/set the INT 08h vector -- under DOSBox-X
' this is safe (reads/writes the IVT only).  We do NOT wait for any tick.
' ==============================================================================
SUB Test_OnTimer_SetsInstalledFlag
    CALL Test_Case("Timer_OnTimer sets IsInstalled=1")
    CALL ResetTimerState
    CALL Timer_OnTimer(1000, CODEPTR(ResetTimerState))
    CALL Assert_IsEqual(TimerInterrupt.IsInstalled, 1, "IsInstalled set to 1")
    CALL Timer_OffTimer
END SUB

SUB Test_OnTimer_StoresUserRoutine
    CALL Test_Case("Timer_OnTimer stores HandlerRoutine in UserRoutine")
    CALL ResetTimerState
    DIM addr AS DWORD
    addr = CODEPTR(ResetTimerState)
    CALL Timer_OnTimer(500, addr)
    CALL Assert_IsEqual(TimerInterrupt.UserRoutine, addr, "UserRoutine address stored")
    CALL Timer_OffTimer
END SUB

SUB Test_OnTimer_ComputesIntervalTicks
    CALL Test_Case("Timer_OnTimer: 1000ms -> IntervalTicks = 18")
    CALL ResetTimerState
    CALL Timer_OnTimer(1000, CODEPTR(ResetTimerState))
    ' (1000 * 182) \ 10000 = 18
    CALL Assert_IsEqual(TimerInterrupt.IntervalTicks, 18, "IntervalTicks = 18 for 1000ms")
    CALL Timer_OffTimer
END SUB

SUB Test_OnTimer_MinIntervalTicks
    CALL Test_Case("Timer_OnTimer: very short interval -> IntervalTicks clamped to 1")
    CALL ResetTimerState
    ' 10ms: (10 * 182) \ 10000 = 0 -> clamped to 1
    CALL Timer_OnTimer(10, CODEPTR(ResetTimerState))
    CALL Assert_IsEqual(TimerInterrupt.IntervalTicks, 1, "IntervalTicks clamped to 1")
    CALL Timer_OffTimer
END SUB

SUB Test_OnTimer_SavesOldVector
    CALL Test_Case("Timer_OnTimer saves a non-zero OldVector")
    CALL ResetTimerState
    CALL Timer_OnTimer(1000, CODEPTR(ResetTimerState))
    CALL Assert_IsNotZero(TimerInterrupt.OldVector, "OldVector non-zero after install")
    CALL Timer_OffTimer
END SUB

SUB Test_OffTimer_ClearsInstalledFlag
    CALL Test_Case("Timer_OffTimer clears IsInstalled")
    CALL ResetTimerState
    CALL Timer_OnTimer(1000, CODEPTR(ResetTimerState))
    CALL Timer_OffTimer
    CALL Assert_IsEqual(TimerInterrupt.IsInstalled, 0, "IsInstalled cleared")
END SUB

SUB Test_OffTimer_ClearsUserRoutine
    CALL Test_Case("Timer_OffTimer clears UserRoutine")
    CALL ResetTimerState
    CALL Timer_OnTimer(1000, CODEPTR(ResetTimerState))
    CALL Timer_OffTimer
    CALL Assert_IsZero(TimerInterrupt.UserRoutine, "UserRoutine zeroed")
END SUB

SUB Test_OffTimer_DoubleCallIgnored
    CALL Test_Case("Timer_OffTimer is idempotent (second call is no-op)")
    CALL ResetTimerState
    CALL Timer_OnTimer(1000, CODEPTR(ResetTimerState))
    CALL Timer_OffTimer
    ' Second call must not crash and flag stays 0
    CALL Timer_OffTimer
    CALL Assert_IsEqual(TimerInterrupt.IsInstalled, 0, "still 0 after double Off")
END SUB

SUB Test_OnTimer_ReinstallReplacesHandler
    CALL Test_Case("Second Timer_OnTimer implicitly removes the first")
    CALL ResetTimerState
    DIM addr1 AS DWORD, addr2 AS DWORD
    addr1 = CODEPTR(ResetTimerState)
    addr2 = CODEPTR(Timer_Init)
    CALL Timer_OnTimer(200, addr1)
    CALL Timer_OnTimer(500, addr2)
    CALL Assert_IsEqual(TimerInterrupt.UserRoutine, addr2, "UserRoutine updated to addr2")
    CALL Assert_IsEqual(TimerInterrupt.IsInstalled, 1, "still installed after reinstall")
    CALL Timer_OffTimer
END SUB

' ==============================================================================
' Suite 9 — HrTimer state bookkeeping
' Timer_HrTimer issues OUT instructions to the PIT and installs INT 08h.
' We test only state (IntervalTicks=1, UserRoutine, IsInstalled) and
' immediately uninstall + restore to avoid leaving the PIT at high frequency.
' Both tests are merged into one invocation to minimise PIT reprogramming.
' ==============================================================================
SUB Test_HrTimer_StateBookkeeping
    CALL Test_Case("Timer_HrTimer: IntervalTicks=1, UserRoutine stored, IsInstalled=1")
    CALL ResetTimerState
    DIM addr AS DWORD
    addr = CODEPTR(ResetTimerState)
    CALL Timer_HrTimer(100, addr)
    CALL Assert_IsEqual(TimerInterrupt.IntervalTicks, 1, "IntervalTicks=1 for HrTimer")
    CALL Assert_IsEqual(TimerInterrupt.UserRoutine, addr, "UserRoutine set by HrTimer")
    CALL Assert_IsEqual(TimerInterrupt.IsInstalled, 1, "IsInstalled=1 after HrTimer")
    ' Restore default PIT frequency before uninstalling
    CALL Timer_OffTimer
    CALL Timer_Restore
END SUB

' ==============================================================================
' Suite 10 — TimerTickCounter (ISR tick counter, read directly)
' ==============================================================================
SUB Test_TickCounter_StartsAtZero
    CALL Test_Case("TimerTickCounter is 0 after ResetTimerState")
    CALL ResetTimerState
    CALL Assert_IsZero(TimerTickCounter, "TimerTickCounter starts at 0")
END SUB

SUB Test_TickCounter_ManualIncrement
    CALL Test_Case("TimerTickCounter increments as expected (direct write)")
    CALL ResetTimerState
    TimerTickCounter = 5
    CALL Assert_IsEqual(TimerTickCounter, 5, "manual set to 5 preserved")
    TimerTickCounter = TimerTickCounter + 1
    CALL Assert_IsEqual(TimerTickCounter, 6, "manual increment to 6")
END SUB
