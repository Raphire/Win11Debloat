BeforeAll {
    function Test-StoreSearchSuggestionsDisabledForAllUsers { $false }
    function Test-StoreSearchSuggestionsDisabled { param($StoreAppsDatabase) $false }
    function Get-StoreAppsDatabasePathForUser { param($UserName) 'store.db' }
    function Get-UserName { 'Alice' }
    function Test-WindowsOptionalFeatureEnabled { param($FeatureName) $false }
    function Get-RegFileOperations { param($regFilePath) @() }
    function Split-RegistryPath { param($path) $null }
    function Get-RegistryRootKey { param($hiveName) $null }

    function New-CurrentStateRegistryKey {
        param([hashtable]$Values = @{}, [hashtable]$Kinds = @{})
        $key = [PSCustomObject]@{ Values = $Values; Kinds = $Kinds; Closed = $false }
        $key | Add-Member ScriptMethod GetValueNames { @($this.Kinds.Keys) }
        $key | Add-Member ScriptMethod GetValueKind { param($name) $this.Kinds[$name] }
        $key | Add-Member ScriptMethod GetValue { param($name, $defaultValue, $options) $this.Values[$name] }
        $key | Add-Member ScriptMethod Close { $this.Closed = $true }
        return $key
    }

    . (Join-Path $PSScriptRoot '..\Scripts\Features\Get-CurrentTweakState.ps1')
}

Describe 'Get-ExpectedRegistryValueKind' {
    It 'maps <ValueType> to <Expected>' -ForEach @(
        @{ ValueType = 'DWord'; Expected = [Microsoft.Win32.RegistryValueKind]::DWord }
        @{ ValueType = 'QWord'; Expected = [Microsoft.Win32.RegistryValueKind]::QWord }
        @{ ValueType = 'String'; Expected = [Microsoft.Win32.RegistryValueKind]::String }
        @{ ValueType = 'Binary'; Expected = [Microsoft.Win32.RegistryValueKind]::Binary }
        @{ ValueType = 'Hex2'; Expected = [Microsoft.Win32.RegistryValueKind]::ExpandString }
        @{ ValueType = 'Hex7'; Expected = [Microsoft.Win32.RegistryValueKind]::MultiString }
    ) {
        $operation = [PSCustomObject]@{ ValueType = $ValueType }

        Get-ExpectedRegistryValueKind -Operation $operation | Should -Be $Expected
    }

    It 'returns null for unsupported operation types' {
        Get-ExpectedRegistryValueKind -Operation ([PSCustomObject]@{ ValueType = 'Hex11' }) | Should -BeNullOrEmpty
    }
}

Describe 'Test-FeatureApplied - special features' {
    BeforeEach {
        $script:Params = @{}
        Reset-FeatureStateCache
        $script:Features = @{
            DisableWidgets = [PSCustomObject]@{}
            DisableStoreSearchSuggestions = [PSCustomObject]@{}
            EnableWindowsSandbox = [PSCustomObject]@{}
            EnableWindowsSubsystemForLinux = [PSCustomObject]@{}
        }
        Mock Get-AppxPackage { $null }
        Mock Test-StoreSearchSuggestionsDisabledForAllUsers { $true }
        Mock Test-StoreSearchSuggestionsDisabled { $true }
        Mock Get-StoreAppsDatabasePathForUser { 'store.db' }
        Mock Get-UserName { 'Alice' }
        Mock Test-WindowsOptionalFeatureEnabled { $true }
    }

    It '<Case>' -ForEach @(
        @{ Case = 'treats Widgets as disabled when all related packages are absent'; PresentPackage = $null; Expected = $true }
        @{ Case = 'treats Widgets as enabled when a related package is present'; PresentPackage = 'MicrosoftWindows.Client.WebExperience'; Expected = $false }
    ) {
        Mock Get-AppxPackage {
            param($Name, [switch]$AllUsers)
            if ($Name) {
                if ($Name -eq $PresentPackage) { [PSCustomObject]@{ Name = $Name } }
                return
            }
            if ($PresentPackage) { [PSCustomObject]@{ Name = $PresentPackage } }
        }

        Test-FeatureApplied -FeatureId 'DisableWidgets' | Should -Be $Expected
        # One -AllUsers enumeration answers every package, so no per-name queries are needed.
        Should -Invoke Get-AppxPackage -Times 1 -Exactly -ParameterFilter { $AllUsers -and -not $Name }
        Should -Invoke Get-AppxPackage -Times 0 -Exactly -ParameterFilter { [bool]$Name }
    }

    It 'uses <Case> Store detection' -ForEach @(
        @{ Case = 'all-user'; Params = @{ Sysprep = $true }; AllUsersCalls = 1; UserCalls = 0 }
        @{ Case = 'user-specific'; Params = @{}; AllUsersCalls = 0; UserCalls = 1 }
    ) {
        $script:Params = $Params
        Test-FeatureApplied -FeatureId 'DisableStoreSearchSuggestions' | Should -BeTrue
        Should -Invoke Test-StoreSearchSuggestionsDisabledForAllUsers -Times $AllUsersCalls -Exactly
        Should -Invoke Test-StoreSearchSuggestionsDisabled -Times $UserCalls -Exactly -ParameterFilter { $StoreAppsDatabase -eq 'store.db' }
    }

    It 'checks the expected optional feature for Windows Sandbox' {
        Test-FeatureApplied -FeatureId 'EnableWindowsSandbox' | Should -BeTrue
        Should -Invoke Test-WindowsOptionalFeatureEnabled -Times 1 -Exactly -ParameterFilter { $FeatureName -eq 'Containers-DisposableClientVM' }
    }

    It '<Case>' -ForEach @(
        @{ Case = 'reports WSL applied when both optional features are enabled'; DisabledFeature = $null; Expected = $true }
        @{ Case = 'reports WSL not applied when VirtualMachinePlatform is disabled'; DisabledFeature = 'VirtualMachinePlatform'; Expected = $false }
    ) {
        Mock Test-WindowsOptionalFeatureEnabled { param($FeatureName) $FeatureName -ne $DisabledFeature }
        Test-FeatureApplied -FeatureId 'EnableWindowsSubsystemForLinux' | Should -Be $Expected
    }
}

Describe 'Test-FeatureApplied - registry preconditions' {
    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = $TestDrive
        Reset-FeatureStateCache
        $script:Features = @{
            NoRegistry = [PSCustomObject]@{ RegistryKey = '' }
            MissingFile = [PSCustomObject]@{ RegistryKey = 'missing.reg' }
            EmptyOperations = [PSCustomObject]@{ RegistryKey = 'empty.reg' }
        }
    }

    It 'returns false for <Case>' -ForEach @(
        @{ Case = 'a feature without registry data'; FeatureId = 'NoRegistry'; ParserBehavior = 'None' }
        @{ Case = 'a missing registry file'; FeatureId = 'MissingFile'; ParserBehavior = 'None' }
        @{ Case = 'an empty registry operation set'; FeatureId = 'EmptyOperations'; ParserBehavior = 'Empty' }
        @{ Case = 'a registry operation parse failure'; FeatureId = 'EmptyOperations'; ParserBehavior = 'Throw' }
    ) {
        if ($ParserBehavior -ne 'None') {
            '' | Set-Content -LiteralPath (Join-Path $TestDrive 'empty.reg')
            if ($ParserBehavior -eq 'Empty') { Mock Get-RegFileOperations { @() } }
            if ($ParserBehavior -eq 'Throw') { Mock Get-RegFileOperations { throw 'parse failed' } }
        }

        Test-FeatureApplied -FeatureId $FeatureId | Should -BeFalse
    }
}

Describe 'Test-FeatureApplied - registry state comparison' {
    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = $TestDrive
        Reset-FeatureStateCache
        $script:Features = @{ RegistryFeature = [PSCustomObject]@{ RegistryKey = 'feature.reg' } }
        '' | Set-Content -LiteralPath (Join-Path $TestDrive 'feature.reg')
        Mock Split-RegistryPath { [PSCustomObject]@{ Hive = 'HKEY_CURRENT_USER'; SubKey = 'Software\Example' } }
    }

    It 'matches set values by kind and normalized unsigned data and closes the key' {
        $key = New-CurrentStateRegistryKey -Values @{ Large = -1L } -Kinds @{ Large = [Microsoft.Win32.RegistryValueKind]::QWord }
        $root = [PSCustomObject]@{ Key = $key }
        $root | Add-Member ScriptMethod OpenSubKey { param($path, $writable) $this.Key }
        Mock Get-RegistryRootKey { $root }
        Mock Get-RegFileOperations { @([PSCustomObject]@{ OperationType = 'SetValue'; KeyPath = 'HKEY_CURRENT_USER\Software\Example'; ValueName = 'Large'; ValueType = 'QWord'; ValueData = [uint64]::MaxValue }) }

        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -BeTrue
        $key.Closed | Should -BeTrue
    }

    It 'returns false for a value-kind or data mismatch' -ForEach @(
        @{ ActualKind = [Microsoft.Win32.RegistryValueKind]::String; ActualData = '1'; ExpectedType = 'DWord'; ExpectedData = 1 }
        @{ ActualKind = [Microsoft.Win32.RegistryValueKind]::DWord; ActualData = 2; ExpectedType = 'DWord'; ExpectedData = 1 }
    ) {
        $key = New-CurrentStateRegistryKey -Values @{ Enabled = $ActualData } -Kinds @{ Enabled = $ActualKind }
        $root = [PSCustomObject]@{ Key = $key }
        $root | Add-Member ScriptMethod OpenSubKey { param($path, $writable) $this.Key }
        Mock Get-RegistryRootKey { $root }
        Mock Get-RegFileOperations { @([PSCustomObject]@{ OperationType = 'SetValue'; KeyPath = 'HKEY_CURRENT_USER\Software\Example'; ValueName = 'Enabled'; ValueType = $ExpectedType; ValueData = $ExpectedData }) }

        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -BeFalse
        $key.Closed | Should -BeTrue
    }

    It 'compares binary data in order: <Case>' -ForEach @(
        @{ Case = 'identical bytes'; Actual = @(1, 2, 3); Expected = @(1, 2, 3); Result = $true }
        @{ Case = 'the same bytes in a different order'; Actual = @(1, 2, 3); Expected = @(3, 2, 1); Result = $false }
        @{ Case = 'a different length'; Actual = @(1, 2, 3); Expected = @(1, 2); Result = $false }
        @{ Case = 'a single byte that matches'; Actual = @(1); Expected = 1; Result = $true }
        @{ Case = 'a single zero byte that matches'; Actual = @(0); Expected = 0; Result = $true }
        @{ Case = 'a longer value against a single expected byte'; Actual = @(1, 2); Expected = 1; Result = $false }
        @{ Case = 'an empty value on both sides'; Actual = @(); Expected = $null; Result = $true }
    ) {
        $key = New-CurrentStateRegistryKey -Values @{ Mask = [byte[]]$Actual } -Kinds @{ Mask = [Microsoft.Win32.RegistryValueKind]::Binary }
        $root = [PSCustomObject]@{ Key = $key }
        $root | Add-Member ScriptMethod OpenSubKey { param($path, $writable) $this.Key }
        Mock Get-RegistryRootKey { $root }
        Mock Get-RegFileOperations { @([PSCustomObject]@{ OperationType = 'SetValue'; KeyPath = 'HKEY_CURRENT_USER\Software\Example'; ValueName = 'Mask'; ValueType = 'Binary'; ValueData = $Expected }) }

        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -Be $Result
    }

    It 'compares multi-string data in order: <Case>' -ForEach @(
        @{ Case = 'identical strings'; Actual = @('one', 'two'); Expected = @('one', 'two'); Result = $true }
        @{ Case = 'the same strings in a different order'; Actual = @('one', 'two'); Expected = @('two', 'one'); Result = $false }
        @{ Case = 'a different length'; Actual = @('one', 'two'); Expected = 'one'; Result = $false }
        @{ Case = 'a single string that matches'; Actual = @('one'); Expected = 'one'; Result = $true }
        @{ Case = 'single strings sharing their first character'; Actual = @('other'); Expected = 'one'; Result = $false }
        @{ Case = 'an empty value on both sides'; Actual = @(); Expected = $null; Result = $true }
    ) {
        $key = New-CurrentStateRegistryKey -Values @{ Items = [string[]]$Actual } -Kinds @{ Items = [Microsoft.Win32.RegistryValueKind]::MultiString }
        $root = [PSCustomObject]@{ Key = $key }
        $root | Add-Member ScriptMethod OpenSubKey { param($path, $writable) $this.Key }
        Mock Get-RegistryRootKey { $root }
        Mock Get-RegFileOperations { @([PSCustomObject]@{ OperationType = 'SetValue'; KeyPath = 'HKEY_CURRENT_USER\Software\Example'; ValueName = 'Items'; ValueType = 'Hex7'; ValueData = $Expected }) }

        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -Be $Result
        $key.Closed | Should -BeTrue
    }

    It 'treats missing keys and values as successful delete operations' -ForEach @(
        @{ OperationType = 'DeleteKey'; ReturnKey = $false }
        @{ OperationType = 'DeleteValue'; ReturnKey = $true }
    ) {
        $key = New-CurrentStateRegistryKey
        $root = [PSCustomObject]@{ Key = $key; ReturnKey = $ReturnKey }
        $root | Add-Member ScriptMethod OpenSubKey { param($path, $writable) if ($this.ReturnKey) { $this.Key } else { $null } }
        Mock Get-RegistryRootKey { $root }
        Mock Get-RegFileOperations { @([PSCustomObject]@{ OperationType = $OperationType; KeyPath = 'HKEY_CURRENT_USER\Software\Example'; ValueName = 'Gone' }) }

        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -BeTrue
    }
}

Describe 'Feature state caches' {
    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = $TestDrive
        Reset-FeatureStateCache
        $script:Features = @{ RegistryFeature = [PSCustomObject]@{ RegistryKey = 'feature.reg' } }
        '' | Set-Content -LiteralPath (Join-Path $TestDrive 'feature.reg')
        Mock Split-RegistryPath { [PSCustomObject]@{ Hive = 'HKEY_CURRENT_USER'; SubKey = 'Software\Example' } }
        Mock Get-RegistryRootKey { $null }
    }

    It 'parses a registry file once per refresh' {
        Mock Get-RegFileOperations { @() }

        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -BeFalse
        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -BeFalse
        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -BeFalse

        Should -Invoke Get-RegFileOperations -Times 1 -Exactly
    }

    It 'parses the registry file again after the cache is reset' {
        Mock Get-RegFileOperations { @() }

        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -BeFalse
        Reset-FeatureStateCache
        Test-FeatureApplied -FeatureId 'RegistryFeature' | Should -BeFalse

        Should -Invoke Get-RegFileOperations -Times 2 -Exactly
    }

    It 'reuses one Appx enumeration for every Widgets package' {
        $script:Features['DisableWidgets'] = [PSCustomObject]@{}
        Mock Get-AppxPackage { @() }

        Test-FeatureApplied -FeatureId 'DisableWidgets' | Should -BeTrue
        Test-FeatureApplied -FeatureId 'DisableWidgets' | Should -BeTrue

        Should -Invoke Get-AppxPackage -Times 1 -Exactly -ParameterFilter { $AllUsers -eq $true -and -not $Name }
    }

    It 'falls back to a per-package query when the enumeration fails' {
        Reset-FeatureStateCache
        $script:Features['DisableWidgets'] = [PSCustomObject]@{}
        Mock Get-AppxPackage {
            param($Name, [switch]$AllUsers)
            if (-not $Name) { throw 'enumeration failed' }
            if ($Name -eq 'MicrosoftWindows.Client.WebExperience') { [PSCustomObject]@{ Name = $Name } }
        }

        Test-FeatureApplied -FeatureId 'DisableWidgets' | Should -BeFalse
        Should -Invoke Get-AppxPackage -Times 2 -Exactly -ParameterFilter { [bool]$Name }
    }
}

Describe 'Get-CachedRegistryPath' {
    BeforeEach {
        Reset-FeatureStateCache
        Mock Split-RegistryPath { [PSCustomObject]@{ Hive = 'HKEY_CURRENT_USER'; SubKey = 'Software\Example' } }
        Mock Get-RegistryRootKey { [PSCustomObject]@{ Name = 'root' } }
    }

    It 'resolves a path once per refresh' {
        Get-CachedRegistryPath -KeyPath 'HKEY_CURRENT_USER\Software\Example' | Should -Not -BeNullOrEmpty
        Get-CachedRegistryPath -KeyPath 'HKEY_CURRENT_USER\Software\Example' | Should -Not -BeNullOrEmpty
        Get-CachedRegistryPath -KeyPath 'HKEY_CURRENT_USER\Software\Example' | Should -Not -BeNullOrEmpty

        Should -Invoke Split-RegistryPath -Times 1 -Exactly
        Should -Invoke Get-RegistryRootKey -Times 1 -Exactly
    }

    It 'resolves the path again after the cache is reset' {
        Get-CachedRegistryPath -KeyPath 'HKEY_CURRENT_USER\Software\Example' | Should -Not -BeNullOrEmpty
        Reset-FeatureStateCache
        Get-CachedRegistryPath -KeyPath 'HKEY_CURRENT_USER\Software\Example' | Should -Not -BeNullOrEmpty

        Should -Invoke Split-RegistryPath -Times 2 -Exactly
    }

    It 'returns nothing for a path that cannot be resolved' {
        Mock Split-RegistryPath { $null }

        Get-CachedRegistryPath -KeyPath 'not-a-registry-path' | Should -BeNullOrEmpty
    }

    It 'returns nothing when the hive is unknown' {
        Mock Get-RegistryRootKey { $null }

        Get-CachedRegistryPath -KeyPath 'HKEY_CURRENT_USER\Software\Example' | Should -BeNullOrEmpty
    }
}

Describe 'Get-CurrentGroupActiveIndex' {
    BeforeEach { Mock Test-FeatureApplied { $false } }

    It 'returns the one-based index of the first fully applied option' {
        $group = [PSCustomObject]@{ Values = @(
            [PSCustomObject]@{ FeatureIds = @('One', 'Missing') }
            [PSCustomObject]@{ FeatureIds = @('Two', 'Three') }
        ) }
        Mock Test-FeatureApplied { param($FeatureId) $FeatureId -in @('Two', 'Three') }

        Get-CurrentGroupActiveIndex -Group $group | Should -Be 2
    }

    It 'returns zero when no option is fully applied' {
        $group = [PSCustomObject]@{ Values = @([PSCustomObject]@{ FeatureIds = @('One') }) }
        Get-CurrentGroupActiveIndex -Group $group | Should -Be 0
    }
}
