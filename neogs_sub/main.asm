; =========================================================================
; PROJECT 124 — NeoGS Z80 firmware / command dispatcher
; Based on NeoGS Programmer's Guide v0.1.A and ports.inc v0.3.
;
; MEMORY MAP / BOOT:
; The stock GS105a ROM loads a tiny module at $5B00. That module enables
; RAM-over-ROM and receives this firmware at logical RAM address $0000.
; The firmware occupies $0000-$2FFF; its stack is at $3FFF.
; NeoGS logical $4000-$7FFF is the second half of physical RAM page 1,
; therefore logical $5000 maps to physical linear address $00D000.
; The x86 DMA frame is placed at $5000: [length lo][length hi][x86 bytes].
; The interpreter starts at $5002 and is bounded by the exact file length.
; =========================================================================

        INCLUDE "../shared/neogs_io.inc"

        ORG     $0000

ROM_RETURN_TRAMPOLINE_ADDR EQU $4000
X86_DMA_HEADER_ADDR        EQU $5000
X86_RAM_RUN_ADDR           EQU $5002
DMA_WAIT_LIMIT   EQU #FFFF
DMA_WAIT_OUTER   EQU 8
IPC_WAIT_LIMIT   EQU #FFFF

; Firmware entry vector
        jp      start_neoprogram
        BLOCK   53, 0
        ei
        ret
        BLOCK   198, 0

start_neoprogram:
        di
        im      1
        ld      sp, $3FFF

        ; Set Z80 to the documented maximum guaranteed clock: 20 MHz.
        ; Do not select 24 MHz: the guide explicitly says it is not guaranteed.
        in      a, (GSCFG0)
        and     #CF
        or      C_20MHZ
        out     (GSCFG0), a

        xor     a
        ld      (neo_dma_error), a
        ld      (x86_reg_ax), a
        ld      (x86_reg_ax+1), a
        ld      (saved_x86_ax), a
        ld      (saved_x86_ax+1), a
        call    x86_cpu_reset
        ld      (x86_exit_status), a
        ld      (neo_command), a
        ld      (neo_tx_byte), a

        ; Copy the ROM-return trampoline into unoverlaid RAM at $4000.
        ld      hl, rom_return_trampoline_code
        ld      de, ROM_RETURN_TRAMPOLINE_ADDR
        ld      bc, rom_return_trampoline_end - rom_return_trampoline_code
        ldir

        ; First send a textual startup confirmation to the host Z80.
        ld      hl, neo_startup_message
        call    neo_send_startup_text
        jr      c, main_loop

        ; ACK only after the host has received the startup message.
        ld      a, NGS_FIRMWARE_READY_ACK
        call    neo_send_data_byte

main_loop:
        ; A command exists only while CBIT (ZXSTAT bit 0) is set.
        in      a, (ZXSTAT)
        bit     B_CBIT, a
        jr      z, main_loop

        ; Read the command byte from ZXCMD. Reading it does NOT clear CBIT.
        in      a, (ZXCMD)
        ld      (neo_command), a

        ; Standard GS #F4 cold restart also returns this custom firmware to ROM.
        cp      GS_CMD_COLD_RESTART
        jp      z, command_return_to_gsrom
        cp      CMD_RESET
        jp      z, command_reset
        cp      CMD_LOAD_X86
        jp      z, command_load_x86
        cp      CMD_RUN_X86
        jp      z, command_run_x86
        cp      CMD_GET_STATUS
        jp      z, command_get_status
        cp      CMD_MEM_TEST
        jp      z, command_mem_test
        cp      CMD_DEBUG_DRAIN
        jp      z, command_debug_drain

        ; Unknown command: release CBIT so the host cannot deadlock.
        xor     a
        out     (CLRCBIT), a
        jp      main_loop

; A #F4 command is also the standard GS105a cold-restart command.
; If our firmware is running, reveal the stock ROM again and jump to its
; reset vector. Leave CBIT asserted: the ROM's cold-start path clears it when
; the standard firmware is ready, so the host's long wait is a real handshake.
command_return_to_gsrom:
        jp      ROM_RETURN_TRAMPOLINE_ADDR

command_reset:
        xor     a
        ld      (neo_dma_error), a
        ld      (x86_exit_status), a
        ld      (x86_reg_ax), a
        ld      (x86_reg_ax+1), a
        ld      (saved_x86_ax), a
        ld      (saved_x86_ax+1), a
        call    x86_cpu_reset
        ld      (x86_last_ip), a
        ld      (x86_last_ip+1), a
        out     (CLRCBIT), a
        jp      main_loop

; -------------------------------------------------------------------------
; CMD_LOAD_X86
; 1) Select ZX DMA module and set physical target $00D000.
; 2) Enable DMA by setting DMA_CST bit 7.
; 3) Clear CBIT: this is the READY indication to the host.
; 4) Wait for host's end marker (#FF written to GSCOM, setting CBIT).
; 5) Disable DMA, then clear CBIT to acknowledge completion.
;
; Host uses OUT/LDIR writes into $0000-$3FFF. No dummy write is performed.
; -------------------------------------------------------------------------
command_load_x86:
        ld      a, C_DMA_ZX
        out     (DMA_MOD), a

        xor     a
        out     (DMA_HAD), a            ; physical address bits 21:16 = 0
        ld      a, #D0
        out     (DMA_MAD), a            ; physical address bits 15:8 = #D0
        xor     a
        out     (DMA_LAD), a            ; physical address bits 7:0 = 0

        ld      a, #80
        out     (DMA_CST), a            ; DMA enable = bit 7

        xor     a
        out     (CLRCBIT), a            ; host may now start LDIR

        ld      d, DMA_WAIT_OUTER
.dma_wait_outer:
        ld      bc, DMA_WAIT_LIMIT
.dma_wait_host_end:
        in      a, (ZXSTAT)
        bit     B_CBIT, a
        jr      nz, .dma_host_end
        dec     bc
        ld      a, b
        or      c
        jr      nz, .dma_wait_host_end
        dec     d
        jr      nz, .dma_wait_outer

        ; Timeout: close DMA and release the host command line.
        xor     a
        out     (DMA_CST), a
        out     (CLRCBIT), a
        ld      a, 1
        ld      (neo_dma_error), a
        ld      a, 3
        ld      (x86_exit_status), a
        jp      main_loop

.dma_host_end:
        xor     a
        out     (DMA_CST), a            ; disable DMA before leaving handler
        out     (CLRCBIT), a            ; acknowledge host's #FF marker
        xor     a
        ld      (neo_dma_error), a
        jp      main_loop

; -------------------------------------------------------------------------
; CMD_RUN_X86 — execute the length-framed payload beginning at $5002.
; -------------------------------------------------------------------------
command_run_x86:
        call    execute_neogs_x86
        xor     a
        out     (CLRCBIT), a
        jp      main_loop

; -------------------------------------------------------------------------
; CMD_MEM_TEST — destructive test of the reserved 1 MiB x86 RAM region.
; Result is returned through the existing CMD_GET_STATUS frame.
; -------------------------------------------------------------------------
command_mem_test:
        ld      hl, 0
        ld      (x86_last_ip), hl
        ld      hl, neo_debug_msg_memtest_started
        call    neo_debug_puts
        call    x86_mem_test
        ld      a, (x86_exit_status)
        or      a
        jr      nz, .memtest_failed
        ld      hl, neo_debug_msg_memtest_pass
        call    neo_debug_puts
        jr      .memtest_done
.memtest_failed:
        ld      hl, neo_debug_msg_memtest_fail
        call    neo_debug_puts
.memtest_done:
        xor     a
        out     (CLRCBIT), a
        jp      main_loop

; Host response: length byte followed by exactly that many debug characters.
command_debug_drain:
        ld      a, (neo_debug_length)
        call    neo_send_data_byte
        jr      c, .debug_drain_failed
        ld      a, (neo_debug_length)
        ld      (neo_debug_remaining), a
        ld      hl, neo_debug_buffer
.debug_drain_loop:
        ld      a, (neo_debug_remaining)
        or      a
        jr      z, .debug_drain_done
        ld      a, (hl)
        call    neo_send_data_byte
        jr      c, .debug_drain_failed
        inc     hl
        ld      a, (neo_debug_remaining)
        dec     a
        ld      (neo_debug_remaining), a
        jr      .debug_drain_loop
.debug_drain_done:
        xor     a
        ld      (neo_debug_length), a
        out     (CLRCBIT), a
        jp      main_loop
.debug_drain_failed:
        xor     a
        out     (CLRCBIT), a
        jp      main_loop

; -------------------------------------------------------------------------
; CMD_GET_STATUS — structured frame:
;   A5 signature, exit status, AX low/high, x86 IP low/high.
; -------------------------------------------------------------------------
command_get_status:
        ld      a, NGS_RESULT_SIGNATURE
        call    neo_send_data_byte
        jr      c, .status_tx_failed

        ld      a, (x86_exit_status)
        call    neo_send_data_byte
        jr      c, .status_tx_failed

        ld      hl, (saved_x86_ax)
        ld      a, l
        call    neo_send_data_byte
        jr      c, .status_tx_failed

        ld      a, h
        call    neo_send_data_byte
        jr      c, .status_tx_failed

        ld      hl, (x86_last_ip)
        ld      a, l
        call    neo_send_data_byte
        jr      c, .status_tx_failed

        ld      a, h
        call    neo_send_data_byte
        jr      c, .status_tx_failed

        xor     a
        out     (CLRCBIT), a
        jp      main_loop

.status_tx_failed:
        xor     a
        out     (CLRCBIT), a
        jp      main_loop

; -------------------------------------------------------------------------
; neo_send_data_byte
; IN: A = byte to send to Spectrum.
; Wait for DBIT=0, write ZXDATWR (#03), then wait for host read to clear DBIT.
; OUT: carry clear on success, carry set on timeout. Preserves HL and DE.
; -------------------------------------------------------------------------
neo_send_startup_text:
        ld      a, (hl)
        or      a
        jr      z, .startup_text_end
        call    neo_send_data_byte
        ret     c
        inc     hl
        jr      neo_send_startup_text
.startup_text_end:
        xor     a
        jp      neo_send_data_byte

; Append a NUL-terminated string to the local debug queue.
; IN: HL=string. HL/BC/DE preserved.
neo_debug_puts:
        ld      a, (hl)
        or      a
        ret     z
        call    neo_debug_putc
        inc     hl
        jr      neo_debug_puts

; Append one byte. Capacity is 255 bytes; excess characters are discarded.
; IN: A=character. HL/BC/DE preserved.
neo_debug_putc:
        push    hl
        push    bc
        push    de
        ld      b, a
        ld      a, (neo_debug_length)
        cp      #FF
        jr      nc, .debug_putc_done
        ld      l, a
        ld      h, 0
        ld      de, neo_debug_buffer
        add     hl, de
        ld      (hl), b
        ld      a, (neo_debug_length)
        inc     a
        ld      (neo_debug_length), a
.debug_putc_done:
        pop     de
        pop     bc
        pop     hl
        ret

neo_send_data_byte:
        ld      (neo_tx_byte), a
        ld      bc, IPC_WAIT_LIMIT
.tx_wait_slot:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      z, .tx_slot_free
        dec     bc
        ld      a, b
        or      c
        jr      nz, .tx_wait_slot
        scf
        ret

.tx_slot_free:
        ld      a, (neo_tx_byte)
        out     (ZXDATWR), a

        ld      bc, IPC_WAIT_LIMIT
.tx_wait_host_read:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      z, .tx_host_read
        dec     bc
        ld      a, b
        or      c
        jr      nz, .tx_wait_host_read
        scf
        ret

.tx_host_read:
        or      a
        ret

neo_command:       db 0
neo_tx_byte:       db 0
neo_dma_error:     db 0
neo_debug_length:  db 0
neo_debug_remaining: db 0
neo_debug_buffer:
        BLOCK   255, 0
neo_startup_message:
        db "[NEOGS] STARTUP OK: LOADED FIRMWARE EXECUTION STARTED.", 13, 0
neo_debug_msg_memtest_started: db "[NEOGS] MEMORY TEST STARTED.", 13, 0
neo_debug_msg_memtest_pass: db "[NEOGS] MEMORY TEST PASS.", 13, 0
neo_debug_msg_memtest_fail: db "[NEOGS] MEMORY TEST FAIL.", 13, 0
saved_x86_ax:      dw 0
x86_last_ip:       dw 0

; This code is copied to $4000 during startup. Its OUT changes the ROM map,
; but the following JP is still fetched from RAM because PC remains in $4000.
rom_return_trampoline_code:
        in      a, (GSCFG0)
        and     #FE
        out     (GSCFG0), a
        jp      0
rom_return_trampoline_end:

        INCLUDE "x86_memory.asm"
        INCLUDE "x86_system.asm"
        INCLUDE "x86_runtime.asm"
        INCLUDE "x86_interpreter.asm"

        ASSERT ROM_RETURN_TRAMPOLINE_ADDR + 16 <= X86_DMA_HEADER_ADDR
        ASSERT X86_RAM_RUN_ADDR + NGS_X86_MAX_CODE_SIZE = #8000

neogs_firmware_end:
