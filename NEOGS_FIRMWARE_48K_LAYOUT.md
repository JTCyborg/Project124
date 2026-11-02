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

## Confirmed NeoGS page-register model

The memory map is four independently mapped 16 KiB windows. The authoritative register table recorded from the current NeoGS FPGA documentation in the Unreal-ng NeoGS TDD is:

- `PG0..PG3` are write-only raw page registers at ports `#20..#23`; reset defaults include PG0=0 and PG1=3.
- In `GSCFG0.EXPAG=1`, `MPAG` (port `#00`) selects PG2 (WIN2 / `$8000-$BFFF`) and `MPAGEX` (port `#10`) independently selects PG3 (WIN3 / `$C000-$FFFF`).
- The encoded page is the 8-bit rotate-left form: page 1 is selected by writing `#80` to MPAG; page 2 by writing `#01` to MPAGEX. This matches the existing bootstrap.
- The NeoGS FPGA map has 256 physical 16 KiB pages (4 MiB); 2 MiB boards mirror the upper half, leaving pages 0..127 unique. The Project124 x86 backend consumes pages 4..67. Pages 68 and 69 are therefore available on both supported 2 MiB and 4 MiB layouts, subject to validating the RAM-size response before loading the v2 image.

Primary-source trail used for this correction: `neogs-tdd.md` §3.2 and §3.3 in `alfishe/unreal-ng`, which records the current FPGA `memmap.v` / `ports.v` behavior; the emulator implementation independently models the four windows and MPAG/MPAGEX. This supersedes the earlier assumption that WIN2 was permanently fixed to page 1.

## Current 64 KiB logical map and first banked layout

Bootstrap mapping and resident runtime are now intentionally distinct:

| Logical window | Range | Bootstrap mapping | Resident runtime mapping / use |
|---|---:|---:|---|
| WIN0 | `$0000-$3FFF` | PG0/page 0 | PG0/page 0: fixed resident firmware (v1 image remains here) |
| WIN1 | `$4000-$7FFF` | PG1/page 3 | PG1/page 3: trampoline at `$4000`; new resident stack at `$4FFE`, guard `$4800-$487F`; DMA frame `$5000-$7FFF` |
| WIN2 | `$8000-$BFFF` | PG2/page 1 via MPAG | PG2/page 68 or 69 via MPAG: banked firmware overlay window |
| WIN3 | `$C000-$FFFF` | PG3/page 2 via MPAGEX | PG3 pages 4..67 via MPAGEX: x86 physical-memory access window |

The bootstrap itself is loaded at `$4000` by ROM command #14 and executes from WIN1 while receiving the firmware. Its temporary stack is `$FFFE` in WIN3/page 2. It can safely receive a segmented v2 image into PG0 and bank pages mapped through WIN2, because neither operation overwrites its executing WIN1 code or temporary WIN3 stack. Once the resident firmware starts, it sets PG1=3 and relocates its operational stack to `$4FFE` in WIN1. This frees WIN2 for banked overlays while MPAGEX continues to own WIN3 for x86 RAM.

A flat 48 KiB copy starting at `$0000` is still invalid: it overwrites the bootstrap at `$4000`, the trampoline/DMA region in WIN1 and runtime-reserved memory. The v2 image must explicitly identify a resident segment and banked segments; the loader maps each segment to its own physical page.

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
- [x] Confirm four-window PG0-PG3 map and EXPAG MPAG/MPAGEX semantics from the current NeoGS FPGA documentation model.
- [x] Identify non-overlapping firmware overlay pages 68 and 69 beyond the x86 backend's pages 4..67 (2 MiB minimum board layout).
- [x] Relocate the resident Z80 stack from WIN2/page 1 to WIN1/page 3 at #4FFE, freeing WIN2 for firmware overlays; source implementation committed, build/runtime pending.
- [ ] Freeze v2 segment table and reserved-region map, including RAM-size guard >= 70 * 16 KiB.
- [ ] Implement v2 packer and static validation.
- [ ] Implement host segmented transfer.
- [ ] Implement NeoGS segmented receiver/bootstrap.
- [ ] Implement bank-aware resident call/data access.
- [ ] CI boundary tests at 16/32/48 KiB.
- [ ] Full hardware runtime regression.

## 2026-11-02 implementation update — WIN2 released for firmware banks

- New source evidence from the NeoGS FPGA documentation model resolved the earlier page-inventory blocker: PG0-PG3 are independently addressable; EXPAG enables MPAG -> PG2/WIN2 and MPAGEX -> PG3/WIN3. NeoGS has 256 16-KiB pages on 4-MiB boards; 2-MiB boards mirror pages 128..255, so pages 68 and 69 remain uniquely addressable on both 2-MiB and 4-MiB boards.
- Project124's x86 backend already reserves pages 4..67. Firmware overlay pages 68 and 69 do not alias that x86 range.
- The resident stack was moved in source from WIN2/page 1 at #BFFE to WIN1/page 3 at #4FFE. The 128-byte guard moved from #B800..#B87F to #4800..#487F. DMA remains at #5000..#7FFF, trampoline remains at #4000, and WIN3/MPAGEX remains dedicated to x86 RAM.
- Startup now explicitly restores PG1=3 while still using the bootstrap's temporary WIN3 stack, then relocates SP to #4FFE. Later PG1 writes in the current source also select page 3, so they preserve the active stack.
- Updated comments/contracts in `main.asm`, `build_firmware.asm`, `bootstrap.asm`, `x86_memory.asm`, `neogs_driver.asm`, and `pack_neogs.ps1`.
- Added assembler assertions for trampoline/guard/stack/DMA non-overlap.
- This is the first code implementation step toward 48 KiB, not yet a 48-KiB loader: the v1 flat-image limit remains 16 KiB until v2 segments, RAM-size validation, bootstrap receiver, packer, host driver and CI are implemented together.
- Build and hardware runtime have not yet been run for this stack relocation. Require CI build plus a full Pentagon/NeoGS log; the stack guard PASS must now prove the new #4800..#487F region.

## 2026-11-02 — STACK-02 CI result

- Source changes and the updated host marker were built by GitHub Actions run [41365093478](https://github.com/JTCyborg/Project124/actions/runs/41365093478), commit `779d47402ccb4533109a118dd71ada8de9f6518e`.
- Firmware build, package/host/TR-DOS build, verification and artifact upload all completed successfully.
- Verified artifact sizes: resident v1 `neogs_code.bin` = 16,006 bytes (`#3E86`); bootstrap = 196 bytes (`#00C4`); package = 16,204 bytes (`#3F4C`, 64 sectors); TR-DOS image = 655,360 bytes.
- The 16 KiB v1 firmware cap is unchanged. The new 48 KiB segmented v2 receiver is not yet present.
- STACK-02 is **CI PASS / hardware runtime pending**. New host marker: `[STACK] PASS: 128-byte WIN1 guard intact; stack stayed above #4880.`
- Do not start placing live overlay code into WIN2 until the user confirms this new stack layout on real Pentagon/NeoGS hardware.

## 2026-11-02 — STACK-02 hardware acceptance and RAM-size gate

- User supplied a full Pentagon/NeoGS runtime log. The new marker `[STACK] PASS: 128-byte WIN1 guard intact; stack stayed above #4880.` confirms the relocated stack and guard after Stage 5.
- The same log passed all existing IPC, 64-page x86 RAM, BIOS/IVT, INT, CPU, I/O, string/REP, INT10, TR-DOS/DMA and HALT stages. Stage 5 returned status/AX `0000 BBAB`.
- STACK-02 is now **hardware runtime PASS**.
- The host ROM probe in `zx_main/neogs_driver.asm` now enforces the minimum RAM capacity required for physical pages 0..69: `#118000` bytes (70 * 16 KiB). This prevents starting a future v2 overlay image on a board whose reported RAM cannot address both pages 68 and 69. Source commit: `39e8632966db0ce3bff1591c2b550f052ac386d9`.
- The new RAM-size gate has not yet been built or run on hardware. Existing v1 firmware remains limited to 16 KiB; no 48 KiB segment transfer is claimed.

- CI for the RAM-capacity gate: [run 41365546148](https://github.com/JTCyborg/Project124/actions/runs/41365546148), commit `39e8632966db0ce3bff1591c2b550f052ac386d9` — **success** (firmware/package/host/TR-DOS build, verification, artifact upload). This is build validation only; the new ROM-size rejection threshold still needs device runtime validation.
