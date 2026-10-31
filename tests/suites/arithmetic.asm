; Arithmetic boundary tests.
        dw 0x3001
        db 0
        dw 0x0000
        dw test_arithmetic_0001_end-test_arithmetic_0001
test_arithmetic_0001:
        mov     ax, 0xFFFF
        inc     ax
        hlt
test_arithmetic_0001_end:
