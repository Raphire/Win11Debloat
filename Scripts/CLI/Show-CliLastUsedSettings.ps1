. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        载入上次保存的设置，并在非静默模式显示待执行更改。
    .DESCRIPTION
        从 SavedSettingsFilePath 读取版本 1.0 的设置，失败时报告错误并退出。
        静默模式直接返回；否则显示更改摘要并等待用户确认，本函数不执行更改。
#>
function Show-CliLastUsedSettings {
    Write-CliHeader (Get-ConsoleTranslation -Text 'Custom Mode')

    try {
        Import-Settings -filePath $script:SavedSettingsFilePath -expectedVersion "1.0"
    }
    catch {
        Write-Error (Get-ConsoleTranslation -Text 'Failed to load settings from LastUsedSettings.json file: {0}' -FormatArgs @($_))
        Wait-ForKeyPress -ExitCode 1
    }

    if ($Silent) {
        # Skip change summary and confirmation prompt
        return
    }

    Write-PendingChanges
    Write-CliHeader (Get-ConsoleTranslation -Text 'Custom Mode')
}
