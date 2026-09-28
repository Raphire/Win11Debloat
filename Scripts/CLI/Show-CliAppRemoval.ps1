# Shows the CLI app removal menu and prompts the user to select which apps to remove.
function Show-CliAppRemoval {
    Write-CliHeader "应用移除"

    Write-Output "> 正在打开应用选择窗口……"

    $result = Show-AppSelectionWindow

    if ($result -eq $true) {
        Write-Output "已选择移除 $($script:SelectedApps.Count) 个应用。"
        Add-Parameter 'RemoveApps'
        Add-Parameter 'Apps' ($script:SelectedApps -join ',')

        Save-Settings

        # Suppress prompt if Silent parameter was passed
        if (-not $Silent) {
            Write-Output ""
            Write-Output ""
            Write-Output "按回车键移除所选应用，或按 Ctrl+C 退出……"
            Read-Host | Out-Null
            Write-CliHeader "应用移除"
        }
    }
    else {
        Write-Host "已取消选择，未移除任何应用。" -ForegroundColor Red
        Write-Output ""
    }
}