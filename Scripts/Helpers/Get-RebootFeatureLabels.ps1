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
            $displayLabel = if ($isUndo -and $feature.UndoLabel) { $feature.UndoLabel } else { $feature.Label }

            if (-not [string]::IsNullOrWhiteSpace([string]$displayLabel)) {
                [void]$rebootFeatureLabels.Add([string]$displayLabel)
            }
        }
    }

    return $rebootFeatureLabels
}