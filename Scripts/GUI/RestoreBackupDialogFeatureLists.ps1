function New-RestoreDialogState {
    param(
        [string]$Result = 'Cancel',
        [string]$SelectedFile = $null,
        $Backup = $null
    )

    return @{ Result = $Result; SelectedFile = $SelectedFile; Backup = $Backup }
}

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

function Get-RestoreDialogFeatureDisplayLabel {
    param(
        [string]$FeatureId,
        [hashtable]$Features
    )

    if ([string]::IsNullOrWhiteSpace($FeatureId)) {
        return 'Unknown feature'
    }

    $featureDefinition = Get-RestoreDialogFeatureDefinition -FeatureId $FeatureId -Features $Features
    if ($featureDefinition -and -not [string]::IsNullOrWhiteSpace([string]$featureDefinition.Label)) {
        return [string]$featureDefinition.Label
    }

    return $FeatureId
}

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

function Get-SelectedFeatureIdsFromBackup {
    param($SelectedBackup)

    $featureIds = New-Object System.Collections.Generic.List[string]
    $seenIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($featureId in @($SelectedBackup.SelectedFeatures) + @($SelectedBackup.SelectedUndoFeatures)) {
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
