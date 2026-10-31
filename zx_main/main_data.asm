; =========================================================================
; FILE: zx_main/main_data.asm
; PROJECT 124 — global state and messages
; =========================================================================

Console_X::         DB 0
Console_Y::         DB 0
OLD_SP::            DW 0
APP_SP_BACKUP::     DW 0
Variable_Backup:    DW 0
                    DW 0
                    DW 0
                    DB 0

; Public result copy retained for other application modules.
X86_RESULT_AX::     DW 0

; Port #EF diagnostic messages.
msg_stage1:    DEFB "[CORE] Stage 1: Clock RTC K512VI1 checked and synced successfully.",13,0
msg_stage2:    DEFB "[CORE] Stage 2: Bootstrapping custom NeoGS Z80 firmware through GS105a ROM loader...",13,0
msg_stage3_ok: DEFB "[GUI] Stage 3: Custom fonts linked. Two-window application workspace rendered.",13,0
msg_stage4:    DEFB "[CORE] Stage 4: Execution window stabilized. Bypassing interactive loop.",13,0
msg_stage_all_complete: DEFB "[HALT] NeoGS firmware loaded; diagnostics completed. System suspended.",13,0

; Screen log strings.
msg_log_screen_ready: DEFB "[SYS_START] PERFECT MANAGER 124 DUAL-CORE NODE ONLINE.",0
msg_log_sp_prefix:    DEFB "[SYS_INFO] ORIGINAL TR-DOS SYSTEM STACK POINTER WAS SAVED AT: #",0
msg_log_exec_x86:     DEFB "[EXECUTE] AUTOMATIC LINEAR TRANSFER INITIATED...",0

; Eight-character TR-DOS filename, extension supplied separately as 'C'.
neogs_firmware_filename: DEFB "neoprog "
