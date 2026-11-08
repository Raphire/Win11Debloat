<#
    .SYNOPSIS
    Resolves display labels for selected features that require reboot.

    .DESCRIPTION
    Combines parameter keys from both forward and undo selections, removes duplicates,
    and returns the feature label that should be shown to users. Undo selections use
    UndoLabel when available.
#>
function Get-RebootFeatureLabels {
    $rebootFeatureLabels = [System.Collections.Generic.List[string]]::new()
    $candidateParamKeys = (@($script:Params.Keys) + @($script:UndoParams.Keys)) | Select-Object -Unique

    foreach ($paramKey in $candidateParamKeys) {
        if ($script:Features.ContainsKey($paramKey) -and $script:Features[$paramKey].RequiresReboot -eq $true) {
            $feature = $script:Features[$paramKey]
            $isUndo = $script:UndoParams.ContainsKey($paramKey)
            $displayLabel = if ($isUndo -and $feature.UndoLabel) { Get-Translation -Key $paramKey -Field 'UndoLabel' -Section 'Features' } else { Get-Translation -Key $paramKey -Field 'Label' -Section 'Features' }

            if (-not [string]::IsNullOrWhiteSpace([string]$displayLabel)) {
                [void]$rebootFeatureLabels.Add([string]$displayLabel)
            }
        }
    }

    return $rebootFeatureLabels
}

<#
    .SYNOPSIS
        Resolves one deferred-removal display label per catalog app, grouping its package IDs.
#>
function Get-DeferredAppRemovalLabels {
    if (-not $script:WingetDeferredRemovals -or $script:WingetDeferredRemovals.Count -eq 0) { return }

    $catalog = Import-JsonFile -filePath $script:AppsListFilePath
    $primaryIds = @{}
    foreach ($app in $catalog.Apps) {
        $ids = @($app.AppId)
        foreach ($id in $ids) { $primaryIds[$id] = $ids[0] }
    }

    $deferredPrimaryIds = foreach ($appId in $script:WingetDeferredRemovals.Keys) {
        if ($primaryIds.ContainsKey($appId)) { $primaryIds[$appId] } else { $appId }
    }
    foreach ($appId in @($deferredPrimaryIds | Sort-Object -Unique)) {
        Get-Translation -Key $appId -Field 'FriendlyName' -Section 'Apps'
    }
}
