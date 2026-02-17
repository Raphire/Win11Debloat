# Read Apps.json and return list of app objects with optional filtering
function LoadAppsDetailsFromJson {
    param (
        [switch]$OnlyInstalled,
        [string]$InstalledList = "",
        [switch]$InitialCheckedFromJson
    )

    $apps = @()
    try {
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to read Apps.json: $_"
        return $apps
    }

    foreach ($appData in $jsonContent.Apps) {
        $appId = $appData.AppId.Trim()
        if ($appId.length -eq 0) { continue }

        if ($OnlyInstalled) {
            if (-not ($InstalledList -like ("*$appId*")) -and -not (Get-AppxPackage -Name $appId)) {
                continue
            }
            if (($appId -eq "Microsoft.Edge") -and -not ($InstalledList -like "* Microsoft.Edge *")) {
                continue
            }
        }

        $friendlyName = if ($appData.FriendlyName) { $appData.FriendlyName } else { $appId }
        $displayName = if ($appData.FriendlyName) { "$($appData.FriendlyName) ($appId)" } else { $appId }
        $isChecked = if ($InitialCheckedFromJson) { $appData.SelectedByDefault } else { $false }

        $apps += [PSCustomObject]@{
            AppId = $appId
            FriendlyName = $friendlyName
            DisplayName = $displayName
            IsChecked = $isChecked
            Description = $appData.Description
            SelectedByDefault = $appData.SelectedByDefault
        }
    }

    return $apps
}
