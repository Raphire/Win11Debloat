. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

# Shows the CLI menu options and prompts the user to select one. Loops until a valid option is selected.
function Show-CliMenuOptions {
    Do {
        $ModeSelectionMessage = (Get-ConsoleTranslation -Text 'Please select an option (1/2)')

        Write-CliHeader (Get-ConsoleTranslation -Text 'Menu')

        Write-Host (Get-ConsoleTranslation -Text '(1) Default mode: Quickly apply the recommended changes')
        Write-Host (Get-ConsoleTranslation -Text '(2) App removal mode: Select & remove apps, without making other changes')

        # Only show this option if SavedSettings file exists
        if (Test-Path $script:SavedSettingsFilePath) {
            Write-Host (Get-ConsoleTranslation -Text '(3) Quickly apply your last used settings')

            $ModeSelectionMessage = (Get-ConsoleTranslation -Text 'Please select an option (1/2/3)')
        }

        Write-Host ""
        Write-Host ""

        $Mode = Read-Host $ModeSelectionMessage

        if (($Mode -eq '3') -and -not (Test-Path $script:SavedSettingsFilePath)) {
            $Mode = $null
        }
    }
    while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3')

    return $Mode
}
