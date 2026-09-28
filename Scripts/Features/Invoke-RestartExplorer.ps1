<#
    .SYNOPSIS
    Restarts Windows Explorer to apply system changes.

    .DESCRIPTION
    Restarts the Explorer process to ensure all UI modifications take effect. Shows a warning if any of the applied features require a reboot to take full effect.
#>
function Invoke-RestartExplorer {
    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[模拟运行] 将重启 Windows 资源管理器。" -ForegroundColor Cyan
        return
    }

    Write-Host "> 正在尝试重启 Windows 资源管理器以应用所有更改……"

    if ($script:Params.ContainsKey('SkipExplorerRestart')) {
        Write-Host "已跳过资源管理器重启，请手动重启电脑以应用所有更改。" -ForegroundColor Yellow
        return
    }

    $rebootFeatures = Get-RebootFeatureLabels
    foreach ($displayLabel in $rebootFeatures) {
        Write-Host "警告：'$displayLabel' 需要重启电脑才能完全生效。" -ForegroundColor Yellow
    }

    # Only restart if the PowerShell process matches the OS architecture.
    # Restarting explorer from a 32bit PowerShell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem) {
        Write-Host "正在重启 Windows 资源管理器……（屏幕可能短暂闪烁）"
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Host "无法重启 Windows 资源管理器，请手动重启电脑以应用所有更改。" -ForegroundColor Yellow
    }
}
