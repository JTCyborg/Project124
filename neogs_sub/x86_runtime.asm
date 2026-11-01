; =========================================================================
; PROJECT 124 — x86 task runtime and DMA-frame entry.
; Validates the loaded task frame, initializes execution control state,
; invokes the CPU instruction loop and captures final AX/IP.
; =========================================================================
execute_neogs_x86:
        ld      a, (neo_dma_error)
        or      a
        jr      z, .dma_ok
        ld      hl, $FFFF
        ld      (saved_x86_ax), hl
        ld      a, 3
        ld      (x86_exit_status), a
        ld      hl, 0
        ld      (x86_last_ip), hl
        ret

.dma_ok:
        ; DMA frame begins with a little-endian x86 byte length at $5000.
        ld      hl, (X86_DMA_HEADER_ADDR)
        ld      a, h
        or      l
        jp      z, .invalid_x86_length

        ; Maximum code length is $2FFE: $5002 + length must not exceed $8000.
        ld      a, h
        cp      #2F
        jr      c, .x86_length_valid
        jp      nz, .invalid_x86_length
        ld      a, l
        cp      #FF
        jp      nc, .invalid_x86_length

.x86_length_valid:
        ld      de, X86_RAM_RUN_ADDR
        add     hl, de
        ld      (x86_program_end), hl

        call    x86_cpu_reset
        ld      hl, #FFFF
        ld      (x86_steps_remaining), hl
        xor     a
        ld      (x86_exit_status), a

        call    x86_sys_log_started
        ld      bc, X86_RAM_RUN_ADDR
        ld      (x86_reg_ip), bc
        call    x86_execute_loop

        ld      hl, (x86_reg_ax)
        ld      (saved_x86_ax), hl
        ld      (x86_last_ip), bc
        ld      (x86_reg_ip), bc
        ret

.invalid_x86_length:
        ld      hl, #FFFF
        ld      (x86_reg_ax), hl
        ld      (saved_x86_ax), hl
        ld      (x86_last_ip), hl
        ld      a, 4
        ld      (x86_exit_status), a
        ret
