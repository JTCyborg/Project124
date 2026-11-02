# NeoGS firmware package v2 — frozen wire format

Status: format contract only; receiver/host implementation pending.
Updated: 2026-11-02

## Compatibility

The existing v1 package remains unchanged:

`WORD bootstrap_length` (little-endian), bootstrap bytes, flat resident firmware bytes.

V2 uses the same outer two-byte bootstrap-length prefix and the same bootstrap binary. The bootstrap is expected to negotiate the image format after it starts. V1 must remain the default until the v2 receiver and host stream are implemented and tested together. A larger payload length alone MUST NOT be treated as v2.

## Payload layout

After the bootstrap bytes, the firmware payload is:

| Offset | Size | Field | Required value |
|---:|---:|---|---|
| 0 | 4 | Magic | ASCII `P124` |
| 4 | 1 | Format version | `2` |
| 5 | 1 | Segment count | `1..3` |
| 6 | 2 | Total segment payload bytes | little-endian, `1..#C000` |
| 8 | count × 6 | Segment descriptors | see below |
| after descriptors | total bytes | Segment payloads | descriptor order |

Header size is `8 + 6 * segment_count` bytes. The maximum three-segment header is 26 bytes.

## Segment descriptor (6 bytes)

| Byte | Field | Meaning |
|---:|---|---|
| 0 | physical_page | `0` resident; `68` or `69` overlay |
| 1..2 | destination_offset | little-endian offset in selected 16-KiB page, `0..#3FFF` |
| 3..4 | segment_length | little-endian, `1..#4000` |
| 5 | flags | bit 0 = executable; bits 1..7 MUST be zero |

Payload records follow the descriptor table in the same order. There is no implicit padding between records.

## Required canonical layout for the first v2 implementation

1. Segment 0: physical page 0, offset 0, executable flag set, nonzero length <= #4000. This is the resident entry image and starts at logical address 0000.
2. Segment 1: physical page 68, offset 0, flags 0 or executable as required by the linker, length 1..#4000.
3. Segment 2: physical page 69, offset 0, flags 0 or executable as required by the linker, length 1..#4000.
4. Segment pages MUST be unique. The resident segment MUST be first. Overlay descriptors may be omitted for a one- or two-segment package while the linker is being migrated.
5. Total segment payload length MUST equal the sum of descriptor lengths and MUST be <= #C000 (48 KiB). The outer TR-DOS package must remain <= #FF00 bytes (255 sectors).

## Physical map and reserved regions

- Page 0 is fixed WIN0 and contains the resident image.
- Page 3 is fixed WIN1: trampoline #4000, guard #4800..#487F, active stack below #4FFE, DMA frame #5000..#7FFF.
- Pages 68 and 69 are mapped one at a time into WIN2 using MPAG. The active Z80 stack MUST remain in WIN1 while WIN2 is switched.
- Pages 4..67 remain exclusively assigned to x86 physical RAM and MUST NOT be used as firmware segment destinations.
- WIN3/MPAGEX remains exclusively assigned to x86 physical RAM pages 4..67 while the guest memory backend is active.
- The host must require the ROM #20 RAM-size report to be >= #118000 bytes before attempting v2 transfer.

## Receiver algorithm contract

1. Validate magic, version, segment count and total length before writing any payload.
2. Read and validate every descriptor before receiving payload bytes. Reject duplicate pages, unsupported flags, zero/oversized lengths, invalid pages, nonzero destination offsets in the initial canonical profile, sum mismatch and total > #C000.
3. For page 0, write payload through WIN0 at the specified offset.
4. For page 68/69, compute the documented MPAG encoding, select that page, and write through WIN2 at #8000 + offset. Restore the runtime's expected MPAG page after each segment; do not alter PG1/WIN1.
5. Count every payload byte and reject truncation or trailing bytes.
6. Only after all segments pass validation and transfer may the receiver send the firmware-ready ACK and jump to resident entry #0000.
7. On any malformed input or timeout, send the defined bootstrap error ACK and halt. Never jump to a partially loaded image.

## Host transfer contract

- The host continues to stream from the reusable 256-byte #C000 buffer; it must not stage the entire package in Spectrum RAM.
- V2 host sends the payload length followed by the complete v2 payload unchanged. The receiver owns parsing and segment placement.
- Host tracks exact bytes sent and compares against the outer package length minus prefix/bootstrap.
- The first-sector bootstrap constraint remains: two-byte outer length + bootstrap must fit in sector 0.

## Validation matrix

- Unit/packer: reject wrong magic/version, count 0 or >3, duplicate pages, page 1..67, page >=70, offset overflow, length 0, length >#4000, total mismatch, total >#C000, unknown flags, and outer package >#FF00.
- Positive fixtures: 16-KiB resident only; resident + one overlay; full 48-KiB three segments.
- Boundary fixtures: segment length #4000, total #4000, #8000, #C000, package ending in a partial final sector.
- Hardware: confirm RAM probe, load each bank, read-back signatures from page 68/69, switch repeatedly while stack guard remains intact, run resident CPU/IPC/DMA regressions, and verify error ACK for corrupted header/truncated payload.

## Implementation status

- [x] WIN1 stack relocation accepted by hardware runtime.
- [x] Host ROM probe now enforces >= #118000 RAM; CI build passed.
- [ ] V2 image builder/packer and positive/negative fixture tests.
- [ ] Host V2 length/accounting path.
- [ ] Bootstrap V2 header/descriptor receiver and bank writes.
- [ ] Resident bank-switch/call/data helpers.
- [ ] Linker split of resident code/data from banked overlays.
- [ ] 48-KiB CI boundary tests and artifact.
- [ ] Hardware V2 runtime acceptance.
