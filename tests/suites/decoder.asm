; Decoder faults and truncated-instruction boundary tests.
        dw 0x0001
        db 2
        dw 0x0000
        dw test_decoder_0001_end-test_decoder_0001
test_decoder_0001:
        db 0xCC
test_decoder_0001_end:

        dw 0x0002
        db 4
        dw 0x0000
        dw test_decoder_0002_end-test_decoder_0002
test_decoder_0002:
        db 0xB8, 0x34
test_decoder_0002_end:
