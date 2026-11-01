; =========================================================================
; PROJECT 124 — NeoGS host-side driver
; Stage 2 uses GS105a #14 (RECEIVE BLOCK) and #13 (JUMP) to start a two-stage bootstrap.
; =========================================================================
        INCLUDE "../shared/neogs_io.inc"

FW_BYTE_TIMEOUT EQU #FFFF
IPC_BYTE_TIMEOUT EQU #FFFF
IPC_CMD_TIMEOUT EQU #FFFF

; -------------------------------------------------------------------------
; Load the separately stored NeoGS firmware file from TR-DOS.
; neoprog.C layout: [WORD bootstrap_length][bootstrap bytes][firmware bytes].
; OUT: Carry clear, complete package at #C000 and exact file length saved.
; Uses the same verified TR-DOS 5.04T catalogue/sector API as Stage 5.
; -------------------------------------------------------------------------
load_neogs_firmware_file::
        ; Search the exact 8.3 catalogue name neoprog.C.
        ld      hl, neo_fw_filename
        ld      de, #5CDD
        ld      bc, 8
        ldir
        ld      a, 'C'
        ld      (#5CE5), a
        ld      a, 9
        ld      (#5D06), a
        ld      c, 10
        call    #3D13
        ld      a, c
        cp      #FF
        jp      z, .file_not_found

        ; C=#0A returns the directory slot. Fetch its full descriptor with C=#08.
        push    af
        xor     a
        ld      (#5D0F), a
        ld      (#5D10), a
        pop     af
        ld      c, 8
        call    #3D13
        ld      a, (#5D0F)
        ld      b, a
        ld      a, (#5D10)
        or      b
        jp      nz, .bad_descriptor

        ; Store the actual package length; its header separates the two code sections.
        ld      hl, (#5CE8)
        ld      (neo_fw_file_length), hl
        ld      a, h
        or      l
        jp      z, .bad_length
        ld      a, h
        or      a
        jr      nz, .package_minimum_ok
        ld      a, l
        cp      3
        jp      c, .bad_length
.package_minimum_ok:
        ; Verify sector count = ceil(file_length / 256).
        ld      hl, (neo_fw_file_length)
        ld      de, 255
        add     hl, de
        ld      a, (#5CEA)
        cp      h
        jp      nz, .bad_descriptor
        ld      (neo_fw_load_remaining), a

        ld      a, (#5CEB)
        cp      16
        jp      nc, .bad_descriptor
        ld      (neo_fw_load_sector), a
        ld      a, (#5CEC)
        ld      (neo_fw_load_track), a
        ld      hl, #C000
        ld      (neo_fw_load_buffer), hl

.read_sector_loop:
        ld      a, (neo_fw_load_track)
        ld      d, a
        ld      a, (neo_fw_load_sector)
        ld      e, a
        ld      hl, (neo_fw_load_buffer)
        ld      b, 1
        ld      c, 5
        xor     a
        ld      (#5D0F), a
        ld      (#5D10), a
        call    #3D13
        ld      a, (#5D0F)
        ld      b, a
        ld      a, (#5D10)
        or      b
        jp      nz, .sector_read_failed

        ; Next 256-byte sector goes to the next host buffer page.
        ld      hl, (neo_fw_load_buffer)
        ld      de, 256
        add     hl, de
        ld      (neo_fw_load_buffer), hl

        ; TR-DOS internal sectors are 0..15; then advance the track.
        ld      a, (neo_fw_load_sector)
        inc     a
        cp      16
        jr      c, .same_track
        xor     a
        ld      (neo_fw_load_sector), a
        ld      a, (neo_fw_load_track)
        inc     a
        ld      (neo_fw_load_track), a
        jr      .sector_advanced
.same_track:
        ld      (neo_fw_load_sector), a
.sector_advanced:
        ld      a, (neo_fw_load_remaining)
        dec     a
        ld      (neo_fw_load_remaining), a
        jp      nz, .read_sector_loop

        xor     a
        ret

.file_not_found:
        ld      a, 1
        jr      .load_failed
.bad_descriptor:
        ld      a, 2
        jr      .load_failed
.bad_length:
        ld      a, 3
        jr      .load_failed
.sector_read_failed:
        ld      a, 4
.load_failed:
        ld      (neo_fw_file_error), a
        scf
        ret

; -------------------------------------------------------------------------
; upload_firmware
; IN : HL = custom firmware binary, DE = byte length.
; OUT: Carry clear only after custom firmware sends NGS_FIRMWARE_READY_ACK.
;
; Cold/warm reset path:
;   #F4 cold restart
;   #20 get total RAM, read three bytes to prove stock ROM is ready
;   #14 receive executable bootstrap directly into RAM at $4000
;   #13 jump to $4000
;   #A1 bootstrap ready, send length, receive #A3 length accepted
;   send custom firmware bytes to RAM $0000, receive #A2 firmware ready
; -------------------------------------------------------------------------
upload_firmware::
        ; HL points to the package read once from TR-DOS; DE is its total length.
        ; Layout: WORD bootstrap_length, bootstrap bytes, then firmware bytes.
        ld      (neo_fw_package_source), hl
        ld      (neo_fw_package_length), de

        ; Decode and validate the bootstrap length from the package header.
        ld      a, d
        or      a
        jr      nz, .package_header_present
        ld      a, e
        cp      3
        jp      c, .upload_failed
.package_header_present:
        ld      a, (hl)
        ld      (neo_fw_bootstrap_length), a
        inc     hl
        ld      a, (hl)
        ld      (neo_fw_bootstrap_length+1), a
        ld      hl, (neo_fw_bootstrap_length)
        ld      a, h
        or      l
        jp      z, .upload_failed
        ld      a, h
        cp      #40
        jp      nc, .upload_failed

        ; Firmware length = package length - header - bootstrap length.
        ld      hl, (neo_fw_package_length)
        ld      de, 2
        or      a
        sbc     hl, de
        jp      c, .upload_failed
        ld      de, (neo_fw_bootstrap_length)
        or      a
        sbc     hl, de
        jp      c, .upload_failed
        ld      (neo_fw_length), hl

        ; Resolve both section pointers inside the same package buffer.
        ld      hl, (neo_fw_package_source)
        inc     hl
        inc     hl
        ld      (neo_fw_bootstrap_source), hl
        ld      de, (neo_fw_bootstrap_length)
        add     hl, de
        ld      (neo_fw_source), hl

        ; Firmware image must fit in low RAM $0000-$2FFF, below SP=$3FFF.
        ld      hl, (neo_fw_length)
        ld      a, h
        or      a
        jp      nz, .firmware_high_nonzero
        ld      a, l
        or      a
        jp      z, .upload_failed
        jr      .firmware_length_valid
.firmware_high_nonzero:
        ld      a, h
        cp      #30
        jr      c, .firmware_length_valid
        jp      nz, .upload_failed
        ld      a, l
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

        ; Phase 3: use the native GS105a memory loader, not the MOD player.
        ; #14 RECEIVE BLOCK expects the first (negative length low) byte
        ; before the command, then negative length high, address low/high,
        ; and exactly N payload bytes. The payload is written directly to RAM.
        ld      a, 3
        ld      (neo_fw_timeout_phase), a
        ld      hl, 0
        ld      de, (neo_fw_bootstrap_length)
        or      a
        sbc     hl, de                  ; HL = -bootstrap length
        ld      (neo_fw_block_length), hl
        ld      a, l
        call    gs_boot_write_command_argument
        jp      c, .upload_failed
        ld      a, GS_CMD_RECEIVE_BLOCK
        call    gs_boot_send_command
        jp      c, .upload_failed

        ; Remaining #14 header: -length high, destination $4000.
        ld      a, (neo_fw_block_length+1)
        call    gs_boot_send_data_byte
        jp      c, .upload_failed
        xor     a
        call    gs_boot_send_data_byte  ; destination low = $00
        jp      c, .upload_failed
        ld      a, #40
        call    gs_boot_send_data_byte  ; destination high = $40
        jp      c, .upload_failed

        ; Phase 4: transfer the executable bootstrap into RAM $4000.
        ld      a, 4
        ld      (neo_fw_timeout_phase), a
        ld      hl, (neo_fw_bootstrap_source)
        ld      de, (neo_fw_bootstrap_length)
.bootstrap_block_loop:
        ld      a, d
        or      e
        jr      z, .bootstrap_block_done
        ld      a, (hl)
        call    gs_boot_send_data_byte
        jp      c, .upload_failed
        inc     hl
        dec     de
        jr      .bootstrap_block_loop
.bootstrap_block_done:

        ; Phase 5: #13 JUMP TO ADDRESS. The low byte is the command's
        ; first argument and must be written before issuing the command.
        ld      a, 5
        ld      (neo_fw_timeout_phase), a
        xor     a                       ; entry address low = $00
        call    gs_boot_write_command_argument
        jp      c, .upload_failed
        ld      a, GS_CMD_JUMP_ADDRESS
        call    gs_boot_send_command
        jp      c, .upload_failed
        ld      a, #40                  ; entry address high = $40
        call    gs_boot_send_data_byte
        jp      c, .upload_failed

        ; Phase 6: bootstrap has enabled RAM-over-ROM and is waiting at $0000.
        ld      a, 6
        ld      (neo_fw_timeout_phase), a
        call    gs_boot_receive_data_byte
        jp      c, .upload_failed
        cp      NGS_BOOTSTRAP_READY_ACK
        jp      nz, .upload_failed

        ; Phase 7: send firmware length low/high and require ACK #A3.
        ld      a, 7
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

        ; Phase 8: stream the custom firmware to RAM address $0000.
        ld      a, 8
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
        ; Phase 9: new firmware has jumped to $0000 and sends ACK #A2.
        ld      a, 9
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

; Preload the first argument byte of GS105a commands #13/#14. Those
; handlers read this byte before clearing CBIT; later arguments use DBIT.
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
        ld      (neo_fw_last_rx_byte), a
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

; TR-DOS NeoGS package loader state and fixed 8-character filename.
neo_fw_filename:        db "neoprog "
neo_fw_load_buffer:     dw 0
neo_fw_load_remaining:  db 0
neo_fw_load_track:      db 0
neo_fw_load_sector:     db 0
neo_fw_file_error:      db 0
neo_fw_file_length:     dw 0

; Stage 2 package parser and transfer state.
neo_fw_package_source:  dw 0
neo_fw_package_length:  dw 0
neo_fw_bootstrap_source: dw 0
neo_fw_bootstrap_length: dw 0
neo_fw_source:          dw 0
neo_fw_length:          dw 0
neo_fw_bootstrap_address: dw #4000
neo_fw_block_length:    dw 0
neo_fw_rom_ram_low:     db 0
neo_fw_rom_ram_mid:     db 0
neo_fw_rom_ram_high:    db 0
neo_fw_command_byte:    db 0
neo_fw_tx_byte:         db 0
neo_fw_last_rx_byte:    db 0
neo_fw_bytes_sent:      dw 0
neo_fw_initial_status:  db 0
neo_fw_last_status:     db 0
neo_fw_timeout_phase:   db 0
