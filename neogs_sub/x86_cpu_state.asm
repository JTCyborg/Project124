; =========================================================================
; PROJECT 124 — x86 execution-control state.
; Expanded register and FLAGS state will be added here in subsequent stages.
; =========================================================================
x86_steps_remaining: dw 0
x86_program_end:     dw 0
x86_exit_status:     db 0

; NeoGS-local diagnostic messages, queued for the host Z80 #EF logger.
neo_debug_msg_x86_hlt:         db "[NEOGS] X86 HLT REACHED.", 13, 0
neo_debug_msg_x86_unsupported: db "[NEOGS] X86 UNSUPPORTED OPCODE.", 13, 0
neo_debug_msg_x86_bounds:      db "[NEOGS] X86 IP OUT OF RANGE.", 13, 0
