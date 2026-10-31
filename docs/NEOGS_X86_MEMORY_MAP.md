# NeoGS GS105a — 8086 physical memory backend

Branch: `fix/neogs-upload-handshake`

## Address map

The initial x86 physical address space is 1 MiB (20-bit, `00000h..FFFFFh`).
It is mapped into NeoGS RAM with a fixed base of `010000h`:

| x86 physical | NeoGS physical | NeoGS 16 KiB page | Purpose |
|---|---:|---:|---|
| `00000h..03FFFh` | `10000h..13FFFh` | 4 | x86 page 0 |
| `04000h..07FFFh` | `14000h..17FFFh` | 5 | x86 page 1 |
| ... | ... | ... | ... |
| `FC000h..FFFFFh` | `10C000h..10FFFFh` | 67 | x86 page 63 |

**Correct endpoint:** 1 MiB beginning at `010000h` ends at `10FFFFh` (inclusive).
This reserves NeoGS pages 0 and 3 for the current Z80 firmware/stack and DMA
frame mapping. Pages 4..67 are within the first 2 MiB, so the initial 1 MiB
x86 region works even when an emulator configuration exposes 2 MiB; the
user's 4 MiB board leaves additional RAM available for later expansion.

## Window selection

The firmware enables `GSCFG0.NOROM` and `GSCFG0.EXPAG`, preserving the
other bits. In the Unreal Speccy GS-Z80 memory model, NOROM maps:
- Z80 window 0 (`0000h..3FFFh`) to NeoGS RAM page 0;
- Z80 window 1 (`4000h..7FFFh`) to NeoGS RAM page 3.

The backend uses `MPAGEX` (`10h`) to map one selected 16 KiB page into
Z80 window 3 (`C000h..FFFFh`). It deliberately uses MPAGEX rather than
MPAG, because MPAG can enforce even-page pairing in non-extended memory
configurations. MPAGEX is independently paged when EXPAG is enabled.

The GS-Z80 model stores the selected page as `ROL8(port_value,1)`; therefore
the backend writes `ROR8(page_number,1)` to MPAGEX. For an x86 physical
address `P`:

- x86 page index = `P >> 14` (0..63);
- NeoGS page index = `(P >> 14) + 4` (4..67);
- window offset = `P & 3FFFh`;
- Z80 pointer = `C000h + (P & 3FFFh)`.

Only window 3 changes during a memory access. Firmware/stack in window 0 and
the current DMA payload in window 1 remain mapped.

## Firmware API

Implemented in `neogs_sub/x86_memory.asm`:

- `x86_mem_init`: enable NOROM + EXPAG.
- `x86_mem_read8`: address in `x86_mem_addr[0..2]`; returns byte in A.
- `x86_mem_write8`: address in `x86_mem_addr[0..2]`, value in
  `x86_mem_value`.
- Invalid addresses above `FFFFFh` set carry.
- `x86_mem_test`: destructive test of 64 pages. It writes unique patterns
  to the first and last byte of each page, then verifies all 128 locations.

The self-test is exposed as private command `CMD_MEM_TEST = 05h`; the host
reads its result through the existing `CMD_GET_STATUS` frame:
- status 0, AX=0001h: all 64 pages passed;
- status 5, AX=`phase:page`: failure (phase 1/2 = write first/last byte;
  phase 3/4 = verify first/last byte).

## Important limitations

- This is a 1 MiB x86 RAM backend, not yet a complete 4 MiB x86 memory model.
- Byte access is implemented; word access and 16-bit offset wrap handling
  must be built on top of it before memory-operand instructions are added.
- The window and register behavior is based on the NeoGS port definitions
  and the Unreal Speccy GS-Z80 implementation. The new test is intended to
  validate it in the user's emulator. It is not a substitute for a physical
  GS105a hardware test.
- The memory self-test is destructive to NeoGS physical pages 4..67. It does
  not touch the firmware page 0 or the current DMA page 3.
