# Shows the CLI last used settings from LastUsedSettings.json file, displays pending changes and prompts the user to apply them.
function ShowCLILastUsedSettings {
    PrintHeader 'Custom Mode'

    try {
        LoadSettings -filePath $script:SavedSettingsFilePath -expectedVersion "1.0"
    }
    catch {
        Write-Error "Failed to load settings from LastUsedSettings.json file: $_"
        AwaitKeyToExit
    }

    if ($Silent) {
        # Skip change summary and confirmation prompt
        return
    }

    PrintPendingChanges
    PrintHeader 'Custom Mode'
}