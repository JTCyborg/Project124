; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ СТРОКОВЫХ ЦЕПОЧЕЧНЫХ ИНСТРУКЦИЙ x86
; МОДУЛЬ: src/x86_strings.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ОБРАБОТЧИК: MOVSW (Опкод $A5) -> Word [DI] = Word [SI], SI+=2, DI+=2 ---
Op_MOVSW:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        ; 1. Рассчитываем плоский адрес источника (DS * 16 + SI)
        LD      HL, (X86_REG_SI)
        LD      IX, (X86_REG_DS)
        LD      IY, HL
        CALC_X86_ADDR                   ; AHL = Плоский адрес источника гостя
        
        ; Подключаем память гостя из пула 640 Кб
        CALL    Switch_X86_RAM

        ; Проецируем адрес HL на окно диспетчера Спектрума $C000-$FFFF
        LD      A, H
        AND     %00111111
        OR      $C0
        LD      H, A

        ; Читаем 16-битное слово из источника [SI]
        LD      E, (HL)                 ; E = Младший байт
        INC     HL
        LD      D, (HL)                 ; DE = Слово данных

        ; 2. Записываем считанное слово DE в приемник (ES * 16 + DI)
        LD      HL, (X86_REG_DI)
        LD      IX, (X86_REG_ES)
        LD      IY, HL
        CALC_X86_ADDR                   ; AHL = Плоский адрес приемника
        
        ; Включаем страницу приемника
        CALL    Switch_X86_RAM

        LD      A, H
        AND     %00111111
        OR      $C0
        LD      H, A

        ; Физически пишем слово в ОЗУ гостя
        LD      (HL), E                 ; Пишем младший байт
        INC     HL
        LD      (HL), D                 ; Пишем старший байт

        ; Восстанавливаем базовую банку памяти коммандера (Страница 0)
        CALL    Restore_X86_Host_RAM

        ; 3. Продвигаем указатели SI и DI на 2 байта вперед (модель с DF=0)
        LD      HL, (X86_REG_SI)
        INC     HL
        INC     HL
        LD      (X86_REG_SI), HL

        LD      HL, (X86_REG_DI)
        INC     HL
        INC     HL
        LD      (X86_REG_DI), HL

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: STOSW (Опкод $AB) -> Word [DI] = AX, DI+=2 ---
Op_STOSW:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        ; Загружаем слово из реального регистра AX виртуальной машины
        LD      DE, (X86_REG_AX)

        ; 1. Рассчитываем плоский адрес приемника (ES * 16 + DI)
        LD      HL, (X86_REG_DI)
        LD      IX, (X86_REG_ES)
        LD      IY, HL
        CALC_X86_ADDR                   ; AHL = Плоский адрес назначения
        
        ; Подключаем память гостя
        CALL    Switch_X86_RAM

        LD      A, H
        AND     %00111111
        OR      $C0
        LD      H, A
        
        ; 2. Записываем слово DE по смещению DI
        LD      (HL), E                 ; Пишем младший байт AX
        INC     HL
        LD      (HL), D                 ; Пишем старший байт AX

        ; Возвращаем базовую страницу Хоста
        CALL    Restore_X86_Host_RAM

        ; 3. Автоматически продвигаем указатель DI на 2 байта вперед
        LD      HL, (X86_REG_DI)
        INC     HL
        INC     HL
        LD      (X86_REG_DI), HL

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET
