function Load-RegistryBackupFromFile {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "Backup file was not found: $FilePath"
    }

    try {
        $rawBackup = Get-Content -LiteralPath $FilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to read backup file '$FilePath'. The file is not valid JSON."
    }

    $normalizedBackup = Normalize-RegistryBackup -Backup $rawBackup
    Write-Host "Backup loaded and validated. Target='$($normalizedBackup.Target)', SelectedFeatures=$(@($normalizedBackup.SelectedFeatures).Count), RootKeys=$(@($normalizedBackup.RegistryKeys).Count)"

    return $normalizedBackup
}

function Normalize-RegistryBackup {
    param(
        [Parameter(Mandatory)]
        $Backup
    )

    $errors = New-Object System.Collections.Generic.List[string]

    if (-not $Backup.PSObject.Properties['Version']) {
        $errors.Add('Missing property: Version')
    }
    elseif ([string]$Backup.Version -ne '1.0') {
        $errors.Add("Unsupported backup version '$($Backup.Version)'.")
    }

    if (-not $Backup.PSObject.Properties['BackupType']) {
        $errors.Add('Missing property: BackupType')
    }
    elseif ([string]$Backup.BackupType -ne 'RegistryState') {
        $errors.Add("Unsupported BackupType '$($Backup.BackupType)'.")
    }

    $normalizedTarget = ''
    if (-not $Backup.PSObject.Properties['Target'] -or [string]::IsNullOrWhiteSpace([string]$Backup.Target)) {
        $errors.Add('Missing property: Target')
    }
    else {
        $normalizedTarget = [string]$Backup.Target

        if ($normalizedTarget -eq 'DefaultUserProfile') {
            # Valid target format.
        }
        elseif ($normalizedTarget -like 'User:*') {
            $targetUserName = $normalizedTarget.Substring(5)
            if ([string]::IsNullOrWhiteSpace($targetUserName)) {
                $errors.Add("Invalid Target '$normalizedTarget'. Expected User:<name>.")
            }
            elseif (-not (CheckIfUserExists -userName $targetUserName)) {
                $errors.Add("Target user '$targetUserName' does not exist on this system.")
            }
        }
        elseif ($normalizedTarget -like 'CurrentUser:*') {
            $targetCurrentUserName = $normalizedTarget.Substring(12)
            if ([string]::IsNullOrWhiteSpace($targetCurrentUserName) -or ($targetCurrentUserName -ne $env:USERNAME)) {
                 $errors.Add("Backup was made for '$targetCurrentUserName', this does not match current user '$env:USERNAME'.")
            }
        }
        else {
            $errors.Add("Unsupported Target '$normalizedTarget'.")
        }
    }

    $registryKeys = @()
    if (-not $Backup.PSObject.Properties['RegistryKeys']) {
        $errors.Add('Missing property: RegistryKeys')
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

    $allowListValidationErrors = @(Test-RegistryBackupMatchesSelectedFeatures -SelectedFeatureIds @($selectedFeatures) -RegistryKeys @($normalizedKeys))
    foreach ($allowListValidationError in $allowListValidationErrors) {
        $errors.Add([string]$allowListValidationError)
    }

    if ($errors.Count -gt 0) {
        Write-Error "Backup validation failed: $($errors -join ' ')"
        throw ("validation failed with $($errors.Count) error(s).")
    }

    return [PSCustomObject]@{
        Version = [string]$Backup.Version
        BackupType = [string]$Backup.BackupType
        CreatedAt = [string]$Backup.CreatedAt
        CreatedBy = [string]$Backup.CreatedBy
        ComputerName = [string]$Backup.ComputerName
        Target = $normalizedTarget
        SelectedFeatures = @($selectedFeatures)
        RegistryKeys = @($normalizedKeys)
    }
}

function Restore-RegistryBackupState {
    param(
        [Parameter(Mandatory)]
        $Backup
    )

    $restoreAction = {
        param($normalizedBackup)

        Write-Host "Applying registry restore from $(@($normalizedBackup.RegistryKeys).Count) root snapshot(s)."
        foreach ($rootSnapshot in @($normalizedBackup.RegistryKeys)) {
            Restore-RegistryKeySnapshot -Snapshot $rootSnapshot
        }
    }

    Write-Host "Starting restore for user '$($Backup.Target)'."

    if ($Backup.Target -eq 'DefaultUserProfile' -or $Backup.Target -like 'User:*') {
        Write-Host "Restore requires loading target user hive."
        Invoke-WithLoadedRestoreHive -Target $Backup.Target -ScriptBlock $restoreAction -ArgumentObject $Backup
        Write-Host "Restore completed for user '$($Backup.Target)'."
        return
    }

    & $restoreAction $Backup
    Write-Host "Restore completed for user '$($Backup.Target)'."
}
