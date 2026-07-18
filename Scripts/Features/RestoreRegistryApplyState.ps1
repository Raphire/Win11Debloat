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

function Convert-RegistryValueKindFromBackup {
    param(
        [string]$KindName
    )

    if ([string]::IsNullOrWhiteSpace($KindName)) {
        return [Microsoft.Win32.RegistryValueKind]::String
    }

    try {
        return [System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], $KindName, $true)
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
        ([Microsoft.Win32.RegistryValueKind]::DWord) {
            $unsigned = [uint32]$Data
            return [BitConverter]::ToInt32([BitConverter]::GetBytes($unsigned), 0)
        }
        ([Microsoft.Win32.RegistryValueKind]::QWord) {
            $unsigned = [uint64]$Data
            return [BitConverter]::ToInt64([BitConverter]::GetBytes($unsigned), 0)
        }
        ([Microsoft.Win32.RegistryValueKind]::MultiString) { return @($Data | ForEach-Object { [string]$_ }) }
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
        ([Microsoft.Win32.RegistryValueKind]::None) { return $null }
        default {
            if ($null -ne $Data) {
                return [string]$Data
            }

            return ''
        }
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
