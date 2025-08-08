' =============================================================================
' TEST.BAS - Test program for enhanced SVGA library features
' =============================================================================
' Tests the new cursor management, timer system, and icon support
' =============================================================================

$INCLUDE "SVGA.SUB"

' Test all new features
SUB Main
    DIM TestX AS WORD, TestY AS WORD
    DIM TimerStart AS LONG, CurrentTime AS LONG
    DIM AnimHandle AS BYTE
    DIM I AS WORD
    
    PRINT "Testing Enhanced SVGA Library Features..."
    PRINT "Initializing graphics mode..."
    
    ' Initialize SVGA system
    CALL Svga_Init
    
    ' Test 1: Timer system (before graphics mode)
    CALL Timer_Init
    TimerStart = Timer_GetTick
    CALL Timer_Delay10Ms(100)  ' Wait 1 second
    CurrentTime = Timer_GetTick
    IF (CurrentTime - TimerStart) >= 90 AND (CurrentTime - TimerStart) <= 110 THEN
        PRINT "Timer system: PASSED"
    ELSE
        PRINT "Timer system: FAILED (Expected ~100 ticks, got"; CurrentTime - TimerStart; ")"
    END IF
    
    PRINT "Entering graphics mode - watch for visual tests..."
    
    ' Set graphics mode
    CALL Svga_SetRes(640, 480, 256)
    
    ' Test 2: Clear screen with new 8086-compatible routine
    CALL Svga_ClearScreen(1)  ' Clear to blue
    CALL Timer_Delay10Ms(50)   ' Brief pause
    
    ' Test 3: Draw test pattern
    FOR I = 0 TO 255
        CALL Svga_PutPixel(I, 100, I)
        CALL Svga_PutPixel(I, 101, 255 - I)
    NEXT I
    
    ' Test 4: Virtual coordinate system
    CALL Virtual_SetScale(2, 2)
    CALL Virtual_SetWindow(320, 240)
    TestX = 50: TestY = 50
    CALL Virtual_ToPhysical(TestX, TestY, TestX, TestY)
    CALL Svga_PutPixel(TestX, TestY, 15)  ' White pixel
    
    ' Test 5: Animation timer
    CALL Timer_SetAnim(10)  ' 100ms animation frame
    
    ' Test 6: Named timers
    CALL Timer_Create(0, 20)  ' Timer 0 with 200ms delay
    CALL Timer_Create(1, 5)   ' Timer 1 with 50ms delay
    
    ' Test 7: Cursor system initialization
    CALL Cursor_Init
    
    ' Test 8: Simple animation loop
    DIM FrameCount AS WORD
    FrameCount = 0
    
    DO WHILE FrameCount < 100
        ' Test animation timer
        IF Timer_IsAnimReady THEN
            ' Draw moving rectangle
            DIM RectX AS WORD
            RectX = (FrameCount * 2) MOD 600
            CALL Svga_FillRect(RectX, 200, RectX + 20, 220, (FrameCount MOD 256))
            FrameCount = FrameCount + 1
        END IF
        
        ' Test named timer 0 (slow)
        IF Timer_IsReady(0) THEN
            CALL Svga_PutPixel(100, 300, 14)  ' Yellow flash
        END IF
        
        ' Test named timer 1 (fast)  
        IF Timer_IsReady(1) THEN
            CALL Svga_PutPixel(200, 300, 12)  ' Red flash
        END IF
        
        ' Check for keypress
        IF INKEY$ <> "" THEN EXIT DO
        
        ' Small delay to prevent 100% CPU usage
        CALL Timer_Delay10Ms(1)
    LOOP
    
    ' Test 9: Cursor positioning test (if we had actual cursor data)
    CALL Cursor_SetPos(320, 240)
    
    ' Display test results
    CALL Svga_ClearScreen(0)
    
    ' Draw test completion message using pixels
    ' (Simplified - in real usage you'd use font system)
    FOR I = 0 TO 200
        CALL Svga_PutPixel(100 + I, 100, 15)  ' White line
        CALL Svga_PutPixel(100 + I, 120, 15)  ' White line
    NEXT I
    
    ' Wait for key
    DO WHILE INKEY$ = ""
        ' Continue testing timers
        CALL Timer_Delay10Ms(1)
    LOOP
    
    ' Cleanup and return to text mode
    CALL Timer_Destroy(0)
    CALL Timer_Destroy(1)
    CALL Svga_Cleanup
    
    ' Now we can print again
    PRINT "All graphics tests completed!"
    PRINT "Press any key to exit..."
    DO WHILE INKEY$ = "": LOOP
END SUB

' Run the test
CALL Main
END