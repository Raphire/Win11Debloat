. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

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
            throw (Get-ConsoleTranslation -Text 'Invalid backup target format for user restore.')
        }
        $userName
    }
    else {
        throw (Get-ConsoleTranslation -Text 'Unsupported backup target ''{0}''.' -FormatArgs @($Target))
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
        throw (Get-ConsoleTranslation -Text 'Unsupported registry path in backup: {0}' -FormatArgs @($($Snapshot.Path)))
    }

    $rootKey = Get-RegistryRootKey -hiveName $registryParts.Hive
    if (-not $rootKey) {
        throw (Get-ConsoleTranslation -Text 'Unsupported registry hive in backup: {0}' -FormatArgs @($($registryParts.Hive)))
    }

    $subKeyPath = $registryParts.SubKey
    if ([string]::IsNullOrWhiteSpace($subKeyPath)) {
        throw (Get-ConsoleTranslation -Text 'Unsupported root-level registry path in backup: {0}' -FormatArgs @($($Snapshot.Path)))
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
            throw (Get-ConsoleTranslation -Text 'Backup contains duplicate or unsupported registry child path: {0}' -FormatArgs @($($subKeySnapshot.Path)))
        }
        Test-RegistryKeySnapshotCanBeRestored -Snapshot $subKeySnapshot
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
        throw (Get-ConsoleTranslation -Text 'Unsupported registry child path in backup: {0}' -FormatArgs @($ChildPath))
    }

    $childName = Split-Path -Path $childParts.SubKey -Leaf
    $expectedSubKey = "$($parentParts.SubKey)\$childName"
    if ([string]::IsNullOrWhiteSpace($childName) -or
        -not $childParts.SubKey.Equals($expectedSubKey, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw (Get-ConsoleTranslation -Text 'Registry child path ''{0}'' is not directly below parent ''{1}''.' -FormatArgs @($ChildPath, $ParentPath))
    }

    return $childName
}

<#
    .SYNOPSIS
        Restores a snapshot to a specific path below an already resolved registry root.

    .DESCRIPTION
        Writes only values and descendants represented by the backup. Existing keys are
        retained so their security descriptors and unrelated data are not destroyed.
#>
<#
    .SYNOPSIS
        将注册表键快照递归恢复到指定根键下。
    .DESCRIPTION
        快照标记不存在时删除对应键树；否则创建或打开键，恢复记录的值和子键。
        不清除快照未列出的其他值或子键。无法打开键时抛出异常，已打开的键会关闭。
    .PARAMETER Snapshot
        包含 Path、Exists、Values 和 SubKeys 的键快照。
    .PARAMETER RootKey
        用于创建或删除子键的注册表根键对象。
    .PARAMETER SubKeyPath
        相对于 RootKey 的目标子键路径。
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

    $key = $RootKey.CreateSubKey($SubKeyPath)
    if ($null -eq $key) {
        throw (Get-ConsoleTranslation -Text 'Unable to create or open registry key ''{0}''' -FormatArgs @($($Snapshot.Path)))
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
<#
    .SYNOPSIS
        根据快照恢复或删除单个注册表值。
    .DESCRIPTION
        Exists 为假时删除该值，否则转换类型和数据后写入；名称为空时操作默认值。
        删除或写入失败时抛出包含值名和键路径的异常。本函数不关闭传入的键。
    .PARAMETER RegistryKey
        已打开、可写的注册表键。
    .PARAMETER Snapshot
        包含 Name、Exists、Kind 和 Data 的值快照。
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
            throw (Get-ConsoleTranslation -Text 'Failed deleting registry value ''{0}'' in ''{1}'': {2}' -FormatArgs @($valueName, $($RegistryKey.Name), $($_.Exception.Message)))
        }
        return
    }

    $valueKind = Convert-RegistryValueKindFromBackup -KindName $Snapshot.Kind
    $normalizedData = Convert-RegistryValueDataFromBackup -Kind $valueKind -Data $Snapshot.Data

    try {
        $RegistryKey.SetValue($valueName, $normalizedData, $valueKind)
    }
    catch {
        throw (Get-ConsoleTranslation -Text 'Failed setting registry value ''{0}'' in ''{1}'': {2}' -FormatArgs @($valueName, $($RegistryKey.Name), $($_.Exception.Message)))
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
<#
    .SYNOPSIS
        将备份中的类型名称转换为注册表值类型。
    .PARAMETER KindName
        不区分大小写的枚举名称；空值按 String 处理，无法解析时抛出异常。
    .OUTPUTS
        Microsoft.Win32.RegistryValueKind。
#>
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
        throw (Get-ConsoleTranslation -Text 'Unsupported registry value kind in backup: {0}' -FormatArgs @($KindName))
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
<#
    .SYNOPSIS
        将备份数据转换为注册表写入所需的类型。
    .DESCRIPTION
        DWord 和 QWord 按原始位模式转换为有符号整数，MultiString 和 Binary
        保持数组不被管道展开。空二进制数据返回空字节数组，非法字节数据抛出异常；
        其他类型转换为字符串，空数据转换为空字符串。
    .PARAMETER Kind
        目标注册表值类型。
    .PARAMETER Data
        从备份读取的值数据。
    .OUTPUTS
        System.Int32、System.Int64、System.String[]、System.Byte[] 或 System.String。
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
                throw (Get-ConsoleTranslation -Text 'Invalid binary registry data in backup. Expected byte values from 0 through 255.')
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
