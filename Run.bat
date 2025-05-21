@echo off
:: Set Windows Terminal installation paths. (Default and Scoop installation)
set "wtDefaultPath=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"
set "wtScoopPath=%USERPROFILE%\scoop\apps\windows-terminal\current\wt.exe"

:: Launch the script in Windows Terminal if installed, otherwise use default PowerShell.
if exist "%wtDefaultPath%" (
    PowerShell -Command "Start-Process -FilePath '%wtDefaultPath%' -ArgumentList 'PowerShell -NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0Win11Debloat.ps1\"\"' -Verb RunAs"
) else if exist "%wtScoopPath%" (
    PowerShell -Command "Start-Process -FilePath '%wtScoopPath%' -ArgumentList 'PowerShell -NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0Win11Debloat.ps1\"\"' -Verb RunAs"
) else (
    echo Windows Terminal not found, using default PowerShell...
    PowerShell -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0Win11Debloat.ps1\"\"' -Verb RunAs}"
)
