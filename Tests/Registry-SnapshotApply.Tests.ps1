BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Backup-RegistrySnapshotCapture.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Restore-RegistryApplyState.ps1')

    function New-FakeRegistryKey {
        param(
            [string]$Name = 'HKEY_CURRENT_USER\Software\Example',
            [hashtable]$Values = @{},
            [hashtable]$Kinds = @{},
            [hashtable]$Children = @{}
        )

        $key = [PSCustomObject]@{
            Name = $Name
            Values = $Values
            Kinds = $Kinds
            Children = $Children
            Closed = $false
            DeletedValues = [System.Collections.Generic.List[string]]::new()
            SetCalls = [System.Collections.Generic.List[object]]::new()
        }
        $key | Add-Member ScriptMethod GetValueNames { @($this.Kinds.Keys) }
        $key | Add-Member ScriptMethod GetValueKind { param($valueName) $this.Kinds[$valueName] }
        $key | Add-Member ScriptMethod GetValue { param($valueName, $defaultValue, $options) $this.Values[$valueName] }
        $key | Add-Member ScriptMethod GetSubKeyNames { @($this.Children.Keys) }
        $key | Add-Member ScriptMethod OpenSubKey { param($subKeyName, $writable) $this.Children[$subKeyName] }
        $key | Add-Member ScriptMethod Close { $this.Closed = $true }
        $key | Add-Member ScriptMethod DeleteValue { param($valueName, $throwOnMissing) $this.DeletedValues.Add([string]$valueName) }
        $key | Add-Member ScriptMethod SetValue { param($valueName, $data, $kind) $this.SetCalls.Add(@($valueName, $data, $kind)) }
        return $key
    }
}

Describe 'Convert-RegistryValueToSnapshot' {
    It 'normalizes <Case> without expanding registry strings' -ForEach @(
        @{ Case = 'null binary'; Kind = [Microsoft.Win32.RegistryValueKind]::Binary; Data = $null; Expected = @() }
        @{ Case = 'empty binary'; Kind = [Microsoft.Win32.RegistryValueKind]::Binary; Data = [byte[]]::new(0); Expected = @() }
        @{ Case = 'binary'; Kind = [Microsoft.Win32.RegistryValueKind]::Binary; Data = [byte[]](1, 255); Expected = @(1, 255) }
        @{ Case = 'multi-string'; Kind = [Microsoft.Win32.RegistryValueKind]::MultiString; Data = [string[]]@('one', 'two'); Expected = @('one', 'two') }
        @{ Case = 'unsigned DWord'; Kind = [Microsoft.Win32.RegistryValueKind]::DWord; Data = -1; Expected = [uint32]::MaxValue }
        @{ Case = 'unsigned QWord'; Kind = [Microsoft.Win32.RegistryValueKind]::QWord; Data = -1L; Expected = [uint64]::MaxValue }
        @{ Case = 'expandable string'; Kind = [Microsoft.Win32.RegistryValueKind]::ExpandString; Data = '%TEMP%'; Expected = '%TEMP%' }
    ) {
        $key = New-FakeRegistryKey -Values @{ Value = $Data } -Kinds @{ Value = $Kind }
        $snapshot = Convert-RegistryValueToSnapshot -RegistryKey $key -ValueName 'Value'
        $snapshot.Exists | Should -BeTrue
        $snapshot.Kind | Should -Be $Kind.ToString()
        if ($Kind -eq [Microsoft.Win32.RegistryValueKind]::Binary) {
            $snapshot.Data -is [array] | Should -BeTrue
            $snapshot.Data.Count | Should -Be $Expected.Count
            if ($Expected.Count -gt 0) {
                $snapshot.Data | Should -Be $Expected
            }
            return
        }
        $snapshot.Data | Should -Be $Expected
    }

    It 'rejects REG_NONE values because their data cannot be read reliably through .NET' {
        $key = New-FakeRegistryKey -Values @{ Value = [byte[]](1) } -Kinds @{ Value = [Microsoft.Win32.RegistryValueKind]::None }

        { Convert-RegistryValueToSnapshot -RegistryKey $key -ValueName 'Value' } |
            Should -Throw 'REG_NONE registry values are not supported for backup*'
    }
}

Describe 'Registry value backup round trip' {
    BeforeAll {
        $script:RoundTripRegistrySubKey = "Software\Win11Debloat\Tests\RegistrySnapshotRoundTrip-$([guid]::NewGuid().ToString('N'))"
        $script:RoundTripRegistryKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($script:RoundTripRegistrySubKey)
    }

    AfterAll {
        if ($script:RoundTripRegistryKey) {
            $script:RoundTripRegistryKey.Close()
        }
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($script:RoundTripRegistrySubKey, $false)
    }

    It 'captures, serializes, and restores <Case> values' -ForEach @(
        @{ Case = 'String'; Kind = [Microsoft.Win32.RegistryValueKind]::String; Data = 'value' }
        @{ Case = 'ExpandString'; Kind = [Microsoft.Win32.RegistryValueKind]::ExpandString; Data = '%TEMP%\value' }
        @{ Case = 'Binary'; Kind = [Microsoft.Win32.RegistryValueKind]::Binary; Data = [byte[]](1) }
        @{ Case = 'DWord'; Kind = [Microsoft.Win32.RegistryValueKind]::DWord; Data = [int]42 }
        @{ Case = 'MultiString'; Kind = [Microsoft.Win32.RegistryValueKind]::MultiString; Data = [string[]]@('one', 'two') }
        @{ Case = 'QWord'; Kind = [Microsoft.Win32.RegistryValueKind]::QWord; Data = [int64]42 }
    ) {
        $sourceName = "Source-$Case"
        $restoredName = "Restored-$Case"
        $script:RoundTripRegistryKey.SetValue($sourceName, $Data, $Kind)

        $snapshot = Convert-RegistryValueToSnapshot -RegistryKey $script:RoundTripRegistryKey -ValueName $sourceName
        $serializedSnapshot = $snapshot | ConvertTo-Json -Depth 5 | ConvertFrom-Json
        $serializedSnapshot.Name = $restoredName

        Restore-RegistryValueSnapshot -RegistryKey $script:RoundTripRegistryKey -Snapshot $serializedSnapshot
        $restoredSnapshot = Convert-RegistryValueToSnapshot -RegistryKey $script:RoundTripRegistryKey -ValueName $restoredName

        $restoredSnapshot.Kind | Should -Be $snapshot.Kind
        if ($Kind -in @([Microsoft.Win32.RegistryValueKind]::Binary, [Microsoft.Win32.RegistryValueKind]::None, [Microsoft.Win32.RegistryValueKind]::MultiString)) {
            $restoredSnapshot.Data -is [array] | Should -BeTrue
        }
        $restoredSnapshot.Data | Should -Be $snapshot.Data
    }
}

Describe 'Convert-RegistryKeyToSnapshot' {
    It 'captures selected missing values and recursively closes child keys' {
        $child = New-FakeRegistryKey -Name 'HKEY_CURRENT_USER\Software\Example\Child' -Values @{ ChildValue = 'data' } -Kinds @{ ChildValue = [Microsoft.Win32.RegistryValueKind]::String }
        $root = New-FakeRegistryKey -Values @{ Present = 1 } -Kinds @{ Present = [Microsoft.Win32.RegistryValueKind]::DWord } -Children @{ Child = $child }

        $snapshot = Convert-RegistryKeyToSnapshot -RegistryKey $root -FullPath $root.Name -ValueNames @('Missing', 'Present') -IncludeSubKeys:$true

        $snapshot.Values | Should -HaveCount 2
        ($snapshot.Values | Where-Object Name -eq 'Missing').Exists | Should -BeFalse
        $snapshot.SubKeys | Should -HaveCount 1
        $snapshot.SubKeys[0].Values[0].Data | Should -Be 'data'
        $child.Closed | Should -BeTrue
    }
}

Describe 'Get-RegistryKeySnapshot' {
    BeforeEach {
        Mock Split-RegistryPath { [PSCustomObject]@{ Hive = 'HKEY_CURRENT_USER'; SubKey = 'Software\Example' } }
    }

    It 'returns an explicit non-existent snapshot when the key is absent' {
        $root = [PSCustomObject]@{}
        $root | Add-Member ScriptMethod OpenSubKey { $null }
        Mock Get-RegistryRootKey { $root }

        $snapshot = Get-RegistryKeySnapshot -KeyPath 'HKEY_CURRENT_USER\Software\Example'
        $snapshot.Exists | Should -BeFalse
        $snapshot.Values | Should -HaveCount 0
    }

    It 'closes an opened root snapshot key' {
        $key = New-FakeRegistryKey
        $root = [PSCustomObject]@{ Key = $key }
        $root | Add-Member ScriptMethod OpenSubKey { $this.Key }
        Mock Get-RegistryRootKey { $root }

        Get-RegistryKeySnapshot -KeyPath 'HKEY_CURRENT_USER\Software\Example' | Out-Null
        $key.Closed | Should -BeTrue
    }
}

Describe 'Restore-RegistryValueSnapshot' {
    It 'deletes a missing value using the default-value name when necessary' {
        $key = New-FakeRegistryKey
        Restore-RegistryValueSnapshot -RegistryKey $key -Snapshot ([PSCustomObject]@{ Name = $null; Exists = $false })
        $key.DeletedValues | Should -Be @('')
    }

    It 'sets a value with its original kind and converted bit pattern' {
        $key = New-FakeRegistryKey
        Restore-RegistryValueSnapshot -RegistryKey $key -Snapshot ([PSCustomObject]@{ Name = 'Large'; Exists = $true; Kind = 'QWord'; Data = [uint64]::MaxValue })
        $key.SetCalls | Should -HaveCount 1
        $key.SetCalls[0][0] | Should -Be 'Large'
        $key.SetCalls[0][1] | Should -Be ([int64]-1)
        $key.SetCalls[0][1].GetType() | Should -Be ([int64])
        $key.SetCalls[0][2] | Should -Be ([Microsoft.Win32.RegistryValueKind]::QWord)
    }

    It 'does not silently downgrade a failed value write to Binary' {
        $key = New-FakeRegistryKey
        $key.PSObject.Members.Remove('SetValue')
        $key | Add-Member ScriptMethod SetValue { throw 'write denied' }
        { Restore-RegistryValueSnapshot -RegistryKey $key -Snapshot ([PSCustomObject]@{ Name = 'Value'; Exists = $true; Kind = 'String'; Data = 'data' }) } |
            Should -Throw '*write denied*'
    }
}

Describe 'Restore-RegistryKeySnapshot - mutation flow' {
    BeforeEach {
        Mock Split-RegistryPath {
            param($path)
            [PSCustomObject]@{ Hive = 'HKEY_CURRENT_USER'; SubKey = $path.Substring('HKEY_CURRENT_USER\'.Length) }
        }
        Mock Remove-RegistrySubKeyTreeIfExists {}
    }

    It 'removes a key that did not exist when the backup was created' {
        Mock Get-RegistryRootKey { [PSCustomObject]@{} }
        Restore-RegistryKeySnapshot -Snapshot ([PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\Gone'; Exists = $false; Values = @(); SubKeys = @() })
        Should -Invoke Remove-RegistrySubKeyTreeIfExists -Times 1 -Exactly -ParameterFilter { $SubKeyPath -eq 'Software\Gone' }
    }

    It 'creates, populates, and closes an existing key snapshot' {
        $key = New-FakeRegistryKey
        $root = [PSCustomObject]@{ Key = $key }
        $root | Add-Member ScriptMethod CreateSubKey { param($path) $this.Key }
        Mock Get-RegistryRootKey { $root }

        Restore-RegistryKeySnapshot -Snapshot ([PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Example'; Exists = $true
            Values = @([PSCustomObject]@{ Name = 'Enabled'; Exists = $true; Kind = 'DWord'; Data = 1 })
            SubKeys = @()
        })

        $key.SetCalls | Should -HaveCount 1
        $key.Closed | Should -BeTrue
    }
}
