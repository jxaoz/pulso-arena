@echo off
setlocal EnableExtensions DisableDelayedExpansion

if /i "%PROCESSOR_ARCHITECTURE%"=="x86" if not defined PROCESSOR_ARCHITEW6432 goto :unsupported
set "PRISMAFRAME_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PRISMAFRAME_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PRISMAFRAME_PS%" goto :missing_power_shell
if not exist "%~dp0PrismaFrame.ps1" goto :missing_files

rem Let Windows PowerShell rebuild its native module path when called from PowerShell 7.
set "PSModulePath="
"%PRISMAFRAME_PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0PrismaFrame.ps1"
set "PRISMAFRAME_RESULT=%ERRORLEVEL%"
if "%PRISMAFRAME_RESULT%"=="0" exit /b 0
echo(
echo O PrismaFrame foi encerrado com o codigo %PRISMAFRAME_RESULT%.
pause
exit /b %PRISMAFRAME_RESULT%

:unsupported
echo O PrismaFrame precisa do Windows de 64 bits.
goto :failed

:missing_power_shell
echo O Windows PowerShell de 64 bits nao foi localizado.
goto :failed

:missing_files
echo PrismaFrame.ps1 nao foi localizado. Extraia toda a pasta antes de abrir.

:failed
pause
exit /b 1
