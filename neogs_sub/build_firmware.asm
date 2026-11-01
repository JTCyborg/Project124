; =========================================================================
; Build NeoGS firmware and one deployable package from the Project 124 root:
;   sjasmplus neogs_sub/build_firmware.asm
;
; neogs_code.bin       custom firmware, loaded at logical RAM address $0000
; neogs_bootstrap.bin  intermediate bootstrap; neoprog.bin packages it with firmware
; =========================================================================
        DEVICE ZXSPECTRUM128
        INCLUDE "main.asm"

; Low RAM is used by the firmware and its stack. Keep the image below $3000;
; the Z80 stack is placed at $3FFF and the x86 DMA payload starts at $5000.
        ASSERT neogs_firmware_end <= $3000
        SAVEBIN "neogs_code.bin", 0, neogs_firmware_end
        SAVEBIN "zx_main/neogs_code.bin", 0, neogs_firmware_end

; GS105a #14 writes the executable bootstrap into fixed RAM $4000-$7FFF.
        ORG     $4000
        INCLUDE "bootstrap.asm"
        ASSERT neogs_bootstrap_start = $4000
        ASSERT neogs_bootstrap_end <= $7FFF
        SAVEBIN "neogs_bootstrap.bin", neogs_bootstrap_start, neogs_bootstrap_end - neogs_bootstrap_start
        SAVEBIN "zx_main/neogs_bootstrap.bin", neogs_bootstrap_start, neogs_bootstrap_end - neogs_bootstrap_start

; One deployable file: [WORD bootstrap_length][bootstrap][firmware].
; The host reads this package once from TR-DOS as neoprog.C.
        ORG     #8000
neoprog_package_start:
        DEFW    neogs_bootstrap_end - neogs_bootstrap_start
        INCBIN  "neogs_bootstrap.bin"
        INCBIN  "neogs_code.bin"
neoprog_package_end:
        SAVEBIN "neoprog.bin", neoprog_package_start, neoprog_package_end - neoprog_package_start
        SAVEBIN "zx_main/neoprog.bin", neoprog_package_start, neoprog_package_end - neoprog_package_start
