; =========================================================================
; PROJECT 124 — 8086 programmer-visible CPU state and execution control.
; Register values are kept in little-endian words. AX is currently connected
; to the baseline interpreter; the remaining registers/segments/FLAGS are
; initialized now and will be connected as instruction families are added.
; =========================================================================

x86_cpu_reset:
        ld      hl, 0
        ld      (x86_reg_ax), hl
        ld      (x86_reg_cx), hl
        ld      (x86_reg_dx), hl
        ld      (x86_reg_bx), hl
        ld      (x86_reg_sp), hl
        ld      (x86_reg_bp), hl
        ld      (x86_reg_si), hl
        ld      (x86_reg_di), hl
        ld      (x86_reg_es), hl
        ld      (x86_reg_cs), hl
        ld      (x86_reg_ss), hl
        ld      (x86_reg_ds), hl
        ld      (x86_reg_ip), hl
        ld      hl, 2
        ld      (x86_reg_flags), hl
        ret

; 8086 general-purpose registers.
x86_reg_ax:          dw 0
x86_reg_cx:          dw 0
x86_reg_dx:          dw 0
x86_reg_bx:          dw 0
x86_reg_sp:          dw 0
x86_reg_bp:          dw 0
x86_reg_si:          dw 0
x86_reg_di:          dw 0

; 8086 segment registers.
x86_reg_es:          dw 0
x86_reg_cs:          dw 0
x86_reg_ss:          dw 0
x86_reg_ds:          dw 0

; Instruction pointer and FLAGS. Reserved bit 1 is set in the reset image.
x86_reg_ip:          dw 0
x86_reg_flags:       dw 2

; Runtime control, not architecturally visible x86 registers.
x86_steps_remaining: dw 0
x86_program_end:     dw 0
x86_exit_status:     db 0
