@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "POWER_SHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "POWER_SHELL=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%POWER_SHELL%" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Scripts\CLI\Start-UsbWorkflow.ps1"
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" pause
exit /b %RESULT%
