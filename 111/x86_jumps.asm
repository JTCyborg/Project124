; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ УСЛОВНЫХ И БЕЗУСЛОВНЫХ ПЕРЕХОДОВ x86
; МОДУЛЬ: src/x86_jumps.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ВСПОМОГАТЕЛЬНАЯ ПРОЦЕДУРА: ВЫПОЛНЕНИЕ ЗНАКOВOГO ПРЫЖКA REL8 ---
; Вход: C = Знаковое смещение (00-FF)
Execute_Rel8_Jump:
        PUSH    AF
        PUSH    BC
        PUSH    HL

        ; Вычисляем расширение знака для Z80 (размножаем 7-й бит регистра C в B)
        LD      B, 0
        BIT     7, C
        JR      Z, .Positive
        LD      B, $FF
.Positive:
        ; Складываем текущий IP со знаковым смещением BC
        LD      HL, (X86_REG_IP)
        ADD     HL, BC
        LD      (X86_REG_IP), HL     ; Записываем обновленный IP обратно в память

        POP     HL
        POP     BC
        POP     AF
        RET

; --- ОБЩАЯ ВНУТРЕННЯЯ ЛОГИКА ДЛЯ ВСЕХ УСЛОВНЫХ ПЕРЕХОДОВ ---
FetchAndCheckJump:              
        CALL    X86_Fetch_Byte          ; Извлекаем знаковое относительное смещение прыжка
        LD      C, A                    ; C = Считанное относительное смещение прыжка
        RET

; --- ОБРАБОТЧИК: JMP Rel8 (Опкод $EB) ---
Op_JMP_Rel8:
        PUSH    AF
        PUSH    BC
        CALL    FetchAndCheckJump  
        CALL    Execute_Rel8_Jump  
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: JZ / JE Rel8 (Опкод $74) -> Прыжок, если ZF = 1 ---
Op_JZ_Rel8:
        PUSH    AF
        PUSH    BC
        CALL    FetchAndCheckJump

        ; Проверяем флаг нуля x86 (ZF - Бит 2 в X86_REG_FLAGS)
        LD      A, (X86_REG_FLAGS)
        BIT     2, A
        JR      Z, .NoJump           ; Если ZF = 0, прыжка нет

        CALL    Execute_Rel8_Jump  ; Если ZF = 1, прыгаем!
.NoJump:
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: JNZ / JNE Rel8 (Опкод $75) -> Прыжок, если ZF = 0 ---
Op_JNZ_Rel8:
        PUSH    AF
        PUSH    BC
        CALL    FetchAndCheckJump

        LD      A, (X86_REG_FLAGS)
        BIT     2, A
        JR      NZ, .NoJump          ; Если ZF = 1, прыжка нет

        CALL    Execute_Rel8_Jump  ; Если ZF = 0, прыгаем!
.NoJump:
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: JC / JB Rel8 (Опкод $72) -> Прыжок, если CF = 1 ---
Op_JC_Rel8:
        PUSH    AF
        PUSH    BC
        CALL    FetchAndCheckJump

        ; Проверяем флаг переноса x86 (CF - Бит 0 в X86_REG_FLAGS)
        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JR      Z, .NoJump           ; Если CF = 0, прыжка нет

        CALL    Execute_Rel8_Jump  
.NoJump:
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: JNC / JAE Rel8 (Опкод $73) -> Прыжок, если CF = 0 ---
Op_JNC_Rel8:
        PUSH    AF
        PUSH    BC
        CALL    FetchAndCheckJump

        LD      A, (X86_REG_FLAGS)
        BIT     0, A
        JR      NZ, .NoJump          ; Если CF = 1, прыжка нет

        CALL    Execute_Rel8_Jump  
.NoJump:
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: JS Rel8 (Опкод $78) -> Прыжок, если SF = 1 ---
Op_JS_Rel8:
        PUSH    AF
        PUSH    BC
        CALL    FetchAndCheckJump

        ; Проверяем флаг знака x86 (SF - Бит 3 в X86_REG_FLAGS)
        LD      A, (X86_REG_FLAGS)
        BIT     3, A
        JR      Z, .NoJump           ; Если SF = 0, прыжка нет

        CALL    Execute_Rel8_Jump  
.NoJump:
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: JNS Rel8 (Опкод $79) -> Прыжок, если SF = 0 ---
Op_JNS_Rel8:
        PUSH    AF
        PUSH    BC
        CALL    FetchAndCheckJump

        LD      A, (X86_REG_FLAGS)
        BIT     3, A
        JR      NZ, .NoJump          ; Если SF = 1, прыжка нет

        CALL    Execute_Rel8_Jump  
.NoJump:
        POP     BC
        POP     AF
        RET
