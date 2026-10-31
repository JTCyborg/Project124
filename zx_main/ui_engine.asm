; =========================================================================
; PROJECT 124 — USER INTERFACE & GRAPHIC TEXT ENGINE (FROM PROJECT 123)
; СИСТЕМНЫЙ ПУТЬ: zx_main/ui_engine.asm (ПОЛНЫЙ КОД ЦЕЛИКОМ)
; =========================================================================

UI_Active_Font:: DB 0                    ; 0 = font88, 1 = font68

; --- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ КУРСОРНОЙ НАВИГАЦИИ (ИЗ ПРОЕКТА 123) ---
CursorY::        DEFB 2                  ; Текущая строка курсора панели (2..10)

; --- ТAБЛИЧНЫЙ СKРOЛЛИНГ НИЖНЕГO OKНA ЛOГOВ ИЗ ПРOЕKТA 123 ---
UI_ScrollConsoleUp::
        PUSH    IX: PUSH AF: PUSH BC: PUSH DE: PUSH HL
        XOR     A                       
        LD      (.local_micro_ctr), A
.global_loop:
        LD      IX, .Line_Addr_Table
        LD      A, 11                   
        LD      (.local_row_ctr), A       
.rows_loop:
        LD      E, (IX+0): LD D, (IX+1)               
        LD      L, (IX+2): LD H, (IX+3)               
        PUSH    IX: PUSH BC                      
        LD      A, (.local_micro_ctr): ADD A, D: LD D, A                    
        LD      A, (.local_micro_ctr): ADD A, H: LD H, A                    
        LD      BC, 32: LDIR                            
        POP     BC: POP IX                      
        LD      DE, 4: ADD IX, DE                  
        LD      A, (.local_row_ctr): DEC A: LD (.local_row_ctr), A
        JR      NZ, .rows_loop   

        LD      A, (.local_micro_ctr): INC A: LD (.local_micro_ctr), A
        CP      8                        
        JR      C, .global_loop   

        ; Сдвиг цветовых атрибутов лога
        LD      DE, #5980: LD HL, #59A0: LD BC, 352: LDIR                            
        ; Очистка последней строки атрибутов
        LD      HL, #5B00: LD DE, #5B01: LD (HL), %01000100: LD BC, 31: LDIR                            
        ; Очистка пикселей 23-й строки
        XOR     A: LD H, #50                  
.clear_pixels:
        PUSH    AF: PUSH HL                      
        LD      L, #E0: LD C, 32: XOR A
.clear_bytes:
        LD      (HL), A: INC HL: DEC C: JR NZ, .clear_bytes  
        POP     HL: INC H: POP AF: INC A: CP 8: JR C, .clear_pixels

        POP     HL: POP DE: POP BC: POP AF: POP IX
        LD      A, 23: LD (Console_Y), A
        XOR     A: LD (Console_X), A
        RET

.Line_Addr_Table:
        DW #4880, #48A0, #48A0, #48C0, #48C0, #48E0, #48E0, #5000                 
        DW #5000, #5020, #5020, #5040, #5040, #5060, #5060, #5080                 
        DW #5080, #50A0, #50A0, #50C0, #50C0, #50E0                 

.local_micro_ctr: DB 0
.local_row_ctr:   DB 0

ClearScreenROM::
        PUSH    BC: PUSH DE: PUSH HL
        LD      HL, #4000: LD DE, #4001: LD (HL), 0: LD BC, 6143: LDIR                            
        LD      HL, #5800: LD DE, #5801: LD (HL), %01000100: LD BC, 767: LDIR
        POP     HL: POP DE: POP BC
        RET

ForceInterfaceColors::
        PUSH    AF: PUSH BC: PUSH DE: PUSH HL
        LD      HL, #5800
        LD      DE, #5801
        LD      (HL), %01001111         ; Верх: Синий
        LD      BC, 383                 
        LDIR
        
        LD      HL, #5980
        LD      DE, #5981
        LD      (HL), %01000100         ; Низ: Черный
        LD      BC, 383                 
        LDIR
        POP     HL: POP DE: POP BC: POP AF
        RET      

; --- АППАРАТНЫЙ ОПРОС КЛАВИШ НАВИГАЦИИ (ИЗ ПРОЕКТА 123) ---
GetHardwareKey::                        
        LD      BC, #DFFE: IN A, (C): BIT 1, A: JR Z, .key_o_pressed        
        LD      BC, #BFFE: IN A, (C): BIT 1, A: JR Z, .key_l_pressed        
        XOR     A: RET
.key_o_pressed: LD A, 1: RET
.key_l_pressed: LD A, 2: RET

; =========================================================================
; ИМПОРТ БИНАРНЫХ ФАЙЛОВ ШРИФТОВ ИЗ ВАШЕГО КАТАЛОГА
; =========================================================================
        ALIGN 256
FONT_DATA_88:
        INCBIN "font88.bin"             ; Крупный шрифт 8x8

        ALIGN 256
FONT_DATA_68:
        INCBIN "font68.bin"             ; Компактный шрифт 6x8


; =========================================================================
