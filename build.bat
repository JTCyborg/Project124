@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem Always build from the repository root, even when launched by double-click.
cd /d "%~dp0"
if errorlevel 1 goto BUILD_FAILED

rem =========================================================================
rem PROJECT 124 — reproducible dual-Z80 build
rem 0. Assemble tests/TEST.ASM to TEST.BIN with NASM.
rem 1. Build NeoGS firmware and bootstrap.
rem 2. Build the Spectrum host and export neoprog.C + TEST.C into disk_A.trd.
rem 3. Verify both TR-DOS files.
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
rem STEP 0 — Assemble external x86 test suite source.
rem NASM is required; the resulting TEST.BIN is exported to TR-DOS as TEST.C.
rem =========================================================================
echo [BUILD] 0/4: Сборка внешнего набора x86-тестов...

if not exist "tests\TEST.ASM" (
    echo [ERROR] Не найден tests\TEST.ASM
    goto BUILD_TESTS_FAILED
)

set "TEST_SIZE="
where nasm.exe >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Не найден NASM (nasm.exe). Добавьте NASM в PATH.
    goto BUILD_TESTS_FAILED
)

if exist "TEST.BIN" del /q "TEST.BIN"
nasm.exe -Wall -f bin tests\TEST.ASM -o TEST.BIN
if errorlevel 1 goto BUILD_TESTS_FAILED
if not exist "TEST.BIN" goto BUILD_TESTS_FAILED

for %%I in (TEST.BIN) do set TEST_SIZE=%%~zI
if "%TEST_SIZE%"=="" goto BUILD_TESTS_FAILED
if %TEST_SIZE% LEQ 0 goto BUILD_TESTS_FAILED
if %TEST_SIZE% GTR 12288 goto BUILD_TESTS_FAILED

echo [SUCCESS] TEST.BIN создан: %TEST_SIZE% bytes.

rem =========================================================================
rem STEP 1 — NeoGS firmware and first-stage bootstrap
rem =========================================================================
echo [BUILD] 1/4: Сборка прошивки NeoGS и Bootstrap...

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
echo [BUILD] 2/4: Сборка host-программы и образа TR-DOS...

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
echo [BUILD] 3/4: Проверка файлов прошивки и тестов в disk_A.trd...

if not exist "tools\verify_neoprog_trd.ps1" goto BUILD_VERIFY_FAILED

powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "tools\verify_neoprog_trd.ps1" ^
    -ImagePath "disk_A.trd" ^
    -FirmwarePath "neogs_code.bin"

if errorlevel 1 goto BUILD_VERIFY_FAILED

powershell -NoProfile -ExecutionPolicy Bypass ^
    -File "tools\verify_test_trd.ps1" ^
    -ImagePath "disk_A.trd" ^
    -TestPath "TEST.BIN"

if errorlevel 1 goto BUILD_VERIFY_FAILED

echo.
echo ================================================================
echo [SUCCESS] PROJECT 124 BUILD AND TR-DOS TEST PIPELINE VERIFY COMPLETED
echo ================================================================
echo.
echo [FILES]
echo   disk_A.trd       - boot.B + proj124.C + NeoGS firmware neoprog.C
echo   neogs_code.bin   - source firmware binary used for TR-DOS export
echo   neogs_bootstrap.bin - first-stage loader embedded in proj124.C
echo   TEST.BIN          - x86 test container assembled from tests\TEST.ASM
echo   TEST.C            - x86 test container stored on the TR-DOS disk
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

:BUILD_TESTS_FAILED
echo.
echo [ERROR] Не удалось собрать tests\TEST.ASM. Проверьте установку NASM и исходник.
goto BUILD_FAILED

:BUILD_ZX_FAILED
echo.
echo [ERROR] Ошибка сборки ZX Spectrum или создания disk_A.trd.
echo Проверь zx_list.txt и вывод sjasmplus.
goto BUILD_FAILED

:BUILD_VERIFY_FAILED
echo.
echo [ERROR] Проверка TR-DOS файлов neoprog.C / TEST.C не пройдена.
echo Образ нельзя считать готовым к запуску.
goto BUILD_FAILED

:BUILD_FAILED
echo.
echo ================================================================
echo [ERROR] PROJECT 124 BUILD FAILED
echo ================================================================
pause
exit /b 1
