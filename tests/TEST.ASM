; =========================================================================
; PROJECT 124 — external x86 test suite aggregator
; Build from repository root: nasm -f bin tests/TEST.ASM -o TEST.BIN
; The host loads the resulting TR-DOS file TEST.C and executes each record.
;
; X86T v1 header:
;   "X86T" signature, version byte, record-count byte.
; Each included category contributes records:
;   ID:u16, expected_status:u8, expected_AX:u16, code_length:u16, code bytes.
; =========================================================================

BITS 16
ORG 0

        db 'X86T'
        db 1
        db 6                       ; total records across all included groups

%include "tests/suites/decoder.asm"
%include "tests/suites/registers.asm"
%include "tests/suites/arithmetic.asm"
%include "tests/suites/control_flow.asm"
