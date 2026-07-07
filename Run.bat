@echo off
setlocal

:: Set Windows Terminal installation paths. (Default and Scoop installation)
set "wtDefaultPath=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"
set "wtScoopPath=%USERPROFILE%\scoop\apps\windows-terminal\current\wt.exe"
set "logFile=%~dp0Logs\Win11Debloat-Run.log"

:: Ensure Logs folder exists
if not exist "%~dp0Logs" mkdir "%~dp0Logs"

:: Determine which terminal exists
if exist "%wtDefaultPath%" (
    set "wtPath=%wtDefaultPath%"
) else if exist "%wtScoopPath%" (
    set "wtPath=%wtScoopPath%"
) else (
    set "wtPath="
)

:: Interpolated into a PS single-quoted string below;
:: Apostrophes escaped via %:'=''% and -File arg uses [char]34 to avoid quote-parity bugs.
set "SCRIPT_PATH=%~dp0Win11Debloat.ps1"

if defined wtPath (
    call :Log Launching Win11Debloat.ps1 with Windows Terminal...
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$p='%SCRIPT_PATH:'=''%'; $q=[char]34; Start-Process -FilePath '%wtPath%' -ArgumentList ('PowerShell -NoProfile -ExecutionPolicy Bypass -File ' + $q + $p + $q) -Verb RunAs" >> "%logFile%" || call :Error "PowerShell command failed"
) else (
    echo Windows Terminal not found, using default PowerShell...
    call :Log Windows Terminal not found. Using default PowerShell to launch Win11Debloat.ps1...
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$p='%SCRIPT_PATH:'=''%'; $q=[char]34; Start-Process PowerShell -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File ' + $q + $p + $q) -Verb RunAs" >> "%logFile%" || call :Error "PowerShell command failed"
)

echo.
echo If you need further assistance, please open an issue at:
echo https://github.com/Raphire/Win11Debloat/issues
goto :EOF

:: Logging Function
:Log
echo(%* >> "%logFile%"
goto :EOF

:: Error Handler
:Error
echo(ERROR: %*
call :Log ERROR: %*
echo Logged in %logFile%
pause
goto :EOF
