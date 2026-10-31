; =========================================================================
; PROJECT 124 — BIOS foundation / POST, stage 1
;
; This module establishes the IBM-PC-compatible low-memory data layout.
; It does NOT yet claim executable BIOS ROM, INT dispatch, or device services.
; The IVT is cleared and reserved; interrupt vectors are installed only when
; the CPU INT/IRET execution path and BIOS service stubs are implemented.
;
; Physical memory profile (20-bit real-mode address space):
;   00000-003FF  Interrupt Vector Table (IVT), 256 x 4 bytes
;   00400-004FF  BIOS Data Area (BDA)
;   00500-9FFFF  conventional RAM window (640 KiB profile)
;   A0000-BFFFF  reserved video-memory window
;   C0000-EFFFF  reserved option-ROM / device window
;   F0000-FFFFF  reserved P124 BIOS ROM window (not mapped read-only yet)
;
; Entry: bios_post
; Exit: x86_exit_status=0, saved_x86_ax=#B105 on success.
;       x86_exit_status=7, saved_x86_ax=#B1xx on POST failure.
; Uses the existing x86 physical-memory backend; no DMA/IPC changes.
; =========================================================================

BIOS_IVT_BASE             EQU #00000
BIOS_IVT_SIZE             EQU #00400
BIOS_BDA_BASE             EQU #00400
BIOS_BDA_SIZE             EQU #00100
BIOS_LOW_MEMORY_END       EQU #00500
BIOS_CONVENTIONAL_KB      EQU 640
BIOS_VIDEO_MODE_TEXT      EQU #03
BIOS_TEXT_COLUMNS         EQU 80
BIOS_TEXT_ROWS            EQU 25
BIOS_POST_SIGNATURE       EQU #B105

; -------------------------------------------------------------------------
; BIOS POST entry.
; -------------------------------------------------------------------------
bios_post:
        call    x86_mem_init
        call    bios_clear_ivt_bda
        jp      c, bios_post_fail_1

        ; BDA equipment word: no IBM-PC legacy equipment bits are asserted.
        ld      hl, #0410
        xor     a
        call    bios_write_byte
        jp      c, bios_post_fail_2
        ld      hl, #0411
        xor     a
        call    bios_write_byte
        jp      c, bios_post_fail_2

        ; Conventional memory size = 640 KiB.
        ld      hl, #0413
        ld      a, #80
        call    bios_write_byte
        jp      c, bios_post_fail_3
        ld      hl, #0414
        ld      a, #02
        call    bios_write_byte
        jp      c, bios_post_fail_3

        ; Keyboard ring buffer starts empty at BDA offset 1Eh.
        ld      hl, #041A
        ld      a, #1E
        call    bios_write_byte
        jp      c, bios_post_fail_4
        ld      hl, #041B
        xor     a
        call    bios_write_byte
        jp      c, bios_post_fail_4
        ld      hl, #041C
        ld      a, #1E
        call    bios_write_byte
        jp      c, bios_post_fail_4
        ld      hl, #041D
        xor     a
        call    bios_write_byte
        jp      c, bios_post_fail_4

        ; Text mode 03h, 80 columns, 4 KiB text page, page zero active.
        ld      hl, #0449
        ld      a, BIOS_VIDEO_MODE_TEXT
        call    bios_write_byte
        jp      c, bios_post_fail_5
        ld      hl, #044A
        ld      a, BIOS_TEXT_COLUMNS
        call    bios_write_byte
        jp      c, bios_post_fail_5
        ld      hl, #044B
        xor     a
        call    bios_write_byte
        jp      c, bios_post_fail_5
        ld      hl, #044C
        xor     a
        call    bios_write_byte
        jp      c, bios_post_fail_5
        ld      hl, #044D
        ld      a, #10
        call    bios_write_byte
        jp      c, bios_post_fail_5
        ld      hl, #0462
        xor     a
        call    bios_write_byte
        jp      c, bios_post_fail_5

        ; 25 rows are represented as rows-minus-one; character height = 16.
        ld      hl, #0484
        ld      a, BIOS_TEXT_ROWS - 1
        call    bios_write_byte
        jp      c, bios_post_fail_6
        ld      hl, #0485
        ld      a, #10
        call    bios_write_byte
        jp      c, bios_post_fail_6
        ld      hl, #0486
        xor     a
        call    bios_write_byte
        jp      c, bios_post_fail_6

        ; POST read-back: verify IVT boundaries and the published BDA profile.
        ld      hl, #0000
        call    bios_read_byte
        jp      c, bios_post_fail_7
        or      a
        jp      nz, bios_post_fail_7

        ld      hl, #03FF
        call    bios_read_byte
        jp      c, bios_post_fail_7
        or      a
        jp      nz, bios_post_fail_7

        ld      hl, #0413
        ld      a, #80
        call    bios_expect_byte
        jp      c, bios_post_fail_8
        ld      hl, #0414
        ld      a, #02
        call    bios_expect_byte
        jp      c, bios_post_fail_8
        ld      hl, #0449
        ld      a, BIOS_VIDEO_MODE_TEXT
        call    bios_expect_byte
        jp      c, bios_post_fail_8
        ld      hl, #044A
        ld      a, BIOS_TEXT_COLUMNS
        call    bios_expect_byte
        jp      c, bios_post_fail_8
        ld      hl, #0484
        ld      a, BIOS_TEXT_ROWS - 1
        call    bios_expect_byte
        jp      c, bios_post_fail_8

        ld      hl, BIOS_POST_SIGNATURE
        ld      (saved_x86_ax), hl
        xor     a
        ld      (x86_exit_status), a
        ld      hl, bios_msg_post_pass
        call    neo_debug_puts
        or      a
        ret

; -------------------------------------------------------------------------
; Clear IVT + BDA (first 1280 bytes) before publishing the BDA profile.
; -------------------------------------------------------------------------
bios_clear_ivt_bda:
        ld      hl, BIOS_IVT_BASE
        ld      (bios_clear_address), hl
        ld      hl, BIOS_LOW_MEMORY_END
        ld      (bios_clear_remaining), hl
        xor     a
        ld      (x86_mem_value), a

.bios_clear_loop:
        ld      hl, (bios_clear_address)
        ld      (x86_mem_addr), hl
        xor     a
        ld      (x86_mem_addr+2), a
        call    x86_mem_write8
        ret     c

        ld      hl, (bios_clear_address)
        inc     hl
        ld      (bios_clear_address), hl
        ld      hl, (bios_clear_remaining)
        dec     hl
        ld      (bios_clear_remaining), hl
        ld      a, h
        or      l
        jr      nz, .bios_clear_loop
        or      a
        ret

; IN: HL=16-bit physical address, A=value. Carry reports memory error.
bios_write_byte:
        ld      (bios_work_value), a
        ld      (x86_mem_addr), hl
        xor     a
        ld      (x86_mem_addr+2), a
        ld      a, (bios_work_value)
        ld      (x86_mem_value), a
        jp      x86_mem_write8

; IN: HL=16-bit physical address. OUT: A=value, carry on memory error.
bios_read_byte:
        ld      (x86_mem_addr), hl
        xor     a
        ld      (x86_mem_addr+2), a
        jp      x86_mem_read8

; IN: HL=address, A=expected byte. Carry if read fails or value differs.
bios_expect_byte:
        ld      (bios_work_value), a
        call    bios_read_byte
        ret     c
        ld      b, a
        ld      a, (bios_work_value)
        cp      b
        ret     z
        scf
        ret

bios_post_fail_1:
        ld      a, 1
        jr      bios_post_fail
bios_post_fail_2:
        ld      a, 2
        jr      bios_post_fail
bios_post_fail_3:
        ld      a, 3
        jr      bios_post_fail
bios_post_fail_4:
        ld      a, 4
        jr      bios_post_fail
bios_post_fail_5:
        ld      a, 5
        jr      bios_post_fail
bios_post_fail_6:
        ld      a, 6
        jr      bios_post_fail
bios_post_fail_7:
        ld      a, 7
        jr      bios_post_fail
bios_post_fail_8:
        ld      a, 8

bios_post_fail:
        ld      (bios_post_error), a
        ld      l, a
        ld      h, #B1
        ld      (saved_x86_ax), hl
        ld      a, 7
        ld      (x86_exit_status), a
        ld      hl, bios_msg_post_fail
        call    neo_debug_puts
        ld      a, (bios_post_error)
        call    neo_debug_putc
        or      a
        scf
        ret

bios_clear_address:   dw 0
bios_clear_remaining: dw 0
bios_work_value:      db 0
bios_post_error:      db 0

bios_msg_post_pass:
        db "[BIOS] POST PASS: IVT cleared; BDA initialized and verified.", 13, 0
bios_msg_post_fail:
        db "[BIOS] POST FAIL: phase=", 0
