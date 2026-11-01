# Project124 — XT BIOS opcode compatibility matrix

Дата: 2026-11-01. Ветка: main.

Область аудита: `bios/bios.asm` против активного 8086 executor `neogs_sub/x86_real_mode.asm`, `x86_real_alu.asm`, `x86_real_alu8.asm`, `x86_real_mov.asm`, `x86_interrupt.asm`. Legacy `x86_interpreter.asm` не учитывается.

**Статусы:** YES — есть decoder route и исполнитель; PARTIAL — поддержана часть форм; NO — отсутствует рабочий маршрут; NOT VERIFIED — требуется сверка с фактическим ROM disassembly. Это статическая матрица по исходникам, не runtime-подтверждение BIOS.

## A. Текущая поддержка активного ядра

| Семейство | Opcode | Статус | Границы |
|---|---|---|---|
| NOP | 90 | YES | XCHG AX,AX также эквивалентен NOP |
| MOV r8,imm8 | B0-B7 | YES | Только immediate в byte-регистр |
| MOV r16,imm16 | B8-BF | YES | Только immediate в word-регистр |
| MOV r/m8,r8 и r8,r/m8 | 88,8A | PARTIAL | Общий EA decoder; ModR/M forms |
| MOV r/m16,r16 и r16,r/m16 | 89,8B | PARTIAL | Общий EA decoder; ModR/M forms |
| ALU byte ModR/M | 00,02,08,0A,10,12,18,1A,20,22,28,2A,30,32,38,3A | PARTIAL | ADD/OR/ADC/SBB/AND/SUB/XOR/CMP; ModR/M |
| TEST byte | 84 | PARTIAL | ModR/M |
| ALU word ModR/M | 01,03,11,13,19,1B,29,2B,39,3B | PARTIAL | ADD/ADC/SBB/SUB/CMP; ModR/M |
| Logical word ModR/M | 09,0B,21,23,31,33 | PARTIAL | OR/AND/XOR |
| TEST word | 85 | PARTIAL | ModR/M |
| INC/DEC r16 | 40-4F | YES | Не включает FE/FF memory/register group |
| PUSH/POP r16 | 50-5F | YES | SS:SP backend |
| PUSHF | 9C | YES | POPF (9D) отсутствует |
| Jcc short | 70-7F | YES | Все 16 условий |
| LOOPNZ/LOOPZ/LOOP/JCXZ | E0-E3 | YES | CX/ZF semantics |
| CALL near / RET near | E8/C3 | YES | Stack-backed |
| CALL far / RETF / JMP far | 9A/CB/EA | YES | Far immediate control flow |
| JMP short | EB | YES | rel8 |
| INT imm8 / INT3 / IRET | CD/CC/CF | YES | Существующий interrupt path |
| HLT | F4 | YES | Завершает текущий execution slice |
| Segment overrides | 26/2E/36/3E | YES | ES/CS/SS/DS |

**Важно:** ALU и MOV поддержаны не во всех формах. В частности, наличие 88/89/8A/8B не означает поддержки MOV Sreg, moffs, LEA/LES/LDS или immediate-to-memory.

## B. BIOS source: обнаруженные отсутствующие группы

| Инструкция/группа | Opcode | Статус |
|---|---|---|
| IN AL/AX,imm8 | E4/E5 | PARTIAL | Decoder implemented; test-port backend only; build/runtime pending |
| OUT imm8,AL/AX | E6/E7 | PARTIAL | Decoder implemented; test-port backend only; build/runtime pending |
| IN AL/AX,DX | EC/ED | PARTIAL | Full 16-bit DX decode; test-port backend only; build/runtime pending |
| OUT DX,AL/AX | EE/EF | PARTIAL | Full 16-bit DX decode; test-port backend only; build/runtime pending |
| MOVSB/MOVSW | A4/A5 | NO |
| CMPSB/CMPSW | A6/A7 | NO |
| STOSB/STOSW | AA/AB | NO |
| LODSB/LODSW | AC/AD | NO |
| SCASB/SCASW | AE/AF | NO |
| REP/REPE/REPNE prefixes | F3/F2 | NO |
| MOV accumulator,moffs | A0-A3 | NO |
| TEST AL/AX,imm | A8/A9 | NO |
| ALU accumulator,imm | 04/05,0C/0D,14/15,1C/1D,24/25,2C/2D,34/35,3C/3D | NO |
| ALU immediate group | 80/81/83 | NO |
| XCHG AX,r16 | 91-97 | NO |
| XCHG r/m,reg | 86/87 | NO |
| LEA | 8D | NO |
| LES/LDS | C4/C5 | NO |
| MOV Sreg | 8C/8E | NO |
| XLAT | D7 | NO |
| MUL/IMUL/DIV/IDIV, NOT/NEG | F6/F7 groups | NO |
| INC/DEC r/m | FE/FF groups | NO |
| SHL/SHR/SAR/ROL/ROR/RCL/RCR | D0-D3,C0/C1 | NO |
| DAA/DAS/AAA/AAS/AAM/AAD | 27/2F/37/3F/D4/D5 | NO |
| CLC/STC/CMC/CLD/STD/CLI/STI | F8-FD | NO |
| POPF | 9D | NO |
| INTO | CE | NO |
| WAIT | 9B | NO |
| LOCK prefix | F0 | NO |
| CBW/CWD | 98/99 | NO |
| RET imm16 / RETF imm16 | C2/CA | NO |

Исходный BIOS содержит мнемоники IN/OUT, строковые операции с REP, XLAT, MUL/DIV, LES/LDS, XCHG, PUSHF/POPF, WAIT, shifts/rotates, DAA, LOCK, INTO и flag-control. Это подтверждает потребность в перечисленных группах, но не утверждает, что каждая из них выполняется на каждом POST path.

### CPU-I/O-01 implementation note (2026-11-01)

- Added active decoder routes for E4-E7 and EC-EF and new `neogs_sub/x86_io.asm` backend.
- Current backend models only guest port 00E0h as a deterministic 16-bit test register. Unmapped IN returns FFh/FFFFh; unmapped OUT is ignored. This is a CPU test device, not a model of PC/XT PIC/PIT/PPI/CRT/FDC/UART.
- Added guest regression programs for all eight IN/OUT forms, full 16-bit DX non-aliasing (01E0h differs from 00E0h), and preservation of guest FLAGS.
- Source integration is committed, but assembler build and NeoGS runtime have not been run. Opcode rows remain PARTIAL until build and runtime evidence exists.

## C. Аппаратные зависимости PC/XT I/O

| Порт/диапазон | Устройство | Требуемая базовая модель |
|---|---|---|
| 20h-21h | 8259 PIC | IMR, IRR/ISR, EOI |
| 40h-43h | 8253 PIT | счётчики/режимы, используемые BIOS |
| 60h-64h | PPI/keyboard interface | data/status/system control |
| 61h | PPI system control | latch bits, speaker/timer gate |
| 3B4h-3B5h | MDA CRTC | index/data |
| 3B8h | MDA mode control | mode/display enable |
| 3BAh | MDA status | status/retrace |
| 3D4h-3D5h | CGA CRTC | index/data |
| 3D8h-3D9h | CGA mode/color | mode/color latches |
| 3DAh | CGA status | status/retrace |
| 3F0h-3F7h | FDC | status/data/DOR/DIR/CCR |
| 3F8h-3FFh | COM1 UART | data/divisor/IER/IIR/LCR/MCR/LSR/MSR |
| 378h-37Ah | LPT1 | data/status/control |

Это базовый PC/XT device checklist, а не окончательный список всех портов, встречающихся в BIOS. Перед реализацией устройств нужно извлечь фактические константы портов из source/listing и определить используемые ветви POST.

## D. План реализации

1. CPU-I/O-01: decoder E4-E7 и EC-EF, byte/word, imm8/DX, 16-bit port address, отдельный guest I/O bus. Никакого прямого обращения к физическим портам Z80/NeoGS.
2. CPU-I/O-02: тестовый guest port device и regression на IN/OUT; проверка AL/AX, DX, imm8, сохранения FLAGS и прочих регистров.
3. CPU-STR-01: MOVS/LODS/STOS/CMPS/SCAS без REP, корректные SI/DI/CX/DF и сегментные правила.
4. CPU-STR-02: REP/REPE/REPNE с CX, ZF, step limit.
5. CPU-ARITH-01: immediate ALU и F6/F7.
6. CPU-SHIFT-01: shift/rotate groups.
7. CPU-FLAGS-01: POPF, LAHF/SAHF, CLC/STC/CMC/CLD/STD/CLI/STI, INTO.
8. BIOS-IO-01: MDA/CGA, PIT/PIC, PPI/keyboard и FDC — по фактически используемым BIOS портам.
9. После каждой группы: SjASMPlus build, firmware size/ASSERT, guest regression и NeoGS runtime log.

## E. Критерии PASS

- YES ставится только при наличии decoder route, реализации и регрессионного теста.
- PARTIAL обязан перечислять поддержанные и отсутствующие формы.
- BIOS POST PASS — только после запуска оригинального 8-КБ ROM с CS:IP=FFFF:0000 и подтверждения фактического выполнения POST/I/O.
- Статический аудит не заменяет сборку и runtime test.
