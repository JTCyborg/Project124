; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ РАСШИРЕННОГО АЛУ И ЛОГИКИ СРАВНЕНИЯ TEST
; МОДУЛЬ: src/x86_alu_ext.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ОБРАБОТЧИК ОПКOДА $A8: TEST AL, Imm8 ---
Op_TEST_AL_Imm8:
        CALL    X86_Fetch_Byte          
        LD      E, A
        LD      A, (X86_REG_AX)         
        AND     E                       
        
        PUSH    AF
        POP     BC                      
        CALL    Update_X86_Flags8       
        
        LD      HL, (X86_REG_FLAGS)
        RES     0, L                    
        LD      A, H
        RES     3, A                    
        LD      H, A
        LD      (X86_REG_FLAGS), HL
        RET

; --- ДИССПЕТЧЕР ДВУХБАЙТОВОЙ ГРУППЫ ОПКOДОВ $84 (TEST Reg8, Reg8) ---
Op_Group_84:
        CALL    X86_Fetch_Byte          
        CP      $E5                     
        JR      Z, .Do_TEST_AH_CH
        
        LD      A, 1
        LD      (X86_CPU_State), A
        RET

.Do_TEST_AH_CH:
        LD      A, (X86_REG_AX + 1)     
        LD      E, A
        LD      A, (X86_REG_CX + 1)     
        AND     E                       
        
        PUSH    AF
        POP     BC                      
        CALL    Update_X86_Flags8       
        
        PUSH    HL
        LD      HL, (X86_REG_FLAGS)
        RES     0, L                    
        LD      A, H
        RES     3, A                    
        LD      H, A
        LD      (X86_REG_FLAGS), HL
        RET

; --- ОБРАБОТЧИКИ СЛОЖНЫХ ФЛАГOВЫХ ИНСТРУКЦИЙ (СПРИНТ 1) ---
X86_Op_STC:
        PUSH    HL
        LD      HL, (X86_REG_FLAGS)
        SET     0, L                    ; CF = 1 (бит 0 младшего байта)
        LD      (X86_REG_FLAGS), HL
        POP     HL
        RET

X86_Op_CLC:
        PUSH    HL
        LD      HL, (X86_REG_FLAGS)
        RES     0, L                    ; CF = 0
        LD      (X86_REG_FLAGS), HL
        POP     HL
        RET

X86_Op_CMC:
        PUSH    AF
        PUSH    HL
        LD      HL, (X86_REG_FLAGS)
        LD      A, L
        XOR     %00000001               ; Инверсия CF
        LD      L, A
        LD      (X86_REG_FLAGS), HL
        POP     HL
        POP     AF
        RET

X86_Op_STD:
        PUSH    HL
        LD      HL, (X86_REG_FLAGS)
        SET     2, H                    ; DF = 1 (бит 10 слова FLAGS — это бит 2 старшего байта H)
        LD      (X86_REG_FLAGS), HL
        POP     HL
        RET

X86_Op_CLD:
        PUSH    HL
        LD      HL, (X86_REG_FLAGS)
        RES     2, H                    ; DF = 0
        LD      (X86_REG_FLAGS), HL
        POP     HL
        RET

; --- РЕАЛИЗАЦИЯ ИНСТРУКЦИЙ 8-БИТНОЙ ГРУППЫ $F6 (NOT AL / NEG AL) ---
X86_Op_Group_F6:
        CALL    X86_Fetch_Byte          ; Читаем байт ModR/M гостя
        LD      C, A                    
        AND     %00111000               
        SRL     A
        SRL     A                       
        SRL     A                       ; Три сдвига для получения чистого значения поля Extension
        
        CP      2                       ; Расширение Опкода /2 — это NOT
        JR      Z, .Do_NOT_AL
        CP      3                       ; Расширение Опкода /3 — это NEG
        JR      Z, .Do_NEG_AL
        
        LD      A, 1
        LD      (X86_CPU_State), A      
        RET

.Do_NOT_AL:
        LD      A, C
        AND     %00000111               ; Проверяем целевой регистр (биты 0-2)
        OR      A                       ; 0 — это регистр AL/AX
        JR      NZ, .Unsupp_F6_Reg
        
        LD      A, (X86_REG_AX)         
        CPL                             
        LD      (X86_REG_AX), A         
        RET

.Do_NEG_AL:
        LD      A, C
        AND     %00000111
        OR      A                       
        JR      NZ, .Unsupp_F6_Reg

        LD      A, (X86_REG_AX)         
        NEG                             
        LD      (X86_REG_AX), A         
        PUSH    AF
        POP     BC                      
        CALL    Update_X86_Flags8       
        RET

.Unsupp_F6_Reg:
        LD      A, 1
        LD      (X86_CPU_State), A
        RET

; --- РЕАЛИЗАЦИЯ ИНСТРУКЦИИ 16-БИТНОЙ ГРУППЫ $F7 (NOT CX / NEG CX) ---
X86_Op_Group_F7:
        CALL    X86_Fetch_Byte          
        LD      C, A                    
        AND     %00111000               
        SRL     A
        SRL     A                       
        SRL     A                       
        
        CP      2                       
        JR      Z, .Do_NOT_16
        CP      3                       
        JR      Z, .Do_NEG_16
        RET

.Do_NOT_16:
        LD      A, C                    
        AND     %00000111               
        CP      1                       ; 1 — это регистр CX
        JR      NZ, .Unsupp_Reg
        
        LD      HL, (X86_REG_CX)
        LD      A, H
        CPL
        LD      H, A
        LD      A, L
        CPL
        LD      L, A                    
        LD      (X86_REG_CX), HL
        RET

.Do_NEG_16:
        LD      A, C                    
        AND     %00000111               
        CP      1                       
        JR      NZ, .Unsupp_Reg
        
        LD      HL, 0
        LD      BC, (X86_REG_CX)
        OR      A
        SBC     HL, BC                  
        LD      (X86_REG_CX), HL
        
        PUSH    AF
        POP     BC                      
        CALL    Update_X86_Flags8       
        RET

.Unsupp_Reg:
        LD      A, 1
        LD      (X86_CPU_State), A
        RET

; --- ОБРАБОТЧИК ОПКOДА $D3: СДВИГИ 16-БИТНЫХ РЕГИСТРОВ НА СЧЕТЧИК CL ---
X86_Op_Group_D3:
        CALL    X86_Fetch_Byte          
        LD      C, A                    
        AND     %00111000               
        SRL     A
        SRL     A
        SRL     A
        CP      4                       ; 4 — это сдвиг SHL / SAL
        JR      NZ, .Unsupp_Shift_Op
        
        LD      A, C
        AND     %00000111               
        OR      A                       
        JR      NZ, .Unsupp_Shift_Reg

        LD      A, (X86_REG_CX)         
        OR      A                       
        RET     Z                       
        
        LD      B, A                    
        LD      HL, (X86_REG_AX)        

.ShiftLoop:
        ADD     HL, HL                  
        DJNZ    .ShiftLoop              

        LD      (X86_REG_AX), HL        
        
        ; ИСПРАВЛЕНО: Обновляем флаги хоста Z80 на основе старшего байта результата сдвига H,
        ; полностью уничтожая деструктивное влияние счетчика DJNZ перед вызовом упаковщика флагов!
        LD      A, H
        AND     A                       
        
        PUSH    AF
        POP     BC                      
        CALL    Update_X86_Flags8       
        RET

.Unsupp_Shift_Op:
.Unsupp_Shift_Reg:
        LD      A, 1
        LD      (X86_CPU_State), A
        RET
