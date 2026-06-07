function Get-RegistryBackupCapturePlans {
    param(
        [object[]]$SelectedRegistryFeatures = @(),
        [object[]]$UndoRegistryFeatures = @(),
        [switch]$UseSysprepRegFiles
    )

    $planMap = @{}

    foreach ($feature in $SelectedRegistryFeatures) {
        $regFilePath = Get-RegistryFilePathForFeature -RegistryKey $feature.RegistryKey -UseSysprepRegFiles:$UseSysprepRegFiles
        if (-not (Test-Path $regFilePath)) {
            throw "Unable to find registry file for backup: $($feature.RegistryKey) ($regFilePath)"
        }

        foreach ($operation in @(Get-RegFileOperations -regFilePath $regFilePath)) {
            if (-not $operation.KeyPath) { continue }
            Add-RegistryPlanOperation -PlanMap $planMap -Operation $operation
        }
    }

    foreach ($feature in $UndoRegistryFeatures) {
        $regFilePath = Resolve-RegistryBackupUndoFilePath -Feature $feature
        if ([string]::IsNullOrWhiteSpace($regFilePath)) {
            continue
        }

        if (-not (Test-Path $regFilePath)) {
            $undoKeyDescription = if (-not [string]::IsNullOrWhiteSpace([string]$feature.RegistryUndoKey)) {
                [string]$feature.RegistryUndoKey
            }
            else {
                [string]$feature.RegistryKey
            }

            throw "Unable to find registry undo file for backup: $undoKeyDescription ($regFilePath)"
        }

        foreach ($operation in @(Get-RegFileOperations -regFilePath $regFilePath)) {
            if (-not $operation.KeyPath) { continue }
            Add-RegistryPlanOperation -PlanMap $planMap -Operation $operation
        }
    }

    return @(
        foreach ($entry in $planMap.Values) {
            [PSCustomObject]@{
                Path = $entry.Path
                IncludeSubKeys = [bool]$entry.IncludeSubKeys
                CaptureAllValues = [bool]$entry.CaptureAllValues
                ValueNames = @($entry.ValueNames)
            }
        }
    )
}

function Add-RegistryPlanOperation {
    param(
        [hashtable]$PlanMap,
        [PSCustomObject]$Operation
    )

    $mapKey = $Operation.KeyPath.ToLowerInvariant()
    if (-not $PlanMap.ContainsKey($mapKey)) {
        $PlanMap[$mapKey] = [PSCustomObject]@{
            Path = $Operation.KeyPath
            IncludeSubKeys = $false
            CaptureAllValues = $false
            ValueNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        }
    }

    $plan = $PlanMap[$mapKey]
    switch ($Operation.OperationType) {
        'DeleteKey' {
            $plan.IncludeSubKeys = $true
            $plan.CaptureAllValues = $true
        }
        'SetValue' {
            if (-not $plan.CaptureAllValues) {
                $null = $plan.ValueNames.Add([string]$Operation.ValueName)
            }
        }
        'DeleteValue' {
            if (-not $plan.CaptureAllValues) {
                $null = $plan.ValueNames.Add([string]$Operation.ValueName)
            }
        }
    }
}

function Resolve-RegistryBackupUndoFilePath {
    param(
        [Parameter(Mandatory)]
        $Feature
    )

    $undoRegistryKey = [string]$Feature.RegistryUndoKey
    if (-not [string]::IsNullOrWhiteSpace($undoRegistryKey)) {
        $resolvedUndoPath = Resolve-UndoRegFilePath -FileName $undoRegistryKey
        return Join-Path $script:RegfilesPath $resolvedUndoPath
    }

    $resolvedRegistryKey = [string]$Feature.RegistryKey
    if ([string]::IsNullOrWhiteSpace($resolvedRegistryKey)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($resolvedRegistryKey)) {
        return $resolvedRegistryKey
    }

    return Join-Path $script:RegfilesPath $resolvedRegistryKey
}

function Get-RegistrySnapshotsForBackup {
    param(
        [object[]]$CapturePlans = @()
    )

    if ($CapturePlans.Count -eq 0) {
        return @()
    }

    $snapshotScript = {
        param($plans)

        $snapshots = @()
        foreach ($plan in $plans) {
            $snapshots += Get-RegistryKeySnapshot -KeyPath $plan.Path -CaptureAllValues:$plan.CaptureAllValues -ValueNames @($plan.ValueNames) -IncludeSubKeys:$plan.IncludeSubKeys
        }

        return @($snapshots)
    }

    if ($script:Params.ContainsKey('Sysprep') -or $script:Params.ContainsKey('User')) {
        return Invoke-WithLoadedBackupHive -ScriptBlock $snapshotScript -ArgumentObject @($CapturePlans)
    }

    return & $snapshotScript $CapturePlans
}

function Invoke-WithLoadedBackupHive {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        $ArgumentObject = $null
    )

    $targetUserName = if ($script:Params.ContainsKey('Sysprep')) {
        'Default'
    }
    else {
        $script:Params.Item('User')
    }

    return Invoke-WithTargetUserHive -TargetUserName $targetUserName -ScriptBlock $ScriptBlock -ArgumentObject $ArgumentObject
}

function Get-RegistryKeySnapshot {
    param(
        [Parameter(Mandatory)]
        [string]$KeyPath,
        [bool]$CaptureAllValues = $false,
        [string[]]$ValueNames = @(),
        [bool]$IncludeSubKeys = $false
    )

    $registryParts = Split-RegistryPath -path $KeyPath
    if (-not $registryParts) {
        throw "Unsupported registry path in backup: $KeyPath"
    }

    $rootKey = Get-RegistryRootKey -hiveName $registryParts.Hive
    if (-not $rootKey) {
        throw "Unsupported registry hive in backup: $($registryParts.Hive)"
    }

    $subKeyPath = $registryParts.SubKey
    $key = $rootKey.OpenSubKey($subKeyPath, $false)
    if ($null -eq $key) {
        return @{
            Path = $KeyPath
            Exists = $false
            Values = @()
            SubKeys = @()
        }
    }

    try {
        return (Convert-RegistryKeyToSnapshot -RegistryKey $key -FullPath $KeyPath -CaptureAllValues:$CaptureAllValues -ValueNames $ValueNames -IncludeSubKeys:$IncludeSubKeys)
    }
    finally {
        $key.Close()
    }
}

function Convert-RegistryKeyToSnapshot {
    param(
        [Parameter(Mandatory)]
        [Microsoft.Win32.RegistryKey]$RegistryKey,
        [Parameter(Mandatory)]
        [string]$FullPath,
        [bool]$CaptureAllValues = $false,
        [string[]]$ValueNames = @(),
        [bool]$IncludeSubKeys = $false
    )

    $values = @()
    if ($CaptureAllValues) {
        foreach ($valueName in @($RegistryKey.GetValueNames())) {
            $values += @(Convert-RegistryValueToSnapshot -RegistryKey $RegistryKey -ValueName $valueName)
        }
    }
    else {
        foreach ($valueName in @($ValueNames | Sort-Object -Unique)) {
            $exists = ($RegistryKey.GetValueNames() -contains $valueName)
            if ($exists) {
                $values += @(Convert-RegistryValueToSnapshot -RegistryKey $RegistryKey -ValueName $valueName)
            }
            else {
                $values += @{
                    Name = $valueName
                    Exists = $false
                    Kind = $null
                    Data = $null
                }
            }
        }
    }

    $subKeys = @()
    if ($IncludeSubKeys) {
        foreach ($subKeyName in @($RegistryKey.GetSubKeyNames())) {
            $childKey = $RegistryKey.OpenSubKey($subKeyName, $false)
            if ($null -eq $childKey) { continue }

            try {
                $childPath = if ([string]::IsNullOrWhiteSpace($FullPath)) { $subKeyName } else { "$FullPath\$subKeyName" }
                $subKeys += @(Convert-RegistryKeyToSnapshot -RegistryKey $childKey -FullPath $childPath -CaptureAllValues:$true -IncludeSubKeys:$true)
            }
            finally {
                $childKey.Close()
            }
        }
    }

    return @{
        Path = $FullPath
        Exists = $true
        Values = $values
        SubKeys = $subKeys
    }
}

function Convert-RegistryValueToSnapshot {
    param(
        [Parameter(Mandatory)]
        [Microsoft.Win32.RegistryKey]$RegistryKey,
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$ValueName
    )

    $valueKind = $RegistryKey.GetValueKind($ValueName)
    $value = $RegistryKey.GetValue($ValueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    try {
        $normalizedValue = switch ($valueKind) {
            ([Microsoft.Win32.RegistryValueKind]::Binary) { @($value | ForEach-Object { [int]$_ }) }
            ([Microsoft.Win32.RegistryValueKind]::MultiString) { @($value) }
            ([Microsoft.Win32.RegistryValueKind]::DWord) { [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$value), 0) }
            ([Microsoft.Win32.RegistryValueKind]::QWord) { [BitConverter]::ToUInt64([BitConverter]::GetBytes([int64]$value), 0) }
            default { if ($null -ne $value) { [string]$value } else { $null } }
        }
    }
    catch {
        $valueType = if ($null -ne $value) { $value.GetType().FullName } else { '<null>' }
        $valueForLog = if ($null -eq $value) { '<null>' } elseif ($value -is [array]) { ($value -join ',') } else { [string]$value }
        throw "Failed to normalize registry value for backup. Key='$($RegistryKey.Name)' Name='$ValueName' Kind='$valueKind' RawType='$valueType' RawValue='$valueForLog'. InnerError: $($_.Exception.Message)"
    }

    return @{
        Name = $ValueName
        Exists = $true
        Kind = $valueKind.ToString()
        Data = $normalizedValue
    }
}

function Get-RegistryBackupTargetDescription {
    if ($script:Params.ContainsKey('Sysprep')) {
        return 'DefaultUserProfile'
    }

    $resolvedUserName = [string](GetUserName)

    if ($script:Params.ContainsKey('User')) {
        return "User:$resolvedUserName"
    }

    return "CurrentUser:$resolvedUserName"
}
