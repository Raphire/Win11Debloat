<#
    .SYNOPSIS
        Runs a script block against the registry hive for a backup target.

    .PARAMETER Target
        A supported backup target: DefaultUserProfile or User:<user name>.

    .PARAMETER ScriptBlock
        The operation to run after the target user hive is available.

    .PARAMETER ArgumentObject
        Optional object passed to the script block.
#>
function Invoke-WithLoadedRestoreHive {
    param(
        [Parameter(Mandatory)]
        [string]$Target,
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        $ArgumentObject = $null
    )

    $targetUserName = if ($Target -eq 'DefaultUserProfile') {
        'Default'
    }
    elseif ($Target -like 'User:*') {
        $userName = $Target.Substring(5)
        if ([string]::IsNullOrWhiteSpace($userName)) {
            throw 'Invalid backup target format for user restore.'
        }
        $userName
    }
    else {
        throw "Unsupported backup target '$Target'."
    }

    Invoke-WithTargetUserHive -TargetUserName $targetUserName -ScriptBlock $ScriptBlock -ArgumentObject $ArgumentObject
}

<#
    .SYNOPSIS
        Restores a registry key and its child keys from a backup snapshot.

    .PARAMETER Snapshot
        The saved registry-key state, including existence, values, and subkeys.
#>
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

    Test-RegistryKeySnapshotCanBeRestored -Snapshot $Snapshot
    Restore-RegistryKeySnapshotAtPath -Snapshot $Snapshot -RootKey $rootKey -SubKeyPath $subKeyPath
}

<#
    .SYNOPSIS
        Validates registry values and subkey paths in a snapshot before live registry state is changed.

    .PARAMETER Snapshot
        The registry key snapshot to validate before it is restored.
#>
function Test-RegistryKeySnapshotCanBeRestored {
    param(
        [Parameter(Mandatory)]
        $Snapshot
    )

    if (-not [bool]$Snapshot.Exists) { return }

    $childNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($valueSnapshot in @($Snapshot.Values)) {
        if ([bool]$valueSnapshot.Exists) {
            $valueKind = Convert-RegistryValueKindFromBackup -KindName $valueSnapshot.Kind
            $null = Convert-RegistryValueDataFromBackup -Kind $valueKind -Data $valueSnapshot.Data
        }
    }

    foreach ($subKeySnapshot in @($Snapshot.SubKeys)) {
        $childName = Get-DirectRegistrySnapshotChildName -ParentPath $Snapshot.Path -ChildPath $subKeySnapshot.Path
        if ([string]::IsNullOrWhiteSpace($childName) -or -not $childNames.Add($childName)) {
            throw "Backup contains duplicate or unsupported registry child path: $($subKeySnapshot.Path)"
        }
        Test-RegistryKeySnapshotCanBeRestored -Snapshot $subKeySnapshot
    }
}

<#
    .SYNOPSIS
        Preflights every root snapshot before any registry changes or hive loading.
#>
function Test-RegistryBackupSnapshotsCanBeRestored {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$RegistryKeys)

    $rootPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($snapshot in $RegistryKeys) {
        $parts = Split-RegistryPath -path $snapshot.Path
        if (-not $parts -or [string]::IsNullOrWhiteSpace($parts.SubKey) -or
            $parts.Hive -notin @('HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE', 'HKEY_CLASSES_ROOT', 'HKEY_USERS', 'HKEY_CURRENT_CONFIG')) {
            throw "Unsupported registry path in backup: $($snapshot.Path)"
        }
        if (-not $rootPaths.Add("$($parts.Hive)\$($parts.SubKey)")) {
            throw "Backup contains duplicate registry root path: $($snapshot.Path)"
        }
        Test-RegistryKeySnapshotCanBeRestored -Snapshot $snapshot
    }
}

<#
    .SYNOPSIS
        Returns a snapshot child's name only when it is directly below its parent.

    .PARAMETER ParentPath
        The registry path of the expected parent snapshot.

    .PARAMETER ChildPath
        The registry path of the child snapshot to validate.
#>
function Get-DirectRegistrySnapshotChildName {
    param(
        [Parameter(Mandatory)]
        [string]$ParentPath,
        [Parameter(Mandatory)]
        [string]$ChildPath
    )

    $parentParts = Split-RegistryPath -path $ParentPath
    $childParts = Split-RegistryPath -path $ChildPath
    if (-not $parentParts -or -not $childParts -or
        -not $parentParts.Hive.Equals($childParts.Hive, [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]::IsNullOrWhiteSpace($parentParts.SubKey) -or
        [string]::IsNullOrWhiteSpace($childParts.SubKey)) {
        throw "Unsupported registry child path in backup: $ChildPath"
    }

    $childName = Split-Path -Path $childParts.SubKey -Leaf
    $expectedSubKey = "$($parentParts.SubKey)\$childName"
    if ([string]::IsNullOrWhiteSpace($childName) -or
        -not $childParts.SubKey.Equals($expectedSubKey, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Registry child path '$ChildPath' is not directly below parent '$ParentPath'."
    }

    return $childName
}

<#
    .SYNOPSIS
        Restores a snapshot to a specific path below an already resolved registry root.

    .DESCRIPTION
        Writes only values and descendants represented by the backup. Existing keys are
        retained so their security descriptors and unrelated data are not destroyed.
        A key recorded as originally absent is removed only if trusted validation
        authorized cleanup and no values or subkeys remain.
#>
function Restore-RegistryKeySnapshotAtPath {
    param(
        [Parameter(Mandatory)]
        $Snapshot,
        [Parameter(Mandatory)]
        $RootKey,
        [Parameter(Mandatory)]
        [string]$SubKeyPath
    )

    if (-not $Snapshot.Exists) {
        Remove-RegistrySubKeyTreeIfExists -RootKey $RootKey -SubKeyPath $SubKeyPath
        return
    }

    $onlyDeletesValues = @($Snapshot.SubKeys).Count -eq 0 -and
        @($Snapshot.Values | Where-Object { [bool]$_.Exists }).Count -eq 0
    if ($onlyDeletesValues -and (@($Snapshot.Values).Count -gt 0 -or $Snapshot.RemoveEmptyKey)) {
        # An absent value-only key already has the requested state.
        $key = $RootKey.OpenSubKey($SubKeyPath, $true)
        if ($null -eq $key) { return }
    }
    else {
        $key = $RootKey.CreateSubKey($SubKeyPath)
    }
    if ($null -eq $key) {
        throw "Unable to create or open registry key '$($Snapshot.Path)'"
    }

    $removeEmptyKey = $false
    try {
        foreach ($valueSnapshot in @($Snapshot.Values)) {
            Restore-RegistryValueSnapshot -RegistryKey $key -Snapshot $valueSnapshot
        }
        if ($Snapshot.RemoveEmptyKey -and $onlyDeletesValues) {
            $removeEmptyKey = @($key.GetValueNames()).Count -eq 0 -and @($key.GetSubKeyNames()).Count -eq 0
        }
    }
    finally {
        $key.Close()
    }

    if ($removeEmptyKey) {
        Remove-RegistryEmptyKeyIfExists -RootKey $RootKey -SubKeyPath $SubKeyPath
    }

    foreach ($subKeySnapshot in @($Snapshot.SubKeys)) {
        $childName = Get-DirectRegistrySnapshotChildName -ParentPath $Snapshot.Path -ChildPath $subKeySnapshot.Path

        Restore-RegistryKeySnapshotAtPath -Snapshot $subKeySnapshot -RootKey $RootKey -SubKeyPath "$SubKeyPath\$childName"
    }

}

<#
    .SYNOPSIS
        Restores or removes a registry value from a backup snapshot.

    .PARAMETER RegistryKey
        The open registry key that contains the value.

    .PARAMETER Snapshot
        The saved registry-value state to apply.
#>
function Restore-RegistryValueSnapshot {
    param(
        [Parameter(Mandatory)]
        $RegistryKey,
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
        throw "Failed setting registry value '$valueName' in '$($RegistryKey.Name)': $($_.Exception.Message)"
    }
}

<#
    .SYNOPSIS
        Converts a backed-up registry value-kind name to its .NET enum value.

    .PARAMETER KindName
        The registry value-kind name stored in the backup.

    .OUTPUTS
        Microsoft.Win32.RegistryValueKind
#>
function Convert-RegistryValueKindFromBackup {
    param(
        [string]$KindName
    )

    if ([string]::IsNullOrWhiteSpace($KindName)) {
        return [Microsoft.Win32.RegistryValueKind]::String
    }

    try {
        $kind = [System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], $KindName, $true)
        if (-not [System.Enum]::IsDefined([Microsoft.Win32.RegistryValueKind], $kind) -or
            $kind -in @([Microsoft.Win32.RegistryValueKind]::Unknown, [Microsoft.Win32.RegistryValueKind]::None)) {
            throw "Unsupported registry value kind in backup: $KindName"
        }
        return $kind
    }
    catch {
        throw "Unsupported registry value kind in backup: $KindName"
    }
}

<#
    .SYNOPSIS
        Converts backed-up data to a value suitable for registry restoration.

    .PARAMETER Kind
        The registry value kind that determines how the data is converted.

    .PARAMETER Data
        The serialized value data from the backup.
#>
function Convert-RegistryValueDataFromBackup {
    param(
        [Microsoft.Win32.RegistryValueKind]$Kind,
        $Data
    )

    switch ($Kind) {
        ([Microsoft.Win32.RegistryValueKind]::DWord) {
            $unsigned = [uint32]$Data
            return [BitConverter]::ToInt32([BitConverter]::GetBytes($unsigned), 0)
        }
        ([Microsoft.Win32.RegistryValueKind]::QWord) {
            $unsigned = [uint64]$Data
            return [BitConverter]::ToInt64([BitConverter]::GetBytes($unsigned), 0)
        }
        ([Microsoft.Win32.RegistryValueKind]::MultiString) { return ,([string[]]@($Data | ForEach-Object { [string]$_ })) }
        ([Microsoft.Win32.RegistryValueKind]::Binary) {
            if ($null -eq $Data) {
                return ,(New-Object byte[] 0)
            }

            $bytes = Convert-BackupDataToByteArray -Data $Data
            if ($null -eq $bytes) {
                throw 'Invalid binary registry data in backup. Expected byte values from 0 through 255.'
            }
            # Keep the byte array intact instead of writing each byte to the
            # pipeline. RegistryKey.SetValue requires a byte[] for Binary.
            return ,$bytes
        }
        default {
            if ($null -ne $Data) {
                return [string]$Data
            }

            return ''
        }
    }
}

<#
    .SYNOPSIS
        Converts serialized binary backup data to a byte array.

    .PARAMETER Data
        A byte array or collection of integer byte values from the backup.

    .OUTPUTS
        System.Byte[]
        Returns $null when the input contains invalid byte data.
#>
function Convert-BackupDataToByteArray {
    param(
        $Data
    )

    if ($null -eq $Data) {
        return $null
    }

    if ($Data -is [byte[]]) {
        return ,$Data
    }

    $items = @($Data)
    if ($items.Count -eq 0) {
        return ,(New-Object byte[] 0)
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

    return ,$bytes
}
