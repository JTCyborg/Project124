; HLT and instruction-stream termination tests.
        dw 0x4001
        db 0
        dw 0x0000
        dw test_control_0001_end-test_control_0001
test_control_0001:
        nop
        hlt
test_control_0001_end:

        dw 0x4002
        db 4
        dw 0x0000
        dw test_control_0002_end-test_control_0002
test_control_0002:
        nop
test_control_0002_end:
