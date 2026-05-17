function DisableWiFi {
while ($true) {
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    throw "This script must be run as Administrator."
}

    Start-Sleep -Seconds 2

    $wifiAdapters = Get-NetAdapter -Physical -IncludeHidden |
        Where-Object {
            ($_.NdisPhysicalMedium -in 1, 9 -or
            $_.InterfaceDescription -match 'Wi-?Fi|Wireless|WLAN|802\.11') -and
            $_.Status -eq 'Up'
         }

    if ($wifiAdapters) {
        $wifiAdapters | Disable-NetAdapter -Confirm:$false
     }
 }
 }
