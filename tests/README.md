# Project 124 x86 tests

`TEST.ASM` is the suite aggregator. It emits the X86T container header and
includes the category files under `tests/suites/`. NASM produces one
`TEST.BIN`, which is exported to TR-DOS as `TEST.C`.

## Test ID ranges

| ID range | Category | Current source |
|---|---|---|
| `0x0000–0x0FFF` | Decoder and malformed instruction cases | `suites/decoder.asm` |
| `0x1000–0x1FFF` | General registers and data movement | `suites/registers.asm` |
| `0x2000–0x2FFF` | FLAGS and condition evaluation | Planned |
| `0x3000–0x3FFF` | Arithmetic and logic | `suites/arithmetic.asm` |
| `0x4000–0x4FFF` | Control transfer and execution termination | `suites/control_flow.asm` |
| `0x5000–0x5FFF` | Segmented addressing and memory | Planned |
| `0x6000–0x6FFF` | Stack and procedure calls | Planned |
| `0x7000–0x7FFF` | Interrupts and exception paths | Planned |
| `0x8000–0x8FFF` | String and repeat instructions | Planned |
| `0x9000–0x9FFF` | I/O and system environment | Planned |

A category file contributes one or more records to the shared container.
Every record declares its own expected status, expected AX, and exact payload
length. The host runner does not know or depend on the internal implementation
of any x86 instruction.
