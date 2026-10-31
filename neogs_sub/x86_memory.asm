; =========================================================================
; PROJECT 124 — 8086 physical memory backend for NeoGS GS105a
;
; x86 physical $00000-$FFFFF maps to NeoGS RAM pages 4..67
; (NeoGS physical base $010000, page size $4000 / 16 KiB).
; Window C000-FFFF is switched through MPAGEX. This keeps firmware in
; window 0 / page 0 and the current DMA frame in window 1 / page 3.
;
; x86_mem_addr is a 20-bit little-endian address:
;   +0 = bits 7:0, +1 = bits 15:8, +2 = bits 19:16 (valid 0..0F).
;
; API:
;   x86_mem_init: enable NOROM + EXPAG, preserving other GSCFG0 bits.
;   x86_mem_read8:  IN x86_mem_addr; OUT A=value, carry=invalid address.
;   x86_mem_write8: IN x86_mem_addr and x86_mem_value; carry=invalid address.
;   x86_mem_test: destructive test of the reserved 1 MiB x86 RAM region.
;                 status=0, AX=0001 on pass; status=5, AX=phase:page on fail.
;
; The test leaves NOROM+EXPAG enabled. Only window 3 is switched by MPAGEX.
; =========================================================================

X86_MEM_NGSPAGE_BASE EQU 4
X86_MEM_PAGE_COUNT   EQU 64

x86_mem_init:
        in      a, (GSCFG0)
        or      M_NOROM | M_EXPAG
        out     (GSCFG0), a
        ret

; Convert x86_mem_addr into a Z80 pointer in C000-FFFF.
; OUT: HL=window pointer, carry clear; carry set if address > FFFFF.
x86_mem_map_addr:
        ld      a, (x86_mem_addr+2)
        cp      #10
        jr      nc, .bad_address

        ; page = (physical >> 14) + 4
        ; page index = (high_nibble << 2) | (middle_byte >> 6)
        add     a, a
        add     a, a
        ld      b, a
        ld      a, (x86_mem_addr+1)
        rlca
        rlca
        and     #03
        or      b
        add     a, X86_MEM_NGSPAGE_BASE

        ; MPAGEX uses ROL8(page,1); send ROR8(page,1).
        rrca
        out     (MPAGEX), a

        ; Window C000-FFFF maps the selected 16 KiB physical page.
        ld      a, (x86_mem_addr+1)
        and     #3F
        or      #C0
        ld      h, a
        ld      a, (x86_mem_addr)
        ld      l, a
        or      a
        ret

.bad_address:
        scf
        ret

; Read one byte. IN x86_mem_addr[0..2]. OUT A=byte, carry on invalid address.
x86_mem_read8:
        call    x86_mem_map_addr
        ret     c
        ld      a, (hl)
        or      a
        ret

; Write one byte. IN x86_mem_addr[0..2], x86_mem_value.
x86_mem_write8:
        call    x86_mem_map_addr
        ret     c
        ld      a, (x86_mem_value)
        ld      (hl), a
        or      a
        ret

; -------------------------------------------------------------------------
; Destructive physical RAM mapping test.
; Every page receives unique values at offsets 0000 and 3FFF. A second pass
; verifies all 128 locations, detecting missing pages and page aliases.
; -------------------------------------------------------------------------
x86_mem_test:
        call    x86_mem_init
        xor     a
        ld      (x86_mem_page), a
        ld      (x86_mem_phase), a

.write_page_loop:
        call    x86_mem_build_page_start
        ld      a, (x86_mem_page)
        xor     #5A
        ld      (x86_mem_value), a
        call    x86_mem_write8
        jp      c, x86_mem_test_write_start_fail

        call    x86_mem_build_page_end
        ld      a, (x86_mem_page)
        xor     #A5
        ld      (x86_mem_value), a
        call    x86_mem_write8
        jp      c, x86_mem_test_write_end_fail

        ld      a, (x86_mem_page)
        inc     a
        ld      (x86_mem_page), a
        cp      X86_MEM_PAGE_COUNT
        jr      c, .write_page_loop

        xor     a
        ld      (x86_mem_page), a

.verify_page_loop:
        call    x86_mem_build_page_start
        call    x86_mem_read8
        jp      c, x86_mem_test_verify_start_fail
        ld      b, a
        ld      a, (x86_mem_page)
        xor     #5A
        cp      b
        jp      nz, x86_mem_test_verify_start_fail

        call    x86_mem_build_page_end
        call    x86_mem_read8
        jp      c, x86_mem_test_verify_end_fail
        ld      b, a
        ld      a, (x86_mem_page)
        xor     #A5
        cp      b
        jp      nz, x86_mem_test_verify_end_fail

        ld      a, (x86_mem_page)
        inc     a
        ld      (x86_mem_page), a
        cp      X86_MEM_PAGE_COUNT
        jr      c, .verify_page_loop

        ; Success: AX=0001 means all 64 pages passed.
        ld      hl, 1
        ld      (saved_x86_ax), hl
        xor     a
        ld      (x86_exit_status), a
        ret

x86_mem_test_write_start_fail:
        ld      a, 1
        jr      x86_mem_test_fail
x86_mem_test_write_end_fail:
        ld      a, 2
        jr      x86_mem_test_fail
x86_mem_test_verify_start_fail:
        ld      a, 3
        jr      x86_mem_test_fail
x86_mem_test_verify_end_fail:
        ld      a, 4

x86_mem_test_fail:
        ld      (x86_mem_phase), a
        ld      a, (x86_mem_page)
        ld      l, a
        ld      a, (x86_mem_phase)
        ld      h, a
        ld      (saved_x86_ax), hl
        ld      a, 5
        ld      (x86_exit_status), a
        ret

; Build page * 4000h, offset 0000.
x86_mem_build_page_start:
        xor     a
        ld      (x86_mem_addr), a
        ld      a, (x86_mem_page)
        ld      b, a
        and     #03
        add     a, a
        add     a, a
        add     a, a
        add     a, a
        add     a, a
        add     a, a
        ld      (x86_mem_addr+1), a
        ld      a, b
        rrca
        rrca
        and     #0F
        ld      (x86_mem_addr+2), a
        ret

; Build page * 4000h + 3FFFh.
x86_mem_build_page_end:
        ld      a, #FF
        ld      (x86_mem_addr), a
        ld      a, (x86_mem_page)
        ld      b, a
        and     #03
        add     a, a
        add     a, a
        add     a, a
        add     a, a
        add     a, a
        add     a, a
        or      #3F
        ld      (x86_mem_addr+1), a
        ld      a, b
        rrca
        rrca
        and     #0F
        ld      (x86_mem_addr+2), a
        ret

x86_mem_addr:  db 0, 0, 0
x86_mem_value: db 0
x86_mem_page:  db 0
x86_mem_phase: db 0
