; =========================================================================
; PROJECT 124 — x86 instruction fetch / dispatch loop.
; The CPU state, opcode table and execution handlers are separate modules.
; =========================================================================

x86_execute_loop:
x86_next_instruction:
        ; Every opcode fetch must remain strictly below the exclusive end.
        ld      hl, (x86_program_end)
        or      a
        sbc     hl, bc
        jp      c, x86_ip_out_of_range
        ld      a, h
        or      l
        jp      z, x86_ip_out_of_range

        ld      hl, (x86_steps_remaining)
        ld      a, h
        or      l
        jr      nz, .budget_ok
        ld      a, 1
        ld      (x86_exit_status), a
        ld      hl, (saved_z80_ax)
        ret

.budget_ok:
        dec     hl
        ld      (x86_steps_remaining), hl

        ; Fetch opcode and advance IP.
        ld      a, (bc)
        inc     bc

        ; Resolve handler from 256-entry WORD table.
        ld      l, a
        ld      h, 0
        add     hl, hl
        ld      de, x86_jump_table
        add     hl, de
        ld      e, (hl)
        inc     hl
        ld      d, (hl)

        ; Restore AX in HL and jump to the selected handler. PUSH/RET is
        ; the Z80's safe indirect-jump idiom; BC remains the virtual x86 IP.
        ld      hl, (saved_z80_ax)
        push    de
        ret

; Decoder table and instruction-family execution modules.
        INCLUDE "x86_decode.asm"
        INCLUDE "x86_exec_base.asm"
        INCLUDE "x86_cpu_state.asm"
