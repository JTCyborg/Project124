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


; =========================================================================
; =========================================================================
; LOWER SCREEN BITMAP HEX DUMP — PORT #EF
; Dumps ONLY the Spectrum bitmap for the lower half: Y=96..191, 3072 bytes.
; Color attributes are deliberately excluded.
; Output is ASCII HEX with scanline labels and Spectrum bitmap addresses.
; IN: A = frame number.
; =========================================================================
P124_DumpLowerScreen::
        push    af
        push    bc
        push    de
        push    hl
        ld      (P124_VRAM_FRAME), a
        ld      hl, P124_VRAM_DUMP_HEADER
        call    P124_VRAM_DumpString
        ld      a, (P124_VRAM_FRAME)
        call    P124_VRAM_DumpHex8
        ld      hl, P124_VRAM_BITMAP_HEADER
        call    P124_VRAM_DumpString

        ld      a, 96
        ld      (P124_VRAM_Y), a
.bitmap_line:
        ld      a, (P124_VRAM_Y)
        ld      c, 0
        call    bios_dbg_calc_addr
        ld      (P124_VRAM_PTR), hl

        ld      hl, P124_VRAM_Y_LABEL
        call    P124_VRAM_DumpString
        ld      a, (P124_VRAM_Y)
        call    P124_VRAM_DumpHex8
        ld      a, ' '
        call    P124_VRAM_DumpPutChar
        ld      a, '@'
        call    P124_VRAM_DumpPutChar
        ld      hl, (P124_VRAM_PTR)
        call    P124_VRAM_DumpHex16
        ld      a, ':'
        call    P124_VRAM_DumpPutChar
        ld      a, ' '
        call    P124_VRAM_DumpPutChar

        ld      b, 32
.bitmap_byte:
        ld      hl, (P124_VRAM_PTR)
        ld      a, (hl)
        call    P124_VRAM_DumpHex8
        ld      hl, (P124_VRAM_PTR)
        inc     hl
        ld      (P124_VRAM_PTR), hl
        ld      a, ' '
        call    P124_VRAM_DumpPutChar
        djnz    .bitmap_byte

        call    P124_VRAM_DumpCRLF
        ld      a, (P124_VRAM_Y)
        inc     a
        ld      (P124_VRAM_Y), a
        cp      192
        jr      c, .bitmap_line

        ld      hl, P124_VRAM_DUMP_END
        call    P124_VRAM_DumpString
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

P124_VRAM_DumpString:
        push    hl
.string_next:
        ld      a, (hl)
        or      a
        jr      z, .string_done
        call    P124_VRAM_DumpPutChar
        inc     hl
        jr      .string_next
.string_done:
        pop     hl
        ret

; A = byte, output two uppercase hexadecimal digits.
P124_VRAM_DumpHex8:
        push    af
        rrca
        rrca
        rrca
        rrca
        call    P124_VRAM_DumpNibble
        pop     af
        call    P124_VRAM_DumpNibble
        ret

; HL = 16-bit value, output four uppercase hexadecimal digits.
P124_VRAM_DumpHex16:
        push    hl
        ld      a, h
        call    P124_VRAM_DumpHex8
        ld      a, l
        call    P124_VRAM_DumpHex8
        pop     hl
        ret

P124_VRAM_DumpNibble:
        and     #0F
        cp      10
        jr      c, .nibble_digit
        add     a, 7
.nibble_digit:
        add     a, '0'
        jp      P124_VRAM_DumpPutChar

; A = ASCII character. Preserve caller registers used by dump loops.
P124_VRAM_DumpPutChar:
        push    af
        push    bc
        ld      bc, #00EF
        out     (c), a
        pop     bc
        pop     af
        ret

P124_VRAM_DumpCRLF:
        push    af
        ld      a, 13
        call    P124_VRAM_DumpPutChar
        ld      a, 10
        call    P124_VRAM_DumpPutChar
        pop     af
        ret

P124_VRAM_DUMP_HEADER:   defb 13,10,"===== P124 BITMAP FRAME ",0
P124_VRAM_BITMAP_HEADER: defb " LOWER SCREEN PIXELS Y=96..191 (32 BYTES/SCANLINE) =====",13,10,0
P124_VRAM_Y_LABEL:       defb "Y=",0
P124_VRAM_DUMP_END:      defb "===== END P124 BITMAP FRAME =====",13,10,0
P124_VRAM_FRAME:         db 0
P124_VRAM_Y:             db 0
P124_VRAM_PTR:           dw 0
