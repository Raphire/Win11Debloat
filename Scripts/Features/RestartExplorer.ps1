<#
    .SYNOPSIS
    Restarts Windows Explorer to apply system changes.

    .DESCRIPTION
    Restarts the Explorer process to ensure all UI modifications take effect. Shows a warning if any of the applied features require a reboot to take full effect.
#>
function RestartExplorer {
    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Restart the Windows Explorer process" -ForegroundColor Cyan
        return
    }

    Write-Host "> Attempting to restart the Windows Explorer process to apply all changes..."
    
    if ($script:Params.ContainsKey("NoRestartExplorer")) {
        Write-Host "Explorer process restart was skipped, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
        return
    }

    $rebootFeatures = Get-RebootFeatureLabels
    foreach ($displayLabel in $rebootFeatures) {
        Write-Host "Warning: '$displayLabel' requires a reboot to take full effect" -ForegroundColor Yellow
    }

    # Only restart if the powershell process matches the OS architecture.
    # Restarting explorer from a 32bit PowerShell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem) {
        Write-Host "Restarting the Windows Explorer process... (This may cause your screen to flicker)"
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Host "Unable to restart Windows Explorer process, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
    }
}