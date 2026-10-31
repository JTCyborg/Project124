; Segmentation and 16-bit ModR/M test bank (91..98).

X86_Test4_Table
        dw      X86_T91, X86_T92, X86_T93, X86_T94
        dw      X86_T95, X86_T96, X86_T97, X86_T98

X86_Test4_Lengths
        dw      X86_T91_E - X86_T91, X86_T92_E - X86_T92
        dw      X86_T93_E - X86_T93, X86_T94_E - X86_T94
        dw      X86_T95_E - X86_T95, X86_T96_E - X86_T96
        dw      X86_T97_E - X86_T97, X86_T98_E - X86_T98

; [BX+DI] defaults to DS and supports writing and reading r/m8.
X86_T91
        db      $BB, $00, $02
        db      $BF, $03, $00
        db      $B0, $5A
        db      $88, $01
        db      $B0, $00
        db      $8A, $01
        db      $F4
X86_T91_E

; [BP+SI] defaults to SS, not DS.
X86_T92
        db      $B8, $00, $10
        db      $8E, $D8
        db      $B8, $00, $20
        db      $8E, $D0
        db      $BD, $10, $02
        db      $BE, $02, $00
        db      $B0, $A5
        db      $88, $02
        db      $B0, $00
        db      $8A, $02
        db      $88, $C1
        db      $F4
X86_T92_E

; Signed Disp8: [BP+DI-2] = SS:[0210h].
X86_T93
        db      $B8, $00, $20
        db      $8E, $D0
        db      $BD, $10, $02
        db      $BF, $02, $00
        db      $B0, $B6
        db      $88, $43, $FE
        db      $B0, $00
        db      $8A, $43, $FE
        db      $88, $C1
        db      $F4
X86_T93_E

; mod=00,r/m=110 is a direct displacement.
X86_T94
        db      $B0, $6D
        db      $88, $06, $34, $12
        db      $B0, $00
        db      $8A, $06, $34, $12
        db      $F4
X86_T94_E

; ES segment override is honored by r/m byte operations.
X86_T95
        db      $B8, $00, $20
        db      $8E, $C0
        db      $BB, $00, $02
        db      $BF, $03, $00
        db      $B0, $C3
        db      $26, $88, $01
        db      $B0, $00
        db      $26, $8A, $01
        db      $F4
X86_T95_E

; CS override reads from the code segment, not DS.
X86_T96
        db      $B8, $00, $10
        db      $8E, $D8
        db      $BB, $00, $01
        db      $2E, $8A, $07
        db      $F4
X86_T96_E

; Keep both segment accesses in guest bank 0 and at distinct physical offsets.
X86_T97
        db      $B8, $00, $00
        db      $8E, $D8
        db      $B8, $00, $01
        db      $8E, $D0
        db      $BD, $00, $02
        db      $BE, $00, $00
        db      $B0, $55
        db      $3E, $88, $02
        db      $B0, $AA
        db      $88, $02
        db      $B0, $00
        db      $8A, $02
        db      $88, $C1
        db      $B0, $00
        db      $3E, $8A, $02
        db      $F4
X86_T97_E

; Explicit SS override selects SS even for a [BX] effective address.
X86_T98
        db      $B8, $00, $00
        db      $8E, $D8
        db      $B8, $00, $08
        db      $8E, $D0
        db      $BB, $00, $02
        db      $B0, $11
        db      $88, $07
        db      $B0, $E7
        db      $36, $88, $07
        db      $B0, $00
        db      $8A, $07
        db      $88, $C1
        db      $B0, $00
        db      $36, $8A, $07
        db      $F4
X86_T98_E
