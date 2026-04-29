function Get-RegistryBackupCapturePlans {
    param(
        [Parameter(Mandatory)]
        [object[]]$SelectedRegistryFeatures
    )

    $planMap = @{}
    foreach ($feature in $SelectedRegistryFeatures) {
        $regFilePath = Get-RegistryFilePathForFeature -Feature $feature
        if (-not (Test-Path $regFilePath)) {
            throw "Unable to find registry file for backup: $($feature.RegistryKey) ($regFilePath)"
        }

        foreach ($operation in @(Get-RegFileOperations -regFilePath $regFilePath)) {
            if (-not $operation.KeyPath) { continue }

            $mapKey = $operation.KeyPath.ToLowerInvariant()
            if (-not $planMap.ContainsKey($mapKey)) {
                $planMap[$mapKey] = [PSCustomObject]@{
                    Path = $operation.KeyPath
                    IncludeSubKeys = $false
                    CaptureAllValues = $false
                    ValueNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
                }
            }

            $plan = $planMap[$mapKey]
            switch ($operation.OperationType) {
                'DeleteKey' {
                    $plan.IncludeSubKeys = $true
                    $plan.CaptureAllValues = $true
                }
                'SetValue' {
                    if (-not $plan.CaptureAllValues) {
                        $null = $plan.ValueNames.Add([string]$operation.ValueName)
                    }
                }
                'DeleteValue' {
                    if (-not $plan.CaptureAllValues) {
                        $null = $plan.ValueNames.Add([string]$operation.ValueName)
                    }
                }
            }
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

function Get-RegistrySnapshotsForBackup {
    param(
        [Parameter(Mandatory)]
        [object[]]$CapturePlans
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

    $hiveDatPath = if ($script:Params.ContainsKey('Sysprep')) {
        GetUserDirectory -userName 'Default' -fileName 'NTUSER.DAT'
    }
    else {
        GetUserDirectory -userName $script:Params.Item('User') -fileName 'NTUSER.DAT'
    }

    $global:LASTEXITCODE = 0
    reg load 'HKU\Default' "$hiveDatPath" | Out-Null
    $loadExitCode = $LASTEXITCODE
    if ($loadExitCode -ne 0) {
        throw "Failed to load user hive for registry backup at '$hiveDatPath' (exit code: $loadExitCode)"
    }

    try {
        return & $ScriptBlock $ArgumentObject
    }
    finally {
        $global:LASTEXITCODE = 0
        reg unload 'HKU\Default' | Out-Null
        $unloadExitCode = $LASTEXITCODE
        if ($unloadExitCode -ne 0) {
            throw "Failed to unload registry hive 'HKU\Default' (exit code: $unloadExitCode)"
        }
    }
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
    $normalizedValue = switch ($valueKind) {
        ([Microsoft.Win32.RegistryValueKind]::Binary) { @($value | ForEach-Object { [int]$_ }) }
        ([Microsoft.Win32.RegistryValueKind]::MultiString) { @($value) }
        ([Microsoft.Win32.RegistryValueKind]::DWord) { [uint32]$value }
        ([Microsoft.Win32.RegistryValueKind]::QWord) { [uint64]$value }
        default { if ($null -ne $value) { [string]$value } else { $null } }
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
