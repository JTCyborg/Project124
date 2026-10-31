; =========================================================================
; PROJECT 124 — FILE PANELS & HIGH LEVEL GRAPHICS (FROM PROJECT 123)
; СИСТЕМНЫЙ ПУТЬ: zx_main/ui_panels.asm (ПОЛНЫЙ КОД ЦЕЛИКОМ)
; =========================================================================

; --- ТАБЛИЦА АДРЕСОВ АТРИБУТОВ СТРОК КУРСOРА ПАНЕЛИ (Y = 2..10) ---
Cursor_Row_Table:
        DW #5841 , #5861 , #5881 , #58A1 , #58C1 , #58E1 , #5901 , #5921 , #5941

; --- ВЫЧИСЛЕНИЕ АДРЕСА СТРОКИ АТРИБУТОВ ДЛЯ КУРСОРНОЙ НАВИГАЦИИ ---
Get_Cursor_RAM_Address:
        LD      A, (CursorY)            
        SUB     2                       
        ADD     A, A                    
        LD      E, A 
        LD      D, 0 
        LD      HL, Cursor_Row_Table    
        ADD     HL, DE                  
        LD      A, (HL) 
        LD      E, A 
        INC     HL 
        LD      A, (HL) 
        LD      D, A 
        EX      DE, HL                  
        RET 

; --- ОТРЕСОВКА ИНВЕРСИОННОЙ ПОЛОСЫ ВЫДЕЛЕНИЯ ФАЙЛА ---
DrawActiveCursor::
        PUSH    BC                      
        PUSH    HL                      
        CALL    Get_Cursor_RAM_Address  
        LD      B, 30                   
.loop:
        LD      (HL), %00111000         ; Инверсия: Белый фон, черный text
        INC     HL                     
        DJNZ    .loop                  
        POP     HL                     
        POP     BC                      
        RET                             

; --- СТИРАНИЕ ИНВЕРСИОННОЙ ПОЛОСЫ С ВОЗВРАТОМ СИНЕГО ЦВЕТА ---
EraseActiveCursor::
        PUSH    BC                      
        PUSH    HL                      
        CALL    Get_Cursor_RAM_Address  
        LD      B, 30                   
.loop:
        LD      (HL), %01001111         ; Синий фон %4F
        INC     HL                     
        DJNZ    .loop                  
        POP     HL                     
        POP     BC                      
        RET                             

; --- ГЛОБАЛЬНАЯ ТОЧКА ИНИЦИАЛИЗАЦИИ ИНТЕРФЕЙСА ОКОН PERFECT COMMANDER ---
INIT_PROGRAM_INTERFACE::
        PUSH    AF: PUSH BC: PUSH DE: PUSH HL

        CALL    ClearScreenROM          ; Полная очистка экрана и атрибутов
        
        LD      A, 12                   
        LD      (#5C6A), A              ; DF_SZ = 12 строк для панели файлов
        LD      A, %00111000            
        LD      (#5C8D), A             
        LD      A, %01000100            
        LD      (#5C8C), A             

        XOR     A                       
        OUT     (254), A                ; Черный бордюр

        LD      A, %00111000            
        LD      (#5C48), A             
        LD      (#5C8F), A             
        LD      (#5C49), A             

        CALL    ForceInterfaceColors    ; Заливка окон цветом
        CALL    DrawCommanderPanels     ; Отрисовка разделительной линии панелей

        ; Начальные координаты для вывода логов в нижнем черном окне
        LD      A, 12                   
        LD      (Console_Y), A
        XOR     A
        LD      (Console_X), A         

        ; ОТРЕНДЕРИТЬ ДИНАМИЧЕСКИЙ КАТАЛОГ ДИСКА А
        CALL    Refresh_Panel_Directory 

        ; Фиксируем полосу курсора на первую строку файлов (строка 2)
        LD      A, 2                  
        LD      (CursorY), A          
        CALL    DrawActiveCursor       

        POP     HL: POP DE: POP BC: POP AF
        RET

; --- АППАРАТНЫЙ КОНТРОЛЬ СВОБОДНОГО МЕСТА ДЛЯ ВЕРТИКАЛЬНОГО СКРОЛЛИНГА ---
EnsureConsoleSpace::
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      A, (Console_Y)
        CP      24                      ; Нижний лог занимает строки 12..23
        JR      C, .space_ok            

        CALL    UI_ScrollConsoleUp      ; Вызываем табличный аппаратный сдвиг экрана
        
        LD      A, 23                   
        LD      (Console_Y), A
        XOR     A
        LD      (Console_X), A          

.space_ok:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET


; =========================================================================
