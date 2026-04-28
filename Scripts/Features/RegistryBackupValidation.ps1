function Get-NormalizedSelectedFeatureIdsFromBackup {
    param(
        [Parameter(Mandatory)]
        $Backup
    )

    $selectedFeatures = New-Object System.Collections.Generic.List[string]
    $selectedFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $errors = New-Object System.Collections.Generic.List[string]
    $hasInvalidSelectedFeatureId = $false

    if (-not $Backup.PSObject.Properties['SelectedFeatures']) {
        $errors.Add('Missing property: SelectedFeatures')
        return [PSCustomObject]@{
            SelectedFeatures = @($selectedFeatures)
            Errors = @($errors)
        }
    }

    foreach ($featureId in @($Backup.SelectedFeatures)) {
        if ($featureId -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$featureId)) {
            $hasInvalidSelectedFeatureId = $true
            continue
        }

        $normalizedFeatureId = [string]$featureId
        if ($selectedFeatureIds.Add($normalizedFeatureId)) {
            $selectedFeatures.Add($normalizedFeatureId)
        }
    }

    if ($hasInvalidSelectedFeatureId) {
        $errors.Add('SelectedFeatures must contain non-empty string feature IDs.')
    }

    if ($selectedFeatures.Count -eq 0) {
        $errors.Add('SelectedFeatures must contain at least one feature ID.')
    }

    return [PSCustomObject]@{
        SelectedFeatures = @($selectedFeatures)
        Errors = @($errors)
    }
}

function Normalize-RegistryKeySnapshot {
    param(
        [Parameter(Mandatory)]
        $Snapshot
    )

    if (-not $Snapshot.PSObject.Properties['Path'] -or [string]::IsNullOrWhiteSpace([string]$Snapshot.Path)) {
        throw 'Backup validation failed: Registry key snapshot is missing Path.'
    }

    $exists = $false
    if ($Snapshot.PSObject.Properties['Exists']) {
        $exists = [bool]$Snapshot.Exists
    }

    $values = @()
    if ($Snapshot.PSObject.Properties['Values']) {
        foreach ($valueSnapshot in @($Snapshot.Values)) {
            $valueExists = $true
            if ($valueSnapshot.PSObject.Properties['Exists']) {
                $valueExists = [bool]$valueSnapshot.Exists
            }

            $values += [PSCustomObject]@{
                Name = [string]$valueSnapshot.Name
                Exists = $valueExists
                Kind = if ($valueSnapshot.PSObject.Properties['Kind']) { [string]$valueSnapshot.Kind } else { $null }
                Data = if ($valueSnapshot.PSObject.Properties['Data']) { $valueSnapshot.Data } else { $null }
            }
        }
    }

    $subKeys = @()
    if ($Snapshot.PSObject.Properties['SubKeys']) {
        foreach ($subKeySnapshot in @($Snapshot.SubKeys)) {
            $subKeys += @(Normalize-RegistryKeySnapshot -Snapshot $subKeySnapshot)
        }
    }

    return [PSCustomObject]@{
        Path = [string]$Snapshot.Path
        Exists = $exists
        Values = @($values)
        SubKeys = @($subKeys)
    }
}
