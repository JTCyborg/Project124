; Build isolated V2 stage-0 bootstrap.
        DEVICE ZXSPECTRUM128
        INCLUDE "../shared/neogs_io.inc"
        ORG     #4000
        INCLUDE "bootstrap_v2_stage0.asm"
        SAVEBIN "neogs_v2_bootstrap.bin", v2_stage0_start, v2_stage0_end - v2_stage0_start
        SAVEBIN "zx_main/neogs_v2_bootstrap.bin", v2_stage0_start, v2_stage0_end - v2_stage0_start
        ASSERT v2_stage0_end - v2_stage0_start <= 248
