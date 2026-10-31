; =========================================================================
; PROJECT 124 — NeoGS host-side driver
; Stage 2 uses the standard GS105a ROM loader and a two-stage bootstrap.
; =========================================================================
        INCLUDE "../shared/neogs_io.inc"

FW_BYTE_TIMEOUT EQU #FFFF
IPC_BYTE_TIMEOUT EQU #FFFF
IPC_CMD_TIMEOUT EQU #FFFF

; -------------------------------------------------------------------------
; upload_firmware
; IN : HL = custom firmware binary, DE = byte length.
; OUT: Carry clear only after custom firmware sends NGS_FIRMWARE_READY_ACK.
;
; Cold/warm reset path:
;   #F4 cold restart (custom firmware maps stock ROM back and JP $0000)
;   #20 get total RAM, read three bytes to prove stock ROM is ready
;   #00 reset flags
;   #30 load module, #D1 open stream, bootstrap bytes, #D2 close stream
;   read/echo module handle, #31 run module
;   #A1 bootstrap ready, send length, receive #A3 length accepted
;   send custom firmware bytes, receive #A2 firmware ready
; -------------------------------------------------------------------------
upload_firmware::
        ld      (neo_fw_source), hl
        ld      (neo_fw_length), de

        ; Firmware image must fit in low RAM $0000-$2FFF, below SP=$3FFF.
        ld      a, d
        or      e
        jp      z, .upload_failed
        ld      a, d
        cp      #30
        jr      c, .firmware_length_valid
        jp      nz, .upload_failed
        ld      a, e
        or      a
        jp      nz, .upload_failed
.firmware_length_valid:
        xor     a
        ld      (neo_fw_bytes_sent), a
        ld      (neo_fw_bytes_sent+1), a
        ld      (neo_fw_timeout_phase), a
        in      a, (GSSTAT)
        ld      (neo_fw_initial_status), a
        ld      (neo_fw_last_status), a

        ; Phase 1: documented GS105a cold restart. Also returns a running
        ; Project 124 firmware to the stock ROM before the new bootstrap.
        ld      a, 1
        ld      (neo_fw_timeout_phase), a
        ld      a, GS_CMD_COLD_RESTART
        call    gs_boot_send_command_long
        jp      c, .upload_failed

        ; Phase 2: #20 returns three RAM-size bytes only after stock ROM is up.
        ; Retry #F4 once: if the previous run was interrupted during DMA, the
        ; first #F4 may have been consumed as the DMA end marker; the second
        ; reaches the command dispatcher after it returns to its main loop.
        ld      a, 2
        ld      (neo_fw_timeout_phase), a
        call    gs_boot_probe_rom
        jr      nc, .stock_rom_ready
        ld      a, 1
        ld      (neo_fw_timeout_phase), a
        ld      a, GS_CMD_COLD_RESTART
        call    gs_boot_send_command_long
        jp      c, .upload_failed
        ld      a, 2
        ld      (neo_fw_timeout_phase), a
        call    gs_boot_probe_rom
        jp      c, .upload_failed
.stock_rom_ready:

        ; Phase 3: clear residual flags before the module stream.
        ld      a, 3
        ld      (neo_fw_timeout_phase), a
        ld      a, GS_CMD_RESET_FLAGS
        call    gs_boot_send_command
        jp      c, .upload_failed

        ; Phase 4: allocate/load a module in the stock GS105a ROM.
        ld      a, 4
        ld      (neo_fw_timeout_phase), a
        ld      a, GS_CMD_LOAD_MODULE
        call    gs_boot_send_command
        jp      c, .upload_failed

        ; Some GS105a revisions expose the module handle immediately after
        ; #30; the published transfer example exposes it after #D2. Accept
        ; either documented timing without leaving DBIT pending.
        xor     a
        ld      (neo_fw_handle_valid), a
        call    gs_boot_receive_data_byte
        jr      c, .no_early_module_handle
        ld      (neo_fw_module_handle), a
        ld      a, 1
        ld      (neo_fw_handle_valid), a
.no_early_module_handle:

        ; Phase 5: open the module stream.
        ld      a, 5
        ld      (neo_fw_timeout_phase), a
        ld      a, GS_CMD_OPEN_STREAM
        call    gs_boot_send_command
        jp      c, .upload_failed

        ; Phase 6: transfer the small resident bootstrap to $5B00-$5FFF.
        ld      a, 6
        ld      (neo_fw_timeout_phase), a
        ld      hl, neogs_bootstrap_start
        ld      de, neogs_bootstrap_end - neogs_bootstrap_start
.bootstrap_stream_loop:
        ld      a, d
        or      e
        jr      z, .bootstrap_stream_done
        ld      a, (hl)
        call    gs_boot_send_data_byte
        jp      c, .upload_failed
        inc     hl
        dec     de
        jr      .bootstrap_stream_loop

.bootstrap_stream_done:
        ; Phase 7: close stream, read module handle, then return it for #31.
        ld      a, 7
        ld      (neo_fw_timeout_phase), a
        ld      a, GS_CMD_CLOSE_STREAM
        call    gs_boot_send_command
        jp      c, .upload_failed
        call    gs_boot_receive_data_byte
        jr      c, .no_late_module_handle
        ld      (neo_fw_module_handle), a
        ld      a, 1
        ld      (neo_fw_handle_valid), a
.no_late_module_handle:
        ld      a, (neo_fw_handle_valid)
        or      a
        jp      z, .upload_failed
        ; The GS #31 example writes the handle first and immediately sends
        ; #31; the ROM consumes this argument while processing that command.
        ld      a, (neo_fw_module_handle)
        call    gs_boot_write_command_argument
        jp      c, .upload_failed

        ; Phase 8: run the resident bootstrap and wait for ACK #A1.
        ld      a, 8
        ld      (neo_fw_timeout_phase), a
        ld      a, GS_CMD_RUN_MODULE
        call    gs_boot_send_command
        jp      c, .upload_failed
        call    gs_boot_receive_data_byte
        jp      c, .upload_failed
        cp      NGS_BOOTSTRAP_READY_ACK
        jp      nz, .upload_failed

        ; Phase 9: send firmware length low/high and require ACK #A3.
        ld      a, 9
        ld      (neo_fw_timeout_phase), a
        ld      hl, (neo_fw_length)
        ld      a, l
        call    gs_boot_send_data_byte
        jp      c, .upload_failed
        ld      a, h
        call    gs_boot_send_data_byte
        jp      c, .upload_failed
        call    gs_boot_receive_data_byte
        jp      c, .upload_failed
        cp      NGS_BOOTSTRAP_LENGTH_ACK
        jp      nz, .upload_failed

        ; Phase 10: stream the custom firmware to RAM address $0000.
        ld      a, 10
        ld      (neo_fw_timeout_phase), a
        ld      hl, (neo_fw_source)
        ld      de, (neo_fw_length)
.firmware_stream_loop:
        ld      a, d
        or      e
        jr      z, .firmware_stream_done
        ld      a, (hl)
        call    gs_boot_send_data_byte
        jp      c, .upload_failed
        inc     hl
        dec     de
        jr      .firmware_stream_loop

.firmware_stream_done:
        ; Phase 11: new firmware has jumped to $0000 and sends ACK #A2.
        ld      a, 11
        ld      (neo_fw_timeout_phase), a
        call    gs_boot_receive_data_byte
        jp      c, .upload_failed
        cp      NGS_FIRMWARE_READY_ACK
        jp      nz, .upload_failed

        xor     a
        ret

.upload_failed:
        scf
        ret

; -------------------------------------------------------------------------
; Standard GS105a ROM transport primitives.
; Commands use CBIT; data bytes use DBIT. All waits are bounded.
; -------------------------------------------------------------------------

; Probe stock ROM by reading the three-byte RAM size returned by command #20.
gs_boot_probe_rom:
        ld      a, GS_CMD_GET_TOTAL_RAM
        call    gs_boot_send_command_long
        ret     c
        call    gs_boot_receive_data_byte
        ret     c
        ld      (neo_fw_rom_ram_low), a
        call    gs_boot_receive_data_byte
        ret     c
        ld      (neo_fw_rom_ram_mid), a
        call    gs_boot_receive_data_byte
        ret     c
        ld      (neo_fw_rom_ram_high), a
        ld      a, (neo_fw_rom_ram_low)
        ld      b, a
        ld      a, (neo_fw_rom_ram_mid)
        or      b
        ld      b, a
        ld      a, (neo_fw_rom_ram_high)
        or      b
        jr      nz, .rom_probe_ok
        scf
        ret
.rom_probe_ok:
        or      a
        ret

; Long command wait for #F4 cold restart and ROM self-test.
gs_boot_send_command_long:
        ld      (neo_fw_command_byte), a
        ld      a, (neo_fw_command_byte)
        out     (GSCOM), a
        push    de
        ld      d, 16
.long_outer:
        ld      bc, FW_BYTE_TIMEOUT
.long_inner:
        in      a, (GSSTAT)
        ld      (neo_fw_last_status), a
        bit     B_CBIT, a
        jr      z, .long_done
        dec     bc
        ld      a, b
        or      c
        jr      nz, .long_inner
        dec     d
        jr      nz, .long_outer
        pop     de
        scf
        ret
.long_done:
        pop     de
        or      a
        ret

gs_boot_send_command:
        ld      (neo_fw_command_byte), a
        ld      a, (neo_fw_command_byte)
        out     (GSCOM), a
        ld      bc, FW_BYTE_TIMEOUT
.command_wait:
        in      a, (GSSTAT)
        ld      (neo_fw_last_status), a
        bit     B_CBIT, a
        jr      z, .command_done
        dec     bc
        ld      a, b
        or      c
        jr      nz, .command_wait
        scf
        ret
.command_done:
        or      a
        ret

; Write one command argument to GSDAT without waiting for its post-write
; DBIT clear. The following command (#31) consumes this argument, matching
; the published GS105a module-run sequence.
gs_boot_write_command_argument:
        ld      (neo_fw_tx_byte), a
        ld      bc, FW_BYTE_TIMEOUT
.argument_wait_free:
        in      a, (GSSTAT)
        ld      (neo_fw_last_status), a
        bit     B_DBIT, a
        jr      z, .argument_slot_free
        dec     bc
        ld      a, b
        or      c
        jr      nz, .argument_wait_free
        scf
        ret
.argument_slot_free:
        ld      a, (neo_fw_tx_byte)
        out     (GSDAT), a
        or      a
        ret

gs_boot_send_data_byte:
        ld      (neo_fw_tx_byte), a
        ld      bc, FW_BYTE_TIMEOUT
.data_wait_free:
        in      a, (GSSTAT)
        ld      (neo_fw_last_status), a
        bit     B_DBIT, a
        jr      z, .data_slot_free
        dec     bc
        ld      a, b
        or      c
        jr      nz, .data_wait_free
        scf
        ret
.data_slot_free:
        ld      a, (neo_fw_tx_byte)
        out     (GSDAT), a
        ld      bc, FW_BYTE_TIMEOUT
.data_wait_consumed:
        in      a, (GSSTAT)
        ld      (neo_fw_last_status), a
        bit     B_DBIT, a
        jr      z, .data_consumed
        dec     bc
        ld      a, b
        or      c
        jr      nz, .data_wait_consumed
        scf
        ret
.data_consumed:
        push    hl
        ld      hl, (neo_fw_bytes_sent)
        inc     hl
        ld      (neo_fw_bytes_sent), hl
        pop     hl
        or      a
        ret

gs_boot_receive_data_byte:
        ld      bc, FW_BYTE_TIMEOUT
.receive_wait:
        in      a, (GSSTAT)
        ld      (neo_fw_last_status), a
        bit     B_DBIT, a
        jr      nz, .receive_ready
        dec     bc
        ld      a, b
        or      c
        jr      nz, .receive_wait
        scf
        ret
.receive_ready:
        in      a, (GSDAT)
        or      a
        ret

; -------------------------------------------------------------------------
; Project 124 private-protocol waits (custom firmware already running).
; -------------------------------------------------------------------------
neogs_wait_command_done::
        ld      bc, IPC_CMD_TIMEOUT
.cmd_wait:
        in      a, (GSSTAT)
        bit     B_CBIT, a
        jr      z, .cmd_done
        dec     bc
        ld      a, b
        or      c
        jr      nz, .cmd_wait
        scf
        ret
.cmd_done:
        or      a
        ret

neogs_wait_command_done_long::
        push    de
        ld      d, #10
.cmd_long_outer:
        ld      bc, IPC_CMD_TIMEOUT
.cmd_long_inner:
        in      a, (GSSTAT)
        bit     B_CBIT, a
        jr      z, .cmd_long_done
        dec     bc
        ld      a, b
        or      c
        jr      nz, .cmd_long_inner
        dec     d
        jr      nz, .cmd_long_outer
        pop     de
        scf
        ret
.cmd_long_done:
        pop     de
        or      a
        ret

neogs_wait_data_byte::
        ld      bc, IPC_BYTE_TIMEOUT
.data_wait:
        in      a, (GSSTAT)
        bit     B_DBIT, a
        jr      nz, .data_ready
        dec     bc
        ld      a, b
        or      c
        jr      nz, .data_wait
        scf
        ret
.data_ready:
        in      a, (GSDAT)
        or      a
        ret

; Stage 2 diagnostics consumed by zx_main/main.asm.
neo_fw_source:          dw 0
neo_fw_length:          dw 0
neo_fw_module_handle:   db 0
neo_fw_handle_valid:    db 0
neo_fw_rom_ram_low:     db 0
neo_fw_rom_ram_mid:     db 0
neo_fw_rom_ram_high:    db 0
neo_fw_command_byte:    db 0
neo_fw_tx_byte:         db 0
neo_fw_bytes_sent:      dw 0
neo_fw_initial_status:  db 0
neo_fw_last_status:     db 0
neo_fw_timeout_phase:   db 0
