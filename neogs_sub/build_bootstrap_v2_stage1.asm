; Build isolated V2 stage-1 receiver.
; It is not linked into the active V1 package until stage-0/host protocol is ready.
        DEVICE ZXSPECTRUM128
        INCLUDE "../shared/neogs_io.inc"
        ORG     #4800
        INCLUDE "bootstrap_v2_stage1.asm"
        SAVEBIN "neogs_v2_stage1.bin", v2_stage1_start, v2_stage1_end - v2_stage1_start
        SAVEBIN "zx_main/neogs_v2_stage1.bin", v2_stage1_start, v2_stage1_end - v2_stage1_start
        ASSERT v2_stage1_end - v2_stage1_start <= #0800
