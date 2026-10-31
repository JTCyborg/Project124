; =========================================================================
; PROJECT 124 — base x86 instruction handlers and fault exits.
; Keep handlers independent from opcode table layout.
; =========================================================================
; 90 — NOP
x86_nop:
        ld      (x86_reg_ax), hl
        jp      x86_next_instruction

; 40 — INC AX
x86_inc_ax:
        inc     hl
        ld      (x86_reg_ax), hl
        jp      x86_next_instruction

; B8 iw — MOV AX, imm16 (little-endian immediate)
x86_mov_ax_imm16:
        ; B8 requires two immediate bytes. Reject a truncated instruction.
        ld      hl, (x86_program_end)
        or      a
        sbc     hl, bc
        ld      de, 2
        or      a
        sbc     hl, de
        jp      c, x86_ip_out_of_range

        ld      l, c
        ld      h, b
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        ld      b, h
        ld      c, l
        ld      (x86_reg_ax), de
        jp      x86_next_instruction

; F4 — HLT: successful end of task
x86_hlt:
        ld      (x86_reg_ax), hl
        call    x86_sys_log_hlt
        xor     a
        ld      (x86_exit_status), a
        ret

; Unsupported instruction: stop rather than executing arbitrary memory.
x86_unsupported:
        ld      (x86_reg_ax), hl
        call    x86_sys_log_unsupported
        ld      a, 2
        ld      (x86_exit_status), a
        ret

x86_ip_out_of_range:
        ld      a, 4
        ld      (x86_exit_status), a
        call    x86_sys_log_bounds
        ld      hl, (x86_reg_ax)
        ret
