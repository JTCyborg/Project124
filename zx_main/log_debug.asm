; =========================================================================
; PERFECT COMMANDER 123 — СЕРВИСНЫЙ МОДУЛЬ МНОГОСТРОЧНОЙ ПЕЧАТИ И HEX-ЛОГОВ
; СИСТЕМНЫЙ ПУТЬ: zx_main/log_debug.asm (ПОЛНЫЙ КОД ЦЕЛИКОМ)
; =========================================================================

LOG_WriteMessageToBuffer::
        PUSH    AF: PUSH BC: PUSH DE: PUSH HL: PUSH IX
        PUSH    HL: POP IX                      

.loop_text:
        LD      A, (IX+0): OR A: JR Z, .msg_finished
        LD      B, A                    

        ; Отправляем символ напрямую в физический знакоместный рендерер экрана
        CALL    Direct_PrintChar           
        INC     IX: JR .loop_text

.msg_finished:
        ; Автоматически закрываем строку лога переводом каретки CR/LF
        CALL    LOG_CloseActiveLine

        POP     IX: POP HL: POP DE: POP BC: POP AF
        RET

LOG_CloseActiveLine::
        PUSH    AF: PUSH BC: PUSH DE: PUSH HL
        LD      A, #0D: CALL Direct_PrintChar
        LD      A, #0A: CALL Direct_PrintChar
        POP     HL: POP DE: POP BC: POP AF
        RET

; -------------------------------------------------------------------------
; ВЫВОД 16-БИТНОГО HEX-ЗНАЧЕНИЯ ИЗ HL НА ЭКРАН ХОСТА
; -------------------------------------------------------------------------
Util_PrintHex16Screen::
        PUSH    AF
        PUSH    BC
        LD      A, H
        CALL    Util_Internal_ScreenHex8   ; Печатаем старший байт (H)
        LD      A, L
        CALL    Util_Internal_ScreenHex8   ; Печатаем младший байт (L)
        POP     BC
        POP     AF
        RET

; -------------------------------------------------------------------------
; ВЫВОД 8-БИТНОГО HEX-ЗНАЧЕНИЯ ИЗ L НА ЭКРАН ХОСТА
; -------------------------------------------------------------------------
Util_PrintHex8Screen::
        PUSH    AF
        PUSH    BC
        LD      A, L
        CALL    Util_Internal_ScreenHex8   ; Печатаем байт напрямую
        POP     BC
        POP     AF
        RET

; -------------------------------------------------------------------------
; ГЛОБАЛЬНАЯ ПОДПРОГРАММА ПОБАЙТОВОГО РЕНДЕРА И ВЫВОДА В HEX НА ЭКРАН
; -------------------------------------------------------------------------
Util_Internal_ScreenHex8::
        PUSH    AF
        RRA: RRA: RRA: RRA                 ; Сдвигаем старший ниббл вниз
        CALL    .local_nibble
        POP     AF
.local_nibble:
        AND     #0F                        ; Изолируем 4 бита
        CP      10
        JR      C, .is_digit
        ADD     A, 7                       ; Коррекция для символов A..F
.is_digit:
        ADD     A, "0"                     ; Перевод в ASCII-код
        CALL    Direct_PrintChar           ; Печать символа в знакоместо экрана
        RET


; =========================================================================
