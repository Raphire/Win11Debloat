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
        $friendlyName = Get-Translation -Key $primaryAppId -Field 'FriendlyName' -Section 'Apps'
        $displayName = "$friendlyName ($appIdDisplay)"
        $isChecked = if ($InitialCheckedFromJson) { $appData.SelectedByDefault } else { $false }

        $apps += [PSCustomObject]@{
            AppId = $appIdArray
            AppIdDisplay = $appIdDisplay
            FriendlyName = $friendlyName
            DisplayName = $displayName
            IsChecked = $isChecked
            Description = Get-Translation -Key $primaryAppId -Field 'Description' -Section 'Apps'
            SelectedByDefault = $appData.SelectedByDefault
            Recommendation = $appData.Recommendation
            RemovalMethod = if ($appData.RemovalMethod -and $appData.RemovalMethod -eq 'WinGet') { 'WinGet' } else { 'Appx' }
        }
    }

    return $apps
}

<#
    .SYNOPSIS
        Runs Import-AppDetailsFromJson in a background runspace via Invoke-NonBlocking.

    .DESCRIPTION
        The runspace inherits neither dot-sourced functions nor script-scoped variables, so
        this dot-sources the app loader, its winget helper, and the language loader inside the
        scriptblock, and passes $Lang through to be reassigned to $script:Lang there.

    .PARAMETER OnlyInstalled
        Filters the results to applications detected through Appx or the supplied
        winget installation list.

    .PARAMETER InstalledList
        A pre-fetched winget installation list used when filtering installed apps.

    .PARAMETER InitialCheckedFromJson
        Sets each returned app's IsChecked value from its SelectedByDefault setting.

    .PARAMETER Lang
        The loaded language object ($script:Lang) to make available inside the runspace.
#>
function Invoke-AppDetailsFromJsonAsync {
    param (
        [string]$LoaderScriptPath = $script:LoadAppsDetailsScriptPath,
        [string]$HelperScriptPath = $script:TestAppInWingetListScriptPath,
        [string]$LanguageFileScriptPath = $script:ImportLanguageFileScriptPath,
        [string]$AppsFilePath = $script:AppsListFilePath,
        [object[]]$InstalledList = $null,
        [switch]$OnlyInstalled,
        [switch]$InitialCheckedFromJson,
        [object]$Lang = $script:Lang
    )

    $onlyInstalledValue = [bool]$OnlyInstalled
    $initialCheckedFromJsonValue = [bool]$InitialCheckedFromJson

    return Invoke-NonBlocking -ScriptBlock {
        param($loaderScript, $helperScript, $languageFileScript, $appsListFilePath, $installedList, $onlyInstalled, $initialCheckedFromJson, $Lang)
        $script:AppsListFilePath = $appsListFilePath
        $script:Lang = $Lang
        . $helperScript
        . $languageFileScript
        . $loaderScript
        Import-AppDetailsFromJson -OnlyInstalled:$onlyInstalled -InstalledList $installedList -InitialCheckedFromJson:$initialCheckedFromJson
    } -ArgumentList $LoaderScriptPath, $HelperScriptPath, $LanguageFileScriptPath, $AppsFilePath, $InstalledList, $onlyInstalledValue, $initialCheckedFromJsonValue, $Lang
}
