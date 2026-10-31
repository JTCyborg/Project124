; =========================================================================
; PROJECT 124 — external x86 test suite source
; Build: nasm -f bin tests/test.asm -o test.bin
; The binary is copied to TR-DOS as TEST.C.
;
; Container format (little-endian):
;   4 bytes  magic "X86T"
;   1 byte   format version (1)
;   1 byte   number of test records
;   repeated records:
;     word   test ID
;     byte   expected x86 exit status
;     word   expected AX
;     word   machine-code length
;     bytes  x86 machine code
;
; This fixture deliberately uses only the currently implemented x86 subset.
; It proves the complete source -> NASM -> TR-DOS -> Z80 -> DMA -> NeoGS
; -> result-frame pipeline. Additional test records can be added without
; embedding test bytes into zx_main/x86_loader.asm.
; =========================================================================

BITS 16
ORG 0

        db 'X86T'
        db 1                       ; container version
        db 1                       ; test record count

        dw 0x0001                  ; test ID
        db 0                       ; expected status: success / HLT
        dw 0xBBAB                  ; expected AX
        dw test_0001_end-test_0001 ; payload length
test_0001:
        mov     ax, 0xBBAA
        inc     ax
        nop
        hlt
test_0001_end:
