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
