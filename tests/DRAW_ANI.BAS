' =============================================================================
' DRAW_ANI.BAS - tests for DRAW_ANI.SUB (in-memory animation state machine)
' =============================================================================
' Tests the DrawAni_* API: state setup, GetAnimationInfo, GetFrameCount,
' GetFrameDelay, StartAnimation, StopAnimation, IsPlaying, GetAnimationState,
' DrawAni_AdvanceFrame, FreeAnimation, SetAnimationSpeed, SetAutoCleanup.
' No file I/O -- animation slots are initialised directly via ANIAnimations().
' =============================================================================
$INCLUDE "TESTLIB.BI"
$INCLUDE "TYPES.SUB"
$INCLUDE "VGA.SUB"

' Forward-declare value-returning functions used before their definition
DECLARE FUNCTION DrawAni_GetFrameCount(BYVAL animHandle AS BYTE) AS WORD
DECLARE FUNCTION DrawAni_GetFrameDelay(BYVAL animHandle AS BYTE, BYVAL frameIndex AS WORD) AS WORD
DECLARE FUNCTION DrawAni_IsPlaying(BYVAL animHandle AS BYTE) AS BYTE
DECLARE FUNCTION DrawAni_GetAnimationState(BYVAL animHandle AS BYTE) AS BYTE
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
' Timer stubs -- keep tick counter in TimerSystemContext so DrawAni_* comparisons work
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
    CALL DrawAni_GetAnimationInfo(h, w, ht, fc, hx, hy)
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
    CALL DrawAni_GetAnimationInfo(8, w, ht, fc, hx, hy)   ' handle 8 is out-of-range (max = 7)
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
    CALL DrawAni_GetAnimationInfo(0, w, ht, fc, hx, hy)
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
    CALL Assert_IsEqual(DrawAni_GetFrameCount(h), 6, "frameCount = 6")
END SUB

' =============================================================================
' GetFrameCount with bad handle returns 0
' =============================================================================
SUB Test_GetFrameCount_BadHandle
    CALL Test_Case("GetFrameCount with handle > 7 returns 0")
    CALL ClearAllSlots
    CALL Assert_IsZero(DrawAni_GetFrameCount(9), "frameCount=0 for handle 9")
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
    CALL Assert_IsEqual(DrawAni_GetFrameDelay(h, 0), 10, "global FrameDelay = 10")
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
    CALL Assert_IsEqual(DrawAni_GetFrameDelay(h, 1), 25, "per-frame rate = 25")
END SUB

' =============================================================================
' GetFrameDelay with bad handle returns 0
' =============================================================================
SUB Test_GetFrameDelay_BadHandle
    CALL Test_Case("GetFrameDelay with bad handle returns 0")
    CALL ClearAllSlots
    CALL Assert_IsZero(DrawAni_GetFrameDelay(10, 0), "delay=0 for bad handle")
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
    CALL DrawAni_StartAnimation(h, 10, 10, 2, 0)
    CALL Assert_IsEqual(DrawAni_GetAnimationState(h), %ANIM_STATE_PLAYING, "state = PLAYING")
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
    CALL DrawAni_StartAnimation(h, 0, 0, 0, 0)
    CALL Assert_IsEqual(DrawAni_GetAnimationState(h), %ANIM_STATE_PLAYING, "state = PLAYING")
    CALL Assert_IsTrue(DrawAni_IsPlaying(h), "IsPlaying = true for infinite")
END SUB

' =============================================================================
' StartAnimation on bad handle is a no-op
' =============================================================================
SUB Test_StartAnimation_BadHandle
    CALL Test_Case("StartAnimation on bad handle does not crash")
    CALL ClearAllSlots
    CALL DrawAni_StartAnimation(8, 0, 0, 1, 0)   ' handle 8 out-of-range -- should no-op
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
    CALL DrawAni_StartAnimation(h, 0, 0, 1, 0)
    CALL Assert_IsTrue(DrawAni_IsPlaying(h), "IsPlaying = true after Start")
END SUB

' =============================================================================
' IsPlaying: false after StopAnimation even with TotalLoops=0 (infinite)
' =============================================================================
SUB Test_IsPlaying_AfterStop
    CALL Test_Case("IsPlaying false after StopAnimation even when TotalLoops=0")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    CALL DrawAni_StartAnimation(h, 0, 0, 0, 0)   ' infinite
    CALL Assert_IsTrue(DrawAni_IsPlaying(h), "IsPlaying true while infinite")
    CALL DrawAni_StopAnimation(h)
    CALL Assert_IsFalse(DrawAni_IsPlaying(h), "IsPlaying false after Stop (TotalLoops=0 case)")
END SUB

' =============================================================================
' StopAnimation resets CurrentFrame to 0 and state to STOPPED
' =============================================================================
SUB Test_StopAnimation_ResetsState
    CALL Test_Case("StopAnimation resets CurrentFrame and sets STOPPED state")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 4, 0, 0)
    CALL DrawAni_StartAnimation(h, 0, 0, 2, 0)
    ANIAnimations(h).CurrentFrame = 3
    CALL DrawAni_StopAnimation(h)
    CALL Assert_IsZero(ANIAnimations(h).CurrentFrame, "CurrentFrame = 0 after Stop")
    CALL Assert_IsEqual(DrawAni_GetAnimationState(h), %ANIM_STATE_STOPPED, "state = STOPPED")
    CALL Assert_IsZero(ANIAnimations(h).LoopCount, "LoopCount = 0 after Stop")
END SUB

' =============================================================================
' StopAnimation on bad/unloaded handle is a no-op
' =============================================================================
SUB Test_StopAnimation_BadHandle
    CALL Test_Case("StopAnimation on bad handle does not crash")
    CALL ClearAllSlots
    CALL DrawAni_StopAnimation(8)    ' out-of-range
    CALL Assert_IsTrue(1, "survived bad-handle stop")
    CALL DrawAni_StopAnimation(0)    ' IsLoaded = 0 --> also a no-op
    CALL Assert_IsTrue(1, "survived unloaded-slot stop")
END SUB

' =============================================================================
' DrawAni_AdvanceFrame: advances CurrentFrame and wraps at FrameCount
' =============================================================================
SUB Test_AdvanceFrame_Wraps
    CALL Test_Case("DrawAni_AdvanceFrame increments and wraps at FrameCount")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 3, 0, 0)
    CALL DrawAni_StartAnimation(h, 0, 0, 0, 0)   ' infinite so wrap keeps PLAYING
    ANIAnimations(h).CurrentFrame = 0
    CALL DrawAni_AdvanceFrame(h)
    CALL Assert_IsEqual(ANIAnimations(h).CurrentFrame, 1, "frame 0 -> 1")
    CALL DrawAni_AdvanceFrame(h)
    CALL Assert_IsEqual(ANIAnimations(h).CurrentFrame, 2, "frame 1 -> 2")
    CALL DrawAni_AdvanceFrame(h)
    CALL Assert_IsEqual(ANIAnimations(h).CurrentFrame, 0, "frame 2 wraps to 0 (FrameCount=3)")
END SUB

' =============================================================================
' DrawAni_AdvanceFrame: finite loop -- FINISHED when LoopCount reaches 0
' =============================================================================
SUB Test_AdvanceFrame_FiniteLoop_Stops
    CALL Test_Case("DrawAni_AdvanceFrame sets FINISHED after last loop completes")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    CALL DrawAni_StartAnimation(h, 0, 0, 1, 0)   ' 1 loop
    ' Advance through both frames of the one loop
    CALL DrawAni_AdvanceFrame(h)   ' frame 0->1
    CALL DrawAni_AdvanceFrame(h)   ' frame 1->2 => wrap => LoopCount 1->0 => FINISHED
    CALL Assert_IsEqual(DrawAni_GetAnimationState(h), %ANIM_STATE_FINISHED, "state = FINISHED after 1 loop")
    CALL Assert_IsZero(ANIAnimations(h).CurrentFrame, "CurrentFrame reset to 0 after loop")
END SUB

' =============================================================================
' DrawAni_AdvanceFrame: infinite loop -- stays PLAYING after wrapping
' =============================================================================
SUB Test_AdvanceFrame_InfiniteLoop_Continues
    CALL Test_Case("DrawAni_AdvanceFrame infinite loop stays PLAYING after wrap")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    CALL DrawAni_StartAnimation(h, 0, 0, 0, 0)   ' infinite (loopCount=0)
    CALL DrawAni_AdvanceFrame(h)   ' 0->1
    CALL DrawAni_AdvanceFrame(h)   ' 1->2 => wrap
    CALL Assert_IsEqual(DrawAni_GetAnimationState(h), %ANIM_STATE_PLAYING, "still PLAYING after wrap (infinite)")
    CALL Assert_IsZero(ANIAnimations(h).CurrentFrame, "frame wrapped back to 0")
END SUB

' =============================================================================
' GetAnimationState: STOPPED on unloaded slot
' =============================================================================
SUB Test_GetAnimationState_UnloadedSlot
    CALL Test_Case("GetAnimationState returns STOPPED for unloaded/bad handle")
    CALL ClearAllSlots
    CALL Assert_IsEqual(DrawAni_GetAnimationState(0), %ANIM_STATE_STOPPED, "unloaded slot = STOPPED")
    CALL Assert_IsEqual(DrawAni_GetAnimationState(8), %ANIM_STATE_STOPPED, "bad handle = STOPPED")
END SUB

' =============================================================================
' FreeAnimation clears slot so GetFrameCount returns 0
' =============================================================================
SUB Test_FreeAnimation_ClearsSlot
    CALL Test_Case("FreeAnimation zeroes IsLoaded so GetFrameCount returns 0")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 16, 16, 5, 8, 8)
    CALL Assert_IsEqual(DrawAni_GetFrameCount(h), 5, "5 frames before free")
    CALL DrawAni_FreeAnimation(h)
    CALL Assert_IsZero(DrawAni_GetFrameCount(h), "0 frames after free")
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
    CALL DrawAni_FreeAnimation(h)
    CALL Assert_IsZero(ANIRateData(h, 0), "RateData[0] cleared")
    CALL Assert_IsZero(ANIRateData(h, 2), "RateData[2] cleared")
END SUB

' =============================================================================
' FreeAnimation on bad handle is a no-op
' =============================================================================
SUB Test_FreeAnimation_BadHandle
    CALL Test_Case("FreeAnimation with handle > 7 does not crash")
    CALL ClearAllSlots
    CALL DrawAni_FreeAnimation(8)
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
    CALL DrawAni_SetAnimationSpeed(h, 50)    ' half speed -> delay doubled
    CALL Assert_IsEqual(ANIAnimations(h).FrameDelay, 20, "FrameDelay = 20 at half speed")
END SUB

SUB Test_SetAnimationSpeed_DoubleSpeed
    CALL Test_Case("SetAnimationSpeed 200 halves the FrameDelay")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    ANIAnimations(h).FrameDelay = 20
    CALL DrawAni_SetAnimationSpeed(h, 200)   ' double speed -> delay halved
    CALL Assert_IsEqual(ANIAnimations(h).FrameDelay, 10, "FrameDelay = 10 at double speed")
END SUB

SUB Test_SetAnimationSpeed_ZeroGuard
    CALL Test_Case("SetAnimationSpeed 0 is treated as 100 (no-op for delay)")
    DIM h AS BYTE
    CALL ClearAllSlots
    h = MakeAni(0, 8, 8, 2, 0, 0)
    ANIAnimations(h).FrameDelay = 10
    CALL DrawAni_SetAnimationSpeed(h, 0)    ' guard: treated as 100
    CALL Assert_IsEqual(ANIAnimations(h).FrameDelay, 10, "FrameDelay unchanged with speed=0 guard")
END SUB

' =============================================================================
' SetAutoCleanup stores the flag
' =============================================================================
SUB Test_SetAutoCleanup
    CALL Test_Case("SetAutoCleanup stores flag; ignored for bad handle")
    CALL ClearAllSlots
    CALL DrawAni_SetAutoCleanup(0, 1)
    CALL Assert_IsNotZero(AnimationAutoCleanup(0), "AutoCleanup flag set for slot 0")
    CALL DrawAni_SetAutoCleanup(0, 0)
    CALL Assert_IsZero(AnimationAutoCleanup(0), "AutoCleanup flag cleared for slot 0")
    CALL DrawAni_SetAutoCleanup(8, 1)   ' out-of-range -- no-op, should not crash
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
        CALL Assert_IsEqual(DrawAni_GetFrameCount(i), i + 1, "slot " + STR$(i) + " frameCount ok")
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
    CALL DrawAni_StartAnimation(h, 0, 0, 0, 0)
    ANIAnimations(h).CurrentFrame = 3
    CALL DrawAni_ResetAnimation(h)
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
    CALL DrawAni_ShowFrame(h, 50, 50, 3)
    CALL Assert_IsEqual(ANIAnimations(h).CurrentFrame, 0, "out-of-range frame clamped to 0")
END SUB

' =============================================================================
' Exception: ShowFrame on bad handle is a no-op
' =============================================================================
SUB Test_ShowFrame_BadHandle
    CALL Test_Case("ShowFrame on bad/unloaded handle is a no-op")
    CALL ClearAllSlots
    CALL DrawAni_ShowFrame(8, 10, 10, 0)   ' handle 8 out-of-range
    CALL Assert_IsTrue(1, "survived bad-handle ShowFrame")
    CALL DrawAni_ShowFrame(0, 10, 10, 0)   ' IsLoaded = 0 --> also a no-op
    CALL Assert_IsTrue(1, "survived unloaded-slot ShowFrame")
END SUB

' =============================================================================
' Binary helpers for building fixture files
' =============================================================================
FUNCTION LE16A(BYVAL v AS WORD) AS STRING
    LE16A = CHR$(v AND 255) + CHR$((v \ 256) AND 255)
END FUNCTION
FUNCTION LE32A(BYVAL v AS LONG) AS STRING
    LE32A = CHR$(v AND 255) + CHR$((v \ 256) AND 255) + _
            CHR$((v \ 65536) AND 255) + CHR$((v \ 16777216) AND 255)
END FUNCTION

' Build a single-frame 4x4 4-bit CUR payload (as a string, not a file).
' Palette: index 0=black(0), index 3=colour 3, index 7=colour 7, others=0.
' XOR pattern (top-down screen order, stored bottom-up in file):
'   row 0: pixels 3, 3, 3, 3   (all index 3)
'   row 1: pixels 7, 7, 7, 7   (all index 7)
'   row 2: pixels 3, 7, 3, 7
'   row 3: pixels 7, 3, 7, 3
' AND mask: all opaque (0).
' Hotspot: (0, 0), kind=2 (CUR), width=4 height=4.
FUNCTION MakeCurPayload4x4_4bit() AS STRING
    DIM hdr AS STRING, entry AS STRING, bih AS STRING
    DIM pal AS STRING, xorData AS STRING, andData AS STRING
    DIM imageOffset AS LONG, bytesInRes AS LONG
    DIM i AS INTEGER

    imageOffset = 22   ' 6-byte CUR header + 16-byte directory entry
    ' BIH(40) + palette(16*4=64) + XOR(4 bytes/row * 4 rows = 16) + AND(4 bytes/row * 4 rows = 16)
    bytesInRes = 40 + 64 + 16 + 16

    hdr   = LE16A(0) + LE16A(2) + LE16A(1)   ' reserved=0, kind=2 (CUR), count=1
    entry = CHR$(4) + CHR$(4) + CHR$(16) + CHR$(0) + _
            LE16A(0) + LE16A(0) + _           ' hotX=0, hotY=0
            LE32A(bytesInRes) + LE32A(imageOffset)

    ' BITMAPINFOHEADER: biHeight doubled (4 XOR + 4 AND rows)
    bih = LE32A(40) + LE32A(4) + LE32A(8) + LE16A(1) + LE16A(4) + _
          LE32A(0) + LE32A(0) + LE32A(0) + LE32A(0) + LE32A(0) + LE32A(0)

    ' 16-entry BGRA palette: entry i = (B=i, G=i, R=i, A=0)
    pal = ""
    FOR i = 0 TO 15
        pal = pal + CHR$(i) + CHR$(i) + CHR$(i) + CHR$(0)
    NEXT i

    ' XOR data (bottom-up: file-row 0 = screen row 3, file-row 3 = screen row 0)
    ' Each row: 4 nibbles packed into 2 bytes, padded to 4 bytes (DWORD-aligned).
    ' Screen row 3 (file-row 0): 7,3,7,3  -> nibbles: &H73 &H73 + 2 pad
    ' Screen row 2 (file-row 1): 3,7,3,7  -> &H37 &H37 + 2 pad
    ' Screen row 1 (file-row 2): 7,7,7,7  -> &H77 &H77 + 2 pad
    ' Screen row 0 (file-row 3): 3,3,3,3  -> &H33 &H33 + 2 pad
    xorData = CHR$(&H73) + CHR$(&H73) + CHR$(0) + CHR$(0)  ' file-row 0 (screen row 3)
    xorData = xorData + CHR$(&H37) + CHR$(&H37) + CHR$(0) + CHR$(0)  ' screen row 2
    xorData = xorData + CHR$(&H77) + CHR$(&H77) + CHR$(0) + CHR$(0)  ' screen row 1
    xorData = xorData + CHR$(&H33) + CHR$(&H33) + CHR$(0) + CHR$(0)  ' screen row 0

    ' AND mask: all opaque (bit=0)
    andData = STRING$(16, CHR$(0))

    MakeCurPayload4x4_4bit = hdr + entry + bih + pal + xorData + andData
END FUNCTION

' Write a spec-true 1-frame ANI file to disk.
' The single icon chunk is a 4x4 4-bit CUR (see MakeCurPayload4x4_4bit).
SUB MakeAniFile_1frame(BYVAL fileName AS STRING)
    DIM iconPayload AS STRING
    DIM anihPayload AS STRING
    DIM ratePayload AS STRING
    DIM listInner AS STRING, listChunk AS STRING
    DIM anihChunk AS STRING, rateChunk AS STRING
    DIM iconChunk AS STRING, riffBody AS STRING, riff AS STRING
    DIM iconSize AS LONG, listSize AS LONG, riffBodySize AS LONG

    iconPayload = MakeCurPayload4x4_4bit()
    iconSize = LEN(iconPayload)

    ' icon chunk: "icon" + LE32(size) + payload
    iconChunk = "icon" + LE32A(iconSize) + iconPayload
    ' WORD-align icon chunk (iconSize already even for our fixture)

    ' LIST/fram inner: type tag "fram" + icon chunk(s)
    listInner = "fram" + iconChunk
    listSize = LEN(listInner)
    listChunk = "LIST" + LE32A(listSize) + listInner

    ' anih chunk: 36-byte ANIHeaderType
    anihPayload = LE32A(36) + LE32A(1) + LE32A(1) + LE32A(4) + LE32A(4) + _
                  LE32A(4) + LE32A(1) + LE32A(6) + LE32A(0)
    anihChunk = "anih" + LE32A(36) + anihPayload

    ' rate chunk: 1 DWORD
    ratePayload = LE32A(6)
    rateChunk = "rate" + LE32A(4) + ratePayload

    ' Assemble RIFF body
    riffBody = "ACON" + anihChunk + rateChunk + listChunk
    riffBodySize = LEN(riffBody)
    riff = "RIFF" + LE32A(riffBodySize) + riffBody

    OPEN fileName FOR BINARY AS #7
    PUT$ #7, riff
    CLOSE #7
END SUB

' Helper: read one pixel from the VGA framebuffer at (x,y)
FUNCTION GetP_Ani(BYVAL x AS WORD, BYVAL y AS WORD) AS INTEGER
    DIM xv AS WORD, yv AS WORD, rv AS BYTE
    xv = x : yv = y : rv = 0
    CALL Vga_GetPixel(xv, yv, rv)
    GetP_Ani = rv
END FUNCTION

' =============================================================================
' LoadAnimation: spec-true ANI reads RIFF correctly (0-based fix)
' =============================================================================
SUB Test_LoadAnimation_SpecTrueANI
    CALL Test_Case("LoadAnimation on spec-true ANI returns valid handle with correct frame count")
    CALL ClearAllSlots
    CALL MakeAniFile_1frame("TANI1.ANI")
    DIM h AS BYTE
    h = DrawAni_LoadAnimation("TANI1.ANI")
    CALL Assert_AreNotEqual(h, 255, "handle <> 255 (load succeeded)")
    CALL Assert_IsEqual(DrawAni_GetFrameCount(h), 1, "FrameCount = 1 from anih chunk")
    CALL Assert_IsEqual(ANIAnimations(h).Wide, 4, "Wide = 4 from anih chunk")
    CALL Assert_IsEqual(ANIAnimations(h).Height, 4, "Height = 4 from anih chunk")
    CALL Assert_IsNotZero(ANIFrameOffStore(h, 0), "frame 0 offset recorded (not 0)")
    CALL Assert_IsNotZero(ANIFrameSizStore(h, 0), "frame 0 size recorded (not 0)")
    IF h < 8 THEN CALL DrawAni_FreeAnimation(h)
END SUB

' =============================================================================
' LoadAnimation: file with wrong RIFF magic returns 255
' =============================================================================
SUB Test_LoadAnimation_BadMagic
    CALL Test_Case("LoadAnimation returns 255 when RIFF magic is wrong")
    CALL ClearAllSlots
    OPEN "TBAD.ANI" FOR BINARY AS #8
    PUT$ #8, "XXXX" + LE32A(4) + "ACON"
    CLOSE #8
    CALL Assert_IsEqual(DrawAni_LoadAnimation("TBAD.ANI"), 255, "bad magic -> 255")
END SUB

' =============================================================================
' ShowFrame: decodes 4-bit CUR icon chunk and draws correct opaque pixels
' =============================================================================
SUB Test_ShowFrame_RealPixels
    CALL Test_Case("ShowFrame draws decoded 4-bit icon pixels at correct screen positions")
    CALL ClearAllSlots
    ' Fill background with colour 99 so we can distinguish undrawn pixels
    DIM bx AS WORD, by AS WORD
    FOR by = 0 TO 9
        FOR bx = 0 TO 9
            CALL Vga_PutPixel(bx, by, 99)
        NEXT bx
    NEXT by

    CALL MakeAniFile_1frame("TANI1.ANI")
    DIM h AS BYTE
    h = DrawAni_LoadAnimation("TANI1.ANI")
    IF h = 255 THEN
        CALL Assert_IsTrue(0, "load failed -- cannot test ShowFrame pixels")
        EXIT SUB
    END IF

    ' Draw frame 0 at (0,0).  hotspot (0,0) -> no offset adjustment.
    ' Screen row 0 = index 3 for all 4 columns.
    ' Screen row 1 = index 7 for all 4 columns.
    CALL DrawAni_ShowFrame(h, 0, 0, 0)

    ' Row 0 (screen y=0): all pixels = palette index 3
    CALL Assert_IsEqual(GetP_Ani(0, 0), 3, "ShowFrame row0 col0 = palette index 3")
    CALL Assert_IsEqual(GetP_Ani(1, 0), 3, "ShowFrame row0 col1 = palette index 3")
    CALL Assert_IsEqual(GetP_Ani(3, 0), 3, "ShowFrame row0 col3 = palette index 3")
    ' Row 1 (screen y=1): all pixels = palette index 7
    CALL Assert_IsEqual(GetP_Ani(0, 1), 7, "ShowFrame row1 col0 = palette index 7")
    CALL Assert_IsEqual(GetP_Ani(3, 1), 7, "ShowFrame row1 col3 = palette index 7")
    ' Row 2 (screen y=2): alternating 3,7,3,7
    CALL Assert_IsEqual(GetP_Ani(0, 2), 3, "ShowFrame row2 col0 = 3")
    CALL Assert_IsEqual(GetP_Ani(1, 2), 7, "ShowFrame row2 col1 = 7")
    CALL Assert_IsEqual(GetP_Ani(2, 2), 3, "ShowFrame row2 col2 = 3")
    CALL Assert_IsEqual(GetP_Ani(3, 2), 7, "ShowFrame row2 col3 = 7")
    ' Row 3 (screen y=3): alternating 7,3,7,3
    CALL Assert_IsEqual(GetP_Ani(0, 3), 7, "ShowFrame row3 col0 = 7")
    CALL Assert_IsEqual(GetP_Ani(1, 3), 3, "ShowFrame row3 col1 = 3")

    IF h < 8 THEN CALL DrawAni_FreeAnimation(h)
END SUB

' =============================================================================
' ShowFrame transparency: AND-masked pixel is not overwritten
' =============================================================================
SUB Test_ShowFrame_Transparency
    CALL Test_Case("ShowFrame respects AND mask: transparent pixel leaves background intact")
    CALL ClearAllSlots

    ' Build a 2x2 1-bit CUR payload: only top-left pixel (0,0) is opaque (colour 255);
    ' the other 3 are transparent.
    ' Pixel layout (screen order, top-down):
    '   row 0: opaque pixel index 1 (=255), transparent pixel 0
    '   row 1: transparent, transparent
    ' AND mask (0=opaque, 1=transparent):
    '   row 0: bit7=0 (opaque), bit6=1 (transparent) -> byte &H40; padded to 4 bytes
    '   row 1: all transparent -> byte &HC0
    ' XOR 1-bit: row 0 top-pixel=1 -> &H80; row 1 all 0 -> &H00
    DIM hdr2 AS STRING, entry2 AS STRING, bih2 AS STRING
    DIM pal2 AS STRING, xor2 AS STRING, and2 AS STRING
    DIM iconPayload2 AS STRING
    DIM anihPayload2 AS STRING, ratePayload2 AS STRING
    DIM listInner2 AS STRING, listChunk2 AS STRING
    DIM anihChunk2 AS STRING, rateChunk2 AS STRING
    DIM iconChunk2 AS STRING, riffBody2 AS STRING, riff2 AS STRING
    DIM iconSize2 AS LONG

    hdr2   = LE16A(0) + LE16A(2) + LE16A(1)
    ' XOR: 1bpp, 2px/row -> scanline = ((2*1+31)\32)*4 = 4 bytes
    ' AND mask: 2px/row -> 4 bytes/row
    ' BIH(40) + palette(2*4=8) + XOR(4*2=8) + AND(4*2=8) = 64
    entry2 = CHR$(2) + CHR$(2) + CHR$(2) + CHR$(0) + _
             LE16A(0) + LE16A(0) + LE32A(64) + LE32A(22)
    bih2   = LE32A(40) + LE32A(2) + LE32A(4) + LE16A(1) + LE16A(1) + _
             LE32A(0) + LE32A(0) + LE32A(0) + LE32A(0) + LE32A(0) + LE32A(0)
    pal2   = CHR$(0)+CHR$(0)+CHR$(0)+CHR$(0) + CHR$(255)+CHR$(255)+CHR$(255)+CHR$(0)
    ' XOR bottom-up: file-row 0 = screen row 1 (all 0) ; file-row 1 = screen row 0 (px0=1)
    xor2   = CHR$(0)+CHR$(0)+CHR$(0)+CHR$(0) + CHR$(&H80)+CHR$(0)+CHR$(0)+CHR$(0)
    ' AND bottom-up: file-row 0 = screen row 1 (all transparent) ; file-row 1 = screen row 0 (px0 opaque, px1 transparent)
    and2   = CHR$(&HC0)+CHR$(0)+CHR$(0)+CHR$(0) + CHR$(&H40)+CHR$(0)+CHR$(0)+CHR$(0)
    iconPayload2 = hdr2 + entry2 + bih2 + pal2 + xor2 + and2
    iconSize2 = LEN(iconPayload2)

    iconChunk2  = "icon" + LE32A(iconSize2) + iconPayload2
    listInner2  = "fram" + iconChunk2
    listChunk2  = "LIST" + LE32A(LEN(listInner2)) + listInner2
    anihPayload2 = LE32A(36)+LE32A(1)+LE32A(1)+LE32A(2)+LE32A(2)+LE32A(1)+LE32A(1)+LE32A(6)+LE32A(0)
    anihChunk2  = "anih" + LE32A(36) + anihPayload2
    ratePayload2 = LE32A(6)
    rateChunk2  = "rate" + LE32A(4) + ratePayload2
    riffBody2   = "ACON" + anihChunk2 + rateChunk2 + listChunk2
    riff2       = "RIFF" + LE32A(LEN(riffBody2)) + riffBody2

    OPEN "TANI2.ANI" FOR BINARY AS #6
    PUT$ #6, riff2
    CLOSE #6

    ' Fill (0,0)..(3,3) with background colour 42
    DIM tx AS WORD, ty AS WORD
    FOR ty = 0 TO 3
        FOR tx = 0 TO 3
            CALL Vga_PutPixel(tx, ty, 42)
        NEXT tx
    NEXT ty

    DIM h2 AS BYTE
    h2 = DrawAni_LoadAnimation("TANI2.ANI")
    IF h2 = 255 THEN
        CALL Assert_IsTrue(0, "load failed -- cannot test transparency")
        EXIT SUB
    END IF

    CALL DrawAni_ShowFrame(h2, 0, 0, 0)

    ' Pixel (0,0) is opaque with index 1 -> colour 255
    CALL Assert_IsEqual(GetP_Ani(0, 0), 255, "opaque pixel (0,0) = 255 (index 1)")
    ' Pixel (1,0) is transparent -> stays 42
    CALL Assert_IsEqual(GetP_Ani(1, 0), 42, "transparent pixel (1,0) unchanged = 42")
    ' Row 1: all transparent -> stay 42
    CALL Assert_IsEqual(GetP_Ani(0, 1), 42, "transparent row1 (0,1) unchanged = 42")
    CALL Assert_IsEqual(GetP_Ani(1, 1), 42, "transparent row1 (1,1) unchanged = 42")

    IF h2 < 8 THEN CALL DrawAni_FreeAnimation(h2)
END SUB
