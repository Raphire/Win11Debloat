# Returns the feature metadata for a parameter when it supports undo; otherwise returns $null.
function GetUndoFeatureForParam {
    param (
        [string]$paramKey
    )

    if (-not $script:Features -or -not $script:Features.ContainsKey($paramKey)) {
        return $null
    }

    $feature = $script:Features[$paramKey]
    if (-not ($feature.RegistryUndoKey -and ($feature.UndoText -or $feature.UndoAction))) {
        return $null
    }

    return $feature
}
