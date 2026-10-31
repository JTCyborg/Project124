# 8086/8088 CPU Emulator — architecture and implementation plan

Target: Intel 8086/8088, 16-bit real-address mode, 20-bit physical address bus.
Execution host: NeoGS Z80 firmware on GS105a.
Project branch: `fix/neogs-upload-handshake`.

## Compatibility contract

- The initial target is the original 8086/8088 instruction set, not 80186+, 286 protected mode, or 386+.
- 16-bit general registers: AX, CX, DX, BX, SP, BP, SI, DI.
- Segment registers: ES, CS, SS, DS.
- IP and FLAGS.
- Physical address calculation: `(segment << 4) + offset`, reduced to 20 bits (A20 is always masked on original 8086/8088).
- Little-endian byte/word memory access.
- 8086 and 8088 share the programmer-visible instruction set; bus width and prefetch timing are not initially cycle-accurate.
- Initial emulator goal is instruction/functional compatibility, not exact bus timing or cycle accuracy.
- Undefined/reserved flag bits must not be treated as ordinary writable status flags. Exact per-instruction flag behavior will be documented and tested.
- Unsupported opcodes and invalid encodings terminate with an explicit emulator error, never execute arbitrary Z80 memory.

## Current baseline

The existing interpreter supports only `90 NOP`, `40 INC AX`, `B8 MOV AX,imm16`, and `F4 HLT`.
Its task image is currently loaded at logical NeoGS address `$5002`, with a two-byte length header at `$5000`. The current payload window is `$2FFE` bytes.
The existing CBIT/DBIT/DMA transport and command protocol are considered a working baseline and must remain isolated from CPU changes.

## Memory architecture — required design

8086 physical address space is 1 MiB, but NeoGS's current Z80 logical address map and the existing 12 KiB DMA execution window do not provide a flat 1 MiB array.
Implement a memory abstraction before adding instructions that access memory:
- `x86_phys_addr`: segment:offset to 20-bit physical address.
- `x86_mem_read8`, `x86_mem_read16`, `x86_mem_write8`, `x86_mem_write16`.
- A documented physical-memory backend with explicit region map and bounds checks.
- No instruction handler may directly dereference arbitrary Z80 addresses for an x86 physical address.
- Decide and document the supported physical RAM size and mapping from GS105a hardware before claiming full 1 MiB memory compatibility.
- Preserve correct 16-bit offset wrap behavior for accesses crossing offset FFFFh; do not silently substitute a flat 20-bit increment where the CPU wraps an offset within a segment.

## CPU state interface

Canonical CPU state must be separate from Z80 transport variables:
- AX, CX, DX, BX, SP, BP, SI, DI
- ES, CS, SS, DS
- IP, FLAGS
- halt state and exit/error status
- instruction budget / optional diagnostic counters

AX must no longer be conflated with the old `saved_z80_ax` transport/result variable. Keep an explicit compatibility bridge for the existing result frame until the CPU runner is migrated.

## Decoder design

- Fetch bytes through CS:IP and increment IP with 16-bit wrap.
- Prefix parser: segment overrides ES/CS/SS/DS, LOCK, REPNE, REP/REPE.
- ModR/M decoder for 16-bit 8086 addressing forms:
  BX+SI, BX+DI, BP+SI, BP+DI, SI, DI, BP (mod=00,r/m=110 means disp16), BX, plus disp8/disp16.
- Register/memory operand abstraction for 8-bit and 16-bit registers.
- Decode failures must be bounded and return a defined error status.

## Implementation milestones

1. **CPU state and flags** — register file, reset state, flag masks/helpers, state dump.
2. **Memory backend** — 20-bit address calculation, region map, safe byte/word access, boundary tests.
3. **Fetch/decode foundation** — instruction fetch, prefixes, ModR/M and effective address.
4. **Core data movement** — MOV forms, XCHG, LEA, segment-register moves, PUSH/POP.
5. **ALU and flags** — ADD/ADC/SUB/SBB/CMP, INC/DEC, AND/OR/XOR/TEST, NOT/NEG, shifts/rotates.
6. **Control flow** — conditional jumps, JMP, CALL/RET, LOOP/JCXZ, HLT, flag control.
7. **String and I/O** — MOVS/CMPS/STOS/LODS/SCAS, REP, IN/OUT.
8. **Interrupts** — INT n, INT3, INTO, IRET and a configurable interrupt-vector table.
9. **Remaining 8086 instructions and compatibility testing** — documented coverage matrix and regression suite.

Each milestone must include test programs with expected registers, flags, memory and exit status. Do not mark a milestone complete merely because it assembles.

## Non-goals for initial 8086/8088 target

- 80186/80188-only instructions.
- 80286 protected mode and descriptor tables.
- 32-bit registers, operand-size/address-size prefixes, paging, and 386+ instructions.
- Cycle-accurate 8086 prefetch queue and bus timing.

## Safety / integration constraints

- Keep the current ZX↔NeoGS CBIT/DBIT/DMA protocol unchanged unless a separately tested transport fix is necessary.
- Keep the existing diagnostic payload and result frame working throughout migration.
- Do not modify `zx_main/boot_loader.asm` without explicit user permission.
- Do not claim full 8086 compatibility until the opcode coverage matrix and test suite demonstrate it.
