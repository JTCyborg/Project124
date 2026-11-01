@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo.
echo ================================================================
echo PROJECT 124 BUILD
echo ================================================================
echo.

if not exist "tools\sjasmplus.exe" (
    echo ERROR: tools\sjasmplus.exe not found.
    goto BUILD_FAILED
)

echo [1/2] Building NeoGS firmware and bootstrap...
"tools\sjasmplus.exe" --dirbol -I "neogs_sub" -I "shared" --lst="neogs_list.txt" --sym="neogs_map.txt" "neogs_sub/build_firmware.asm"
if errorlevel 1 goto BUILD_NEOGS_FAILED

echo [PACK] Creating neoprog.bin...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pack_neogs.ps1"
if errorlevel 1 goto BUILD_NEOGS_FAILED

if not exist "neogs_code.bin" (
    echo ERROR: neogs_code.bin was not created.
    goto BUILD_NEOGS_FAILED
)
if not exist "neogs_bootstrap.bin" (
    echo ERROR: neogs_bootstrap.bin was not created.
    goto BUILD_NEOGS_FAILED
)
if not exist "neoprog.bin" (
    echo ERROR: neoprog.bin was not created.
    goto BUILD_NEOGS_FAILED
)
if not exist "zx_main\neoprog.bin" (
    echo ERROR: zx_main\neoprog.bin was not created.
    goto BUILD_NEOGS_FAILED
)

echo [2/2] Building Spectrum host and TR-DOS image...
"tools\sjasmplus.exe" --dirbol -I "zx_main" -I "shared" -I "neogs_sub" --lst="zx_list.txt" --sym="zx_map.txt" "zx_main/main.asm"
if errorlevel 1 goto BUILD_ZX_FAILED

if not exist "disk_A.trd" (
    echo ERROR: disk_A.trd was not created.
    goto BUILD_ZX_FAILED
)

echo.
echo ================================================================
echo BUILD COMPLETED
echo ================================================================
echo.
dir "neogs_code.bin" "neogs_bootstrap.bin" "neoprog.bin" "disk_A.trd"
pause
exit /b 0

:BUILD_NEOGS_FAILED
echo.
echo ERROR: NeoGS build or package creation failed.
echo Check neogs_list.txt and the messages above.
pause
exit /b 1

:BUILD_ZX_FAILED
echo.
echo ERROR: Spectrum build failed.
echo Check zx_list.txt and the messages above.
pause
exit /b 1

:BUILD_FAILED
echo.
echo ERROR: tools\sjasmplus.exe is missing.
pause
exit /b 1
