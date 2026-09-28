. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        确定默认模式的应用选择，载入并保存默认设置。
    .DESCRIPTION
        RunDefaults 使用默认卸载列表，RunDefaultsLite 不卸载应用；否则询问用户。
        手动选择游戏栏应用时可追加相关禁用选项。载入默认设置失败时报告错误并退出。
        非静默模式显示待执行更改并等待确认；本函数不执行这些更改。
#>
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
          $( Read-Host -Prompt (Get-ConsoleTranslation -Text 'Disable Game Bar integration and game/screen recording? This also stops ms-gamingoverlay and ms-gamebar popups (y/n)') ) -eq 'y') {
            $DisableGameBarIntegrationInput = $true;
        }
    }

    Write-CliHeader (Get-ConsoleTranslation -Text 'Default Mode')

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
        Write-Error (Get-ConsoleTranslation -Text 'Failed to load settings from DefaultSettings.json file: {0}' -FormatArgs @($_))
        Wait-ForKeyPress -ExitCode 1
    }

    Save-Settings

    if ($Silent) {
        # Skip change summary and confirmation prompt
        return
    }

    Write-PendingChanges
    Write-CliHeader (Get-ConsoleTranslation -Text 'Default Mode')
}
