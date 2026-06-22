<#
    .SYNOPSIS
    Checks whether an app ID appears in a parsed winget installed list.

    .DESCRIPTION
    Tries an exact match against the .Id property first. When that
    fails, falls back to a substring search guarded by a word-boundary
    regex so that short IDs don't accidentally match longer ones
    (e.g. 'Microsoft.Edge' will not match 'Microsoft.EdgeDev').

    .PARAMETER appId
    The identifier to search for (e.g. 'Microsoft.Copilot').

    .PARAMETER InstalledList
    An array of PSCustomObject from GetInstalledAppsViaWinget.
#>
function Test-AppInWingetList {
    param(
        [string]$appId,
        [object[]]$InstalledList
    )

    if (-not $InstalledList) { return $false }

    # Normalize to array
    $list = @($InstalledList)

    # Exact match first (fast and precise)
    if ($list.Id -contains $appId) {
        return $true
    }

    # Substring fallback with word-boundary guard
    $boundaryPattern = '(?<![a-zA-Z0-9])' + [regex]::Escape($appId) + '(?![a-zA-Z0-9])'

    foreach ($entry in $list) {
        if ($entry.Id -like "*$appId*" -and $entry.Id -match $boundaryPattern) {
            return $true
        }
    }

    return $false
}
