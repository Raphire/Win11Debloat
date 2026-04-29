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
            SelectedFeatures = $selectedFeatures.ToArray()
            Errors = $errors.ToArray()
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
        SelectedFeatures = $selectedFeatures.ToArray()
        Errors = $errors.ToArray()
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

function Test-RegistryBackupMatchesSelectedFeatures {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SelectedFeatureIds,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RegistryKeys
    )

    $errors = New-Object System.Collections.Generic.List[string]

    if (-not $script:Features -or $script:Features.Count -eq 0) {
        $errors.Add('Unable to validate registry backup allowlist because feature definitions are not loaded.')
        return $errors.ToArray()
    }

    $selectedRegistryFeatures = @(Get-SelectedRegistryFeaturesForBackupValidation -SelectedFeatureIds @($SelectedFeatureIds) -Errors $errors)

    $capturePlans = @()
    if ($errors.Count -eq 0 -and $selectedRegistryFeatures.Count -gt 0) {
        $capturePlans = @(Get-RegistryBackupCapturePlans -SelectedRegistryFeatures @($selectedRegistryFeatures))
    }

    $planMap = New-RegistryBackupAllowListPlanMap -CapturePlans @($capturePlans)

    if ($planMap.Count -eq 0 -and @($RegistryKeys).Count -gt 0) {
        $errors.Add('Backup contains registry snapshots but no allowed registry paths were derived from SelectedFeatures.')
    }

    foreach ($rootSnapshot in @($RegistryKeys)) {
        Test-RegistrySnapshotAgainstAllowList -Snapshot $rootSnapshot -PlanMap $planMap -Errors $errors
    }

    return $errors.ToArray()
}

function Get-SelectedRegistryFeaturesForBackupValidation {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SelectedFeatureIds,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        $Errors
    )

    if ($null -eq $Errors -or -not ($Errors -is [System.Collections.IList])) {
        throw 'Get-SelectedRegistryFeaturesForBackupValidation requires Errors to be a mutable list collection.'
    }

    $selectedRegistryFeatures = New-Object System.Collections.Generic.List[object]
    foreach ($featureId in @($SelectedFeatureIds)) {
        if (-not $script:Features.ContainsKey($featureId)) {
            $Errors.Add("Selected feature '$featureId' was not found in the current feature catalog.")
            continue
        }

        $feature = $script:Features[$featureId]
        if ($feature -and -not [string]::IsNullOrWhiteSpace([string]$feature.RegistryKey)) {
            $selectedRegistryFeatures.Add($feature)
        }
    }

    return $selectedRegistryFeatures.ToArray()
}

function New-RegistryBackupAllowListPlanMap {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CapturePlans
    )

    $planMap = @{}
    foreach ($plan in @($CapturePlans)) {
        $normalizedPath = Get-NormalizedRegistryPathKey -Path $plan.Path
        if ([string]::IsNullOrWhiteSpace($normalizedPath)) {
            continue
        }

        $planMap[$normalizedPath] = [PSCustomObject]@{
            Path = $plan.Path
            NormalizedPath = $normalizedPath
            IncludeSubKeys = [bool]$plan.IncludeSubKeys
            CaptureAllValues = [bool]$plan.CaptureAllValues
            ValueNames = ConvertTo-RegistryValueNameSet -ValueNames @($plan.ValueNames)
        }
    }

    return $planMap
}

function ConvertTo-RegistryValueNameSet {
    param(
        [AllowEmptyCollection()]
        [string[]]$ValueNames
    )

    $valueNameSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($valueName in @($ValueNames)) {
        $null = $valueNameSet.Add([string]$valueName)
    }

    return $valueNameSet
}

function Test-RegistrySnapshotAgainstAllowList {
    param(
        [Parameter(Mandatory)]
        $Snapshot,
        [Parameter(Mandatory)]
        [hashtable]$PlanMap,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Errors
    )

    $snapshotPath = [string]$Snapshot.Path
    $normalizedPath = Get-NormalizedRegistryPathKey -Path $snapshotPath
    if ([string]::IsNullOrWhiteSpace($normalizedPath)) {
        $Errors.Add("Backup contains unsupported registry path '$snapshotPath'.")
        return
    }

    $planMatch = Find-RegistryAllowListPlanMatch -NormalizedPath $normalizedPath -PlanMap $PlanMap
    if ($null -eq $planMatch) {
        $Errors.Add("Backup contains unexpected registry path '$snapshotPath' that is not allowed by SelectedFeatures.")
        return
    }

    foreach ($valueSnapshot in @($Snapshot.Values)) {
        $valueName = Get-NormalizedRegistryValueName -ValueName $valueSnapshot.Name
        $valueExists = [bool]$valueSnapshot.Exists

        if (-not (Test-RegistryValueAllowedByPlan -PlanMatch $planMatch -ValueName $valueName)) {
            $Errors.Add("Backup contains unexpected value '$valueName' under '$snapshotPath'.")
        }

        $kindName = if ($valueSnapshot.PSObject.Properties['Kind']) { [string]$valueSnapshot.Kind } else { '' }
        $valueReference = Get-RegistryValueReferenceForError -SnapshotPath $snapshotPath -ValueName $valueName
        if ($valueExists) {
            if (-not (Test-RegistryValueKindNameSupported -KindName $kindName)) {
                $Errors.Add("Backup contains unsupported registry value kind '$kindName' for '$valueReference'.")
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($kindName)) {
            $Errors.Add("Backup value '$valueReference' must not define Kind when Exists is false.")
        }
    }

    foreach ($subKeySnapshot in @($Snapshot.SubKeys)) {
        Test-RegistrySnapshotAgainstAllowList -Snapshot $subKeySnapshot -PlanMap $PlanMap -Errors $Errors
    }
}

function Test-RegistryValueAllowedByPlan {
    param(
        [Parameter(Mandatory)]
        $PlanMatch,
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ValueName
    )

    $ValueName = Get-NormalizedRegistryValueName -ValueName $ValueName

    if ($PlanMatch.CaptureAllValues -or $PlanMatch.IsDescendant) {
        return $true
    }

    return $PlanMatch.ValueNames.Contains($ValueName)
}

function Get-RegistryValueReferenceForError {
    param(
        [Parameter(Mandatory)]
        [string]$SnapshotPath,
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ValueName
    )

    $ValueName = Get-NormalizedRegistryValueName -ValueName $ValueName

    if ([string]::IsNullOrWhiteSpace($ValueName)) {
        return "$SnapshotPath\\(Default)"
    }

    return "$SnapshotPath\\$ValueName"
}

function Get-NormalizedRegistryValueName {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [object]$ValueName
    )

    if ($null -eq $ValueName) {
        return ''
    }

    return [string]$ValueName
}

function Find-RegistryAllowListPlanMatch {
    param(
        [Parameter(Mandatory)]
        [string]$NormalizedPath,
        [Parameter(Mandatory)]
        [hashtable]$PlanMap
    )

    if ($PlanMap.ContainsKey($NormalizedPath)) {
        $plan = $PlanMap[$NormalizedPath]
        return [PSCustomObject]@{
            IsDescendant = $false
            CaptureAllValues = [bool]$plan.CaptureAllValues
            ValueNames = $plan.ValueNames
        }
    }

    foreach ($plan in @($PlanMap.Values)) {
        if (-not [bool]$plan.IncludeSubKeys) {
            continue
        }

        $subKeyPrefix = "$($plan.NormalizedPath)\\"
        if ($NormalizedPath.StartsWith($subKeyPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [PSCustomObject]@{
                IsDescendant = $true
                CaptureAllValues = $true
                ValueNames = $plan.ValueNames
            }
        }
    }

    return $null
}

function Get-NormalizedRegistryPathKey {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $parts = Split-RegistryPath -path $Path
    if (-not $parts) {
        return $null
    }

    $hiveName = [string]$parts.Hive
    if ([string]::IsNullOrWhiteSpace($hiveName)) {
        return $null
    }

    $normalizedHive = $hiveName.ToUpperInvariant()
    $subKey = [string]$parts.SubKey
    if ([string]::IsNullOrWhiteSpace($subKey)) {
        return $normalizedHive
    }

    $normalizedSubKey = ($subKey -replace '/', '\\').Trim('\')
    if ([string]::IsNullOrWhiteSpace($normalizedSubKey)) {
        return $normalizedHive
    }

    return "$normalizedHive\\$normalizedSubKey"
}

function Test-RegistryValueKindNameSupported {
    param(
        [string]$KindName
    )

    if ([string]::IsNullOrWhiteSpace($KindName)) {
        return $false
    }

    try {
        $kind = [System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], $KindName, $true)
        return $kind -ne [Microsoft.Win32.RegistryValueKind]::Unknown
    }
    catch {
        return $false
    }
}
