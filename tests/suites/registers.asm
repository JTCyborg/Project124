; Register-transfer and general-register baseline tests.
        dw 0x1001
        db 0
        dw 0xBBAB
        dw test_registers_0001_end-test_registers_0001
test_registers_0001:
        mov     ax, 0xBBAA
        inc     ax
        nop
        hlt
test_registers_0001_end:
