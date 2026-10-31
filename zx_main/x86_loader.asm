; =========================================================================
; PROJECT 124 — NeoGS interpreter and physical-memory diagnostics
;
; Built-in transport diagnostics remain embedded in the host application.
; The external regression suite is loaded separately from TR-DOS TEST.C.
; Both paths send raw x86 payloads to the running NeoGS firmware via DMA.
; neoprog.C remains reserved exclusively for the NeoGS firmware image.
; =========================================================================

DMA_HOST_WINDOW    EQU #0000
DMA_WINDOW_LIMIT   EQU #3000

RUN_NEOGS_DIAGNOSTICS::
        MACRO_EF_STRING P124_msg_boot_diag_start

        ; Release any stale command and reset the firmware protocol state.
        ld      a, #FE
        out     (GSCOM), a
        call    neogs_wait_command_done
        jp      c, .boot_protocol_error

        ld      a, CMD_RESET
        out     (GSCOM), a
        call    neogs_wait_command_done
        jp      c, .boot_protocol_error

        ; Run the NeoGS-side physical memory/addressing self-test.
        ; Instruction-level x86 tests are no longer embedded here: they all
        ; come from the external TEST.C suite loaded in the next stage.
        MACRO_EF_STRING P124_msg_memtest_start
        call    neogs_mem_test_and_get_result
        jp      c, .boot_memtest_transport_fail
        ld      a, (P124_X86_RESULT_STATUS)
        or      a
        jp      nz, .boot_memtest_fail
        ld      hl, (P124_X86_RESULT_AX)
        ld      de, 1
        or      a
        sbc     hl, de
        jp      nz, .boot_memtest_fail

        MACRO_EF_STRING P124_msg_memtest_pass
        MACRO_EF_STRING P124_msg_boot_diag_pass
        or      a
        ret

.boot_protocol_error:
        MACRO_EF_STRING P124_msg_boot_protocol_fail
        scf
        ret

.boot_memtest_transport_fail:
        MACRO_EF_STRING P124_msg_memtest_transport_fail
        scf
        ret

.boot_memtest_fail:
        MACRO_EF_STRING P124_msg_memtest_fail
        ld      a, (P124_X86_RESULT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 32
        ld      hl, (P124_X86_RESULT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        ret

; =========================================================================
; NeoGS transport helpers — CBIT/DBIT protocol
; =========================================================================

; IN: HL=source in host RAM, BC=payload byte count (1..#2FFE).
; OUT: Carry clear after NeoGS armed DMA, consumed the host end marker,
;      and disabled DMA. Carry set on timeout.
neogs_send_dma_block:
        ld      a, b
        or      c
        jp      z, .dma_bad_length
        ld      a, b
        cp      #40
        jr      c, .dma_length_ok
        jp      nz, .dma_bad_length
        ld      a, c
        or      a
        jp      nz, .dma_bad_length
.dma_length_ok:
        ld      (P124_DMA_SOURCE), hl
        ld      (P124_DMA_LENGTH), bc

        ; Validate payload + two-byte length prefix <= $3000.
        push    bc
        pop     hl
        ld      de, 2
        add     hl, de
        ld      a, h
        cp      #30
        jr      c, .dma_total_length_ok
        jp      nz, .dma_bad_length
        ld      a, l
        or      a
        jp      nz, .dma_bad_length
.dma_total_length_ok:
        ld      a, CMD_LOAD_X86
        out     (GSCOM), a
        call    neogs_wait_command_done
        ret     c

        ; The DMA engine observes host memory-write cycles. LDIR transfers
        ; the two-byte length header followed by the payload. No dummy write.
        di
        ld      hl, (P124_DMA_LENGTH)
        ld      (P124_DMA_HEADER), hl
        ld      hl, P124_DMA_HEADER
        ld      de, DMA_HOST_WINDOW
        ld      bc, 2
        ldir

        ld      hl, (P124_DMA_SOURCE)
        ld      de, DMA_HOST_WINDOW + 2
        ld      bc, (P124_DMA_LENGTH)
        ldir

        ; End marker is a command-byte write, not a DMA data byte.
        ld      a, #FF
        out     (GSCOM), a
        call    neogs_wait_command_done
        ret

.dma_bad_length:
        scf
        ret

; Send RUN command and fetch the four-byte result frame:
; A5 signature, status, AX low, AX high.
neogs_run_and_get_result:
        ld      a, CMD_RUN_X86
        out     (GSCOM), a
        call    neogs_wait_command_done_long
        ret     c
        call    neogs_drain_debug
        ret     c
        jp      neogs_get_result_frame

; Run the NeoGS physical-memory self-test and fetch its result frame.
neogs_mem_test_and_get_result:
        ld      a, CMD_MEM_TEST
        out     (GSCOM), a
        call    neogs_wait_command_done_long
        ret     c
        call    neogs_drain_debug
        ret     c

neogs_get_result_frame:
        ld      a, CMD_GET_STATUS
        out     (GSCOM), a

        call    neogs_wait_data_byte
        ret     c
        ld      (P124_X86_RESULT_MAGIC), a

        call    neogs_wait_data_byte
        ret     c
        ld      (P124_X86_RESULT_STATUS), a

        call    neogs_wait_data_byte
        ret     c
        ld      e, a

        call    neogs_wait_data_byte
        ret     c
        ld      d, a
        ld      (P124_X86_RESULT_AX), de
        ld      (X86_RESULT_AX), de

        call    neogs_wait_data_byte
        ret     c
        ld      e, a
        call    neogs_wait_data_byte
        ret     c
        ld      d, a
        ld      (P124_X86_RESULT_IP), de

        call    neogs_wait_command_done
        ret     c

        ld      a, (P124_X86_RESULT_MAGIC)
        cp      NGS_RESULT_SIGNATURE
        jr      z, .result_frame_ok
        scf
        ret
.result_frame_ok:
        or      a
        ret

; -------------------------------------------------------------------------
; Diagnostic state and messages
; -------------------------------------------------------------------------
P124_DMA_SOURCE:             dw 0
P124_DMA_LENGTH:             dw 0
P124_DMA_HEADER:             dw 0
P124_X86_RESULT_MAGIC:       db 0
P124_X86_RESULT_STATUS:      db 0
P124_X86_RESULT_AX:          dw 0
P124_X86_RESULT_IP:          dw 0
P124_msg_boot_diag_start:    defb "[CORE] Checking NeoGS firmware and physical x86 memory map.", 13, 0
P124_msg_boot_diag_pass:     defb "[CORE] PASS: NeoGS firmware and memory subsystem ready.", 13, 0
P124_msg_boot_protocol_fail: defb "[CORE] FAIL: NeoGS command/data protocol error.", 13, 0
P124_msg_memtest_start:      defb "[MEM] Testing 64 x 16 KiB page mappings at both boundaries...", 13, 0
P124_msg_memtest_pass:       defb "[MEM] PASS: 64 page mappings and 128 boundary bytes verified.", 13, 0
P124_msg_memtest_fail:       defb "[MEM] FAIL: status / phase:page = ", 0
P124_msg_memtest_transport_fail: defb "[MEM] FAIL: NeoGS memory-test command/result timeout.", 13, 0
P124_msg_diag_all_pass:      defb "[DIAG] PASS: all NeoGS firmware diagnostics returned verified results.", 13, 0


; =========================================================================
; EXTERNAL X86T TEST CONTAINER — TR-DOS -> HOST RAM -> NeoGS DMA
; Container v1:
;   header: "X86T", version:u8, record_count:u8
;   record: id:u16, expected_status:u8, expected_AX:u16,
;           payload_length:u16, payload bytes
; =========================================================================

RUN_TRDOS_X86_TEST::
        MACRO_EF_STRING P124_msg_test_suite_start

        ; neogs_load_trdos_file reads TEST.C into #C000. The application
        ; stack remains at #AFFF, safely below the staging buffer.
        ld      hl, P124_test_filename
        ld      a, 'C'
        call    neogs_load_trdos_file
        jp      c, .test_file_error

        ld      (P124_TEST_FILE_LENGTH), de
        ld      a, d
        cp      0
        jr      nz, .test_minimum_size_ok
        ld      a, e
        cp      6
        jp      c, .test_bad_container
.test_minimum_size_ok:

        ; Validate X86T signature and supported version.
        ld      hl, TRDOS_PANEL_BUFFER
        ld      a, (hl)
        cp      'X'
        jp      nz, .test_bad_container
        inc     hl
        ld      a, (hl)
        cp      '8'
        jp      nz, .test_bad_container
        inc     hl
        ld      a, (hl)
        cp      '6'
        jp      nz, .test_bad_container
        inc     hl
        ld      a, (hl)
        cp      'T'
        jp      nz, .test_bad_container
        inc     hl
        ld      a, (hl)
        cp      1
        jp      nz, .test_bad_version
        inc     hl
        ld      a, (hl)
        or      a
        jp      z, .test_bad_container
        ld      (P124_TEST_REMAINING_RECORDS), a

        ; Cursor starts immediately after the six-byte X86T header.
        inc     hl
        ld      (P124_TEST_CURSOR), hl
        ld      hl, (P124_TEST_FILE_LENGTH)
        ld      de, 6
        or      a
        sbc     hl, de
        ld      (P124_TEST_BYTES_REMAINING), hl

        xor     a
        ld      (P124_TEST_PASS_COUNT), a
        ld      (P124_TEST_FAIL_COUNT), a

.test_record_loop:
        ld      a, (P124_TEST_REMAINING_RECORDS)
        or      a
        jp      z, .test_suite_complete

        ; Every record header is exactly seven bytes.
        ld      hl, (P124_TEST_BYTES_REMAINING)
        ld      de, 7
        or      a
        sbc     hl, de
        jp      c, .test_bad_container
        ld      (P124_TEST_BYTES_REMAINING), hl

        ; Decode ID, expected status, expected AX and payload length.
        ld      hl, (P124_TEST_CURSOR)
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        ld      (P124_TEST_ID), de

        ld      a, (hl)
        inc     hl
        ld      (P124_TEST_EXPECT_STATUS), a

        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        ld      (P124_TEST_EXPECT_AX), de

        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        ld      (P124_TEST_PAYLOAD_LENGTH), de
        ld      (P124_TEST_CURSOR), hl

        ; Reject zero-length payloads and any payload extending past EOF.
        ld      hl, (P124_TEST_PAYLOAD_LENGTH)
        ld      a, h
        or      l
        jp      z, .test_bad_container
        ld      de, (P124_TEST_BYTES_REMAINING)
        or      a
        sbc     hl, de
        jp      c, .test_payload_length_ok
        jp      z, .test_payload_length_ok
        jp      .test_bad_container

.test_payload_length_ok:
        ld      hl, (P124_TEST_CURSOR)
        ld      (P124_TEST_PAYLOAD), hl
        ld      bc, (P124_TEST_PAYLOAD_LENGTH)
        call    neogs_send_dma_block
        jp      c, .test_dma_error

        call    neogs_run_and_get_result
        jp      c, .test_result_error

        ; Compare both expected fields. A mismatch is recorded but does not
        ; stop the suite; transport/container errors still abort immediately.
        ld      a, (P124_X86_RESULT_STATUS)
        ld      b, a
        ld      a, (P124_TEST_EXPECT_STATUS)
        cp      b
        jr      nz, .test_record_mismatch

        ld      hl, (P124_X86_RESULT_AX)
        ld      de, (P124_TEST_EXPECT_AX)
        or      a
        sbc     hl, de
        jr      nz, .test_record_mismatch

        ld      a, 1
        ld      (P124_TEST_RESULT_MATCH), a
        jr      .test_record_report

.test_record_mismatch:
        xor     a
        ld      (P124_TEST_RESULT_MATCH), a

.test_record_report:
        MACRO_EF_STRING P124_msg_test_id
        ld      hl, (P124_TEST_ID)
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_expected_status
        ld      a, (P124_TEST_EXPECT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_actual_status
        ld      a, (P124_X86_RESULT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_expected_ax
        ld      hl, (P124_TEST_EXPECT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_actual_ax
        ld      hl, (P124_X86_RESULT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_actual_ip
        ld      hl, (P124_X86_RESULT_IP)
        MACRO_EF_HEX16 hl

        ld      a, (P124_TEST_RESULT_MATCH)
        or      a
        jr      z, .test_record_failed
        ld      a, (P124_TEST_PASS_COUNT)
        inc     a
        ld      (P124_TEST_PASS_COUNT), a
        MACRO_EF_STRING P124_msg_test_pass
        jr      .test_record_advance

.test_record_failed:
        ld      a, (P124_TEST_FAIL_COUNT)
        inc     a
        ld      (P124_TEST_FAIL_COUNT), a
        MACRO_EF_STRING P124_msg_test_fail

.test_record_advance:
        ; Advance over the payload and reduce the exact remaining byte count.
        ld      hl, (P124_TEST_CURSOR)
        ld      de, (P124_TEST_PAYLOAD_LENGTH)
        add     hl, de
        ld      (P124_TEST_CURSOR), hl

        ld      hl, (P124_TEST_BYTES_REMAINING)
        ld      de, (P124_TEST_PAYLOAD_LENGTH)
        or      a
        sbc     hl, de
        ld      (P124_TEST_BYTES_REMAINING), hl

        ld      a, (P124_TEST_REMAINING_RECORDS)
        dec     a
        ld      (P124_TEST_REMAINING_RECORDS), a
        jp      .test_record_loop

.test_suite_complete:
        ; The container must end exactly after the last declared record.
        ld      hl, (P124_TEST_BYTES_REMAINING)
        ld      a, h
        or      l
        jp      nz, .test_bad_container

        MACRO_EF_STRING P124_msg_test_summary
        ld      a, (P124_TEST_PASS_COUNT)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_summary_fail
        ld      a, (P124_TEST_FAIL_COUNT)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13

        ld      a, (P124_TEST_FAIL_COUNT)
        or      a
        jr      nz, .test_suite_failed
        MACRO_EF_STRING P124_msg_test_suite_pass
        or      a
        ret

.test_suite_failed:
        MACRO_EF_STRING P124_msg_test_suite_fail
        scf
        ret

.test_file_error:
        MACRO_EF_STRING P124_msg_test_file_error
        ld      a, (neo_trdos_error)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        ret

.test_bad_version:
        MACRO_EF_STRING P124_msg_test_bad_version
        scf
        ret

.test_bad_container:
        MACRO_EF_STRING P124_msg_test_bad_container
        scf
        ret

.test_dma_error:
        MACRO_EF_STRING P124_msg_test_dma_error
        scf
        ret

.test_result_error:
        MACRO_EF_STRING P124_msg_test_result_error
        scf
        ret

; Test container state. All values surviving NeoGS calls are stored here.
P124_test_filename:             defb "TEST    "
P124_TEST_FILE_LENGTH:          dw 0
P124_TEST_CURSOR:               dw 0
P124_TEST_BYTES_REMAINING:      dw 0
P124_TEST_REMAINING_RECORDS:    db 0
P124_TEST_ID:                   dw 0
P124_TEST_EXPECT_STATUS:        db 0
P124_TEST_EXPECT_AX:            dw 0
P124_TEST_PAYLOAD_LENGTH:       dw 0
P124_TEST_PAYLOAD:              dw 0
P124_TEST_RESULT_MATCH:         db 0
P124_TEST_PASS_COUNT:           db 0
P124_TEST_FAIL_COUNT:           db 0

P124_msg_test_suite_start:       defb "[X86TEST] Loading external TEST.C suite...", 13, 0
P124_msg_test_id:                defb 13, "[X86TEST] ID=", 0
P124_msg_test_expected_status:   defb " EXPECT_STATUS=", 0
P124_msg_test_actual_status:     defb " ACTUAL_STATUS=", 0
P124_msg_test_expected_ax:       defb " EXPECT_AX=", 0
P124_msg_test_actual_ax:         defb " ACTUAL_AX=", 0
P124_msg_test_actual_ip:         defb " ACTUAL_IP=", 0
P124_msg_test_pass:              defb " PASS", 13, 0
P124_msg_test_fail:              defb " FAIL", 13, 0
P124_msg_test_summary:           defb "[X86TEST] PASS COUNT=", 0
P124_msg_test_summary_fail:      defb " FAIL COUNT=", 0
P124_msg_test_suite_pass:        defb "[X86TEST] SUITE PASS.", 13, 0
P124_msg_test_suite_fail:        defb "[X86TEST] SUITE FAILED.", 13, 0
P124_msg_test_file_error:        defb "[X86TEST] ERROR: cannot load TEST.C; TR-DOS error=", 0
P124_msg_test_bad_version:       defb "[X86TEST] ERROR: unsupported X86T container version.", 13, 0
P124_msg_test_bad_container:     defb "[X86TEST] ERROR: malformed X86T container or truncated record.", 13, 0
P124_msg_test_dma_error:         defb "[X86TEST] ERROR: NeoGS DMA transport failed.", 13, 0
P124_msg_test_result_error:      defb "[X86TEST] ERROR: NeoGS execution/result transport failed.", 13, 0
