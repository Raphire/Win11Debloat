# Shows the CLI last used settings from LastUsedSettings.json file, displays pending changes and prompts the user to apply them.
function Show-CliLastUsedSettings {
    Write-CliHeader 'Custom Mode'

    try {
        Import-Settings -filePath $script:SavedSettingsFilePath -expectedVersion "1.0"
    }
    catch {
        Write-Error "Failed to load settings from LastUsedSettings.json file: $_"
        Wait-ForKeyPress
    }

    if ($Silent) {
        # Skip change summary and confirmation prompt
        return
    }

    Write-PendingChanges
    Write-CliHeader 'Custom Mode'
}