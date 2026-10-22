BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1')

    function Initialize-EmptyKeyCleanupTest {
        param([scriptblock]$Setup = {})

        $script:testSubKey = "Software\Win11Debloat\Tests\RegistryEmptyKeyCleanup-$([guid]::NewGuid().ToString('N'))"
        $script:testRoot = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($script:testSubKey)
        $candidate = $script:testRoot.CreateSubKey('Candidate')
        try {
            & $Setup $candidate
        }
        finally {
            $candidate.Close()
        }

        # Exercise the real P/Invoke and status handling, without mocks.
        Remove-RegistryEmptyKeyIfExists -RootKey $script:testRoot -SubKeyPath 'Candidate'
        $script:remainingKey = $script:testRoot.OpenSubKey('Candidate', $false)
    }
}

Describe 'Native empty-key cleanup' {
    BeforeEach {
        $script:testRoot = $null
        $script:remainingKey = $null
    }

    AfterEach {
        if ($null -ne $script:remainingKey) { $script:remainingKey.Close() }
        if ($null -ne $script:testRoot) {
            $script:testRoot.Close()
            [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($script:testSubKey, $false)
        }
    }

    It 'deletes an empty key' {
        Initialize-EmptyKeyCleanupTest

        $script:remainingKey | Should -BeNullOrEmpty
    }

    It 'retains a key containing <Case> and its value' -ForEach @(
        @{ Case = 'a named value'; ValueName = 'KeepValue' }
        @{ Case = 'a default value'; ValueName = '' }
    ) {
        Initialize-EmptyKeyCleanupTest -Setup {
            param($Candidate)
            $Candidate.SetValue($ValueName, 'keep', [Microsoft.Win32.RegistryValueKind]::String)
        }

        $script:remainingKey | Should -Not -BeNullOrEmpty
        @($script:remainingKey.GetValueNames()) | Should -HaveCount 1
        $script:remainingKey.GetValue($ValueName) | Should -BeExactly 'keep'
    }

    It 'retains a key containing a child key' {
        Initialize-EmptyKeyCleanupTest -Setup {
            param($Candidate)
            $child = $Candidate.CreateSubKey('KeepChild')
            $child.Close()
        }

        $script:remainingKey | Should -Not -BeNullOrEmpty
        @($script:remainingKey.GetSubKeyNames()) | Should -Be @('KeepChild')
    }
}
