. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

# Shows the CLI app removal menu and prompts the user to select which apps to remove.
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