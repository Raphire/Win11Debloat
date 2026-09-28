. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

# Shows the CLI last used settings from LastUsedSettings.json file, displays pending changes and prompts the user to apply them.
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
