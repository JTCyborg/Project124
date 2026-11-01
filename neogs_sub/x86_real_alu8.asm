; =========================================================================
; PROJECT 124 — 8086 byte ALU and register-direct logical operations
;
; Byte arithmetic: ADD/ADC/SBB/SUB/CMP r/m8,r8 and reverse direction.
; Byte logic: OR/AND/XOR/TEST.
; Word logic: OR/AND/XOR/TEST.
; Only ModR/M mod=11 (register-direct) is accepted in this stage.
; Logical instructions clear CF/OF and deterministically clear undefined AF.
; =========================================================================

; -------------------------------------------------------------------------
; 8-bit arithmetic and logical ModR/M forms.
; A=opcode. Byte register encoding: AL,CL,DL,BL,AH,CH,DH,BH.
; -------------------------------------------------------------------------
x86_real_alu8_modrm:
        ld      (x86_real_opcode), a
        call    x86_real_fetch8
        ret     c
        ld      (x86_alu8_modrm), a
        and     #C0
        cp      #C0
        jp      nz, x86_real_alu_unsupported

        ld      a, (x86_alu8_modrm)
        and     #38
        srl     a
        srl     a
        srl     a
        ld      (x86_alu8_reg), a
        ld      a, (x86_alu8_modrm)
        and     7
        ld      (x86_alu8_rm), a

        xor     a
        ld      (x86_alu8_no_write), a
        ld      (x86_alu8_is_logic), a

        ld      a, (x86_real_opcode)
        cp      #84
        jp      z, .test_rm_destination

        ; Opcode bit 1 selects reg-field destination for reverse forms.
        and     2
        jr      nz, .reg_destination
        ld      a, (x86_alu8_rm)
        ld      (x86_alu8_dst_reg), a
        ld      a, (x86_alu8_reg)
        ld      (x86_alu8_src_reg), a
        jp      .operands_ready
.reg_destination:
        ld      a, (x86_alu8_reg)
        ld      (x86_alu8_dst_reg), a
        ld      a, (x86_alu8_rm)
        ld      (x86_alu8_src_reg), a
        jp      .operands_ready
.test_rm_destination:
        ld      a, (x86_alu8_rm)
        ld      (x86_alu8_dst_reg), a
        ld      a, (x86_alu8_reg)
        ld      (x86_alu8_src_reg), a
        ld      a, 1
        ld      (x86_alu8_no_write), a

.operands_ready:
        ld      a, (x86_alu8_dst_reg)
        call    x86_alu8_read_reg
        ld      (x86_alu8_dst), a
        ld      a, (x86_alu8_src_reg)
        call    x86_alu8_read_reg
        ld      (x86_alu8_src), a

        ld      a, (x86_real_opcode)
        cp      #84
        jr      z, .force_test
        and     #38
        ld      (x86_alu8_mode), a
        cp      #08
        jr      z, .mark_logic
        cp      #20
        jr      z, .mark_logic
        cp      #30
        jr      nz, .capture_carry
.mark_logic:
        ld      a, 1
        ld      (x86_alu8_is_logic), a
        jp      .carry_ready
.force_test:
        ld      a, #20
        ld      (x86_alu8_mode), a
        ld      a, 1
        ld      (x86_alu8_is_logic), a
        jp      .carry_ready

.capture_carry:
        xor     a
        ld      (x86_alu8_carry_in), a
        ld      a, (x86_alu8_mode)
        cp      #10
        jr      z, .read_carry
        cp      #18
        jr      nz, .carry_ready
.read_carry:
        ld      a, (x86_reg_flags)
        and     1
        ld      (x86_alu8_carry_in), a
.carry_ready:
        ld      a, (x86_alu8_is_logic)
        or      a
        jp      nz, .execute_logic
        ld      a, (x86_alu8_mode)
        or      a
        jp      z, .execute_add
        cp      #10
        jp      z, .execute_adc
        cp      #18
        jp      z, .execute_sbb
        ; SUB and CMP.
        ld      a, (x86_alu8_dst)
        ld      b, a
        ld      a, (x86_alu8_src)
        ld      c, a
        ld      a, b
        sub     c
        jp      .arithmetic_done

.execute_add:
        ld      a, (x86_alu8_dst)
        ld      b, a
        ld      a, (x86_alu8_src)
        add     a, b
        jp      .arithmetic_done
.execute_adc:
        ld      a, (x86_alu8_carry_in)
        or      a
        jr      z, .adc_clear
        scf
        jr      .adc_ready
.adc_clear:
        or      a
.adc_ready:
        ld      a, (x86_alu8_dst)
        ld      b, a
        ld      a, (x86_alu8_src)
        adc     a, b
        jp      .arithmetic_done
.execute_sbb:
        ld      a, (x86_alu8_carry_in)
        or      a
        jr      z, .sbb_clear
        scf
        jr      .sbb_ready
.sbb_clear:
        or      a
.sbb_ready:
        ld      a, (x86_alu8_dst)
        ld      b, a
        ld      a, (x86_alu8_src)
        ld      c, a
        ld      a, b
        sbc     a, c
        jp      .arithmetic_done

.execute_logic:
        ld      a, (x86_alu8_dst)
        ld      b, a
        ld      a, (x86_alu8_mode)
        cp      #08
        jr      z, .logic_or
        cp      #20
        jr      z, .logic_and
        ld      a, (x86_alu8_src)
        xor     b
        jr      .logic_done
.logic_or:
        ld      a, (x86_alu8_src)
        or      b
        jr      .logic_done
.logic_and:
        ld      a, (x86_alu8_src)
        and     b
.logic_done:
        ld      (x86_alu8_result), a
        xor     a
        ld      (x86_alu8_carry), a
        ld      (x86_alu8_carry_in), a
        ld      a, (x86_alu8_result)
        ld      l, a
        ld      h, 0
        ld      (x86_logic_result), hl
        ld      a, 1
        ld      (x86_logic_width), a
        call    x86_real_logic_update_flags
        jp      .write_result

.arithmetic_done:
        ; Preserve result before using A to capture Z80 carry.
        ld      (x86_alu8_result), a
        ld      a, 0
        adc     a, 0
        ld      (x86_alu8_carry), a
        call    x86_real_alu8_update_flags

.write_result:
        ld      a, (x86_alu8_no_write)
        or      a
        jp      nz, x86_real_next
        ld      a, (x86_real_opcode)
        and     #38
        cp      #38
        jp      z, x86_real_next
        ld      a, (x86_alu8_dst_reg)
        ld      b, a
        ld      a, (x86_alu8_result)
        ld      c, a
        ld      a, b
        call    x86_alu8_write_reg
        jp      x86_real_next

; Read byte register selected by A; return byte in A.
x86_alu8_read_reg:
        and     7
        cp      4
        jr      c, .low_byte
        sub     4
        add     a, a
        inc     a
        jr      .offset_ready
.low_byte:
        add     a, a
.offset_ready:
        ld      e, a
        ld      d, 0
        ld      hl, x86_reg_ax
        add     hl, de
        ld      a, (hl)
        ret

; Write byte register selected by A; value is in x86_alu8_result.
x86_alu8_write_reg:
        and     7
        cp      4
        jr      c, .low_byte
        sub     4
        add     a, a
        inc     a
        jr      .offset_ready
.low_byte:
        add     a, a
.offset_ready:
        ld      e, a
        ld      d, 0
        ld      hl, x86_reg_ax
        add     hl, de
        ld      a, (x86_alu8_result)
        ld      (hl), a
        ret

; Update arithmetic flags for byte ADD/ADC/SUB/SBB/CMP.
x86_real_alu8_update_flags:
        xor     a
        ld      (x86_alu8_new_flags), a
        ld      (x86_alu8_new_flags+1), a

        ld      a, (x86_alu8_carry)
        or      a
        jr      z, .parity
        ld      hl, x86_alu8_new_flags
        set     0, (hl)
.parity:
        ld      a, (x86_alu8_result)
        and     a
        jp      pe, .set_pf
        jr      .zero
.set_pf:
        ld      hl, x86_alu8_new_flags
        set     2, (hl)
.zero:
        ld      a, (x86_alu8_result)
        or      a
        jr      nz, .sign
        ld      hl, x86_alu8_new_flags
        set     6, (hl)
.sign:
        ld      a, (x86_alu8_result)
        bit     7, a
        jr      z, .auxiliary
        ld      hl, x86_alu8_new_flags
        set     7, (hl)

.auxiliary:
        ld      a, (x86_alu8_mode)
        cp      #18
        jr      nc, .aux_subtract
        ld      a, (x86_alu8_dst)
        and     #0F
        ld      b, a
        ld      a, (x86_alu8_src)
        and     #0F
        add     a, b
        ld      b, a
        ld      a, (x86_alu8_carry_in)
        add     a, b
        cp      #10
        jr      c, .overflow
        jr      .set_af
.aux_subtract:
        ld      a, (x86_alu8_dst)
        and     #0F
        ld      b, a
        ld      a, (x86_alu8_src)
        and     #0F
        ld      c, a
        ld      a, (x86_alu8_carry_in)
        add     a, c
        cp      #10
        jr      nc, .set_af
        ld      c, a
        ld      a, b
        cp      c
        jr      nc, .overflow
.set_af:
        ld      hl, x86_alu8_new_flags
        set     4, (hl)

.overflow:
        ld      a, (x86_alu8_dst)
        ld      b, a
        ld      a, (x86_alu8_result)
        xor     b
        and     #80
        jr      z, .merge
        ld      a, (x86_alu8_dst)
        ld      b, a
        ld      a, (x86_alu8_src)
        xor     b
        and     #80
        ld      b, a
        ld      a, (x86_alu8_mode)
        cp      #18
        jr      nc, .subtract_overflow
        ld      a, b
        or      a
        jr      nz, .merge
        jr      .set_of
.subtract_overflow:
        ld      a, b
        or      a
        jr      z, .merge
.set_of:
        ld      hl, x86_alu8_new_flags+1
        set     3, (hl)
.merge:
        ld      hl, (x86_reg_flags)
        ld      de, #772A
        ld      a, h
        and     d
        ld      h, a
        ld      a, l
        and     e
        ld      l, a
        ld      de, (x86_alu8_new_flags)
        ld      a, h
        or      d
        ld      h, a
        ld      a, l
        or      e
        ld      l, a
        ld      (x86_reg_flags), hl
        ret

; -------------------------------------------------------------------------
; 16-bit register-direct OR/AND/XOR/TEST forms.
; -------------------------------------------------------------------------
x86_real_logic16_modrm:
        ld      (x86_real_opcode), a
        call    x86_real_fetch8
        ret     c
        ld      (x86_logic_modrm), a
        and     #C0
        cp      #C0
        jp      nz, x86_real_alu_unsupported

        ld      a, (x86_logic_modrm)
        and     #38
        srl     a
        srl     a
        srl     a
        ld      (x86_logic_reg), a
        ld      a, (x86_logic_modrm)
        and     7
        ld      (x86_logic_rm), a
        xor     a
        ld      (x86_logic_no_write), a

        ld      a, (x86_real_opcode)
        cp      #85
        jr      z, .test_rm
        and     2
        jr      nz, .reg_destination
        ld      a, (x86_logic_rm)
        ld      (x86_logic_dst_reg), a
        ld      a, (x86_logic_reg)
        ld      (x86_logic_src_reg), a
        jr      .read_values
.reg_destination:
        ld      a, (x86_logic_reg)
        ld      (x86_logic_dst_reg), a
        ld      a, (x86_logic_rm)
        ld      (x86_logic_src_reg), a
        jr      .read_values
.test_rm:
        ld      a, (x86_logic_rm)
        ld      (x86_logic_dst_reg), a
        ld      a, (x86_logic_reg)
        ld      (x86_logic_src_reg), a
        ld      a, 1
        ld      (x86_logic_no_write), a
.read_values:
        ld      a, (x86_logic_dst_reg)
        call    x86_alu_read_reg16
        ld      (x86_logic_dst), hl
        ld      a, (x86_logic_src_reg)
        call    x86_alu_read_reg16
        ld      (x86_logic_src), hl

        ld      a, (x86_real_opcode)
        and     #38
        cp      #08
        jr      z, .word_or
        cp      #20
        jr      z, .word_and
        ; XOR and TEST (TEST is forced to AND).
        cp      #30
        jr      z, .word_xor
        ld      a, #20
        ld      (x86_logic_mode), a
        jr      .word_and
.word_or:
        ld      a, #08
        ld      (x86_logic_mode), a
        ld      hl, (x86_logic_dst)
        ld      de, (x86_logic_src)
        ld      a, l
        or      e
        ld      l, a
        ld      a, h
        or      d
        ld      h, a
        jr      .word_done
.word_and:
        ld      a, #20
        ld      (x86_logic_mode), a
        ld      hl, (x86_logic_dst)
        ld      de, (x86_logic_src)
        ld      a, l
        and     e
        ld      l, a
        ld      a, h
        and     d
        ld      h, a
        jr      .word_done
.word_xor:
        ld      a, #30
        ld      (x86_logic_mode), a
        ld      hl, (x86_logic_dst)
        ld      de, (x86_logic_src)
        ld      a, l
        xor     e
        ld      l, a
        ld      a, h
        xor     d
        ld      h, a
.word_done:
        ld      (x86_logic_result), hl
        ld      a, 2
        ld      (x86_logic_width), a
        call    x86_real_logic_update_flags
        ld      a, (x86_logic_no_write)
        or      a
        jp      nz, x86_real_next
        ld      a, (x86_logic_dst_reg)
        ld      hl, (x86_logic_result)
        call    x86_alu_write_reg16
        jp      x86_real_next

; Shared deterministic logical flags. CF/AF/OF are cleared; PF/ZF/SF
; are calculated from the selected 8-bit or 16-bit result width.
x86_real_logic_update_flags:
        xor     a
        ld      (x86_logic_new_flags), a
        ld      (x86_logic_new_flags+1), a
        ld      hl, (x86_logic_result)
        ld      a, l
        and     a
        jp      pe, .set_pf
        jr      .zero_check
.set_pf:
        ld      hl, x86_logic_new_flags
        set     2, (hl)
.zero_check:
        ld      a, (x86_logic_width)
        cp      1
        jr      z, .byte_zero
        ld      hl, (x86_logic_result)
        ld      a, h
        or      l
        jr      nz, .sign_check
        jr      .set_zf
.byte_zero:
        ld      a, (x86_logic_result)
        or      a
        jr      nz, .sign_check
.set_zf:
        ld      hl, x86_logic_new_flags
        set     6, (hl)
.sign_check:
        ld      a, (x86_logic_width)
        cp      1
        jr      z, .byte_sign
        ld      a, (x86_logic_result+1)
        bit     7, a
        jr      z, .merge
        jr      .set_sf
.byte_sign:
        ld      a, (x86_logic_result)
        bit     7, a
        jr      z, .merge
.set_sf:
        ld      hl, x86_logic_new_flags
        set     7, (hl)
.merge:
        ld      hl, (x86_reg_flags)
        ld      de, #772A
        ld      a, h
        and     d
        ld      h, a
        ld      a, l
        and     e
        ld      l, a
        ld      de, (x86_logic_new_flags)
        ld      a, h
        or      d
        ld      h, a
        ld      a, l
        or      e
        ld      l, a
        ld      (x86_reg_flags), hl
        ret

; Independent guest regression for byte arithmetic and 8/16-bit logic.
x86_real_alu8_logic_test:
        ld      hl, x86_guest_alu8_logic_image
        ld      de, #5400
        ld      bc, x86_guest_alu8_logic_image_end - x86_guest_alu8_logic_image
        call    x86_real_copy_image
        jr      nc, .image_ready
        ld      hl, #1C07
        jp      .set_failure
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
        ld      hl, #5400
        ld      (x86_reg_ip), hl
        ld      hl, #7000
        ld      (x86_reg_ss), hl
        ld      hl, #0100
        ld      (x86_reg_sp), hl
        ld      hl, #0202
        ld      (x86_reg_flags), hl
        call    x86_real_execute
        jr      nc, .execution_ok
        ld      hl, #1C07
        jp      .set_failure
.execution_ok:
        ld      hl, (x86_reg_ax)
        ld      de, #F0F0
        or      a
        sbc     hl, de
        jp      nz, .result_fail
        ld      hl, (x86_reg_cx)
        ld      de, #0F0F
        or      a
        sbc     hl, de
        jp      nz, .result_fail
        ld      hl, (x86_reg_bx)
        ld      de, 0
        or      a
        sbc     hl, de
        jp      nz, .result_fail
        ld      hl, (x86_reg_si)
        ld      de, #0A92
        or      a
        sbc     hl, de
        jp      nz, .flags_fail
        ld      hl, (x86_reg_di)
        ld      de, #0297
        or      a
        sbc     hl, de
        jp      nz, .flags_fail
        ld      hl, (x86_reg_bp)
        ld      de, #0246
        or      a
        sbc     hl, de
        jp      nz, .flags_fail
        ld      hl, (x86_reg_dx)
        ld      de, #0286
        or      a
        sbc     hl, de
        jp      nz, .flags_fail
        ld      hl, (x86_reg_sp)
        ld      de, #0100
        or      a
        sbc     hl, de
        jp      nz, .result_fail
        ld      hl, (x86_reg_flags)
        ld      de, #0246
        or      a
        sbc     hl, de
        jp      nz, .flags_fail
        or      a
        ret
.result_fail:
        ld      hl, #1C08
        jp      .set_failure
.flags_fail:
        ld      hl, #1C09
.set_failure:
        ld      (saved_x86_ax), hl
        ld      a, 9
        ld      (x86_exit_status), a
        scf
        ret

x86_alu8_modrm:       db 0
x86_alu8_mode:        db 0
x86_alu8_reg:         db 0
x86_alu8_rm:          db 0
x86_alu8_dst_reg:     db 0
x86_alu8_src_reg:     db 0
x86_alu8_dst:         db 0
x86_alu8_src:         db 0
x86_alu8_result:      db 0
x86_alu8_carry_in:    db 0
x86_alu8_carry:       db 0
x86_alu8_no_write:    db 0
x86_alu8_is_logic:    db 0
x86_alu8_new_flags:   dw 0

x86_logic_modrm:      db 0
x86_logic_mode:       db 0
x86_logic_reg:        db 0
x86_logic_rm:         db 0
x86_logic_dst_reg:    db 0
x86_logic_src_reg:    db 0
x86_logic_no_write:   db 0
x86_logic_width:      db 0
x86_logic_dst:        dw 0
x86_logic_src:        dw 0
x86_logic_result:     dw 0
x86_logic_new_flags:  dw 0

x86_guest_alu8_logic_image:
        db #B1,#01                 ; MOV CL,01
        db #B0,#10                 ; MOV AL,10
        db #00,#C8                 ; ADD AL,CL (r/m destination) -> 11
        db #B0,#7F                 ; MOV AL,7F
        db #02,#C1                 ; ADD AL,CL (reg destination) -> 80
        db #9C,#5E                 ; PUSHF/POP SI -> 0A92
        db #B0,#00                 ; MOV AL,00
        db #2A,#C1                 ; SUB AL,CL -> FF, CF=1
        db #9C,#5F                 ; PUSHF/POP DI -> 0297
        db #B3,#00                 ; MOV BL,00
        db #12,#D9                 ; ADC BL,CL -> 02 (reg destination, carry-in)
        db #B0,#00                 ; MOV AL,00
        db #2A,#C1                 ; SUB AL,CL -> FF, CF=1
        db #1A,#D9                 ; SBB BL,CL -> 00 (reg destination)
        db #B0,#00                 ; MOV AL,00
        db #2A,#C1                 ; SUB AL,CL -> FF, CF=1
        db #10,#C8                 ; ADC AL,CL -> 01 (r/m destination)
        db #18,#C8                 ; SBB AL,CL -> FF (r/m destination)
        db #B0,#05                 ; MOV AL,05
        db #28,#C8                 ; SUB AL,CL -> 04 (r/m destination)
        db #38,#C8                 ; CMP AL,CL -> flags only, AL stays 04
        db #B0,#01                 ; MOV AL,01
        db #3A,#C1                 ; CMP AL,CL -> ZF=1, AL stays 01
        db #B1,#0F                 ; MOV CL,0F
        db #B0,#F0                 ; MOV AL,F0
        db #20,#C8                 ; AND AL,CL (r/m destination) -> 00
        db #9C,#5D                 ; PUSHF/POP BP -> 0246
        db #B0,#F0                 ; MOV AL,F0
        db #22,#C1                 ; AND AL,CL (reg destination) -> 00
        db #B0,#F0                 ; MOV AL,F0
        db #08,#C8                 ; OR AL,CL (r/m destination) -> FF
        db #9C,#5A                 ; PUSHF/POP DX -> 0286
        db #B0,#F0                 ; MOV AL,F0
        db #0A,#C1                 ; OR AL,CL (reg destination) -> FF
        db #B0,#FF                 ; MOV AL,FF
        db #30,#C8                 ; XOR AL,CL (r/m destination) -> F0
        db #B0,#FF                 ; MOV AL,FF
        db #32,#C1                 ; XOR AL,CL (reg destination) -> F0
        db #84,#C1                 ; TEST AL,CL -> flags only, AL stays F0
        db #B8,#F0,#F0             ; MOV AX,F0F0
        db #B9,#0F,#0F             ; MOV CX,0F0F
        db #21,#C8                 ; AND AX,CX (r/m destination) -> 0000
        db #B8,#F0,#F0             ; MOV AX,F0F0
        db #23,#C1                 ; AND AX,CX (reg destination) -> 0000
        db #B8,#F0,#F0             ; MOV AX,F0F0
        db #09,#C8                 ; OR AX,CX (r/m destination) -> FFFF
        db #B8,#F0,#F0             ; MOV AX,F0F0
        db #0B,#C1                 ; OR AX,CX (reg destination) -> FFFF
        db #B8,#F0,#F0             ; MOV AX,F0F0
        db #31,#C8                 ; XOR AX,CX (r/m destination) -> F0F0
        db #B8,#F0,#F0             ; MOV AX,F0F0
        db #33,#C1                 ; XOR AX,CX (reg destination) -> F0F0
        db #85,#C1                 ; TEST AX,CX -> flags only, AX stays F0F0
        db #F4
x86_guest_alu8_logic_image_end:
