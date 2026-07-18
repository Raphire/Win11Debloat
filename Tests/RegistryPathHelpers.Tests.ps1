BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\RegistryPathHelpers.ps1')
}

Describe 'Split-RegistryPath' {
    BeforeEach { $script:RegistryTargetHiveMountName = $null }

    It 'normalizes whitespace, slashes, and a registry subkey' {
        $result = Split-RegistryPath -path ' HKEY_CURRENT_USER/Software/Example/ '

        $result.Hive | Should -Be 'HKEY_CURRENT_USER'
        $result.SubKey | Should -Be 'Software\Example'
    }

    It 'returns null for <Case>' -ForEach @(
        @{ Case = 'a blank path'; Path = '   ' }
        @{ Case = 'a path without a hive'; Path = 'Software\Example' }
        @{ Case = 'an abbreviated hive path'; Path = 'HKCU\Software\Example' }
    ) {
        Split-RegistryPath -path $Path | Should -BeNullOrEmpty
    }

    It 'rewrites the Default user hive only while a target hive is mounted' {
        $script:RegistryTargetHiveMountName = 'S-1-5-21-123'

        (Split-RegistryPath -path 'HKEY_USERS\Default\Software\Example').SubKey | Should -Be 'S-1-5-21-123\Software\Example'
        (Split-RegistryPath -path 'HKEY_USERS\Other\Software\Example').SubKey | Should -Be 'Other\Software\Example'
    }
}

Describe 'Get-RegistryFilePathForFeature' {
    BeforeEach { $script:RegfilesPath = 'C:\Regfiles'; $script:Params = @{} }

    It 'uses <Case>' -ForEach @(
        @{ Case = 'the normal layout by default'; Params = @{}; UseSysprepRegFiles = $false; ExpectedRoot = 'C:\Regfiles' }
        @{ Case = 'the Sysprep layout for an explicit switch'; Params = @{}; UseSysprepRegFiles = $true; ExpectedRoot = 'C:\Regfiles\Sysprep' }
        @{ Case = 'the Sysprep layout for User mode'; Params = @{ User = 'Alice' }; UseSysprepRegFiles = $false; ExpectedRoot = 'C:\Regfiles\Sysprep' }
    ) {
        $script:Params = $Params
        Get-RegistryFilePathForFeature -RegistryKey 'Feature.reg' -UseSysprepRegFiles:$UseSysprepRegFiles |
            Should -Be (Join-Path $ExpectedRoot 'Feature.reg')
    }
}

Describe 'Remove-RegistrySubKeyTreeIfExists' {
    It 'deletes a subtree and ignores a key that disappears during deletion' {
        $root = [PSCustomObject]@{ Calls = 0 }
        $root | Add-Member ScriptMethod DeleteSubKeyTree { param($path, $throwOnMissing) $this.Calls++ }
        { Remove-RegistrySubKeyTreeIfExists -RootKey $root -SubKeyPath 'Software\Example' } | Should -Not -Throw
        $root.Calls | Should -Be 1

        $root.PSObject.Members.Remove('DeleteSubKeyTree')
        $root | Add-Member ScriptMethod DeleteSubKeyTree { throw [System.ArgumentException]::new('already gone') }
        { Remove-RegistrySubKeyTreeIfExists -RootKey $root -SubKeyPath 'Software\Example' } | Should -Not -Throw
    }

    It 'preserves access-denied failures' -ForEach @(
        @{ Exception = [System.UnauthorizedAccessException]::new('denied') }
        @{ Exception = [System.Security.SecurityException]::new('blocked') }
    ) {
        $root = [PSCustomObject]@{ Failure = $Exception }
        $root | Add-Member ScriptMethod DeleteSubKeyTree { throw $this.Failure }
        { Remove-RegistrySubKeyTreeIfExists -RootKey $root -SubKeyPath 'Software\Example' } | Should -Throw
    }

    It 'preserves unexpected registry deletion failures' {
        $root = [PSCustomObject]@{ Failure = [System.IO.IOException]::new('registry I/O failure') }
        $root | Add-Member ScriptMethod DeleteSubKeyTree { throw $this.Failure }

        { Remove-RegistrySubKeyTreeIfExists -RootKey $root -SubKeyPath 'Software\Example' } | Should -Throw '*registry I/O failure*'
    }
}
