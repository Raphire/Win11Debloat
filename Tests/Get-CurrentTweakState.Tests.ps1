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
        @{ Case = 'treats Widgets as disabled when all related packages are absent'; PresentPackage = $null; Expected = $true; ExpectedCalls = 3 }
        @{ Case = 'treats Widgets as enabled when a related package is present'; PresentPackage = 'MicrosoftWindows.Client.WebExperience'; Expected = $false; ExpectedCalls = 2 }
    ) {
        Mock Get-AppxPackage { param($Name) if ($Name -eq $PresentPackage) { [PSCustomObject]@{ Name = $Name } } }

        Test-FeatureApplied -FeatureId 'DisableWidgets' | Should -Be $Expected
        Should -Invoke Get-AppxPackage -Times $ExpectedCalls -Exactly
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
