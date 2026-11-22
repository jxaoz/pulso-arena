@echo off
setlocal EnableExtensions DisableDelayedExpansion

if /i "%PROCESSOR_ARCHITECTURE%"=="x86" if not defined PROCESSOR_ARCHITEW6432 goto :unsupported
set "PULSOARENA_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PULSOARENA_PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PULSOARENA_PS%" goto :missing_power_shell
if not exist "%~dp0PulsoArena.ps1" goto :missing_files

rem Let Windows PowerShell rebuild its native module path when called from PowerShell 7.
set "PSModulePath="
"%PULSOARENA_PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0PulsoArena.ps1"
set "PULSOARENA_RESULT=%ERRORLEVEL%"
if "%PULSOARENA_RESULT%"=="0" exit /b 0
echo(
echo O Pulso Arena foi encerrado com o codigo %PULSOARENA_RESULT%.
pause
exit /b %PULSOARENA_RESULT%

:unsupported
echo O Pulso Arena precisa do Windows de 64 bits.
goto :failed

:missing_power_shell
echo O Windows PowerShell de 64 bits nao foi localizado.
goto :failed

:missing_files
echo PulsoArena.ps1 nao foi localizado. Extraia toda a pasta antes de abrir.

:failed
pause
exit /b 1
