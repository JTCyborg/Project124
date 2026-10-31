; =========================================================================
; Build both NeoGS binaries from the Project 124 root:
;   sjasmplus neogs_sub/build_firmware.asm
;
; neogs_code.bin       custom firmware, loaded at logical RAM address $0000
; neogs_bootstrap.bin  tiny GS105a module, loaded by ROM at $5B00
; =========================================================================
        DEVICE ZXSPECTRUM128
        INCLUDE "main.asm"

; Low RAM is used by the firmware and its stack. Keep the image below $3000;
; the Z80 stack is placed at $3FFF and the x86 DMA payload starts at $5000.
        ASSERT neogs_firmware_end <= $3000
        SAVEBIN "neogs_code.bin", 0, neogs_firmware_end
        SAVEBIN "zx_main/neogs_code.bin", 0, neogs_firmware_end

; Stock GS105a safely hosts a small resident module in $5B00-$5FFF.
        ORG     $5B00
        INCLUDE "bootstrap.asm"
        ASSERT neogs_bootstrap_start = $5B00
        ASSERT neogs_bootstrap_end <= $6000
        SAVEBIN "neogs_bootstrap.bin", neogs_bootstrap_start, neogs_bootstrap_end - neogs_bootstrap_start
        SAVEBIN "zx_main/neogs_bootstrap.bin", neogs_bootstrap_start, neogs_bootstrap_end - neogs_bootstrap_start
