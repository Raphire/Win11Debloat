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
            Write-Host "不支持移除应用 '$appString'，将跳过该应用。" -ForegroundColor Yellow
            continue
        }

        $validatedAppsList += $appString
    }

    return $validatedAppsList
}
