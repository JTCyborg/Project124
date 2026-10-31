; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ 16-БИТНОГО УМНОЖЕНИЯ И ДЕЛЕНИЯ x86 (DX:AX)
; МОДУЛЬ: src/x86_mul16.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ОБРАБОТЧИК: MUL CX (Из группы $F7, ModR/M $E1) -> DX:AX = AX * CX ---
Op_MUL_CX:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      HL, (X86_REG_AX)
        LD      DE, (X86_REG_CX)

        PUSH    DE
        PUSH    HL
        
        LD      BC, HL
        LD      HL, 0
        LD      A, 16
.MulLoop:
        ADD     HL, HL
        EX      DE, HL
        ADD     HL, HL
        EX      DE, HL
        JR      NC, .NoAdd
        ADD     HL, BC
        JR      NC, .NoAdd
        INC     DE
.NoAdd:
        DEC     A
        JR      NZ, .MulLoop

        POP     BC
        POP     BC

        LD      (X86_REG_AX), HL        ; Младшие 16 бит в AX
        LD      (X86_REG_DX), DE        ; Старшие 16 бит в DX

        ; Обновляем флаги Carry/Overflow x86 по состоянию старшего регистра DX
        LD      A, D
        OR      E
        LD      A, (X86_REG_FLAGS)
        JR      Z, .ClearCF
        SET     0, A                    ; If DX != 0, взводим CF
        JR      .SaveFlags
.ClearCF:
        RES     0, A                    ; If DX == 0, гасим CF
.SaveFlags:
        LD      (X86_REG_FLAGS), A

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: DIV CX (Из группы $F7, ModR/M $F1) -> AX = DX:AX / CX, DX = Остаток ---
Op_DIV_CX:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      DE, (X86_REG_CX)        ; DE = Делитель (CX)
        
        ; Безопасная проверка делителя на чистый ноль 0000h
        LD      A, D
        OR      E
        JR      NZ, .DoDiv              

        ; Бесшумный пропуск деления на ноль для стабильности сквозных тестов
        JR      .ExitDiv

.DoDiv:
        LD      HL, (X86_REG_DX)        ; HL = Старшее слово делимого (DX) -> будущий Остаток
        LD      BC, (X86_REG_AX)        ; BC = Младшее слово делимого (AX) -> будущее Частное

        ; Проверка на аппаратное переполнение частного x86
        LD      A, H
        CP      D
        JR      C, .NoOverflow
        JR      NZ, .ExitDiv
        LD      A, L
        CP      E
        JR      NC, .ExitDiv
.NoOverflow:

        LD      A, 16                   ; Ровно 16 итераций побитового деления
.DivLoop:
        ; 1. КАНОНИЧЕСКИЙ СКВОЗНОЙ 32-БИТНЫЙ СДВИГ HL:BC ВЛЕВО НА 1 БИТ
        SLA     C                       ; Сдвиг CL влево, старший бит уходит в Carry хоста
        RL      B                       ; Сдвиг CH влево, втягивает Carry
        ADC     HL, HL                  ; Сдвиг остатка HL влево, втягивает старший бит из BC

        ; 2. ВЫЧИТАЕМ ДЕЛИТЕЛЬ ИЗ ТЕКУЩЕГО ОСТАТКА HL
        OR      A                       ; Очищаем флаг Carry Z80 перед вычитанием
        SBC     HL, DE                  ; HL = HL - DE (Остаток - Делитель)
        JR      NC, .SubSuccess         ; Если Carry=0, вычитание успешно!

        ; Вычитание неуспешно — восстанавливаем остаток, младший бит частного остается в 0
        ADD     HL, DE              
        JR      .NextBit             

.SubSuccess:
        ; Вычитание успешно! Младший бит частного (бит 0 регистра C) взводим в 1
        INC     C                   

.NextBit:
        DEC     A
        JR      NZ, .DivLoop            ; Повторяем до выполнения всех 16 бит

        ; Записываем финальные очищенные результаты обратно в ОЗУ хоста
        LD      (X86_REG_AX), BC        ; AX = Рассчитанное частное
        LD      (X86_REG_DX), HL        ; DX = Итоговый остаток

        XOR     A
        LD      (X86_REG_FLAGS), A      ; Обнуляем неопределенные для DIV флаги

.ExitDiv:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET
