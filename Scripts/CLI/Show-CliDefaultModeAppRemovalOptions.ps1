# Shows the CLI default mode app removal options. Loops until a valid option is selected.
function Show-CliDefaultModeAppRemovalOptions {
    Write-CliHeader '默认模式'

    Write-Host "提示：默认移除列表包含 Microsoft Teams、Spotify、便笺等应用。选择第 2 项可查看并调整要移除的应用。" -ForegroundColor DarkGray
    Write-Host ""

    Do {
        Write-Host "选项：" -ForegroundColor Yellow
        Write-Host " (n) 不移除任何应用" -ForegroundColor Yellow
        Write-Host " (1) 仅移除默认列表中的应用" -ForegroundColor Yellow
        Write-Host " (2) 手动选择要移除的应用" -ForegroundColor Yellow
        $RemoveAppsInput = Read-Host "是否移除应用？将为所有用户移除所选应用。（输入 n、1 或 2）"

        # Show app selection form if user entered option 3
        if ($RemoveAppsInput -eq '2') {
            $result = Show-AppSelectionWindow

            if ($result -ne $true) {
                # User cancelled or closed app selection, change RemoveAppsInput so the menu will be shown again
                Write-Host ""
                Write-Host "已取消应用选择，请重新选择。" -ForegroundColor Red

                $RemoveAppsInput = 'c'
            }
            
            Write-Host ""
        }
    }
    while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2')

    return $RemoveAppsInput
}