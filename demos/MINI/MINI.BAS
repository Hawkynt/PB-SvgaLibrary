' minimal harness proof: link the library, draw, honour SMOKE
$INCLUDE "SVGA.BI"
$LINK "SVGA.PBL"
DIM f AS INTEGER, xv AS WORD, yv AS WORD, cv AS BYTE
CALL Svga_Init(0)
CALL Svga_SetRes(320, 200, 256)
FOR f = 1 TO 30
    xv = 10 + f : yv = 50 : cv = f AND 255
    CALL Svga_FillRect(xv, yv, xv + 20, yv + 20, cv)
NEXT f
CALL Vesa_Close(0)
IF INSTR(UCASE$(COMMAND$), "SMOKE") > 0 THEN
    OPEN "SMOKE.OK" FOR OUTPUT AS #1
    PRINT #1, "OK " + Svga_Version$
    CLOSE #1
END IF
END
