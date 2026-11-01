$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$BootstrapPath = Join-Path $Root 'neogs_bootstrap.bin'
$FirmwarePath = Join-Path $Root 'neogs_code.bin'
$PackagePath = Join-Path $Root 'neoprog.bin'
$HostPackagePath = Join-Path $Root 'zx_main/neoprog.bin'

foreach ($Path in @($BootstrapPath, $FirmwarePath)) {
    if (-not (Test-Path $Path -PathType Leaf)) {
        throw "Required NeoGS binary is missing: $Path"
    }
}

$Bootstrap = [IO.File]::ReadAllBytes($BootstrapPath)
$Firmware = [IO.File]::ReadAllBytes($FirmwarePath)

if ($Bootstrap.Length -eq 0 -or $Bootstrap.Length -gt 0x3FFF) {
    throw "Invalid NeoGS bootstrap length: $($Bootstrap.Length)"
}
# Must match neogs_sub/build_firmware.asm and the runtime checks in
# neogs_sub/bootstrap.asm and zx_main/neogs_driver.asm.
# The first firmware segment may occupy the full #0000-#3FFF window; the Z80 stack is in WIN3.
if ($Firmware.Length -eq 0 -or $Firmware.Length -gt 0x4000) {
    throw "Invalid NeoGS firmware length: $($Firmware.Length) (maximum 16384 bytes / 0x4000)"
}

$PackageLength = 2 + $Bootstrap.Length + $Firmware.Length
if ($PackageLength -gt 0x4000) {
    throw "NeoGS package exceeds the host #C000 buffer: $PackageLength bytes"
}

# Package format consumed by the existing Stage 2 driver:
# [WORD bootstrap_length, little-endian][bootstrap][firmware]
$Package = New-Object byte[] $PackageLength
$Header = [BitConverter]::GetBytes([UInt16]$Bootstrap.Length)
[Array]::Copy($Header, 0, $Package, 0, 2)
[Array]::Copy($Bootstrap, 0, $Package, 2, $Bootstrap.Length)
[Array]::Copy($Firmware, 0, $Package, 2 + $Bootstrap.Length, $Firmware.Length)

[IO.File]::WriteAllBytes($PackagePath, $Package)
[IO.File]::WriteAllBytes($HostPackagePath, $Package)

Write-Host ("[PACK] neoprog.bin = {0} bytes (bootstrap {1} + firmware {2})" -f $PackageLength, $Bootstrap.Length, $Firmware.Length) -ForegroundColor Green
