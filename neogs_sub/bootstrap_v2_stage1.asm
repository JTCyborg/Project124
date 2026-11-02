; =========================================================================
; PROJECT 124 — V2 second-stage segmented firmware receiver
;
; Loaded by the V2 stage-0 bootstrap at $4800 and executed from WIN1/page 3.
; WIN1 is never paged while this code is running. Stack remains in WIN3/page 2.
;
; Protocol after entry:
;   stage-1 -> host: #A4 READY
;   host -> stage-1: WORD complete_v2_payload_length (LE)
;   stage-1 -> host: #A3 LENGTH_ACCEPTED
;   host -> stage-1: v2 payload (P124 header + descriptors + segment data)
;   stage-1 validates the complete header before writing any segment.
;   On success it jumps to resident entry $0000 (resident sends #A2).
;
; This module is intentionally separate from the active v1 bootstrap path.
; =========================================================================

STAGE1_READY_ACK EQU #A4
STAGE1_LENGTH_ACK EQU #A3
STAGE1_ERROR_ACK EQU #E1
STAGE1_TIMEOUT EQU #FFFF

v2_stage1_start:
        di
        ld      sp, #FFFE
        ; Keep the default WIN2 page selected until a descriptor explicitly
        ; requests an overlay. WIN3 is not touched: stack remains in page 2.
        ld      a, #80
        out     (MPAG), a

        ld      a, STAGE1_READY_ACK
        call    v2s_send_byte

        ; Host sends exact v2 payload length, including header/descriptors.
        call    v2s_receive_byte
        ld      (v2s_payload_length), a
        call    v2s_receive_byte
        ld      (v2s_payload_length+1), a
        ld      hl, (v2s_payload_length)
        ld      a, h
        or      l
        jp      z, v2s_error
        ; Largest legal payload is #C000 + 26 = #C01A.
        ld      a, h
        cp      #C1
        jp      nc, v2s_error
        ld      a, STAGE1_LENGTH_ACK
        call    v2s_send_byte

        ; Validate fixed header before parsing variable descriptor table.
        call    v2s_receive_byte
        cp      'P'
        jp      nz, v2s_error
        call    v2s_receive_byte
        cp      '1'
        jp      nz, v2s_error
        call    v2s_receive_byte
        cp      '2'
        jp      nz, v2s_error
        call    v2s_receive_byte
        cp      '4'
        jp      nz, v2s_error
        call    v2s_receive_byte
        cp      2
        jp      nz, v2s_error
        call    v2s_receive_byte
        cp      1
        jp      c, v2s_error
        cp      4
        jp      nc, v2s_error
        ld      (v2s_segment_count), a

        call    v2s_receive_byte
        ld      (v2s_total_length), a
        call    v2s_receive_byte
        ld      (v2s_total_length+1), a
        ld      hl, (v2s_total_length)
        ld      a, h
        cp      #C0
        jp      c, v2s_total_nonzero
        jp      nz, v2s_error
        ld      a, l
        or      a
        jp      nz, v2s_error
v2s_total_nonzero:
        ld      a, h
        or      l
        jp      z, v2s_error

        ; Parse and validate all descriptors. No destination memory is written
        ; until every descriptor and the aggregate byte count are accepted.
        xor     a
        ld      (v2s_index), a
        ld      (v2s_sum), a
        ld      (v2s_sum+1), a
        ld      ix, v2s_pages
        ld      iy, v2s_lengths
v2s_descriptor_loop:
        ; physical page
        call    v2s_receive_byte
        ld      (v2s_current_page), a
        ld      a, (v2s_index)
        or      a
        jr      nz, v2s_descriptor_overlay
        ld      a, (v2s_current_page)
        or      a
        jp      nz, v2s_error
        jr      v2s_descriptor_page_ok
v2s_descriptor_overlay:
        ld      a, (v2s_current_page)
        cp      68
        jr      z, v2s_descriptor_page_ok
        cp      69
        jp      nz, v2s_error
        ; Page 68 and page 69 may each appear once only.
        ld      a, (v2s_index)
        cp      1
        jr      nz, v2s_descriptor_page_ok
        ; First overlay cannot duplicate page 69 because it is current.
v2s_descriptor_page_ok:
        ; Reject a page already used by an earlier descriptor.
        ld      a, (v2s_index)
        or      a
        jr      z, v2s_descriptor_unique
        ld      b, a
        ld      hl, v2s_pages
v2s_duplicate_scan:
        ld      a, (hl)
        ld      c, a
        ld      a, (v2s_current_page)
        cp      c
        jp      z, v2s_error
        inc     hl
        djnz    v2s_duplicate_scan
v2s_descriptor_unique:
        ld      a, (v2s_current_page)
        ld      (ix+0), a
        inc     ix

        ; destination offset must be zero in the initial canonical profile.
        call    v2s_receive_byte
        or      a
        jp      nz, v2s_error
        call    v2s_receive_byte
        or      a
        jp      nz, v2s_error

        ; segment length: 1..#4000
        call    v2s_receive_byte
        ld      e, a
        call    v2s_receive_byte
        ld      d, a
        ld      a, d
        cp      #40
        jr      c, v2s_descriptor_length_low
        jp      nz, v2s_error
        ld      a, e
        or      a
        jp      nz, v2s_error
v2s_descriptor_length_low:
        ld      a, d
        or      e
        jp      z, v2s_error
        ld      (iy+0), e
        inc     iy
        ld      (iy+0), d
        inc     iy

        ; flags: only bit 0 is defined. Resident must be executable.
        call    v2s_receive_byte
        ld      b, a
        and     #FE
        jp      nz, v2s_error
        ld      a, (v2s_index)
        or      a
        jr      nz, v2s_descriptor_flags_ok
        bit     0, b
        jp      z, v2s_error
v2s_descriptor_flags_ok:
        ; Sum descriptor lengths in 16-bit arithmetic.
        ld      hl, (v2s_sum)
        add     hl, de
        ld      (v2s_sum), hl

        ld      a, (v2s_index)
        inc     a
        ld      (v2s_index), a
        ; Compare index with segment_count.
        ld      a, (v2s_segment_count)
        ld      b, a
        ld      a, (v2s_index)
        cp      b
        jp      nz, v2s_descriptor_loop

        ; Require descriptor sum == declared total.
        ld      hl, (v2s_sum)
        ld      de, (v2s_total_length)
        or      a
        sbc     hl, de
        jp      nz, v2s_error

        ; Require exact payload length = fixed header + descriptors + data.
        ld      hl, (v2s_total_length)
        ld      a, (v2s_segment_count)
        add     a, a
        ld      e, a
        add     a, a
        add     a, e                   ; A = count * 6
        add     a, 8
        ld      e, a
        ld      d, 0
        add     hl, de
        ld      de, (v2s_payload_length)
        or      a
        sbc     hl, de
        jp      nz, v2s_error

        ; All metadata passed. Copy each segment to its physical destination.
        xor     a
        ld      (v2s_index), a
        ld      ix, v2s_pages
        ld      iy, v2s_lengths
v2s_copy_segment:
        ld      a, (ix+0)
        or      a
        jr      z, v2s_copy_resident
        cp      68
        jr      z, v2s_select_page68
        ; page 69 -> MPAG ROR8 encoding #A2
        ld      a, #A2
        out     (MPAG), a
        jr      v2s_copy_overlay
v2s_select_page68:
        ; page 68 -> MPAG ROR8 encoding #22
        ld      a, #22
        out     (MPAG), a
v2s_copy_overlay:
        ld      hl, #8000
        jr      v2s_copy_setup
v2s_copy_resident:
        ld      hl, 0
v2s_copy_setup:
        ld      e, (iy+0)
        inc     iy
        ld      d, (iy+0)
        inc     iy
v2s_copy_byte_loop:
        call    v2s_receive_byte
        ld      (hl), a
        inc     hl
        dec     de
        ld      a, d
        or      e
        jr      nz, v2s_copy_byte_loop

        ; Restore default WIN2 page before processing next descriptor.
        ld      a, #80
        out     (MPAG), a
        inc     ix
        ld      a, (v2s_index)
        inc     a
        ld      (v2s_index), a
        ld      b, a
        ld      a, (v2s_segment_count)
        cp      b
        jr      nz, v2s_copy_segment

        ; Do not send READY here: resident entry emits the existing #A2 ACK.
        jp      0

v2s_error:
        ld      a, STAGE1_ERROR_ACK
        call    v2s_send_byte
v2s_halt:
        di
        halt
        jr      v2s_halt

; Receive one byte from Spectrum through the NeoGS ZX data channel.
v2s_receive_byte:
        ld      bc, STAGE1_TIMEOUT
.v2s_rx_wait:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      nz, .v2s_rx_ready
        dec     bc
        ld      a, b
        or      c
        jr      nz, .v2s_rx_wait
        jp      v2s_error
.v2s_rx_ready:
        in      a, (ZXDATRD)
        ret

; Send one byte and wait until host consumes it.
v2s_send_byte:
        ld      (v2s_tx_byte), a
        ld      bc, STAGE1_TIMEOUT
.v2s_tx_wait_free:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      z, .v2s_tx_slot
        dec     bc
        ld      a, b
        or      c
        jr      nz, .v2s_tx_wait_free
        jp      v2s_halt
.v2s_tx_slot:
        ld      a, (v2s_tx_byte)
        out     (ZXDATWR), a
        ld      bc, STAGE1_TIMEOUT
.v2s_tx_wait_read:
        in      a, (ZXSTAT)
        bit     B_DBIT, a
        jr      z, .v2s_tx_done
        dec     bc
        ld      a, b
        or      c
        jr      nz, .v2s_tx_wait_read
        jp      v2s_halt
.v2s_tx_done:
        ret

v2s_payload_length: dw 0
v2s_total_length:   dw 0
v2s_segment_count:  db 0
v2s_index:          db 0
v2s_current_page:   db 0
v2s_sum:            dw 0
v2s_tx_byte:        db 0
v2s_pages:          defs 3, 0
v2s_lengths:        defs 6, 0
v2_stage1_end:

        ASSERT v2_stage1_start = #4800
        ASSERT v2_stage1_end <= #5000
