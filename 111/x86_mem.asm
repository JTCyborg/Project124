; =========================================================================
; PERFECT COMMANDER 110 — МЕНЕДЖЕР СТРАНИЦ 640Kb CONVENTIONAL MEMORY
; МОДУЛЬ: src/x86_mem.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ИСПРАВЛЕННЫЙ МАКРОС ВЫЧИСЛЕНИЯ 20-БИТНОГО АДРЕСА x86 ---
        MACRO CALC_X86_ADDR
        PUSH    BC
        PUSH    IX
        POP     HL                      ; HL = Базовый сегмент гостя (CS или DS)
        
        ; Точный расчет: Сегмент * 16. Извлекаем старшую тетраду в аккумулятор A
        LD      A, H
        AND     %11110000
        SRL     A
        SRL     A
        SRL     A
        SRL     A                       ; A = Старшие 4 бита сегмента (номер мегабайтного окна)
        
        ; Сдвигаем пару HL влево на 4 бита
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL                  ; HL теперь удерживает (Сегмент * 16) & 0xFFFF
        
        PUSH    IY
        POP     BC                      ; BC = Смещение гостя (IP или эффективный адрес)
        
        OR      A                       ; Очистка флага переноса
        ADD     HL, BC                  ; Складываем сегмент со смещением
        JR      NC, 1F                  
        INC     A                       ; Учитываем перенос в старший разряд страницы
1:                                  
        POP     BC
        ENDM                        

; --- ФУНКЦИЯ ПЕРЕКЛЮЧЕНИЯ СТРАНИЦ x86 В ОКНО $C000-$FFFF ---
Switch_X86_RAM:
        PUSH    AF
        PUSH    HL
        PUSH    DE

        LD      D, A
        LD      A, H
        AND     %11000000
        SRL     A
        SRL     A
        SRL     A
        SRL     A
        SRL     A
        SRL     A
        LD      E, A

        LD      A, D
        AND     %00001111
        RLCA
        RLCA
        OR      E
        LD      E, A                    

        LD      A, E
        CP      40                      
        JR      NC, .Segmentation_Fault 

        LD      A, E
        ADD     A, 16                   
        LD      E, A                    

        LD      A, E
        SRL     A
        SRL     A
        SRL     A                       ; Старшие биты банка 16-KiB выбираются через Pentagon
        LD      BC, #EFF7
        OUT     (C), A

        LD      A, E
        AND     %00000111
        OR      #10                     ; Сохраняем ROM/режим хоста при выборе банка RAM
        LD      BC, #7FFD
        OUT     (C), A

        POP     DE
        POP     HL
        POP     AF                      ; ИСПРАВЛЕНО: Каноническое восстановление аккумулятора флагов хоста
        RET

.Segmentation_Fault:
        LD      A, 1
        LD      (X86_CPU_State), A   
        POP     DE
        POP     HL
        POP     AF
        RET

Restore_X86_Host_RAM:
        PUSH    AF
        PUSH    BC
        XOR     A
        LD      BC, #EFF7
        OUT     (C), A
        LD      A, #10
        LD      BC, #7FFD
        OUT     (C), A
        POP     BC
        POP     AF
        RET

Switch_Pentagon_RAM_Direct:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        
        XOR     A
        LD      BC, #EFF7
        OUT     (C), A                  
        
        LD      A, E
        AND     %00000111
        LD      D, A
        
        LD      A, E
        AND     %00001000
        ADD     A, A
        ADD     A, A
        ADD     A, A
        OR      D
        LD      D, A
        
        LD      A, E
        AND     %00010000
        ADD     A, A
        ADD     A, A
        ADD     A, A
        ADD     A, A
        OR      D
        
        LD      BC, #7FFD
        OUT     (C), A
        
        POP     DE
        POP     BC
        POP     AF
        RET

; --- АТОМАРНЫЙ FETCH БАЙТА ИЗ КОДА ГОСТЯ ---
X86_Fetch_Byte:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    IX
        PUSH    IY                      

        LD      HL, (X86_REG_IP)
        PUSH    HL                      
        INC     HL
        LD      (X86_REG_IP), HL        

        LD      IX, (X86_REG_CS)        
        
        POP     HL                      
        PUSH    HL                      
        PUSH    HL
        POP     IY                      
        
        CALC_X86_ADDR           
        CALL    Switch_X86_RAM          

        LD      A, H
        AND     %00111111
        OR      $C0                  
        LD      H, A
        
        LD      A, (HL)                 
        LD      E, A                    

        CALL    Restore_X86_Host_RAM
        LD      A, E                    
        POP     HL                      
        POP     IY                      
        POP     IX
        POP     BC
        POP     DE
        POP     HL
        RET

; --- АТОМАРНОЕ ЧТЕНИЕ БАЙТА ДАННЫХ ГОСТЯ ---
X86_Read_Byte_Data:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    IX
        PUSH    IY                      

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
        LD      B, A                    

        CALL    Restore_X86_Host_RAM
        LD      A, B                    
        POP     IY                      
        POP     IX
        POP     BC
        POP     DE
        POP     HL
        RET

X86_Read_Byte_Segment:
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    IX
        PUSH    IY
        PUSH    DE
        POP     IY
        CALC_X86_ADDR
        CALL    Switch_X86_RAM
        LD      A, (X86_CPU_State)
        CP      2
        JR      Z, .ReadFailed
        LD      A, H
        AND     %00111111
        OR      $C0
        LD      H, A
        LD      A, (HL)
        LD      (X86_Mem_TempByte), A
        JR      .ReadRestore
.ReadFailed:
        XOR     A
.ReadRestore:
        CALL    Restore_X86_Host_RAM
        POP     IY
        POP     IX
        POP     BC
        POP     DE
        POP     HL
        LD      A, (X86_Mem_TempByte)
        RET

X86_Write_Byte_Segment:
        LD      (X86_Mem_TempByte), A
        PUSH    HL
        PUSH    DE
        PUSH    BC
        PUSH    IX
        PUSH    IY
        PUSH    DE
        POP     IY
        CALC_X86_ADDR
        CALL    Switch_X86_RAM
        LD      A, (X86_CPU_State)
        CP      2
        JR      Z, .WriteRestore
        LD      A, H
        AND     %00111111
        OR      $C0
        LD      H, A
        LD      A, (X86_Mem_TempByte)
        LD      (HL), A
.WriteRestore:
        CALL    Restore_X86_Host_RAM
        POP     IY
        POP     IX
        POP     BC
        POP     DE
        POP     HL
        RET

; =========================================================================
; НИЗКОРАСПОЛОЖЕННЫЕ АТОМАРНЫЕ ШЛЮЗЫ ТЕНЕВОЙ БАНКИ ЛОГА 4
; =========================================================================
X86_ClearLog_Bank4:
        PUSH    AF
        PUSH    BC
        PUSH    HL
        
        LD      A, 4 + 16               
        LD      BC, #7FFD
        OUT     (C), A

        LD      HL, $C000               
        LD      (HL), " "

        LD      A, #10                  
        LD      BC, #7FFD
        OUT     (C), A
        
        POP     HL
        POP     BC
        POP     AF
        RET

X86_ReadLogSectors_Bank4:
        PUSH    AF
        PUSH    BC
        PUSH    HL
        
        LD      (#5D0F), A              
        LD      A, 4 + 16               
        LD      BC, #7FFD
        OUT     (C), A

        LD      HL, $C000               
        LD      C, #05                  
        EI
        CALL    #3D13                   
        DI

        LD      A, #10                  
        LD      BC, #7FFD
        OUT     (C), A
        
        POP     HL
        POP     BC
        POP     AF
        RET

X86_WriteLogChar_Bank4:
        LD      (TRDLOG_CHAR), A        
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      A, 4 + 16               
        LD      BC, #7FFD
        OUT     (C), A

        LD      HL, (TRDLOG_LENGTH)
        LD      DE, $C000               
        ADD     HL, DE
        LD      A, (TRDLOG_CHAR)
        LD      (HL), A                 

        LD      HL, (TRDLOG_LENGTH)
        INC     HL
        LD      (TRDLOG_LENGTH), HL     

        LD      A, #10
        LD      BC, #7FFD
        OUT     (C), A
        
        POP     HL
        POP     DE
        POP     BC
        RET
