[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResidentPath,

    [string]$Overlay68Path,
    [string]$Overlay69Path,

    [string]$BootstrapPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($BootstrapPath)) {
    $BootstrapPath = Join-Path $Root 'neogs_bootstrap.bin'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $Root 'neoprog_v2.bin'
}

function Read-RequiredBinary {
    param([string]$Path, [string]$Role, [int]$Maximum)
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Role binary is missing: $Path"
    }
    [byte[]]$Bytes = [IO.File]::ReadAllBytes($Path)
    if ($Bytes.Length -lt 1 -or $Bytes.Length -gt $Maximum) {
        throw "$Role length must be 1..$Maximum bytes; got $($Bytes.Length)"
    }
    return ,$Bytes
}

[byte[]]$Bootstrap = Read-RequiredBinary -Path $BootstrapPath -Role 'Bootstrap' -Maximum 254
[byte[]]$Resident = Read-RequiredBinary -Path $ResidentPath -Role 'Resident page 0' -Maximum 0x4000

$Segments = New-Object 'System.Collections.Generic.List[object]'
$Segments.Add([pscustomobject]@{
    Page = 0
    Offset = 0
    Flags = 1
    Bytes = $Resident
})

if (-not [string]::IsNullOrWhiteSpace($Overlay68Path)) {
    [byte[]]$Bytes68 = Read-RequiredBinary -Path $Overlay68Path -Role 'Overlay page 68' -Maximum 0x4000
    $Segments.Add([pscustomobject]@{ Page = 68; Offset = 0; Flags = 0; Bytes = $Bytes68 })
}
if (-not [string]::IsNullOrWhiteSpace($Overlay69Path)) {
    [byte[]]$Bytes69 = Read-RequiredBinary -Path $Overlay69Path -Role 'Overlay page 69' -Maximum 0x4000
    $Segments.Add([pscustomobject]@{ Page = 69; Offset = 0; Flags = 0; Bytes = $Bytes69 })
}

if ($Segments.Count -lt 1 -or $Segments.Count -gt 3) {
    throw "V2 segment count must be 1..3; got $($Segments.Count)"
}

[int]$TotalLength = 0
foreach ($Segment in $Segments) {
    if ($Segment.Page -ne 0 -and $Segment.Page -ne 68 -and $Segment.Page -ne 69) {
        throw "Unsupported physical page: $($Segment.Page)"
    }
    if ($Segment.Offset -ne 0) {
        throw "Initial V2 profile requires destination offset 0"
    }
    if ($Segment.Bytes.Length -lt 1 -or $Segment.Bytes.Length -gt 0x4000) {
        throw "Segment length outside 1..16384 bytes"
    }
    $TotalLength += $Segment.Bytes.Length
}
if ($TotalLength -gt 0xC000) {
    throw "V2 payload exceeds 48-KiB limit: $TotalLength"
}

$HeaderLength = 8 + (6 * $Segments.Count)
$Payload = New-Object byte[] ($HeaderLength + $TotalLength)
$Payload[0] = 0x50 # P
$Payload[1] = 0x31 # 1
$Payload[2] = 0x32 # 2
$Payload[3] = 0x34 # 4
$Payload[4] = 2
$Payload[5] = [byte]$Segments.Count
[Array]::Copy([BitConverter]::GetBytes([UInt16]$TotalLength), 0, $Payload, 6, 2)

[int]$DescriptorOffset = 8
[int]$DataOffset = $HeaderLength
foreach ($Segment in $Segments) {
    $Payload[$DescriptorOffset] = [byte]$Segment.Page
    [Array]::Copy([BitConverter]::GetBytes([UInt16]$Segment.Offset), 0, $Payload, $DescriptorOffset + 1, 2)
    [Array]::Copy([BitConverter]::GetBytes([UInt16]$Segment.Bytes.Length), 0, $Payload, $DescriptorOffset + 3, 2)
    $Payload[$DescriptorOffset + 5] = [byte]$Segment.Flags
    [Array]::Copy($Segment.Bytes, 0, $Payload, $DataOffset, $Segment.Bytes.Length)
    $DescriptorOffset += 6
    $DataOffset += $Segment.Bytes.Length
}

$PackageLength = 2 + $Bootstrap.Length + $Payload.Length
if ($PackageLength -gt 0xFF00) {
    throw "V2 package exceeds TR-DOS 255-sector limit: $PackageLength bytes"
}

$Package = New-Object byte[] $PackageLength
[Array]::Copy([BitConverter]::GetBytes([UInt16]$Bootstrap.Length), 0, $Package, 0, 2)
[Array]::Copy($Bootstrap, 0, $Package, 2, $Bootstrap.Length)
[Array]::Copy($Payload, 0, $Package, 2 + $Bootstrap.Length, $Payload.Length)

$OutputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($OutputDirectory) -and -not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
[IO.File]::WriteAllBytes($OutputPath, $Package)

Write-Host ("[V2-PACK] {0}: {1} bytes; segments={2}; firmware={3} bytes; header={4}; TR-DOS sectors={5}" -f
    $OutputPath, $Package.Length, $Segments.Count, $TotalLength, $HeaderLength, [Math]::Ceiling($Package.Length / 256.0))
