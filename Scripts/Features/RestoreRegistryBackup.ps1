function Load-RegistryBackupFromFile {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "Backup file was not found: $FilePath"
    }

    try {
        $rawBackup = Get-Content -Path $FilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to read backup file '$FilePath'. The file is not valid JSON."
    }

    return Normalize-RegistryBackup -Backup $rawBackup
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

    if (-not $Backup.PSObject.Properties['Target'] -or [string]::IsNullOrWhiteSpace([string]$Backup.Target)) {
        $errors.Add('Missing property: Target')
    }

    $registryKeys = @()
    if (-not $Backup.PSObject.Properties['RegistryKeys']) {
        $errors.Add('Missing property: RegistryKeys')
    }
    else {
        $registryKeys = @($Backup.RegistryKeys)
    }

    if ($errors.Count -gt 0) {
        throw ("Backup validation failed: {0}" -f ($errors -join ' '))
    }

    $normalizedKeys = @()
    foreach ($keySnapshot in $registryKeys) {
        $normalizedKeys += @(Normalize-RegistryKeySnapshot -Snapshot $keySnapshot)
    }

    $selectedFeatures = @()
    if ($Backup.PSObject.Properties['SelectedFeatures']) {
        $selectedFeatures = @($Backup.SelectedFeatures)
    }

    return [PSCustomObject]@{
        Version = [string]$Backup.Version
        BackupType = [string]$Backup.BackupType
        CreatedAt = [string]$Backup.CreatedAt
        CreatedBy = [string]$Backup.CreatedBy
        ComputerName = [string]$Backup.ComputerName
        Target = [string]$Backup.Target
        SelectedFeatures = $selectedFeatures
        RegistryKeys = @($normalizedKeys)
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

function Restore-RegistryBackupState {
    param(
        [Parameter(Mandatory)]
        $Backup
    )

    $restoreAction = {
        param($normalizedBackup)

        foreach ($rootSnapshot in @($normalizedBackup.RegistryKeys)) {
            Restore-RegistryKeySnapshot -Snapshot $rootSnapshot
        }
    }

    if ($Backup.Target -eq 'DefaultUserProfile' -or $Backup.Target -like 'User:*') {
        Invoke-WithLoadedRestoreHive -Target $Backup.Target -ScriptBlock $restoreAction -ArgumentObject $Backup
        return
    }

    & $restoreAction $Backup
}

function Invoke-WithLoadedRestoreHive {
    param(
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        $ArgumentObject = $null
    )

    $hiveDatPath = if ($Target -eq 'DefaultUserProfile') {
        GetUserDirectory -userName 'Default' -fileName 'NTUSER.DAT'
    }
    elseif ($Target -like 'User:*') {
        $userName = $Target.Substring(5)
        if ([string]::IsNullOrWhiteSpace($userName)) {
            throw 'Invalid backup target format for user restore.'
        }
        GetUserDirectory -userName $userName -fileName 'NTUSER.DAT'
    }
    else {
        throw "Unsupported backup target '$Target'."
    }

    $global:LASTEXITCODE = 0
    reg load 'HKU\Default' $hiveDatPath | Out-Null
    $loadExitCode = $LASTEXITCODE
    if ($loadExitCode -ne 0) {
        throw "Failed to load target user hive '$hiveDatPath' (exit code: $loadExitCode)."
    }

    try {
        & $ScriptBlock $ArgumentObject
    }
    finally {
        $global:LASTEXITCODE = 0
        reg unload 'HKU\Default' | Out-Null
    }
}

function Restore-RegistryKeySnapshot {
    param(
        [Parameter(Mandatory)]
        $Snapshot
    )

    $registryParts = Split-RegistryPath -path $Snapshot.Path
    if (-not $registryParts) {
        throw "Unsupported registry path in backup: $($Snapshot.Path)"
    }

    $rootKey = Get-RegistryRootKey -hiveName $registryParts.Hive
    if (-not $rootKey) {
        throw "Unsupported registry hive in backup: $($registryParts.Hive)"
    }

    $subKeyPath = $registryParts.SubKey
    if ([string]::IsNullOrWhiteSpace($subKeyPath)) {
        throw "Unsupported root-level registry path in backup: $($Snapshot.Path)"
    }

    if (-not $Snapshot.Exists) {
        Remove-RegistrySubKeyTreeIfExists -RootKey $rootKey -SubKeyPath $subKeyPath
        return
    }

    $forceFullTree = @($Snapshot.SubKeys).Count -gt 0
    if ($forceFullTree) {
        Remove-RegistrySubKeyTreeIfExists -RootKey $rootKey -SubKeyPath $subKeyPath
    }

    $key = $rootKey.CreateSubKey($subKeyPath)
    if ($null -eq $key) {
        throw "Unable to create or open registry key '$($Snapshot.Path)'"
    }

    try {
        foreach ($valueSnapshot in @($Snapshot.Values)) {
            Restore-RegistryValueSnapshot -RegistryKey $key -Snapshot $valueSnapshot
        }
    }
    finally {
        $key.Close()
    }

    foreach ($subKeySnapshot in @($Snapshot.SubKeys)) {
        Restore-RegistryKeySnapshot -Snapshot $subKeySnapshot
    }
}

function Restore-RegistryValueSnapshot {
    param(
        [Parameter(Mandatory)]
        [Microsoft.Win32.RegistryKey]$RegistryKey,
        [Parameter(Mandatory)]
        $Snapshot
    )

    $valueName = if ($null -ne $Snapshot.Name) { [string]$Snapshot.Name } else { '' }

    if (-not [bool]$Snapshot.Exists) {
        try {
            $RegistryKey.DeleteValue($valueName, $false)
        }
        catch {
            throw "Failed deleting registry value '$valueName' in '$($RegistryKey.Name)': $($_.Exception.Message)"
        }
        return
    }

    $valueKind = Convert-RegistryValueKindFromBackup -KindName $Snapshot.Kind
    $normalizedData = Convert-RegistryValueDataFromBackup -Kind $valueKind -Data $Snapshot.Data

    try {
        $RegistryKey.SetValue($valueName, $normalizedData, $valueKind)
    }
    catch {
        $retryBytes = Convert-BackupDataToByteArray -Data $Snapshot.Data
        if ($null -ne $retryBytes) {
            try {
                $RegistryKey.SetValue($valueName, $retryBytes, [Microsoft.Win32.RegistryValueKind]::Binary)
                return
            }
            catch {
                # Fall through to original error message for context.
            }
        }

        throw "Failed setting registry value '$valueName' in '$($RegistryKey.Name)': $($_.Exception.Message)"
    }
}

function Convert-RegistryValueKindFromBackup {
    param(
        [string]$KindName
    )

    if ([string]::IsNullOrWhiteSpace($KindName)) {
        return [Microsoft.Win32.RegistryValueKind]::String
    }

    try {
        return [Microsoft.Win32.RegistryValueKind]::Parse([Microsoft.Win32.RegistryValueKind], $KindName, $true)
    }
    catch {
        throw "Unsupported registry value kind in backup: $KindName"
    }
}

function Convert-RegistryValueDataFromBackup {
    param(
        [Microsoft.Win32.RegistryValueKind]$Kind,
        $Data
    )

    switch ($Kind) {
        ([Microsoft.Win32.RegistryValueKind]::DWord) { return [uint32]$Data }
        ([Microsoft.Win32.RegistryValueKind]::QWord) { return [uint64]$Data }
        ([Microsoft.Win32.RegistryValueKind]::MultiString) { return @($Data | ForEach-Object { [string]$_ }) }
        ([Microsoft.Win32.RegistryValueKind]::Binary) {
            $bytes = Convert-BackupDataToByteArray -Data $Data
            if ($null -eq $bytes) {
                return (New-Object byte[] 0)
            }
            return $bytes
        }
        ([Microsoft.Win32.RegistryValueKind]::None) { return $null }
        default { return (if ($null -ne $Data) { [string]$Data } else { '' }) }
    }
}

function Convert-BackupDataToByteArray {
    param(
        $Data
    )

    if ($null -eq $Data) {
        return $null
    }

    if ($Data -is [byte[]]) {
        return $Data
    }

    $items = @($Data)
    if ($items.Count -eq 0) {
        return (New-Object byte[] 0)
    }

    foreach ($item in $items) {
        if ($item -isnot [ValueType] -and $item -isnot [string]) {
            return $null
        }

        $parsed = 0
        if (-not [int]::TryParse([string]$item, [ref]$parsed)) {
            return $null
        }

        if ($parsed -lt 0 -or $parsed -gt 255) {
            return $null
        }
    }

    $bytes = New-Object byte[] $items.Count
    for ($i = 0; $i -lt $items.Count; $i++) {
        $bytes[$i] = [byte][int]$items[$i]
    }

    return $bytes
}

function Remove-RegistrySubKeyTreeIfExists {
    param(
        [Parameter(Mandatory)]
        [Microsoft.Win32.RegistryKey]$RootKey,
        [Parameter(Mandatory)]
        [string]$SubKeyPath
    )

    $existing = $RootKey.OpenSubKey($SubKeyPath, $false)
    if ($existing) {
        $existing.Close()
        $RootKey.DeleteSubKeyTree($SubKeyPath, $false)
    }
}
