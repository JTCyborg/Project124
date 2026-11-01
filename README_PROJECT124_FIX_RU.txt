PROJECT 124 — ПАКЕТ ИСПРАВЛЕНИЙ ИЗ ИСХОДНИКОВ
================================================

Статус
------
Это исправленный набор исходников, а не подтверждённая сборка/прошивка.
В текущем контейнере нет установленного sjasmplus и нет физической NeoGS,
поэтому ассемблирование и аппаратный запуск здесь НЕ заявляются как выполненные.
Перед записью в реальную карту обязательно собрать у себя и проверить вывод
ассемблера без ошибок.

Что исправлено
--------------

1. Первичная загрузка прошивки NeoGS (Stage 2)
   - Основной Z80-хост один раз ищет TR-DOS файл neoprog.C и читает его
     сектора в буфер #C000. Формат файла:
       WORD bootstrap_length (little-endian), bootstrap bytes, firmware bytes.
   - В proj124.C не встроены ни bootstrap, ни основная прошивка NeoGS.
   - Существующий Stage 2 выполняет штатный ROM handshake GS105a:
       #F4 Cold restart
       #20 Get total RAM; чтение трёх байт подтверждает готовность ROM
       #14 RECEIVE BLOCK — передача bootstrap в NeoGS RAM #4000
       #13 JUMP — запуск bootstrap по адресу #4000
       #A1 — bootstrap готов принимать основной образ
       передача длины firmware и ожидание #A3
       передача firmware из того же буфера #C000 в NeoGS RAM #0000
       #A2 — подтверждение запуска основной прошивки.
   - Bootstrap и firmware — две части одного neoprog.C; отдельного второго
     TR-DOS чтения и дополнительного файлового загрузчика нет.
   - При ошибке Stage 2 останавливает запуск и выводит фазу, GSSTAT,
     последний принятый байт и число переданных байтов через порт #EF.

2. Размещение NeoGS Z80 firmware
   - Основная прошивка собирается с ORG $0000; стек расположен на $3FFF.
   - Bootstrap собирается отдельно для загрузки в RAM NeoGS по адресу $4000.
   - Build script создаёт промежуточные neogs_code.bin и neogs_bootstrap.bin,
     затем объединяет их в один пакет neoprog.bin:
       [WORD bootstrap_length][bootstrap][firmware].
   - В TR-DOS экспортируется только единый NeoGS-файл neoprog.C.
   - Ни bootstrap, ни основная прошивка не входят в proj124.C.

3. DMA и x86-пayload
   - DMA frame имеет вид: [length_lo][length_hi][x86 bytes].
   - Frame загружается по логическому адресу NeoGS $5000 (физический $00D000).
   - x86 выполнение начинается с $5002.
   - Исполняемое окно $5002-$7FFF — 12 KiB; максимальный payload $2FFE.
   - Два байта заголовка и payload передаются двумя последовательными LDIR,
     чтобы все DMA-записи шли обычными циклами записи памяти Spectrum.
   - Время ожидания окончания DMA на NeoGS увеличено.
   - Интерпретатор проверяет конец файла перед каждым opcode и перед чтением
     двух immediate-байтов инструкции B8. Добавлен статус 4 для выхода за границы
     / обрезанной инструкции.

4. TR-DOS
   - После C=#0A (поиск имени) выполняется C=#08 (чтение полного дескриптора).
   - Длина, число секторов и первый сектор проверяются ДО чтения.
   - Проверяется равенство sector_count = ceil(file_length / 256).
   - Для x86-задач размер ограничен $2FFE; NeoGS package Stage 2 отдельно
     ограничен 16 KiB и читается в #C000 без переполнения.
   - Перед C=#08/C=#05 очищаются и после операции проверяются оба байта
     результата TR-DOS: #5D0F/#5D10.
   - В file_utils исправлены счётчик и стек при пропуске неверной записи.
   - Исправлена заливка атрибутов в Refresh_Panel_Directory: DE теперь задан.
   - Размер каталожного файла в KB округляется вверх без 8-битного переполнения.
   - Проверяются границы CursorY и пустые/недопустимые записи.

5. BASIC boot loader
   - В строке 20 удалён REM, который превращал LOAD в комментарий.
   - LOAD и CODE записаны токенами BASIC (#EF и #AF), а не ASCII-словами.

6. Шрифты
   - font68.bin собран из сохранённого zx_6x8_768.bin (768 байт).
   - font88.bin — printable ASCII 32..127, извлечённый из
     zx_spectrum_6x8.bin (2048 байт) по 8 байт на символ; итог 768 байт.
   - Это соответствует индексации ui_engine: (ASCII - 32) * 8.

7. Область памяти Spectrum
   - ASSERT ProgramEnd <= #A800 оставляет не менее 2 KiB между концом
     proj124.C и стеком приложения, растущим вниз от #AFFF.

Сборка
------
Из корня проекта вручную (если SjASMPlus находится в tools):

  ./tools/sjasmplus -I neogs_sub -I shared neogs_sub/build_firmware.asm
  powershell -ExecutionPolicy Bypass -File .\\pack_neogs.ps1
  ./tools/sjasmplus -I zx_main -I shared -I neogs_sub zx_main/main.asm

ВАЖНО: не собирайте neogs_sub/main.asm отдельной командой как первый этап.
Этот файл создаёт только основную Z80-прошивку и НЕ создаёт neogs_bootstrap.bin.
Оба промежуточных бинарника (neogs_code.bin и neogs_bootstrap.bin) создаёт
neogs_sub/build_firmware.asm. Затем pack_neogs.ps1 формирует neoprog.bin.
Только после этого собирается zx_main/main.asm.

Нужен SjASMPlus 1.21 или новее (рекомендуется 1.24.0), поскольку в сборке
используются include paths также для INCBIN. Либо одной командой в PowerShell:

  powershell -ExecutionPolicy Bypass -File .\build_project124.ps1

Ожидаемые результаты:
  neogs_code.bin
  neogs_bootstrap.bin
  neoprog.bin
  zx_main/neogs_code.bin
  zx_main/neogs_bootstrap.bin
  zx_main/neoprog.bin
  disk_A.trd

font88.bin и font68.bin уже включены в пакет в корне и zx_main/.

Если сборка запускается с другим рабочим каталогом, проверьте разрешение
относительных INCLUDE/INCBIN путей; обе копии NeoGS BIN создаются намеренно.

Важное ограничение x86
----------------------
В текущем проекте нет исходника полноценного x86-ядра. Файл x86task.C
собирается из шестибайтного диагностического теста:
  B8 AA BB 40 90 F4
Интерпретатор поддерживает только NOP, INC AX, MOV AX,imm16 и HLT.
Это проверка цепочки TR-DOS -> DMA -> NeoGS interpreter, а не полноценная
операционная система или совместимый 8086 CPU.

Аппаратная проверка после сборки
--------------------------------
1. Убедиться, что Stage 2 проходит все фазы и появляется ACK #A2.
2. Убедиться, что диагностический x86-тест возвращает STATUS=0, AX=#BBAB.
3. После этого проверять Stage 5 и чтение x86task.C с TR-DOS.
4. При сбое сохранить полный лог порта #EF, особенно BOOT PHASE и GSSTAT.

Статусы x86 interpreter:
  0 — HLT / успешное завершение
  1 — исчерпан лимит инструкций
  2 — неподдерживаемый opcode
  3 — ошибка DMA
  4 — неверная длина / IP за концом payload / обрезанный immediate

Неизменённые файлы
------------------
debug_system.asm, driver_cmos.asm, log_debug.asm, display.asm, ui_engine.asm и
ui_panels.asm включены из последнего сохранённого дампа проекта и не изменялись.
Если в рабочей папке есть более новые версии этих шести файлов, сохраняйте свои
версии и заменяйте только перечисленные в PATCH_MANIFEST.txt файлы.

Источники по загрузке GS/NeoGS
------------------------------
General Sound Programming Guide (команды #00/#30/#D1/#D2/#31, DBIT/CBIT):
https://zxpress.ru/ru/ezines/think/29-5/rukovodstvo-po-programmirovaniyu-zvukovoy-karty-general-sound-dlya-zx-spectrum-tehnicheskie

NeoGS / GS105a discussion (resident code at $5B00, DAC region $6000-$7FFF,
small bootstrap loading the main image at $0000):
https://dlcorp.nedopc.com/viewtopic.php?f=31&t=271
