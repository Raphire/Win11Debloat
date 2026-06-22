<#
    .SYNOPSIS
        Creates a lightweight state object for the restore-backup dialog result.

    .DESCRIPTION
        Encapsulates the user's dialog choice (Result), the selected backup file
        path, and the parsed backup payload so callers receive a single object.
#>
function New-RestoreDialogState {
    param(
        [string]$Result = 'Cancel',
        [string]$SelectedFile = $null,
        $Backup = $null
    )

    return @{ Result = $Result; SelectedFile = $SelectedFile; Backup = $Backup }
}

<#
    .SYNOPSIS
        Looks up a feature definition by ID from the provided feature catalog.

    .PARAMETER FeatureId
        The identifier to search for (e.g. 'DisableTelemetry').

    .PARAMETER Features
        A hashtable loaded from Features.json (FeatureId -> feature object).
#>
function Get-RestoreDialogFeatureDefinition {
    param(
        [string]$FeatureId,
        [hashtable]$Features
    )

    if ([string]::IsNullOrWhiteSpace($FeatureId) -or -not $Features) {
        return $null
    }

    if ($Features.ContainsKey($FeatureId)) {
        return $Features[$FeatureId]
    }

    return $null
}

<#
    .SYNOPSIS
        Determines whether a feature can be automatically reverted via registry restore.

    .DESCRIPTION
        Returns $true when the feature has a non-empty RegistryKey, indicating
        an apply .reg file exists that can be undone automatically. Features
        with custom logic (no RegistryKey) must be manually reverted.

    .PARAMETER FeatureId
        The feature identifier to check.

    .PARAMETER Features
        A hashtable loaded from Features.json.
#>
function Test-RestoreDialogFeatureCanAutoRevert {
    param(
        [string]$FeatureId,
        [hashtable]$Features
    )

    if ([string]::IsNullOrWhiteSpace($FeatureId)) {
        return $false
    }

    $featureDefinition = Get-RestoreDialogFeatureDefinition -FeatureId $FeatureId -Features $Features
    if ($featureDefinition) {
        return -not [string]::IsNullOrWhiteSpace([string]$featureDefinition.RegistryKey)
    }

    return $false
}

<#
    .SYNOPSIS
        Resolves a human-readable label for a feature shown in the restore dialog.

    .DESCRIPTION
        Returns the feature's Label from Features.json when found, falling back
        to the raw FeatureId string. For null/empty FeatureIds returns 'Unknown feature'.

    .PARAMETER FeatureId
        The feature identifier to resolve a label for.

    .PARAMETER Features
        A hashtable loaded from Features.json.
#>
function Get-RestoreDialogFeatureDisplayLabel {
    param(
        [string]$FeatureId,
        [hashtable]$Features
    )

    if ([string]::IsNullOrWhiteSpace($FeatureId)) {
        return 'Unknown feature'
    }

    $featureDefinition = Get-RestoreDialogFeatureDefinition -FeatureId $FeatureId -Features $Features
    if ($featureDefinition) {
        return [string]$featureDefinition.Label
    }

    return $FeatureId
}

<#
    .SYNOPSIS
        Checks whether a feature should appear in the restore dialog's overview list.

    .DESCRIPTION
        A feature is considered visible when it exists in the catalog and has
        a non-empty Category (meaning it belongs to a UI grouping). Features
        without a Category are hidden from the overview.

    .PARAMETER FeatureId
        The feature identifier to check.

    .PARAMETER Features
        A hashtable loaded from Features.json.
#>
function Test-RestoreDialogFeatureVisibleInOverview {
    param(
        [string]$FeatureId,
        [hashtable]$Features
    )

    if ([string]::IsNullOrWhiteSpace($FeatureId)) {
        return $false
    }

    $featureDefinition = Get-RestoreDialogFeatureDefinition -FeatureId $FeatureId -Features $Features
    if (-not $featureDefinition) {
        return $false
    }

    return -not [string]::IsNullOrWhiteSpace([string]$featureDefinition.Category)
}

<#
    .SYNOPSIS
        Extracts deduplicated forward (apply) feature IDs from a backup payload.

    .PARAMETER SelectedBackup
        The parsed backup object containing a SelectedFeatures property.
#>
function Get-SelectedForwardFeatureIdsFromBackup {
    param($SelectedBackup)

    $selectedFeatureIds = New-Object System.Collections.Generic.List[string]
    $seenSelectedFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($featureId in @($SelectedBackup.SelectedFeatures)) {
        if ([string]::IsNullOrWhiteSpace([string]$featureId)) {
            continue
        }

        $normalizedId = [string]$featureId
        if ($seenSelectedFeatureIds.Add($normalizedId)) {
            $selectedFeatureIds.Add($normalizedId)
        }
    }

    return @($selectedFeatureIds.ToArray())
}

<#
    .SYNOPSIS
        Extracts deduplicated undo feature IDs from a backup payload.

    .PARAMETER SelectedBackup
        The parsed backup object containing a SelectedUndoFeatures property.
#>
function Get-SelectedUndoFeatureIdsFromBackup {
    param($SelectedBackup)

    $selectedUndoFeatureIds = New-Object System.Collections.Generic.List[string]
    $seenUndoFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($featureId in @($SelectedBackup.SelectedUndoFeatures)) {
        if ([string]::IsNullOrWhiteSpace([string]$featureId)) {
            continue
        }

        $normalizedId = [string]$featureId
        if ($seenUndoFeatureIds.Add($normalizedId)) {
            $selectedUndoFeatureIds.Add($normalizedId)
        }
    }

    return @($selectedUndoFeatureIds.ToArray())
}

<#
    .SYNOPSIS
        Merges forward and undo feature IDs from a backup into a single deduplicated list.

    .PARAMETER SelectedBackup
        The parsed backup object containing SelectedFeatures and SelectedUndoFeatures.
#>
function Get-CombinedSelectedFeatureIdsFromBackup {
    param($SelectedBackup)

    $featureIds = New-Object System.Collections.Generic.List[string]
    $seenIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($featureId in @(Get-SelectedForwardFeatureIdsFromBackup -SelectedBackup $SelectedBackup) + @(Get-SelectedUndoFeatureIdsFromBackup -SelectedBackup $SelectedBackup)) {
        if ([string]::IsNullOrWhiteSpace([string]$featureId)) {
            continue
        }

        $normalizedId = [string]$featureId
        if ($seenIds.Add($normalizedId)) {
            $featureIds.Add($normalizedId)
        }
    }

    return @($featureIds.ToArray())
}

<#
    .SYNOPSIS
        Convenience wrapper that returns all combined feature IDs from a backup.

    .PARAMETER SelectedBackup
        The parsed backup object.
#>
function Get-SelectedFeatureIdsFromBackup {
    param($SelectedBackup)

    return @(Get-CombinedSelectedFeatureIdsFromBackup -SelectedBackup $SelectedBackup)
}

<#
    .SYNOPSIS
        Splits selected feature IDs into revertible and non-revertible lists for display.

    .DESCRIPTION
        Iterates the provided feature IDs, filters to those visible in the overview,
        and separates them into auto-revertible (has a RegistryKey) and non-revertible
        (requires manual undo) buckets. Each entry includes a display label.

    .PARAMETER SelectedFeatureIds
        The list of feature IDs to categorize.

    .PARAMETER Features
        A hashtable loaded from Features.json.
#>
function Get-RestoreBackupFeatureLists {
    param(
        [string[]]$SelectedFeatureIds,
        [hashtable]$Features
    )

    $revertibleFeaturesList = @()
    $nonRevertibleFeaturesList = @()

    foreach ($featureId in $SelectedFeatureIds) {
        if (-not (Test-RestoreDialogFeatureVisibleInOverview -FeatureId $featureId -Features $Features)) {
            continue
        }

        $displayItem = [PSCustomObject]@{ DisplayText = "- $(Get-RestoreDialogFeatureDisplayLabel -FeatureId $featureId -Features $Features)" }
        if (Test-RestoreDialogFeatureCanAutoRevert -FeatureId $featureId -Features $Features) {
            $revertibleFeaturesList += $displayItem
        }
        else {
            $nonRevertibleFeaturesList += $displayItem
        }
    }

    return [PSCustomObject]@{
        Revertible = @($revertibleFeaturesList)
        NonRevertible = @($nonRevertibleFeaturesList)
    }
}
