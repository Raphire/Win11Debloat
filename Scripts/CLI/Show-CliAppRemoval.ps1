. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        从命令行打开应用选择窗口，并保存确认后的卸载选项。
    .DESCRIPTION
        选择成功后记录 RemoveApps 和应用 ID，保存设置；非静默模式等待回车确认，
        用户也可按 Ctrl+C 退出。取消选择时只显示提示，本函数不执行应用卸载。
#>
function Show-CliAppRemoval {
    Write-CliHeader (Get-ConsoleTranslation -Text 'App Removal')

    Write-Output (Get-ConsoleTranslation -Text '> Opening app selection form...')

    $result = Show-AppSelectionWindow

    if ($result -eq $true) {
        Write-Output (Get-ConsoleTranslation -Text 'You have selected {0} apps for removal' -FormatArgs @($($script:SelectedApps.Count)))
        Add-Parameter 'RemoveApps'
        Add-Parameter 'Apps' ($script:SelectedApps -join ',')

        Save-Settings

        # Suppress prompt if Silent parameter was passed
        if (-not $Silent) {
            Write-Output ""
            Write-Output ""
            Write-Output (Get-ConsoleTranslation -Text 'Press enter to remove the selected apps or press CTRL+C to quit...')
            Read-Host | Out-Null
            Write-CliHeader (Get-ConsoleTranslation -Text 'App Removal')
        }
    }
    else {
        Write-Host (Get-ConsoleTranslation -Text 'Selection was cancelled, no apps have been removed') -ForegroundColor Red
        Write-Output ""
    }
}
