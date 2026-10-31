# Project124

ZX Spectrum Pentagon 1024 project with a host Z80 and a NeoGS Z80 firmware core.

## Build

Run `build.bat` from the repository root on Windows. The build requires
`tools/sjasmplus.exe` and Windows PowerShell.

The build order is intentional:

1. `neogs_sub/build_firmware.asm` assembles the NeoGS firmware to
   `neogs_code.bin` and the first-stage loader to `neogs_bootstrap.bin`.
2. `zx_main/main.asm` assembles `proj124.C` and `boot.B`. It also exports
   the exact bytes from `neogs_code.bin` into the TR-DOS image as
   `neoprog.C`.
3. `tools/verify_neoprog_trd.ps1` verifies the `neoprog.C` catalogue entry,
   byte length, sector count, and every stored firmware byte against
   `neogs_code.bin`.

The build fails if the firmware is empty, exceeds 12 KiB, or the TR-DOS copy
does not match the freshly assembled firmware.

## Runtime loading model

- `neoprog.C` is the **NeoGS firmware image**, not an x86 application.
- The main Z80 finds `neoprog.C` in the TR-DOS catalogue and reads its sectors
  into host RAM at `#C000`.
- The existing GS105a ROM protocol loads the embedded first-stage bootstrap
  at NeoGS RAM `#4000`. The bootstrap receives the firmware bytes from the
  host buffer and installs the firmware at NeoGS RAM `#0000`.
- The host waits for the firmware-ready ACK before proceeding.
- Commander does not execute `neoprog.C` as a Spectrum code file. It is
  reserved for the NeoGS firmware and is loaded automatically during startup.

## Interpreter diagnostics

The x86 diagnostic payloads are separate small byte arrays embedded in the
host application. The host sends each test to the running NeoGS firmware
through the existing DMA/IPC protocol, requests the result frame, and checks
the returned signature, status, and AX value.

The physical-memory diagnostic is implemented in the NeoGS firmware. Its
current test writes and verifies two boundary bytes (offsets `0000` and
`3FFF`) on each of the 64 mapped 16 KiB pages. It verifies page mapping and
boundary-byte retention; it is **not** a full byte-by-byte RAM test.

A diagnostic PASS message is emitted only after the host has received and
checked the corresponding NeoGS result frame.
