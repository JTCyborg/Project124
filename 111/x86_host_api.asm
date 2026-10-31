; =========================================================================
; PERFECT COMMANDER 111 — СЕРВИСНЫЙ МОДУЛЬ ХОСТА ДЛЯ ВИРТУАЛЬНОЙ МАШИНЫ x86
; МОДУЛЬ: src/x86_host_api.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

InitX86CPU:
        PUSH    HL
        XOR     A
        LD      (X86_CPU_State), A
        LD      (X86_Current_Opcode), A
        LD      (X86_Fault_Opcode), A
        
        LD      HL, 0
        LD      (X86_REG_AX), HL
        LD      (X86_REG_BX), HL
        LD      (X86_REG_CX), HL
        LD      (X86_REG_DX), HL
        LD      (X86_REG_SI), HL
        LD      (X86_REG_DI), HL
        LD      (X86_REG_BP), HL
        LD      (X86_REG_FLAGS), HL  

        LD      HL, $FFFE            
        LD      (X86_REG_SP), HL

        LD      HL, $0000
        LD      (X86_REG_CS), HL     
        LD      (X86_REG_DS), HL     
        LD      (X86_REG_SS), HL     
        LD      (X86_REG_ES), HL     

        LD      HL, $0100
        LD      (X86_REG_IP), HL     
        XOR     A
        LD      (X86_Segment_Override), A
        POP     HL
        RET

InitAndRunX86:
        CALL    LoadX86Program          
        CALL    InitX86CPU              
        CALL    X86_CPU_Cycle           
        RET                             

; --- АППАРАТНО ЗАЩИЩЕННЫЙ ЗАГРУЗЧИК БИНАРНОГО КОДА ГОСТЯ ЧЕРЕЗ АТОМАРНЫЙ ШЛЮЗ ---
LoadX86Program:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        ; --- АВТОНОМНЫЙ ПЕРЕХВАТ ДЛЯ НОВОГО ТЕСТ-БАНКА HDD (ПРОЕКТ 111) ---
        ; Из-за "DEC A" в main.asm человеческий тест 99 имеет внутренний индекс 98
        LD      A, (Current_Test_ID)    
        CP      98                      ; Проверяем триггер дискового тест-банка
        JP      NC, .LoadFromHDDBank    ; Уходим на внешнюю выборку

        ; 1. ВЫЧИСЛЯЕМ АДРЕСА И ДЛИНЫ СТРОГО ПРИ СТАБИЛЬНОЙ СТРАНИЦЕ ХОСТА
        CP      90                      ; Индексы 90+ принадлежат четвертому банку
        JP      NC, .LoadFromBank4
        CP      82                      ; Индексы 82+ принадлежат третьему банку
        JP      NC, .LoadFromBank3
        CP      41                      ; Вышли за границы первого банка (0..40)?
        JR      NC, .LoadFromBank2      

        ; --- ОБРАБОТКА БАНКА 1 ---
        LD      L, A
        LD      H, 0
        ADD     HL, HL                  
        LD      DE, X86_Test_Table
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        PUSH    DE                      

        LD      A, (Current_Test_ID)
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_Test_Lengths
        ADD     HL, DE
        LD      C, (HL)
        INC     HL
        LD      B, (HL)                 
        JP      .DirectInjectDispatcher ; ФИКС: изменен JR на дальний JP

.LoadFromBank2:
        ; --- ОБРАБОТКА БАНКА 2 ---
        SUB     41                      
        LD      L, A
        LD      H, 0
        ADD     HL, HL                  
        LD      DE, X86_Test2_Table
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        PUSH    DE                      

        LD      A, (Current_Test_ID)
        SUB     41                      
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_Test2_Lengths
        ADD     HL, DE
        LD      C, (HL)
        INC     HL
        LD      B, (HL)                 

        JP      .DirectInjectDispatcher ; ФИКС: изменен JR на дальний JP

.LoadFromBank3:
        ; --- ОБРАБОТКА БАНКА 3 (ТЕСТЫ 83+) ---
        LD      A, (Current_Test_ID)
        SUB     82
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_Test3_Table
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        PUSH    DE

        LD      A, (Current_Test_ID)
        SUB     82
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_Test3_Lengths
        ADD     HL, DE
        LD      C, (HL)
        INC     HL
        LD      B, (HL)

        JP      .DirectInjectDispatcher ; ФИКС: изменен JR на дальний JP

.LoadFromBank4:
        ; --- ОБРАБОТКА БАНКА 4 (ТЕСТЫ 91+) ---
        LD      A, (Current_Test_ID)
        SUB     90
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_Test4_Table
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        PUSH    DE

        LD      A, (Current_Test_ID)
        SUB     90
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_Test4_Lengths
        ADD     HL, DE
        LD      C, (HL)
        INC     HL
        LD      B, (HL)
        JP      .DirectInjectDispatcher ; ФИКС: изменен JR на дальний JP

.LoadFromHDDBank:
        ; --- ОБРАБОТКА НОВОГО АВТОНОМНОГО БАНКА HDD ТЕСТОВ (99+) ---
        LD      A, (Current_Test_ID)
        SUB     98                      ; Вычисляем индекс в новой HDD таблице (98 -> 0)
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_HDD_Test_Table  ; Читаем указатель из новой внешней таблицы
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        PUSH    DE

        LD      A, (Current_Test_ID)
        SUB     98
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_HDD_Test_Lengths ; Читаем длину из новой внешней таблицы
        ADD     HL, DE
        LD      C, (HL)
        INC     HL
        LD      B, (HL)
        ; Проваливаемся в родной диспетчер инъекции

.DirectInjectDispatcher:
        POP     HL                      ; HL = Исходный адрес теста в ОЗУ хоста
        LD      DE, $C100               ; DE = Начало сегмента кода гостя x86

        LD      A, B
        OR      C
        JR      Z, .LoadProgramEnd      

.ByteInjectionLoop:
        LD      A, (HL)
        LD      (X86_Host_Temp_Injection_Byte), A

        PUSH    HL
        PUSH    BC

        LD      A, %00000010            ; Гостевая физическая RAM начинается со страницы 16
        LD      BC, #EFF7
        OUT     (C), A
        
        LD      A, #10                  
        LD      BC, #7FFD
        OUT     (C), A

        LD      A, (X86_Host_Temp_Injection_Byte)
        LD      (DE), A

        XOR     A
        LD      BC, #EFF7
        OUT     (C), A

        LD      A, #10
        LD      BC, #7FFD
        OUT     (C), A

        POP     BC
        POP     HL
        INC     HL
        INC     DE
        DEC     BC
        
        LD      A, B
        OR      C
        JR      NZ, .ByteInjectionLoop  

.LoadProgramEnd:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Debug_PrintCPUState:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      A, #10
        LD      BC, #7FFD
        OUT     (C), A

        LD      A, "I"
        CALL    AppendLogChar
        LD      A, "P"
        CALL    AppendLogChar
        LD      A, "="
        CALL    AppendLogChar
        LD      HL, (X86_REG_IP)
        CALL    Log_PrintHEX16          

        LD      A, " "
        CALL    AppendLogChar
        LD      A, "A"
        CALL    AppendLogChar
        LD      A, "X"
        CALL    AppendLogChar
        LD      A, "="
        CALL    AppendLogChar
        LD      HL, (X86_REG_AX)
        CALL    Log_PrintHEX16

        LD      A, " "
        CALL    AppendLogChar
        LD      A, "C"
        CALL    AppendLogChar
        LD      A, "X"
        CALL    AppendLogChar
        LD      A, "="
        CALL    AppendLogChar
        LD      HL, (X86_REG_CX)
        CALL    Log_PrintHEX16

        LD      A, " "
        CALL    AppendLogChar
        LD      A, "F"
        CALL    AppendLogChar
        LD      A, "L"
        CALL    AppendLogChar
        LD      A, "="
        CALL    AppendLogChar
        LD      HL, (X86_REG_FLAGS)
        CALL    Log_PrintHEX16

        LD      A, #0D
        CALL    AppendLogChar
        LD      A, #0A
        CALL    AppendLogChar

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

Log_PrintHEX16:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        PUSH    HL                      
        LD      A, H
        SRL     A
        SRL     A
        SRL     A
        SRL     A                       
        CALL    ConvertNibble_Fixed     

        POP     HL                      
        PUSH    HL                      
        LD      A, H                    
        CALL    ConvertNibble_Fixed     

        POP     HL                      
        PUSH    HL                      
        LD      A, L
        SRL     A
        SRL     A
        SRL     A
        SRL     A                       
        CALL    ConvertNibble_Fixed     

        POP     HL                      
        LD      A, L                    
        CALL    ConvertNibble_Fixed     

        POP     HL                      
        POP     DE
        POP     BC
        POP     AF
        RET

ConvertNibble_Fixed:
        AND     %00001111               
        CP      10
        JR      C, .Digit               
        ADD     A, "A" - 10             
        JR      .Print                  
.Digit:
        ADD     A, "0"                  
.Print:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        CALL    AppendLogChar           
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

X86_Host_Temp_Injection_Byte:   DB 0
