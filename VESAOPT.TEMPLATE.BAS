' =============================================================================
' VESAOPT.TEMPLATE.BAS - per-width template for the VESA fast-path families
' =============================================================================
' This file is NOT compiled and NOT shipped. scripts/gen-vesaopt.py expands it
' once per configured (width x height) mode into VOPT<width>.SUB, deriving:
'   {W}            the pixel width (and every literal stride in the asm)
'   {OFFSET:var}   the y*width offset as a SHIFT LEFT/ADD chain built from the
'                  width's set bits (no MUL - PowerBASIC cannot inline, so the
'                  decomposition is expanded right into every handler)
'   {SPANS}        the per-width FillCircle half-span table (unit-local)
'   {MAXR}         the largest sane circle radius (height \ 2)
'   ' {IF:SINGLEBANK} ... ' {ELSE} ... ' {ENDIF}
'                  picks the bank-free fill variants where the whole frame fits
'                  one 64k bank (width*height <= 65536, i.e. mode 13h)
' The tool also emits VESAOPT.SUB (Svga_WireVesaOptimized wiring all generated
' families into SVGADispatch) and VESAOPT.INC (the include aggregate the
' umbrella SVGA.SUB pulls in). Regenerate after editing this template:
'   python3 scripts/gen-vesaopt.py        (CI fails on template/output drift)
' =============================================================================

' ---------------------------------------------------------------------------
' {W}-wide VESA 256-colour family. y*{W} is inlined as shifts/adds in every
' handler (PowerBASIC cannot inline a FUNCTION). A horizontal run crosses at
' most one 64k bank boundary, so HLine is branch-light straight-line code:
' fill to the boundary, switch the bank once, fill the rest. VLine fast-paths
' the common single-bank case and otherwise fills whole row-runs per bank.
' FillRect batches rows per bank into one asm loop; FillCircle sweeps a
' precomputed integer span table top-to-bottom so the bank only ever advances.
' ---------------------------------------------------------------------------

' half-span per row distance for the FillCircle sweep (unit-local scratch,
' sized for the largest sane radius of this width's canonical mode)
DIM {SPANS}(0 TO {MAXR}) AS SHARED WORD

SUB Vesa{W}_PutPixel(x_a AS WORD, y_a AS WORD, c_a AS BYTE)
    DIM x AS WORD, y AS WORD, c AS BYTE, o AS LONG, t AS LONG, bank AS WORD, winOff AS WORD
    x = x_a : y = y_a : c = c_a
    {OFFSET:y}
    o = o + x
    bank = o \ 65536
    IF bank <> VESASystemContext.VWnd THEN CALL Memory_SetVesaWindow(bank)
    winOff = o AND &HFFFF
    DEF SEG = &HA000 : POKE winOff, c : DEF SEG
END SUB

SUB Vesa{W}_GetPixel(x_a AS WORD, y_a AS WORD, resultVal AS BYTE)
    DIM x AS WORD, y AS WORD, o AS LONG, t AS LONG, bank AS WORD, winOff AS WORD
    x = x_a : y = y_a
    {OFFSET:y}
    o = o + x
    bank = o \ 65536
    IF bank <> VESASystemContext.VWnd THEN CALL Memory_SetVesaWindow(bank)
    winOff = o AND &HFFFF
    DEF SEG = &HA000 : resultVal = PEEK(winOff) : DEF SEG
END SUB

SUB Vesa{W}_HLine(x1_a AS WORD, x2_a AS WORD, y_a AS WORD, c_a AS BYTE)
    DIM x1 AS WORD, x2 AS WORD, y AS WORD, c AS BYTE
    DIM o AS LONG, t AS LONG, toEnd AS LONG, runLen AS WORD, bank AS WORD, winOff AS WORD, rest AS WORD
    x1 = x1_a : x2 = x2_a : y = y_a : c = c_a
    IF x1 > x2 THEN SWAP x1, x2
    {OFFSET:y}
    o = o + x1
    runLen = x2 - x1 + 1
    bank = o \ 65536
    IF bank <> VESASystemContext.VWnd THEN CALL Memory_SetVesaWindow(bank)
    winOff = o AND &HFFFF
    toEnd = 65536 - winOff
    IF toEnd >= runLen THEN
        !PUSH ES
        !PUSH DI
        !MOV AX, &HA000
        !MOV ES, AX
        !MOV DI, winOff
        !MOV CX, runLen
        !MOV AL, c
        !CLD
        !REP STOSB
        !POP DI
        !POP ES
    ELSE
        rest = runLen - toEnd
        !PUSH ES
        !PUSH DI
        !MOV AX, &HA000
        !MOV ES, AX
        !MOV DI, winOff
        !MOV CX, toEnd
        !MOV AL, c
        !CLD
        !REP STOSB
        !POP DI
        !POP ES
        CALL Memory_SetVesaWindow(bank + 1)
        !PUSH ES
        !PUSH DI
        !MOV AX, &HA000
        !MOV ES, AX
        !XOR DI, DI
        !MOV CX, rest
        !MOV AL, c
        !CLD
        !REP STOSB
        !POP DI
        !POP ES
    END IF
END SUB

SUB Vesa{W}_VLine(x_a AS WORD, y1_a AS WORD, y2_a AS WORD, c_a AS BYTE)
    DIM x AS WORD, y1 AS WORD, y2 AS WORD, c AS BYTE
    DIM o AS LONG, t AS LONG, endO AS LONG, toEndRows AS LONG
    DIM rowsLeft AS WORD, rowsThis AS WORD, bank AS WORD, winOff AS WORD
    x = x_a : y1 = y1_a : y2 = y2_a : c = c_a
    IF y1 > y2 THEN SWAP y1, y2
    {OFFSET:y1}
    o = o + x
    rowsLeft = y2 - y1 + 1
    endO = o + (rowsLeft - 1) * {W}&
    IF (o \ 65536) = (endO \ 65536) THEN
        ' whole column in one bank - no per-row checks
        bank = o \ 65536
        IF bank <> VESASystemContext.VWnd THEN CALL Memory_SetVesaWindow(bank)
        winOff = o AND &HFFFF
        !PUSH ES
        !PUSH DI
        !MOV AX, &HA000
        !MOV ES, AX
        !MOV DI, winOff
        !MOV CX, rowsLeft
        !MOV DX, {W}
        !MOV AL, c
        Vesa{W}VLineFast:
        !MOV ES:[DI], AL
        !ADD DI, DX
        !LOOP Vesa{W}VLineFast
        !POP DI
        !POP ES
    ELSE
        DO WHILE rowsLeft > 0
            bank = o \ 65536
            IF bank <> VESASystemContext.VWnd THEN CALL Memory_SetVesaWindow(bank)
            winOff = o AND &HFFFF
            toEndRows = (65536 - winOff) \ {W}
            IF toEndRows < 1 THEN toEndRows = 1
            IF toEndRows > rowsLeft THEN rowsThis = rowsLeft ELSE rowsThis = toEndRows
            !PUSH ES
            !PUSH DI
            !MOV AX, &HA000
            !MOV ES, AX
            !MOV DI, winOff
            !MOV CX, rowsThis
            !MOV DX, {W}
            !MOV AL, c
            Vesa{W}VLineSeg:
            !MOV ES:[DI], AL
            !ADD DI, DX
            !LOOP Vesa{W}VLineSeg
            !POP DI
            !POP ES
            o = o + rowsThis * {W}&
            rowsLeft = rowsLeft - rowsThis
        LOOP
    END IF
END SUB

' {IF:SINGLEBANK}
SUB Vesa{W}_FillRect(x1_a AS WORD, y1_a AS WORD, x2_a AS WORD, y2_a AS WORD, c_a AS BYTE)
    DIM x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD, c AS BYTE
    DIM o AS LONG, t AS LONG
    DIM runLen AS WORD, rowsLeft AS WORD, strideRest AS WORD, winOff AS WORD
    x1 = x1_a : y1 = y1_a : x2 = x2_a : y2 = y2_a : c = c_a
    IF x1 > x2 THEN SWAP x1, x2
    IF y1 > y2 THEN SWAP y1, y2
    {OFFSET:y1}
    o = o + x1
    runLen = x2 - x1 + 1
    rowsLeft = y2 - y1 + 1
    strideRest = {W} - runLen
    winOff = o AND &HFFFF
    ' the whole frame lives in ONE 64k bank, so the entire rectangle is a
    ' single asm loop - no bank checks at all, word fills per row
    !PUSH ES
    !PUSH DI
    !MOV AX, &HA000
    !MOV ES, AX
    !MOV DI, winOff
    !MOV BX, rowsLeft
    !MOV DX, strideRest
    !MOV AL, c
    !MOV AH, AL
    !CLD
    V{W}FRRow:
    !MOV CX, runLen
    !TEST DI, 1
    !JZ V{W}FRAligned
    !STOSB
    !DEC CX
    !JZ V{W}FRNext
    V{W}FRAligned:
    !SHR CX, 1
    !REP STOSW
    !JNC V{W}FRNext
    !STOSB
    V{W}FRNext:
    !ADD DI, DX
    !DEC BX
    !JNZ V{W}FRRow
    !POP DI
    !POP ES
END SUB
' {ELSE}
SUB Vesa{W}_FillRect(x1_a AS WORD, y1_a AS WORD, x2_a AS WORD, y2_a AS WORD, c_a AS BYTE)
    DIM x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD, c AS BYTE
    DIM o AS LONG, t AS LONG, toEnd AS LONG, fitRows AS LONG
    DIM runLen AS WORD, rowsLeft AS WORD, rowsThis AS WORD, strideRest AS WORD
    DIM bank AS WORD, winOff AS WORD, part1 AS WORD, part2 AS WORD
    x1 = x1_a : y1 = y1_a : x2 = x2_a : y2 = y2_a : c = c_a
    IF x1 > x2 THEN SWAP x1, x2
    IF y1 > y2 THEN SWAP y1, y2
    {OFFSET:y1}
    o = o + x1
    runLen = x2 - x1 + 1
    rowsLeft = y2 - y1 + 1
    strideRest = {W} - runLen
    DO WHILE rowsLeft > 0
        bank = o \ 65536
        IF bank <> VESASystemContext.VWnd THEN CALL Memory_SetVesaWindow(bank)
        winOff = o AND &HFFFF
        toEnd = 65536 - winOff
        IF toEnd < runLen THEN
            ' this row straddles the bank edge: fill to the edge, switch once, fill the rest
            part1 = toEnd
            part2 = runLen - part1
            !PUSH ES
            !PUSH DI
            !MOV AX, &HA000
            !MOV ES, AX
            !MOV DI, winOff
            !MOV CX, part1
            !MOV AL, c
            !CLD
            !REP STOSB
            !POP DI
            !POP ES
            CALL Memory_SetVesaWindow(bank + 1)
            !PUSH ES
            !PUSH DI
            !MOV AX, &HA000
            !MOV ES, AX
            !XOR DI, DI
            !MOV CX, part2
            !MOV AL, c
            !CLD
            !REP STOSB
            !POP DI
            !POP ES
            o = o + {W}
            rowsLeft = rowsLeft - 1
        ELSE
            ' batch every row whose span stays inside this bank into ONE asm loop:
            ' the bank is checked once per BATCH, not per row, and each row is a
            ' word fill (leading/trailing odd byte handled branch-light in asm)
            fitRows = (toEnd - runLen) \ {W} + 1
            IF fitRows > rowsLeft THEN rowsThis = rowsLeft ELSE rowsThis = fitRows
            !PUSH ES
            !PUSH DI
            !MOV AX, &HA000
            !MOV ES, AX
            !MOV DI, winOff
            !MOV BX, rowsThis
            !MOV DX, strideRest
            !MOV AL, c
            !MOV AH, AL
            !CLD
            V{W}FRRow:
            !MOV CX, runLen
            !TEST DI, 1
            !JZ V{W}FRAligned
            !STOSB
            !DEC CX
            !JZ V{W}FRNext
            V{W}FRAligned:
            !SHR CX, 1
            !REP STOSW
            !JNC V{W}FRNext
            !STOSB
            V{W}FRNext:
            !ADD DI, DX
            !DEC BX
            !JNZ V{W}FRRow
            !POP DI
            !POP ES
            o = o + rowsThis * {W}&
            rowsLeft = rowsLeft - rowsThis
        END IF
    LOOP
END SUB
' {ENDIF}

SUB Vesa{W}_DrawRect(x1_a AS WORD, y1_a AS WORD, x2_a AS WORD, y2_a AS WORD, c_a AS BYTE)
    DIM x1 AS WORD, y1 AS WORD, x2 AS WORD, y2 AS WORD, c AS BYTE
    x1 = x1_a : y1 = y1_a : x2 = x2_a : y2 = y2_a : c = c_a
    IF x1 > x2 THEN SWAP x1, x2
    IF y1 > y2 THEN SWAP y1, y2
    CALL Vesa{W}_HLine(x1, x2, y1, c)
    CALL Vesa{W}_HLine(x1, x2, y2, c)
    CALL Vesa{W}_VLine(x1, y1, y2, c)
    CALL Vesa{W}_VLine(x2, y1, y2, c)
END SUB

' {IF:SINGLEBANK}
SUB Vesa{W}_FillCircle(cx_a AS WORD, cy_a AS WORD, r_a AS WORD, c_a AS BYTE)
    DIM cx AS WORD, cy AS WORD, r AS WORD, c AS BYTE
    DIM rr AS LONG, xx AS LONG, xxsq AS LONG, dysq AS LONG
    DIM dy AS INTEGER, row AS INTEGER
    DIM o AS LONG, t AS LONG
    DIM runLen AS WORD, halfw AS WORD, winOff AS WORD, yTop AS WORD
    cx = cx_a : cy = cy_a : r = r_a : c = c_a
    IF r > {MAXR} THEN r = {MAXR}
    ' pass 1: integer half-span per row distance (incremental squares - no FPU)
    rr = r : rr = rr * rr
    xx = r : xxsq = rr : dysq = 0
    FOR dy = 0 TO r
        DO WHILE xxsq + dysq > rr
            xxsq = xxsq - xx - xx + 1
            xx = xx - 1
        LOOP
        {SPANS}(dy) = xx
        dysq = dysq + dy + dy + 1
    NEXT dy
    ' pass 2: the whole frame lives in ONE 64k bank - per row just a word fill
    yTop = cy - r
    {OFFSET:yTop}
    o = o + cx
    FOR row = -r TO r
        dy = row : IF dy < 0 THEN dy = -dy
        halfw = {SPANS}(dy)
        runLen = halfw + halfw + 1
        winOff = (o - halfw) AND &HFFFF
        !PUSH ES
        !PUSH DI
        !MOV AX, &HA000
        !MOV ES, AX
        !MOV DI, winOff
        !MOV CX, runLen
        !MOV AL, c
        !MOV AH, AL
        !CLD
        !TEST DI, 1
        !JZ V{W}FCAligned
        !STOSB
        !DEC CX
        !JZ V{W}FCDone
        V{W}FCAligned:
        !SHR CX, 1
        !REP STOSW
        !JNC V{W}FCDone
        !STOSB
        V{W}FCDone:
        !POP DI
        !POP ES
        o = o + {W}
    NEXT row
END SUB
' {ELSE}
SUB Vesa{W}_FillCircle(cx_a AS WORD, cy_a AS WORD, r_a AS WORD, c_a AS BYTE)
    DIM cx AS WORD, cy AS WORD, r AS WORD, c AS BYTE
    DIM rr AS LONG, xx AS LONG, xxsq AS LONG, dysq AS LONG
    DIM dy AS INTEGER, row AS INTEGER
    DIM o AS LONG, t AS LONG, rowStart AS LONG, toEnd AS LONG
    DIM runLen AS WORD, halfw AS WORD, bank AS WORD, winOff AS WORD
    DIM part1 AS WORD, part2 AS WORD, yTop AS WORD
    cx = cx_a : cy = cy_a : r = r_a : c = c_a
    IF r > {MAXR} THEN r = {MAXR}
    ' pass 1: integer half-span per row distance (incremental squares - no FPU)
    rr = r : rr = rr * rr
    xx = r : xxsq = rr : dysq = 0
    FOR dy = 0 TO r
        DO WHILE xxsq + dysq > rr
            xxsq = xxsq - xx - xx + 1
            xx = xx - 1
        LOOP
        {SPANS}(dy) = xx
        dysq = dysq + dy + dy + 1
    NEXT dy
    ' pass 2: sweep rows top to bottom - row offsets only grow, so the bank only
    ' ever advances: one compare per row, a switch only at a real 64k boundary
    yTop = cy - r
    {OFFSET:yTop}
    o = o + cx
    FOR row = -r TO r
        dy = row : IF dy < 0 THEN dy = -dy
        halfw = {SPANS}(dy)
        runLen = halfw + halfw + 1
        rowStart = o - halfw
        bank = rowStart \ 65536
        IF bank <> VESASystemContext.VWnd THEN CALL Memory_SetVesaWindow(bank)
        winOff = rowStart AND &HFFFF
        toEnd = 65536 - winOff
        IF toEnd < runLen THEN
            ' rare: this span straddles the bank edge - split it once
            part1 = toEnd
            part2 = runLen - part1
            !PUSH ES
            !PUSH DI
            !MOV AX, &HA000
            !MOV ES, AX
            !MOV DI, winOff
            !MOV CX, part1
            !MOV AL, c
            !CLD
            !REP STOSB
            !POP DI
            !POP ES
            CALL Memory_SetVesaWindow(bank + 1)
            !PUSH ES
            !PUSH DI
            !MOV AX, &HA000
            !MOV ES, AX
            !XOR DI, DI
            !MOV CX, part2
            !MOV AL, c
            !CLD
            !REP STOSB
            !POP DI
            !POP ES
        ELSE
            !PUSH ES
            !PUSH DI
            !MOV AX, &HA000
            !MOV ES, AX
            !MOV DI, winOff
            !MOV CX, runLen
            !MOV AL, c
            !MOV AH, AL
            !CLD
            !TEST DI, 1
            !JZ V{W}FCAligned
            !STOSB
            !DEC CX
            !JZ V{W}FCDone
            V{W}FCAligned:
            !SHR CX, 1
            !REP STOSW
            !JNC V{W}FCDone
            !STOSB
            V{W}FCDone:
            !POP DI
            !POP ES
        END IF
        o = o + {W}
    NEXT row
END SUB
' {ENDIF}
