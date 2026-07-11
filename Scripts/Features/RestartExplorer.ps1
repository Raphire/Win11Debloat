# Restart the Windows Explorer process
function RestartExplorer {
    # Restarting Explorer while running in Sysprep or User context is not necessary
    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")) {
        return
    }

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Restart the Windows Explorer process" -ForegroundColor Cyan
        return
    }

    Write-Host "> Attempting to restart the Windows Explorer process to apply all changes..."
    
    if ($script:Params.ContainsKey("NoRestartExplorer")) {
        Write-Host "Explorer process restart was skipped, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
        return
    }

    $candidateParamKeys = @($script:Params.Keys) + @($script:UndoParams.Keys)
    foreach ($paramKey in $candidateParamKeys) {
        if ($script:Features.ContainsKey($paramKey) -and $script:Features[$paramKey].RequiresReboot -eq $true) {
            $feature = $script:Features[$paramKey]
            $isUndo = $script:UndoParams.ContainsKey($paramKey)
            $displayLabel = if ($isUndo -and $feature.UndoLabel) { $feature.UndoLabel } else { $feature.Label }
            Write-Host "Warning: '$displayLabel' requires a reboot to take full effect" -ForegroundColor Yellow
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