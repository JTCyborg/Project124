; =========================================================================
; PROJECT 124 — LOW LEVEL GRAPHIC CHR RENDERER (FROM PROJECT 123)
; СИСТЕМНЫЙ ПУТЬ: zx_main/display.asm (ПОЛНЫЙ КОД ЦЕЛИКОМ)
; =========================================================================

; =========================================================================
; [Дописать в самое начало файла zx_main/display.asm]
; =========================================================================
; Связываем имя шрифта из 123-го ядра с бинарным массивом ui_engine проекта 124
EXTERNAL_FONT_BIN EQU FONT_DATA_88


; --- ПРОЦЕДУРА ПРЯМОЙ ПЕЧАТИ НИЖНЕГО ОТЛАДЧИКА С АВТО-СКРОЛЛОМ ---
Direct_PrintChar::
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      B, A                    

        ; Тотальный аппаратный перехват в физический порт отладки #EF
        IF ENABLE_HARDWARE_DEBUG == 1
        PUSH    BC
        LD      BC, #00EF
        OUT     (C), A                  
        POP     BC
        ENDIF

        CP      #0D                     ; Проверяем возврат каретки (CR)
        JR      NZ, .check_lf
        XOR     A
        LD      (Console_X), A          
        JP      .done_print             

.check_lf:
        CP      #0A                     ; Проверяем перевод строки (LF)
        JR      NZ, .render_gate
        XOR     A
        LD      (Console_X), A          
        LD      A, (Console_Y)
        INC     A                       
        LD      (Console_Y), A
        CALL    EnsureConsoleSpace      
        JP      .done_print             

.render_gate:
        LD      A, (Console_Y)
        LD      D, A                    
        LD      A, (Console_X)
        LD      C, A                    
        
        LD      A, B                    
        CALL    Direct_PrintChar_Args   

        LD      A, (Console_X)
        INC     A
        LD      (Console_X), A          

        CP      32                      ; Автоперенос по правому краю
        JR      C, .done_print          
        
        XOR     A
        LD      (Console_X), A          
        LD      A, (Console_Y)
        INC     A                       
        LD      (Console_Y), A
        CALL    EnsureConsoleSpace      

.done_print:
        POP     HL
        POP     DE
        POP     BC
        RET

; --- ТОЧНЫЙ КAНОНИЧЕСКИЙ РЕНДЕРЕР ЗНAКОМЕСТА ИЗ ПРОЕКТА 123 ---
Direct_PrintChar_Args::
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        ; 1. РАСЧЕТ ТОЧНОГО АДРЕСА АТРИБУТА ЦВЕТА (#5800)
        LD      A, D                    ; Console_Y (0..23)
        AND     #18                     
        RRCA: RRCA: RRCA
        ADD     A, #58                  
        LD      H, A
        
        LD      A, D
        AND     #07
        RLCA: RLCA: RLCA: RLCA: RLCA    
        LD      L, A
        
        LD      A, C                    ; Console_X (0..31)
        ADD     A, L
        LD      L, A                    

        LD      A, D                    
        CP      12                      
        JR      NC, .set_black_bg
        LD      A, %01001111            ; Верх (0..11): PAPER=1(Синий), INK=7(Белый), BRIGHT=1
        JR      .write_color
.set_black_bg:
        LD      A, %01000100            ; Низ (12..23): PAPER=0(Черный), INK=4(Зеленый), BRIGHT=1
.write_color:
        LD      (HL), A                 

        ; 2. КAНОНИЧЕСКИЙ РАСЧЕТ АДРЕСА ПИКСЕЛЕЙ В ЭКРАНЕ (#4000)
        LD      A, D                    
        AND     #18
        ADD     A, #40                  
        LD      H, A                    
        
        LD      A, D                    
        AND     #07
        RRCA: RRCA: RRCA
        LD      L, A
        
        LD      A, L
        AND     #E0
        ADD     A, C                    
        LD      E, A
        
        LD      A, L
        AND     #07
        OR      H
        LD      D, A                    ; DE = базовый адрес пикселей на экране

        ; 3. ПОСТРОЧНЫЙ РЕНДЕР ШРИФТА ИЗ ВЫБРАННОГО МАССИВА ОБОЛОЧКИ
        LD      A, B                    
        SUB     32
        LD      L, A
        LD      H, 0
        ADD     HL, HL
        ADD     HL, HL
        ADD     HL, HL                  ; HL = смещение буквы (ASCII * 8)
        
        PUSH    DE
        LD      A, (UI_Active_Font)
        AND     A
        JR      NZ, .low_font68
        LD      BC, FONT_DATA_88
        JR      .low_font_done
.low_font68:
        LD      BC, FONT_DATA_68
.low_font_done:
        ADD     HL, BC                  
        POP     DE

        ; Отрисовка 8 вертикальных линий
        LD      B, 8
.draw_font_loop:
        LD      A, (HL)
        LD      (DE), A
        INC     HL
        INC     D                       
        DJNZ    .draw_font_loop

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

; Отрисовка разделительной рамки панелей Commander
DrawCommanderPanels::
        PUSH    AF: PUSH BC: PUSH DE: PUSH HL
        LD      A, 11
        LD      (Console_Y), A
        XOR     A
        LD      (Console_X), A
        LD      B, 32
.loop_line:
        LD      A, #44                  ; Код горизонтальной линии "═"
        CALL    Direct_PrintChar_Args
        LD      A, (Console_X): INC A: LD (Console_X), A
        DJNZ    .loop_line
        POP     HL: POP DE: POP BC: POP AF
        RET


; =========================================================================
