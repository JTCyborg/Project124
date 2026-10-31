param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [Parameter(Mandatory = $true)]
    [string]$FirmwarePath
)

$ErrorActionPreference = "Stop"

try {
    if (-not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) {
        throw "TR-DOS image not found: $ImagePath"
    }
    if (-not (Test-Path -LiteralPath $FirmwarePath -PathType Leaf)) {
        throw "NeoGS firmware binary not found: $FirmwarePath"
    }

    [byte[]]$image = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ImagePath))
    [byte[]]$firmware = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $FirmwarePath))

    if ($image.Length -ne 655360) {
        throw "Invalid TRD image size: $($image.Length), expected 655360 bytes."
    }
    if ($firmware.Length -le 0 -or $firmware.Length -gt 0x3000) {
        throw "Invalid NeoGS firmware size: $($firmware.Length), allowed range is 1..12288 bytes."
    }

    # TR-DOS catalogue: 128 entries * 16 bytes in the first 8 sectors.
    $entryOffset = -1
    for ($offset = 0; $offset -lt 2048; $offset += 16) {
        $name = [Text.Encoding]::ASCII.GetString($image, $offset, 8)
        $type = $image[$offset + 8]
        if (($name -eq "neoprog ") -and ($type -eq 0x43)) {
            $entryOffset = $offset
            break
        }
    }

    if ($entryOffset -lt 0) {
        throw "TR-DOS catalogue does not contain neoprog.C."
    }

    # Catalogue offsets follow the TR-DOS descriptor layout used by
    # zx_main/neogs_driver.asm: length at +11, sector count +13,
    # first sector +14, track +15.
    $catalogueLength = [int]$image[$entryOffset + 11] +
                       ([int]$image[$entryOffset + 12] * 256)
    $sectorCount = [int]$image[$entryOffset + 13]
    $sector = [int]$image[$entryOffset + 14]
    $track = [int]$image[$entryOffset + 15]

    if ($catalogueLength -ne $firmware.Length) {
        throw "neoprog.C length mismatch: TR-DOS=$catalogueLength, firmware=$($firmware.Length)."
    }

    $expectedSectors = [int][Math]::Ceiling($firmware.Length / 256.0)
    if ($sectorCount -ne $expectedSectors) {
        throw "neoprog.C sector-count mismatch: TR-DOS=$sectorCount, expected=$expectedSectors."
    }
    if ($sector -lt 0 -or $sector -gt 15 -or $track -lt 0 -or $track -gt 79) {
        throw "Invalid first data sector in neoprog.C catalogue entry."
    }

    # Verify every meaningful file byte against the freshly built firmware.
    $firmwareOffset = 0
    $remaining = $firmware.Length
    for ($index = 0; $index -lt $sectorCount; $index++) {
        if ($track -gt 79) {
            throw "neoprog.C data extends beyond the 80-track TR-DOS image."
        }

        $diskOffset = (($track * 16) + $sector) * 256
        $chunkLength = [Math]::Min(256, $remaining)

        for ($byteIndex = 0; $byteIndex -lt $chunkLength; $byteIndex++) {
            if ($image[$diskOffset + $byteIndex] -ne $firmware[$firmwareOffset + $byteIndex]) {
                throw ("neoprog.C data mismatch at file offset 0x{0:X4}." -f ($firmwareOffset + $byteIndex))
            }
        }

        $firmwareOffset += $chunkLength
        $remaining -= $chunkLength
        $sector++
        if ($sector -ge 16) {
            $sector = 0
            $track++
        }
    }

    if ($remaining -ne 0) {
        throw "TR-DOS data ended before the complete firmware image was verified."
    }

    Write-Host ("[VERIFY] neoprog.C found in TR-DOS catalogue.")
    Write-Host ("[VERIFY] Firmware size: {0} bytes ({1} sectors)." -f $firmware.Length, $sectorCount)
    Write-Host "[VERIFY] Every firmware byte in disk_A.trd matches neogs_code.bin."
    exit 0
}
catch {
    Write-Host ("[VERIFY] ERROR: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
