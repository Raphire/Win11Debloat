# Show CLI default mode options for removing apps, or set selection if RunDefaults or RunDefaultsLite parameter was passed
function Show-CliDefaultModeOptions {
    if ($RunDefaults) {
        $RemoveAppsInput = '1'
    }
    elseif ($RunDefaultsLite) {
        $RemoveAppsInput = '0'                
    }
    else {
        $RemoveAppsInput = Show-CliDefaultModeAppRemovalOptions

        if ($RemoveAppsInput -eq '2' -and ($script:SelectedApps.contains('Microsoft.XboxGameOverlay') -or $script:SelectedApps.contains('Microsoft.XboxGamingOverlay')) -and 
          $( Read-Host -Prompt "是否禁用游戏栏集成和游戏／屏幕录制？这也会阻止 ms-gamingoverlay 和 ms-gamebar 弹窗。（输入 y 确认，n 取消）" ) -eq 'y') {
            $DisableGameBarIntegrationInput = $true;
        }
    }

    Write-CliHeader '默认模式'

    try {
        # Select app removal options based on user input
        switch ($RemoveAppsInput) {
            '1' {
                Add-Parameter 'RemoveApps'
                Add-Parameter 'Apps' 'Default'
            }
            '2' {
                Add-Parameter 'RemoveApps'
                Add-Parameter 'Apps' ($script:SelectedApps -join ',')

                if ($DisableGameBarIntegrationInput) {
                    Add-Parameter 'DisableDVR'
                    Add-Parameter 'DisableGameBarIntegration'
                }
            }
        }

        Import-Settings -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"
    }
    catch {
        Write-Error "无法从 DefaultSettings.json 文件加载设置：$_"
        Wait-ForKeyPress -ExitCode 1
    }

    Save-Settings

    if ($Silent) {
        # Skip change summary and confirmation prompt
        return
    }

    Write-PendingChanges
    Write-CliHeader '默认模式'
}
