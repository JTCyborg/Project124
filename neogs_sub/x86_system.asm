; =========================================================================
; PROJECT 124 — x86 system-environment boundary.
; CPU handlers call these services instead of depending directly on the
; NeoGS debug-queue implementation. Future BIOS/interrupt/I/O services
; belong in this module or in dedicated system submodules.
; =========================================================================

x86_sys_log_started:
        ld      hl, neo_debug_msg_x86_started
        jp      neo_debug_puts

x86_sys_log_hlt:
        ld      hl, neo_debug_msg_x86_hlt
        jp      neo_debug_puts

x86_sys_log_unsupported:
        ld      hl, neo_debug_msg_x86_unsupported
        jp      neo_debug_puts

x86_sys_log_bounds:
        ld      hl, neo_debug_msg_x86_bounds
        jp      neo_debug_puts

neo_debug_msg_x86_started:      db "[NEOGS] X86 PAYLOAD EXECUTION STARTED.", 13, 0
neo_debug_msg_x86_hlt:          db "[NEOGS] X86 HLT REACHED.", 13, 0
neo_debug_msg_x86_unsupported:  db "[NEOGS] X86 UNSUPPORTED OPCODE.", 13, 0
neo_debug_msg_x86_bounds:       db "[NEOGS] X86 IP OUT OF RANGE.", 13, 0
