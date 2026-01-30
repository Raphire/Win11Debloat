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
    for /f "tokens=2 delims== " %%a in ('wmic os get lastbootuptime ^| findstr /r /c:"[0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{2}:[0-9]{2} [0-9]{4}"') do (
        set "uptime=%%a"
    )
    for /f "tokens=1-3 delims=: " %%a in ("!uptime!") do (
        set "hours=%%a"
        set "minutes=%%b"
        set "seconds=%%c"
    )
    set /a "totalSeconds=%hours%*3600+%minutes%*60+%seconds%"
    set /a "elapsedMinutes=%totalSeconds%/60"
    ping -n 1 127.0.0.1 >nul
    if errorlevel 1 (
        echo [!elapsedMinutes!:!~4!:!~5!:!~6! !~7!:!~8! !~9! !~10!] The script has finished running. >> "%logFile%"
    ) else (
        echo [!elapsedMinutes!:!~4!:!~5!:!~6! !~7!:!~8! !~9! !~10!] The script is still running. Waiting for 5 seconds... >> "%logFile%"
        timeout /t 5 /nobreak >nul
        goto :checkScript
    )
) else (
    echo [!elapsedMinutes!:!~4!:!~5!:!~6! !~7!:!~8! !~9! !~10!] Failure when checking for existence of Win11Debloat.ps1 running. >> "%logFile%"
)