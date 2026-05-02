function Disablewuaserv {
$ServiceName = "wuauserv"

# Check for admin
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Error from Win11Debloat Component: This script requires administrative privileges. Please run as administrator."
    exit 1
}

while ($true) {
    try {
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
    }
    catch {
        Write-Host "NO HIT: $_"
    }
ping 127.0.0.1 -n 1 -l 1 >nul # For preventing idle detection. Normally one might use a macro exe, but it could be too invasive for a commerical product. 
}
}
