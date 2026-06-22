<#
    .SYNOPSIS
        Maps a .reg file value type string to its RegistryValueKind enum.

    .PARAMETER Operation
        A parsed .reg operation object containing a ValueType property.
#>
function Get-ExpectedRegistryValueKind {
    param(
        [Parameter(Mandatory)]
        $Operation
    )

    switch ([string]$Operation.ValueType) {
        'DWord' { return [Microsoft.Win32.RegistryValueKind]::DWord }
        'QWord' { return [Microsoft.Win32.RegistryValueKind]::QWord }
        'String' { return [Microsoft.Win32.RegistryValueKind]::String }
        'Binary' { return [Microsoft.Win32.RegistryValueKind]::Binary }
        'Hex2' { return [Microsoft.Win32.RegistryValueKind]::ExpandString }
        'Hex7' { return [Microsoft.Win32.RegistryValueKind]::MultiString }
        default { return $null }
    }
}

<#
    .SYNOPSIS
        Tests whether a feature's registry operations currently match the live registry.

    .DESCRIPTION
        Returns $true when ALL operations in the apply .reg file match current system
        state. Returns $false if the feature has no RegistryKey, the reg file is
        missing, or any operation mismatches. Special-cased features (Widgets, Store
        suggestions, Windows Sandbox, WSL) bypass .reg checking entirely.

    .PARAMETER FeatureId
        The feature identifier to test.
#>
function Test-FeatureApplied {
    param (
        [Parameter(Mandatory)]
        [string]$FeatureId
    )

    $feature = $script:Features[$FeatureId]

    switch ($FeatureId) {
        'DisableWidgets' {
            # Widgets packages cannot be reinstalled automatically, so we treat their
            # absence as the applied state (checked) and presence as not-yet-applied.
            $widgetAppIds = @(
                'Microsoft.StartExperiencesApp',
                'MicrosoftWindows.Client.WebExperience',
                'Microsoft.WidgetsPlatformRuntime'
            )

            foreach ($appId in $widgetAppIds) {
                if (Get-AppxPackage -Name $appId -AllUsers -ErrorAction SilentlyContinue) {
                    return $false
                }
            }

            return $true
        }
        'DisableStoreSearchSuggestions' {
            if ($script:Params.ContainsKey('Sysprep')) {
                return (Test-StoreSearchSuggestionsDisabledForAllUsers)
            }

            $storeDbPath = GetStoreAppsDatabasePathForUser -UserName (GetUserName)

            return (Test-StoreSearchSuggestionsDisabled -StoreAppsDatabase $storeDbPath)
        }
        'EnableWindowsSandbox' {
            return (Test-WindowsOptionalFeatureEnabled -FeatureName 'Containers-DisposableClientVM')
        }
        'EnableWindowsSubsystemForLinux' {
            $wslEnabled = Test-WindowsOptionalFeatureEnabled -FeatureName 'Microsoft-Windows-Subsystem-Linux'
            $vmpEnabled = Test-WindowsOptionalFeatureEnabled -FeatureName 'VirtualMachinePlatform'
            return ($wslEnabled -and $vmpEnabled)
        }
    }

    if (-not $feature.RegistryKey) { return $false }

    $regFilePath = Join-Path $script:RegfilesPath $feature.RegistryKey
    if (-not (Test-Path $regFilePath)) { return $false }

    try {
        $operations = @(Get-RegFileOperations -regFilePath $regFilePath)
    }
    catch { return $false }

    if ($operations.Count -eq 0) { return $false }

    foreach ($op in $operations) {
        $parts = Split-RegistryPath -path $op.KeyPath
        if (-not $parts) { return $false }

        $rootKey = Get-RegistryRootKey -hiveName $parts.Hive
        if (-not $rootKey) { return $false }

        $key = $null
        try {
            $key = $rootKey.OpenSubKey($parts.SubKey, $false)

            switch ($op.OperationType) {
                'DeleteKey' {
                    if ($null -ne $key) { return $false }
                }
                'DeleteValue' {
                    if ($null -ne $key) {
                        $names = @($key.GetValueNames())
                        if ($names -icontains $op.ValueName) { return $false }
                    }
                    # key missing = value also gone = operation matches
                }
                'SetValue' {
                    if ($null -eq $key) { return $false }
                    $names = @($key.GetValueNames())
                    if (-not ($names -icontains $op.ValueName)) { return $false }

                    $actualKind = $key.GetValueKind($op.ValueName)
                    $expectedKind = Get-ExpectedRegistryValueKind -Operation $op
                    if ($null -eq $expectedKind -or $actualKind -ne $expectedKind) { return $false }
                    $actualRaw  = $key.GetValue($op.ValueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)

                    $actual = switch ($actualKind) {
                        ([Microsoft.Win32.RegistryValueKind]::DWord) {
                            [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$actualRaw), 0)
                        }
                        ([Microsoft.Win32.RegistryValueKind]::QWord) {
                            [BitConverter]::ToUInt64([BitConverter]::GetBytes([int64]$actualRaw), 0)
                        }
                        ([Microsoft.Win32.RegistryValueKind]::Binary) {
                            @($actualRaw | ForEach-Object { [int]$_ })
                        }
                        ([Microsoft.Win32.RegistryValueKind]::MultiString) {
                            @($actualRaw)
                        }
                        default {
                            if ($null -ne $actualRaw) { [string]$actualRaw } else { $null }
                        }
                    }

                    $expected = $op.ValueData

                    $match = if (($actual -is [array]) -and ($expected -is [array])) {
                        (Compare-Object $actual $expected).Count -eq 0
                    } else {
                        $actual -eq $expected
                    }

                    if (-not $match) { return $false }
                }
            }
        }
        catch { return $false }
        finally {
            if ($null -ne $key) { $key.Close() }
        }
    }

    return $true
}

<#
    .SYNOPSIS
        Returns the 1-based index of the UiGroup option whose features all match
        current system state.

    .DESCRIPTION
        Returns 0 if no option fully matches, meaning the current state is unknown
        or represents "No Change".

    .PARAMETER Group
        A UiGroup object whose Values array contains options with FeatureIds.
#>
function Get-CurrentGroupActiveIndex {
    param (
        [Parameter(Mandatory)]
        [object]$Group
    )

    $i = 1
    foreach ($val in $Group.Values) {
        $allApplied = $true
        foreach ($fid in $val.FeatureIds) {
            if (-not (Test-FeatureApplied -FeatureId $fid)) {
                $allApplied = $false
                break
            }
        }
        if ($allApplied) { return $i }
        $i++
    }

    return 0
}
