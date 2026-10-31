; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ 16-БИТНЫХ ИНКРЕМЕНТОВ И ДЕКРЕМЕНТОВ x86
; МОДУЛЬ: src/x86_incdec16.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

Op_INC_AX:
        PUSH    HL
        LD      HL, (X86_REG_AX)
        INC     HL
        LD      (X86_REG_AX), HL
        POP     HL
        RET

Op_INC_CX:
        PUSH    HL
        LD      HL, (X86_REG_CX)
        INC     HL
        LD      (X86_REG_CX), HL
        POP     HL
        RET

Op_INC_DX:
        PUSH    HL
        LD      HL, (X86_REG_DX)
        INC     HL
        LD      (X86_REG_DX), HL
        POP     HL
        RET

Op_DEC_AX:
        PUSH    HL
        LD      HL, (X86_REG_AX)
        DEC     HL
        LD      (X86_REG_AX), HL
        POP     HL
        RET

Op_DEC_CX:
        PUSH    HL
        LD      HL, (X86_REG_CX)
        DEC     HL
        LD      (X86_REG_CX), HL
        POP     HL
        RET

Op_DEC_DX:
        PUSH    HL
        LD      HL, (X86_REG_DX)
        DEC     HL
        LD      (X86_REG_DX), HL
        POP     HL
        RET
