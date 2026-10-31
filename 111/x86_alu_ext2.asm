; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ РАСШИРЕННОЙ 16-БИТНОЙ АРИФМЕТИКИ x86
; МОДУЛЬ: src/x86_alu_ext2.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ОБРАБОТЧИК: ADD AX, Imm16 (Опкод $05) -> AX = AX + imm16 ---
Op_ADD_AX_Imm16:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        ; 1. FETCH: Безопасно последовательно считываем 16-битную константу
        CALL    X86_Fetch_Byte
        LD      E, A                    ; E = Младший байт константы
        CALL    X86_Fetch_Byte
        LD      D, A                    ; DE = 16-битная константа (imm16)

        ; 2. Выполняем сложение на Z80
        LD      HL, (X86_REG_AX)        ; HL = AX
        OR      A                       ; Сброс carry Z80 перед сложением
        ADD     HL, DE                  ; HL = AX + DE (imm16)
        
        PUSH    AF                      ; СРАЗУ сохраняем флаги Z80 в стек хоста
        LD      (X86_REG_AX), HL        ; Сохраняем результат в AX
        POP     BC                      ; Извлекаем сохраненную пару AF в BC. Теперь C содержит флаги!

        ; 3. Расчет флагов x86 по каноническому стандарту АЛУ
        CALL    Update_X86_ALU_Flags

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: SUB CX, Imm16 (Из группы $81, ModR/M $E9) -> CX = CX - imm16 ---
Op_SUB_CX_Imm16:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        ; 1. FETCH: Извлекаем 16-битную константу imm16 через Fetch-шлюз
        CALL    X86_Fetch_Byte
        LD      E, A                    ; E = Младший байт константы
        CALL    X86_Fetch_Byte
        LD      D, A                    ; DE = 16-битная константа (imm16)

        ; 2. Выполняем 16-битное вычитание на Z80
        LD      HL, (X86_REG_CX)        ; HL = CX
        OR      A                       ; Очищаем Carry перед SBC
        SBC     HL, DE                  ; HL = CX - DE (imm16)
        
        PUSH    AF                      ; СРАЗУ сохраняем флаги Z80
        LD      (X86_REG_CX), HL        ; Сохраняем результат в CX
        POP     BC                      ; Извлекаем сохраненную пару AF в BC. C содержит флаги F!

        ; 3. Расчет флагов x86 по каноническому стандарту АЛУ
        CALL    Update_X86_ALU_Flags

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET
