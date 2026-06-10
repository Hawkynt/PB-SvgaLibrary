' =============================================================================
' DRAW_ANI.BAS - tests for DRAW_ANI.SUB (in-memory animation state machine)
' =============================================================================
' Tests the Ani_* API: state setup, GetAnimationInfo, GetFrameCount,
' GetFrameDelay, StartAnimation, StopAnimation, IsPlaying, GetAnimationState,
' AdvanceAnimationFrame, FreeAnimation, SetAnimationSpeed, SetAutoCleanup.
' No file I/O -- animation slots are initialised directly via ANIAnimations().
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"

' Forward-declare value-returning functions used before their definition
DECLARE FUNCTION Ani_GetFrameCount(BYVAL animHandle AS BYTE) AS WORD
DECLARE FUNCTION Ani_GetFrameDelay(BYVAL animHandle AS BYTE, BYVAL frameIndex AS WORD) AS WORD
DECLARE FUNCTION Ani_IsPlaying(BYVAL animHandle AS BYTE) AS BYTE
DECLARE FUNCTION Ani_GetAnimationState(BYVAL animHandle AS BYTE) AS BYTE
' Timer stubs -- forward-declare so DRAW_ANI.SUB can call them
DECLARE FUNCTION Timer_GetTimerTick() AS LONG
DECLARE FUNCTION Timer_IsTimerReady(BYVAL timerName AS BYTE) AS BYTE

$INCLUDE "DRAW_ANI.SUB"

' =============================================================================
' Stubs -- satisfy external calls made by DRAW_ANI.SUB code paths
' =============================================================================
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
SUB Svga_FillRect(x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD, c AS BYTE)
    ' stub -- no actual VRAM write needed for state-machine tests
END SUB
SUB Svga_DrawRect(x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD, c AS BYTE)
    ' stub
END SUB
SUB Virtual_ToPhysical(x AS WORD, y AS WORD, px AS WORD, py AS WORD)
    px = x : py = y
END SUB
FUNCTION Virtual_IsVisible(BYVAL x AS WORD, BYVAL y AS WORD) AS BYTE
    Virtual_IsVisible = 1
END FUNCTION
' Timer stubs -- keep tick counter in TimerSystemContext so Ani_* comparisons work
SUB Timer_Init
    TimerSystemContext.IsInitialized = 1
    TimerSystemContext.TickCount = 0
END SUB
FUNCTION Timer_GetTimerTick AS LONG
    IF TimerSystemContext.IsInitialized = 0 THEN CALL Timer_Init
    Timer_GetTimerTick = TimerSystemContext.TickCount
END FUNCTION
SUB Timer_Create(BYVAL timerName AS BYTE, BYVAL delayTicks AS WORD)
    ' stub
END SUB
FUNCTION Timer_IsTimerReady(BYVAL timerName AS BYTE) AS BYTE
    Timer_IsTimerReady = 0
END FUNCTION
SUB Timer_Destroy(BYVAL timerName AS BYTE)
    ' stub
END SUB

' =============================================================================
' Helper: seed a slot directly (no file I/O)
' =============================================================================
FUNCTION MakeAni(BYVAL slot AS BYTE, BYVAL w AS WORD, BYVAL h AS WORD, _
                 BYVAL fc AS WORD, BYVAL hx AS WORD, BYVAL hy AS WORD) AS BYTE
    ANIAnimations(slot).IsLoaded   = 1
    ANIAnimations(slot).Wide       = w
    ANIAnimations(slot).Height     = h
    ANIAnimations(slot).FrameCount = fc
    ANIAnimations(slot).HotspotX   = hx
    ANIAnimations(slot).HotspotY   = hy
    ANIAnimations(slot).FrameDelay = 5
    ANIAnimations(slot).CurrentFrame = 0
    ANIAnimations(slot).LoopCount  = 0
    ANIAnimations(slot).TotalLoops = 0
    ANIAnimations(slot).LastFrameTime = 0
    AnimationStates(slot)          = %ANIM_STATE_STOPPED
    AnimationTimerIDs(slot)        = 255
    AnimationAutoCleanup(slot)     = 0
    MakeAni = slot
END FUNCTION

' Free all slots (clean state between tests)
SUB ClearAllSlots
    DIM i AS BYTE
    FOR i = 0 TO 7
        ANIAnimations(i).IsLoaded = 0
        ANIAnimations(i).FrameCount = 0
        ANIAnimations(i).CurrentFrame = 0
        ANIAnimations(i).LoopCount = 0
        ANIAnimations(i).TotalLoops = 0
        ANIAnimations(i).LastFrameTime = 0
        ANIAnimations(i).Wide = 0
        ANIAnimations(i).Height = 0
        ANIAnimations(i).FrameDelay = 0
        AnimationStates(i) = %ANIM_STATE_STOPPED
        AnimationTimerIDs(i) = 255
        AnimationAutoCleanup(i) = 0
    NEXT i
    TimerSystemContext.TickCount = 0
END SUB

' =============================================================================
' Test_Setup / Test_Teardown
' =============================================================================
SUB Test_Setup
    SVGAScreenContext.XRes = 320
    SVGAScreenContext.YRes = 200
    CALL ClearAllSlots
    ' Enter mode 13h for any ShowFrame pixel checks
    !MOV AX, &H0013
    !INT &H10
END SUB

SUB Test_Teardown
    !MOV AX, &H0003
    !INT &H10
END SUB

' =============================================================================
' HappyPath: slot 0 -- GetAnimationInfo returns seeded values
' =============================================================================
SUB Test_GetAnimationInfo_HappyPath
    CALL Test_Case("GetAnimationInfo returns correct width/height/frameCount/hotspot")
    DIM h AS BYTE, w AS WORD, ht AS WORD, fc AS WORD, hx AS WORD, hy AS WORD
    CALL ClearAllSlots
    h = MakeAni(0, 32, 24, 4, 16, 12)
    CALL Ani_GetAnimationInfo(h, w, ht, fc, hx, hy)
    CALL Assert_IsEqual(w,  32, "width  = 32")
    CALL Assert_IsEqual(ht, 24, "height = 24")
    CALL Assert_IsEqual(fc,  4, "frameCount = 4")
    CALL Assert_IsEqual(hx, 16, "hotX = 16")
    CALL Assert_IsEqual(hy, 12, "hotY = 12")
END SUB

' =============================================================================
' GetAnimationInfo with invalid handle returns zeros
' =============================================================================
SUB Test_GetAnimationInfo_InvalidHandle
    CALL Test_Case("GetAnimationInfo with invalid handle returns zero for all out-params")
    DIM w AS WORD, ht AS WORD, fc AS WORD, hx AS WORD, hy AS WORD
    CALL ClearAllSlots
    CALL Ani_GetAnimationInfo(8, w, ht, fc, hx, hy)   ' handle 8 is out-of-range (max = 7)
    CALL Assert_IsZero(w,  "width=0 for bad handle")
    CALL Assert_IsZero(ht, "height=0 for bad handle")
    CALL Assert_IsZero(fc, "frameCount=0 for bad handle")
END SUB

' =============================================================================
' GetAnimationInfo on unloaded slot returns zeros
' =============================================================================
SUB Test_GetAnimationInfo_UnloadedSlot
    CALL Test_Case("GetAnimationInfo on unloaded slot returns zeros")
    DIM w AS WORD, ht AS WORD, fc AS WORD, hx AS WORD, hy AS WORD
    CALL ClearAllSlots
    ' slot 0 is IsLoaded=0 after ClearAllSlots
    CALL Ani_GetAnimationInfo(0, w, ht, fc, hx, hy)
    CALL Assert_IsZero(w,  "width=0 for unloaded slot")
    CALL Assert_IsZero(fc, "frameCount=0 for unloaded slot")
END SUB

' =============================================================================
' GetFrameCount HappyPath
' =============================================================================
SUB Test_GetFrameCount_HappyPath
    CALL Test_Case("GetFrameCount returns seeded frame count")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 16, 16, 6, 0, 0)
    CALL Assert_IsEqual(Ani_GetFrameCount(h), 6, "frameCount = 6")
END SUB

' =============================================================================
' GetFrameCount with bad handle returns 0
' =============================================================================
SUB Test_GetFrameCount_BadHandle
    CALL Test_Case("GetFrameCount with handle > 7 returns 0")
    CALL ClearAllSlots
    CALL Assert_IsZero(Ani_GetFrameCount(9), "frameCount=0 for handle 9")
END SUB

' =============================================================================
' GetFrameDelay -- global delay falls back when no per-frame rate set
' =============================================================================
SUB Test_GetFrameDelay_GlobalFallback
    CALL Test_Case("GetFrameDelay uses global FrameDelay when no per-frame rate is set")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 3, 0, 0)
    ANIAnimations(h).FrameDelay = 10
    ANIRateData(h, 0) = 0   ' no per-frame rate
    CALL Assert_IsEqual(Ani_GetFrameDelay(h, 0), 10, "global FrameDelay = 10")
END SUB

' =============================================================================
' GetFrameDelay -- per-frame rate overrides global
' =============================================================================
SUB Test_GetFrameDelay_PerFrameRate
    CALL Test_Case("GetFrameDelay returns per-frame rate when set")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 3, 0, 0)
    ANIAnimations(h).FrameDelay = 10
    ANIRateData(h, 1) = 25
    CALL Assert_IsEqual(Ani_GetFrameDelay(h, 1), 25, "per-frame rate = 25")
END SUB

' =============================================================================
' GetFrameDelay with bad handle returns 0
' =============================================================================
SUB Test_GetFrameDelay_BadHandle
    CALL Test_Case("GetFrameDelay with bad handle returns 0")
    CALL ClearAllSlots
    CALL Assert_IsZero(Ani_GetFrameDelay(10, 0), "delay=0 for bad handle")
END SUB

' =============================================================================
' StartAnimation sets state to PLAYING and resets frame to 0
' =============================================================================
SUB Test_StartAnimation_SetsPlayingState
    CALL Test_Case("StartAnimation marks state PLAYING and resets CurrentFrame")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 3, 0, 0)
    ANIAnimations(h).CurrentFrame = 2   ' simulate mid-animation
    CALL Ani_StartAnimation(h, 10, 10, 2, 0)
    CALL Assert_IsEqual(Ani_GetAnimationState(h), %ANIM_STATE_PLAYING, "state = PLAYING")
    CALL Assert_IsZero(ANIAnimations(h).CurrentFrame, "CurrentFrame reset to 0")
    CALL Assert_IsEqual(ANIAnimations(h).LoopCount, 2, "LoopCount = 2")
    CALL Assert_IsEqual(ANIAnimations(h).TotalLoops, 2, "TotalLoops = 2")
END SUB

' =============================================================================
' StartAnimation with infinite loops (0) keeps playing flag
' =============================================================================
SUB Test_StartAnimation_InfiniteLoops
    CALL Test_Case("StartAnimation with loopCount=0 sets infinite play")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    CALL Ani_StartAnimation(h, 0, 0, 0, 0)
    CALL Assert_IsEqual(Ani_GetAnimationState(h), %ANIM_STATE_PLAYING, "state = PLAYING")
    CALL Assert_IsTrue(Ani_IsPlaying(h), "IsPlaying = true for infinite")
END SUB

' =============================================================================
' StartAnimation on bad handle is a no-op
' =============================================================================
SUB Test_StartAnimation_BadHandle
    CALL Test_Case("StartAnimation on bad handle does not crash")
    CALL ClearAllSlots
    CALL Ani_StartAnimation(8, 0, 0, 1, 0)   ' handle 8 out-of-range -- should no-op
    CALL Assert_IsTrue(1, "survived bad-handle call")
END SUB

' =============================================================================
' IsPlaying: true when playing, false when stopped/finished
' =============================================================================
SUB Test_IsPlaying_AfterStart
    CALL Test_Case("IsPlaying true immediately after StartAnimation")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    CALL Ani_StartAnimation(h, 0, 0, 1, 0)
    CALL Assert_IsTrue(Ani_IsPlaying(h), "IsPlaying = true after Start")
END SUB

' =============================================================================
' IsPlaying: false after StopAnimation (regression for TotalLoops=0 bug)
' =============================================================================
SUB Test_IsPlaying_AfterStop
    CALL Test_Case("IsPlaying false after StopAnimation even when TotalLoops=0")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    CALL Ani_StartAnimation(h, 0, 0, 0, 0)   ' infinite
    CALL Assert_IsTrue(Ani_IsPlaying(h), "IsPlaying true while infinite")
    CALL Ani_StopAnimation(h)
    CALL Assert_IsFalse(Ani_IsPlaying(h), "IsPlaying false after Stop (TotalLoops=0 case)")
END SUB

' =============================================================================
' StopAnimation resets CurrentFrame to 0 and state to STOPPED
' =============================================================================
SUB Test_StopAnimation_ResetsState
    CALL Test_Case("StopAnimation resets CurrentFrame and sets STOPPED state")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 4, 0, 0)
    CALL Ani_StartAnimation(h, 0, 0, 2, 0)
    ANIAnimations(h).CurrentFrame = 3
    CALL Ani_StopAnimation(h)
    CALL Assert_IsZero(ANIAnimations(h).CurrentFrame, "CurrentFrame = 0 after Stop")
    CALL Assert_IsEqual(Ani_GetAnimationState(h), %ANIM_STATE_STOPPED, "state = STOPPED")
    CALL Assert_IsZero(ANIAnimations(h).LoopCount, "LoopCount = 0 after Stop")
END SUB

' =============================================================================
' StopAnimation on bad/unloaded handle is a no-op
' =============================================================================
SUB Test_StopAnimation_BadHandle
    CALL Test_Case("StopAnimation on bad handle does not crash")
    CALL ClearAllSlots
    CALL Ani_StopAnimation(8)    ' out-of-range
    CALL Assert_IsTrue(1, "survived bad-handle stop")
    CALL Ani_StopAnimation(0)    ' IsLoaded = 0 --> also a no-op
    CALL Assert_IsTrue(1, "survived unloaded-slot stop")
END SUB

' =============================================================================
' AdvanceAnimationFrame: advances CurrentFrame and wraps at FrameCount
' =============================================================================
SUB Test_AdvanceFrame_Wraps
    CALL Test_Case("AdvanceAnimationFrame increments and wraps at FrameCount")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 3, 0, 0)
    CALL Ani_StartAnimation(h, 0, 0, 0, 0)   ' infinite so wrap keeps PLAYING
    ANIAnimations(h).CurrentFrame = 0
    CALL AdvanceAnimationFrame(h)
    CALL Assert_IsEqual(ANIAnimations(h).CurrentFrame, 1, "frame 0 -> 1")
    CALL AdvanceAnimationFrame(h)
    CALL Assert_IsEqual(ANIAnimations(h).CurrentFrame, 2, "frame 1 -> 2")
    CALL AdvanceAnimationFrame(h)
    CALL Assert_IsEqual(ANIAnimations(h).CurrentFrame, 0, "frame 2 wraps to 0 (FrameCount=3)")
END SUB

' =============================================================================
' AdvanceAnimationFrame: finite loop -- FINISHED when LoopCount reaches 0
' =============================================================================
SUB Test_AdvanceFrame_FiniteLoop_Stops
    CALL Test_Case("AdvanceAnimationFrame sets FINISHED after last loop completes")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    CALL Ani_StartAnimation(h, 0, 0, 1, 0)   ' 1 loop
    ' Advance through both frames of the one loop
    CALL AdvanceAnimationFrame(h)   ' frame 0->1
    CALL AdvanceAnimationFrame(h)   ' frame 1->2 => wrap => LoopCount 1->0 => FINISHED
    CALL Assert_IsEqual(Ani_GetAnimationState(h), %ANIM_STATE_FINISHED, "state = FINISHED after 1 loop")
    CALL Assert_IsZero(ANIAnimations(h).CurrentFrame, "CurrentFrame reset to 0 after loop")
END SUB

' =============================================================================
' AdvanceAnimationFrame: infinite loop -- stays PLAYING after wrapping
' =============================================================================
SUB Test_AdvanceFrame_InfiniteLoop_Continues
    CALL Test_Case("AdvanceAnimationFrame infinite loop stays PLAYING after wrap")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    CALL Ani_StartAnimation(h, 0, 0, 0, 0)   ' infinite (loopCount=0)
    CALL AdvanceAnimationFrame(h)   ' 0->1
    CALL AdvanceAnimationFrame(h)   ' 1->2 => wrap
    CALL Assert_IsEqual(Ani_GetAnimationState(h), %ANIM_STATE_PLAYING, "still PLAYING after wrap (infinite)")
    CALL Assert_IsZero(ANIAnimations(h).CurrentFrame, "frame wrapped back to 0")
END SUB

' =============================================================================
' GetAnimationState: STOPPED on unloaded slot
' =============================================================================
SUB Test_GetAnimationState_UnloadedSlot
    CALL Test_Case("GetAnimationState returns STOPPED for unloaded/bad handle")
    CALL ClearAllSlots
    CALL Assert_IsEqual(Ani_GetAnimationState(0), %ANIM_STATE_STOPPED, "unloaded slot = STOPPED")
    CALL Assert_IsEqual(Ani_GetAnimationState(8), %ANIM_STATE_STOPPED, "bad handle = STOPPED")
END SUB

' =============================================================================
' FreeAnimation clears slot so GetFrameCount returns 0
' =============================================================================
SUB Test_FreeAnimation_ClearsSlot
    CALL Test_Case("FreeAnimation zeroes IsLoaded so GetFrameCount returns 0")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 16, 16, 5, 8, 8)
    CALL Assert_IsEqual(Ani_GetFrameCount(h), 5, "5 frames before free")
    CALL Ani_FreeAnimation(h)
    CALL Assert_IsZero(Ani_GetFrameCount(h), "0 frames after free")
    CALL Assert_IsZero(ANIAnimations(h).IsLoaded, "IsLoaded = 0 after free")
END SUB

' =============================================================================
' FreeAnimation clears per-frame rate data
' =============================================================================
SUB Test_FreeAnimation_ClearsRateData
    CALL Test_Case("FreeAnimation zeroes ANIRateData for the slot")
    DIM h AS BYTE, i AS INTEGER
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 3, 0, 0)
    ANIRateData(h, 0) = 20
    ANIRateData(h, 2) = 15
    CALL Ani_FreeAnimation(h)
    CALL Assert_IsZero(ANIRateData(h, 0), "RateData[0] cleared")
    CALL Assert_IsZero(ANIRateData(h, 2), "RateData[2] cleared")
END SUB

' =============================================================================
' FreeAnimation on bad handle is a no-op
' =============================================================================
SUB Test_FreeAnimation_BadHandle
    CALL Test_Case("FreeAnimation with handle > 7 does not crash")
    CALL ClearAllSlots
    CALL Ani_FreeAnimation(8)
    CALL Assert_IsTrue(1, "survived bad-handle free")
END SUB

' =============================================================================
' SetAnimationSpeed adjusts FrameDelay
' =============================================================================
SUB Test_SetAnimationSpeed_HalfSpeed
    CALL Test_Case("SetAnimationSpeed 50 doubles the FrameDelay")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    ANIAnimations(h).FrameDelay = 10
    CALL Ani_SetAnimationSpeed(h, 50)    ' half speed -> delay doubled
    CALL Assert_IsEqual(ANIAnimations(h).FrameDelay, 20, "FrameDelay = 20 at half speed")
END SUB

SUB Test_SetAnimationSpeed_DoubleSpeed
    CALL Test_Case("SetAnimationSpeed 200 halves the FrameDelay")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    ANIAnimations(h).FrameDelay = 20
    CALL Ani_SetAnimationSpeed(h, 200)   ' double speed -> delay halved
    CALL Assert_IsEqual(ANIAnimations(h).FrameDelay, 10, "FrameDelay = 10 at double speed")
END SUB

SUB Test_SetAnimationSpeed_ZeroGuard
    CALL Test_Case("SetAnimationSpeed 0 is treated as 100 (no-op for delay)")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    ANIAnimations(h).FrameDelay = 10
    CALL Ani_SetAnimationSpeed(h, 0)    ' guard: treated as 100
    CALL Assert_IsEqual(ANIAnimations(h).FrameDelay, 10, "FrameDelay unchanged with speed=0 guard")
END SUB

' =============================================================================
' SetAutoCleanup stores the flag
' =============================================================================
SUB Test_SetAutoCleanup
    CALL Test_Case("SetAutoCleanup stores flag; ignored for bad handle")
    CALL ClearAllSlots
    CALL Ani_SetAutoCleanup(0, 1)
    CALL Assert_IsNotZero(AnimationAutoCleanup(0), "AutoCleanup flag set for slot 0")
    CALL Ani_SetAutoCleanup(0, 0)
    CALL Assert_IsZero(AnimationAutoCleanup(0), "AutoCleanup flag cleared for slot 0")
    CALL Ani_SetAutoCleanup(8, 1)   ' out-of-range -- no-op, should not crash
    CALL Assert_IsTrue(1, "survived bad-handle SetAutoCleanup")
END SUB

' =============================================================================
' Multiple slots: up to 8 independent animations
' =============================================================================
SUB Test_MultipleSlots
    CALL Test_Case("Up to 8 independent animation slots can coexist")
    DIM i AS BYTE
    CALL ClearAllSlots
    FOR i = 0 TO 7
        DIM dummy AS BYTE
        dummy = MakeAni(i, i + 1, i + 2, i + 1, 0, 0)
    NEXT i
    FOR i = 0 TO 7
        CALL Assert_IsEqual(ANIAnimations(i).Wide, i + 1, "slot " + STR$(i) + " width ok")
        CALL Assert_IsEqual(Ani_GetFrameCount(i), i + 1, "slot " + STR$(i) + " frameCount ok")
    NEXT i
END SUB

' =============================================================================
' ResetAnimation restores frame to 0 without changing state
' =============================================================================
SUB Test_ResetAnimation
    CALL Test_Case("ResetAnimation resets CurrentFrame to 0")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 4, 0, 0)
    CALL Ani_StartAnimation(h, 0, 0, 0, 0)
    ANIAnimations(h).CurrentFrame = 3
    CALL Ani_ResetAnimation(h)
    CALL Assert_IsZero(ANIAnimations(h).CurrentFrame, "CurrentFrame = 0 after Reset")
END SUB

' =============================================================================
' Boundary: frame index at exact FrameCount wraps in ShowFrame
' =============================================================================
SUB Test_ShowFrame_OobFrameWraps
    CALL Test_Case("ShowFrame wraps out-of-range frameIndex to 0")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 4, 4, 3, 0, 0)
    ANIAnimations(h).FrameDelay = 1
    ' frameIndex == FrameCount (3) -> should be clamped to 0 inside ShowFrame
    CALL Ani_ShowFrame(h, 50, 50, 3)
    CALL Assert_IsEqual(ANIAnimations(h).CurrentFrame, 0, "out-of-range frame clamped to 0")
END SUB

' =============================================================================
' Exception: ShowFrame on bad handle is a no-op
' =============================================================================
SUB Test_ShowFrame_BadHandle
    CALL Test_Case("ShowFrame on bad/unloaded handle is a no-op")
    CALL ClearAllSlots
    CALL Ani_ShowFrame(8, 10, 10, 0)   ' handle 8 out-of-range
    CALL Assert_IsTrue(1, "survived bad-handle ShowFrame")
    CALL Ani_ShowFrame(0, 10, 10, 0)   ' IsLoaded = 0 --> also a no-op
    CALL Assert_IsTrue(1, "survived unloaded-slot ShowFrame")
END SUB
