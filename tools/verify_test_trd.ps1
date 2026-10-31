param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [Parameter(Mandatory = $true)]
    [string]$TestPath
)

$ErrorActionPreference = "Stop"

try {
    if (-not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) {
        throw "TR-DOS image not found: $ImagePath"
    }
    if (-not (Test-Path -LiteralPath $TestPath -PathType Leaf)) {
        throw "External x86 test binary not found: $TestPath"
    }

    [byte[]]$image = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $ImagePath))
    [byte[]]$test = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $TestPath))

    if ($image.Length -ne 655360) {
        throw "Invalid TRD image size: $($image.Length), expected 655360 bytes."
    }
    if ($test.Length -lt 12 -or $test.Length -gt 0x3000) {
        throw "Invalid TEST.BIN size: $($test.Length), expected 12..12288 bytes."
    }
    if ([Text.Encoding]::ASCII.GetString($test, 0, 4) -ne "X86T") {
        throw "TEST.BIN has an invalid X86T signature."
    }
    if ($test[4] -ne 1 -or $test[5] -lt 1) {
        throw "Unsupported X86T version or empty test suite."
    }

    # Validate that all declared records fit exactly inside the container.
    $cursor = 6
    for ($record = 0; $record -lt [int]$test[5]; $record++) {
        if (($cursor + 7) -gt $test.Length) {
            throw "Truncated test record header at record $record."
        }
        $payloadLength = [int]$test[$cursor + 5] + ([int]$test[$cursor + 6] * 256)
        $cursor += 7
        if ($payloadLength -le 0 -or ($cursor + $payloadLength) -gt $test.Length) {
            throw "Invalid or truncated x86 payload in record $record."
        }
        $cursor += $payloadLength
    }
    if ($cursor -ne $test.Length) {
        throw "Unexpected trailing bytes after the final X86T record."
    }

    # Find the TEST.C catalogue entry (8-byte name + type 'C').
    $entryOffset = -1
    for ($offset = 0; $offset -lt 2048; $offset += 16) {
        $name = [Text.Encoding]::ASCII.GetString($image, $offset, 8)
        $type = $image[$offset + 8]
        if (($name -eq "TEST    ") -and ($type -eq 0x43)) {
            $entryOffset = $offset
            break
        }
    }
    if ($entryOffset -lt 0) {
        throw "TR-DOS catalogue does not contain TEST.C."
    }

    $catalogueLength = [int]$image[$entryOffset + 11] +
                       ([int]$image[$entryOffset + 12] * 256)
    $sectorCount = [int]$image[$entryOffset + 13]
    $sector = [int]$image[$entryOffset + 14]
    $track = [int]$image[$entryOffset + 15]

    if ($catalogueLength -ne $test.Length) {
        throw "TEST.C length mismatch: TR-DOS=$catalogueLength, TEST.BIN=$($test.Length)."
    }
    $expectedSectors = [int][Math]::Ceiling($test.Length / 256.0)
    if ($sectorCount -ne $expectedSectors) {
        throw "TEST.C sector-count mismatch: TR-DOS=$sectorCount, expected=$expectedSectors."
    }
    if ($sector -gt 15 -or $track -gt 79) {
        throw "Invalid first data sector in TEST.C catalogue entry."
    }

    $fileOffset = 0
    $remaining = $test.Length
    for ($index = 0; $index -lt $sectorCount; $index++) {
        if ($track -gt 79) {
            throw "TEST.C data extends beyond the 80-track TR-DOS image."
        }
        $diskOffset = (($track * 16) + $sector) * 256
        $chunkLength = [Math]::Min(256, $remaining)
        for ($byteIndex = 0; $byteIndex -lt $chunkLength; $byteIndex++) {
            if ($image[$diskOffset + $byteIndex] -ne $test[$fileOffset + $byteIndex]) {
                throw ("TEST.C data mismatch at file offset 0x{0:X4}." -f ($fileOffset + $byteIndex))
            }
        }
        $fileOffset += $chunkLength
        $remaining -= $chunkLength
        $sector++
        if ($sector -ge 16) {
            $sector = 0
            $track++
        }
    }

    if ($remaining -ne 0) {
        throw "TR-DOS data ended before the complete TEST.C container was verified."
    }

    Write-Host "[VERIFY] TEST.C found in TR-DOS catalogue."
    Write-Host ("[VERIFY] X86T v{0}, records: {1}, size: {2} bytes." -f $test[4], $test[5], $test.Length)
    Write-Host "[VERIFY] Every TEST.C byte matches TEST.BIN."
    exit 0
}
catch {
    Write-Host ("[VERIFY] ERROR: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
