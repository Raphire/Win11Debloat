<#
    .SYNOPSIS
        Loads a registry backup from a JSON file and normalizes its contents.

    .DESCRIPTION
        Loads a registry backup from disk and returns a normalized representation
        of its contents suitable for use by the restore workflow. Throws if the
        file is missing, unreadable, or not valid JSON.

    .PARAMETER FilePath
        The absolute path to the registry backup JSON file to load.

    .OUTPUTS
        PSCustomObject
        A normalized registry backup object produced by ConvertTo-NormalizedRegistryBackup.
#>
function Import-RegistryBackup {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw (Get-Translation -Key 'BackupFileNotFound' -FormatArgs @($FilePath))
    }

    try {
        $rawBackup = Get-Content -LiteralPath $FilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw (Get-Translation -Key 'BackupFileNotValidJson' -FormatArgs @($FilePath))
    }

    return ConvertTo-NormalizedRegistryBackup -Backup $rawBackup
}

<#
    .SYNOPSIS
        Validates and normalizes a raw registry backup object.

    .DESCRIPTION
        Validates the structure and content of the supplied backup and converts
        it into a normalized representation that can be safely consumed by the
        restore workflow. Throws if validation fails.

    .PARAMETER Backup
        The raw backup object (typically parsed from JSON) to normalize.

    .OUTPUTS
        PSCustomObject
        A normalized backup with Version, BackupType, CreatedAt, CreatedBy,
        ComputerName, Target, SelectedFeatures, SelectedUndoFeatures, and
        RegistryKeys properties.
#>
function ConvertTo-NormalizedRegistryBackup {
    param(
        [Parameter(Mandatory)]
        $Backup
    )

    $errors = New-Object System.Collections.Generic.List[string]

    if (-not $Backup.PSObject.Properties['Version']) {
        $errors.Add((Get-Translation -Key 'BackupMissingProperty' -FormatArgs @('Version')))
    }
    elseif ([string]$Backup.Version -ne '1.0') {
        $errors.Add((Get-Translation -Key 'BackupUnsupportedVersion' -FormatArgs @($Backup.Version)))
    }

    if (-not $Backup.PSObject.Properties['BackupType']) {
        $errors.Add((Get-Translation -Key 'BackupMissingProperty' -FormatArgs @('BackupType')))
    }
    elseif ([string]$Backup.BackupType -ne 'RegistryState') {
        $errors.Add((Get-Translation -Key 'BackupUnsupportedType' -FormatArgs @($Backup.BackupType)))
    }

    $normalizedTarget = ''
    if (-not $Backup.PSObject.Properties['Target'] -or [string]::IsNullOrWhiteSpace([string]$Backup.Target)) {
        $errors.Add((Get-Translation -Key 'BackupMissingProperty' -FormatArgs @('Target')))
    }
    else {
        $normalizedTarget = [string]$Backup.Target

        if ($normalizedTarget -eq 'DefaultUserProfile') {
            # Valid target format.
        }
        elseif ($normalizedTarget -like 'User:*') {
            $targetUserName = $normalizedTarget.Substring(5)
            $targetValidation = Test-TargetUserName -UserName $targetUserName
            if (-not $targetValidation.IsValid) {
                $errors.Add((Get-Translation -Key 'BackupInvalidUser' -FormatArgs @($normalizedTarget)))
            }
        }
        elseif ($normalizedTarget -like 'CurrentUser:*') {
            $targetCurrentUserName = $normalizedTarget.Substring(12)
            if (Test-RunningAsSystem) {
                $errors.Add((Get-Translation -Key 'BackupUserScopedWrongContext' -FormatArgs @($targetCurrentUserName)))
            }
            elseif ([string]::IsNullOrWhiteSpace($targetCurrentUserName) -or
                -not (Test-UserNameMatch -UserNameA $targetCurrentUserName -UserNameB $env:USERNAME)) {
                 $errors.Add((Get-Translation -Key 'BackupUserMismatch' -FormatArgs @($targetCurrentUserName, $env:USERNAME)))
            }
        }
        else {
            $errors.Add((Get-Translation -Key 'BackupUnsupportedTarget' -FormatArgs @($normalizedTarget)))
        }
    }

    $registryKeys = @()
    if (-not $Backup.PSObject.Properties['RegistryKeys']) {
        $errors.Add((Get-Translation -Key 'BackupMissingProperty' -FormatArgs @('RegistryKeys')))
    }
    else {
        $registryKeys = @($Backup.RegistryKeys)
    }

    $normalizedKeys = @()
    foreach ($keySnapshot in $registryKeys) {
        $normalizedKeys += @(Normalize-RegistryKeySnapshot -Snapshot $keySnapshot)
    }

    $selectedFeatureParseResult = Get-NormalizedSelectedFeatureIdsFromBackup -Backup $Backup
    $selectedFeatures = @($selectedFeatureParseResult.SelectedFeatures)
    foreach ($selectedFeatureParseError in @($selectedFeatureParseResult.Errors)) {
        $errors.Add([string]$selectedFeatureParseError)
    }

    $selectedUndoFeatureParseResult = Get-NormalizedSelectedUndoFeatureIdsFromBackup -Backup $Backup
    $selectedUndoFeatures = @($selectedUndoFeatureParseResult.SelectedUndoFeatures)
    foreach ($selectedUndoFeatureParseError in @($selectedUndoFeatureParseResult.Errors)) {
        $errors.Add([string]$selectedUndoFeatureParseError)
    }

    $allSelectedFeatures = @($selectedFeatures) + @($selectedUndoFeatures)
    if ($allSelectedFeatures.Count -eq 0) {
        $errors.Add((Get-Translation -Key 'BackupMissingSelectedFeatures'))
    }
    else {
        try {
            $allowListValidationErrors = @(Test-RegistryBackupMatchesSelectedFeatures -SelectedFeatureIds @($selectedFeatures) -SelectedUndoFeatureIds @($selectedUndoFeatures) -Target $normalizedTarget -RegistryKeys @($normalizedKeys))
            foreach ($allowListValidationError in $allowListValidationErrors) {
                $errors.Add([string]$allowListValidationError)
            }
        }
        catch {
            $errors.Add((Get-Translation -Key 'BackupAllowlistValidationFailed' -FormatArgs @($_.Exception.Message)))
        }
    }

    if ($errors.Count -gt 0) {
        Write-Error "Backup validation failed: $($errors -join ' ')"
        if ($errors.Count -eq 1) {
            throw (Get-Translation -Key 'BackupValidationSingleError' -FormatArgs @($errors[0]))
        }
        else {
            throw (Get-Translation -Key 'BackupValidationMultipleErrors' -FormatArgs @($errors.Count))
        }
    }

    return [PSCustomObject]@{
        Version = [string]$Backup.Version
        BackupType = [string]$Backup.BackupType
        CreatedAt = [string]$Backup.CreatedAt
        CreatedBy = [string]$Backup.CreatedBy
        ComputerName = [string]$Backup.ComputerName
        Target = $normalizedTarget
        SelectedFeatures = @($selectedFeatures)
        SelectedUndoFeatures = @($selectedUndoFeatures)
        RegistryKeys = @($normalizedKeys)
    }
}

<#
    .SYNOPSIS
        Restores registry state from a normalized backup object.

    .DESCRIPTION
        Applies the registry state described by the supplied backup back to the
        registry, loading the appropriate user hive when required.

    .PARAMETER Backup
        A normalized backup object (as produced by ConvertTo-NormalizedRegistryBackup) whose
        RegistryKeys snapshots should be restored.

    .OUTPUTS
        PSCustomObject
        Returns an object with a Result property set to $true when the restore
        completes successfully.
#>
function Restore-RegistryBackupState {
    param(
        [Parameter(Mandatory)]
        $Backup
    )

    $friendlyTarget = Get-FriendlyRegistryBackupTarget -Target ([string]$Backup.Target)

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Restore registry backup for $friendlyTarget" -ForegroundColor Cyan
        return [PSCustomObject]@{ Result = $true }
    }

    $restoreAction = {
        param($normalizedBackup)

        Write-Host "Applying registry restore from $(@($normalizedBackup.RegistryKeys).Count) root snapshot(s)."
        foreach ($rootSnapshot in @($normalizedBackup.RegistryKeys)) {
            Restore-RegistryKeySnapshot -Snapshot $rootSnapshot
        }
    }

    Write-Host "Starting restore for $friendlyTarget."

    if ($Backup.Target -eq 'DefaultUserProfile' -or $Backup.Target -like 'User:*') {
        Write-Host "Restore requires loading target user hive."
        Invoke-WithLoadedRestoreHive -Target $Backup.Target -ScriptBlock $restoreAction -ArgumentObject $Backup
        Write-Host "Restore completed for $friendlyTarget."
        return [PSCustomObject]@{ Result = $true }
    }

    & $restoreAction $Backup
    Write-Host "Restore completed for $friendlyTarget."
    return [PSCustomObject]@{ Result = $true }
}
