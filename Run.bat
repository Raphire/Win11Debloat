@echo off
chcp 65001 >nul
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
    call :Log 正在通过 Windows 终端启动 Win11Debloat.ps1……
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$p='%SCRIPT_PATH:'=''%'; $w='%wtPath:'=''%'; $q=[char]34; Start-Process -FilePath $w -ArgumentList ('PowerShell -NoProfile -ExecutionPolicy Bypass -File ' + $q + $p + $q) -Verb RunAs" >> "%logFile%" || call :Error "PowerShell 命令执行失败"
) else (
    echo 未找到 Windows 终端，正在使用默认 PowerShell……
    call :Log 未找到 Windows 终端，正在通过默认 PowerShell 启动 Win11Debloat.ps1……
    PowerShell -NoProfile -ExecutionPolicy Bypass -Command "$p='%SCRIPT_PATH:'=''%'; $q=[char]34; Start-Process PowerShell -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File ' + $q + $p + $q) -Verb RunAs" >> "%logFile%" || call :Error "PowerShell 命令执行失败"
)

echo.
echo 如需进一步帮助，可在以下页面反馈问题：
echo https://github.com/Raphire/Win11Debloat/issues
goto :EOF

:: Logging Function
:Log
echo(%* >> "%logFile%"
goto :EOF

:: Error Handler
:Error
echo(错误：%*
call :Log 错误： %*
echo 日志已记录到 %logFile%
pause
goto :EOF
