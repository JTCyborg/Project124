; =========================================================================
; PROJECT 124 — 8086 MOV r/m,reg and MOV reg,r/m execution
;
; Implements 88h/89h/8Ah/8Bh:
;   MOV r/m8,r8   MOV r/m16,r16
;   MOV r8,r/m8   MOV r16,r/m16
;
; Supports all 8086 16-bit effective-address forms:
;   [BX+SI], [BX+DI], [BP+SI], [BP+DI], [SI], [DI], [BP], [BX]
;   direct [disp16], signed disp8 and disp16.
; Default segment is DS; BP-based forms default to SS.
; Segment override prefixes are not implemented in this stage.
; =========================================================================

x86_real_mov_modrm:
        ld      (x86_mov_opcode), a
        call    x86_real_fetch8
        ret     c
        call    x86_real_mov_decode_modrm
        ret     c

        ; Opcode bit 0 selects byte/word; bit 1 selects direction.
        ; Internal convention: width=0 means word, width=1 means byte.
        ; 8086 opcode bit 0 is the inverse: 0=byte, 1=word.
        ld      a, (x86_mov_opcode)
        and     1
        xor     1
        ld      (x86_mov_width), a

        ld      a, (x86_mov_opcode)
        and     2
        jr      nz, .register_destination

        ; 88/89: read reg field, then write r/m destination.
        ld      a, (x86_mov_reg)
        call    x86_real_mov_read_reg
        ret     c
        ld      (x86_mov_value), hl
        jp      x86_real_mov_write_rm

.register_destination:
        ; 8A/8B: read r/m source, then write reg field.
        call    x86_real_mov_read_rm
        ret     c
        ld      a, (x86_mov_reg)
        jp      x86_real_mov_write_reg

; -------------------------------------------------------------------------
; Decode ModR/M and 8086 effective address.
; IN: A=ModR/M. OUT: x86_mov_mod/reg/rm/is_reg/effective offset/segment.
; -------------------------------------------------------------------------
x86_real_mov_decode_modrm:
        ld      (x86_mov_modrm), a
        and     #C0
        rlca
        rlca
        ld      (x86_mov_mod), a

        ld      a, (x86_mov_modrm)
        and     #38
        srl     a
        srl     a
        srl     a
        ld      (x86_mov_reg), a

        ld      a, (x86_mov_modrm)
        and     7
        ld      (x86_mov_rm), a

        ld      a, (x86_mov_mod)
        cp      3
        jp      z, .register_operand

        xor     a
        ld      (x86_mov_is_reg), a
        ld      hl, (x86_reg_ds)
        ld      (x86_mov_segment), hl
        ld      hl, 0
        ld      (x86_mov_offset), hl

        ; mod=00,r/m=110 is direct [disp16], not [BP].
        ld      a, (x86_mov_mod)
        or      a
        jr      nz, .decode_base
        ld      a, (x86_mov_rm)
        cp      6
        jr      nz, .decode_base
        call    x86_real_mov_fetch16
        ret     c
        ld      (x86_mov_offset), hl
        jr      .decode_displacement

.decode_base:
        ld      a, (x86_mov_rm)
        cp      0
        jr      z, .base_bx_si
        cp      1
        jr      z, .base_bx_di
        cp      2
        jr      z, .base_bp_si
        cp      3
        jr      z, .base_bp_di
        cp      4
        jr      z, .base_si
        cp      5
        jr      z, .base_di
        cp      6
        jr      z, .base_bp
        jp      .base_bx

.base_bx_si:
        ld      hl, (x86_reg_bx)
        ld      de, (x86_reg_si)
        add     hl, de
        jr      .base_ready
.base_bx_di:
        ld      hl, (x86_reg_bx)
        ld      de, (x86_reg_di)
        add     hl, de
        jr      .base_ready
.base_bp_si:
        call    x86_real_mov_use_ss
        ld      hl, (x86_reg_bp)
        ld      de, (x86_reg_si)
        add     hl, de
        jr      .base_ready
.base_bp_di:
        call    x86_real_mov_use_ss
        ld      hl, (x86_reg_bp)
        ld      de, (x86_reg_di)
        add     hl, de
        jr      .base_ready
.base_si:
        ld      hl, (x86_reg_si)
        jr      .base_ready
.base_di:
        ld      hl, (x86_reg_di)
        jr      .base_ready
.base_bp:
        call    x86_real_mov_use_ss
        ld      hl, (x86_reg_bp)
        jr      .base_ready
.base_bx:
        ld      hl, (x86_reg_bx)

.base_ready:
        ld      (x86_mov_offset), hl

.decode_displacement:
        ld      a, (x86_mov_mod)
        cp      1
        jr      z, .disp8
        cp      2
        jr      z, .disp16
        or      a
        ret

.disp8:
        call    x86_real_fetch8
        ret     c
        ld      e, a
        ld      d, 0
        bit     7, a
        jr      z, .disp8_add
        dec     d
.disp8_add:
        ld      hl, (x86_mov_offset)
        add     hl, de
        ld      (x86_mov_offset), hl
        or      a
        ret

.disp16:
        call    x86_real_mov_fetch16
        ret     c
        ld      de, (x86_mov_offset)
        add     hl, de
        ld      (x86_mov_offset), hl
        or      a
        ret

.register_operand:
        ld      a, 1
        ld      (x86_mov_is_reg), a
        ld      a, (x86_mov_rm)
        ld      (x86_mov_reg_operand), a
        or      a
        ret

x86_real_mov_use_ss:
        ld      hl, (x86_reg_ss)
        ld      (x86_mov_segment), hl
        ret

; Fetch little-endian immediate/displacement through the bounded CS:IP path.
x86_real_mov_fetch16:
        call    x86_real_fetch8
        ret     c
        ld      l, a
        call    x86_real_fetch8
        ret     c
        ld      h, a
        or      a
        ret

; IN A=register index. OUT HL=value (byte values are zero-extended).
x86_real_mov_read_reg:
        ld      (x86_mov_reg_temp), a
        ld      a, (x86_mov_width)
        or      a
        jr      z, .read_word
        ld      a, (x86_mov_reg_temp)
        call    x86_alu8_read_reg
        ld      l, a
        ld      h, 0
        or      a
        ret
.read_word:
        ld      a, (x86_mov_reg_temp)
        jp      x86_alu_read_reg16

; IN A=register index, HL=value.
x86_real_mov_write_reg:
        ld      (x86_mov_reg_temp), a
        ld      (x86_mov_value), hl
        ld      a, (x86_mov_width)
        or      a
        jr      z, .write_word
        ld      hl, (x86_mov_value)
        ld      a, l
        ld      (x86_alu8_result), a
        ld      a, (x86_mov_reg_temp)
        call    x86_alu8_write_reg
        jp      x86_real_next
.write_word:
        ld      hl, (x86_mov_value)
        ld      a, (x86_mov_reg_temp)
        call    x86_alu_write_reg16
        jp      x86_real_next

; Read r/m operand. OUT HL=value; carry on memory fault.
x86_real_mov_read_rm:
        ld      a, (x86_mov_is_reg)
        or      a
        jr      z, .read_memory
        ld      a, (x86_mov_reg_operand)
        jp      x86_real_mov_read_reg
.read_memory:
        ld      hl, (x86_mov_offset)
        ld      (x86_mem_offset), hl
        ld      hl, (x86_mov_segment)
        ld      (x86_mem_segment), hl
        ld      a, (x86_mov_width)
        or      a
        jr      z, .read_memory_word
        ld      hl, (x86_mov_offset)
        ld      (x86_mem_offset_work), hl
        ld      hl, (x86_mov_segment)
        ld      (x86_mem_segment), hl
        call    x86_mem_calc_phys
        call    x86_mem_read8
        ret     c
        ld      l, a
        ld      h, 0
        or      a
        ret
.read_memory_word:
        jp      x86_mem_read16

; Write x86_mov_value to r/m destination.
x86_real_mov_write_rm:
        ld      a, (x86_mov_is_reg)
        or      a
        jr      z, .write_memory
        ld      a, (x86_mov_reg_operand)
        ld      hl, (x86_mov_value)
        jp      x86_real_mov_write_reg
.write_memory:
        ld      hl, (x86_mov_offset)
        ld      (x86_mem_offset), hl
        ld      hl, (x86_mov_segment)
        ld      (x86_mem_segment), hl
        ld      a, (x86_mov_width)
        or      a
        jr      z, .write_memory_word
        ld      hl, (x86_mov_offset)
        ld      (x86_mem_offset_work), hl
        ld      hl, (x86_mov_segment)
        ld      (x86_mem_segment), hl
        call    x86_mem_calc_phys
        ld      a, (x86_mov_value)
        ld      (x86_mem_value), a
        call    x86_mem_write8
        ret     c
        jp      x86_real_next
.write_memory_word:
        ld      hl, (x86_mov_value)
        ld      (x86_mem_word_value), hl
        call    x86_mem_write16
        ret     c
        jp      x86_real_next

x86_mov_opcode:        db 0
x86_mov_modrm:         db 0
x86_mov_mod:           db 0
x86_mov_reg:           db 0
x86_mov_rm:            db 0
x86_mov_reg_operand:   db 0
x86_mov_is_reg:        db 0
x86_mov_width:         db 0
x86_mov_offset:        dw 0
x86_mov_segment:       dw 0
x86_mov_value:         dw 0
x86_mov_reg_temp:      db 0

; -------------------------------------------------------------------------
; Regression test for all four MOV ModR/M opcodes and DS/SS effective
; addressing. Success: carry clear, saved_x86_ax=1D01h.
; -------------------------------------------------------------------------
x86_real_mov_memory_test:
        ld      hl, x86_mov_memory_test_image
        ld      de, #5600
        ld      bc, x86_mov_memory_test_image_end - x86_mov_memory_test_image
        call    x86_real_copy_image
        jr      nc, .image_ready
        ld      hl, #1D01
        jp      .fail

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
        ld      hl, #5600
        ld      (x86_reg_ip), hl
        ld      hl, #7000
        ld      (x86_reg_ss), hl
        ld      hl, #0100
        ld      (x86_reg_sp), hl
        ld      hl, #0202
        ld      (x86_reg_flags), hl

        call    x86_real_execute
        jr      nc, .execution_ok
        ld      hl, #1D02
        jp      .fail

.execution_ok:
        ld      hl, (x86_reg_ax)
        ld      de, #1234
        or      a
        sbc     hl, de
        jp      nz, .fail_ax
        ld      hl, (x86_reg_cx)
        ld      de, #1234
        or      a
        sbc     hl, de
        jp      nz, .fail_cx
        ld      hl, (x86_reg_dx)
        ld      de, #AB34
        or      a
        sbc     hl, de
        jp      nz, .fail_dx
        ld      hl, (x86_reg_bx)
        ld      de, #AB34
        or      a
        sbc     hl, de
        jp      nz, .fail_bx
        ld      hl, (x86_reg_di)
        ld      de, #AB34
        or      a
        sbc     hl, de
        jp      nz, .fail_di
        ld      hl, (x86_reg_si)
        ld      de, #1234
        or      a
        sbc     hl, de
        jp      nz, .fail_si

        ; Verify DS:0200, DS:0004 and DS:0206 word writes.
        ld      hl, 0
        ld      (x86_mem_segment), hl
        ld      hl, #0200
        ld      (x86_mem_offset), hl
        call    x86_mem_read16
        jp      c, .fail_memory
        ld      de, #1234
        or      a
        sbc     hl, de
        jp      nz, .fail_memory

        ld      hl, 0
        ld      (x86_mem_segment), hl
        ld      hl, #0004
        ld      (x86_mem_offset), hl
        call    x86_mem_read16
        jp      c, .fail_memory
        ld      de, #AB34
        or      a
        sbc     hl, de
        jp      nz, .fail_memory

        ld      hl, 0
        ld      (x86_mem_segment), hl
        ld      hl, #0206
        ld      (x86_mem_offset), hl
        call    x86_mem_read16
        jp      c, .fail_memory
        ld      de, #AB34
        or      a
        sbc     hl, de
        jp      nz, .fail_memory

        ; BP-based forms must default to SS rather than DS.
        ld      hl, #7000
        ld      (x86_mem_segment), hl
        ld      hl, #0100
        ld      (x86_mem_offset), hl
        call    x86_mem_read16
        jp      c, .fail_memory
        ld      de, #1234
        or      a
        sbc     hl, de
        jp      nz, .fail_memory

        ld      hl, #1D01
        ld      (saved_x86_ax), hl
        xor     a
        ld      (x86_exit_status), a
        or      a
        ret

.fail_ax:
        ld      hl, #1D30
        jp      .fail
.fail_cx:
        ld      hl, #1D31
        jp      .fail
.fail_dx:
        ld      hl, #1D32
        jp      .fail
.fail_bx:
        ld      hl, #1D33
        jp      .fail
.fail_di:
        ; Diagnostic: return the actual DI value instead of the generic
        ; 1D34 marker so the host log exposes the failed register contents.
        ld      hl, (x86_reg_di)
        ld      (saved_x86_ax), hl
        ld      a, 11
        ld      (x86_exit_status), a
        scf
        ret
.fail_si:
        ld      hl, #1D35
        jp      .fail
.fail_memory:
        ld      hl, #1D04
.fail:
        ld      (saved_x86_ax), hl
        ld      a, 11
        ld      (x86_exit_status), a
        scf
        ret

x86_mov_memory_test_image:
        db #B8,#34,#12             ; MOV AX,1234
        db #8B,#C8                 ; MOV CX,AX (ModR/M register-direct)
        db #89,#CA                 ; MOV DX,CX (reverse register-direct)
        db #BB,#00,#02             ; MOV BX,0200
        db #89,#07                 ; MOV [BX],AX
        db #8B,#0F                 ; MOV CX,[BX]
        db #88,#4F,#02             ; MOV [BX+02],CL
        db #8A,#57,#02             ; MOV DL,[BX+02]
        db #BA,#34,#AB             ; MOV DX,AB34
        db #89,#14                 ; MOV [SI],DX (SI initially zero)
        db #8B,#1C                 ; MOV BX,[SI]
        db #89,#16,#06,#02         ; MOV [0206],DX
        db #8B,#3E,#06,#02         ; MOV DI,[0206]
        db #BD,#00,#01             ; MOV BP,0100
        db #89,#46,#00             ; MOV [BP+00],AX (SS default)
        db #8B,#76,#00             ; MOV SI,[BP+00] (SS default)
        db #F4
x86_mov_memory_test_image_end:
