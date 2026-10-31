; =========================================================================
; FILE: src/system/sys_kbd.asm
; =========================================================================
; PERFECT COMMANDER 124 — ПОДCИCТЕМА КЛAВИAТУРЫ И АППАРАТНЫЙ ПЕРЕХВАТ ENTER
; =========================================================================

MAIN_INTERFACE_LOOP::
        ; --- РАБОЧИЙ ИНТЕРАКТИВНЫЙ ЦИКЛ НАВИГАЦИИ ПО ФАЙЛАМ ПАНЕЛЕЙ ---
        
        ; 1. Опрос клавиши ENTER (Полуряд BREAK..ENTER, порт #FFF7)
        LD      BC, #FFF7               
        IN      A, (C)
        CPL                             
        AND     %00000001               ; Изолируем бит кнопки ENTER
        JP      NZ, Handle_Enter_Gate   ; ПЕРЕХВАТ: прыгаем на шлюз анализа имени файла

        ; 2. Опрос клавиши SPACE (Выход в Бейсик)
        LD      BC, #7FFE               
        IN      A, (C)
        CPL                             
        AND     %00000001               ; Изолируем бит кнопки SPACE
        JP      NZ, Exit_To_Basic_Log   ; Если нажали SPACE — выходим в Бейсик через сброс

        ; 3. Опрос навигационных стрелок 'O' (Вверх) и 'L' (Вниз)
        CALL    GetHardwareKey          
        
        CP      1                       
        JP      Z, Move_Up             
        
        CP      2                       
        JP      Z, Move_Down          

        ; Небольшая шинная задержка для стабилизации дребезга контактов
        PUSH    BC                    
        LD      BC, 200                
.bus_delay:
        DEC     BC                     
        LD      A, B                    
        OR      C                     
        JP      NZ, .bus_delay          
        POP     BC                    
        
        JP      MAIN_INTERFACE_LOOP   

; =========================================================================
; ИНТЕЛЛЕКТУАЛЬНЫЙ ШЛЮЗ ОБРАБОТКИ ENTER
; =========================================================================
Handle_Enter_Gate:
        ; Фиксируем нажатие ENTER в порту отладки #EF через макрос
        MACRO_EF_STRING STR_EF_ENTER_DETECTED

        ; Получаем адрес 16-байтного описателя файла в буфере каталога
        CALL    GetSelectedFileDescriptor
        
        ; Защита от пустых/удаленных слотов
        LD      A, (HL)
        OR      A
        JP      Z, MAIN_INTERFACE_LOOP
        CP      1
        JP      Z, MAIN_INTERFACE_LOOP

        ; Проверяем имя файла. Если это "neoprog ", запускаем сквозной IPC-стрим в карту
        PUSH    HL
        PUSH    DE
        PUSH    BC
        LD      DE, task_filename       ; Указатель на строку "neoprog "
        LD      BC, 8                   ; Проверяем ровно 8 символов имени
.check_name_loop:
        LD      A, (DE)
        CP      (HL)
        JR      NZ, .not_neoprog_file   ; Если хоть один символ не совпал — это обычный софт хоста
        INC     HL
        INC     DE
        DEC     BC
        LD      A, B
        OR      C
        JR      NZ, .check_name_loop

        ; ИМЯ СОВПАЛО! Запускаем аппаратный конвейер трансляции в NeoGS
        POP     BC
        POP     DE
        POP     HL                      ; Восстанавливаем регистры

        LD      HL, msg_log_exec_x86
        CALL    LOG_WriteMessageToBuffer  

        ; --- ЗАЩИЩЕННЫЙ КОНТЕКСТ ДЛЯ БЕЗОПАСНОЙ РАБОТЫ С ПЗУ TR-DOS ---
        DI                              
        LD      (APP_SP_BACKUP), SP     
        LD      SP, (OLD_SP)            ; Восстанавливаем оригинальный системный стек TR-DOS
        
        LD      HL, task_filename
        LD      A, 'C'
        CALL    EXECUTE_X86_FILE_STAGE ; Считываем neoprog.C в буфер и выплескиваем в NeoGS с хекс-дампом
        
        LD      SP, (APP_SP_BACKUP)     ; Переносим стек обратно в приложение 124
        EI                              
        
        CALL    WaitKeyRelease_Safe
        JP      MAIN_INTERFACE_LOOP

.not_neoprog_file:
        POP     BC
        POP     DE
        POP     HL                      ; Восстанавливаем указатель на дескриптор
        JP      Execute_Selected_File   ; Уходим на стандартный запуск бинарника Спектрума

; =========================================================================
; ОБРАБОТЧИК ЗАПУСКА СТАНДАРТНОГО СОФТА ХОСТА
; =========================================================================
Execute_Selected_File:
        CALL    LogSelectedFile
        CALL    GetSelectedFileDescriptor
        
        PUSH    HL
        LD      DE, 8
        ADD     HL, DE
        LD      A, (HL)                 
        POP     HL
        
        CP      "C"
        JP      NZ, .error_not_code_file

        PUSH    HL
        LD      DE, 9
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)                 ; DE = Канонический адрес запуска файла хоста
        POP     HL

        MACRO_EF_STRING STR_EF_EXEC_RUN

        CALL    WaitKeyRelease_Safe

        ; --- ПЕРЕДАЧА УПРАВЛЕНИЯ ЗАПУСКАЕМОМУ ФАЙЛУ ХОСТА ---
        LD      SP, (OLD_SP)
        EI                              
        PUSH    DE                      
        RET                             

.error_not_code_file:
        LD      HL, .str_err_type
        CALL    LOG_WriteMessageToBuffer
        CALL    WaitKeyRelease_Safe
        JP      MAIN_INTERFACE_LOOP

; --- Строковые ресурсы ---
.str_err_type: DEFB "[EXEC_ERROR] CAN ONLY EXECUTE BINARY CODE FILES (*.C)", #0D, #0A, 0

; =========================================================================
; ОБРАБОТЧИК ОЖИДАНИЯ И ОТПУСКАНИЯ КЛАВИШИ SPACE С ФИКСИРОВАННЫМ ТРЕЙСОМ
; =========================================================================
Wait_For_Step_Space::
        PUSH    AF: PUSH BC: PUSH DE: PUSH HL

        MACRO_EF_STRING STR_EF_KBD_WAIT

.wait_key_press:
        LD      BC, #7FFE               
        IN      A, (C)
        CPL: AND %00000001: JR Z, .wait_key_press      

        MACRO_EF_STRING STR_EF_KBD_PRESSED

.wait_key_release:
        LD      BC, #7FFE
        IN      A, (C)
        CPL: AND %00000001: JR NZ, .wait_key_release   

        MACRO_EF_STRING STR_EF_KBD_RELEASED

        POP     HL: POP DE: POP BC: POP AF
        RET

; Безопасный выход через аппаратный рестарт ПЗУ
Exit_To_Basic_Log:
        DI
        LD      A, #10
        LD      BC, #7FFD
        OUT     (C), A
        XOR     A
        OUT     (254), A
        
        MACRO_EF_STRING STR_EF_SPACE_DETECTED
        JP      0                             

; Спецификация строк отладочного порта #EF
STR_EF_ENTER_DETECTED:  DEFB "[KEYBOARD] ENTER key press captured. Parsing target node filename...", #0D, #0A, 0
STR_EF_SPACE_DETECTED:  DEFB "[KEYBOARD] SPACE key press captured. Terminating runtime. Swapping bank to ROM 0...", #0D, #0A, 0
STR_EF_KBD_WAIT:        DEFB "[KBD_WAIT_SPACE] SYSTEM PAUSED. PRESS SPACE TO EXECUTE NEXT STEP...", #0D, #0A, 0
STR_EF_KBD_PRESSED:     DEFB "   -> [KEY_SPACE_PRESSED]", #0D, #0A, 0
STR_EF_KBD_RELEASED:    DEFB " -> [KEY_SPACE_RELEASED] -> RESUMING CORE.", #0D, #0A, 0
STR_EF_EXEC_RUN:       DEFB "[EXEC_ENGINE] TRANSFERRING CPU CORE BLOCK CONTROL...", #0D, #0A, 0
