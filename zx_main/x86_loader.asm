; =========================================================================
; PROJECT 124 — TR-DOS task loader + NeoGS DMA / IPC
; Hardware protocol is based on NeoGS Programmer's Guide v0.1.A and
; ports.inc v0.3. The application-level command IDs/frame are Project 124.
;
; DMA mapping used here:
;   NeoGS physical DMA destination = $00D000
;   NeoGS Z80 logical DMA frame address = $5000
;   two-byte length header at $5000; x86 execution begins at $5002.
; This follows the guide's default mapping: logical $4000-$7FFF is the
; second half of physical 32K page 1 ($00C000-$00FFFF).
;
; Host DMA writes to Spectrum address $0000-$3FFF. For DMA WRITE there is
; NO dummy write. The dummy access described by the user is only for DMA READ.
; =========================================================================

; neogs_io.inc is included once by neogs_driver.asm before this module.

DMA_HOST_WINDOW    EQU #0000
DMA_WINDOW_LIMIT   EQU #3000

EXECUTE_X86_FILE_STAGE::
        ld      (P124_X86_REQUEST_FILENAME), hl
        ld      (P124_X86_REQUEST_TYPE), a
        ld      (P124_X86_LOADER_SP_BACKUP), sp
        ld      sp, #BFFF              ; buffer starts at #C000; stack below it

        MACRO_EF_STRING P124_msg_dbg_stack_isolated

        ; -------------------------------------------------------------
        ; Stage 5.0: deterministic diagnostic before accessing TR-DOS.
        ; B8 AA BB 40 90 F4 = MOV AX,BBAA / INC AX / NOP / HLT.
        ; Expected result: status=0, AX=BBAB.
        ; -------------------------------------------------------------
        MACRO_EF_STRING P124_msg_ipc_diag_start

        ; Exercise unknown-command release and explicit firmware reset before DMA.
        ld      a, #FE
        out     (GSCOM), a
        call    neogs_wait_command_done
        jp      c, .diag_protocol_error

        ld      a, CMD_RESET
        out     (GSCOM), a
        call    neogs_wait_command_done
        jp      c, .diag_protocol_error

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

        ; -------------------------------------------------------------
        ; Extended interpreter/transport self-test.
        ; Each case is sent through the real CBIT -> DMA -> DBIT path.
        ; Expected non-zero interpreter statuses are deliberate test results.
        ; -------------------------------------------------------------
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

        ; -------------------------------------------------------------
        ; NeoGS x86 memory test: 64 pages plus word/segment addressing cases.
        ; Destructive only to the reserved x86 memory region.
        ; -------------------------------------------------------------
        MACRO_EF_STRING P124_msg_memtest_start
        call    neogs_mem_test_and_get_result
        jp      c, .diag_extended_fail
        ld      a, (P124_X86_RESULT_STATUS)
        or      a
        jp      nz, .diag_memtest_fail
        ld      hl, (P124_X86_RESULT_AX)
        ld      de, 1
        or      a
        sbc     hl, de
        jp      nz, .diag_memtest_fail
        MACRO_EF_STRING P124_msg_memtest_pass

        ; BIOS foundation POST. Uses the same command/result channel; DMA is untouched.
        MACRO_EF_STRING P124_msg_bios_post_start
        call    neogs_bios_post_and_get_result
        jp      c, .bios_post_transport_fail
        ld      a, (P124_X86_RESULT_STATUS)
        or      a
        jp      nz, .bios_post_fail
        ld      hl, (P124_X86_RESULT_AX)
        ld      de, #B105
        or      a
        sbc     hl, de
        jp      nz, .bios_post_fail
        MACRO_EF_STRING P124_msg_bios_post_pass

        ; -------------------------------------------------------------
        ; Stage 2A: 8086 real-mode INT/IRET frame and stack test.
        ; This validates IVT lookup, FLAGS/CS/IP push order, IF/TF clearing,
        ; IRET restoration, and SP balance. Guest handler execution is Stage 2B.
        ; -------------------------------------------------------------
        MACRO_EF_STRING P124_msg_int_test_start
        call    neogs_int_test_and_get_result
        jp      c, .int_test_transport_fail
        ld      a, (P124_X86_RESULT_STATUS)
        or      a
        jp      nz, .int_test_fail
        ld      hl, (P124_X86_RESULT_AX)
        ld      de, #1A01
        or      a
        sbc     hl, de
        jp      nz, .int_test_fail
        MACRO_EF_STRING P124_msg_int_test_pass

        ; -------------------------------------------------------------
        ; Stage 5A: search TR-DOS directory entry.
        ; Name #5CDD..#5CE4, type #5CE5, per the working project path.
        ; -------------------------------------------------------------
        ld      hl, (P124_X86_REQUEST_FILENAME)
        ld      de, #5CDD
        ld      bc, 8
        ldir
        ld      a, (P124_X86_REQUEST_TYPE)
        ld      (#5CE5), a
        ld      a, 9
        ld      (#5D06), a
        ld      c, 10
        call    #3D13
        ld      a, c
        cp      #FF
        jp      z, .file_not_found

        ; C=#0A returns only the catalogue entry number. Fetch the full
        ; 16-byte descriptor explicitly with C=#08 before using #5CE8..#5CEC.
        ld      a, c
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
        jp      nz, .bad_file_descriptor

        MACRO_EF_STRING P124_msg_file_ok

        ; -------------------------------------------------------------
        ; Stage 5B: validate descriptor BEFORE reading any sector.
        ; #5CE8 = byte length, #5CEA = sector count,
        ; #5CEB = first internal sector (0..15), #5CEC = track.
        ; The DMA frame window is $5000..$7FFF (12 KiB). Its first two
        ; bytes are the length header, so executable payload max is $2FFE.
        ; -------------------------------------------------------------
        ld      bc, (#5CE8)
        ld      a, b
        or      c
        jp      z, .empty_file_error
        ld      (P124_X86_FILE_LENGTH), bc

        ; Reject files larger than the executable 12 KB window minus header.
        ld      a, b
        cp      #2F
        jr      c, .file_length_ok
        jp      nz, .task_too_large
        ld      a, c
        cp      #FF
        jp      nc, .task_too_large
.file_length_ok:
        ; Sector count must equal ceil(file_length / 256).
        ld      hl, (P124_X86_FILE_LENGTH)
        ld      de, 255
        add     hl, de
        ld      e, h
        ld      a, (#5CEA)
        or      a
        jp      z, .empty_file_error
        cp      e
        jp      nz, .bad_file_descriptor
        ld      (P124_X86_READ_REMAINING), a

        ld      a, (#5CEB)
        cp      16
        jp      nc, .bad_file_descriptor
        ld      (P124_X86_READ_SECTOR), a
        ld      a, (#5CEC)
        ld      (P124_X86_READ_TRACK), a
        ld      hl, TRDOS_PANEL_BUFFER
        ld      (P124_X86_READ_BUFFER), hl

.read_sector_loop:
        ; Read exactly one sector per TR-DOS #05 call.
        ld      a, (P124_X86_READ_TRACK)
        ld      d, a
        ld      a, (P124_X86_READ_SECTOR)
        ld      e, a
        ld      hl, (P124_X86_READ_BUFFER)
        ld      b, 1
        ld      c, 5
        xor     a
        ld      (#5D0F), a
        ld      (#5D10), a
        call    #3D13
        ; C=#05 stores its two-byte error result at #5D0F/#5D10.
        ld      a, (#5D0F)
        ld      b, a
        ld      a, (#5D10)
        or      b
        jp      nz, .sector_read_error

        ; Advance host buffer by 256 bytes.
        ld      hl, (P124_X86_READ_BUFFER)
        ld      de, 256
        add     hl, de
        ld      (P124_X86_READ_BUFFER), hl

        ; TR-DOS sectors are numbered 0..15 in this project convention.
        ld      a, (P124_X86_READ_SECTOR)
        inc     a
        cp      16
        jr      c, .sector_same_track
        xor     a
        ld      (P124_X86_READ_SECTOR), a
        ld      a, (P124_X86_READ_TRACK)
        inc     a
        ld      (P124_X86_READ_TRACK), a
        jr      .sector_advanced

.sector_same_track:
        ld      (P124_X86_READ_SECTOR), a

.sector_advanced:
        ld      a, (P124_X86_READ_REMAINING)
        dec     a
        ld      (P124_X86_READ_REMAINING), a
        jp      nz, .read_sector_loop

        MACRO_EF_STRING P124_msg_buf_loaded

        ; -------------------------------------------------------------
        ; Stage 5C: transfer actual task. The DMA frame contains a two-byte
        ; length prefix, therefore the total transfer must fit in $3000 bytes.
        ; -------------------------------------------------------------
        ld      bc, (P124_X86_FILE_LENGTH)
        ld      hl, TRDOS_PANEL_BUFFER
        call    neogs_send_dma_block
        jp      c, .task_dma_error
        MACRO_EF_STRING P124_msg_task_dma_ok

        ; -------------------------------------------------------------
        ; Stage 5D: execute and fetch framed result.
        ; -------------------------------------------------------------
        call    neogs_run_and_get_result
        jp      c, .result_timeout

        MACRO_EF_STRING P124_msg_x86_result_ready
        ld      a, (P124_X86_RESULT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 32
        ld      hl, (P124_X86_RESULT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13

        ld      a, (P124_X86_RESULT_STATUS)
        or      a
        jp      nz, .interpreter_error

        ld      hl, (P124_X86_RESULT_AX)
        call    Util_PrintHex16Screen
        call    LOG_CloseActiveLine
        or      a
        jp      .loader_restore_stack

; -------------------------------------------------------------------------
; Error exits. All return through the same original-stack restoration.
; -------------------------------------------------------------------------
.diag_dma_error:
        MACRO_EF_STRING P124_msg_ipc_diag_dma_fail
        scf
        jp      .loader_restore_stack

.diag_protocol_error:
        MACRO_EF_STRING P124_msg_ipc_diag_frame_fail
        scf
        jp      .loader_restore_stack

.diag_execution_error:
        MACRO_EF_STRING P124_msg_ipc_diag_status_fail
        ld      a, (P124_X86_RESULT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        jp      .loader_restore_stack

.diag_extended_fail:
        MACRO_EF_STRING P124_msg_ipc_edge_fail
        scf
        jp      .loader_restore_stack

.bios_post_transport_fail:
        MACRO_EF_STRING P124_msg_bios_post_transport_fail
        scf
        jp      .loader_restore_stack

.bios_post_fail:
        MACRO_EF_STRING P124_msg_bios_post_fail
        ld      a, (P124_X86_RESULT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 32
        ld      hl, (P124_X86_RESULT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        jp      .loader_restore_stack

.int_test_transport_fail:
        MACRO_EF_STRING P124_msg_int_test_transport_fail
        scf
        jp      .loader_restore_stack

.int_test_fail:
        MACRO_EF_STRING P124_msg_int_test_fail
        ld      a, (P124_X86_RESULT_STATUS)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 32
        ld      hl, (P124_X86_RESULT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        jp      .loader_restore_stack

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
        jp      .loader_restore_stack

.diag_wrong_result:
        MACRO_EF_STRING P124_msg_ipc_diag_wrong_ax
        ld      hl, (P124_X86_RESULT_AX)
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        jp      .loader_restore_stack

.file_not_found:
        MACRO_EF_STRING P124_msg_err_no_file
        scf
        jp      .loader_restore_stack

.empty_file_error:
        MACRO_EF_STRING P124_msg_err_empty_file
        scf
        jp      .loader_restore_stack

.bad_file_descriptor:
        MACRO_EF_STRING P124_msg_err_bad_descriptor
        scf
        jp      .loader_restore_stack

.sector_read_error:
        MACRO_EF_STRING P124_msg_err_sector_read
        ld      hl, (#5D0F)
        MACRO_EF_HEX16 hl
        MACRO_EF_CHAR 13
        scf
        jp      .loader_restore_stack

.task_too_large:
        MACRO_EF_STRING P124_msg_err_task_too_large
        scf
        jp      .loader_restore_stack

.task_dma_error:
        MACRO_EF_STRING P124_msg_err_dma_transfer
        scf
        jp      .loader_restore_stack

.result_timeout:
        MACRO_EF_STRING P124_msg_err_result_timeout
        scf
        jp      .loader_restore_stack

.interpreter_error:
        MACRO_EF_STRING P124_msg_err_interpreter_status
        scf
        jp      .loader_restore_stack

.loader_restore_stack:
        ld      hl, (P124_X86_LOADER_SP_BACKUP)
        ld      sp, hl
        ret

; =========================================================================
; NeoGS transport helpers — exact CBIT/DBIT meanings from Guide v0.1.A
; =========================================================================

; IN: HL=source in host RAM, BC=payload byte count (1..#2FFE).
; OUT: Carry clear after NeoGS armed DMA, consumed the host end marker,
;      and disabled DMA. Carry set on timeout.
;
; Protocol:
;   host OUT GSCOM,CMD_LOAD_X86 -> CBIT=1
;   NeoGS configures DMA, clears CLRCBIT -> CBIT=0 (READY)
;   host LDIR to #0000..#3FFF (no dummy write)
;   host OUT GSCOM,#FF -> CBIT=1 (end marker)
;   NeoGS disables DMA, clears CLRCBIT -> CBIT=0 (DONE)
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

        ; Validate payload + 2-byte length prefix <= $3000.
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

        ; LDIR is used for BOTH pieces of the frame. This is intentional:
        ; the DMA engine observes host memory-write cycles. The first LDIR
        ; writes the two-byte header to host addresses #0000-#0001; the second
        ; writes the payload to #0002 onward. No direct LD (nn),A writes and
        ; no temporary stack are needed.
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

        ; End marker is a command-byte write; it is NOT a DMA data byte.
        ld      a, #FF
        out     (GSCOM), a
        call    neogs_wait_command_done
        ret

.dma_bad_length:
        scf
        ret

; Send RUN command and fetch the four-byte application result frame:
; A5 signature, status, AX low, AX high.
neogs_run_and_get_result:
        ld      a, CMD_RUN_X86
        out     (GSCOM), a
        call    neogs_wait_command_done_long
        ret     c
        jp      neogs_get_result_frame

; Run the BIOS low-memory POST and fetch the existing four-byte result frame.
neogs_bios_post_and_get_result:
        ld      a, CMD_BIOS_POST
        out     (GSCOM), a
        call    neogs_wait_command_done_long
        ret     c
        jp      neogs_get_result_frame

; Run the 8086 interrupt entry/return architectural self-test.
neogs_int_test_and_get_result:
        ld      a, CMD_INT_TEST
        out     (GSCOM), a
        call    neogs_wait_command_done_long
        ret     c
        jp      neogs_get_result_frame

; Run the NeoGS physical-memory self-test and fetch its result frame.
neogs_mem_test_and_get_result:
        ld      a, CMD_MEM_TEST
        out     (GSCOM), a
        call    neogs_wait_command_done_long
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

; Diagnostic data: MOV AX,#BBAA / INC AX / NOP / HLT -> AX=#BBAB.
P124_msg_memtest_start: DEFB "[MEM] Testing x86 RAM pages and 8086 word/segment addressing...", 13, 0
P124_msg_memtest_pass:  DEFB "[MEM] PASS: 64 pages + word access + segment/offset wrap verified.", 13, 0
P124_msg_bios_post_start: DEFB "[BIOS] Stage 1: initialize IVT and BIOS Data Area...", 13, 0
P124_msg_bios_post_pass: DEFB "[BIOS] PASS: IVT/BDA initialized; 640 KiB and text profile verified.", 13, 0
P124_msg_bios_post_transport_fail: DEFB "[BIOS] FAIL: POST command/result timeout.", 13, 0
P124_msg_bios_post_fail: DEFB "[BIOS] FAIL: POST status/detail = ", 0
P124_msg_int_test_start: DEFB "[INT] Stage 2A: checking IVT lookup and 8086 interrupt stack frame...", 13, 0
P124_msg_int_test_pass: DEFB "[INT] PASS: FLAGS/CS/IP frame, IF/TF clear, IRET restore and SP balance.", 13, 0
P124_msg_int_test_transport_fail: DEFB "[INT] FAIL: interrupt test command/result timeout.", 13, 0
P124_msg_int_test_fail: DEFB "[INT] FAIL: status/detail = ", 0
P124_msg_memtest_fail:  DEFB "[MEM] FAIL: status / detail = ", 0

x86_diag_program:
        defb    #B8, #AA, #BB, #40, #90, #F4
x86_diag_program_end:

; Additional interpreter edge cases, each transferred through actual DMA.
x86_diag_inc_wrap:
        defb    #B8, #FF, #FF, #40, #F4       ; AX wraps to 0000
x86_diag_inc_wrap_end:
x86_diag_nop_hlt:
        defb    #90, #F4                      ; NOP followed by HLT
x86_diag_nop_hlt_end:
x86_diag_unsupported:
        defb    #CC                            ; unsupported opcode -> status 2
x86_diag_unsupported_end:
x86_diag_truncated_mov:
        defb    #B8, #34                       ; MOV AX,imm16 missing high byte
x86_diag_truncated_mov_end:
x86_diag_fallthrough:
        defb    #90                            ; IP reaches exclusive end -> status 4
x86_diag_fallthrough_end:

; Run one diagnostic payload through DMA, execute it, and compare both
; interpreter status and AX. IN: HL=payload, BC=length, A=expected status,
; DE=expected AX. OUT: carry clear on exact match, set on any transport/result
; mismatch. This deliberately accepts the expected error statuses above.
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

; Data/state
P124_X86_LOADER_SP_BACKUP: dw 0
P124_DMA_SOURCE:           dw 0
P124_DMA_LENGTH:           dw 0
P124_DMA_HEADER:           dw 0
P124_X86_REQUEST_FILENAME: dw 0
P124_X86_REQUEST_TYPE:     db 0
P124_X86_FILE_LENGTH:      dw 0
P124_X86_READ_BUFFER:      dw 0
P124_X86_READ_REMAINING:   db 0
P124_X86_READ_TRACK:       db 0
P124_X86_READ_SECTOR:      db 0
P124_X86_RESULT_MAGIC:     db 0
P124_X86_RESULT_STATUS:    db 0
P124_X86_RESULT_AX:        dw 0
P124_DIAG_EXPECT_STATUS:    db 0
P124_DIAG_EXPECT_AX:        dw 0

; Strings
P124_msg_dbg_stack_isolated: defb "[DBG] LOADER STACK AT #BFFF; TR-DOS BUFFER AT #C000.", 13, 0
P124_msg_ipc_diag_start:     defb "[IPC TEST] Starting documented CBIT/DBIT + DMA diagnostic.", 13, 0
P124_msg_ipc_diag_pass:      defb "[IPC TEST] PASS: x86 HLT completed, AX=#", 0
P124_msg_ipc_diag_dma_fail:  defb "[IPC TEST] FAIL: DMA ready/end handshake timed out.", 13, 0
P124_msg_ipc_diag_frame_fail:defb "[IPC TEST] FAIL: command/data frame timeout or bad signature.", 13, 0
P124_msg_ipc_diag_status_fail:defb "[IPC TEST] FAIL: x86 interpreter status is not zero: #", 0
P124_msg_ipc_diag_wrong_ax:  defb "[IPC TEST] FAIL: expected AX=#BBAB, got #", 0
P124_msg_ipc_edge_start:      defb "[IPC TEST] Running 5 interpreter edge cases through DMA.", 13, 0
P124_msg_ipc_edge_pass:       defb "[IPC TEST] PASS: 5 interpreter edge cases; DMA/IPC stable.", 13, 0
P124_msg_ipc_edge_fail:       defb "[IPC TEST] FAIL: interpreter edge-case or repeated DMA test.", 13, 0
P124_msg_file_ok:            defb "[STAGE 5] [TRDOS] Task file found.", 13, 0
P124_msg_buf_loaded:         defb "[STAGE 5] [BUFFER] File sectors loaded into host RAM #C000.", 13, 0
P124_msg_task_dma_ok:        defb "[STAGE 5] [DMA] NeoGS acknowledged DMA completion.", 13, 0
P124_msg_x86_result_ready:  defb "[STAGE 5] [RESULT] Status / AX = ", 0
P124_msg_err_no_file:        defb "[STAGE 5] [ERROR] Task file not found.", 13, 0
P124_msg_err_empty_file:     defb "[STAGE 5] [ERROR] Task file is empty or has zero sectors.", 13, 0
P124_msg_err_bad_descriptor: defb "[STAGE 5] [ERROR] TR-DOS file descriptor is inconsistent.", 13, 0
P124_msg_err_sector_read:    defb "[STAGE 5] [ERROR] TR-DOS sector read failed; code=#", 0
P124_msg_err_task_too_large: defb "[STAGE 5] [ERROR] Task exceeds the 12 KB executable window (max payload $2FFE).", 13, 0
P124_msg_err_dma_transfer:   defb "[STAGE 5] [ERROR] NeoGS DMA handshake failed.", 13, 0
P124_msg_err_result_timeout: defb "[STAGE 5] [ERROR] NeoGS result frame timed out.", 13, 0
P124_msg_err_interpreter_status: defb "[STAGE 5] [ERROR] x86 interpreter returned non-zero status.", 13, 0
