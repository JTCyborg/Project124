; =========================================================================
; PERFECT COMMANDER 110 — МОДУЛЬ СИСТЕМНЫХ ПРЕРЫВАНИЙ BIOS / DOS API x86
; МОДУЛЬ: src/x86_int21.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ГЛАВНЫЙ ДИСПЕТЧЕР СИСТЕМНЫХ ПРЕРЫВАНИЙ ГОСТЯ ---
Op_INT_21h_Dispatcher:
        PUSH    AF                      
        LD      A, (X86_INT_VECTOR)     
        
        CP      $08                     ; Системный таймер BIOS?
        JR      Z, .Int08h_Timer
        
        CP      $10                     ; Видео-сервис BIOS?
        JR      Z, .Int10h_Video

        CP      $11
        JR      Z, .Int11h_Equipment

        CP      $12
        JR      Z, .Int12h_Memory
        
        CP      $16                     ; Сервис клавиатуры BIOS?
        JR      Z, .Int16h_Keyboard
        
        CP      $21                     ; Системные вызовы DOS API?
        JR      Z, .Int21h_DOS_Gateway
        
        LD      A, 1
        LD      (X86_CPU_State), A
        POP     AF                      
        RET

; --- ОБРАБОТЧИК: INT 08h (Системный Таймер BIOS) ---
.Int08h_Timer:
        PUSH    HL
        PUSH    DE

        ; Инкрементируем счетчик времени гостя в ОЗУ хоста (переменные в log_vars.asm)
        LD      HL, (X86_BIOS_TIMER_LO)
        INC     HL                      
        LD      (X86_BIOS_TIMER_LO), HL
        
        LD      A, H
        OR      L
        JR      NZ, .DoIRET_Simulation  
        
        LD      HL, (X86_BIOS_TIMER_HI)
        INC     HL                      
        LD      (X86_BIOS_TIMER_HI), HL

.DoIRET_Simulation:
        POP     DE
        POP     HL
        POP     AF                      
        RET

; --- ОБРАБОТЧИК: INT 10h (Видео-сервис BIOS) ---
.Int10h_Video:
        PUSH    HL
        LD      A, (X86_REG_AX + 1)     ; AH — номер функции
        CP      $0E                     
        JR      NZ, .Int10h_Exit
        LD      A, (X86_REG_AX)         ; AL — ASCII-код символа гостя
        CALL    AppendLogChar           
.Int10h_Exit:
        POP     HL
        POP     AF                      
        RET

.Int11h_Equipment:
        LD      HL, $0021
        LD      (X86_REG_AX), HL
        POP     AF
        RET

.Int12h_Memory:
        LD      HL, $0280
        LD      (X86_REG_AX), HL
        POP     AF
        RET

; --- ОБРАБОТЧИК: INT 16h (Сервис клавиатуры BIOS) ---
.Int16h_Keyboard:
        PUSH    HL
        LD      A, (X86_REG_AX + 1)     ; AH — номер функции
        CP      $01                     
        JR      NZ, .Int16h_Exit
        
        LD      HL, (X86_REG_FLAGS)
        SET     6, L                    
        LD      (X86_REG_FLAGS), HL
.Int16h_Exit:
        POP     HL
        POP     AF                      
        RET

; --- ШЛЮЗ ДЛЯ DOS API ПРИНТЕРА СТРОК ---
.Int21h_DOS_Gateway:
        CALL    Op_INT_21h              
        POP     AF                      
        RET

; =========================================================================
; DOS ПРИНТЕР СТРОК
; =========================================================================
Op_INT_21h:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        PUSH    IY                      

        LD      A, (X86_REG_AX + 1)
        CP      $09                     
        JP      NZ, .Unsupported

        LD      DE, (X86_REG_DX)        

.PrintLoop:
        PUSH    DE
        POP     IY                  
        LD      IX, (X86_REG_DS)     
        
        CALC_X86_ADDR           
        CALL    Switch_X86_RAM          

        LD      A, H
        AND     %00111111
        OR      $C0
        LD      H, A
        LD      A, (HL)                 

        CP      "$"                     
        JR      Z, .ExitSuccess      

        PUSH    DE                 
        PUSH    AF                 

        CALL    Restore_X86_Host_RAM

        POP     AF                  
        PUSH    AF

        CALL    AppendLogChar           

        POP     AF                  
        POP     DE                  

        INC     DE                      
        JP      .PrintLoop

.ExitSuccess:
        LD      (X86_REG_DX), DE

        CALL    Restore_X86_Host_RAM

        POP     IY
        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

.Unsupported:
        LD      A, 1
        LD      (X86_CPU_State), A   
        
        POP     IY
        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET
