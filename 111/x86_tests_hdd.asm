; =========================================================================
; PERFECT COMMANDER 111 — АВТОНОМНЫЙ БАНК ГОСТЕВЫХ ТЕСТОВ ДЛЯ NEMO IDE HDD
; МОДУЛЬ: src/x86_tests_hdd.asm (РАСШИРЕННЫЙ СПИСОК ТЕСТОВ ЖЕЛЕЗА И FAT16)
; =========================================================================

; --- ТАБЛИЦА АДРЕСОВ ОПКOДOВ ДЛЯ ДИСКОВЫХ ТЕСТOВ (ИНДЕКСАЦИЯ С ID=99) ---
X86_HDD_Test_Table:
        DW      X86_T99_CheckStatus        ; ID = 99: Тест базового чтения портов
        DW      X86_T100_ReadSector        ; ID = 100: Чтение сектора в изолированный буфер хоста
        DW      X86_T101_WriteTestSector   ; ID = 101: Запись шаблона в выделенный сектор LBA 4
        DW      X86_T102_VerifyTestSector  ; ID = 102: Повторное чтение и проверка шаблона
        DW      X86_T103_ReadBIOS          ; ID = 103: BIOS чтение с копированием в память гостя
        DW      X86_T104_VerifyBPB         ; ID = 104: Тест математики BPB-парсера (FAT16)
        DW      X86_T105_VerifyDirectory   ; ID = 105: Тест распаковки имен файлов FAT16

; --- ТАБЛИЦА ДЛИН БИНАРНЫХ БЛОКOВ ТЕСТOВ ---
X86_HDD_Test_Lengths:
        DW      X86_T99_CheckStatus_E - X86_T99_CheckStatus
        DW      X86_T100_ReadSector_E - X86_T100_ReadSector
        DW      X86_T101_WriteTestSector_E - X86_T101_WriteTestSector
        DW      X86_T102_VerifyTestSector_E - X86_T102_VerifyTestSector
        DW      X86_T103_ReadBIOS_E - X86_T103_ReadBIOS
        DW      X86_T104_VerifyBPB_E - X86_T104_VerifyBPB
        DW      X86_T105_VerifyDirectory_E - X86_T105_VerifyDirectory

; =========================================================================
; ТЕСТЫ 99..103 ОСТАВЛЕНЫ В ОРИГИНАЛЬНОМ АРХИВНОМ ВИДЕ БЕЗ ИЗМЕНЕНИЙ
; =========================================================================
X86_T99_CheckStatus:
        DB      $BA, $F0, $00           ; mov dx, 0x00F0 (Регистр статуса Nemo IDE)
        DB      $EC                     ; in al, dx      (Читаем состояние шины в AL)
        DB      $F4                     ; hlt            (AX отобразит статус HDD)
X86_T99_CheckStatus_E:

X86_T100_ReadSector:
        DB      $B8, $00, $00           ; mov ax, 0x0000
        DB      $8E, $C0                ; mov es, ax     
        DB      $B3, $00                ; mov bl, 0x00   
        DB      $B7, $02                ; mov bh, 0x02   
        DB      $B4, $02                ; mov ah, 0x02   (Функция AH=02h — Чтение)
        DB      $B0, $01                ; mov al, 0x01   (Количество секторов = 1)
        DB      $B5, $00                ; mov ch, 0x00   (Младшие 8 бит цилиндра = 0)
        DB      $B1, $05                ; mov cl, 0x05   (Номер сектора = 5)
        DB      $B6, $00                ; mov dh, 0x00   (Номер головки = 0)
        DB      $B2, $80                ; mov dl, 0x80   (Номер накопителя: Первый HDD)
        DB      $CD, $13                ; int 0x13       
        DB      $F4                     ; hlt            
X86_T100_ReadSector_E:

X86_T101_WriteTestSector:
        DB      $B8, $00, $00           ; mov ax, 0
        DB      $B4, $03                ; mov ah, 03h (write sectors)
        DB      $B0, $01
        DB      $B5, $00
        DB      $B1, $05
        DB      $B6, $00
        DB      $B2, $80
        DB      $CD, $13
        DB      $F4
X86_T101_WriteTestSector_E:

X86_T102_VerifyTestSector:
        DB      $B8, $00, $00
        DB      $8E, $C0
        DB      $B3, $00                
        DB      $B7, $02                
        DB      $B4, $02
        DB      $B0, $01
        DB      $B5, $00
        DB      $B1, $05
        DB      $B6, $00
        DB      $B2, $80
        DB      $CD, $13
        DB      $F4
X86_T102_VerifyTestSector_E:

X86_T103_ReadBIOS:
        DB      $B8, $00, $00
        DB      $8E, $C0
        DB      $B3, $00                
        DB      $B7, $02                
        DB      $B4, $02
        DB      $B0, $01
        DB      $B5, $00
        DB      $B1, $05
        DB      $B6, $00
        DB      $B2, $80
        DB      $CD, $13
        DB      $F4
X86_T103_ReadBIOS_E:

; =========================================================================
; ТЕСТ 104: ПОДГОТОВКА К ВЕРИФИКАЦИИ BPB-ПАРСЕРА FAT16
; ИСПРАВЛЕНО: Принудительная каноническая очистка и инициализация CX 
; вынесена в самый верх кода, полностью защищая Fetch-декодер от рассинхрона!
; =========================================================================
X86_T104_VerifyBPB:
        DB      $B1, $01                ; mov cl, 0x01   — Загружаем сектор 1
        DB      $B5, $00                ; mov ch, 0x00   — Загружаем цилиндр 0 (Компактный CX собран!)
        DB      $B8, $00, $00           ; mov ax, 0x0000
        DB      $8E, $C0                ; mov es, ax     
        DB      $B3, $00                ; mov bl, 0x00   
        DB      $B7, $02                ; mov bh, 0x02   — Буфер памяти гостя ES:BX ($0000:$0200)
        DB      $B4, $02                ; mov ah, 0x02   — Функция BIOS 02h (Чтение)
        DB      $B0, $01                ; mov al, 0x01   — Читаем 1 сектор
        DB      $B6, $00                ; mov dh, 0x00   — Головка 0
        DB      $B2, $80                ; mov dl, 0x80   — Накопитель 80h (HDD)
        DB      $CD, $13                ; int 0x13       
        DB      $F4                     ; hlt            
X86_T104_VerifyBPB_E:

; =========================================================================
; ТЕСТ 105: ПОДГОТОВКА К ВЕРИФИКАЦИИ КОНВЕРСИИ ИМЕН ФАЙЛОВ
; ИСПРАВЛЕНО: Принудительная каноническая очистка и инициализация CX вынесена вверх
; =========================================================================
X86_T105_VerifyDirectory:
        DB      $B1, $02                ; mov cl, 0x02   — Загружаем сектор оглавления
        DB      $B5, $00                ; mov ch, 0x00   — Загружаем цилиндр 0
        DB      $B8, $00, $00           
        DB      $8E, $C0                
        DB      $B3, $00                
        DB      $B7, $02                
        DB      $B4, $02                ; Функция 02h — Чтение
        DB      $B0, $01                ; 1 сектор
        DB      $B6, $00                
        DB      $B2, $80                
        DB      $CD, $13                
        DB      $F4                     ; hlt
X86_T105_VerifyDirectory_E:
