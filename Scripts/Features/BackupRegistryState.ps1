<#
    .SYNOPSIS
        Creates a timestamped JSON backup of registry state for selected features.

    .DESCRIPTION
        Resolves selected and undo features from the provided keys, captures their
        registry state, and saves the result as a JSON file in the Backups/ folder.
        Returns the file path on success, $null if no registry-backed features exist.

    .PARAMETER ActionableKeys
        Param keys from $script:Params to resolve into apply features.

    .PARAMETER ExtraFeatures
        Additional synthetic feature objects (e.g. undo features) to include.
#>
function New-RegistrySettingsBackup {
    param(
        [string[]]$ActionableKeys,
        [object[]]$ExtraFeatures = @()
    )

    $ActionableKeys = @($ActionableKeys)
    $selectedFeatures = @(Get-SelectedFeatures -ActionableKeys $ActionableKeys)
    $undoFeatures = @($ExtraFeatures | Where-Object { $_ -ne $null })
    $allFeatures = @($selectedFeatures) + @($undoFeatures)
    if (@($allFeatures | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.RegistryKey) }).Count -eq 0) {
        return $null
    }

    $timestamp = Get-Date
    $backupDirectory = $script:RegistryBackupsPath
    if (-not (Test-Path $backupDirectory)) {
        New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    }

    $backupFileName = 'Win11Debloat-RegistryBackup-{0}.json' -f $timestamp.ToString('yyyyMMdd_HHmmss')
    $backupFilePath = Join-Path $backupDirectory $backupFileName

    $backupConfig = Get-RegistryBackupPayload -SelectedFeatures $selectedFeatures -UndoFeatures $undoFeatures -CreatedAt $timestamp
    if (-not (SaveToFile -Config $backupConfig -FilePath $backupFilePath -MaxDepth 25)) {
        throw "Failed to save registry backup to '$backupFilePath'"
    }

    Write-Host "Backup successfully created: $backupFilePath"
    Write-Host ""

    return $backupFilePath
}

<#
    .SYNOPSIS
        Resolves param keys into deduplicated feature objects from the catalog.

    .PARAMETER ActionableKeys
        Param keys to look up in $script:Features.
#>
function Get-SelectedFeatures {
    param(
        [string[]]$ActionableKeys
    )

    $selectedFeatures = New-Object System.Collections.Generic.List[object]
    $selectedFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($paramKey in $ActionableKeys) {
        if (-not $script:Features.ContainsKey($paramKey)) { continue }

        $feature = $script:Features[$paramKey]
        if (-not $feature) { continue }

        $featureId = [string]$feature.FeatureId
        if ($selectedFeatureIds.Add($featureId)) {
            $selectedFeatures.Add($feature)
        }
    }

    return @($selectedFeatures.ToArray())
}

<#
    .SYNOPSIS
        Builds the full backup payload object from selected and undo features.

    .DESCRIPTION
        Deduplicates feature IDs, resolves registry capture plans, snapshots all
        registry keys, and assembles the final backup hashtable with metadata.

    .PARAMETER SelectedFeatures
        Feature objects from the apply side.

    .PARAMETER UndoFeatures
        Synthetic feature objects from the undo side.

    .PARAMETER CreatedAt
        Timestamp recorded in the backup metadata.
#>
function Get-RegistryBackupPayload {
    param(
        [object[]]$SelectedFeatures = @(),
        [object[]]$UndoFeatures = @(),
        [Parameter(Mandatory)]
        [datetime]$CreatedAt
    )

    $selectedFeatureIds = New-Object System.Collections.Generic.List[string]
    $seenSelectedFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($feature in $SelectedFeatures) {
        $featureId = [string]$feature.FeatureId
        if ($seenSelectedFeatureIds.Add($featureId)) {
            $selectedFeatureIds.Add($featureId)
        }
    }

    $selectedUndoFeatureIds = New-Object System.Collections.Generic.List[string]
    $seenUndoFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($feature in $UndoFeatures) {
        $featureId = [string]$feature.FeatureId
        if ($seenUndoFeatureIds.Add($featureId)) {
            $selectedUndoFeatureIds.Add($featureId)
        }
    }

    $selectedRegistryFeatures = @(Get-RegistryBackedFeatures -Features $SelectedFeatures)
    $undoRegistryFeatures = @($UndoFeatures | Where-Object { 
        -not [string]::IsNullOrWhiteSpace([string]$_.RegistryUndoKey) -or -not [string]::IsNullOrWhiteSpace([string]$_.RegistryKey)
    })
    $capturePlans = @(Get-RegistryBackupCapturePlans -SelectedRegistryFeatures $selectedRegistryFeatures -UndoRegistryFeatures $undoRegistryFeatures)
    $registryKeys = @(Get-RegistrySnapshotsForBackup -CapturePlans $capturePlans)

    $backupPayload = @{
        Version = '1.0'
        BackupType = 'RegistryState'
        CreatedAt = $CreatedAt.ToString('o')
        CreatedBy = 'Win11Debloat'
        Target = (Get-RegistryBackupTargetDescription)
        ComputerName = $env:COMPUTERNAME
        SelectedFeatures = @($selectedFeatureIds)
        RegistryKeys = @($registryKeys)
    }

    if ($selectedUndoFeatureIds.Count -gt 0) {
        $backupPayload['SelectedUndoFeatures'] = @($selectedUndoFeatureIds)
    }

    return $backupPayload
}
