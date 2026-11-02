; =========================================================================
; PROJECT 124 — x86 opcode dispatch table (256 one-byte opcodes).
; Unknown opcodes resolve to x86_unsupported until implemented.
; =========================================================================
        ALIGN   256
x86_jump_table:
        DW      x86_unsupported             ; 00
        DW      x86_unsupported             ; 01
        REPT    #40 - #02
        DW      x86_unsupported
        ENDR
        DW      x86_inc_ax                  ; 40
        REPT    #90 - #41
        DW      x86_unsupported
        ENDR
        DW      x86_nop                     ; 90
        REPT    #B8 - #91
        DW      x86_unsupported
        ENDR
        DW      x86_mov_ax_imm16            ; B8
        REPT    #F4 - #B9
        DW      x86_unsupported
        ENDR
        DW      x86_hlt                     ; F4
        REPT    256 - #F5
        DW      x86_unsupported
        ENDR
