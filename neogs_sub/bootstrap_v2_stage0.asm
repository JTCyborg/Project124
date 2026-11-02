; =========================================================================
; PROJECT 124 — V2 stage-0 bootstrap
;
; GS105a #14 loads this <=254-byte image at $4000; #13 enters at $4000.
; It configures the four-window map, receives the isolated stage-1 receiver
; into the temporary WIN1 area $4800-$4FFF, then jumps to $4800.
;
; Protocol:
;   stage-0 -> host: #A1 READY
;   host -> stage-0: WORD stage1_length (1..#0800)
;   stage-0 -> host: #A3 LENGTH_ACCEPTED
;   host -> stage-0: exactly stage1_length bytes
;   stage-0 jumps to $4800; stage-1 then sends #A4.
; =========================================================================

v2_stage0_start:
        di
        in      a, (GSCFG0)
        and     #FD
        or      M_NOROM
        or      M_EXPAG
        out     (GSCFG0), a

        ; Default windows: WIN2=page 1, WIN3=page 2.
        ld      a, #80
        out     (MPAG), a
        ld      a, #01
        out     (MPAGEX), a
        ld      sp, #FFFE

        ld      a, NGS_BOOTSTRAP_READY_ACK
        call    v20_send_byte

        call    v20_receive_byte
        ld      e, a
        call    v20_receive_byte
        ld      d, a

        ; Stage-1 must fit entirely in temporary WIN1 range #4800..#4FFF.
        ld      a, d
        cp      #08
        jp      c, v20_length_high_ok
        jp      nz, v20_error
        ld      a, e
        or      a
        jp      nz, v20_error
v20_length_high_ok:
        ld      a, d
        or      e
        jp      z, v20_error

        ld      a, NGS_BOOTSTRAP_LENGTH_ACK
        call    v20_send_byte
        ld      hl, #4800
v20_copy_loop:
        ld      a, d
        or      e
        jr      z, v20_start_stage1
        call    v20_receive_byte
        ld      (hl), a
        inc     hl
        dec     de
        jr      v20_copy_loop

v20_start_stage1:
        jp      #4800

v20_error:
        ld      a, NGS_BOOTSTRAP_ERROR_ACK
        call    v20_send_byte
v20_halt:
        di
        halt
        jr      v20_halt

; The host has the authoritative timeout. Do not run an independent
; instruction-count timeout here: the two CPUs advance in different clock
; domains, and a host-side turnaround can otherwise expire this receiver.
v20_receive_byte:
.v20_rx_wait:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      z, .v20_rx_wait
        in      a, (ZXDATRD)
        ret

; Wait for the host to consume our byte, then return. The host owns timeout
; and recovery; keeping this side waiting avoids a false local timeout while
; the host/emulator synchronizes the shared DBIT flag.
v20_send_byte:
        ld      (v20_tx_byte), a
.v20_tx_wait_free:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      nz, .v20_tx_wait_free
        ld      a, (v20_tx_byte)
        out     (ZXDATWR), a
.v20_tx_wait_read:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      nz, .v20_tx_wait_read
        ret

v20_tx_byte: db 0
v2_stage0_end:
        ASSERT v2_stage0_start = #4000
        ASSERT v2_stage0_end <= #4100
        ASSERT v2_stage0_end - v2_stage0_start <= 248
