; =========================================================================
; PROJECT 124
; ROOT MODULAR LINKER — DUAL PROCESSOR BUILD
; LINEAR AUTORUN SEQUENCE — FIXED SECTOR LENGTH TRD EXPORT
; =========================================================================

ENABLE_DEBUG_CONSOLE_TEST EQU 0
ENABLE_HARDWARE_DEBUG     EQU 1
ENABLE_TRDOS_DEBUG        EQU 1

        ; --- ВСТРОЕННЫЙ LUA-СКРИПТ АВТОМАТИЧЕСКОГО ДАМПА ПРОЕКТА 124 ---
        LUA
            local out_file = io.open("dump_project_124.txt", "w")
            if out_file then
                out_file:write("; =========================================================================\n")
                out_file:write("; PROJECT 124 DUMP DATA (DOUBLED Z80 INTERFACES)\n")
                out_file:write("; =========================================================================\n\n")

                local files = {
                    "shared/neogs_io.inc",
                    "zx_main/main.asm",
                    "zx_main/main_data.asm",
                    "zx_main/boot_loader.asm",
                    "zx_main/neogs_driver.asm",
                    "zx_main/x86_loader.asm",
                    "zx_main/debug_system.asm",
                    "zx_main/driver_cmos.asm",
                    "zx_main/log_debug.asm",
                    "zx_main/display.asm",
                    "zx_main/bios_console.asm",
                    "zx_main/ui_engine.asm",
                    "zx_main/ui_panels.asm",
                    "zx_main/file_utils.asm",
                    "neogs_sub/main.asm",
                    "neogs_sub/bootstrap.asm",
                    "neogs_sub/x86_interpreter.asm",
                    "neogs_sub/x86_memory.asm",
                    "neogs_sub/bios/bios_core.asm",
                    "neogs_sub/bios/bios_video.asm",
                    "neogs_sub/x86_interrupt.asm",
                    "neogs_sub/x86_real_mode.asm",
                    "neogs_sub/build_firmware.asm"
                }

                for _, fname in ipairs(files) do
                    out_file:write("; =========================================================================\n")
                    out_file:write("; FILE: " .. fname .. "\n")
                    out_file:write("; =========================================================================\n")
                    local in_file = io.open(fname, "r")
                    if in_file then
                        out_file:write(in_file:read("*all"))
                        in_file:close()
                    else
                        out_file:write("; [LINK ERROR: File " .. fname .. " not found]\n")
                    end
                    out_file:write("\n\n")
                end
                out_file:close()
            end
        ENDLUA

        DEVICE ZXSPECTRUM128
        EMPTYTRD "disk_A.trd"

        ; ГЛОБАЛЬНАЯ КОНСТАНТА БЕЗОПАСНОГО БУФЕРА КАТАЛОГА / ДАННЫХ
TRDOS_PANEL_BUFFER EQU #C000

        ; Базовый адрес старта основного кода Spectrum — 24576 ($6000)
        ORG 24576

; Первичный прыжок на старт, прецизионно выровненный на адрес 24585
        jp      Init_Z80_System
        BLOCK   6, 0            

; Сюда прыгает бут-загрузчик из строки 30 по команде RANDOMIZE USR VAL "24585"
Init_Z80_System::
        di

        ; АТОМАРНЫЙ МАРКЕР СТАРТА: Выстреливаем байт #AA (170) напрямую в порт #EF
        ld      a, #AA
        out     (#EF), a

        ld      (OLD_SP), sp    
        ld      sp, $AFFF       ; Переносим стек в безопасную зону проекта 124

        ld      a, #10
        ld      bc, #7FFD
        out     (C), a
        ld      (#5C3B), a

        xor     a
        ld      bc, #EFF7
        out     (C), a          ; Инициализация Pentagon-расширения

        ; Raw startup marker: confirms Init_Z80_System reached its end.
        ld      a, 'I'
        out     (#EF), a
        jp      START_APPLICATION

; Подключение системы отладки и макросов порта #EF
        INCLUDE "debug_system.asm"

START_APPLICATION:
        ; Raw markers bypass timestamp/RTC code so an early hang is visible.
        ld      a, 'C'
        out     (#EF), a

        ; ЭТАП 1 — ЗАПУСК CMOS ЧАСОВ К512ВИ1
        call    CHECK_AND_INIT_CMOS
        ld      a, 'D'
        out     (#EF), a
        ld      a, 'E'
        out     (#EF), a
        MACRO_EF_STRING msg_stage1

        ; ЭТАП 2 — ДВУХСТУПЕНЧАТАЯ ЗАГРУЗКА ПРОШИВКИ NEOGS
        ; GS105a #14 загружает исполняемый bootstrap в RAM $4000;
        ; команда #13 запускает его, после чего он включает RAM-over-ROM,
        ; принимает образ в адрес $0000 и передаёт управление новой прошивке.
        ; The 9 KiB firmware is a separate TR-DOS file, not resident host code.
        MACRO_EF_STRING msg_stage2_file_start
        call    load_neogs_firmware_file
        jr      nc, .firmware_file_loaded
        MACRO_EF_STRING msg_stage2_file_fail
        ld      a, (neo_fw_file_error)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 HL
        MACRO_EF_CHAR 13
        di
.firmware_file_halt:
        halt
        jr      .firmware_file_halt

.firmware_file_loaded:
        MACRO_EF_STRING msg_stage2_file_ok
        ld      hl, #C000
        ld      de, neogs_binary_end - neogs_binary_start
        call    upload_firmware
        jr      c, .firmware_upload_failed
        MACRO_EF_STRING msg_stage2
        jp      .firmware_upload_done

.firmware_upload_failed:
        MACRO_EF_STRING msg_stage2_fail
        MACRO_EF_STRING msg_stage2_sent
        ld      hl, (neo_fw_bytes_sent)
        MACRO_EF_HEX16 HL
        MACRO_EF_CHAR 13
        MACRO_EF_STRING msg_stage2_initial
        ld      a, (neo_fw_initial_status)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 HL
        MACRO_EF_CHAR 13
        MACRO_EF_STRING msg_stage2_status
        ld      a, (neo_fw_last_status)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 HL
        MACRO_EF_CHAR 13
        MACRO_EF_STRING msg_stage2_phase
        ld      a, (neo_fw_timeout_phase)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 HL
        MACRO_EF_CHAR 13
        MACRO_EF_STRING msg_stage2_rx
        ld      a, (neo_fw_last_rx_byte)
        ld      l, a
        ld      h, 0
        MACRO_EF_HEX16 HL
        MACRO_EF_CHAR 13
        MACRO_EF_STRING msg_stage2_bootstrap
        ld      hl, (neo_fw_bootstrap_address)
        MACRO_EF_HEX16 HL
        MACRO_EF_CHAR 13
        di
.firmware_upload_halt:
        halt
        jr      .firmware_upload_halt

.firmware_upload_done:

        ; ЭТАП 3 — ИНИЦИАЛИЗАЦИЯ И ОТРИСОВКА ИНТЕРФЕЙСА ОКОН И ДВУХ ШРИФТОВ
        call    INIT_PROGRAM_INTERFACE

        MACRO_EF_STRING msg_stage3_ok

        ; ЭТАП 4 — ВЫВОД СТАРТОВОГО ОТЧЕТА В НИЖНЕЕ ОКНО ЛОГОВ COMMANDER
        ld      hl, msg_log_screen_ready
        call    LOG_WriteMessageToBuffer  

        ld      hl, msg_log_sp_prefix
        call    LOG_WriteMessageToBuffer  
        ld      hl, (OLD_SP)
        MACRO_EF_HEX16  hl
        MACRO_EF_CHAR   13
        MACRO_EF_STRING msg_stage4
        call    BIOS_DebugConsole_Init

        ; ЭТАП 5 — АВТОМАТИЧЕСКИЙ ЛИНЕЙНЫЙ ПЕРЕХОД К ЗАГРУЗКЕ И IPC ТРАНСЛЯЦИИ ЗАДАЧИ
        ld      hl, task_filename
        ld      a, 'C'
        
        ; ВАЖНО: не переключаемся на старый TR-DOS SP (#Cxxx).
        ; Буфер чтения начинается с #C000 и перезаписывает эту область.
        ; Stage 5 сам временно переносит рабочий стек на #BFFF, а этот
        ; CALL остаётся на безопасном прикладном стеке (#AFFF).
        di
        call    EXECUTE_X86_FILE_STAGE
        ei
        jr      c, .x86_stage_failed

        ; Финальная точка останова ядра после завершения всех этапов
.core_halt:
        MACRO_EF_STRING msg_stage_all_complete
        di
        halt
        jr      .core_halt

; Ошибка выполнения этапа загрузки/запуска x86-задачи.
.x86_stage_failed:
        MACRO_EF_STRING msg_stage5_fail
        di
.x86_stage_failed_halt:
        halt
        jr      .x86_stage_failed_halt

msg_stage5_fail:
        DEFB "[CORE] ERROR: x86 task pipeline failed; startup halted.", 13, 0

; Ошибка загрузки прошивки NeoGS. Не продолжаем работу с неподтвержденным ядром.
msg_stage2_fail:
        DEFB "[CORE] ERROR: NeoGS ROM bootstrap / firmware handshake failed.", 13, 0
msg_stage2_sent:
        DEFB "[FW] DATA BYTES SENT = ", 0
msg_stage2_initial:
        DEFB "[FW] INITIAL GSSTAT #BB = ", 0
msg_stage2_status:
        DEFB "[FW] LAST GSSTAT #BB = ", 0
msg_stage2_phase:
        DEFB "[FW] BOOT PHASE (1=#F4,2=#20,3=#14,4=DATA,5=#13,6=BOOT,7=LEN,8=FW,9=READY) = ", 0
msg_stage2_rx:
        DEFB "[FW] LAST RX BYTE = ", 0
msg_stage2_bootstrap:
        DEFB "[FW] BOOTSTRAP ADDRESS = ", 0
msg_stage2_file_start:
        DEFB "[FW] Loading neogs.C from TR-DOS into #C000...", 13, 0
msg_stage2_file_ok:
        DEFB "[FW] neogs.C verified and loaded into #C000.", 13, 0
msg_stage2_file_fail:
        DEFB "[FW] ERROR: neogs.C missing, corrupt or unreadable; code=#", 0

; =========================================================================
; СТРОГАЯ ПОСЛЕДОВАТЕЛЬНАЯ СБОРКА ИЗОЛИРОВАННЫХ МОДУЛЕЙ ИНТЕРФЕЙСА ХОСТА
; =========================================================================
        INCLUDE "main_data.asm"     
        INCLUDE "driver_cmos.asm"   
        INCLUDE "neogs_driver.asm"  
        INCLUDE "x86_loader.asm"    
        INCLUDE "log_debug.asm"     
        
        INCLUDE "display.asm"       ; Модуль низкоуровневого вывода знакомест
        INCLUDE "ui_engine.asm"     ; Модуль прошивки шрифтов и скроллера
        INCLUDE "bios_console.asm"  ; 42-column 6x8 BIOS debug console
        INCLUDE "ui_panels.asm"     ; Модуль высокоуровневых панелей Commander
        INCLUDE "file_utils.asm"    ; Модуль живой работы с диском TR-DOS

; Keep the small first-stage bootstrap inside the resident host image.
; The large firmware is stored as a separate TR-DOS CODE file (neogs.C).
        PAGE    0
neogs_bootstrap_start:
        INCBIN "neogs_bootstrap.bin"
neogs_bootstrap_end:

ProgramEnd:
        ; Keep at least 2 KiB between the loaded program and the application
        ; stack growing down from #AFFF. The TR-DOS buffer starts at #C000.
        ASSERT ProgramEnd <= #A800

; Assemble the firmware payload in RAM bank 1 only as SAVETRD source data.
; The host TR-DOS reader loads neogs.C into bank 0 at #C000 during startup.
        PAGE    1
        ORG     #C000
neogs_binary_start:
        INCBIN "neogs_code.bin"
neogs_binary_end:

; Return to bank 0 and place the BASIC boot program at #E000.
        PAGE    0
        ORG     #E000
        INCLUDE "boot_loader.asm"

; NeoGS firmware is built as a separate binary by neogs_sub/build_firmware.asm.

; =========================================================================
; СЕКТОР ФИНАЛЬНОГО ОКОНЧАТЕЛЬНОГО ЭКСПОРТА НА ДИСК
; =========================================================================
        PAGE    0                       ; Возвращаем базовый нулевой банк памяти хоста

        ; Синхронный экспорт бинарных блоков в образ TRD
        SAVETRD "disk_A.trd", "proj124.C", 24576, ProgramEnd - 24576
        SAVETRD "disk_A.trd", "boot.B", BASIC_START, BASIC_END - BASIC_START
        ; Firmware is a separate TR-DOS file loaded by the host sector reader to #C000.
        PAGE    1
        SAVETRD "disk_A.trd", "neogs.C", neogs_binary_start, neogs_binary_end - neogs_binary_start
        PAGE    0
        ; Диагностический x86 payload для проверки TR-DOS -> DMA -> interpreter.
        ; Это тест из 6 байт, а не полноценное x86-ядро/операционная система.
        SAVETRD "disk_A.trd", "neoprog.C", x86_diag_program, x86_diag_program_end - x86_diag_program


; =========================================================================
