; =========================================================================
; PROJECT 124 — external x86 test suite source
; Build: nasm -f bin tests/TEST.ASM -o TEST.BIN
; Exported to TR-DOS as TEST.C and executed by the NeoGS x86 core.
;
; X86T container v1 (all multibyte fields little-endian):
;   magic[4] = "X86T"
;   version  = 1
;   count    = number of records
;   record   = ID:u16, expected_status:u8, expected_AX:u16,
;              code_length:u16, code[code_length]
;
; The first suite covers the currently implemented instruction subset and
; the interpreter's current stop/fault cases. Add new tests as new records;
; never hardcode test payload bytes into zx_main/x86_loader.asm.
; =========================================================================

BITS 16
ORG 0

        db 'X86T'
        db 1
        db 6                       ; six independent test records

; TEST 0001 — MOV AX,imm16 / INC AX / NOP / HLT
        dw 0x0001
        db 0                       ; expected status: normal HLT
        dw 0xBBAB                  ; expected AX
        dw test_0001_end-test_0001
test_0001:
        mov     ax, 0xBBAA
        inc     ax
        nop
        hlt
test_0001_end:

; TEST 0002 — 16-bit INC wrap: FFFF -> 0000
        dw 0x0002
        db 0
        dw 0x0000
        dw test_0002_end-test_0002
test_0002:
        mov     ax, 0xFFFF
        inc     ax
        hlt
test_0002_end:

; TEST 0003 — NOP / HLT with reset AX
        dw 0x0003
        db 0
        dw 0x0000
        dw test_0003_end-test_0003
test_0003:
        nop
        hlt
test_0003_end:

; TEST 0004 — unsupported opcode INT3 (#CC), expected status 2
        dw 0x0004
        db 2
        dw 0x0000
        dw test_0004_end-test_0004
test_0004:
        db 0xCC
test_0004_end:

; TEST 0005 — truncated MOV AX,imm16, expected bounds status 4
        dw 0x0005
        db 4
        dw 0x0000
        dw test_0005_end-test_0005
test_0005:
        db 0xB8, 0x34
test_0005_end:

; TEST 0006 — instruction stream ends without HLT, expected status 4
        dw 0x0006
        db 4
        dw 0x0000
        dw test_0006_end-test_0006
test_0006:
        nop
test_0006_end:
