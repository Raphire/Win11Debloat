# Show CLI default mode options for removing apps, or set selection if RunDefaults or RunDefaultsLite parameter was passed
function ShowCLIDefaultModeOptions {
    if ($RunDefaults) {
        $RemoveAppsInput = '1'
    }
    elseif ($RunDefaultsLite) {
        $RemoveAppsInput = '0'                
    }
    else {
        $RemoveAppsInput = ShowCLIDefaultModeAppRemovalOptions

        if ($RemoveAppsInput -eq '2' -and ($script:SelectedApps.contains('Microsoft.XboxGameOverlay') -or $script:SelectedApps.contains('Microsoft.XboxGamingOverlay')) -and 
          $( Read-Host -Prompt "Disable Game Bar integration and game/screen recording? This also stops ms-gamingoverlay and ms-gamebar popups (y/n)" ) -eq 'y') {
            $DisableGameBarIntegrationInput = $true;
        }
    }

    PrintHeader 'Default Mode'

    # Add default settings based on user input
    try {
        # Select app removal options based on user input
        switch ($RemoveAppsInput) {
            '1' {
                AddParameter 'RemoveApps'
                AddParameter 'Apps' 'Default'
            }
            '2' {
                AddParameter 'RemoveAppsCustom'

                if ($DisableGameBarIntegrationInput) {
                    AddParameter 'DisableDVR'
                    AddParameter 'DisableGameBarIntegration'
                }
            }
        }

        # Load settings from DefaultSettings.json and add to params
        LoadSettings -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"
    }
    catch {
        Write-Error "Failed to load settings from DefaultSettings.json file: $_"
        AwaitKeyToExit
    }

    SaveSettings

    # Skip change summary if Silent parameter was passed
    if ($Silent) {
        return
    }

    PrintPendingChanges
    PrintHeader 'Default Mode'
}