; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ 8-БИТНЫХ ИНКРЕМЕНТОВ И ДЕКРЕМЕНТОВ x86
; МОДУЛЬ: src/x86_incdec8.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

Op_INC_AL:
        PUSH    AF
        PUSH    BC
        LD      A, (X86_REG_AX)
        INC     A
        LD      (X86_REG_AX), A
        
        PUSH    AF
        POP     BC                      ; C = Флаги Z80
        LD      A, (X86_REG_FLAGS)      ; Берем старые флаги x86
        AND     %00000001               ; Сохраняем старый CF (бит 0)
        LD      D, A
        
        LD      A, (X86_REG_AX)         ; Анализируем результат
        CALL    Update_X86_Flags8_NoCF
        LD      A, (X86_REG_FLAGS)
        OR      D                       ; Склеиваем старый CF с новыми флагами
        LD      (X86_REG_FLAGS), A
        
        POP     BC
        POP     AF
        RET

Op_INC_CL:
        PUSH    AF
        PUSH    BC
        LD      A, (X86_REG_CX)
        INC     A
        LD      (X86_REG_CX), A
        
        PUSH    AF
        POP     BC
        LD      A, (X86_REG_FLAGS)
        AND     %00000001
        LD      D, A
        
        LD      A, (X86_REG_CX)
        CALL    Update_X86_Flags8_NoCF
        LD      A, (X86_REG_FLAGS)
        OR      D
        LD      (X86_REG_FLAGS), A
        
        POP     BC
        POP     AF
        RET

Op_DEC_AH:
        PUSH    AF
        PUSH    BC
        LD      A, (X86_REG_AX + 1)
        DEC     A
        LD      (X86_REG_AX + 1), A
        
        PUSH    AF
        POP     BC
        LD      A, (X86_REG_FLAGS)
        AND     %00000001
        LD      D, A
        
        LD      A, (X86_REG_AX + 1)
        CALL    Update_X86_Flags8_NoCF
        LD      A, (X86_REG_FLAGS)
        OR      D
        LD      (X86_REG_FLAGS), A
        
        POP     BC
        POP     AF
        RET

; Вспомогательная подпрограмма для INC/DEC, которая не трогает CF
Update_X86_Flags8_NoCF:
        PUSH    BC
        LD      B, 0
        AND     A
        JR      NZ, .CheckSign
        SET     2, B                    ; ZF
.CheckSign:
        BIT     7, A
        JR      Z, .Save
        SET     3, B                    ; SF
.Save:
        LD      A, B
        LD      (X86_REG_FLAGS), A
        POP     BC
        RET
