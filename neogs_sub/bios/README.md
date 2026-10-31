# P124 BIOS — implementation stages

## Stage 1: low-memory foundation and POST

Implemented in `bios_core.asm`, called by the NeoGS command `CMD_BIOS_POST`
after the physical x86 RAM mapping test.

### Current behavior

1. Enables the existing 1 MiB x86 physical-memory mapping.
2. Clears physical addresses `00000h..004FFh`:
   - `00000h..003FFh`: 256-entry Interrupt Vector Table (IVT).
   - `00400h..004FFh`: BIOS Data Area (BDA).
3. Publishes the initial BDA profile:
   - conventional memory: 640 KiB at BDA `0413h`;
   - keyboard buffer head/tail: `001Eh`;
   - video mode: `03h`;
   - text columns: 80;
   - text page size: 4096 bytes;
   - active page: 0;
   - text rows: 25;
   - character height: 16.
4. Reads back the IVT boundary bytes and selected BDA fields.
5. Returns the normal P124 result frame with status 0 and AX signature `B105h`
   on success. POST errors use status 7 and AX `B1xxh`.

The host starts this POST through the existing command/data protocol. The
DMA/IPC transfer implementation and the external X86T test container are not
changed by this stage.

## Explicit limitations

Stage 1 is a memory-layout foundation, not a bootable IBM PC BIOS yet:

- IVT is cleared but service vectors are not installed.
- No executable BIOS ROM is mapped at `F0000h..FFFFFh`.
- ROM write protection is not implemented.
- x86 `INT` / `IRET` execution semantics are not implemented by this stage.
- INT 10h, 13h, 16h and 1Ah services are not yet available.
- Video, keyboard, disk and RTC device backends are not yet exposed through
  guest-visible BIOS calls.

These are deliberate boundaries. The next stage must first implement and
test the 8086 interrupt entry/return path and the guest stack semantics. Only
then should IVT entries point to BIOS service handlers.

## Memory map proposal

| Physical range | Purpose | Stage 1 status |
|---|---|---|
| `00000h..003FFh` | IVT | Cleared / reserved |
| `00400h..004FFh` | BDA | Initialized / selected fields verified |
| `00500h..9FFFFh` | Conventional RAM profile | Reserved by map; allocator not implemented |
| `A0000h..BFFFFh` | Video memory | Reserved only |
| `C0000h..EFFFFh` | Option ROM / device window | Reserved only |
| `F0000h..FFFFFh` | P124 BIOS ROM | Reserved only |

The physical memory backend still maps the complete 1 MiB as RAM. The table
above is the guest-visible layout contract being established; it is not yet
hardware-enforced memory protection or ROM shadowing.
