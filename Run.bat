@echo off
:: Check Windows Terminal installation paths (default and Scoop installation)
set "wtPath1=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"
set "wtPath2=%USERPROFILE%\scoop\apps\windows-terminal\current\wt.exe"

:: Check if Windows Terminal is installed
if exist "%wtPath1%" (
    echo Detected Windows Terminal, executing with wt...
    PowerShell -Command "Start-Process -FilePath '%wtPath1%' -ArgumentList 'PowerShell -NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0Win11Debloat.ps1\"\"' -Verb RunAs"
) else if exist "%wtPath2%" (
    echo Detected Windows Terminal installed via Scoop...
    PowerShell -Command "Start-Process -FilePath '%wtPath2%' -ArgumentList 'PowerShell -NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0Win11Debloat.ps1\"\"' -Verb RunAs"
) else (
    echo Windows Terminal not found, using default PowerShell...
    PowerShell -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0Win11Debloat.ps1\"\"' -Verb RunAs}"
)
