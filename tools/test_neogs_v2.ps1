$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Packer = Join-Path $PSScriptRoot 'pack_neogs_v2.ps1'
$Temp = Join-Path ([IO.Path]::GetTempPath()) ("project124-v2-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Temp | Out-Null

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FAILED: $Message" }
}
function Write-PatternFile {
    param([string]$Path, [int]$Length, [byte]$Value)
    [byte[]]$Data = New-Object byte[] $Length
    for ($i = 0; $i -lt $Length; $i++) { $Data[$i] = [byte](($Value + $i) -band 0xFF) }
    [IO.File]::WriteAllBytes($Path, $Data)
}
function Read-U16 {
    param([byte[]]$Data, [int]$Offset)
    return [BitConverter]::ToUInt16($Data, $Offset)
}
function Invoke-ExpectedFailure {
    param([scriptblock]$Action, [string]$Name)
    $Failed = $false
    try { & $Action } catch { $Failed = $true }
    Assert-True $Failed "negative fixture must fail: $Name"
    Write-Host "[V2-TEST] REJECT PASS: $Name"
}

try {
    $Bootstrap = Join-Path $Temp 'bootstrap.bin'
    $Resident = Join-Path $Temp 'resident.bin'
    $Overlay68 = Join-Path $Temp 'overlay68.bin'
    $Overlay69 = Join-Path $Temp 'overlay69.bin'
    $Output = Join-Path $Temp 'package.bin'
    Write-PatternFile $Bootstrap 196 0xA0
    Write-PatternFile $Resident 0x4000 0x10
    Write-PatternFile $Overlay68 0x4000 0x40
    Write-PatternFile $Overlay69 0x4000 0x70

    # Full 48-KiB image: resident page 0 + overlay pages 68 and 69.
    & $Packer -BootstrapPath $Bootstrap -ResidentPath $Resident -Overlay68Path $Overlay68 -Overlay69Path $Overlay69 -OutputPath $Output
    [byte[]]$Package = [IO.File]::ReadAllBytes($Output)
    $BootstrapLength = Read-U16 $Package 0
    $PayloadStart = 2 + $BootstrapLength
    Assert-True ($BootstrapLength -eq 196) 'outer bootstrap length'
    Assert-True ($Package.Length -eq (2 + 196 + 26 + 0xC000)) '48-KiB package exact size'
    Assert-True ($Package[$PayloadStart] -eq 0x50 -and $Package[$PayloadStart + 1] -eq 0x31 -and $Package[$PayloadStart + 2] -eq 0x32 -and $Package[$PayloadStart + 3] -eq 0x34) 'P124 magic'
    Assert-True ($Package[$PayloadStart + 4] -eq 2) 'format version'
    Assert-True ($Package[$PayloadStart + 5] -eq 3) 'segment count'
    Assert-True ((Read-U16 $Package ($PayloadStart + 6)) -eq 0xC000) 'total payload length'

    $D0 = $PayloadStart + 8
    $D1 = $D0 + 6
    $D2 = $D1 + 6
    Assert-True ($Package[$D0] -eq 0 -and (Read-U16 $Package ($D0 + 1)) -eq 0 -and (Read-U16 $Package ($D0 + 3)) -eq 0x4000 -and $Package[$D0 + 5] -eq 1) 'resident descriptor'
    Assert-True ($Package[$D1] -eq 68 -and (Read-U16 $Package ($D1 + 1)) -eq 0 -and (Read-U16 $Package ($D1 + 3)) -eq 0x4000 -and $Package[$D1 + 5] -eq 0) 'page 68 descriptor'
    Assert-True ($Package[$D2] -eq 69 -and (Read-U16 $Package ($D2 + 1)) -eq 0 -and (Read-U16 $Package ($D2 + 3)) -eq 0x4000 -and $Package[$D2 + 5] -eq 0) 'page 69 descriptor'

    $DataStart = $PayloadStart + 26
    Assert-True ($Package[$DataStart] -eq 0x10) 'resident data starts after descriptor table'
    Assert-True ($Package[$DataStart + 0x4000] -eq 0x40) 'page 68 payload follows resident'
    Assert-True ($Package[$DataStart + 0x8000] -eq 0x70) 'page 69 payload follows page 68'
    Assert-True ($Package.Length -le 0xFF00) '48-KiB package within TR-DOS limit'
    Write-Host '[V2-TEST] FULL 48-KiB fixture PASS'

    # Resident-only migration fixture.
    & $Packer -BootstrapPath $Bootstrap -ResidentPath $Resident -OutputPath $Output
    [byte[]]$Package = [IO.File]::ReadAllBytes($Output)
    $PayloadStart = 2 + (Read-U16 $Package 0)
    Assert-True ($Package[$PayloadStart + 5] -eq 1) 'resident-only segment count'
    Assert-True ((Read-U16 $Package ($PayloadStart + 6)) -eq 0x4000) 'resident-only length'
    Write-Host '[V2-TEST] RESIDENT-ONLY FIXTURE PASS'

    # Resident + one overlay migration fixture.
    & $Packer -BootstrapPath $Bootstrap -ResidentPath $Resident -Overlay68Path $Overlay68 -OutputPath $Output
    [byte[]]$Package = [IO.File]::ReadAllBytes($Output)
    $PayloadStart = 2 + (Read-U16 $Package 0)
    Assert-True ($Package[$PayloadStart + 5] -eq 2) 'two-segment count'
    Assert-True ((Read-U16 $Package ($PayloadStart + 6)) -eq 0x8000) 'two-segment length'
    Write-Host '[V2-TEST] TWO-SEGMENT FIXTURE PASS'

    $Empty = Join-Path $Temp 'empty.bin'
    $TooLarge = Join-Path $Temp 'too-large.bin'
    Write-PatternFile $Empty 0 0
    Write-PatternFile $TooLarge 0x4001 0x55
    Invoke-ExpectedFailure { & $Packer -BootstrapPath $Bootstrap -ResidentPath $Empty -OutputPath $Output } 'empty resident'
    Invoke-ExpectedFailure { & $Packer -BootstrapPath $Bootstrap -ResidentPath $TooLarge -OutputPath $Output } 'resident > 16 KiB'
    Invoke-ExpectedFailure { & $Packer -BootstrapPath $Bootstrap -ResidentPath $Resident -Overlay68Path $TooLarge -OutputPath $Output } 'overlay > 16 KiB'
    Invoke-ExpectedFailure { & $Packer -BootstrapPath (Join-Path $Temp 'missing.bin') -ResidentPath $Resident -OutputPath $Output } 'missing bootstrap'

    Write-Host '[V2-TEST] ALL TESTS PASS'
}
finally {
    if (Test-Path -LiteralPath $Temp) { Remove-Item -LiteralPath $Temp -Recurse -Force }
}
