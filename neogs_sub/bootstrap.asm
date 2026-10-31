; =========================================================================
; PROJECT 124 — first-stage NeoGS bootstrap module
;
; Loaded by the stock GS105a ROM using the standard General Sound protocol:
;   #30 LOAD MODULE, #D1 OPEN STREAM, bytes, #D2 CLOSE STREAM, #31 RUN MODULE.
;
; The stock module loader places this small resident module at $5B00.
; It maps RAM over the low ROM window, receives a 16-bit firmware length and
; exactly that many bytes through the documented ZX data channel, stores the
; custom firmware at RAM address $0000, then jumps to $0000.
;
; This deliberately remains below $6000: the GS105a software uses $6000-$7FFF
; for DAC-related work. The forum's documented safe resident area is $5B00-$5FFF.
; =========================================================================

neogs_bootstrap_start:
        di
        ld      sp, #3FFF

        ; Hide the stock ROM and expose RAM at logical $0000-$3FFF.
        in      a, (GSCFG0)
        and     #FD                    ; clear RAMRO: low RAM must be writable
        or      M_NOROM                ; map RAM over the stock ROM at $0000
        out     (GSCFG0), a

        ; Tell Spectrum that the tiny loader is running and waiting for length.
        ld      a, NGS_BOOTSTRAP_READY_ACK
        call    bootstrap_send_data_byte

        ; Host sends length low byte, then high byte.
        call    bootstrap_receive_data_byte
        ld      e, a
        call    bootstrap_receive_data_byte
        ld      d, a

        ; Reject zero length and any image larger than the reserved low RAM area.
        ld      a, d
        or      e
        jr      z, bootstrap_error
        ld      a, d
        cp      #30
        jr      c, bootstrap_length_ok
        jr      nz, bootstrap_error
        ld      a, e
        or      a
        jr      nz, bootstrap_error

bootstrap_length_ok:
        ; Explicitly acknowledge that the length is accepted before the host
        ; starts streaming the firmware payload.
        ld      a, NGS_BOOTSTRAP_LENGTH_ACK
        call    bootstrap_send_data_byte
        ld      hl, 0

bootstrap_copy_loop:
        ld      a, d
        or      e
        jr      z, bootstrap_start_firmware
        call    bootstrap_receive_data_byte
        ld      (hl), a
        inc     hl
        dec     de
        jr      bootstrap_copy_loop

bootstrap_start_firmware:
        jp      0

bootstrap_error:
        ld      a, NGS_BOOTSTRAP_ERROR_ACK
        call    bootstrap_send_data_byte
.bootstrap_halt:
        di
        halt
        jr      .bootstrap_halt

; Wait for one byte from Spectrum. Reading ZXDATRD clears DBIT.
bootstrap_receive_data_byte:
.rx_wait:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      z, .rx_wait
        in      a, (ZXDATRD)
        ret

; Send one byte to Spectrum. Host reads GSDAT and clears DBIT.
bootstrap_send_data_byte:
        ld      (bootstrap_tx_byte), a
.tx_free:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      nz, .tx_free
        ld      a, (bootstrap_tx_byte)
        out     (ZXDATWR), a
.tx_wait_read:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      nz, .tx_wait_read
        ret

bootstrap_tx_byte:
        db      0

neogs_bootstrap_end:
