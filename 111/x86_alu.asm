; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ 16-БИТНОЙ ОСНОВНОЙ АРИФМЕТИКИ x86 (ALU)
; МОДУЛЬ: src/x86_alu.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; Константы масок флагов x86 в байте X86_REG_FLAGS
X86_CF_MASK     EQU %00000001   ; Carry Flag (Бит 0)
X86_ZF_MASK     EQU %00000100   ; Zero Flag (Бит 2)
X86_SF_MASK     EQU %00001000   ; Sign Flag (Бит 3)

; --- ВСПОМОГАТЕЛЬНАЯ ПРОЦЕДУРА: РАСЧЕТ И ЗАПИСЬ ФЛАГОВ x86 ---
; Вход: HL = Результат операции, C = Флаги Z80 хоста
Update_X86_ALU_Flags:
        PUSH    AF
        PUSH    BC
        LD      B, 0                 ; B будет копить флаги x86

        ; 1. Проверка Zero Flag (ZF)
        LD      A, H
        OR      L
        JR      NZ, .CheckSign
        SET     2, B                ; Если результат 0, взводим ZF (бит 2)

.CheckSign:
        ; 2. Проверка Sign Flag (SF - знаковый бит 15)
        BIT     7, H
        JR      Z, .CheckCarry
        SET     3, B                ; Если бит 15 равен 1, взводим SF (бит 3)

.CheckCarry:
        ; 3. Проверка Carry Flag (CF). Проверяем бит Carry во флагах Z80, сохраненных в C
        BIT     0, C                ; Бит 0 регистра флагов Z80 — это всегда Carry (C)
        JR      Z, .SaveFlags
        SET     0, B                ; Если у Z80 был перенос, взводим CF x86 (бит 0)

.SaveFlags:
        LD      A, B
        LD      (X86_REG_FLAGS), A   ; Записываем итоговый чистый байт флагов x86
        
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: ADD AX, CX (Опкод $01, ModR/M $C1) ---
Op_ADD_AX_CX:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      HL, (X86_REG_AX)
        LD      DE, (X86_REG_CX)
        
        OR      A                    ; Сброс carry Z80 перед сложением
        ADD     HL, DE              ; HL = AX + CX
        PUSH    AF                  ; Консервируем флаги Z80 в стеке
        
        LD      (X86_REG_AX), HL     ; Записываем результат обратно в AX

        POP     BC                  ; Извлекаем сохраненную пару AF в BC. C содержит флаги F!
        CALL    Update_X86_ALU_Flags

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: SUB AX, CX (Опкод $29, ModR/M $C1) ---
Op_SUB_AX_CX:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      HL, (X86_REG_AX)
        LD      DE, (X86_REG_CX)
        
        OR      A                    ; Сброс carry Z80 перед вычитанием
        SBC     HL, DE              ; HL = AX - CX
        PUSH    AF                  ; Консервируем флаги Z80 в стеке
        
        LD      (X86_REG_AX), HL     ; ЗаписываемBox результат обратно в AX

        POP     BC                  ; Извлекаем сохраненную пару AF в BC. C содержит флаги F!
        CALL    Update_X86_ALU_Flags

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: CMP AX, CX (Опкод $3B, ModR/M $C1) ---
Op_CMP_AX_CX:
        CALL    X86_Fetch_Byte
        CP      $C1                     ; Поддерживается только ModR/M CMP AX, CX
        JP      NZ, Op_Unimplemented
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      HL, (X86_REG_AX)
        LD      DE, (X86_REG_CX)
        
        OR      A
        SBC     HL, DE              ; Рассчитываем HL = AX - CX (результат не сохраняем)
        PUSH    AF                  ; Консервируем полученные флаги Z80 на стеке
        POP     BC                  ; Забираем их в пару BC. Теперь C содержит флаги F!

        CALL    Update_X86_ALU_Flags

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET
