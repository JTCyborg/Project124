@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo.
echo ================================================================
echo PROJECT 124 BUILD - V1 + V2
echo ================================================================
echo.

if not exist "tools\sjasmplus.exe" (
    echo ERROR: tools\sjasmplus.exe not found.
    goto BUILD_FAILED
)

if not exist "build_project124.ps1" (
    echo ERROR: build_project124.ps1 not found in project root.
    goto BUILD_FAILED
)

rem The PowerShell orchestrator generates all V1/V2 binaries and include
rem files before assembling zx_main/main.asm.
if not exist "pack_neogs.ps1" (
    echo [SETUP] pack_neogs.ps1 is missing. Downloading...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/JTCyborg/Project124/main/pack_neogs.ps1' -OutFile '%~dp0pack_neogs.ps1'; exit 0 } catch { Write-Error $_; exit 1 }"
    if errorlevel 1 goto BUILD_PACKER_FAILED
)

if not exist "pack_neogs.ps1" goto BUILD_PACKER_FAILED

echo [BUILD] Running complete Project124 build pipeline...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_project124.ps1"
if errorlevel 1 goto BUILD_FAILED

if not exist "disk_A.trd" (
    echo ERROR: disk_A.trd was not created.
    goto BUILD_FAILED
)
if not exist "disk_A_v2.trd" (
    echo ERROR: disk_A_v2.trd was not created.
    goto BUILD_FAILED
)
if not exist "zx_main\neoprog_v2_chunks.inc" (
    echo ERROR: V2 generated include is missing after successful build.
    goto BUILD_FAILED
)

echo.
echo ================================================================
echo BUILD COMPLETED - V1 and V2
echo ================================================================
echo.
dir "neogs_code.bin" "neoprog.bin" "neoprog_v2.bin" "disk_A.trd" "disk_A_v2.trd"
pause
exit /b 0

:BUILD_PACKER_FAILED
echo.
echo ERROR: pack_neogs.ps1 is missing and could not be downloaded.
pause
exit /b 1

:BUILD_FAILED
echo.
echo ERROR: Project124 build failed. See messages above.
pause
exit /b 1
