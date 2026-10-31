; =========================================================================
; ПРОЕКТ 124 — СИСТЕМА ОТЛАДКИ ПОРТА #EF (ИЗ ПРОЕКТА 123)
; СИСТЕМНЫЙ ПУТЬ: zx_main/debug_system.asm (ТОЛЬКО ХАРДВЕРНЫЙ ПОРТ #EF)
; =========================================================================

; --- ГЛОБАЛЬНЫЙ МАКРОС ДЛЯ ВЫВОДА СИМВОЛА В ПОРТ #EF ---
MACRO_EF_CHAR   MACRO   char
                IF ENABLE_HARDWARE_DEBUG == 1
                    PUSH    AF
                    PUSH    BC
                    LD      A, char
                    LD      BC, #00EF
                    OUT     (C), A
                    POP     BC
                    POP     AF
                ENDIF
                ENDM

; --- ГЛОБАЛЬНЫЙ МАКРОС ДЛЯ ВЫВОДА СТРОКИ В ПОРТ #EF ---
MACRO_EF_STRING MACRO   str_addr
                IF ENABLE_HARDWARE_DEBUG == 1
                    PUSH    HL
                    LD      HL, str_addr
                    CALL    DBG_Port_PrintString
                    POP     HL
                ENDIF
                ENDM

; --- ГЛОБАЛЬНЫЙ МАКРОС ДЛЯ ДАМПА 16-БИТНОГО РЕГИСТРА В ПОРТ #EF ---
MACRO_EF_HEX16  MACRO   reg_hl
                IF ENABLE_HARDWARE_DEBUG == 1
                    PUSH    HL
                    PUSH    reg_hl
                    POP     HL
                    CALL    DBG_Port_PrintHex16
                    POP     HL
                ENDIF
                ENDM

; --- ФИЗИЧЕСКИЕ ПОДПРОГРАММЫ ОТЛАДКИ ПОРТА #EF ---
                IF ENABLE_HARDWARE_DEBUG == 1

; ПОДПРОГРАММЫ ГЕНЕРАЦИИ ТАЙМСТАМПА В ПОРТ ОТЛАДКИ #EF
DBG_Port_PrintTimestamp::
        PUSH    AF
        PUSH    BC
        PUSH    HL
        
        CALL    READ_CURRENT_TIME       ; Считываем актуальное время из чипа К512ВИ1
        LD      BC, #00EF               ; Порт вывода отладки
        
        LD      A, "["
        OUT     (C), A
        LD      A, (txt_hour+0)
        OUT     (C), A
        LD      A, (txt_hour+1)
        OUT     (C), A
        LD      A, ":"
        OUT     (C), A
        LD      A, (txt_min+0)
        OUT     (C), A
        LD      A, (txt_min+1)
        OUT     (C), A
        LD      A, ":"
        OUT     (C), A
        LD      A, (txt_sec+0)
        OUT     (C), A
        LD      A, (txt_sec+1)
        OUT     (C), A
        LD      A, "]"
        OUT     (C), A
        LD      A, " "
        OUT     (C), A
        
        POP     HL
        POP     BC
        POP     AF
        RET

; Отправка ASCIIZ строки в порт #EF (с автоматическим таймстампом)
DBG_Port_PrintString::
        PUSH    AF
        PUSH    BC
        PUSH    HL
        
        CALL    DBG_Port_PrintTimestamp ; Принудительно выводим штамп времени

.loop_ef_s:
        LD      A, (HL)
        OR      A                       
        JR      Z, .done_ef_s
        LD      BC, #00EF
        OUT     (C), A
        INC     HL
        JR      .loop_ef_s
.done_ef_s:
        POP     HL
        POP     BC
        POP     AF
        RET

; Вывод 16-битного HEX-значения из HL в порт #EF
DBG_Port_PrintHex16::
        PUSH    AF
        PUSH    BC
        
        LD      A, H
        CALL    .local_hex8
        LD      A, L
        CALL    .local_hex8
        
        POP     BC
        POP     AF
        RET

.local_hex8:
        PUSH    AF
        RRA: RRA: RRA: RRA
        CALL    .local_nibble
        POP     AF
.local_nibble:
        AND     #0F
        CP      10
        JR      C, .is_dig
        ADD     A, 7
.is_dig:
        ADD     A, "0"
        LD      BC, #00EF
        OUT     (C), A
        RET

                ENDIF   ; Конец блока условной компиляции порта #EF


; =========================================================================
