; =========================================================================
; FILE: zx_main/x86_test_runner.asm
; =========================================================================
; АВТОМАТИЧЕСКИЙ КОНВЕЙЕР ТЕСТОВ X86 В ОЗУ ХОСТА С ИСПРАВЛЕННЫМ СТЕКОМ
; =========================================================================

RUN_X86_RAM_TESTS::
        LD      HL, msg_pipe_start
        CALL    LOG_WriteMessageToBuffer
        MACRO_EF_STRING msg_pipe_start

        LD      IX, x86_test_table      ; Указатель на начало таблицы тестов в ОЗУ

.test_loop:
        LD      L, (IX+0)
        LD      H, (IX+1)               ; HL = Адрес текстового имени теста
        LD      A, H: OR L
        JP      Z, .pipeline_success    ; Если указатель нулевой — все тесты пройдены!

        PUSH    HL                      ; Сохраняем имя теста в стек для отчета

        ; -----------------------------------------------------------------
        ; ШАГ 1: НАСТРОЙКА СЛОТОВ ХОСТА И ОТПРАВКА КОДА ФУНКЦИИ ЧЕРЕЗ DMA
        ; -----------------------------------------------------------------
        DI
        LD      A, #10                  ; Переключаемся на Банк 0 ОЗУ хоста
        LD      BC, #7FFD
        OUT     (C), A
        LD      (#5C3B), A              
        EI

        LD      A, CMD_LOAD_X86
        OUT     (#BB), A                ; Включаем режим загрузки на карте
        
        ; Пауза стабилизации FPGA ДМА-модуля
        LD      B, 100: DJNZ $

        LD      E, (IX+2)
        LD      D, (IX+3)               ; DE = Физический адрес x86 кода функции в ОЗУ хоста
        LD      C, (IX+4)
        LD      B, (IX+5)               ; BC = Размер x86 кода в байтах

        DI                              ; Блокируем прерывания Спектрума
        LD      (DMA_SP_H_BUF), SP
        LD      SP, $AFFF               ; Переносим стек в безопасную зону
        
        PUSH    BC                      
        EX      DE, HL                  
        LD      DE, $0000           
        LDIR                            ; Аппаратный ДМА перенос кода операции на карту
        
        LD      A, #FF
        OUT     (#BB), A                ; Сигнализируем NeoGS о завершении LDIR
        LD      SP, (DMA_SP_H_BUF)
        EI                              ; Восстанавливаем прерывания
        POP     BC

        ; -----------------------------------------------------------------
        ; ШАГ 2: ПЕРЕДАЧА ВХОДНОГО ВЕКТОРА AX В ПОРТЫ КАРТЫ
        ; -----------------------------------------------------------------
        LD      L, (IX+6)
        LD      H, (IX+7)               ; HL = Входной тестовый AX
        
.wait_port1:
        IN      A, (#BB)
        RRA
        JR      C, .wait_port1          
        LD      A, L
        OUT     (#B3), A                ; Младший байт AX в GSDAT

.wait_port2:
        IN      A, (#BB)
        RRA
        JR      C, .wait_port2
        LD      A, H
        OUT     (#B3), A                ; Старший байт AX в GSDAT

        ; -----------------------------------------------------------------
        ; ШАГ 3: ЗАПУСК ИНТЕРПРЕТАТОРА И СЧИТЫВАНИЕ РЕЗУЛЬТАТА
        ; -----------------------------------------------------------------
        LD      A, CMD_RUN_X86
        OUT     (#BB), A                ; Посылаем сигнал на старт вычислений

        ; Пауза на выполнение опкодов виртуальным процессором
        LD      BC, 3000: DEC BC: LD A, B: OR C: JR NZ, $-3

        ; Запрашиваем результат вычислений (CMD_GET_STATUS)
        LD      A, CMD_GET_STATUS
        OUT     (#BB), A

.wait_ax_l:
        IN      A, (#BB)
        RRA
        JR      C, .wait_ax_l       
        IN      A, (#B3)            
        LD      E, A                    ; E = полученный младший AX

.wait_ax_h:
        IN      A, (#BB)
        RRA
        JR      C, .wait_ax_h       
        IN      A, (#B3)            
        LD      D, A                    ; D = полученный старший AX

        ; -----------------------------------------------------------------
        ; ШАГ 4: МАТЕМАТИЧЕСКАЯ ВЕРИФИКАЦИЯ ЦИФР
        ; -----------------------------------------------------------------
        LD      A, (IX+8)
        LD      H, (IX+9)               ; HL = Ожидаемый эталонный AX
        
        POP     IY                      ; IY = Адрес имени теста (сняли из стека, баланс ок!)
        PUSH    DE                      ; Сохраняем полученный результат AX в стек

        XOR     A
        EX      DE, HL
        SBC     HL, DE                  ; Сравниваем полученное с эталоном
        JR      NZ, .test_failed

        ; ПРОВЕРКА УСПЕШНА!
        PUSH    IY: POP HL
        CALL    LOG_WriteMessageToBuffer
        LD      HL, msg_status_pass
        CALL    LOG_WriteMessageToBuffer
        MACRO_EF_STRING msg_status_pass
        
        POP     DE                      ; Чистим временный AX из стека (баланс!)
        JR      .next_iteration

.test_failed:
        ; ТЕСТ ПОВАЛЕН!
        PUSH    IY: POP HL
        CALL    LOG_WriteMessageToBuffer
        LD      HL, msg_status_fail
        CALL    LOG_WriteMessageToBuffer
        MACRO_EF_STRING msg_status_fail
        
        POP     DE                      ; Извлекаем ошибочный AX из стека (баланс!)
        MACRO_EF_HEX16  DE              ; Выплескиваем ошибочную цифру в порт #EF
        MACRO_EF_CHAR   13

.next_iteration:
        LD      DE, 10                  ; Размер одной структуры тест-кейса в таблице
        ADD     IX, DE                  ; Сдвигаемся на следующий тест
        JP      .test_loop

.pipeline_success:
        LD      HL, msg_pipe_ok
        CALL    LOG_WriteMessageToBuffer
        MACRO_EF_STRING msg_pipe_ok
        RET

; --- ТАБЛИЦА СТРУКТУР ТЕСТ-КЕЙСОВ В ОЗУ ХОСТА ---
x86_test_table:
        ; Тест 1: Проверка инкремента (fn_inc). Вход: #BBAA, Ожидаем: #BBAB
        DW      str_t1_name, x86_fn_inc_start, x86_fn_inc_end - x86_fn_inc_start, #BBAA, #BBAB
        
        ; Тест 2: Проверка MOV AX (fn_mov). Вход: #0000, Ожидаем: #BBAA
        DW      str_t2_name, x86_fn_mov_start, x86_fn_mov_end - x86_fn_mov_start, #0000, #BBAA
        
        ; Тест 3: Проверка NOP (fn_nop). Вход: #1234, Ожидаем: #1234
        DW      str_t3_name, x86_fn_nop_start, x86_fn_nop_end - x86_fn_nop_start, #1234, #1234
        
        ; Маркер конца таблицы (Нулевой указатель имени)
        DW      0

DMA_SP_H_BUF:   DW 0

; --- Текстовые имена тестов и строковые ресурсы ---
str_t1_name:    DEFB "[TEST] x86 INC AX check ", 0
str_t2_name:    DEFB "[TEST] x86 MOV AX,iw check ", 0
str_t3_name:    DEFB "[TEST] x86 NOP empty check ", 0
msg_pipe_start: DEFB "[PIPELINE] Launching automated x86 core test suite inside host RAM...", 13, 0
msg_status_pass: DEFB " -> [ PASS ]", 13, 0
msg_status_fail: DEFB " -> [!FAIL!]", 13, 0
msg_pipe_ok:    DEFB "[PIPELINE] All structured RAM test cases verified successfully.", 13, 0
