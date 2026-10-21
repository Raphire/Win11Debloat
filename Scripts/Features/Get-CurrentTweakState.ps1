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
        Returns the set of installed Appx package names, cached for the current refresh.

    .DESCRIPTION
        `Get-AppxPackage -Name <id> -AllUsers` costs roughly 60 ms per call, and the
        Widgets check needs three of them. A single `-AllUsers` enumeration costs about
        the same as one name query and answers all three, so the names are collected once
        and reused. The cache is cleared by Reset-FeatureStateCache so a later refresh
        still sees packages installed or removed in the meantime.

        Returns $null when the enumeration fails, which lets the caller fall back to the
        per-name query instead of reporting a wrong state.
#>
function Get-InstalledAppxNameSet {
    if ($null -ne $script:InstalledAppxNameCache) {
        # The unary comma keeps an empty set from being unrolled into nothing by the pipeline,
        # which the caller would see as a failed enumeration.
        return ,$script:InstalledAppxNameCache
    }

    try {
        $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($package in @(Get-AppxPackage -AllUsers -ErrorAction Stop)) {
            if ($package.Name -is [string]) { [void]$names.Add($package.Name) }
        }
        $script:InstalledAppxNameCache = $names
    }
    catch {
        # Leave the cache empty so the caller falls back to the per-name query.
        $script:InstalledAppxNameCache = $null
        return $null
    }

    return ,$script:InstalledAppxNameCache
}

<#
    .SYNOPSIS
        Drops the per-refresh caches used while reading the current tweak state.

    .DESCRIPTION
        Call this before a refresh so registry files and Appx package lists are read fresh.
        The caches only live for one refresh, so changes made outside Win11Debloat are
        picked up by the next one.
#>
function Reset-FeatureStateCache {
    $script:RegFileOperationCache = $null
    $script:InstalledAppxNameCache = $null
    $script:FeatureAppliedCache = $null
}

<#
    .SYNOPSIS
        Returns the parsed operations of a .reg file, cached for the current refresh.

    .DESCRIPTION
        Parsing a .reg file costs a few milliseconds and the same file is read for every
        feature that references it, on every refresh. The parsed operations depend only on
        the file contents, which do not change while the window is open, so they are cached
        per refresh and invalidated by Reset-FeatureStateCache.
#>
function Get-CachedRegFileOperations {
    param(
        [Parameter(Mandatory)]
        [string]$RegFilePath
    )

    if ($null -eq $script:RegFileOperationCache) {
        $script:RegFileOperationCache = @{}
    }

    $cached = $script:RegFileOperationCache[$RegFilePath]
    if ($null -ne $cached) { return $cached }

    $operations = @(Get-RegFileOperations -regFilePath $RegFilePath)
    $script:RegFileOperationCache[$RegFilePath] = $operations
    return $operations
}

<#
    .SYNOPSIS
        Tests whether a feature is applied, caching the answer for the current refresh.

    .DESCRIPTION
        A feature can back a checkbox and several UiGroup options, and the tweaks tab asks
        for the same state more than once per refresh. This caches the result of
        Test-FeatureAppliedUncached per FeatureId for the duration of one refresh, so the
        registry is read once per feature instead of once per control.

        The cache is dropped by Reset-FeatureStateCache, which runs before each refresh, so
        a change made outside Win11Debloat is picked up next time.

    .PARAMETER FeatureId
        The feature identifier to test.
#>
function Test-FeatureApplied {
    param (
        [Parameter(Mandatory)]
        [string]$FeatureId
    )

    if ($null -eq $script:FeatureAppliedCache) {
        $script:FeatureAppliedCache = @{}
    }

    if ($script:FeatureAppliedCache.ContainsKey($FeatureId)) {
        return $script:FeatureAppliedCache[$FeatureId]
    }

    $applied = [bool](Test-FeatureAppliedUncached -FeatureId $FeatureId)
    $script:FeatureAppliedCache[$FeatureId] = $applied
    return $applied
}

<#
    .SYNOPSIS
        Tests whether a feature's registry operations currently match the live registry.

    .DESCRIPTION
        Returns $true when ALL operations in the apply .reg file match current system
        state. Returns $false if the feature has no RegistryKey, the reg file is
        missing, or any operation mismatches. Special-cased features (Widgets, Store
        suggestions, Windows Sandbox, WSL) bypass .reg checking entirely.

        Callers go through Test-FeatureApplied, which adds the per-refresh cache; this
        function always reads the live state.

    .PARAMETER FeatureId
        The feature identifier to test.
#>
function Test-FeatureAppliedUncached {
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

            $installedNames = Get-InstalledAppxNameSet
            if ($null -ne $installedNames) {
                foreach ($appId in $widgetAppIds) {
                    if ($installedNames.Contains($appId)) { return $false }
                }

                return $true
            }

            # The single enumeration failed; fall back to one query per package.
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

            $storeDbPath = Get-StoreAppsDatabasePathForUser -UserName (Get-UserName)

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
        $operations = @(Get-CachedRegFileOperations -RegFilePath $regFilePath)
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

                    # Binary and MultiString data is an ordered sequence. The .reg parser hands back a single-element
                    # sequence as a scalar and an empty one as $null, so normalise both sides to arrays by kind and
                    # compare them position by position (Compare-Object would treat [1,2,3] and [3,2,1] as equal).
                    $match = if ($actualKind -in @([Microsoft.Win32.RegistryValueKind]::Binary, [Microsoft.Win32.RegistryValueKind]::MultiString)) {
                        $actualItems = @(if ($null -ne $actual) { $actual })
                        $expectedItems = @(if ($null -ne $expected) { $expected })
                        $sameSequence = $actualItems.Count -eq $expectedItems.Count
                        for ($i = 0; $sameSequence -and $i -lt $actualItems.Count; $i++) {
                            if ($actualItems[$i] -ne $expectedItems[$i]) { $sameSequence = $false }
                        }
                        $sameSequence
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
