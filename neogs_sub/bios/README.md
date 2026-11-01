# P124 BIOS — implementation stages

## Stage 1: low-memory foundation and POST

Implemented in `bios_core.asm`, called by `CMD_BIOS_POST` after the physical
x86 RAM mapping test.

POST initializes the 1 MiB real-mode memory backend, clears IVT/BDA, publishes
the initial 640 KiB / 80x25 text-mode profile, verifies the IVT and selected
BDA fields, then installs IVT vector 10h as a firmware service trap at
`0000:5200`. The POST result remains status 0 / AX=`B105h`.

The 80x25 values are the initial POST profile. When a guest calls INT 10h,
AH=00h, AL=03h, Stage 3A changes the active project console profile to 42x12.

## Stage 2A: real-mode interrupt frame

`x86_interrupt.asm` implements the architectural INT/IRET frame:

- `x86_int_enter` reads the IVT entry, pushes FLAGS, CS, then IP, clears IF
  and TF, and loads the target CS:IP.
- `x86_iret_return` restores IP, CS and FLAGS from SS:SP.
- The self-test installs a temporary vector 20h, checks the exact frame,
  verifies IF/TF clearing and full register/stack restoration, then removes
  the temporary vector.

Host command: `08h`. Expected result: status 0 / AX=`1A01h`.

## Stage 2B: guest handler execution

`x86_real_mode.asm` adds a separate CS:IP fetch/execute path and executes
a guest INT 20h handler through the real-mode memory backend. The limited
instruction set at this stage includes NOP, INC r16, DEC r16, PUSH r16, POP r16, MOV r8,imm8,
MOV r16,imm16 (all eight general registers), short conditional branches
(JO/JNO, JB/JAE, JE/JNE, JBE/JA, JS/JNS, JP/JNP, JL/JGE, JLE/JG),
LOOPNZ/LOOPZ/LOOP/JCXZ, JMP rel8, HLT, INT imm8, INT 3 and IRET.

The self-test runs the guest caller at `0000:5002` and handler at `0000:5100`. It verifies the MOV immediate register paths, `INC SI` (`7FFFh` to
`8000h`) and `DEC DI` (`8000h` to `7FFFh`), including OF/SF/ZF/AF/PF
behavior and CF preservation. The control-flow sequence checks a backward
`LOOP` (CX reaches zero), `JCXZ`, `JMP rel8`, and representative
taken/not-taken `Jcc` cases (JNZ, JZ, JO, JB and JL). These instructions
must preserve FLAGS.

The stack regression exercises `PUSH r16` and `POP r16` for the general
registers, checks that the register values are restored and that SP balances,
verifies the original 8086 `PUSH SP` behavior (the pre-decrement SP value is
pushed), and verifies that `POP SP` replaces SP with the popped word. Stack
words are accessed through SS:SP and the physical-memory backend; a PUSH/POP
pair also crosses the SS:FFFFh-to-SS:0000h offset boundary. Stack instructions
must preserve FLAGS.

After the INT 20h handler changes AX to `1234h` and IRET returns, the test
checks the post-HLT IP using the assembled guest-image length, FLAGS=`0B16h`,
SP=`0100h`, and the retained register values. CX is expected to be `0000h`
after LOOP. The expected return IP is computed at assembly time. The final stack probes leave DX=`0100h` (8086 PUSH SP result) and BP=`00F0h` (POP SP result observed by a following PUSH SP); CX remains `0000h` after LOOP.
Host command: `09h`. Expected result: status 0 / AX=`1A02h`.

## Stage 3A: BIOS INT 10h text services

Implemented in `bios_video.asm`. The guest executes INT 10h through the
normal IVT lookup and interrupt stack frame. The service itself is a firmware
trap; it returns through the normal IRET primitive. This is not an executable
IBM PC BIOS ROM.

Supported functions:

| AH | Function | Project behavior |
|---|---|---|
| `00h` | Set video mode | Supports AL=`03h`; selects the project 42x12 console and clears it |
| `0Fh` | Get video mode | Returns AL=`03h`, AH=42 columns, BH=0 |
| `02h` | Set cursor | Page zero only; DH=row 0..11, DL=column 0..41 |
| `03h` | Get cursor | Returns DH=row, DL=column for page zero |
| `0Eh` | Teletype output | Sends AL through the host stream; supports printable ASCII, CR, LF, BS and BEL |

The project console intentionally differs from standard IBM mode 03h geometry:
it uses 42 columns x 12 rows, 6x8 glyphs, and the existing lower Spectrum
debug window. The BDA mode/column/page/row/character-height fields are updated
to match this project profile when AH=00h, AL=03h is called.

### Host display and emulator log

The NeoGS firmware sends teletype bytes over the existing DBIT/GSDAT channel
while the Spectrum host polls the channel. Each nonzero character is sent to
printer/debug port `#EF` and drawn in the existing lower debug window.

The new `zx_main/bios_console.asm` renderer uses `font68.bin` (768 bytes,
96 glyphs x 8 scanlines). Six pixels are packed per character, giving exactly
42 columns across 252 of the Spectrum's 256 horizontal pixels. The console
has 12 rows and uses the existing lower-window scroll path. The existing
32-column Commander renderer is not replaced.

Stream control frames are:

- `00 00`: clear the lower debug console;
- `00 01 row col`: set the lower debug-console cursor;
- any nonzero byte: teletype character.

Host command `0Ah` runs the Stage 3A guest self-test. It exercises all five
INT 10h functions, cursor round-trip, 43-character wrap, CR/LF, and the live
stream-to-port-`#EF` / 6x8-screen path. Expected result: status 0 /
AX=`1A10h`, DX=`020Fh`, BDA cursor=`020Fh`.

## Real-mode TR-DOS task execution

Host command `0Bh` executes the loaded TR-DOS payload through the CS:IP
executor. The payload is copied from the DMA window into the x86 physical
memory backend at `0000:5002`. Instruction fetches are bounded to the loaded
payload and the current task entry uses CS=0.

The legacy linear interpreter remains available for the transport/edge-case
diagnostics. The real-mode executor currently supports NOP, INC r16, DEC r16, MOV
r16,imm16 for AX/CX/DX/BX/SP/BP/SI/DI, MOV r8,imm8 (including the standard
AH/AL BIOS calling convention), all short Jcc conditions (70h-7Fh),
LOOPNZ/LOOPZ/LOOP/JCXZ (E0h-E3h), JMP rel8 (EBh), HLT, INT imm8, INT 3
and IRET. INC/DEC update OF/SF/ZF/AF/PF, preserve CF, and retain all other
FLAGS bits. PUSH/POP use SS:SP and do not modify FLAGS. LOOP-family instructions preserve FLAGS; Jcc tests the
architectural CF/PF/ZF/SF/OF bits. Relative targets are computed from IP
after the displacement byte, and the next instruction fetch remains bounded
to the loaded task image. It is not a complete 8086 emulator.

## Memory map and limitations

| Physical range | Purpose | Status |
|---|---|---|
| `00000h..003FFh` | IVT | Cleared at POST; vector 10h installed |
| `00400h..004FFh` | BDA | Initial profile verified; INT 10h updates text fields |
| `00500h..9FFFFh` | Conventional RAM | Memory backend available; allocator not implemented |
| `A0000h..BFFFFh` | Video memory | Reserved; not used by the project console |
| `C0000h..EFFFFh` | Option ROM/device window | Reserved only |
| `F0000h..FFFFFh` | P124 BIOS ROM | Reserved; no executable ROM mapped |

The physical memory backend still maps the complete 1 MiB as RAM. There is no
ROM write protection, no complete IBM PC BIOS ROM, and no full 8086 execution.
INT 13h, INT 16h and INT 1Ah are not implemented. The current video backend
supports only the listed INT 10h functions and page zero.
