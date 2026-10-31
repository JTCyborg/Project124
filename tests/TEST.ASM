; =========================================================================
; PROJECT 124 — first external x86 test program
; Assembled by NASM as a flat 16-bit binary and stored on TR-DOS as TEST.C.
;
; Current NeoGS interpreter baseline:
;   MOV AX, BBAA
;   INC AX
;   NOP
;   HLT
; Expected result: exit_status=0, AX=BBAB.
;
; Keep this first test within the currently implemented opcode subset.
; As the NeoGS CPU core grows, this file becomes the first member of the
; external x86 test suite. Do not embed its bytes in zx_main/x86_loader.asm.
; =========================================================================

BITS 16
ORG 0

test_entry:
        mov     ax, 0xBBAA
        inc     ax
        nop
        hlt

test_end:
