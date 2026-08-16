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

    $lookup = @{}
    foreach ($setting in @($Config.Deployment)) {
        if ($setting -and $setting.Name) {
            $lookup[$setting.Name] = $setting.Value
        }
    }

    $hasScope = $lookup.ContainsKey('AppRemovalScopeIndex')
    $hasUser = $lookup.ContainsKey('UserSelectionIndex')

    # "Current user only" (index 1) is only valid together with "Current User" (index 0)
    if ($hasScope -and [int]$lookup['AppRemovalScopeIndex'] -eq 1) {
        if (-not $hasUser -or [int]$lookup['UserSelectionIndex'] -ne 0) {
            return "App removal scope 'Current user only' (AppRemovalScopeIndex 1) requires the deployment target 'Current User' (UserSelectionIndex 0)."
        }
    }

    # "Target user only" (index 2) is only valid together with "Other User" (index 1)
    if ($hasScope -and [int]$lookup['AppRemovalScopeIndex'] -eq 2) {
        if (-not $hasUser -or [int]$lookup['UserSelectionIndex'] -ne 1) {
            return "App removal scope 'Target user only' (AppRemovalScopeIndex 2) requires the deployment target 'Other User' (UserSelectionIndex 1)."
        }
        if (-not $lookup.ContainsKey('OtherUsername') -or [string]::IsNullOrWhiteSpace("$($lookup['OtherUsername'])")) {
            return "App removal scope 'Target user only' (AppRemovalScopeIndex 2) requires an 'OtherUsername' value."
        }
    }

    return $null
}
