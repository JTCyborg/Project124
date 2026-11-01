# Project124 — 48 KiB NeoGS firmware layout: implementation design

Updated: 2026-11-02
Branch: main

## Purpose

Implement the project's 48 KiB firmware-image target without weakening existing memory-safety assertions or breaking the proven DMA/x86 runtime. This document is the implementation contract for the next code changes.

## Verified current source state

The following facts were verified directly against the current `main` sources:

| Area | Current implementation |
|---|---|
| Firmware origin/export | `neogs_sub/main.asm` starts at `ORG $0000`; `build_firmware.asm` exports bytes `[0, neogs_firmware_end)`. |
| Build-time limit | `build_firmware.asm` asserts `neogs_firmware_end <= $4000`. |
| Bootstrap limit | `bootstrap.asm` rejects a firmware length greater than `$4000`, then copies the stream linearly from logical address `$0000`. |
| Host limit | `zx_main/neogs_driver.asm` rejects a length greater than `$4000`. |
| Package limit | `pack_neogs.ps1` rejects firmware larger than `0x4000`; package itself is limited to `0xFF00`. |
| CI limit | `.github/workflows/project124-build.yml` rejects firmware larger than `0x4000`. |
| Firmware resident code | `neogs_sub/main.asm` currently keeps active Z80 firmware in fixed WIN0. |
| ROM return trampoline | Source routine is copied to logical `$4000`; the live trampoline is in WIN1. |
| DMA frame | Logical `$5000-$7FFF`, 12 KiB; WIN1 is physical page 3 and the DMA target is physical `$00D000`. |
| Z80 stack | Main firmware uses `SP=$BFFE` in WIN2/page 1; guard is `$B800-$B87F`. |
| x86 memory backend | `x86_memory.asm` switches WIN3 with MPAGEX for each 16 KiB x86 physical page; x86 pages 0..63 map to NeoGS pages 4..67. |

## Current 64 KiB logical map

The bootstrap currently configures:

| Logical window | Range | Current physical page | Current use |
|---|---:|---:|---|
| WIN0 | `$0000-$3FFF` | 0, fixed | Resident Z80 firmware |
| WIN1 | `$4000-$7FFF` | 3, fixed | `$4000` return trampoline area; `$5000-$7FFF` DMA frame |
| WIN2 | `$8000-$BFFF` | 1, via MPAG | Z80 stack at `$BFFE`; guard `$B800-$B87F` |
| WIN3 | `$C000-$FFFF` | 2 initially, then pages 4..67 via MPAGEX | x86 physical-memory access window |

The bootstrap itself is loaded at `$4000` by ROM command #14 and is currently executing from WIN1 while it receives the firmware. Therefore, a naive linear copy of a 48 KiB image starting at `$0000` would overwrite the currently executing bootstrap as soon as the stream reaches `$4000`. It would also overwrite the trampoline/DMA region and later conflict with the live stack/x86 window.

## Non-negotiable invariants

1. Do not replace `$4000` limits with `$C000` in isolation.
2. Do not overwrite the executing bootstrap before the last byte is received and validated.
3. Do not overwrite the DMA frame `$5000-$7FFF` while a DMA operation may be active.
4. Preserve the ROM return trampoline at `$4000` and its ability to return to stock ROM.
5. Preserve a valid Z80 stack across every bank switch, interrupt, IPC operation and x86 memory access.
6. Preserve WIN3/MPAGEX semantics used by `x86_memory.asm`; x86 RAM pages 4..67 must not alias firmware storage.
7. Preserve the existing REP/CPU/BIOS/INT/STACK guest regressions and their host PASS markers.
8. A build/CI PASS is not a NeoGS runtime PASS. Runtime acceptance requires a user-provided full device log.

## Implementation strategy

The 48 KiB image must become a bank-aware image, not a larger flat binary.

### Phase 0 — layout and toolchain contract (in progress)

- Verify exact NeoGS page-register semantics, page count and RAM-size response from the GS105a documentation / existing hardware source.
- Establish which physical pages are guaranteed by the ROM RAM probe and which are reserved for x86 pages 4..67.
- Establish a safe bootstrap staging location and a stack location that remain valid while the firmware banks are written.
- Define a versioned image header with explicit segment descriptors (destination page/window, destination offset, byte length, flags/entry metadata).
- Define overlap assertions for bootstrap, trampoline, DMA frame, Z80 stack/guard, resident firmware and x86 window.

### Phase 1 — segmented package and host transfer

- Keep the existing v1 flat-image format accepted for current <=16 KiB firmware.
- Add a v2 segmented-image format; never infer v2 from a larger length alone.
- Update the packer to emit deterministic segment records and validate exact total size, page bounds, overlap and package sector count.
- Update the Z80 host to parse the versioned header and stream segment payloads without storing the whole package in Spectrum RAM.
- Keep the existing reusable `$C000` 256-byte TR-DOS sector buffer and 255-sector TR-DOS file ceiling.
- Add host-side accounting for header bytes, segment bytes and total bytes acknowledged by GS.

### Phase 2 — NeoGS bootstrap receiver

- Relocate or redesign the bootstrap so it cannot be overwritten by incoming segments.
- Receive segment descriptors and payloads with bounded waits.
- Map only the destination bank required for the current segment; restore the bank state after writes.
- Reject malformed lengths, page numbers, overlapping reserved regions, unsupported flags and incomplete transfers with a defined error ACK.
- Do not jump to the resident entry until every segment is received and validated.

### Phase 3 — bank-aware resident runtime

- Keep a small fixed resident core responsible for IPC, interrupts, DMA, stack and bank switching.
- Put additional code/data in explicit banked segments and access them only through reviewed bank-call/data-window helpers.
- Ensure bank switches cannot strand the active stack, interrupt vectors, DMA frame or return trampoline.
- Keep the x86 WIN3/MPAGEX mapping independent from the firmware bank selector.
- Add guest regression coverage for banked call/return, nested calls, interrupts during banked execution, and x86 memory access while a banked routine is resident.

### Phase 4 — build, CI and runtime acceptance

- Enforce the 48 KiB total image limit consistently in assembler, packer, host and CI.
- Verify every segment's exact size and physical destination.
- Add package boundary tests at 16 KiB, 32 KiB and 48 KiB, including last partial sector.
- Run the full existing CI regression.
- Require a full Pentagon/NeoGS runtime log with explicit new banked-image PASS markers before marking runtime tasks PASS.

## Immediate implementation blocker

A correct final segment map cannot yet be asserted from the current source alone: the exact usable physical page inventory and the documented behavior of MPAG/MPAGEX under the target GS105a RAM configuration must be confirmed. The current code only proves the use of WIN0/page 0, WIN1/page 3, WIN2/page 1, WIN3/page 2 and x86 pages 4..67. It does not prove that any additional page is available for firmware overlays.

Until that is verified, no code change may enlarge the accepted firmware length. The first implementation deliverable is the versioned segment format and validation model, followed by a bootstrap staging design that is proven not to self-overwrite.

## Status

- [x] Current source limits and memory consumers audited.
- [x] Current logical/physical window map recorded.
- [x] Unsafe flat 48 KiB copy path identified.
- [ ] Confirm GS105a physical RAM page inventory and MPAG/MPAGEX semantics from primary documentation.
- [ ] Freeze v2 segment table and reserved-region map.
- [ ] Implement v2 packer and static validation.
- [ ] Implement host segmented transfer.
- [ ] Implement NeoGS segmented receiver/bootstrap.
- [ ] Implement bank-aware resident call/data access.
- [ ] CI boundary tests at 16/32/48 KiB.
- [ ] Full hardware runtime regression.
