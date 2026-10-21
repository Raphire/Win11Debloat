<#
    .SYNOPSIS
        Extracts and deduplicates the SelectedFeatures list from a backup, validating each entry.

    .DESCRIPTION
        Returns an empty SelectedFeatures array with an error when the property is missing
        entirely, and flags (without stopping) any entry that isn't a non-empty string.
#>
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
        $errors.Add((Get-Translation -Key 'BackupMissingProperty' -FormatArgs @('SelectedFeatures')))
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
        $errors.Add((Get-Translation -Key 'BackupSelectedFeaturesMustBeStrings'))
    }

    return [PSCustomObject]@{
        SelectedFeatures = $selectedFeatures.ToArray()
        Errors = $errors.ToArray()
    }
}

<#
    .SYNOPSIS
        Extracts and deduplicates the SelectedUndoFeatures list from a backup, validating each entry.

    .DESCRIPTION
        Unlike SelectedFeatures, this property is optional: a missing property returns an
        empty array with no error, since not every backup has undone features to restore.
#>
function Get-NormalizedSelectedUndoFeatureIdsFromBackup {
    param(
        [Parameter(Mandatory)]
        $Backup
    )

    $selectedUndoFeatures = New-Object System.Collections.Generic.List[string]
    $selectedUndoFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $errors = New-Object System.Collections.Generic.List[string]

    # SelectedUndoFeatures is optional - only process if present
    if (-not $Backup.PSObject.Properties['SelectedUndoFeatures']) {
        return [PSCustomObject]@{
            SelectedUndoFeatures = $selectedUndoFeatures.ToArray()
            Errors = $errors.ToArray()
        }
    }

    $hasInvalidSelectedUndoFeatureId = $false
    foreach ($featureId in @($Backup.SelectedUndoFeatures)) {
        if ($featureId -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$featureId)) {
            $hasInvalidSelectedUndoFeatureId = $true
            continue
        }

        $normalizedFeatureId = [string]$featureId
        if ($selectedUndoFeatureIds.Add($normalizedFeatureId)) {
            $selectedUndoFeatures.Add($normalizedFeatureId)
        }
    }

    if ($hasInvalidSelectedUndoFeatureId) {
        $errors.Add((Get-Translation -Key 'BackupSelectedUndoFeaturesMustBeStrings'))
    }

    return [PSCustomObject]@{
        SelectedUndoFeatures = $selectedUndoFeatures.ToArray()
        Errors = $errors.ToArray()
    }
}

<#
    .SYNOPSIS
        Normalizes a raw registry key snapshot into a consistent shape, recursing into sub-keys.

    .DESCRIPTION
        Fills in defaults for optional properties (Values, SubKeys) so downstream
        validation can read a predictable shape regardless of what the backup file omitted.
        Requires Path and a Boolean Exists to avoid interpreting missing data as deletion.
#>
function Normalize-RegistryKeySnapshot {
    param(
        [Parameter(Mandatory)]
        $Snapshot
    )

    if (-not $Snapshot.PSObject.Properties['Path'] -or [string]::IsNullOrWhiteSpace([string]$Snapshot.Path)) {
        throw (Get-Translation -Key 'BackupSnapshotMissingPath')
    }

    if (-not $Snapshot.PSObject.Properties['Exists'] -or $Snapshot.Exists -isnot [bool]) {
        throw (Get-Translation -Key 'BackupSnapshotInvalidExists' -FormatArgs @($Snapshot.Path))
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
        Exists = $Snapshot.Exists
        OriginallyAbsent = ($Snapshot.OriginallyAbsent -is [bool] -and $Snapshot.OriginallyAbsent)
        Values = @($values)
        SubKeys = @($subKeys)
    }
}

<#
    .SYNOPSIS
        Validates that a backup's registry snapshots only contain paths and values the
        selected (and undo) features are actually allowed to touch.

    .DESCRIPTION
        Builds an allow-list from the capture plans of the selected features, then checks
        every snapshot against it. Returns an array of translated error strings; an empty
        array means the backup is valid.

#>
function Test-RegistryBackupMatchesSelectedFeatures {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SelectedFeatureIds,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SelectedUndoFeatureIds,
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RegistryKeys
    )

    $errors = New-Object System.Collections.Generic.List[string]

    $planMap = Get-RegistryBackupValidationPlanMap -SelectedFeatureIds $SelectedFeatureIds -SelectedUndoFeatureIds $SelectedUndoFeatureIds -Target $Target -Errors $errors

    if ($errors.Count -gt 0) {
        return $errors.ToArray()
    }

    return Test-RegistryBackupAgainstAllowList -RegistryKeys $RegistryKeys -PlanMap $planMap
}

<#
    .SYNOPSIS
        Validates registry snapshots against an already derived trusted allow-list.

    .DESCRIPTION
        Internal helper shared by feature-based validation and the import workflow.
        The plan map must come from Get-RegistryBackupValidationPlanMap, never backup data.
        When ExecutableValueWarnings is supplied, executable content mismatches are collected
        for confirmation instead of blocking import. All other validation errors remain blocking.
#>
function Test-RegistryBackupAgainstAllowList {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RegistryKeys,
        [Parameter(Mandatory)]
        [hashtable]$PlanMap,
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$ExecutableValueWarnings
    )

    $errors = New-Object System.Collections.Generic.List[string]

    if ($PlanMap.Count -eq 0 -and @($RegistryKeys).Count -gt 0) {
        $errors.Add((Get-Translation -Key 'BackupNoAllowedRegistryPaths'))
    }

    foreach ($rootSnapshot in @($RegistryKeys)) {
        Test-RegistrySnapshotAgainstAllowList -Snapshot $rootSnapshot -PlanMap $PlanMap -Errors $errors -ExecutableValueWarnings $ExecutableValueWarnings
    }

    return $errors.ToArray()
}

<#
    .SYNOPSIS
        Derives trusted registry permissions once for backup conversion and validation.
#>
function Get-RegistryBackupValidationPlanMap {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SelectedFeatureIds,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SelectedUndoFeatureIds,
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Errors
    )

    if (-not $script:Features -or $script:Features.Count -eq 0) {
        $Errors.Add((Get-Translation -Key 'BackupFeatureCatalogNotLoaded'))
        return @{}
    }

    $selectedRegistryFeatures = @(Get-SelectedRegistryFeaturesForBackupValidation -SelectedFeatureIds @($SelectedFeatureIds) -IsUndoFeature:$false -Errors $Errors)
    $undoRegistryFeatures = @(Get-SelectedRegistryFeaturesForBackupValidation -SelectedFeatureIds @($SelectedUndoFeatureIds) -IsUndoFeature:$true -Errors $Errors)
    $useSysprepRegFiles = ($Target -eq 'DefaultUserProfile') -or ($Target -like 'User:*')

    $capturePlans = @()
    if ($Errors.Count -eq 0 -and ($selectedRegistryFeatures.Count -gt 0 -or $undoRegistryFeatures.Count -gt 0)) {
        $capturePlans = @(Get-RegistryBackupCapturePlans -SelectedRegistryFeatures @($selectedRegistryFeatures) -UndoRegistryFeatures @($undoRegistryFeatures) -UseSysprepRegFiles:$useSysprepRegFiles)
    }

    $planMap = New-RegistryBackupAllowListPlanMap -CapturePlans @($capturePlans)
    if ($planMap.Count -gt 0) {
        # Catalog data supplies trusted content only; selected plans still authorize locations and operations.
        $trustedValueMap = Get-RegistryBackupTrustedValueMap -Features @($script:Features.Values) -UseSysprepRegFiles:$useSysprepRegFiles
        foreach ($plan in $planMap.Values) {
            $plan | Add-Member -MemberType NoteProperty -Name TrustedValueMap -Value $trustedValueMap
        }
    }
    return $planMap
}

<#
    .SYNOPSIS
        Reads trusted executable value data from both directions of catalog features.

    .DESCRIPTION
        This supplies data comparisons only; the selected operation's capture plan still
        controls which paths and value names may be restored. Backup fields never supply trust.
#>
function Get-RegistryBackupTrustedValueMap {
    param(
        [object[]]$Features = @(),
        [switch]$UseSysprepRegFiles
    )

    $trustedValueMap = @{}
    $filePaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($feature in $Features) {
        if (-not [string]::IsNullOrWhiteSpace([string]$feature.RegistryKey)) {
            $null = $filePaths.Add((Get-RegistryFilePathForFeature -RegistryKey $feature.RegistryKey -UseSysprepRegFiles:$UseSysprepRegFiles))
        }
        $undoPath = Resolve-RegistryBackupUndoFilePath -Feature $feature
        if (-not [string]::IsNullOrWhiteSpace($undoPath)) { $null = $filePaths.Add($undoPath) }
    }

    foreach ($filePath in $filePaths) {
        # A missing counterpart cannot authorize data; the active direction is checked by capture planning.
        if (-not (Test-Path -LiteralPath $filePath)) { continue }
        foreach ($operation in @(Get-RegFileOperations -regFilePath $filePath)) {
            if ($operation.OperationType -ne 'SetValue' -or
                -not (Test-RegistryValueMayExecuteCode -Path $operation.KeyPath -ValueName $operation.ValueName -KindName $operation.ValueType)) { continue }
            $pathKey = Get-NormalizedRegistryPathKey -Path $operation.KeyPath
            if (-not $trustedValueMap.ContainsKey($pathKey)) { $trustedValueMap[$pathKey] = @{} }
            $name = [string]$operation.ValueName
            $trustedValueMap[$pathKey][$name] = @($trustedValueMap[$pathKey][$name]) + @($operation)
        }
    }
    return $trustedValueMap
}

<#
    .SYNOPSIS
        Identifies command lines, COM server registrations, and executable indirections.
#>
function Test-RegistryValueMayExecuteCode {
    param([string]$Path, [AllowEmptyString()][string]$ValueName, [string]$KindName = 'String')

    $parts = Split-RegistryPath -path $Path
    if (-not $parts) { return $false }
    return $parts.SubKey -match '(?i)(?:^|\\)(?:Run|RunOnce|RunOnceEx|InprocServer(?:32)?|InprocHandler(?:32)?|LocalServer(?:32)?|TreatAs|AutoTreatAs|AutoConvertTo|ScriptletURL)(?:\\|$)' -or
        $parts.SubKey -match '(?i)\\shell\\[^\\]+\\(?:command|ddeexec)(?:\\|$)' -or
        ($ValueName -eq '' -and $parts.SubKey -match '(?i)\\shellex\\ContextMenuHandlers\\[^\\]+$') -or
        # COM activation can use string indirections outside InprocServer32. Numeric settings are not server paths.
        ($KindName -notin @('DWord', 'QWord') -and $parts.SubKey -match '(?i)(?:^|\\)CLSID\\[^\\]+(?:\\|$)') -or
        $ValueName -match '^(?i:DelegateExecute|ExplorerCommandHandler|ScriptletURL|DllSurrogate|DllSurrogateExecutable)$'
}

function Test-RegistryExecutableValueDataAllowed {
    param($Snapshot, [string]$Path, [hashtable]$TrustedValueMap)

    $kind = [System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], [string]$Snapshot.Kind, $true)
    if (-not (Test-RegistryValueMayExecuteCode -Path $Path -ValueName $Snapshot.Name -KindName $kind.ToString())) { return $true }
    $stringKinds = @([Microsoft.Win32.RegistryValueKind]::String, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    if ($kind -notin ($stringKinds + @([Microsoft.Win32.RegistryValueKind]::DWord, [Microsoft.Win32.RegistryValueKind]::QWord))) { return $false }
    # Empty executable registrations cannot supply a command or DLL path.
    if ($kind -in $stringKinds -and ($null -eq $Snapshot.Data -or [string]$Snapshot.Data -ceq '')) { return $true }
    $pathKey = Get-NormalizedRegistryPathKey -Path $Path
    if ($null -eq $TrustedValueMap -or -not $TrustedValueMap.ContainsKey($pathKey)) { return $false }
    foreach ($operation in @($TrustedValueMap[$pathKey][[string]$Snapshot.Name])) {
        if ($null -eq $operation) { continue }
        $trustedKind = if ($operation.ValueType -eq 'Hex2') { 'ExpandString' } else { $operation.ValueType }
        if ($kind.ToString() -eq $trustedKind -and [string]$Snapshot.Data -ceq [string]$operation.ValueData) { return $true }
    }
    return $false
}

<#
    .SYNOPSIS
        Converts legacy absent value-only keys into scoped missing-value snapshots.

    .DESCRIPTION
        Uses only trusted feature plans. Empty absent-key snapshots at exact value-only
        paths are converted in memory; authorized tree deletions and invalid snapshots
        remain unchanged for subsequent validation. The input snapshots are not modified.
#>
function ConvertTo-CompatibleRegistryKeySnapshots {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RegistryKeys,
        [Parameter(Mandatory)]
        [hashtable]$PlanMap
    )

    foreach ($snapshot in $RegistryKeys) {
        $normalizedPath = Get-NormalizedRegistryPathKey -Path $snapshot.Path
        $plan = if ($normalizedPath) { $PlanMap[$normalizedPath] } else { $null }
        $convertAbsentKey = $snapshot.Exists -is [bool] -and -not $snapshot.Exists -and
            @($snapshot.Values).Count -eq 0 -and @($snapshot.SubKeys).Count -eq 0 -and
            $null -ne $plan -and -not $plan.CaptureAllValues -and -not $plan.IncludeSubKeys -and
            $plan.ValueNames.Count -gt 0 -and
            -not (Test-RegistryKeyDeletionAllowed -NormalizedPath $normalizedPath -PlanMap $PlanMap)

        $originallyAbsent = $convertAbsentKey -or ($snapshot.OriginallyAbsent -is [bool] -and $snapshot.OriginallyAbsent)
        # Absence is backup data; permission to clean up comes from an exact, nonrecursive plan.
        # RemoveEmptyKey is derived here and is deliberately not read by normalization.
        $removeEmptyKey = $originallyAbsent -and ($snapshot.Exists -or $convertAbsentKey) -and
            $null -ne $plan -and -not $plan.CaptureAllValues -and -not $plan.IncludeSubKeys -and
            @($snapshot.SubKeys).Count -eq 0 -and
            @($snapshot.Values | Where-Object { [bool]$_.Exists }).Count -eq 0

        [PSCustomObject]@{
            Path = $snapshot.Path
            Exists = if ($convertAbsentKey) { $true } else { $snapshot.Exists }
            OriginallyAbsent = $originallyAbsent
            RemoveEmptyKey = $removeEmptyKey
            Values = @(
                if ($convertAbsentKey) {
                    foreach ($valueName in @($plan.ValueNames | Sort-Object)) {
                        [PSCustomObject]@{ Name = $valueName; Exists = $false; Kind = $null; Data = $null }
                    }
                } else { $snapshot.Values }
            )
            SubKeys = @(ConvertTo-CompatibleRegistryKeySnapshots -RegistryKeys @($snapshot.SubKeys) -PlanMap $PlanMap)
        }
    }
}

<#
    .SYNOPSIS
        Resolves selected feature IDs to their catalog entries, keeping only the ones with a
        registry-backed apply or undo key relevant to the requested direction.

    .DESCRIPTION
        Appends a translated error to the caller-supplied Errors list for any feature ID that
        isn't in the current catalog, rather than failing the whole validation outright.
#>
function Get-SelectedRegistryFeaturesForBackupValidation {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SelectedFeatureIds,
        [Parameter(Mandatory)]
        [bool]$IsUndoFeature,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        $Errors
    )

    if ($null -eq $Errors -or -not ($Errors -is [System.Collections.IList])) {
        throw 'Get-SelectedRegistryFeaturesForBackupValidation requires Errors to be a mutable list collection.'
    }
    # Intentionally not localized: this throw signals a programming error (a caller passing the
    # wrong collection type), not a condition a user's backup file can trigger.

    $selectedRegistryFeatures = New-Object System.Collections.Generic.List[object]
    foreach ($featureId in @($SelectedFeatureIds)) {
        if (-not $script:Features.ContainsKey($featureId)) {
            $Errors.Add((Get-Translation -Key 'BackupFeatureNotInCatalog' -FormatArgs @($featureId)))
            continue
        }

        $feature = $script:Features[$featureId]
        if (-not $feature) {
            continue
        }

        # For undo features, check RegistryUndoKey if present (real features)
        # Otherwise check RegistryKey (for synthetic features from backup capture)
        $registryKeyToUse = if ($IsUndoFeature) {
            $key = [string]$feature.RegistryUndoKey
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                $key
            }
            else {
                [string]$feature.RegistryKey
            }
        }
        else {
            [string]$feature.RegistryKey
        }

        if (-not [string]::IsNullOrWhiteSpace($registryKeyToUse)) {
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
            AllowDeleteKey = [bool]$plan.AllowDeleteKey
            ValueNames = ConvertTo-RegistryValueNameSet -ValueNames @($plan.ValueNames)
        }
    }

    return $planMap
}

<#
    .SYNOPSIS
        Converts registry value names into a case-insensitive set.

    .DESCRIPTION
        Preserves empty names and prevents PowerShell from enumerating the returned
        HashSet.
#>
function ConvertTo-RegistryValueNameSet {
    param(
        [AllowEmptyCollection()]
        [string[]]$ValueNames
    )

    $valueNameSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($valueName in @($ValueNames)) {
        $null = $valueNameSet.Add([string]$valueName)
    }

    # Prevent PowerShell from enumerating the HashSet into an array or single string
    return ,$valueNameSet
}

<#
    .SYNOPSIS
        Validates a registry snapshot against the selected-feature allow list.

    .DESCRIPTION
        Recursively validates snapshot paths, value names, value kinds, and value
        data, appending validation errors to the supplied list.
#>
function Test-RegistrySnapshotAgainstAllowList {
    param(
        [Parameter(Mandatory)]
        $Snapshot,
        [Parameter(Mandatory)]
        [hashtable]$PlanMap,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Errors,
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$ExecutableValueWarnings
    )

    $snapshotPath = [string]$Snapshot.Path
    $normalizedPath = Get-NormalizedRegistryPathKey -Path $snapshotPath
    if ([string]::IsNullOrWhiteSpace($normalizedPath) -or $snapshotPath.IndexOf([char]0) -ge 0) {
        $Errors.Add((Get-Translation -Key 'BackupUnsupportedRegistryPath' -FormatArgs @($snapshotPath)))
        return
    }

    $planMatch = Find-RegistryAllowListPlanMatch -NormalizedPath $normalizedPath -PlanMap $PlanMap
    if ($null -eq $planMatch) {
        $Errors.Add((Get-Translation -Key 'BackupUnexpectedRegistryPath' -FormatArgs @($snapshotPath)))
        return
    }

    if (-not $Snapshot.PSObject.Properties['Exists'] -or $Snapshot.Exists -isnot [bool]) {
        $Errors.Add((Get-Translation -Key 'BackupSnapshotInvalidExists' -FormatArgs @($snapshotPath)))
        return
    }

    if (-not $Snapshot.Exists -and -not (Test-RegistryKeyDeletionAllowed -NormalizedPath $normalizedPath -PlanMap $PlanMap)) {
        $Errors.Add((Get-Translation -Key 'BackupUnexpectedKeyDeletion' -FormatArgs @($snapshotPath)))
    }

    foreach ($valueSnapshot in @($Snapshot.Values)) {
        $valueName = Get-NormalizedRegistryValueName -ValueName $valueSnapshot.Name
        $valueExists = [bool]$valueSnapshot.Exists

        if ($valueName.IndexOf([char]0) -ge 0 -or -not (Test-RegistryValueAllowedByPlan -PlanMatch $planMatch -ValueName $valueName)) {
            $Errors.Add((Get-Translation -Key 'BackupUnexpectedValue' -FormatArgs @($valueName, $snapshotPath)))
        }

        $kindName = if ($valueSnapshot.PSObject.Properties['Kind']) { [string]$valueSnapshot.Kind } else { '' }
        $valueReference = Get-RegistryValueReferenceForError -SnapshotPath $snapshotPath -ValueName $valueName
        if ($valueExists) {
            if (-not (Test-RegistryValueKindNameSupported -KindName $kindName)) {
                $Errors.Add((Get-Translation -Key 'BackupUnsupportedValueKind' -FormatArgs @($kindName, $valueReference)))
            }
            elseif (-not (Test-RegistryValueDataMatchesKind -KindName $kindName -Data $valueSnapshot.Data)) {
                $Errors.Add((Get-Translation -Key 'BackupInvalidValueData' -FormatArgs @($kindName, $valueReference)))
            }
            elseif (-not (Test-RegistryExecutableValueDataAllowed -Snapshot $valueSnapshot -Path $snapshotPath -TrustedValueMap $planMatch.TrustedValueMap)) {
                if ($null -eq $ExecutableValueWarnings) {
                    $Errors.Add((Get-Translation -Key 'BackupUnsafeExecutableValue' -FormatArgs @($valueReference)))
                }
                else {
                    $ExecutableValueWarnings.Add([PSCustomObject]@{
                        Path = $snapshotPath
                        Name = $valueName
                        Kind = $kindName
                        Data = $valueSnapshot.Data
                    })
                }
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($kindName)) {
            $Errors.Add((Get-Translation -Key 'BackupValueMustNotDefineKind' -FormatArgs @($valueReference)))
        }
    }

    foreach ($subKeySnapshot in @($Snapshot.SubKeys)) {
        Test-RegistrySnapshotAgainstAllowList -Snapshot $subKeySnapshot -PlanMap $PlanMap -Errors $Errors -ExecutableValueWarnings $ExecutableValueWarnings
    }
}

<#
    .SYNOPSIS
        Tests whether backed-up registry data is valid for its declared value kind.

    .DESCRIPTION
        Rejects corrupted or hand-edited backup data that cannot be restored safely,
        such as a DWord that overflows UInt32 or binary data containing an invalid byte.
        This validation runs before Restore-RegistryKeySnapshot mutates the live
        registry, preventing a failed conversion from leaving a partially restored key.

    .PARAMETER KindName
        The declared registry value kind name, such as DWord, QWord, or Binary.

    .PARAMETER Data
        The backed-up value data to validate against the declared kind.

    .OUTPUTS
        System.Boolean
#>
function Test-RegistryValueDataMatchesKind {
    param(
        [Parameter(Mandatory)]
        [string]$KindName,
        [AllowNull()]
        $Data
    )

    $kind = [System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], $KindName, $true)
    switch ($kind) {
        ([Microsoft.Win32.RegistryValueKind]::DWord) {
            $parsed = [uint32]0
            return [uint32]::TryParse([string]$Data, [System.Globalization.NumberStyles]::Integer, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)
        }
        ([Microsoft.Win32.RegistryValueKind]::QWord) {
            $parsed = [uint64]0
            return [uint64]::TryParse([string]$Data, [System.Globalization.NumberStyles]::Integer, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)
        }
        ([Microsoft.Win32.RegistryValueKind]::Binary) {
            if ($null -eq $Data -or $Data -isnot [array]) { return $false }
            foreach ($item in @($Data)) {
                if ($item -isnot [ValueType] -and $item -isnot [string]) { return $false }
                $parsed = 0
                if (-not [int]::TryParse([string]$item, [ref]$parsed) -or $parsed -lt 0 -or $parsed -gt 255) {
                    return $false
                }
            }
            return $true
        }
        ([Microsoft.Win32.RegistryValueKind]::MultiString) {
            foreach ($item in @($Data)) {
                if ($item -isnot [string]) { return $false }
            }
            return $true
        }
        default { return ($null -eq $Data -or $Data -is [string]) }
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

<#
    .SYNOPSIS
        Checks whether selected feature operations authorize deletion of a key tree.

    .DESCRIPTION
        Only DeleteKey operations grant this permission. Checks all plans so an exact
        value-only plan cannot hide a recursive deletion allowed by an ancestor.
#>
function Test-RegistryKeyDeletionAllowed {
    param(
        [Parameter(Mandatory)]
        [string]$NormalizedPath,
        [Parameter(Mandatory)]
        [hashtable]$PlanMap
    )

    foreach ($plan in $PlanMap.Values) {
        if (-not $plan.AllowDeleteKey) { continue }

        if ($NormalizedPath.Equals($plan.NormalizedPath, [System.StringComparison]::OrdinalIgnoreCase) -or
            ($plan.IncludeSubKeys -and $NormalizedPath.StartsWith("$($plan.NormalizedPath)\", [System.StringComparison]::OrdinalIgnoreCase))) {
            return $true
        }
    }

    return $false
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
            TrustedValueMap = $plan.TrustedValueMap
        }
    }

    foreach ($plan in @($PlanMap.Values)) {
        if (-not [bool]$plan.IncludeSubKeys) {
            continue
        }

        $subKeyPrefix = "$($plan.NormalizedPath)\"
        if ($NormalizedPath.StartsWith($subKeyPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return [PSCustomObject]@{
                IsDescendant = $true
                CaptureAllValues = $true
                ValueNames = $plan.ValueNames
                TrustedValueMap = $plan.TrustedValueMap
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

<#
    .SYNOPSIS
        Tests whether a registry value-kind name is supported in backups.

    .DESCRIPTION
        Parses kind names case-insensitively and rejects empty, invalid, Unknown,
        and None values.
#>
function Test-RegistryValueKindNameSupported {
    param(
        [string]$KindName
    )

    if ([string]::IsNullOrWhiteSpace($KindName)) {
        return $false
    }

    try {
        $kind = [System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], $KindName, $true)
        return [System.Enum]::IsDefined([Microsoft.Win32.RegistryValueKind], $kind) -and
            $kind -notin @([Microsoft.Win32.RegistryValueKind]::Unknown, [Microsoft.Win32.RegistryValueKind]::None)
    }
    catch {
        return $false
    }
}

