@echo off
:: Set Windows Terminal installation paths. (Default and Scoop installation)
set "wtDefaultPath=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"
set "wtScoopPath=%USERPROFILE%\scoop\apps\windows-terminal\current\wt.exe"

:: Set the log file path
set "logFile=%~dp0Win11Debloat.log"

:: Check if Windows Terminal is installed
if exist "%wtDefaultPath%" (
    set "wtPath=%wtDefaultPath%"
) else if exist "%wtScoopPath%" (
    set "wtPath=%wtScoopPath%"
) else (
    echo Windows Terminal not found. Using default PowerShell instead.
    set "wtPath="
)

:: Launch the script in Windows Terminal if installed, otherwise use default PowerShell
if defined wtPath (
    PowerShell -Command "Start-Process -FilePath '%wtPath%' -ArgumentList 'PowerShell -NoProfile -ExecutionPolicy Bypass -File ""%~dp0Win11Debloat.ps1""' -Verb RunAs" >> "%logFile%"
) else (
    echo Windows Terminal not found. Using default PowerShell instead...
    PowerShell -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0Win11Debloat.ps1""' -Verb RunAs}" >> "%logFile%"
)

:: Check if the script has finished running
:checkScript
if exist "%~dp0Win11Debloat.ps1" (
    ping -n 1 127.0.0.1 >nul
    if errorlevel 1 (
        echo The script has finished running. >> "%logFile%"
    ) else (
        echo The script is still successfully running, Rechecking in 10 seconds... >> "%logFile%"
        timeout /t 10 /nobreak >nul
        goto :checkScript
    )
) else (
    echo The script has finished running. >> "%logFile%"
)