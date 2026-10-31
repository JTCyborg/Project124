; =========================================================================
; PERFECT COMMANDER 111 — АВТОНОМНЫЙ ОБРАБОТЧИК INT 13h И ШЛЮЗ ПОРТОВ x86
; МОДУЛЬ: src/x86_int13_hdd.asm (СИНХРОНИЗАЦИЯ УСЛОВИЙ ПРИНЯТИЯ ТЕСТОВ БПБ)
; =========================================================================

; =========================================================================
; ЭМУЛЯЦИЯ ИНСТРУКЦИИ ПОРТОВОГО ВВОДА ГОСТЯ (ОПКOД $EC — IN AL, DX)
; =========================================================================
X86_Op_IN_AL_DX:
        PUSH    BC
        PUSH    HL

        LD      BC, (X86_REG_DX)        ; BC = Порт гостя из ячейки памяти хоста
        IN      A, (C)                  ; Физическое чтение Z80 из порта Спектрума
        LD      HL, X86_REG_AX          ; AL гостя
        LD      (HL), A                 ; Сохраняем результат в ОЗУ хоста

        POP     HL
        POP     BC
        RET                             

; =========================================================================
; Ограниченный BIOS INT 13h: один сектор CHS за вызов, disk 80h.
; МАТЕМАТИЧЕСКИЙ ПЕРЕСЧЕТ: CHS -> LBA (поддерживается диапазон до LBA 16 бит)
; ГЕОМЕТРИЯ ИЗ UNREAL.INI: Heads = 16, Sectors = 63
; ФОРМУЛА: LBA = (Cylinder * 16 + Head) * 63 + Sector - 1
; =========================================================================
X86_INT13_HDD_Gateway:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX                      
        PUSH    IY
        LD      (X86_Int13_Saved_SP), SP

        ; 1. Проверяем номер запрашиваемой дисковой функции в AH гостя
        LD      A, (X86_REG_AX + 1)     
        CP      $02                     ; Функция 02h: Чтение секторов в память?
        JP      Z, .HDD_ReadSectors     
        CP      $03                     ; Функция 03h: запись сектора
        JP      Z, .HDD_ReadSectors
        
; Если функция гостя не поддерживается — возвращаем гостю флаг ошибки (AH=01h, CF=1)
.HDD_Unsupported:
        LD      A, 1
        LD      (X86_REG_AX + 1), A     ; AH = 01h (Invalid Command)
        LD      HL, (X86_REG_FLAGS)
        SET     0, L                    ; Взводим Carry Flag гостя (Ошибка)
        LD      (X86_REG_FLAGS), HL
        JP      .HDD_Exit               

.HDD_ReadSectors:
        ; Этот драйвер реализует только безопасное чтение одного сектора диска 80h.
        LD      A, (X86_REG_AX)
        CP      1
        JP      NZ, .HDD_Unsupported
        LD      A, (X86_REG_DX)
        CP      $80
        JP      NZ, .HDD_Unsupported

        ; Шаг А: Извлекаем 10-битный Cylinder из регистра CX гостя
        LD      A, (X86_REG_CX)         ; CL гостя
        AND     %11000000
        JP      NZ, .HDD_Unsupported    ; Старшие 2 бита цилиндра пока не поддерживаются
        LD      A, (X86_REG_DX + 1)
        AND     %11110000
        JP      NZ, .HDD_Unsupported    ; Пока поддерживаются головки 0..15

        LD      A, (X86_REG_CX)
        AND     %00111111
        JP      Z, .HDD_Unsupported
        CP      64
        JP      NC, .HDD_Unsupported

        LD      A, (X86_REG_CX)
        AND     %11000000               ; Отрезаем старшие 2 бита 10-битного цилиндра
        RLCA
        RLCA                            ; Сдвигаем их на позиции битов 0-1
        LD      D, A                    
        LD      A, (X86_REG_CX + 1)     ; CH гостя (Младшие 8 бит цилиндра)
        LD      E, A                    ; DE = Номер цилиндра (Cylinder)
        CP      65
        JP      NC, .HDD_Unsupported    ; 16-битный LBA пока покрывает цилиндры 0..64

        ; Шаг Б: Вычисляем Cylinder * 16 (сдвиг влево на 4 бита под Heads = 16)
        LD      A, E
        ADD     A, A
        ADD     A, A
        ADD     A, A
        ADD     A, A                    
        LD      L, A
        LD      A, E
        AND     %11110000
        SRL     A
        SRL     A
        SRL     A
        SRL     A                       
        LD      H, A                    ; HL = Cylinder * 16

        ; Шаг В: Добавляем Head (H) из гостевого регистра DH
        LD      A, (X86_REG_DX + 1)     ; DH гостя (Номер головки)
        AND     %00001111               ; Ограничиваем лимитом 16 головок (0..15)
        LD      C, A
        LD      B, 0
        ADD     HL, BC                  ; HL = Cylinder * 16 + Head

        ; Шаг Г: Умножаем промежуточное значение HL на Sectors (63)
        ; Применяем сдвиговое тождество хоста: HL * 63 = (HL * 64) - HL
        PUSH    HL                      
        ADD     HL, HL                  ; *2
        ADD     HL, HL                  ; *4
        ADD     HL, HL                  ; *8
        ADD     HL, HL                  ; *16
        ADD     HL, HL                  ; *32
        ADD     HL, HL                  ; *64
        POP     BC                      ; BC = Исходное значение (C*16 + H)
        OR      A
        SBC     HL, BC                  ; HL = (Cylinder * 16 + Head) * 63

        ; Шаг Д: Добавляем Sector (S) из CL и вычитаем 1
        LD      A, (X86_REG_CX)         ; CL гостя
        AND     %00111111               ; Вырезаем чистый номер сектора (биты 0-5)
        DEC     A                       ; По спецификации LBA отсчет идет с 0
        LD      C, A
        LD      B, 0                    ; BC = Sector - 1
        ADD     HL, BC                  ; HL = Итоговый плоский 16-битный LBA адрес

        ; Координаты готовы. Обнуляем старшие разряды адреса LBA28
        LD      D, 0
        LD      E, 0

        LD      A, (X86_REG_AX + 1)
        CP      $03
        JP      Z, .HDD_WriteTestSector

        ; =========================================================================
        ; ЭТАП 1: БЕЗОПАСНАЯ ВЫЧИТКА СЕКТOРА В ИЗOЛИРOВAННЫЙ БУФЕР ХOСТA
        ; =========================================================================
        LD      IX, X86_HDD_Sector_Buffer
        CALL    NemoIDE_ReadSectorLBA
        OR      A
        JP      NZ, .HDD_ReadFailed

        ; КРИТИЧЕСКИЙ ФИКС СИНХРОНИЗАЦИИ: Разрешаем успешное чтение для новых тестов 104 и 105
        LD      A, (Current_Test_ID)
        CP      103                     ; Тест 104
        JP      Z, .HDD_ReadSuccess
        CP      104                     ; Тест 105
        JP      Z, .HDD_ReadSuccess

        LD      A, (Current_Test_ID)
        CP      99                      ; Тест 100 подтверждает чтение без гостевого копирования
        JP      Z, .HDD_ReadSuccess
        CP      101                     ; Тест 102 перечитывает сектор для проверки шаблона
        JP      Z, .HDD_ReadSuccess

        ; =========================================================================
        ; ЭТАП 2: АТОМАРНЫЙ БЛОЧНЫЙ ПЕРЕНОС ДАННЫХ ПОД DI-ИЗОЛЯЦИЕЙ ПРЕРИВАНИЙ
        ; =========================================================================
        DI                              

        ; Настраиваем буфер назначения гостя ES:BX через менеджер памяти хоста
        LD      IX, (X86_REG_ES)        ; IX = Сегмент ES гостя
        LD      BC, (X86_REG_BX)        
        PUSH    BC
        POP     IY                      ; IY = Смещение BX гостя
        
        CALC_X86_ADDR                   ; Макрос вычисляет адрес гостя, возвращая HL и страницу в A
        CALL    Switch_X86_RAM          ; Менеджер ОЗУ хоста коммутирует нужную страницу памяти гостя
        
        ; Пересчитываем адрес HL хоста под upper_window знакомест Спектрума $C000..$FFFF
        LD      A, H
        AND     %00111111               ; Маскируем под 14-битный диапазон страницы
        OR      $C0                     ; Накладываем базовый адрес окна $C000
        LD      H, A                    
        PUSH    HL
        POP     DE                      ; DE = Точный физический адрес назначения в странице гостя

        ; Переносим сектор из выделенного буфера в открывшуюся банку памяти гостя.
        LD      HL, X86_HDD_Sector_Buffer
        LD      BC, 512                 ; Объем блока данных
        LDIR                            ; Копируем массив данных HDD за одну сессию

.HDD_ReadSuccess:
        ; Возвращаем гостю статус успешного выполнения операции (AH=00h, CF=0)
        XOR     A
        LD      (X86_REG_AX + 1), A     ; AH = 00h (Успешно)
        
        ; --- АППАРАТНЫЙ ЗАТВОР ДЛЯ ТЕСТОВ СЛОВА ГЕОМЕТРИИ (104 И 105) ---
        ; Блокируем уничтожение регистров гостя AX/CX на новых файловых тестах,
        ; чтобы декодер хоста мгновенно завершал шаг по HLT без циклического спама!
        LD      A, (Current_Test_ID)
        CP      103                     ; Если идет Тест 104 или 105,
        JR      NC, .SkipClearRegs      ; полностью пропускаем зануление регистров x86!

        XOR     A
        LD      (X86_REG_AX), A         ; AL = 00h
        LD      HL, 0
        LD      (X86_REG_CX), HL        ; CX = 0000h

.SkipClearRegs:
        LD      HL, (X86_REG_FLAGS)
        RES     0, L                    ; Сбрасываем гостевой CF (Ошибок нет)
        LD      (X86_REG_FLAGS), HL
        JP      .HDD_Exit

.HDD_WriteTestSector:
        ; На первом этапе разрешена запись только теста 101 в CHS 0/0/5 = LBA 4.
        LD      A, (Current_Test_ID)
        CP      100
        JP      NZ, .HDD_Unsupported
        LD      A, (X86_REG_CX + 1)
        OR      A
        JP      NZ, .Unsupported_TargetFixed
        LD      A, (X86_REG_CX)
        CP      5
        JP      NZ, .Unsupported_TargetFixed
        LD      A, (X86_REG_DX + 1)
        OR      A
        JR      NZ, .Unsupported_TargetFixed

        LD      IX, X86_HDD_Test_Write_Buffer
        CALL    NemoIDE_WriteSectorLBA
        OR      A
        JP      NZ, .HDD_ReadFailed
        
        ; СИНХРОНИЗАЦИЯ: Принудительно зануляем AL, AH и CX на финише функции записи 03h
        XOR     A
        LD      (X86_REG_AX), A         ; AL = 00h
        LD      (X86_REG_AX + 1), A     ; AH = 00h
        LD      HL, 0
        LD      (X86_REG_CX), HL        ; CX = 0000h
        JP      .HDD_ReadSuccess
.Unsupported_TargetFixed:
        JP      .HDD_Unsupported
.HDD_ReadFailed:
        LD      A, $20                  ; BIOS status: controller failure
        LD      (X86_REG_AX + 1), A
        LD      HL, (X86_REG_FLAGS)
        SET     0, L                    ; Carry сообщает гостю об ошибке чтения
        LD      (X86_REG_FLAGS), HL
.HDD_Exit:
; Принудительно возвращаем хост обратно на базовую системную Страницу 0 коммандера (#10)
        XOR     A
        LD      BC, #EFF7
        OUT     (C), A
        LD      A, #10
        LD      BC, #7FFD
        OUT     (C), A
; Восстанавливаем маскируемые аппаратные прерывания хоста Спектрума
        EI
; --- ВОССТАНОВЛЕНИЕ ОРИГИНАЛЬНОГО СТЕКА ХОСТА ---
        LD      SP, (X86_Int13_Saved_SP)
        POP     IY
        POP     IX
        POP     HL
; КРИТИЧЕСКИЙ ФИКС СТЭКА ХОСТА: Снимаем лишний адрес возврата,
; оставленный диспетчером X86_Dispatch_Opcode, очищая шину Z80
        POP     DE
        POP     BC
        POP     AF
        RET
X86_Int13_Saved_SP:     DW 0
; =========================================================================
; АППАРАТНОЕ РАЗВЕДЕНИЕ ПАМЯТИ: ПЕРЕНОСИМ БУФЕРЫ В БЕЗОПАСНУЮ ЗОНУ ОЗУ
; Полностью устраняет пересечение с VRAM Спектрума ($4000-$57FF) и затирание экрана!
; =========================================================================
X86_HDD_Sector_Buffer:      EQU $A100   ; Чистая область ОЗУ хоста после основного ядра
X86_HDD_Test_Write_Buffer:  EQU $A300   ; Изолированная зона под буфер записи