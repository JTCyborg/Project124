```bat
@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem =========================================================================
rem PROJECT 124 — АВТОМАТИЗИРОВАННАЯ ДВУХПРОЦЕССОРНАЯ СБОРКА
rem =========================================================================
rem ШАГ 1: Сборка NeoGS:
rem         neogs_code.bin
rem         neogs_bootstrap.bin (intermediate)
rem         neoprog.bin (combined TR-DOS NeoGS package)
rem
rem ШАГ 2: Сборка ZX Spectrum:
rem         основной код + упаковка TRD
rem
rem Ассемблер: tools\sjasmplus.exe
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
rem ШАГ 1. СБОРКА ПРОШИВКИ NEOGS И BOOTSTRAP
rem =========================================================================

echo [BUILD] Шаг 1: Сборка прошивки NeoGS и Bootstrap...
echo.

tools\sjasmplus.exe --dirbol ^
    -I neogs_sub -I shared ^
    --lst=neogs_list.txt ^
    --sym=neogs_map.txt ^
    neogs_sub/build_firmware.asm

if errorlevel 1 goto BUILD_NEOGS_FAILED

rem Проверка результата сборки

if not exist "neogs_code.bin" (
    echo [ERROR] Не создан neogs_code.bin
    goto BUILD_NEOGS_FAILED
)

if not exist "neogs_bootstrap.bin" (
    echo [ERROR] Не создан neogs_bootstrap.bin
    goto BUILD_NEOGS_FAILED
)

if not exist "neoprog.bin" (
    echo [ERROR] Не создан единый пакет NeoGS neoprog.bin
    goto BUILD_NEOGS_FAILED
)

echo [SUCCESS] neogs_code.bin создан.
echo [SUCCESS] neogs_bootstrap.bin создан.
echo [SUCCESS] neoprog.bin создан (bootstrap + firmware в одном файле).
echo.

rem =========================================================================
rem ШАГ 2. СБОРКА ОСНОВНОГО КОДА ZX SPECTRUM
rem =========================================================================

echo [BUILD] Шаг 2: Сборка ZX Spectrum и TR-DOS...
echo.

tools\sjasmplus.exe --dirbol ^
    -I zx_main -I shared -I neogs_sub ^
    --lst=zx_list.txt ^
    --sym=zx_map.txt ^
    zx_main/main.asm

if errorlevel 1 goto BUILD_ZX_FAILED

echo.
echo ================================================================
echo [SUCCESS] PROJECT 124 BUILD COMPLETED
echo ================================================================
echo.
echo [MAP] neogs_map.txt
echo [MAP] zx_map.txt
echo [LST] neogs_list.txt
echo [LST] zx_list.txt
echo.

echo [FILES] Результаты:
if exist "neogs_code.bin" echo   neogs_code.bin
if exist "neogs_bootstrap.bin" echo   neogs_bootstrap.bin (intermediate)
if exist "neoprog.bin" echo   neoprog.bin (NeoGS package)
if exist "zx_main\neogs_code.bin" echo   zx_main\neogs_code.bin
if exist "zx_main\neogs_bootstrap.bin" echo   zx_main\neogs_bootstrap.bin
echo.

pause
exit /b 0

rem =========================================================================
rem ОШИБКИ СБОРКИ
rem =========================================================================

:BUILD_NEOGS_FAILED
echo.
echo ================================================================
echo [ERROR] ОШИБКА СБОРКИ NEOGS / BOOTSTRAP
echo ================================================================
echo Проверь neogs_list.txt и вывод ассемблера.
echo.
pause
exit /b 1

:BUILD_ZX_FAILED
echo.
echo ================================================================
echo [ERROR] ОШИБКА СБОРКИ ZX SPECTRUM
echo ================================================================
echo Проверь zx_list.txt и вывод ассемблера.
echo.
pause
exit /b 1

:BUILD_FAILED
echo.
echo [ERROR] Сборка невозможна: отсутствует ассемблер.
pause
exit /b 1
```