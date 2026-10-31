; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ 8-БИТНЫХ ПОБИТОВЫХ ОПЕРАЦИЙ x86
; МОДУЛЬ: src/x86_logic8.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

Op_AND_AL_CL:
        PUSH    AF
        PUSH    BC
        LD      A, (X86_REG_AX)         ; AL
        LD      B, A
        LD      A, (X86_REG_CX)         ; CL
        AND     B
        LD      (X86_REG_AX), A         ; Сохраняем в AL
        
        LD      L, A
        LD      H, 0
        CALL    Update_X86_Logic_Flags
        POP     BC
        POP     AF
        RET

Op_OR_AH_CH:
        PUSH    AF
        PUSH    BC
        LD      A, (X86_REG_AX + 1)     ; AH
        LD      B, A
        LD      A, (X86_REG_CX + 1)     ; CH
        OR      B
        LD      (X86_REG_AX + 1), A     ; Сохраняем в AH
        
        LD      L, A
        LD      H, 0
        CALL    Update_X86_Logic_Flags
        POP     BC
        POP     AF
        RET

Op_XOR_AL_CL:
        PUSH    AF
        PUSH    BC
        LD      A, (X86_REG_AX)         ; AL
        LD      B, A
        LD      A, (X86_REG_CX)         ; CL
        XOR     B
        LD      (X86_REG_AX), A         ; Сохраняем в AL
        
        LD      L, A
        LD      H, 0
        CALL    Update_X86_Logic_Flags
        POP     BC
        POP     AF
        RET

Op_TEST_AH_CH:
        PUSH    AF
        PUSH    BC
        LD      A, (X86_REG_AX + 1)     ; AH
        LD      B, A
        LD      A, (X86_REG_CX + 1)     ; CH
        AND     B                       ; Вычисляем только маску флагов
        
        LD      L, A
        LD      H, 0
        CALL    Update_X86_Logic_Flags  ; Регистры не меняются
        POP     BC
        POP     AF
        RET
