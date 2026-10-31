@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem =========================================================================
rem PROJECT 124 — reproducible dual-Z80 build
rem 1. Build NeoGS firmware and bootstrap.
rem 2. Build the Spectrum host and export neoprog.C into disk_A.trd.
rem 3. Verify that TR-DOS neoprog.C is byte-for-byte the NeoGS firmware.
rem =========================================================================

echo.
echo ================================================================
echo              PROJECT 124 BUILD SYSTEM
echo ================================================================
echo.

if not exist "tools\sjasmplus.exe" (
    echo [ERROR] Не найден tools\sjasmplus.exe
    goto BUILD_FAILED
)

rem =========================================================================
rem STEP 1 — NeoGS firmware and first-stage bootstrap
rem =========================================================================
echo [BUILD] 1/3: Сборка прошивки NeoGS и Bootstrap...

tools\sjasmplus.exe --dirbol ^
    -I neogs_sub -I shared ^
    --lst=neogs_list.txt ^
    --sym=neogs_map.txt ^
    neogs_sub/build_firmware.asm

if errorlevel 1 goto BUILD_NEOGS_FAILED
if not exist "neogs_code.bin" goto BUILD_NEOGS_FAILED
if not exist "neogs_bootstrap.bin" goto BUILD_NEOGS_FAILED

echo [SUCCESS] neogs_code.bin и neogs_bootstrap.bin созданы.

rem =========================================================================
rem STEP 2 — Spectrum host and TR-DOS image
rem main.asm exports neogs_code.bin as disk file neoprog.C.
rem The firmware image is NOT embedded in proj124.C.
rem =========================================================================
echo [BUILD] 2/3: Сборка host-программы и образа TR-DOS...

tools\sjasmplus.exe --dirbol ^
    -I zx_main -I shared -I neogs_sub ^
    --lst=zx_list.txt ^
    --sym=zx_map.txt ^
    zx_main/main.asm

if errorlevel 1 goto BUILD_ZX_FAILED
if not exist "disk_A.trd" goto BUILD_ZX_FAILED

rem =========================================================================
rem STEP 3 — Verify TR-DOS directory entry, length, sectors and file bytes
rem =========================================================================
echo [BUILD] 3/3: Проверка neoprog.C внутри disk_A.trd...

if not exist "tools\verify_neoprog_trd.ps1" goto BUILD_VERIFY_FAILED

powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "tools\verify_neoprog_trd.ps1" ^
    -ImagePath "disk_A.trd" ^
    -FirmwarePath "neogs_code.bin"

if errorlevel 1 goto BUILD_VERIFY_FAILED

echo.
echo ================================================================
echo [SUCCESS] PROJECT 124 BUILD AND TR-DOS FIRMWARE VERIFY COMPLETED
echo ================================================================
echo.
echo [FILES]
echo   disk_A.trd       - boot.B + proj124.C + NeoGS firmware neoprog.C
echo   neogs_code.bin   - source firmware binary used for TR-DOS export
echo   neogs_bootstrap.bin - first-stage loader embedded in proj124.C
echo.
echo [MAP/LIST]
echo   neogs_map.txt
echo   neogs_list.txt
echo   zx_map.txt
echo   zx_list.txt
echo.
pause
exit /b 0

:BUILD_NEOGS_FAILED
echo.
echo [ERROR] Ошибка сборки NeoGS firmware/bootstrap.
echo Проверь neogs_list.txt и вывод sjasmplus.
goto BUILD_FAILED

:BUILD_ZX_FAILED
echo.
echo [ERROR] Ошибка сборки ZX Spectrum или создания disk_A.trd.
echo Проверь zx_list.txt и вывод sjasmplus.
goto BUILD_FAILED

:BUILD_VERIFY_FAILED
echo.
echo [ERROR] Проверка neoprog.C в disk_A.trd не пройдена.
echo Образ нельзя считать готовым к запуску.
goto BUILD_FAILED

:BUILD_FAILED
echo.
echo ================================================================
echo [ERROR] PROJECT 124 BUILD FAILED
echo ================================================================
pause
exit /b 1
