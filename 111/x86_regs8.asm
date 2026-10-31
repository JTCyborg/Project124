; =========================================================================
; PERFECT COMMANDER 111 — ПОДДЕРЖКА 8-БИТНЫХ РЕГИСТРОВ x86 (АППАРАТНЫЙ ФИКС)
; МОДУЛЬ: src/x86_regs8.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ОБРАБОТЧИК: MOV AL, imm8 (Опкод $B0) ---
Op_MOV_AL_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        CALL    X86_Fetch_Byte
        LD      B, A                    

        LD      HL, X86_REG_AX
        LD      (HL), B

        POP     HL                      
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: MOV CL, imm8 (Опкод $B1) ---
Op_MOV_CL_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        CALL    X86_Fetch_Byte
        LD      B, A

        LD      HL, X86_REG_CX
        LD      (HL), B

        POP     HL                      
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ДОБАВЛЕНО: MOV DL, imm8 (Опкод $B2) ---
Op_MOV_DL_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        CALL    X86_Fetch_Byte
        LD      B, A

        LD      HL, X86_REG_DX
        LD      (HL), B

        POP     HL                      
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ДОБАВЛЕНО: MOV BL, imm8 (Опкод $B3) ---
Op_MOV_BL_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        CALL    X86_Fetch_Byte
        LD      B, A

        LD      HL, X86_REG_BX
        LD      (HL), B

        POP     HL                      
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: MOV AH, imm8 (Опкод $B4) ---
Op_MOV_AH_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        CALL    X86_Fetch_Byte
        LD      B, A

        LD      HL, X86_REG_AX + 1
        LD      (HL), B

        POP     HL                      
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: MOV CH, imm8 (Опкод $B5) ---
Op_MOV_CH_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        CALL    X86_Fetch_Byte
        LD      B, A

        LD      HL, X86_REG_CX + 1
        LD      (HL), B

        POP     HL                      
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ДОБАВЛЕНО: MOV DH, imm8 (Опкод $B6) ---
Op_MOV_DH_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        CALL    X86_Fetch_Byte
        LD      B, A

        LD      HL, X86_REG_DX + 1
        LD      (HL), B

        POP     HL                      
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ДОБАВЛЕНО: MOV BH, imm8 (Опкод $B7) ---
Op_MOV_BH_Imm8:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        CALL    X86_Fetch_Byte
        LD      B, A

        LD      HL, X86_REG_BX + 1
        LD      (HL), B

        POP     HL                      
        POP     DE
        POP     BC
        POP     AF
        RET
