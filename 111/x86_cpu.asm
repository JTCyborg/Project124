; =========================================================================
; PERFECT COMMANDER 110 — ИЗОЛИРОВАННЫЙ ЦИКЛ CPU И ДЕКОДЕР ОПКOДОВ x86
; МОДУЛЬ: src/x86_cpu.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

X86_CPU_Cycle:
        ; АППАРАТНАЯ ИЗОЛЯЦИЯ СТЕКА: Сберегаем системный SP коммандера Хоста
        LD      (X86_Saved_Host_SP), SP
        
        ; Намертво переносим стек Z80 в безопасный локальный ОЗУ-буфер эмулятора
        LD      SP, X86_CPU_STACK_TOP

.MainLoop:
        ; Проверяем флаг останова процессора гостя на входе в цикл
        LD      A, (X86_CPU_State)
        OR      A
        JP      NZ, .ExitEmulator       

        ; ТОТАЛЬНАЯ ИЗОЛЯЦИЯ КОНТЕКСТA ДЕШИФРАТОРА
        PUSH    IX
        PUSH    IY
        CALL    Debug_PrintCPUState     
        POP     IY
        POP     IX

        ; --- АТОМАРНЫЙ КОНВЕЙЕР FETCH ОПКOДА ---
        PUSH    IX
        PUSH    IY
        CALL    X86_Fetch_Byte          
        POP     IY
        POP     IX
        LD      (X86_Current_Opcode), A

        PUSH    IX
        PUSH    IY
        CALL    X86_Dispatch_Opcode
        POP     IY
        POP     IX

        ; Гарантируем сброс upper window на базовую системную страницу хоста 0 (#10)
        XOR     A
        LD      BC, #EFF7
        OUT     (C), A
        LD      A, #10
        LD      BC, #7FFD
        OUT     (C), A

        ; Проверяем состояние CPU сразу после выполнения команды.
        LD      A, (X86_CPU_State)
        OR      A
        JP      Z, .MainLoop            
        CP      1
        JR      Z, .CheckHaltOpcode
        LD      A, (X86_Current_Opcode)
        LD      (X86_Fault_Opcode), A
        JR      .ExitEmulator
.CheckHaltOpcode:
        LD      A, (X86_Current_Opcode)
        CP      $F4
        JR      Z, .ExitEmulator
        LD      (X86_Fault_Opcode), A
        LD      A, 2
        LD      (X86_CPU_State), A

.ExitEmulator:
        ; ПРИНУДИТЕЛЬНО ВОССТАНАВЛИВАЕМ СИСТЕМНЫЙ СТЭК ХОСТА КОММАНДЕРА
        LD      SP, (X86_Saved_Host_SP)

        ; Гарантируем удержание базовой страницы коммандера (Страница 0) при возврате
        LD      A, #10
        LD      BC, #7FFD                
        OUT     (C), A
        RET

.CallIX:
        JP      (IX)                    

X86_Dispatch_Opcode:
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        LD      DE, X86_Jump_Table
        ADD     HL, DE
        LD      E, (HL)
        INC     HL
        LD      D, (HL)
        PUSH    DE
        POP     IX
        JP      (IX)

; --- ОБРАБОТЧИКИ ОПКОДОВ ЗAГРУЗКИ КОНСТАНТ ---
Op_MOV_AX_Imm16:
        CALL    X86_Fetch_Byte          
        LD      C, A
        CALL    X86_Fetch_Byte          
        LD      B, A
        LD      (X86_REG_AX), BC
        RET                     

Op_MOV_CX_Imm16:
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      (X86_REG_CX), BC
        RET  

Op_MOV_SI_Imm16:
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      (X86_REG_SI), BC        
        RET                     

Op_MOV_DI_Imm16:
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      (X86_REG_DI), BC        
        RET                     

Op_MOV_DX_Imm16:
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      (X86_REG_DX), BC     
        RET

Op_MOV_SP_Imm16:
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      (X86_REG_SP), BC
        RET

Op_MOV_BP_Imm16:
        CALL    X86_Fetch_Byte
        LD      C, A
        CALL    X86_Fetch_Byte
        LD      B, A
        LD      (X86_REG_BP), BC
        RET

Op_CBW:
        LD      A, (X86_REG_AX)
        RLCA
        SBC     A, A
        LD      (X86_REG_AX + 1), A
        RET

Op_CWD:
        LD      A, (X86_REG_AX + 1)
        RLCA
        SBC     A, A
        LD      (X86_REG_DX), A
        LD      (X86_REG_DX + 1), A
        RET
                   
Op_NOP:
        RET                     

; --- ОБРАБОТЧИК ИНСТРУКЦИИ HLT (Опкод $F4) ---
Op_HLT:
        PUSH    AF
        LD      A, 1
        LD      (X86_CPU_State), A      
        POP     AF
        RET

; --- АТОМАРНЫЙ ОБРАБОТЧИК ПРЕРЫВАНИЙ x86 (Опкод $CD) ---
Op_INT_Imm8:
        CALL    X86_Fetch_Byte          
        LD      (X86_INT_VECTOR), A     

        LD      HL, (X86_REG_FLAGS)
        LD      (X86_Bypass_Saved_FLAGS), HL
        
        LD      HL, (X86_REG_CS)
        LD      (X86_Bypass_Saved_CS), HL
        
        LD      HL, (X86_REG_IP)
        LD      (X86_Bypass_Saved_IP), HL

        LD      A, (X86_INT_VECTOR)
        CP      $13
        JP      Z, X86_INT13_HDD_Gateway
        CP      $21
        JR      NZ, .ForwardToDispatcher
        LD      HL, (X86_REG_CS)
        LD      (X86_REG_DS), HL

.ForwardToDispatcher:
        JP      Op_INT_21h_Dispatcher

Op_Unimplemented:
        LD      A, (X86_Current_Opcode)
        LD      (X86_Fault_Opcode), A
        LD      A, 2
        LD      (X86_CPU_State), A   
        RET

Op_CLC:
        JP      X86_Op_CLC

Op_STC:
        JP      X86_Op_STC

Op_CMC:
        JP      X86_Op_CMC

Op_CLD:
        JP      X86_Op_CLD

Op_STD:
        JP      X86_Op_STD

; --- ДИССПЕТЧЕРЫ ДВУХБАЙТОВЫХ ГРУПП ОПКOДОВ ModR/M ---
Op_Group_D1:
        CALL    X86_Fetch_Byte          
        CP      $E0
        JP      Z, Op_SHL_AX_1       
        CP      $E8
        JP      Z, Op_SHR_AX_1       
        CP      $F8
        JP      Z, Op_SAR_AX_1       
        LD      A, 1
        LD      (X86_CPU_State), A   
        RET

Op_Group_89:
        CALL    X86_Fetch_Byte          
        CP      $C2
        JP      Z, Op_MOV_DX_AX    
        CP      $D1
        JP      Z, Op_MOV_CX_DX    
        RET

Op_Group_8B:
        CALL    X86_Fetch_Byte          
        CP      $C1
        JP      Z, Op_MOV_AX_CX    
        RET

Op_Group_02:
        CALL    X86_Fetch_Byte          
        CP      $C1
        JP      Z, Op_ADD_AL_CL      
        LD      A, 1
        LD      (X86_CPU_State), A   
        RET

Op_Group_2A:
        CALL    X86_Fetch_Byte          
        CP      $E5
        JP      Z, Op_SUB_AH_CH      
        LD      A, 1
        LD      (X86_CPU_State), A   
        RET

Op_Group_FE:
        CALL    X86_Fetch_Byte          
        CP      $C0
        JP      Z, Op_INC_AL         
        CP      $C1
        JP      Z, Op_INC_CL            ; ИСПРАВЛЕНО: Удалена мусорная склеенная команда JPCD
        CP      $C4
        JP      Z, Op_DEC_AH         
        LD      A, 1
        LD      (X86_CPU_State), A   
        RET

Op_Group_22:
        CALL    X86_Fetch_Byte
        CP      $C1
        JP      Z, Op_XOR_AL_CL         
        LD      A, 1
        LD      (X86_CPU_State), A
        RET

Op_Group_0A:
        CALL    X86_Fetch_Byte
        CP      $E5
        JP      Z, Op_OR_AH_CH
        LD      A, 1
        LD      (X86_CPU_State), A
        RET

Op_Group_32:
        CALL    X86_Fetch_Byte
        CP      $C1
        JP      Z, Op_XOR_AL_CL
        LD      A, 1
        LD      (X86_CPU_State), A
        RET

Op_Group_F6:
        CALL    X86_Op_Group_F6
        RET

Op_Group_F7:
        CALL    X86_Op_Group_F7
        RET

Op_Group_81:
        CALL    X86_Fetch_Byte
        CP      $E9
        JP      Z, Op_SUB_CX_Imm16   
        LD      A, 1
        LD      (X86_CPU_State), A   
        RET

Op_Group_8E:
        CALL    X86_Fetch_Byte
        CP      $D8
        JR      Z, .Mov_DS_AX        
        CP      $C0
        JR      Z, .Mov_ES_AX        
        CP      $D0
        JR      Z, .Mov_SS_AX
        LD      A, 1
        LD      (X86_CPU_State), A   
        RET

.Mov_DS_AX:
        LD      HL, (X86_REG_AX)
        LD      (X86_REG_DS), HL     
        RET

.Mov_ES_AX:
        LD      HL, (X86_REG_AX)
        LD      (X86_REG_ES), HL
        RET

.Mov_SS_AX:
        LD      HL, (X86_REG_AX)
        LD      (X86_REG_SS), HL
        RET

        ALIGN   2
        DS      128, 0
X86_CPU_STACK_TOP:
