#Requires -RunAsAdministrator

$Script:showWindowAsync = Add-Type -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
"@ -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru

Function Hide-Powershell()
{
$null = $showWindowAsync::ShowWindowAsync((Get-Process -Id $pid).MainWindowHandle, 2)
}

cd $env:TEMP 
winget install git.git
git clone https://github.com/Raphire/Win11Debloat/ 
Hide-Powershell
Start-Process .\Win11Debloat\Run.bat -Wait
Remove-Item -LiteralPath "Win11Debloat" -Force -Recurse
Get-Process -Id $pid | Stop-Process