; =========================================================================
; PERFECT COMMANDER 110 — ПОЛНЫЙ ЛИНЕЙНЫЙ БАНК ТЕСТОВЫХ ПРОШИВОК ГОСТЯ x86
; МОДУЛЬ: src/x86_tests.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ТАБЛИЦА СВЯЗИ ДЛЯ ВЫСОКОУРОВНЕВОГО ЗАГРУЗЧИКА ХОСТА ---
X86_Test_Table:
        DW      X86_T1
        DW      X86_T2
        DW      X86_T3
        DW      X86_T4
        DW      X86_T5
        DW      X86_T6
        DW      X86_T7
        DW      X86_T8
        DW      X86_T9
        DW      X86_T10
        DW      X86_T11
        DW      X86_T12
        DW      X86_T13
        DW      X86_T14
        DW      X86_T15
        DW      X86_T16
        DW      X86_T17
        DW      X86_T18                  ; НОВЫЙ: Флаги Carry / Overflow
        DW      X86_T19                  ; НОВЫЙ: Знаковое IMUL / IDIV
        DW      X86_T20                  ; НОВЫЙ: Стресс-тест Стека и CALL
        dw      X86_T21                  ; НОВЫЙ: Строковый реверс (DF=1)
        dw      X86_T22                  ; НОВЫЙ: Флаг четности PF
        dw      X86_T23                  ; НОВЫЙ: Адресация [BX]
        dw      X86_T24                  ; НОВЫЙ: Адресация [BP+DI]
        dw      X86_T25                  ; НОВЫЙ: Адресация [SI+Disp16]
        dw      X86_T26                  ; НОВЫЙ: Динамический сдвиг SHL AX, CL
        dw      X86_T27                  ; НОВЫЙ: Динамический сдвиг SAR AX, CL
        dw      X86_T28                  ; НОВЫЙ: Эмуляция вызова BIOS INT 10h
        dw      X86_T29                  ; НОВЫЙ: Эмуляция вызова BIOS INT 16h
        dw      X86_T30                  ; НОВЫЙ: Побайтовое копирование REP MOVSB
        dw      X86_T31                  ; НОВЫЙ: Побайтовое заполнение REP STOSB
        dw      X86_T32                  ; НОВЫЙ: Стресс-тест вложенных префиксов REP
        dw      X86_T33
        dw      X86_T34
        dw      X86_T35
        dw      X86_T36
        dw      X86_T37
        dw      X86_T38
        dw      X86_T39
        dw      X86_T40
        dw      X86_T41

X86_Test_Lengths:
        DW      X86_T1_E  - X86_T1
        DW      X86_T2_E  - X86_T2
        DW      X86_T3_E  - X86_T3
        DW      X86_T4_E  - X86_T4
        DW      X86_T5_E  - X86_T5
        DW      X86_T6_E  - X86_T6
        DW      X86_T7_E  - X86_T7
        DW      X86_T8_E  - X86_T8
        DW      X86_T9_E  - X86_T9
        DW      X86_T10_E - X86_T10
        DW      X86_T11_E - X86_T11
        DW      X86_T12_E - X86_T12
        DW      X86_T13_E - X86_T13
        DW      X86_T14_E - X86_T14
        DW      X86_T15_E - X86_T15
        DW      X86_T16_E - X86_T16
        DW      X86_T17_E - X86_T17
        DW      X86_T18_E - X86_T18      ; Длина Т18
        DW      X86_T19_E - X86_T19      ; Длина Т19
        DW      X86_T20_E - X86_T20      ; Длина Т20
        dw      X86_T21_E - X86_T21      ; Длина Т21
        dw      X86_T22_E - X86_T22      ; Длина Т22
        dw      X86_T23_E - X86_T23      ; Длина Т23
        dw      X86_T24_E - X86_T24      ; Длина Т24
        dw      X86_T25_E - X86_T25      ; Длина Т25
        dw      X86_T26_E - X86_T26      ; Длина Т26
        dw      X86_T27_E - X86_T27      ; Длина Т27
        dw      X86_T28_E - X86_T28      ; Длина Т28
        dw      X86_T29_E - X86_T29      ; Длина Т29
        dw      X86_T30_E - X86_T30      ; Длина Т30
        dw      X86_T31_E - X86_T31      ; Длина Т31
        dw      X86_T32_E - X86_T32      ; Длина Т32
        dw      X86_T33_E - X86_T33
        dw      X86_T34_E - X86_T34
        dw      X86_T35_E - X86_T35
        dw      X86_T36_E - X86_T36
        dw      X86_T37_E - X86_T37
        dw      X86_T38_E - X86_T38
        dw      X86_T39_E - X86_T39
        dw      X86_T40_E - X86_T40
        dw      X86_T41_E - X86_T41

; =========================================================================
; ПОСЛЕДОВАТЕЛЬНЫЕ БИНАРНЫЕ БЛОКИ ТЕСТОВ
; =========================================================================

X86_T1:
        DB      $B8, $4F, $0E           ; mov ax, 0x0E4F
        DB      $CD, $10                ; int 0x10 
X86_T1_E:

X86_T2:
        DB      $B8, $05, $00           ; mov ax, 5
        DB      $B9, $03, $00           ; mov cx, 3
        DB      $01, $C1                ; add ax, cx
        DB      $29, $C1                ; sub ax, cx
        DB      $3B, $C1                ; cmp ax, cx
        DB      $F4                     ; hlt
X86_T2_E:

X86_T3:
        DB      $B0, $AA                ; mov al, 0xAA
        DB      $B4, $55                ; mov ah, 0x55
        DB      $B1, $11                ; mov cl, 0x11
        DB      $B5, $22                ; mov ch, 0x22
        DB      $F4                     ; hlt
X86_T3_E:

X86_T4:
        DB      $B4, $09                ; mov ah, 9
        DB      $BA, $08, $01           ; mov dx, 0x0108
        DB      $CD, $21                ; int 0x21
        DB      $F4                     ; hlt
        DB      "HELLO DOS WORLD$"
X86_T4_E:

X86_T5:
        DB      $B8, $03, $00           ; mov ax, 3
        DB      $B9, $05, $00           ; mov cx, 5
        DB      $3B, $C1                ; cmp ax, cx
        DB      $72, $02                ; jc .PassedJC
        DB      $F4
.PassedJC:
        DB      $29, $C1                ; sub ax, cx
        DB      $78, $02                ; js .PassedJS
        DB      $F4
.PassedJS:
        DB      $B9, $FE, $FF           ; mov cx, $FFFE
        DB      $3B, $C1                ; cmp ax, cx
        DB      $74, $02                ; jz .PassedJZ
        DB      $F4
.PassedJZ:
        DB      $EB, $01                ; jmp .End
        DB      $F4
.End:
        DB      $F4                     ; hlt
X86_T5_E:

X86_T6:
        DB      $B8, $55, $55           ; mov ax, 0x5555
        DB      $B9, $AA, $AA           ; mov cx, 0xAAAA
        DB      $F4                     ; hlt
X86_T6_E:

X86_T7:
        DB      $B8, $03, $00           ; mov ax, 3
        DB      $B9, $05, $00           ; mov cx, 5
        DB      $3B, $C1                ; cmp ax, cx
        DB      $B8, $FF, $0F           ; mov ax, 0x0FFF
        DB      $B9, $F0, $FF           ; mov cx, 0xFFF0
        DB      $23, $C1                ; and ax, cx
        DB      $B8, $55, $55           ; mov ax, 0x5555
        DB      $B9, $AA, $AA           ; mov cx, 0xAAAA
        DB      $0B, $C1                ; or ax, cx
        DB      $33, $C1                ; xor ax, cx
        DB      $B9, $00, $00           ; mov cx, 0x0000
        DB      $85, $C1                ; test ax, cx
        DB      $F4                     ; hlt
X86_T7_E:

X86_T8:
        DB      $B8, $03, $00           ; mov ax, 3
        DB      $B9, $05, $00           ; mov cx, 5
        DB      $3B, $C1                ; cmp ax, cx
        DB      $40                     ; inc ax
        DB      $4A                     ; dec dx
        DB      $B9, $01, $00           ; mov cx, 1
        DB      $49                     ; dec cx
        DB      $F4                     ; hlt
X86_T8_E:

X86_T9:
        DB      $B8, $01, $80           ; mov ax, 0x8001
        DB      $D1, $E0                ; shl ax, 1
        DB      $D1, $E8                ; shr ax, 1
        DB      $B8, $01, $80           ; mov ax, 0x8001
        DB      $D1, $F8                ; sar ax, 1
        DB      $F4                     ; hlt
X86_T9_E:

X86_T10:
        DB      $B8, $34, $12           ; mov ax, 0x1234
        DB      $89, $C2                ; mov dx, ax
        DB      $89, $D1                ; mov cx, dx
        DB      $B9, $78, $56           ; mov cx, 0x5678
        DB      $8B, $C1                ; mov ax, cx
        DB      $F4                     ; hlt
X86_T10_E:

X86_T11:
        DB      $B9, $03, $00           ; mov cx, 3
        DB      $B8, $01, $00           ; mov ax, 1
        DB      $3B, $C1                ; cmp ax, cx
        DB      $B8, $58, $0E           ; mov ax, 0x0E58
X86_T11_E:

X86_T12:
        DB      $B0, $70                ; mov al, 0x70
        DB      $B1, $20                ; mov cl, 0x20
        DB      $02, $C1                ; add al, cl
        DB      $B4, $05                ; mov ah, 0x05
        DB      $B5, $05                ; mov ch, 0x05
        DB      $2A, $E5                ; sub ah, ch
        DB      $F4                     ; hlt
X86_T12_E:

X86_T13:
        DB      $B0, $01                ; mov al, 1
        DB      $B1, $02                ; mov cl, 2
        DB      $3B, $C1                ; cmp ax, cx
        DB      $FE, $C0                ; inc al
        DB      $FE, $C1                ; inc cl
        DB      $B4, $01                ; mov ah, 1
        DB      $FE, $C4                ; dec ah
        DB      $F4                     ; hlt
X86_T13_E:

X86_T14:
        DB      $B0, $03                ; mov al, 3
        DB      $B1, $05                ; mov cl, 2
        DB      $3B, $C1                ; cmp ax, cx
        DB      $B0, $0F                ; mov al, 0x0F
        DB      $B1, $F0                ; mov cl, 0xF0
        DB      $22, $C1                ; and al, cl
        DB      $B4, $55                ; mov ah, 0x55
        DB      $B5, $AA                ; mov ch, 0xAA
        DB      $0A, $E5                ; or ah, ch
        DB      $32, $C1                ; xor al, cl
        DB      $B5, $00                ; mov ch, 0x00
        DB      $84, $E5                ; test ah, ch
        DB      $F4                     ; hlt
X86_T14_E:

X86_T15:
        DB      $B8, $00, $01           ; mov ax, 0x0100
        DB      $B9, $10, $00           ; mov cx, 0x0010
        DB      $F7, $E1                ; mul cx
        DB      $B9, $02, $00           ; mov cx, 0x0002
        DB      $F7, $F1                ; div cx
        DB      $F4                     ; hlt
X86_T15_E:

X86_T16:
        DB      $B8, $00, $01           ; mov ax, 0x0100
        DB      $05, $00, $7F           ; add ax, 0x7F00
        DB      $B9, $00, $20           ; mov cx, 0x2000
        DB      $81, $E9, $00, $20      ; sub cx, 0x2000
        DB      $F4                     ; hlt
X86_T16_E:

X86_T17:
        DB      $B8, $00, $10           ; mov ax, 0x1000
        DB      $8E, $D8                ; mov ds, ax
        DB      $8E, $C0                ; mov es, ax
        DB      $B8, $AA, $55           ; mov ax, 0x55AA
        DB      $BE, $00, $02           ; mov si, 0x0200
        DB      $BF, $00, $03           ; mov di, 0x0300
        DB      $AB                     ; stosw
        DB      $BE, $00, $03           ; mov si, 0x0300
        DB      $BF, $00, $04           ; mov di, 0x0400
        DB      $A5                     ; movsw
        DB      $F4                     ; hlt
X86_T17_E:

; -------------------------------------------------------------------------
; НОВЫЙ ТЕСТ 18: ВАЛИДАЦИЯ ФЛАГОВ ПЕРЕПОЛНЕНИЯ И ПЕРЕНОСА (OF / CF)
; -------------------------------------------------------------------------
X86_T18:
        DB      $B8, $FF, $7F           ; mov ax, 0x7FFF (Макс. положительное signed слово)
        DB      $B9, $01, $00           ; mov cx, 0x0001
        DB      $01, $C8                ; add ax, cx     (AX станет 0x8000. Взвод OF=1, SF=1, CF=0)
        DB      $B8, $FF, $FF           ; mov ax, 0xFFFF (Макс. беззнаковое число)
        DB      $01, $C1                ; add ax, cx     (AX станет 0x0000. Взвод CF=1, ZF=1, OF=0)
        DB      $F4                     ; hlt
X86_T18_E:

; -------------------------------------------------------------------------
; НОВЫЙ ТЕСТ 19: МАТЕМАТИКА ЗНАКОВОГО АЛУ (IMUL CX / IDIV CX)
; -------------------------------------------------------------------------
X86_T19:
        DB      $B8, $FE, $FF           ; mov ax, -2     (В кодировке 2's complement: 0xFFFE)
        DB      $B9, $0A, $00           ; mov cx, 10     (0x000A)
        DB      $F7, $E9                ; imul cx        (DX:AX должно стать -20 = 0xFFFFFFEC)
        DB      $B8, $F0, $FF           ; mov ax, -16    (0xFFF0)
        DB      $BA, $FF, $FF           ; mov dx, -1     (0xFFFF -> DX:AX = -16)
        DB      $B9, $03, $00           ; mov cx, 3
        DB      $F7, $F9                ; idiv cx        (AX = Частное -5 = 0xFFFB, DX = Остаток -1 = 0xFFFF)
        DB      $F4                     ; hlt
X86_T19_E:
; =========================================================================
; PERFECT COMMANDER 110 — ДОПОЛНИТЕЛЬНЫЙ БЛОК ТЕСТОВ (С 20 ПО 25)
; МОДУЛЬ: src/x86_tests.asm (СТРОГИЙ СИНТАКСИС ПОД ФЛАГ --DIRBOL)
; =========================================================================

; --- ТЕСТ 20: СТРЕСС-ТЕСТ СТЕКА ГОСТЯ (ГРАНИЧНЫЙ SP, CALL И RET) ---
X86_T20
        db      $BC, $00, $20           ; mov sp, 0x2000 (Инициализация стека)
        db      $B8, $33, $22           ; mov ax, 0x2233
        db      $50                     ; push ax        (SP упадёт до 0x1FFE)
        db      $B8, $00, $00           ; mov ax, 0x0000
        db      $E8, $02, $00           ; call .SubRoutine
        db      $F4                     ; hlt
.SubRoutine
        db      $B8, $FF, $FF           ; mov ax, 0xFFFF
        db      $C3                     ; ret           
X86_T20_E

; --- ТЕСТ 21: СТРОКОВЫЙ РЕВЕРС (ФЛАГ НАПРАВЛЕНИЯ DF = 1) ---
X86_T21
        db      $FD                     ; std            (Устанавливаем DF=1)
        db      $B8, $00, $10           ; mov ax, 0x1000
        db      $8E, $C0                ; mov es, ax
        db      $B8, $33, $33           ; mov ax, 0x3333
        db      $BF, $02, $01           ; mov di, 0x0102
        db      $AB                     ; stosw          (Запись в ES:DI, DI должен уменьшиться до 0x0100!)
        db      $F4                     ; hlt
X86_T21_E

; --- ТЕСТ 22: БАЙТНАЯ АРИФМЕТИКА И РАСЧЕТ ЧЕТНОСТИ (PF / AF) ---
X86_T22
        db      $B0, $03                ; mov al, 3      (Бинарный: 00000011 - чётное число единиц)
        db      $B1, $01                ; mov cl, 1
        db      $00, $C8                ; add al, cl     (AL станет 4 = 00000100 - нечётное число единиц, PF=0)
        db      $B0, $0F                ; mov al, 0x0F
        db      $02, $C1                ; add al, cl     (AL станет 0x10 - произошел полуперенос из бита 3 в 4, AF=1)
        db      $F4                     ; hlt
X86_T22_E

; --- ТЕСТ 23: ДЕШИФРАЦИЯ АДРЕСАЦИИ ПАМЯТИ ПО СЕГМЕНТУ MODR/M [BX] ---
X86_T23
        db      $B8, $00, $20           ; mov ax, 0x2000
        db      $8E, $D8                ; mov ds, ax     (DS = 0x2000)
        db      $BB, $00, $01           ; mov bx, 0x0100 ; BX смещение
        db      $A1, $00, $01           ; mov ax, [0x0100] ; Прямое чтение для сверки
        db      $8B, $07                ; mov ax, [bx]   ; Косвенное чтение через [BX] ModR/M
        db      $F4                     ; hlt
X86_T23_E

; --- ТЕСТ 24: СЛОЖНАЯ СЕГМЕНТНАЯ АДРЕСАЦИЯ [BP+DI] (СТЕКОВЫЙ КАДР) ---
X86_T24
        db      $B8, $00, $30           ; mov ax, 0x3000
        db      $8E, $D0                ; mov ss, ax     (SS указывает на стек)
        db      $BD, $00, $01           ; mov bp, 0x0100
        db      $BF, $02, $00           ; mov di, 0x0002
        db      $8B, $03                ; mov ax, [bp+di]; Чтение из кадра стека SS:[BP+DI]
        db      $F4                     ; hlt
X86_T24_E

; --- ТЕСТ 25: АДРЕСАЦИЯ СО СМЕЩЕНИЕМ DISP16 [SI+Disp16] ---
X86_T25
        db      $BE, $00, $01           ; mov si, 0x0100
        db      $8B, $44, $10, $00      ; mov ax, [si+0x0010] ; Чтение по адресу SI + 16 байт смещения
        db      $F4                     ; hlt
X86_T25_E


; =========================================================================
; НОВЕЙШИЕ СУПЕР-ТЕСТЫ СОВМЕСТИМОСТИ И СТАБИЛЬНОСТИ АРХИТЕКТУРЫ 26..32
; =========================================================================
; --- ТЕСТ 26: ДИНАМИЧЕСКИЙ СДВИГ ВЛЕВО ЧЕРЕЗ СЧЕТЧИК CL (SHL AX, CL) ---
X86_T26
        db      $B8, $01, $00           ; mov ax, 0x0001
        db      $B1, $04                ; mov cl, 4
        db      $D3, $E0                ; shl ax, cl     (AX должно стать 0x0010)
        db      $F4                     ; hlt
X86_T26_E
; --- ТЕСТ 27: ЗНАКОВЫЙ ДИНАМИЧЕСКИЙ СДВИГ ВПРАВО (SAR AX, CL) ---
X86_T27
        db      $B8, $00, $F0           ; mov ax, 0xF000 (Signed отрицательное число)
        db      $B1, $02                ; mov cl, 2
        db      $D3, $F8                ; sar ax, cl     (Знак удерживается! AX должно стать 0xFC00)
        db      $F4                     ; hlt
X86_T27_E
; --- ТЕСТ 28: АППАРАТНАЯ СОВМЕСТИМОСТЬ BIOS ПРЕРЫВАНИЙ ВВОДА-ВЫВОДА (INT 10h) ---
X86_T28
        db      $BC, $00, $10           ; mov sp, 0x1000
        db      $B4, $0E                ; mov ah, 0x0E   (Функция телетайпа BIOS)
        db      $B0, $41                ; mov al, 'A'    (Символ)
        db      $CD, $10                ; int 0x10       (Проверка гостевого стека при вызове)
        db      $F4                     ; hlt
X86_T28_E
; --- ТЕСТ 29: СОВМЕСТИМОСТЬ ПРЕРЫВАНИЙ КЛАВИАТУРЫ BIOS (INT 16h) ---
X86_T29
        db      $B4, $01                ; mov ah, 0x01   (Проверить статус буфера клавиатуры)
        db      $CD, $16                ; int 0x16       (Заглушка должна выставить ZF=1)
        db      $F4                     ; hlt
X86_T29_E
; --- ТЕСТ 30: ЦЕПОЧЕЧНЫЙ ПОВТОР ПОБАЙТОВОГО КОПИРОВАНИЯ (REP MOVSB) ---
X86_T30
        db      $FC                     ; cld            (DF=0, инкремент)
        db      $B8, $00, $10           ; mov ax, 0x1000
        db      $8E, $D8                ; mov ds, ax
        db      $8E, $C0                ; mov es, ax
        db      $BE, $00, $01           ; mov si, 0x0100 ; Смещение источника
        db      $BF, $00, $02           ; mov di, 0x0200 ; Смещение приемника
        db      $B9, $05, $00           ; mov cx, 5      ; Счетчик повторов
        db      $F3, $A4                ; rep movsb      (Копирует 5 байт, CX падает в 0!)
        db      $F4                     ; hlt
X86_T30_E
; --- ТЕСТ 31: ЦЕПОЧЕЧНЫЙ ПОВТОР ПОБАЙТОВОГО ЗАПОЛНЕНИЯ (REP STOSB) ---
X86_T31
        db      $B8, $00, $10           ; mov ax, 0x1000
        db      $8E, $C0                ; mov es, ax
        db      $B0, $FF                ; mov al, 0xFF   ; Паттерн заполнения
        db      $BF, $00, $03           ; mov di, 0x0300
        db      $B9, $08, $00           ; mov cx, 8      ; Заполнить 8 байт ОЗУ гостя
        db      $F3, $AA                ; rep stosb      (CX падает в ноль, DI растет)
        db      $F4                     ; hlt
X86_T31_E
; --- ТЕСТ 32: СТРЕСС-ТЕСТ ПРЕРЫВАНИЙ ВНУТРИ ЦЕПОЧЕЧНЫХ СТРОК (ВЛОЖЕННЫЙ REP) ---
X86_T32
        db      $FC                     ; cld
        db      $B9, $00, $00           ; mov cx, 0      ; Граничное условие счетчика повторов
        db      $F3, $A5                ; rep movsw      (Инструкция должна мгновенно выйти без копирования)
        db      $F4                     ; hlt
X86_T32_E


; --- ТЕСТ 33: ASCII-КОРРЕКЦИЯ ПОСЛЕ СЛОЖЕНИЯ (AAA) ---
X86_T33
        db      $B0, $08                ; mov al, 8
        db      $B1, $04                ; mov cl, 4
        db      $00, $C8                ; add al, cl     (AL станет 12 = 0x0C)
        db      $37                     ; aaa            (AL станет 2, AH увеличится на 1, AF=1, CF=1)
        db      $F4                     ; hlt
X86_T33_E

; --- ТЕСТ 34: ДЕСЯТИЧНАЯ КОРРЕКЦИЯ ПОСЛЕ СЛОЖЕНИЯ (DAA) ---
X86_T34
        db      $B0, $35                ; mov al, 0x35   (Упакованный BCD: 35)
        db      $B1, $28                ; mov cl, 0x28   (Упакованный BCD: 28)
        db      $00, $C8                ; add al, cl     (AL станет 0x5D, некорректный BCD)
        db      $27                     ; daa            (AL скорректируется до 0x63, AF=1)
        db      $F4                     ; hlt
X86_T34_E

; --- ТЕСТ 35: СБРОС ФЛАГА ПРЕРЫВАНИЙ (CLI) ---
X86_T35
        db      $FA                     ; cli            (Флаг IF сбрасывается в 0, запрет прерываний)
        db      $F4                     ; hlt
X86_T35_E

; --- ТЕСТ 36: УСТАНОВКА ФЛАГА ПРЕРЫВАНИЙ (STI) ---
X86_T36
        db      $FB                     ; sti            (Флаг IF взводится в 1, разрешение прерываний)
        db      $F4                     ; hlt
X86_T36_E

; --- ТЕСТ 37: СОХРАНЕНИЕ РЕГИСТРА ФЛАГОВ В СТЕК (PUSHF) ---
X86_T37
        db      $BC, $00, $10           ; mov sp, 0x1000
        db      $9C                     ; pushf          (Флаги x86 улетают в гостевой стек, SP=0x0FFE)
        db      $F4                     ; hlt
X86_T37_E

; --- ТЕСТ 38: ВОССТАНОВЛЕНИЕ РЕГИСТРА ФЛАГОВ ИЗ СТЕКА (POPF) ---
X86_T38
        db      $BC, $FE, $0F           ; mov sp, 0x0FFE
        db      $9D                     ; popf           (Извлечение флагов гостя со стека, SP=0x1000)
        db      $F4                     ; hlt
X86_T38_E

; --- ТЕСТ 39: ДАЛЬНИЙ БЕЗУСЛОВНЫЙ ПЕРЕХОД (JMP FAR) ---
X86_T39
        db      $EA, $00, $02, $00, $20 ; jmp 0x2000:0x0200 (Загрузка CS=0x2000, IP=0x0200)
X86_T39_E

; --- ТЕСТ 40: ДАЛЬНИЙ ВЫЗОВ ПОДПРОГРАММЫ (CALL FAR) ---
X86_T40
        db      $BC, $00, $10           ; mov sp, 0x1000
        db      $9A, $05, $01, $00, $30 ; call 0x3000:0x0105 (Push старого CS, push старого IP)
X86_T40_E

; --- ТЕСТ 41: МЕЖСЕГМЕНТНЫЙ ВОЗВРАТ ИЗ ПОДПРОГРАММЫ (RET FAR) ---
X86_T41
        db      $BC, $FC, $0F           ; mov sp, 0x0FFC (Стек подготовлен под два слова)
        db      $CB                     ; retf           (Восстановление IP, затем восстановление CS)
X86_T41_E