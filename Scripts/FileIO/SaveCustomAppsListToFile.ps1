# Saves the provided appsList to the CustomAppsList file
function SaveCustomAppsListToFile {
    param (
        $appsList
    )

    $script:SelectedApps = $appsList

    # Create file that stores selected apps if it doesn't exist
    if (-not (Test-Path $script:CustomAppsListFilePath)) {
        $null = New-Item $script:CustomAppsListFilePath -ItemType File
    }

    Set-Content -Path $script:CustomAppsListFilePath -Value $script:SelectedApps
}
