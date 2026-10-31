; =========================================================================
; PROJECT 124 — TR-DOS BASIC boot loader
; =========================================================================

CLEAR       EQU     #FD
LOAD        EQU     #EF
CODE        EQU     #AF
RANDOMIZE   EQU     #F9
USR         EQU     #C0
VAL         EQU     #B0
OUT_CMD     EQU     #DF

BASIC_START:
basic_loader:
        ; Line 10: OUT 239,1: CLEAR 24000
        DB      0, 10
        DW      LINE10_END-LINE10
LINE10:
        DB      OUT_CMD
        DB      "239", #0E, #00, #00, #EF, #00, #00
        DB      ","
        DB      "1", #0E, #00, #00, #01, #00, #00
        DB      ":"
        DB      CLEAR
        DB      "24000", #0E, #00, #00, #5D, #C0, #00
        DB      #0D
LINE10_END:

        ; Line 11: print P124 START to debug port #EF.
        DB      0, 11
        DW      LINE11_END-LINE11
LINE11:
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "80", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "49", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "50", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "52", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "32", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "83", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "84", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "65", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "82", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "84", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "13", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "10", 34
        DB      #0D
LINE11_END:

        ; Line 20: RANDOMIZE USR 15619: LOAD "proj124" CODE 24576
        ; LOAD and CODE MUST be BASIC tokens, not printable ASCII text.
        ; There is deliberately no REM token before LOAD.
        DB      0, 20
        DW      LINE20_END-LINE20
LINE20:
        DB      RANDOMIZE
        DB      USR, "15619", #0E, #00, #00
        DW      15619
        DB      #00
        DB      #3A
        DB      LOAD, 34, "proj124", 34, CODE
        DB      "24576", #0E, #00, #00, #00, #60, #00
        DB      #0D
LINE20_END:

        ; Line 21: print LOADED after LOAD returns to BASIC.
        DB      0, 21
        DW      LINE21_END-LINE21
LINE21:
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "76", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "79", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "65", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "68", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "69", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "68", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "13", 34, ":"
        DB      OUT_CMD, VAL, 34, "239", 34, ",", VAL, 34, "10", 34
        DB      #0D
LINE21_END:

        ; Line 30: OUT 239,2: RANDOMIZE USR VAL "24585"
        DB      0, 30
        DW      LINE30_END-LINE30
LINE30:
        DB      OUT_CMD
        DB      "239", #0E, #00, #00, #EF, #00, #00
        DB      ","
        DB      "2", #0E, #00, #00, #02, #00, #00
        DB      ":"
        DB      RANDOMIZE, USR, VAL, 34
        DEFM    "24585"
        DB      34, #0D
LINE30_END:

        DB      #80
BASIC_END:
