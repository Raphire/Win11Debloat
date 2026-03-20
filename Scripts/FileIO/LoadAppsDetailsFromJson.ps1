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
        # Handle AppId as array (could be single or multiple IDs)
        $appIdArray = if ($appData.AppId -is [array]) { $appData.AppId } else { @($appData.AppId) }
        $appIdArray = $appIdArray | ForEach-Object { $_.Trim() } | Where-Object { $_.length -gt 0 }
        if ($appIdArray.Count -eq 0) { continue }

        if ($OnlyInstalled) {
            $isInstalled = $false
            foreach ($appId in $appIdArray) {
                if (($InstalledList -like ("*$appId*")) -or (Get-AppxPackage -Name $appId)) {
                    $isInstalled = $true
                    break
                }
                if (($appId -eq "Microsoft.Edge") -and ($InstalledList -like "* Microsoft.Edge *")) {
                    $isInstalled = $true
                    break
                }
            }
            if (-not $isInstalled) { continue }
        }

        # Use first AppId for fallback names, join all for display
        $primaryAppId = $appIdArray[0]
        $appIdDisplay = $appIdArray -join ', '
        $friendlyName = if ($appData.FriendlyName) { $appData.FriendlyName } else { $primaryAppId }
        $displayName = if ($appData.FriendlyName) { "$($appData.FriendlyName) ($appIdDisplay)" } else { $appIdDisplay }
        $isChecked = if ($InitialCheckedFromJson) { $appData.SelectedByDefault } else { $false }

        $apps += [PSCustomObject]@{
            AppId = $appIdArray
            AppIdDisplay = $appIdDisplay
            FriendlyName = $friendlyName
            DisplayName = $displayName
            IsChecked = $isChecked
            Description = $appData.Description
            SelectedByDefault = $appData.SelectedByDefault
            Recommendation = $appData.Recommendation
        }
    }

    return $apps
}
