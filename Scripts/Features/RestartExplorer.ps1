# Restart the Windows Explorer process
function RestartExplorer {
    Write-Host "> Attempting to restart the Windows Explorer process to apply all changes..."
    
    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User") -or $script:Params.ContainsKey("NoRestartExplorer")) {
        Write-Host "Explorer process restart was skipped, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
        return
    }

    foreach ($paramKey in $script:Params.Keys) {
        if ($script:Features.ContainsKey($paramKey) -and $script:Features[$paramKey].RequiresReboot -eq $true) {
            $feature = $script:Features[$paramKey]
            Write-Host "Warning: '$($feature.Action) $($feature.Label)' requires a reboot to take full effect" -ForegroundColor Yellow
        }
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