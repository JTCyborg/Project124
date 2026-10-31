; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ ПОБИТОВЫХ ЛОГИЧЕСКИХ ОПЕРАЦИЙ x86
; МОДУЛЬ: src/x86_logic.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ВСПOМОГАТЕЛЬНАЯ ПРОЦЕДУРА: РАСЧЕТ ЛОГИЧЕСКИХ ФЛАГОВ x86 ---
; Вход: HL = Результат логической операции
; Особенность: AND/OR/XOR/TEST всегда принудительно сбрасывают CF=0
Update_X86_Logic_Flags:
        PUSH    AF
        PUSH    BC
        LD      B, 0                    ; B будет копить флаги x86 (CF строго = 0)

        ; 1. Проверка Zero Flag (ZF - Бит 2)
        LD      A, H
        OR      L
        JR      NZ, .CheckSign
        SET     2, B                    ; Если результат 0, взводим ZF (бит 2)

.CheckSign:
        ; 2. Проверка Sign Flag (SF - Бит 3, знаковый бит 15)
        BIT     7, H
        JR      Z, .SaveFlags
        SET     3, B                    ; Если бит 15 равен 1, взводим SF (бит 3)

.SaveFlags:
        LD      A, B
        LD      (X86_REG_FLAGS), A      ; Записываем чистый логический байт флагов x86
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: AND AX, CX (Опкод $21) ---
Op_AND_AX_CX:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      HL, (X86_REG_AX)
        LD      DE, (X86_REG_CX)

        ; Побитовое И на Z80 для младшего байта
        LD      A, L
        AND     E
        LD      L, A

        ; Побитовое И на Z80 для старшего байта
        LD      A, H
        AND     D
        LD      H, A

        LD      (X86_REG_AX), HL        ; Сохраняем результат в AX
        CALL    Update_X86_Logic_Flags

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: OR AX, CX (Опкод $09) ---
Op_OR_AX_CX:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      HL, (X86_REG_AX)
        LD      DE, (X86_REG_CX)

        ; Побитовое ИЛИ на Z80 для младшего байта
        LD      A, L
        OR      E
        LD      L, A

        ; Побитовое ИЛИ на Z80 для старшего байта
        LD      A, H
        OR      D
        LD      H, A

        LD      (X86_REG_AX), HL        ; Сохраняем результат в AX
        CALL    Update_X86_Logic_Flags

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: XOR AX, CX (Опкод $31) ---
Op_XOR_AX_CX:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      HL, (X86_REG_AX)
        LD      DE, (X86_REG_CX)

        ; Побитовое ИСКЛЮЧАЮЩЕЕ ИЛИ на Z80 для младшего байта
        LD      A, L
        XOR     E
        LD      L, A

        ; Побитовое ИСКЛЮЧАЮЩЕЕ ИЛИ на Z80 для старшего байта
        LD      A, H
        XOR     D
        LD      H, A

        LD      (X86_REG_AX), HL        ; Сохраняем результат в AX
        CALL    Update_X86_Logic_Flags

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: TEST AX, CX (Опкод $85) ---
Op_TEST_AX_CX:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      HL, (X86_REG_AX)
        LD      DE, (X86_REG_CX)

        ; Вычисляем маску побитового И (как при AND)
        LD      A, L
        AND     E
        LD      L, A

        LD      A, H
        AND     D
        LD      H, A

        ; Рассчитываем только флаги x86, результат операции в AX НЕ сохраняем!
        CALL    Update_X86_Logic_Flags

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET
