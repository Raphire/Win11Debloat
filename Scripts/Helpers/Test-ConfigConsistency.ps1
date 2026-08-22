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
        return 'Configuration is empty or could not be read.'
    }

    if (-not $Config.Version) {
        return 'Configuration is missing a Version field.'
    }

    if (-not $Config.Apps -and -not $Config.Tweaks -and -not $Config.Deployment) {
        return 'The configuration file contains no importable data.'
    }

    if ($null -ne $Config.Apps) {
        if ($Config.Apps -isnot [string] -and $Config.Apps -isnot [System.Collections.IEnumerable]) {
            return 'Configuration Apps entries must be strings.'
        }
        foreach ($app in @($Config.Apps)) {
            if ($app -isnot [string]) {
                return 'Configuration Apps entries must be strings.'
            }
        }
    }

    foreach ($categoryName in @('Tweaks', 'Deployment')) {
        $category = $Config.$categoryName
        if ($null -eq $category) { continue }

        if ($category -is [string] -or $category -isnot [System.Collections.IEnumerable]) {
            return "Configuration $categoryName entries must contain Name and Value properties."
        }
        foreach ($setting in @($category)) {
            $hasName = if ($setting -is [System.Collections.IDictionary]) { $setting.Contains('Name') } else { $null -ne $setting.PSObject.Properties['Name'] }
            $hasValue = if ($setting -is [System.Collections.IDictionary]) { $setting.Contains('Value') } else { $null -ne $setting.PSObject.Properties['Value'] }
            if (-not $setting -or -not $hasName -or -not $hasValue -or $setting.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($setting.Name)) {
                return "Configuration $categoryName entries must contain Name and Value properties."
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
            return 'AppRemovalScopeIndex must be a supported numeric value (0, 1, or 2).'
        }
    }

    $userIndex = $null
    if ($hasUser) {
        if (-not [int]::TryParse("$($lookup['UserSelectionIndex'])", [ref]$userIndex) -or $userIndex -notin @(0, 1, 2)) {
            return 'UserSelectionIndex must be a supported numeric value (0, 1, or 2).'
        }
    }

    # "Current user only" (index 1) is only valid together with "Current User" (index 0)
    if ($hasScope -and $scopeIndex -eq 1) {
        if (-not $hasUser -or $userIndex -ne 0) {
            return "App removal scope 'Current user only' (AppRemovalScopeIndex 1) requires the deployment target 'Current User' (UserSelectionIndex 0)."
        }
    }

    # "Target user only" (index 2) is only valid together with "Other User" (index 1)
    if ($hasScope -and $scopeIndex -eq 2) {
        if (-not $hasUser -or $userIndex -ne 1) {
            return "App removal scope 'Target user only' (AppRemovalScopeIndex 2) requires the deployment target 'Other User' (UserSelectionIndex 1)."
        }
        if (-not $lookup.ContainsKey('OtherUsername') -or [string]::IsNullOrWhiteSpace("$($lookup['OtherUsername'])")) {
            return "App removal scope 'Target user only' (AppRemovalScopeIndex 2) requires an 'OtherUsername' value."
        }
    }

    return $null
}
