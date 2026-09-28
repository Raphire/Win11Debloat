. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

# Returns a validated list of apps based on the provided appsList and the supported apps from Apps.json
function Get-ValidatedAppList {
    param (
        $appsList
    )

    $supportedAppsList = @(Import-AppDetailsFromJson | ForEach-Object { @($_.AppId) }) | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
    $validatedAppsList = @()

    # Validate provided appsList against supportedAppsList
    Foreach ($app in $appsList) {
        $app = $app.Trim()
        $appString = $app.Trim('*')

        if ($supportedAppsList -notcontains $appString) {
            Write-Host (Get-ConsoleTranslation -Text 'Removal of app ''{0}'' is not supported and will be skipped' -FormatArgs @($appString)) -ForegroundColor Yellow
            continue
        }

        $validatedAppsList += $appString
    }

    return $validatedAppsList
}
