BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1')
}

Describe 'Native empty-key cleanup' {
    It 'handles a key containing <Case> without deleting unrelated data' -ForEach @(
        @{ Case = 'nothing'; ValueName = $null; HasChild = $false; ShouldDelete = $true }
        @{ Case = 'a named value'; ValueName = 'KeepValue'; HasChild = $false; ShouldDelete = $false }
        @{ Case = 'a default value'; ValueName = ''; HasChild = $false; ShouldDelete = $false }
        @{ Case = 'a child key'; ValueName = $null; HasChild = $true; ShouldDelete = $false }
    ) {
        $testSubKey = "Software\Win11Debloat\Tests\RegistryEmptyKeyCleanup-$([guid]::NewGuid().ToString('N'))"
        $testRoot = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($testSubKey)
        $remainingKey = $null
        try {
            $candidate = $testRoot.CreateSubKey('Candidate')
            try {
                if ($null -ne $ValueName) {
                    $candidate.SetValue($ValueName, 'keep', [Microsoft.Win32.RegistryValueKind]::String)
                }
                if ($HasChild) {
                    $child = $candidate.CreateSubKey('KeepChild')
                    $child.Close()
                }
            }
            finally {
                $candidate.Close()
            }

            # Exercise the real P/Invoke and status handling, without mocks.
            Remove-RegistryEmptyKeyIfExists -RootKey $testRoot -SubKeyPath 'Candidate'

            $remainingKey = $testRoot.OpenSubKey('Candidate', $false)
            if ($ShouldDelete) {
                $remainingKey | Should -BeNullOrEmpty
            }
            else {
                $remainingKey | Should -Not -BeNullOrEmpty
                if ($null -ne $ValueName) {
                    @($remainingKey.GetValueNames()) | Should -HaveCount 1
                    $remainingKey.GetValue($ValueName) | Should -BeExactly 'keep'
                }
                if ($HasChild) {
                    @($remainingKey.GetSubKeyNames()) | Should -Be @('KeepChild')
                }
            }
        }
        finally {
            if ($null -ne $remainingKey) { $remainingKey.Close() }
            $testRoot.Close()
            [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($testSubKey, $false)
        }
    }
}
