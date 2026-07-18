BeforeAll {
    $restoreApplyStateScriptPath = Join-Path $PSScriptRoot '..\Scripts\Features\RestoreRegistryApplyState.ps1'
    . $restoreApplyStateScriptPath
}

Describe 'Convert-RegistryValueKindFromBackup' {
    It 'defaults a missing kind to String' {
        Convert-RegistryValueKindFromBackup -KindName $null | Should -Be ([Microsoft.Win32.RegistryValueKind]::String)
    }

    It '<Case>' -ForEach @(
        @{ Case = 'parses registry kinds case-insensitively'; KindName = 'dword'; Expected = [Microsoft.Win32.RegistryValueKind]::DWord; ExpectedError = $null }
        @{ Case = 'rejects an invalid registry kind'; KindName = 'NotARegistryValueKind'; Expected = $null; ExpectedError = 'Unsupported registry value kind in backup: NotARegistryValueKind' }
    ) {
        if ($ExpectedError) {
            { Convert-RegistryValueKindFromBackup -KindName $KindName } | Should -Throw $ExpectedError
        }
        else {
            Convert-RegistryValueKindFromBackup -KindName $KindName | Should -Be $Expected
        }
    }
}

Describe 'Convert-RegistryValueDataFromBackup' {
    It 'preserves the bit pattern of an unsigned <Kind>' -ForEach @(
        @{ Kind = [Microsoft.Win32.RegistryValueKind]::DWord; Data = [uint32]::MaxValue; Expected = -1 }
        @{ Kind = [Microsoft.Win32.RegistryValueKind]::QWord; Data = [uint64]::MaxValue; Expected = -1L }
    ) {
        Convert-RegistryValueDataFromBackup -Kind $Kind -Data $Data | Should -Be $Expected
    }

    It 'converts <Case>' -ForEach @(
        @{ Case = 'a multi-string value'; Kind = [Microsoft.Win32.RegistryValueKind]::MultiString; Data = @(1, 'two'); Expected = @('1', 'two'); ExpectNull = $false }
        @{ Case = 'a binary value'; Kind = [Microsoft.Win32.RegistryValueKind]::Binary; Data = @('1', 255); Expected = [byte[]](1, 255); ExpectNull = $false }
        @{ Case = 'a None value'; Kind = [Microsoft.Win32.RegistryValueKind]::None; Data = 'ignored'; Expected = $null; ExpectNull = $true }
        @{ Case = 'a null string to an empty string'; Kind = [Microsoft.Win32.RegistryValueKind]::String; Data = $null; Expected = ''; ExpectNull = $false }
    ) {
        $result = Convert-RegistryValueDataFromBackup -Kind $Kind -Data $Data
        if ($ExpectNull) {
            $result | Should -BeNullOrEmpty
        }
        else {
            $result | Should -Be $Expected
        }
    }

    It 'rejects binary backup data that cannot be represented as bytes' {
        { Convert-RegistryValueDataFromBackup -Kind ([Microsoft.Win32.RegistryValueKind]::Binary) -Data @(-1, 256, 'invalid') } |
            Should -Throw 'Invalid binary registry data in backup*'
    }

    It 'preserves an empty binary value as a byte array' {
        $result = Convert-RegistryValueDataFromBackup -Kind ([Microsoft.Win32.RegistryValueKind]::Binary) -Data $null
        $result | Should -BeNullOrEmpty
        $result.GetType() | Should -Be ([byte[]])
    }
}

Describe 'Convert-BackupDataToByteArray' {
    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an object value'; Data = [PSCustomObject]@{ Value = 1 } }
        @{ Case = 'a negative byte'; Data = @(-1) }
        @{ Case = 'a byte greater than 255'; Data = @(256) }
        @{ Case = 'non-numeric input'; Data = @('invalid') }
    ) {
        Convert-BackupDataToByteArray -Data $Data | Should -BeNullOrEmpty
    }
}
