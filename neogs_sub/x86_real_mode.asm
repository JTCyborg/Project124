; =========================================================================
; PROJECT 124 — 8086 real-mode fetch/execute core, Stage 2B
;
; This first executable slice runs guest instructions through CS:IP and the
; physical-memory backend. Supported: NOP, INC AX, MOV r8/r16,imm, HLT,
; INT imm8, INT3, IRET. It is intentionally not a general 8086 emulator.
;
; x86_real_mode_test installs a guest program at 0000:5002 and an interrupt
; handler at 0000:5100. The guest loads all eight general registers with
; MOV r16,imm16, invokes INT 20h, then resumes at HLT after handler IRET.
; The test checks all MOV destinations, interrupt return, FLAGS and SP.
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

        ; Verify all eight MOV r16,imm16 destinations.
        ld      hl, (x86_reg_cx)
        ld      de, #1234
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_dx)
        ld      de, #7856
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_bx)
        ld      de, #BC9A
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_bp)
        ld      de, #ADDE
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_si)
        ld      de, #8000
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_di)
        ld      de, #7FFF
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5

        ; Verify original control-flow context, SP and FLAGS were restored.
        ld      hl, (x86_reg_cs)
        ld      de, 0
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_ip)
        ld      de, #501F
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_sp)
        ld      de, #0100
        or      a
        sbc     hl, de
        jp      nz, x86_real_test_fail_5
        ld      hl, (x86_reg_flags)
        ld      de, #0B16
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
        jp      c, .not_inc_r16
        cp      #48
        jp      c, x86_real_inc_r16
.not_inc_r16:
        cp      #48
        jp      c, .not_dec_r16
        cp      #50
        jp      c, x86_real_dec_r16
.not_dec_r16:
        cp      #B0
        jp      c, .not_mov_r8
        cp      #B8
        jp      c, x86_real_mov_r8_imm8
.not_mov_r8:
        cp      #B8
        jp      c, .not_mov_r16
        cp      #C0
        jp      c, x86_real_mov_r16_imm16
.not_mov_r16:
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

; 40-47 INC r16 and 48-4F DEC r16.
; The register file is contiguous in 8086 encoding order (AX,CX,DX,BX,
; SP,BP,SI,DI). INC/DEC preserve CF and all non-status/control FLAGS bits.
x86_real_inc_r16:
        ld      (x86_real_opcode), a
        xor     a
        ld      (x86_real_incdec_mode), a
        jp      x86_real_incdec_r16

x86_real_dec_r16:
        ld      (x86_real_opcode), a
        ld      a, 1
        ld      (x86_real_incdec_mode), a

x86_real_incdec_r16:
        ld      a, (x86_real_opcode)
        and     7
        add     a, a
        ld      e, a
        ld      d, 0
        ld      hl, x86_reg_ax
        add     hl, de
        ld      (x86_real_reg_ptr), hl

        ; Save original operand before changing the selected guest register.
        ld      a, (hl)
        ld      (x86_real_old_low), a
        inc     hl
        ld      a, (hl)
        ld      (x86_real_old_high), a

        ld      a, (x86_real_old_low)
        ld      l, a
        ld      a, (x86_real_old_high)
        ld      h, a
        ld      a, (x86_real_incdec_mode)
        or      a
        jr      nz, .decrement_word
        inc     hl
        jr      .store_word
.decrement_word:
        dec     hl
.store_word:
        ld      (x86_real_result), hl
        ld      de, (x86_real_reg_ptr)
        ld      a, l
        ld      (de), a
        inc     de
        ld      a, h
        ld      (de), a

        call    x86_real_update_incdec_flags
        jp      x86_real_next

; Update only OF/SF/ZF/AF/PF. CF is copied from the old FLAGS word;
; all reserved/control bits are retained. PF is even parity of result AL.
x86_real_update_incdec_flags:
        ld      a, (x86_reg_flags)
        and     1
        ld      (x86_real_new_flags), a
        xor     a
        ld      (x86_real_new_flags+1), a

        ; PF: even parity of the low result byte.
        ld      hl, (x86_real_result)
        ld      a, l
        and     a
        jp      pe, .set_pf
        jr      .no_pf
.set_pf:
        ld      hl, x86_real_new_flags
        set     2, (hl)
.no_pf:
        ; ZF: full 16-bit result is zero.
        ld      hl, (x86_real_result)
        ld      a, h
        or      l
        jr      nz, .no_zf
        ld      hl, x86_real_new_flags
        set     6, (hl)
.no_zf:
        ; SF: result bit 15.
        ld      hl, (x86_real_result)
        bit     7, h
        jr      z, .no_sf
        ld      hl, x86_real_new_flags
        set     7, (hl)
.no_sf:
        ; AF: INC when old low nibble was F; DEC when it was 0.
        ld      a, (x86_real_old_low)
        and     #0F
        ld      b, a
        ld      a, (x86_real_incdec_mode)
        or      a
        jr      nz, .check_dec_af
        ld      a, b
        cp      #0F
        jr      nz, .no_af
        jr      .set_af
.check_dec_af:
        ld      a, b
        or      a
        jr      nz, .no_af
.set_af:
        ld      hl, x86_real_new_flags
        set     4, (hl)
.no_af:
        ; OF: INC 7FFF->8000; DEC 8000->7FFF.
        ld      a, (x86_real_old_low)
        cp      #FF
        jr      nz, .no_of
        ld      a, (x86_real_old_high)
        cp      #7F
        jr      nz, .no_of
        ld      a, (x86_real_incdec_mode)
        or      a
        jr      nz, .no_of
        jr      .set_of
.set_of:
        ld      hl, x86_real_new_flags
        inc     hl
        set     3, (hl)
.no_of:
        ld      a, (x86_real_incdec_mode)
        or      a
        jr      z, .flags_merge
        ld      a, (x86_real_old_low)
        or      a
        jr      nz, .flags_merge
        ld      a, (x86_real_old_high)
        cp      #80
        jr      nz, .flags_merge
        ld      hl, x86_real_new_flags
        inc     hl
        set     3, (hl)

.flags_merge:
        ; Merge new status bits with all untouched old FLAGS bits.
        ld      hl, (x86_reg_flags)
        ld      de, #772B             ; clear PF/AF/ZF/OF/SF; preserve CF and other bits
        ld      a, h
        and     d
        ld      h, a
        ld      a, l
        and     e
        ld      l, a
        ld      de, (x86_real_new_flags)
        ld      a, h
        or      d
        ld      h, a
        ld      a, l
        or      e
        ld      l, a
        ld      (x86_reg_flags), hl
        ret

; B8-BF — MOV r16,imm16 (AX,CX,DX,BX,SP,BP,SI,DI).
; The eight word registers are contiguous in x86_modrm.asm in opcode order.
x86_real_mov_r16_imm16:
        ld      (x86_real_opcode), a
        call    x86_real_fetch8
        ret     c
        ld      (x86_real_imm_low), a
        call    x86_real_fetch8
        ret     c
        ld      (x86_real_imm_high), a

        ld      a, (x86_real_opcode)
        sub     #B8
        add     a, a
        ld      e, a
        ld      d, 0
        ld      hl, x86_reg_ax
        add     hl, de
        ld      a, (x86_real_imm_low)
        ld      (hl), a
        inc     hl
        ld      a, (x86_real_imm_high)
        ld      (hl), a
        jp      x86_real_next

; B0-B7 — MOV r8,imm8 (AL,CL,DL,BL,AH,CH,DH,BH).
x86_real_mov_r8_imm8:
        ld      (x86_real_opcode), a
        call    x86_real_fetch8
        ret     c
        ld      (x86_real_imm_byte), a
        ld      a, (x86_real_opcode)
        sub     #B0
        cp      4
        jr      c, .low_byte_register
        sub     4
        add     a, a
        inc     a
        jr      .register_offset_ready
.low_byte_register:
        add     a, a
.register_offset_ready:
        ld      e, a
        ld      d, 0
        ld      hl, x86_reg_ax
        add     hl, de
        ld      a, (x86_real_imm_byte)
        ld      (hl), a
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
x86_real_imm_high:   db 0
x86_real_int_vector: db 0
x86_real_opcode: db 0
x86_real_imm_byte: db 0
x86_real_incdec_mode: db 0
x86_real_old_low: db 0
x86_real_old_high: db 0
x86_real_new_flags: dw 0
x86_real_reg_ptr: dw 0
x86_real_result: dw 0
x86_real_bounds_enable: db 0
x86_real_task_end: dw 0

x86_guest_main_image:
        db #B8,#00,#00             ; MOV AX,0000
        db #B9,#34,#12             ; MOV CX,1234
        db #BA,#56,#78             ; MOV DX,7856
        db #BB,#9A,#BC             ; MOV BX,BC9A
        db #BC,#00,#01             ; MOV SP,0100 (preserve test stack)
        db #BD,#DE,#AD             ; MOV BP,ADDE
        db #BE,#FF,#7F             ; MOV SI,7FFF
        db #46                     ; INC SI -> 8000, OF/SF/AF/PF
        db #BF,#00,#80             ; MOV DI,8000
        db #4F                     ; DEC DI -> 7FFF, OF/AF/PF
        db #CD,#20,#F4             ; INT 20h / HLT
x86_guest_main_image_end:
x86_guest_handler_image:
        db #B8,#34,#12,#CF
x86_guest_handler_image_end:

