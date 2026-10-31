; =========================================================================
; PROJECT 124 — NeoGS interpreter and physical-memory diagnostics
;
; All diagnostic x86 payloads are embedded in the host application and are
; sent to the already-running NeoGS firmware through the existing DMA path.
; neoprog.C is reserved exclusively for the NeoGS firmware image.
; =========================================================================

DMA_HOST_WINDOW    EQU #0000
DMA_WINDOW_LIMIT   EQU #3000

RUN_NEOGS_DIAGNOSTICS::
        MACRO_EF_STRING P124_msg_ipc_diag_start

        ; Unknown-command release and explicit firmware reset before DMA.
        ld      a, #FE
        out     (GSCOM), a
        call    neogs_wait_command_done
        jp      c, .diag_protocol_error

        ld      a, CMD_RESET
        out     (GSCOM), a
        call    neogs_wait_command_done
        jp      c, .diag_protocol_error

        ; MOV AX,BBAA / INC AX / NOP / HLT -> status 0, AX=BBAB.
        ld      hl, x86_diag_program
        ld      bc, x86_diag_program_end - x86_diag_program
        call    neogs_send_dma_block
        jp      c, .diag_dma_error

        call    neogs_run_and_get_result
        jp      c, .diag_protocol_error

        ld      a, (P124_X86_RESULT_STATUS)
        or      a
        jp      nz, .diag_execution_error
        ld      hl, (P124_X86_RESULT_AX)
        ld      de, #BBAB
        or      a
        sbc     hl, de
        jp      nz, .diag_wrong_result

        MACRO_EF_STRING P124_msg_ipc_diag_pass
        ld      hl, (P124_X86_RESULT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13

        ; Five interpreter edge cases. Every payload crosses the real DMA
        ; transport and every result is fetched back from NeoGS over GSDAT.
        MACRO_EF_STRING P124_msg_ipc_edge_start

        ld      hl, x86_diag_inc_wrap
        ld      bc, x86_diag_inc_wrap_end - x86_diag_inc_wrap
        xor     a
        ld      de, #0000
        call    neogs_run_diag_case
        jp      c, .diag_extended_fail

        ld      hl, x86_diag_nop_hlt
        ld      bc, x86_diag_nop_hlt_end - x86_diag_nop_hlt
        xor     a
        ld      de, #0000
        call    neogs_run_diag_case
        jp      c, .diag_extended_fail

        ld      hl, x86_diag_unsupported
        ld      bc, x86_diag_unsupported_end - x86_diag_unsupported
        ld      a, 2
        ld      de, #0000
        call    neogs_run_diag_case
        jp      c, .diag_extended_fail

        ld      hl, x86_diag_truncated_mov
        ld      bc, x86_diag_truncated_mov_end - x86_diag_truncated_mov
        ld      a, 4
        ld      de, #0000
        call    neogs_run_diag_case
        jp      c, .diag_extended_fail

        ld      hl, x86_diag_fallthrough
        ld      bc, x86_diag_fallthrough_end - x86_diag_fallthrough
        ld      a, 4
        ld      de, #0000
        call    neogs_run_diag_case
        jp      c, .diag_extended_fail

        MACRO_EF_STRING P124_msg_ipc_edge_pass

        ; This command invokes x86_mem_test inside the NeoGS firmware.
        ; The host accepts PASS only after receiving status=0 and AX=1.
        MACRO_EF_STRING P124_msg_memtest_start
        call    neogs_mem_test_and_get_result
        jp      c, .diag_memtest_transport_fail
        ld      a, (P124_X86_RESULT_STATUS)
        or      a
        jp      nz, .diag_memtest_fail
        ld      hl, (P124_X86_RESULT_AX)
        ld      de, 1
        or      a
        sbc     hl, de
        jp      nz, .diag_memtest_fail
        MACRO_EF_STRING P124_msg_memtest_pass

        MACRO_EF_STRING P124_msg_diag_all_pass
        or      a
        ret

; -------------------------------------------------------------------------
; Failure exits. No PASS message is emitted unless a NeoGS result frame
; has been received and its signature, status and expected result checked.
; -------------------------------------------------------------------------
.diag_dma_error:
        MACRO_EF_STRING P124_msg_ipc_diag_dma_fail
        scf
        ret

.diag_protocol_error:
        MACRO_EF_STRING P124_msg_ipc_diag_frame_fail
        scf
        ret

.diag_execution_error:
        MACRO_EF_STRING P124_msg_ipc_diag_status_fail
        ld      a, (P124_X86_RESULT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        ret

.diag_extended_fail:
        MACRO_EF_STRING P124_msg_ipc_edge_fail
        scf
        ret

.diag_memtest_transport_fail:
        MACRO_EF_STRING P124_msg_memtest_transport_fail
        scf
        ret

.diag_memtest_fail:
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

.diag_wrong_result:
        MACRO_EF_STRING P124_msg_ipc_diag_wrong_ax
        ld      hl, (P124_X86_RESULT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        ret

; =========================================================================
; External TR-DOS x86 test runner.
; TEST.C is assembled from tests/TEST.ASM on the PC, stored on disk, loaded
; by the host Z80 into #C000, then transferred to NeoGS through DMA.
; The first fixture expects MOV AX,BBAA / INC AX / NOP / HLT -> AX=BBAB.
; =========================================================================
RUN_TRDOS_X86_TEST::
        MACRO_EF_STRING P124_msg_external_test_start

        ld      hl, P124_test_filename
        ld      a, 'C'
        call    neogs_load_trdos_file
        jp      c, .test_file_load_failed

        ; Validate the X86T container header before reading any record.
        ld      hl, TRDOS_PANEL_BUFFER
        ld      a, (hl)
        cp      'X'
        jp      nz, .test_format_failed
        inc     hl
        ld      a, (hl)
        cp      '8'
        jp      nz, .test_format_failed
        inc     hl
        ld      a, (hl)
        cp      '6'
        jp      nz, .test_format_failed
        inc     hl
        ld      a, (hl)
        cp      'T'
        jp      nz, .test_format_failed
        inc     hl
        ld      a, (hl)
        cp      1
        jp      nz, .test_format_failed
        inc     hl
        ld      a, (hl)
        or      a
        jp      z, .test_format_failed
        ld      (P124_TESTS_REMAINING), a
        xor     a
        ld      (P124_TESTS_PASSED), a
        ld      (P124_TESTS_FAILED), a
        inc     hl
        ld      (P124_TEST_RECORD_PTR), hl

.test_record_loop:
        ; Record: ID word, expected status byte, expected AX word,
        ; code length word, then exact x86 machine-code bytes.
        ld      hl, (P124_TEST_RECORD_PTR)
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
        ld      (P124_TEST_LENGTH), de
        ld      (P124_TEST_PAYLOAD), hl

        ; Reject zero-length records and records larger than the DMA window.
        ld      a, d
        or      e
        jp      z, .test_format_failed
        ld      a, d
        cp      #30
        jr      c, .test_length_valid
        jp      nz, .test_format_failed
        ld      a, e
        or      a
        jp      nz, .test_format_failed
.test_length_valid:
        push    hl
        ld      de, (P124_TEST_LENGTH)
        add     hl, de
        ld      (P124_TEST_NEXT_RECORD), hl
        pop     hl

        ; Transfer only the x86 payload, not the container metadata.
        ld      bc, (P124_TEST_LENGTH)
        call    neogs_send_dma_block
        jp      c, .test_dma_failed

        call    neogs_run_and_get_result
        jp      c, .test_protocol_failed

        ; Print the complete machine-readable test result as a human report.
        MACRO_EF_STRING P124_msg_test_id
        ld      hl, (P124_TEST_ID)
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_expected_status
        ld      a, (P124_TEST_EXPECT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_expected_ax
        ld      hl, (P124_TEST_EXPECT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_actual_status
        ld      a, (P124_X86_RESULT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_actual_ax
        ld      hl, (P124_X86_RESULT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_STRING P124_msg_test_ip
        ld      hl, (P124_X86_RESULT_IP)
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13

        ; A test passes only when both expected status and AX match.
        ld      a, (P124_X86_RESULT_STATUS)
        ld      b, a
        ld      a, (P124_TEST_EXPECT_STATUS)
        cp      b
        jr      nz, .test_record_fail
        ld      hl, (P124_X86_RESULT_AX)
        ld      de, (P124_TEST_EXPECT_AX)
        or      a
        sbc     hl, de
        jr      nz, .test_record_fail

        ld      a, (P124_TESTS_PASSED)
        inc     a
        ld      (P124_TESTS_PASSED), a
        jr      .test_record_next

.test_record_fail:
        ld      a, (P124_TESTS_FAILED)
        inc     a
        ld      (P124_TESTS_FAILED), a

.test_record_next:
        ld      hl, (P124_TEST_NEXT_RECORD)
        ld      (P124_TEST_RECORD_PTR), hl
        ld      a, (P124_TESTS_REMAINING)
        dec     a
        ld      (P124_TESTS_REMAINING), a
        jr      nz, .test_record_loop

        MACRO_EF_STRING P124_msg_test_summary
        ld      a, (P124_TESTS_PASSED)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 32
        ld      a, (P124_TESTS_FAILED)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13

        ld      a, (P124_TESTS_FAILED)
        or      a
        jr      nz, .test_suite_failed
        MACRO_EF_STRING P124_msg_external_test_pass
        or      a
        ret

.test_suite_failed:
        MACRO_EF_STRING P124_msg_external_test_fail
        scf
        ret

.test_file_load_failed:
        MACRO_EF_STRING P124_msg_external_test_file_fail
        ld      a, (neo_trdos_error)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        ret

.test_format_failed:
        MACRO_EF_STRING P124_msg_external_test_format_fail
        scf
        ret

.test_dma_failed:
        MACRO_EF_STRING P124_msg_external_test_dma_fail
        scf
        ret

.test_protocol_failed:
        MACRO_EF_STRING P124_msg_external_test_protocol_fail
        scf
        ret

P124_test_filename:               defb "TEST    "
P124_TEST_RECORD_PTR:             dw 0
P124_TEST_NEXT_RECORD:            dw 0
P124_TEST_PAYLOAD:                dw 0
P124_TEST_LENGTH:                 dw 0
P124_TEST_ID:                     dw 0
P124_TEST_EXPECT_STATUS:          db 0
P124_TEST_EXPECT_AX:              dw 0
P124_TESTS_REMAINING:             db 0
P124_TESTS_PASSED:                db 0
P124_TESTS_FAILED:                db 0
P124_msg_external_test_start:     defb "[X86 TEST] Loading TEST.C container from TR-DOS.", 13, 0
P124_msg_external_test_pass:      defb "[X86 TEST] SUITE PASS.", 13, 0
P124_msg_external_test_fail:      defb "[X86 TEST] SUITE FAIL.", 13, 0
P124_msg_external_test_file_fail: defb "[X86 TEST] FAIL: TEST.C load error = #", 0
P124_msg_external_test_format_fail: defb "[X86 TEST] FAIL: invalid X86T header, version, count or record length.", 13, 0
P124_msg_external_test_dma_fail:  defb "[X86 TEST] FAIL: DMA transfer timeout.", 13, 0
P124_msg_external_test_protocol_fail: defb "[X86 TEST] FAIL: NeoGS execution/result protocol error.", 13, 0
P124_msg_test_id:                 defb "[TEST] ID=#", 0
P124_msg_test_expected_status:    defb " EXPECT_STATUS=#", 0
P124_msg_test_expected_ax:        defb " EXPECT_AX=#", 0
P124_msg_test_actual_status:      defb " ACTUAL_STATUS=#", 0
P124_msg_test_actual_ax:          defb " ACTUAL_AX=#", 0
P124_msg_test_ip:                 defb " IP=#", 0
P124_msg_test_summary:            defb "[X86 TEST] SUMMARY PASS/FAIL = ", 0

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
; x86 diagnostic programs are host-side payloads, not the NeoGS firmware.
; They are copied into NeoGS by neogs_send_dma_block immediately before RUN.
; -------------------------------------------------------------------------
x86_diag_program:
        defb    #B8, #AA, #BB, #40, #90, #F4
x86_diag_program_end:

x86_diag_inc_wrap:
        defb    #B8, #FF, #FF, #40, #F4
x86_diag_inc_wrap_end:

x86_diag_nop_hlt:
        defb    #90, #F4
x86_diag_nop_hlt_end:

x86_diag_unsupported:
        defb    #CC
x86_diag_unsupported_end:

x86_diag_truncated_mov:
        defb    #B8, #34
x86_diag_truncated_mov_end:

x86_diag_fallthrough:
        defb    #90
x86_diag_fallthrough_end:

; IN: HL=payload, BC=length, A=expected status, DE=expected AX.
; OUT: carry clear only when the returned NeoGS frame matches both values.
neogs_run_diag_case:
        ld      (P124_DIAG_EXPECT_STATUS), a
        ld      (P124_DIAG_EXPECT_AX), de
        call    neogs_send_dma_block
        ret     c
        call    neogs_run_and_get_result
        ret     c
        ld      a, (P124_X86_RESULT_STATUS)
        ld      b, a
        ld      a, (P124_DIAG_EXPECT_STATUS)
        cp      b
        jr      nz, .diag_case_failed
        ld      hl, (P124_X86_RESULT_AX)
        ld      de, (P124_DIAG_EXPECT_AX)
        or      a
        sbc     hl, de
        jr      nz, .diag_case_failed
        or      a
        ret
.diag_case_failed:
        scf
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
P124_DIAG_EXPECT_STATUS:     db 0
P124_DIAG_EXPECT_AX:         dw 0

P124_msg_ipc_diag_start:     defb "[IPC TEST] Starting NeoGS interpreter diagnostic.", 13, 0
P124_msg_ipc_diag_pass:      defb "[IPC TEST] PASS: x86 HLT completed, AX=#", 0
P124_msg_ipc_diag_dma_fail:  defb "[IPC TEST] FAIL: DMA ready/end handshake timed out.", 13, 0
P124_msg_ipc_diag_frame_fail:defb "[IPC TEST] FAIL: command/data frame timeout or bad signature.", 13, 0
P124_msg_ipc_diag_status_fail:defb "[IPC TEST] FAIL: x86 interpreter returned status #", 0
P124_msg_ipc_diag_wrong_ax:  defb "[IPC TEST] FAIL: expected AX=#BBAB, got #", 0
P124_msg_ipc_edge_start:     defb "[IPC TEST] Running 5 interpreter edge cases through DMA.", 13, 0
P124_msg_ipc_edge_pass:      defb "[IPC TEST] PASS: 5 interpreter edge cases; DMA/IPC stable.", 13, 0
P124_msg_ipc_edge_fail:      defb "[IPC TEST] FAIL: interpreter edge-case or repeated DMA test.", 13, 0
P124_msg_memtest_start:      defb "[MEM] Testing 64 x 16 KiB page mappings at both boundaries...", 13, 0
P124_msg_memtest_pass:       defb "[MEM] PASS: 64 page mappings and 128 boundary bytes verified.", 13, 0
P124_msg_memtest_fail:       defb "[MEM] FAIL: status / phase:page = ", 0
P124_msg_memtest_transport_fail: defb "[MEM] FAIL: NeoGS memory-test command/result timeout.", 13, 0
P124_msg_diag_all_pass:      defb "[DIAG] PASS: all NeoGS firmware diagnostics returned verified results.", 13, 0
