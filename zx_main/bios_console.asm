; =========================================================================
; PROJECT 124 — BIOS 6x8 debug console backend
; Lower Spectrum window: 42 columns x 12 rows, 6 pixels x 8 scanlines.
; Uses font68.bin (96 glyphs, 8 bytes per glyph). This renderer is separate
; from Direct_PrintChar so existing 32-column Commander panels are unchanged.
; =========================================================================

BIOS_DEBUG_COLUMNS EQU 42
BIOS_DEBUG_ROWS    EQU 12
BIOS_DEBUG_TOP     EQU 12

BIOS_DebugConsole_Init::
        ld      a, (Console_Y)
        sub     BIOS_DEBUG_TOP
        jr      nc, .row_ok
        xor     a
.row_ok:
        cp      BIOS_DEBUG_ROWS
        jr      c, .row_valid
        ld      a, BIOS_DEBUG_ROWS - 1
.row_valid:
        ld      (bios_dbg_row), a
        ld      a, (Console_X)
        cp      BIOS_DEBUG_COLUMNS
        jr      c, .col_valid
        xor     a
.col_valid:
        ld      (bios_dbg_col), a
        ret

; Clear only the lower 96-pixel-high window, not the Commander file panel.
BIOS_DebugConsole_Clear::
        push    af
        push    bc
        push    de
        push    hl
        ld      a, 96
        ld      (bios_dbg_clear_y), a
.clear_scanline:
        ld      a, (bios_dbg_clear_y)
        ld      c, 0
        call    bios_dbg_calc_addr
        push    hl
        pop     de
        inc     de
        ld      (hl), 0
        ld      bc, 31
        ldir
        ld      a, (bios_dbg_clear_y)
        inc     a
        ld      (bios_dbg_clear_y), a
        cp      192
        jr      c, .clear_scanline
        ld      hl, #5980
        ld      de, #5981
        ld      (hl), #44
        ld      bc, 383
        ldir
        xor     a
        ld      (bios_dbg_row), a
        ld      (bios_dbg_col), a
        ld      (Console_Y), a
        ld      a, BIOS_DEBUG_TOP
        ld      (Console_Y), a
        ld      (Console_X), a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; IN: A=row, C=column. Invalid coordinates are ignored.
BIOS_DebugConsole_SetCursor::
        cp      BIOS_DEBUG_ROWS
        ret     nc
        ld      (bios_dbg_row), a
        ld      a, c
        cp      BIOS_DEBUG_COLUMNS
        ret     nc
        ld      (bios_dbg_col), a
        ret

; IN: A=one output byte from the NeoGS stream.
; Printable bytes are drawn as packed 6-pixel glyphs; CR/LF/BS are handled.
BIOS_DebugConsole_PrintChar::
        push    af
        push    bc
        push    de
        push    hl
        ld      (bios_dbg_char), a

        cp      13
        jp      z, .carriage_return
        cp      10
        jp      z, .line_feed
        cp      8
        jp      z, .backspace
        cp      7
        jp      z, .done
        cp      32
        jp      c, .done
        cp      128
        jr      c, .glyph_range_ok
        ld      a, '?'
        ld      (bios_dbg_char), a
.glyph_range_ok:
        ld      a, (bios_dbg_char)
        sub     32
        ld      l, a
        ld      h, 0
        add     hl, hl
        add     hl, hl
        add     hl, hl
        ld      de, FONT_DATA_68
        add     hl, de
        ld      (bios_dbg_font_ptr), hl

        ; Pixel X = column * 6, so 42 cells occupy 252 of 256 pixels.
        ld      a, (bios_dbg_col)
        ld      b, a
        add     a, a
        ld      c, a
        add     a, a
        add     a, c
        ld      (bios_dbg_xpixel), a
        xor     a
        ld      (bios_dbg_scan), a

.glyph_scanline:
        ld      hl, (bios_dbg_font_ptr)
        ld      a, (hl)
        ld      (bios_dbg_bits), a
        inc     hl
        ld      (bios_dbg_font_ptr), hl

        ; Absolute Spectrum scanline = 96 + row*8 + scan.
        ld      a, (bios_dbg_row)
        add     a, a
        add     a, a
        add     a, a
        add     a, 96
        ld      b, a
        ld      a, (bios_dbg_scan)
        add     a, b
        ld      (bios_dbg_y), a

        ld      b, 6
.glyph_pixel:
        ld      a, (bios_dbg_xpixel)
        ld      c, a
        and     7
        ld      (bios_dbg_bitpos), a
        ld      a, c
        srl     a
        srl     a
        srl     a
        ld      c, a
        ld      a, (bios_dbg_y)
        call    bios_dbg_calc_addr

        ld      a, (bios_dbg_bitpos)
        ld      c, a
        ld      a, #80
.mask_loop:
        ld      d, a
        ld      a, c
        or      a
        ld      a, d
        jr      z, .mask_ready
        srl     a
        dec     c
        jr      .mask_loop
.mask_ready:
        ld      (bios_dbg_mask), a
        ld      a, (bios_dbg_bits)
        and     #20
        jr      z, .pixel_clear
        ld      a, (hl)
        ld      e, a
        ld      a, (bios_dbg_mask)
        or      e
        ld      (hl), a
        jr      .pixel_done
.pixel_clear:
        ld      a, (bios_dbg_mask)
        cpl
        ld      e, a
        ld      a, (hl)
        and     e
        ld      (hl), a
.pixel_done:
        ld      a, (bios_dbg_bits)
        add     a, a
        ld      (bios_dbg_bits), a
        ld      a, (bios_dbg_xpixel)
        inc     a
        ld      (bios_dbg_xpixel), a
        djnz    .glyph_pixel

        ld      a, (bios_dbg_scan)
        inc     a
        ld      (bios_dbg_scan), a
        cp      8
        jr      c, .glyph_scanline

        ld      a, (bios_dbg_col)
        inc     a
        ld      (bios_dbg_col), a
        cp      BIOS_DEBUG_COLUMNS
        jr      c, .done
        xor     a
        ld      (bios_dbg_col), a
        call    bios_dbg_newline
        jr      .done

.carriage_return:
        xor     a
        ld      (bios_dbg_col), a
        jr      .done
.line_feed:
        call    bios_dbg_newline
        jr      .done
.backspace:
        ld      a, (bios_dbg_col)
        or      a
        jr      z, .done
        dec     a
        ld      (bios_dbg_col), a
.done:
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; Advance one 8-pixel character row and scroll the existing lower window.
bios_dbg_newline:
        ld      a, (bios_dbg_row)
        inc     a
        cp      BIOS_DEBUG_ROWS
        jr      c, .row_in_range
        call    UI_ScrollConsoleUp
        ld      a, BIOS_DEBUG_ROWS - 1
.row_in_range:
        ld      (bios_dbg_row), a
        ret

; IN: A=absolute Y (0..191), C=screen byte X (0..31).
; OUT: HL=Spectrum bitmap address for that scanline and byte.
bios_dbg_calc_addr:
        ld      d, a
        and     #C0
        rrca
        rrca
        rrca
        ld      h, a
        ld      a, d
        and     #07
        rlca
        rlca
        rlca
        rlca
        rlca
        or      h
        or      #40
        ld      h, a
        ld      a, d
        and     #38
        rlca
        rlca
        add     a, c
        ld      l, a
        ; Start each pixel with a fresh mask = 80h >> (X & 7).
        ld      a, #80
        ld      (bios_dbg_mask), a
        ret

bios_dbg_row:       db 0
bios_dbg_col:       db 0
bios_dbg_char:      db 0
bios_dbg_scan:      db 0
bios_dbg_y:         db 0
bios_dbg_xpixel:    db 0
bios_dbg_bitpos:    db 0
bios_dbg_bits:      db 0
bios_dbg_mask:      db 0
bios_dbg_font_ptr:  dw 0
bios_dbg_clear_y:   db 0
