; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ ЭМУЛЯЦИИ АППАРАТНОГО СТЕКА x86
; МОДУЛЬ: src/x86_stack.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ВНУТРЕННЯЯ ПРОЦЕДУРА: ЗАПИСЬ СЛОВА В ВИРТУАЛЬНЫЙ СТЭК ГОСТЯ ---
; Вход: BC = 16-битное записываемое значение
Push_To_X86_Stack:
        PUSH    HL
        PUSH    DE
        PUSH    BC                      ; Сохраняем записываемое слово

        ; 1. Декрементируем указатель стека x86 на 2 байта (Word)
        LD      HL, (X86_REG_SP)
        DEC     HL
        DEC     HL
        LD      (X86_REG_SP), HL

        ; 2. Рассчитываем плоский адрес (SS * 16 + SP)
        LD      IX, (X86_REG_SS)
        LD      IY, HL
        CALC_X86_ADDR                   ; AHL = Плоский адрес вершины стека гостя
        
        ; Включаем нужную банку памяти гостя из пула 640 Кб
        CALL    Switch_X86_RAM

        ; Проецируем адрес HL на окно диспетчера Спектрума $C000-$FFFF
        LD      A, H
        AND     %00111111
        OR      $C0
        LD      H, A

        ; 3. Физически пишем слово в ОЗУ гостя
        POP     BC                      ; Извлекаем слово обратно
        LD      (HL), C                 ; Пишем младший байт
        INC     HL
        LD      (HL), B                 ; Пишем старший байт

        ; Восстанавливаем базовую банку памяти коммандера (Страница 0)
        CALL    Restore_X86_Host_RAM

        POP     DE
        POP     HL
        RET

; --- ВНУТРЕННЯЯ ПРОЦЕДУРА: СНЯТИЕ СЛОВА ИЗ ВИРТУАЛЬНОГО СТЭКА ГОСТЯ ---
; Выход: BC = Считанное из стека 16-битное значение
Pop_From_X86_Stack:
        PUSH    HL
        PUSH    DE

        ; 1. Рассчитываем плоский адрес текущей вершины (SS * 16 + SP)
        LD      HL, (X86_REG_SP)
        LD      IX, (X86_REG_SS)
        LD      IY, HL
        CALC_X86_ADDR                   ; AHL = Адрес слова на стеке
        
        ; Подключаем память гостя
        CALL    Switch_X86_RAM

        LD      A, H
        AND     %00111111
        OR      $C0
        LD      H, A

        ; 2. Вычитываем слово из ОЗУ гостя
        LD      C, (HL)                 ; Считали младший байт
        INC     HL
        LD      B, (HL)                 ; Считали старший байт (BC = Слово)

        ; Возвращаем страницу Хоста
        PUSH    BC
        CALL    Restore_X86_Host_RAM
        POP     BC

        ; 3. Инкрементируем указатель стека SP на 2 байта вверх
        LD      HL, (X86_REG_SP)
        INC     HL
        INC     HL
        LD      (X86_REG_SP), HL

        POP     DE
        POP     HL
        RET

; --- ОБРАБОТЧИКИ ОПКОДОВ PUSH / POP ---
Op_PUSH_AX:
        LD      BC, (X86_REG_AX)
        CALL    Push_To_X86_Stack
        RET

Op_PUSH_CX:
        LD      BC, (X86_REG_CX)
        CALL    Push_To_X86_Stack
        RET

Op_POP_AX:
        CALL    Pop_From_X86_Stack
        LD      (X86_REG_AX), BC
        RET

Op_POP_CX:
        CALL    Pop_From_X86_Stack
        LD      (X86_REG_CX), BC
        RET

; --- ОБРАБОТЧИК: CALL Rel16 (Опкод $E8) ---
Op_CALL_Rel16:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        ; FETCH: Извлекаем 16-битное относительное смещение прыжка
        CALL    X86_Fetch_Byte
        LD      E, A                    ; E = Младший байт смещения
        CALL    X86_Fetch_Byte
        LD      D, A                    ; DE = Полное относительное смещение (imm16)

        ; Сохраняем текущий IP (адрес возврата) в виртуальный стек гостя
        LD      BC, (X86_REG_IP)
        CALL    Push_To_X86_Stack

        ; Выполняем переход: прибавляем относительное смещение к IP
        LD      HL, (X86_REG_IP)
        ADD     HL, DE
        LD      (X86_REG_IP), HL

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: RET (Опкод $C3) ---
Op_RET:
        PUSH    BC
        CALL    Pop_From_X86_Stack
        LD      (X86_REG_IP), BC        ; Переносим снятый адрес возврата в IP
        POP     BC
        RET
