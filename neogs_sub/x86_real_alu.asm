; =========================================================================
; PROJECT 124 — 8086 real-mode 16-bit register-direct ALU
;
; Supported word register forms:
; ADD 01/03, ADC 11/13, SBB 19/1B, SUB 29/2B, CMP 39/3B.
; ModR/M mod=11 only. Memory operands and 8-bit ALU are not implemented.
; PUSHF 9C is included to make guest FLAGS assertions observable.
; =========================================================================

x86_real_alu_modrm16:
        ld      (x86_real_opcode), a
        call    x86_real_fetch8
        ret     c
        ld      (x86_alu_modrm), a
        and     #C0
        cp      #C0
        jp      nz, x86_real_alu_unsupported

        ld      a, (x86_alu_modrm)
        and     #38
        srl     a
        srl     a
        srl     a
        ld      (x86_alu_reg), a
        ld      a, (x86_alu_modrm)
        and     7
        ld      (x86_alu_rm), a

        ; Opcode bit 1 selects reg-field destination (03/13/1B/2B/3B).
        ld      a, (x86_real_opcode)
        and     2
        jr      nz, .reg_destination
        ld      a, (x86_alu_rm)
        ld      (x86_alu_dst_reg), a
        ld      a, (x86_alu_reg)
        ld      (x86_alu_src_reg), a
        jr      .read_operands
.reg_destination:
        ld      a, (x86_alu_reg)
        ld      (x86_alu_dst_reg), a
        ld      a, (x86_alu_rm)
        ld      (x86_alu_src_reg), a
.read_operands:
        ld      a, (x86_alu_dst_reg)
        call    x86_alu_read_reg16
        ld      (x86_alu_dst), hl
        ld      a, (x86_alu_src_reg)
        call    x86_alu_read_reg16
        ld      (x86_alu_src), hl

        ld      a, (x86_real_opcode)
        and     #38
        ld      (x86_alu_mode), a
        xor     a
        ld      (x86_alu_carry_in), a
        ld      a, (x86_alu_mode)
        cp      #10
        jr      z, .capture_carry
        cp      #18
        jr      nz, .execute
.capture_carry:
        ld      a, (x86_reg_flags)
        and     1
        ld      (x86_alu_carry_in), a

.execute:
        ld      a, (x86_alu_mode)
        or      a
        jr      z, .add
        cp      #10
        jr      z, .adc
        cp      #18
        jr      z, .sbb
        ; SUB and CMP: clear the Z80 carry before SBC HL,DE.
        or      a
        ld      hl, (x86_alu_dst)
        ld      de, (x86_alu_src)
        sbc     hl, de
        jr      .operation_done
.add:
        ld      hl, (x86_alu_dst)
        ld      de, (x86_alu_src)
        add     hl, de
        jr      .operation_done
.adc:
        ld      a, (x86_alu_carry_in)
        or      a
        jr      z, .adc_no_carry
        scf
        jr      .adc_execute
.adc_no_carry:
        or      a
.adc_execute:
        ld      hl, (x86_alu_dst)
        ld      de, (x86_alu_src)
        adc     hl, de
        jr      .operation_done
.sbb:
        ld      a, (x86_alu_carry_in)
        or      a
        jr      z, .sbb_no_borrow
        scf
        jr      .sbb_execute
.sbb_no_borrow:
        or      a
.sbb_execute:
        ld      hl, (x86_alu_dst)
        ld      de, (x86_alu_src)
        sbc     hl, de

.operation_done:
        ; LD does not alter Z80 flags, so ADC A,0 captures arithmetic carry.
        ld      a, 0
        adc     a, 0
        ld      (x86_alu_carry), a
        ld      (x86_alu_result), hl
        call    x86_alu_update_flags

        ; CMP updates FLAGS only; every other supported operation writes dst.
        ld      a, (x86_alu_mode)
        cp      #38
        jp      z, x86_real_next
        ld      a, (x86_alu_dst_reg)
        ld      hl, (x86_alu_result)
        call    x86_alu_write_reg16
        jp      x86_real_next

; A=8086 word register number (AX,CX,DX,BX,SP,BP,SI,DI), OUT HL=value.
x86_alu_read_reg16:
        and     7
        add     a, a
        ld      e, a
        ld      d, 0
        ld      hl, x86_reg_ax
        add     hl, de
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        ex      de, hl
        ret

; A=register number, HL=value.
x86_alu_write_reg16:
        ld      (x86_alu_result), hl
        and     7
        add     a, a
        ld      e, a
        ld      d, 0
        ld      hl, x86_reg_ax
        add     hl, de
        ld      de, (x86_alu_result)
        ld      (hl), e
        inc     hl
        ld      (hl), d
        ret

; Rebuild CF/PF/AF/ZF/SF/OF. All other guest FLAGS bits are preserved.
x86_alu_update_flags:
        xor     a
        ld      (x86_alu_new_flags), a
        ld      (x86_alu_new_flags+1), a

        ld      a, (x86_alu_carry)
        or      a
        jr      z, .parity
        ld      hl, x86_alu_new_flags
        set     0, (hl)
.parity:
        ld      hl, (x86_alu_result)
        ld      a, l
        and     a
        jp      pe, .set_pf
        jr      .zero
.set_pf:
        ld      hl, x86_alu_new_flags
        set     2, (hl)
.zero:
        ld      hl, (x86_alu_result)
        ld      a, h
        or      l
        jr      nz, .sign
        ld      hl, x86_alu_new_flags
        set     6, (hl)
.sign:
        ld      hl, (x86_alu_result)
        bit     7, h
        jr      z, .auxiliary
        ld      hl, x86_alu_new_flags
        set     7, (hl)

.auxiliary:
        ; AF is carry/borrow from bit 3.
        ld      a, (x86_alu_mode)
        cp      #18
        jr      nc, .aux_subtract
        ld      a, (x86_alu_dst)
        and     #0F
        ld      b, a
        ld      a, (x86_alu_src)
        and     #0F
        add     a, b
        ld      b, a
        ld      a, (x86_alu_carry_in)
        add     a, b
        cp      #10
        jr      c, .overflow
        jr      .set_af
.aux_subtract:
        ld      a, (x86_alu_dst)
        and     #0F
        ld      b, a
        ld      a, (x86_alu_src)
        and     #0F
        ld      c, a
        ld      a, (x86_alu_carry_in)
        or      a
        jr      z, .subtract_no_borrow_in
        scf
        jr      .subtract_nibble
.subtract_no_borrow_in:
        or      a
.subtract_nibble:
        ld      a, b
        sbc     a, c
        jr      nc, .overflow
.set_af:
        ld      hl, x86_alu_new_flags
        set     4, (hl)

.overflow:
        ; OF = sign(dst) differs from result, with operation-specific
        ; same-sign (ADD/ADC) or different-sign (SUB/SBB/CMP) operands.
        ld      a, (x86_alu_dst+1)
        ld      b, a
        ld      a, (x86_alu_result+1)
        xor     b
        and     #80
        ld      (x86_alu_sign_change), a
        or      a
        jr      z, .merge
        ld      a, (x86_alu_dst+1)
        ld      b, a
        ld      a, (x86_alu_src+1)
        xor     b
        and     #80
        ld      (x86_alu_sign_diff), a
        ld      a, (x86_alu_mode)
        cp      #18
        jr      nc, .subtract_overflow
        ld      a, (x86_alu_sign_diff)
        or      a
        jr      nz, .merge
        jr      .set_of
.subtract_overflow:
        ld      a, (x86_alu_sign_diff)
        or      a
        jr      z, .merge
.set_of:
        ld      hl, x86_alu_new_flags+1
        set     3, (hl)

.merge:
        ld      hl, (x86_reg_flags)
        ld      de, #772A             ; preserve non-status/control bits
        ld      a, h
        and     d
        ld      h, a
        ld      a, l
        and     e
        ld      l, a
        ld      de, (x86_alu_new_flags)
        ld      a, h
        or      d
        ld      h, a
        ld      a, l
        or      e
        ld      l, a
        ld      (x86_reg_flags), hl
        ret

; PUSHF — push guest FLAGS through the normal SS:SP memory path.
x86_real_pushf:
        ld      de, (x86_reg_flags)
        call    x86_real_stack_push
        ret     c
        jp      x86_real_next

x86_real_alu_unsupported:
        ld      a, 2
        ld      (x86_exit_status), a
        scf
        ret

; Independent guest regression: results and saved FLAGS are checked by host.
x86_real_alu_test:
        ld      hl, x86_guest_alu_image
        ld      de, #5200
        ld      bc, x86_guest_alu_image_end - x86_guest_alu_image
        call    x86_real_copy_image
        jr      nc, .image_ready
        ld      hl, #1B07
        jr      .set_failure
.image_ready:
        ld      hl, 0
        ld      (x86_reg_ax), hl
        ld      (x86_reg_bx), hl
        ld      (x86_reg_cx), hl
        ld      (x86_reg_dx), hl
        ld      (x86_reg_bp), hl
        ld      (x86_reg_si), hl
        ld      (x86_reg_di), hl
        ld      (x86_reg_ds), hl
        ld      (x86_reg_es), hl
        ld      (x86_reg_cs), hl
        ld      hl, #5200
        ld      (x86_reg_ip), hl
        ld      hl, #7000
        ld      (x86_reg_ss), hl
        ld      hl, #0100
        ld      (x86_reg_sp), hl
        ld      hl, #0202
        ld      (x86_reg_flags), hl

        call    x86_real_execute
        jr      nc, .execution_ok
        ld      hl, #1B07
        jr      .set_failure
.execution_ok:
        ld      hl, (x86_reg_ax)
        ld      de, 1
        or      a
        sbc     hl, de
        jp      nz, .result_fail
        ld      hl, (x86_reg_dx)
        ld      de, 4
        or      a
        sbc     hl, de
        jp      nz, .result_fail
        ld      hl, (x86_reg_bx)
        ld      de, 1
        or      a
        sbc     hl, de
        jp      nz, .result_fail
        ld      hl, (x86_reg_bp)
        ld      de, 3
        or      a
        sbc     hl, de
        jp      nz, .result_fail
        ld      hl, (x86_reg_sp)
        ld      de, #FFFF
        or      a
        sbc     hl, de
        jp      nz, .result_fail
        ld      hl, (x86_reg_di)
        ld      de, #0A96
        or      a
        sbc     hl, de
        jp      nz, .flags_fail
        ld      hl, (x86_reg_si)
        ld      de, #0297
        or      a
        sbc     hl, de
        jp      nz, .flags_fail
        ld      hl, (x86_reg_flags)
        ld      de, #0246
        or      a
        sbc     hl, de
        jp      nz, .flags_fail
        or      a
        ret
.result_fail:
        ld      hl, #1B08
        jr      .set_failure
.flags_fail:
        ld      hl, #1B09
.set_failure:
        ld      (saved_x86_ax), hl
        ld      a, 9
        ld      (x86_exit_status), a
        scf
        ret

x86_alu_modrm:       db 0
x86_alu_mode:        db 0
x86_alu_reg:         db 0
x86_alu_rm:          db 0
x86_alu_dst_reg:     db 0
x86_alu_src_reg:     db 0
x86_alu_carry_in:    db 0
x86_alu_carry:       db 0
x86_alu_sign_change: db 0
x86_alu_sign_diff:   db 0
x86_alu_dst:         dw 0
x86_alu_src:         dw 0
x86_alu_result:      dw 0
x86_alu_new_flags:   dw 0

x86_guest_alu_image:
        db #B8,#FF,#7F             ; MOV AX,7FFF
        db #B9,#01,#00             ; MOV CX,0001
        db #03,#C1                 ; ADD AX,CX -> 8000
        db #9C,#5F                 ; PUSHF / POP DI -> 0A96
        db #70,#01,#00             ; JO taken
        db #78,#01,#00             ; JS taken
        db #7A,#01,#00             ; JP taken
        db #BD,#02,#00             ; MOV BP,0002
        db #01,#CD                 ; ADD BP,CX -> 0003 (r/m destination)
        db #BC,#00,#00             ; MOV SP,0000
        db #29,#CC                 ; SUB SP,CX -> FFFF, CF=1 (r/m destination)
        db #BA,#00,#00             ; MOV DX,0000
        db #13,#D1                 ; ADC DX,CX -> 0002 (reg destination)
        db #B8,#00,#00             ; MOV AX,0000
        db #2B,#C1                 ; SUB AX,CX -> FFFF, CF=1 (reg destination)
        db #11,#CA                 ; ADC DX,CX -> 0004 (r/m destination)
        db #BB,#05,#00             ; MOV BX,0005
        db #1B,#D9                 ; SBB BX,CX -> 0003 (reg destination)
        db #B8,#00,#00             ; MOV AX,0000
        db #2B,#C1                 ; SUB AX,CX -> CF=1
        db #19,#CB                 ; SBB BX,CX -> 0001 (r/m destination)
        db #B8,#01,#00             ; MOV AX,0001
        db #3B,#C1                 ; CMP AX,CX -> ZF=1 (reg destination)
        db #39,#C8                 ; CMP AX,CX -> ZF=1 (r/m destination)
        db #74,#01,#00             ; JE taken
        db #F4
x86_guest_alu_image_end:
