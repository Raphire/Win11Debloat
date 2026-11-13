<#
    .SYNOPSIS
        Returns the installed Appx package names, cached for the current session.

    .DESCRIPTION
        Get-AppxPackage is slow enough that calling it on every apps-tab refresh is
        noticeable. This helper keeps the result in a script-scoped cache so repeated
        refreshes (toggling the "only installed" filter) reuse one enumeration.

        The cache holds a single enumeration for the process lifetime. Call
        Reset-InstalledAppxNameCache to force a fresh enumeration, for example after
        the user removes an app and wants the list to reflect it.

        The names are returned as a plain string array so they survive being handed
        to a background runspace, where a HashSet would not.

    .PARAMETER Reset
        Discards the cached enumeration before reading, so the next call re-enumerates.

    .OUTPUTS
        System.String[]. The installed package names. Empty when the enumeration
        fails, so callers fall back to per-app queries.
#>
function Get-InstalledAppxNameSet {
    [CmdletBinding()]
    param (
        [switch]$Reset
    )

    if ($Reset) {
        $script:InstalledAppxNameCache = $null
    }

    if ($null -ne $script:InstalledAppxNameCache) {
        return $script:InstalledAppxNameCache
    }

    $names = @()

    try {
        foreach ($installedApp in @(Get-AppxPackage -ErrorAction SilentlyContinue)) {
            if ($installedApp.Name -is [string] -and $installedApp.Name) {
                $names += $installedApp.Name
            }
        }
    }
    catch {
        # An empty result makes the caller fall back to per-app lookups instead of
        # reporting every app as not installed.
        Write-Warning "Unable to enumerate installed Appx packages: $($_.Exception.Message)"
        $script:InstalledAppxNameCache = @()
        return $script:InstalledAppxNameCache
    }

    # Case-insensitive lookup mirrors what the catalog comparison needs.
    $script:InstalledAppxNameCache = @($names | Sort-Object -Unique)
    return $script:InstalledAppxNameCache
}

<#
    .SYNOPSIS
        Discards the cached Appx package name enumeration.

    .DESCRIPTION
        Forces the next Get-InstalledAppxNameSet call to enumerate again, so a freshly
        installed or removed app is picked up.
#>
function Reset-InstalledAppxNameCache {
    $script:InstalledAppxNameCache = $null
}

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

    .PARAMETER InstalledAppxNames
        A pre-fetched set of installed Appx package names. When supplied, the function
        uses it instead of enumerating Get-AppxPackage itself, so a caller that
        refreshes repeatedly can reuse one enumeration.

    .OUTPUTS
        System.Management.Automation.PSCustomObject[]
        Application detail objects containing display, selection, and removal data.
#>
function Import-AppDetailsFromJson {
    param (
        [switch]$OnlyInstalled,
        [object[]]$InstalledList = $null,
        [switch]$InitialCheckedFromJson,
        [object[]]$InstalledAppxNames = $null
    )

    $apps = @()
    try {
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to read Apps.json: $_"
        return $apps
    }

    $installedAppNames = @{}
    if ($OnlyInstalled) {
        # Get-AppxPackage is expensive; query it once and use its package names for the catalog lookup.
        # A caller can pass a pre-fetched set so repeated refreshes reuse one enumeration.
        $appxNames = $InstalledAppxNames
        if ($null -eq $appxNames) {
            $appxNames = @(Get-InstalledAppxNameSet)
        }

        foreach ($appxName in $appxNames) {
            if ($appxName -is [string]) {
                $installedAppNames[$appxName] = $true
            }
        }
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
                if ($installedAppNames.ContainsKey($appId)) {
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

    # The runspace is a fresh powershell instance, so a script-scoped cache cannot be
    # shared with it. Resolve the installed package names here and hand them over, so
    # repeated refreshes reuse one enumeration instead of one per runspace.
    $installedAppxNames = $null
    if ($onlyInstalledValue) {
        $installedAppxNames = [string[]]@(Get-InstalledAppxNameSet)
    }

    return Invoke-NonBlocking -ScriptBlock {
        param($loaderScript, $helperScript, $languageFileScript, $appsListFilePath, $installedList, $onlyInstalled, $initialCheckedFromJson, $Lang, $appxNames)
        $script:AppsListFilePath = $appsListFilePath
        $script:Lang = $Lang
        . $helperScript
        . $languageFileScript
        . $loaderScript
        Import-AppDetailsFromJson -OnlyInstalled:$onlyInstalled -InstalledList $installedList -InitialCheckedFromJson:$initialCheckedFromJson -InstalledAppxNames $appxNames
    } -ArgumentList $LoaderScriptPath, $HelperScriptPath, $LanguageFileScriptPath, $AppsFilePath, $InstalledList, $onlyInstalledValue, $initialCheckedFromJsonValue, $Lang, $installedAppxNames
}
