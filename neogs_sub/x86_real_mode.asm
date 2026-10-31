; =========================================================================
; PROJECT 124 — 8086 real-mode fetch/execute core, Stage 2B
;
; This first executable slice runs guest instructions through CS:IP and the
; physical-memory backend. Supported: NOP, INC AX, MOV AX,imm16, HLT,
; INT imm8, INT3, IRET. It is intentionally not a general 8086 emulator.
;
; x86_real_mode_test installs a guest program at 0000:5002 and an interrupt
; handler at 0000:5100, then executes:
;   MOV AX,0000 / INT 20h / HLT
; handler:
;   MOV AX,1234 / IRET
; The test checks AX, CS:IP return path, FLAGS and SP balance.
; Success: status=0, AX=1A02h. Failure: status=9, AX=1Bxxh.
; =========================================================================

X86_REAL_STEP_LIMIT EQU #FFFF

x86_real_mode_test:
        xor     a
        ld      (x86_real_bounds_enable), a
        call    x86_mem_init

        ; Copy main guest program to physical 0000:5002.
        ld      hl, x86_guest_main_image
        ld      de, #5002
        ld      bc, x86_guest_main_image_end - x86_guest_main_image
        call    x86_real_copy_image
        jp      c, x86_real_test_fail_1

        ; Copy interrupt handler to physical 0000:5100.
        ld      hl, x86_guest_handler_image
        ld      de, #5100
        ld      bc, x86_guest_handler_image_end - x86_guest_handler_image
        call    x86_real_copy_image
        jp      c, x86_real_test_fail_1

        ; Install IVT[20h] = 0000:5100.
        ld      hl, 0
        ld      (x86_mem_segment), hl
        ld      hl, #0080
        ld      (x86_mem_offset), hl
        ld      hl, #5100
        ld      (x86_mem_word_value), hl
        call    x86_mem_write16
        jp      c, x86_real_test_fail_2
        ld      hl, 0
        ld      (x86_mem_segment), hl
        ld      hl, #0082
        ld      (x86_mem_offset), hl
        ld      hl, 0
        ld      (x86_mem_word_value), hl
        call    x86_mem_write16
        jp      c, x86_real_test_fail_2

        ; Initialize guest architectural state.
        ld      hl, 0
        ld      (x86_reg_ax), hl
        ld      (x86_reg_cx), hl
        ld      (x86_reg_dx), hl
        ld      (x86_reg_bx), hl
        ld      (x86_reg_bp), hl
        ld      (x86_reg_si), hl
        ld      (x86_reg_di), hl
        ld      (x86_reg_es), hl
        ld      (x86_reg_ds), hl
        ld      (x86_reg_cs), hl
        ld      hl, #5002
        ld      (x86_reg_ip), hl
        ld      hl, #7000
        ld      (x86_reg_ss), hl
        ld      hl, #0100
        ld      (x86_reg_sp), hl
        ld      hl, #0302
        ld      (x86_reg_flags), hl

        call    x86_real_execute
        jp      c, x86_real_test_fail_3

        ; Handler's MOV AX,1234 must execute before guest IRET returns to HLT.
        ld      hl, (x86_reg_ax)
        ld      de, #1234
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_4

        ; Verify original control-flow context and stack were restored.
        ld      hl, (x86_reg_cs)
        ld      de, 0
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_ip)
        ld      de, #5008
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_sp)
        ld      de, #0100
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_flags)
        ld      de, #0302
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5

        call    x86_real_clear_vector
        jp      c, x86_real_test_fail_6

        ld      hl, #1A02
        ld      (saved_x86_ax), hl
        xor     a
        ld      (x86_exit_status), a
        or      a
        ret

; IN: HL=source in firmware, DE=physical x86 destination, BC=length.
x86_real_copy_image:
        ld      (x86_real_copy_source), hl
        ld      (x86_real_copy_dest), de
        ld      (x86_real_copy_count), bc
x86_real_copy_loop:
        ld      bc, (x86_real_copy_count)
        ld      a, b
        or      c
        ret     z
        ld      hl, (x86_real_copy_source)
        ld      a, (hl)
        ld      (x86_mem_value), a
        ld      hl, (x86_real_copy_dest)
        ld      (x86_mem_addr), hl
        xor     a
        ld      (x86_mem_addr+2), a
        call    x86_mem_write8
        ret     c
        ld      hl, (x86_real_copy_source)
        inc     hl
        ld      (x86_real_copy_source), hl
        ld      hl, (x86_real_copy_dest)
        inc     hl
        ld      (x86_real_copy_dest), hl
        ld      hl, (x86_real_copy_count)
        dec     hl
        ld      (x86_real_copy_count), hl
        jr      x86_real_copy_loop

; Fetch one guest byte from physical ((CS << 4) + IP) & FFFFFh.
; OUT A=byte; guest IP advances only after a successful memory read.
x86_real_fetch8:
        ld      a, (x86_real_bounds_enable)
        or      a
        jr      z, .fetch_unbounded
        ld      hl, (x86_reg_cs)
        ld      a, h
        or      l
        jp      nz, x86_real_fetch_out_of_range
        ld      hl, (x86_reg_ip)
        ld      de, #5002
        or      a
        sbc     hl, de
        jp      c, x86_real_fetch_out_of_range
        ld      hl, (x86_real_task_end)
        ld      de, (x86_reg_ip)
        or      a
        sbc     hl, de
        jp      c, x86_real_fetch_out_of_range
        ld      a, h
        or      l
        jp      z, x86_real_fetch_out_of_range
.fetch_unbounded:
        ld      hl, (x86_reg_ip)
        ld      (x86_mem_offset_work), hl
        ld      hl, (x86_reg_cs)
        ld      (x86_mem_segment), hl
        call    x86_mem_calc_phys
        call    x86_mem_read8
        ret     c
        push    af
        ld      hl, (x86_reg_ip)
        inc     hl
        ld      (x86_reg_ip), hl
        pop     af
        or      a
        ret

x86_real_fetch_out_of_range:
        ld      a, 4
        ld      (x86_exit_status), a
        scf
        ret

x86_real_execute:
        ld      hl, X86_REAL_STEP_LIMIT
        ld      (x86_real_steps), hl
x86_real_next:
        ld      hl, (x86_real_steps)
        ld      a, h
        or      l
        jp      z, x86_real_budget_fail
        dec     hl
        ld      (x86_real_steps), hl

        call    x86_real_fetch8
        ret     c

        cp      #90
        jp      z, x86_real_nop
        cp      #40
        jp      z, x86_real_inc_ax
        cp      #B8
        jp      z, x86_real_mov_ax_imm16
        cp      #BA
        jp      z, x86_real_mov_dx_imm16
        cp      #BB
        jp      z, x86_real_mov_bx_imm16
        cp      #F4
        jp      z, x86_real_hlt
        cp      #CD
        jp      z, x86_real_int_imm8
        cp      #CC
        jp      z, x86_real_int3
        cp      #CF
        jp      z, x86_real_iret

        ld      a, 2
        ld      (x86_exit_status), a
        scf
        ret

x86_real_nop:
        jp      x86_real_next

x86_real_inc_ax:
        ld      hl, (x86_reg_ax)
        inc     hl
        ld      (x86_reg_ax), hl
        jp      x86_real_next

x86_real_mov_ax_imm16:
        call    x86_real_fetch8
        ret     c
        ld      (x86_real_imm_low), a
        call    x86_real_fetch8
        ret     c
        ld      h, a
        ld      a, (x86_real_imm_low)
        ld      l, a
        ld      (x86_reg_ax), hl
        jp      x86_real_next

x86_real_int_imm8:
        call    x86_real_fetch8
        ret     c
        ld      (x86_real_int_vector), a
        call    x86_int_enter
        ret     c
        ld      a, (x86_real_int_vector)
        cp      #10
        jp      nz, x86_real_next
        call    bios_int10_dispatch
        ret     c
        call    x86_iret_return
        ret     c
        jp      x86_real_next

x86_real_mov_bx_imm16:
        call    x86_real_fetch8
        ret     c
        ld      (x86_real_imm_low), a
        call    x86_real_fetch8
        ret     c
        ld      h, a
        ld      a, (x86_real_imm_low)
        ld      l, a
        ld      (x86_reg_bx), hl
        jp      x86_real_next

x86_real_mov_dx_imm16:
        call    x86_real_fetch8
        ret     c
        ld      (x86_real_imm_low), a
        call    x86_real_fetch8
        ret     c
        ld      h, a
        ld      a, (x86_real_imm_low)
        ld      l, a
        ld      (x86_reg_dx), hl
        jp      x86_real_next

x86_real_int3:
        ld      a, 3
        call    x86_int_enter
        ret     c
        jp      x86_real_next

x86_real_iret:
        call    x86_iret_return
        ret     c
        jp      x86_real_next

x86_real_hlt:
        xor     a
        ld      (x86_exit_status), a
        or      a
        ret

x86_real_budget_fail:
        ld      a, 1
        ld      (x86_exit_status), a
        scf
        ret

x86_real_clear_vector:
        ld      hl, 0
        ld      (x86_mem_segment), hl
        ld      hl, #0080
        ld      (x86_mem_offset), hl
        ld      hl, 0
        ld      (x86_mem_word_value), hl
        call    x86_mem_write16
        ret     c
        ld      hl, 0
        ld      (x86_mem_segment), hl
        ld      hl, #0082
        ld      (x86_mem_offset), hl
        ld      hl, 0
        ld      (x86_mem_word_value), hl
        jp      x86_mem_write16

x86_real_test_fail_1:
        ld      a, 1
        jr      x86_real_test_fail
x86_real_test_fail_2:
        ld      a, 2
        jr      x86_real_test_fail
x86_real_test_fail_3:
        ld      a, 3
        jr      x86_real_test_fail
x86_real_test_fail_4:
        ld      a, 4
        jr      x86_real_test_fail
x86_real_test_fail_5:
        ld      a, 5
        jr      x86_real_test_fail
x86_real_test_fail_6:
        ld      a, 6
x86_real_test_fail:
        ld      l, a
        ld      h, #1B
        ld      (saved_x86_ax), hl
        ld      a, 9
        ld      (x86_exit_status), a
        scf
        ret

x86_real_steps:       dw 0
x86_real_copy_source: dw 0
x86_real_copy_dest:   dw 0
x86_real_copy_count:  dw 0
x86_real_imm_low:    db 0
x86_real_int_vector: db 0
x86_real_bounds_enable: db 0
x86_real_task_end: dw 0

x86_guest_main_image:
        db #B8,#00,#00,#CD,#20,#F4
x86_guest_main_image_end:
x86_guest_handler_image:
        db #B8,#34,#12,#CF
x86_guest_handler_image_end:

