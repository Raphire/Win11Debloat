# Returns a validated list of apps based on the provided appsList and the supported apps from Apps.json
function ValidateAppslist {
    param (
        $appsList
    )

    $supportedAppsList = (LoadAppsDetailsFromJson | ForEach-Object { $_.AppId })
    $validatedAppsList = @()

    # Validate provided appsList against supportedAppsList
    Foreach ($app in $appsList) {
        $app = $app.Trim()
        $appString = $app.Trim('*')

        if ($supportedAppsList -notcontains $appString) {
            Write-Host "Removal of app '$appString' is not supported and will be skipped" -ForegroundColor Yellow
            continue
        }

        $validatedAppsList += $appString
    }

    return $validatedAppsList
}
