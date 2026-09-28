# Shows the CLI menu options and prompts the user to select one. Loops until a valid option is selected.
function Show-CliMenuOptions {
    Do { 
        $ModeSelectionMessage = "请选择一项（1/2）"

        Write-CliHeader 'Menu'

        Write-Host "(1) 默认模式：快速应用推荐的更改"
        Write-Host "(2) 应用移除模式：选择并移除应用，不进行其他更改"

        # Only show this option if SavedSettings file exists
        if (Test-Path $script:SavedSettingsFilePath) {
            Write-Host "(3) 快速应用上次使用的设置"
            
            $ModeSelectionMessage = "请选择一项（1/2/3）"
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
