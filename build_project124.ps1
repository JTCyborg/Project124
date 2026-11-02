$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $Root
try {
    # Prefer the assembler shipped with this project; fall back to PATH.
    $LocalAssemblerCandidates = @(
        (Join-Path $Root 'tools/sjasmplus.exe'),
        (Join-Path $Root 'tools/sjasmplus')
    )
    $AssemblerPath = $null
    foreach ($Candidate in $LocalAssemblerCandidates) {
        if (Test-Path $Candidate -PathType Leaf) {
            $AssemblerPath = (Resolve-Path $Candidate).Path
            break
        }
    }
    if (-not $AssemblerPath) {
        $PathAssembler = Get-Command sjasmplus -ErrorAction Stop
        $AssemblerPath = $PathAssembler.Source
    }
    Write-Host "Using assembler: $AssemblerPath" -ForegroundColor DarkGray
    $OldOutputs = @(
        'neogs_code.bin',
        'neogs_bootstrap.bin',
        'neogs_v2_bootstrap.bin',
        'neogs_v2_stage1.bin',
        'zx_main/neogs_code.bin',
        'zx_main/neogs_bootstrap.bin',
        'neoprog.bin',
        'zx_main/neoprog.bin',
        'disk_A.trd'
    )
    foreach ($File in $OldOutputs) {
        if (Test-Path $File) { Remove-Item $File -Force }
    }

    Write-Host "[1/2] Building NeoGS firmware, bootstrap and single neoprog package..." -ForegroundColor Cyan
    & $AssemblerPath -I 'neogs_sub' -I 'shared' 'neogs_sub/build_firmware.asm'
    if ($LASTEXITCODE -ne 0) {
        throw "NeoGS firmware build failed (sjasmplus exit code $LASTEXITCODE)."
    }

    # Assemble the isolated V2 first-stage bootstrap; it must fit the first sector.
    & $AssemblerPath -I 'neogs_sub' -I 'shared' 'neogs_sub/build_bootstrap_v2_stage0.asm'
    if ($LASTEXITCODE -ne 0) {
        throw "NeoGS V2 stage-0 build failed (sjasmplus exit code $LASTEXITCODE)."
    }
    $V2Stage0 = Get-Item 'neogs_v2_bootstrap.bin'
    if ($V2Stage0.Length -le 0 -or $V2Stage0.Length -gt 254) {
        throw "V2 stage-0 exceeds first-sector bootstrap limit: $($V2Stage0.Length) bytes."
    }
    Write-Host ("[V2-STAGE0] Bootstrap: {0} bytes / 254-byte first-sector budget." -f $V2Stage0.Length)

    # Assemble the isolated V2 second-stage receiver and enforce its WIN1 budget.
    & $AssemblerPath -I 'neogs_sub' -I 'shared' 'neogs_sub/build_bootstrap_v2_stage1.asm'
    if ($LASTEXITCODE -ne 0) {
        throw "NeoGS V2 stage-1 build failed (sjasmplus exit code $LASTEXITCODE)."
    }
    $V2Stage1 = Get-Item 'neogs_v2_stage1.bin'
    if ($V2Stage1.Length -le 0 -or $V2Stage1.Length -gt 0x0800) {
        throw "V2 stage-1 exceeds temporary WIN1 area #4800..#4FFF: $($V2Stage1.Length) bytes."
    }
    Write-Host ("[V2-STAGE1] Isolated receiver: {0} bytes / 2048-byte budget." -f $V2Stage1.Length)

    & (Join-Path $Root 'pack_neogs.ps1')
    if ($LASTEXITCODE -ne 0) {
        throw "NeoGS package creation failed."
    }

    $Generated = @(
        'neogs_code.bin',
        'neogs_bootstrap.bin',
        'zx_main/neogs_code.bin',
        'zx_main/neogs_bootstrap.bin',
        'neoprog.bin',
        'zx_main/neoprog.bin'
    )
    foreach ($File in $Generated) {
        if (-not (Test-Path $File)) {
            throw "Expected generated file is missing: $File"
        }
    }

    Write-Host "[2/2] Building Spectrum host program and TR-DOS image..." -ForegroundColor Cyan
    & $AssemblerPath -I 'zx_main' -I 'shared' -I 'neogs_sub' 'zx_main/main.asm'
    if ($LASTEXITCODE -ne 0) {
        throw "Spectrum host build failed (sjasmplus exit code $LASTEXITCODE)."
    }
    if (-not (Test-Path 'disk_A.trd')) {
        throw 'Assembler returned success, but disk_A.trd was not created.'
    }

    Write-Host "Build completed. Output files:" -ForegroundColor Green
    Get-Item 'neogs_code.bin','neogs_bootstrap.bin','neoprog.bin','disk_A.trd' |
        Select-Object Name,Length,LastWriteTime |
        Format-Table -AutoSize
}
finally {
    Pop-Location
}
