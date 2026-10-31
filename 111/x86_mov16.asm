; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ МАТРИЦЫ КОПИРОВАНИЯ ДАННЫХ x86 (MOV REG, REG)
; МОДУЛЬ: src/x86_mov16.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ОБРАБОТЧИК: MOV AX, CX (Опкод $8B, $C1) ---
Op_MOV_AX_CX:
        PUSH    HL
        LD      HL, (X86_REG_CX)
        LD      (X86_REG_AX), HL        ; AX = CX
        POP     HL
        RET

; --- ОБРАБОТЧИК: MOV DX, AX (Опкод $89, $C2) ---
Op_MOV_DX_AX:
        PUSH    HL
        LD      HL, (X86_REG_AX)
        LD      (X86_REG_DX), HL        ; DX = AX
        POP     HL
        RET

; --- ОБРАБОТЧИК: MOV CX, DX (Опкод $89, $D1) ---
Op_MOV_CX_DX:
        PUSH    HL
        LD      HL, (X86_REG_DX)
        LD      (X86_REG_CX), HL        ; CX = DX
        POP     HL
        RET
