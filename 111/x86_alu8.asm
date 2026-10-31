; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ 8-БИТНОЙ ОСНОВНОЙ АРИФМЕТИКИ x86 (ALU8)
; МОДУЛЬ: src/x86_alu8.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ВСПОМОГАТЕЛЬНАЯ ПРОЦЕДУРА: ОБНОВЛЕНИЕ 8-БИТНЫХ ФЛАГОВ x86 ---
; Вход: A = Результат операции, C = Флаги Z80
Update_X86_Flags8:
        PUSH    AF
        PUSH    BC
        
        LD      B, 0                    ; Результирующий байт флагов x86

        ; 1. Перенос Carry (Бит 0 x86) -> берется из бита 0 флагов Z80 (регистр C)
        BIT     0, C                
        JR      Z, .CheckZero
        SET     0, B                    ; Ставим CF

.CheckZero:
        ; 2. Флаг нуля Zero (Бит 2 x86) -> проверяем внешний результат в аккумуляторе A
        OR      A                       ; Выставляет флаг нуля Z80 для аккумулятора A
        JR      NZ, .CheckSign
        SET     2, B                    ; Ставим ZF

.CheckSign:
        ; 3. Флаг знака Sign (Бит 3 x86) -> проверяем старший бит результата в A
        BIT     7, A                    
        JR      Z, .SaveFlags
        SET     3, B                    ; Ставим SF

.SaveFlags:
        LD      A, B
        LD      (X86_REG_FLAGS), A      ; Записываем байт флагов
        
        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: ADD AL, CL (Опкод $02, $C1) ---
Op_ADD_AL_CL:
        PUSH    AF
        PUSH    BC
        
        LD      A, (X86_REG_AX)         ; A = AL
        LD      C, A
        LD      A, (X86_REG_CX)         ; A = CL
        LD      B, A                    ; B = CL
        LD      A, C                    ; A = AL

        ADD     A, B                    ; AL = AL + CL
        LD      (X86_REG_AX), A         ; Сохраняем результат обратно в AL
        
        PUSH    AF
        POP     BC                      ; Извлекаем флаги Z80 в регистр C
        CALL    Update_X86_Flags8

        POP     BC
        POP     AF
        RET

; --- ОБРАБОТЧИК: SUB AH, CH (Опкод $2A, $E5) ---
Op_SUB_AH_CH:
        PUSH    AF
        PUSH    BC

        LD      A, (X86_REG_AX + 1)     ; A = AH
        LD      C, A
        LD      A, (X86_REG_CX + 1)     ; A = CH
        LD      B, A                    ; B = CH
        LD      A, C                    ; A = AH

        SUB     B                       ; AH = AH - CH
        LD      (X86_REG_AX + 1), A     ; Сохраняем результат обратно в AH

        PUSH    AF
        POP     BC                      ; Извлекаем флаги Z80 в регистр C
        CALL    Update_X86_Flags8

        POP     BC
        POP     AF
        RET

; =========================================================================
; НOВЫЙ АТОМАРНЫЙ ОБРАБОТЧИК ДЛЯ ТЕСТОВ ЗНАКОВЫХ ПЕРЕХОДОВ 45..46
; =========================================================================

; --- ОБРАБОТЧИК: CMP AL, CL (Опкод $3A, $C1) ---
; Выполняет вычитание AL - CL только для обновления флагов x86,
; само значение в регистре AL гостя x86 остается нетронутым.
Op_CMP_AL_CL:
        PUSH    AF
        PUSH    BC

        LD      A, (X86_REG_AX)         ; A = AL гостя
        LD      C, A                    ; Запоминаем AL в C
        LD      A, (X86_REG_CX)         ; A = CL гостя
        LD      B, A                    ; B = CL
        LD      A, C                    ; Восстанавливаем A = AL

        SUB     B                       ; Выполняем сравнение через вычитание (AL - CL)
        
        PUSH    AF
        POP     BC                      ; Извлекаем полученные флаги Z80 хоста в регистр C
        CALL    Update_X86_Flags8       ; Вызываем твою родную процедуру упаковки флагов x86!

        POP     BC
        POP     AF
        RET
