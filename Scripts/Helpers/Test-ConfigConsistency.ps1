<#
    .SYNOPSIS
        Validates that a configuration file is structurally consistent before it is applied.

    .DESCRIPTION
        Returns $null when the configuration is valid, otherwise a string describing the
        first problem found. Used by both the CLI and GUI import paths to reject invalid
        configs before any settings are applied.

    .OUTPUTS
        System.String. $null when valid, otherwise an error message.
#>
function Test-ConfigConsistency {
    param($Config)

    if (-not $Config) {
        return Get-Translation -Key 'ConfigEmptyOrUnreadable'
    }

    if (-not $Config.Version) {
        return Get-Translation -Key 'ConfigMissingVersion'
    }

    if (-not $Config.Apps -and -not $Config.Tweaks -and -not $Config.Deployment) {
        return Get-Translation -Key 'ConfigNoImportableData'
    }

    if ($null -ne $Config.Apps) {
        if ($Config.Apps -isnot [string] -and $Config.Apps -isnot [System.Collections.IEnumerable]) {
            return Get-Translation -Key 'ConfigAppsMustBeStrings'
        }
        foreach ($app in @($Config.Apps)) {
            if ($app -isnot [string]) {
                return Get-Translation -Key 'ConfigAppsMustBeStrings'
            }
        }
    }

    foreach ($categoryName in @('Tweaks', 'Deployment')) {
        $category = $Config.$categoryName
        if ($null -eq $category) { continue }

        if ($category -is [string] -or $category -isnot [System.Collections.IEnumerable]) {
            return Get-Translation -Key 'ConfigEntriesMustHaveNameAndValue' -FormatArgs @($categoryName)
        }
        foreach ($setting in @($category)) {
            $hasName = if ($setting -is [System.Collections.IDictionary]) { $setting.Contains('Name') } else { $null -ne $setting.PSObject.Properties['Name'] }
            $hasValue = if ($setting -is [System.Collections.IDictionary]) { $setting.Contains('Value') } else { $null -ne $setting.PSObject.Properties['Value'] }
            if (-not $setting -or -not $hasName -or -not $hasValue -or $setting.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($setting.Name)) {
                return Get-Translation -Key 'ConfigEntriesMustHaveNameAndValue' -FormatArgs @($categoryName)
            }
        }
    }

    $lookup = @{}
    foreach ($setting in @($Config.Deployment)) {
        if ($setting -and $setting.Name) {
            $lookup[$setting.Name] = $setting.Value
        }
    }

    $hasScope = $lookup.ContainsKey('AppRemovalScopeIndex')
    $hasUser = $lookup.ContainsKey('UserSelectionIndex')

    $scopeIndex = $null
    if ($hasScope) {
        if (-not [int]::TryParse("$($lookup['AppRemovalScopeIndex'])", [ref]$scopeIndex) -or $scopeIndex -notin @(0, 1, 2)) {
            return Get-Translation -Key 'ConfigInvalidAppRemovalScopeIndex'
        }
    }

    $userIndex = $null
    if ($hasUser) {
        if (-not [int]::TryParse("$($lookup['UserSelectionIndex'])", [ref]$userIndex) -or $userIndex -notin @(0, 1, 2)) {
            return Get-Translation -Key 'ConfigInvalidUserSelectionIndex'
        }
    }

    # "Current user only" (index 1) is only valid together with "Current User" (index 0)
    if ($hasScope -and $scopeIndex -eq 1) {
        if (-not $hasUser -or $userIndex -ne 0) {
            return Get-Translation -Key 'ConfigScopeRequiresCurrentUserTarget'
        }
    }

    # "Target user only" (index 2) is only valid together with "Other User" (index 1)
    if ($hasScope -and $scopeIndex -eq 2) {
        if (-not $hasUser -or $userIndex -ne 1) {
            return Get-Translation -Key 'ConfigScopeRequiresOtherUserTarget'
        }
        if (-not $lookup.ContainsKey('OtherUsername') -or [string]::IsNullOrWhiteSpace("$($lookup['OtherUsername'])")) {
            return Get-Translation -Key 'ConfigScopeRequiresOtherUsername'
        }
    }

    return $null
}
