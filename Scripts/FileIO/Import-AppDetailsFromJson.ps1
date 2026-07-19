<#
    .SYNOPSIS
        Loads application details from Apps.json.

    .DESCRIPTION
        Reads the application definitions from Apps.json, optionally filters the
        results to installed applications, and returns normalized app objects for
        display and selection.

    .PARAMETER OnlyInstalled
        Filters the results to applications detected through Appx or the supplied
        winget installation list.

    .PARAMETER InstalledList
        A pre-fetched winget installation list used when filtering installed apps.

    .PARAMETER InitialCheckedFromJson
        Sets each returned app's IsChecked value from its SelectedByDefault setting.

    .OUTPUTS
        System.Management.Automation.PSCustomObject[]
        Application detail objects containing display, selection, and removal data.
#>
function Import-AppDetailsFromJson {
    param (
        [switch]$OnlyInstalled,
        [object[]]$InstalledList = $null,
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
        $appIdArray = @(
            foreach ($rawAppId in @($appData.AppId)) {
                if ($rawAppId -isnot [string]) { continue }
                $normalizedAppId = $rawAppId.Trim()
                if ($normalizedAppId.Length -gt 0) { $normalizedAppId }
            }
        )
        if ($appIdArray.Count -eq 0) { continue }

        if ($OnlyInstalled) {
            $isInstalled = $false
            foreach ($appId in $appIdArray) {
                # Check Get-AppxPackage first (fast, no process launch)
                if (Get-AppxPackage -Name $appId) {
                    $isInstalled = $true
                    break
                }

                # Then check the pre-fetched winget list
                if ($InstalledList -and (Test-AppInWingetList -appId $appId -InstalledList $InstalledList)) {
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
            RemovalMethod = if ($appData.RemovalMethod -and $appData.RemovalMethod -eq 'WinGet') { 'WinGet' } else { 'Appx' }
        }
    }

    return $apps
}
