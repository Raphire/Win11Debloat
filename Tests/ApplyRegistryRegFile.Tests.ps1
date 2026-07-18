BeforeAll {
    function Invoke-WithTargetUserHive { param($TargetUserName, $ScriptBlock, $ArgumentObject) }
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\RegistryPathHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-RegFileOperations.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\ApplyRegistryRegFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\RestoreRegistryApplyState.ps1')
}

Describe 'Convert-RegOperationToValueKind' {
    It 'converts <Case> to a registry-compatible value' -ForEach @(
        @{ Case = 'an unsigned DWord'; ValueName = $null; ValueType = 'DWord'; ValueData = [uint32]::MaxValue; ExpectedName = ''; ExpectedKind = [Microsoft.Win32.RegistryValueKind]::DWord; ExpectedValue = -1 }
        @{ Case = 'a string value'; ValueName = 'Name'; ValueType = 'String'; ValueData = 42; ExpectedName = 'Name'; ExpectedKind = [Microsoft.Win32.RegistryValueKind]::String; ExpectedValue = '42' }
        @{ Case = 'a binary value'; ValueName = 'Bytes'; ValueType = 'Binary'; ValueData = @(1, 255); ExpectedName = 'Bytes'; ExpectedKind = [Microsoft.Win32.RegistryValueKind]::Binary; ExpectedValue = [byte[]](1, 255) }
    ) {
        $result = Convert-RegOperationToValueKind -Operation ([PSCustomObject]@{
            KeyPath = 'HK'; ValueName = $ValueName; ValueType = $ValueType; ValueData = $ValueData
        })

        $result.Name | Should -Be $ExpectedName
        $result.Kind | Should -Be $ExpectedKind
        $result.Value | Should -Be $ExpectedValue
    }

    It 'throws for unsupported value types' {
        { Convert-RegOperationToValueKind -Operation ([PSCustomObject]@{ KeyPath = 'HKCU\X'; ValueType = 'Hex9'; ValueData = 1 }) } |
            Should -Throw "Unsupported value type 'Hex9' while applying reg operation for 'HKCU\X'"
    }
}

Describe 'Get-RegistryKeyForOperation validation' {
    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an unsupported path format'; RegistryPath = 'HKCU\Software\Example'; ExpectedError = 'Unsupported registry path:*' }
        @{ Case = 'an unsupported registry hive'; RegistryPath = 'HKEY_UNKNOWN\Software\Example'; ExpectedError = "Unsupported registry hive 'HKEY_UNKNOWN'*" }
    ) {
        { Get-RegistryKeyForOperation -RegistryPath $RegistryPath } | Should -Throw $ExpectedError
    }
}

Describe 'Invoke-RegistryOperation' {
    BeforeEach {
        Mock Get-RegistryKeyForOperation { [PSCustomObject]@{ RootKey = [Microsoft.Win32.Registry]::CurrentUser; SubKeyPath = 'Software\Example'; Key = 'key' } }
        Mock Remove-RegistrySubKeyTreeIfExists {}
        Mock Invoke-RegistryDeleteValueOperation {}
        Mock Invoke-RegistrySetValueOperation {}
    }

    It 'dispatches <Type> to <Expected>' -ForEach @(
        @{ Type = 'DeleteKey'; Expected = 'Remove-RegistrySubKeyTreeIfExists' }
        @{ Type = 'DeleteValue'; Expected = 'Invoke-RegistryDeleteValueOperation' }
        @{ Type = 'SetValue'; Expected = 'Invoke-RegistrySetValueOperation' }
    ) {
        $operation = [PSCustomObject]@{ OperationType = $Type; KeyPath = 'HKEY_CURRENT_USER\Software\Example'; ValueName = 'Value' }

        Invoke-RegistryOperation -Operation $operation -RegFilePath 'feature.reg'

        Should -Invoke $Expected -Times 1 -Exactly
    }

    It 'opens keys with create=<Create> and open=<Open> for <Type>' -ForEach @(
        @{ Type = 'DeleteKey'; Create = $false; Open = $false }
        @{ Type = 'DeleteValue'; Create = $false; Open = $true }
        @{ Type = 'SetValue'; Create = $true; Open = $true }
    ) {
        $operation = [PSCustomObject]@{ OperationType = $Type; KeyPath = 'HKEY_CURRENT_USER\Software\Example' }

        Invoke-RegistryOperation -Operation $operation -RegFilePath 'feature.reg'

        Should -Invoke Get-RegistryKeyForOperation -Times 1 -Exactly -ParameterFilter {
            [bool]$CreateIfMissing -eq $Create -and [bool]$OpenKey -eq $Open
        }
    }

    It 'rejects unknown operation types with file context' {
        $operation = [PSCustomObject]@{ OperationType = 'Unknown'; KeyPath = 'HKEY_CURRENT_USER\Software\Example' }
        { Invoke-RegistryOperation -Operation $operation -RegFilePath 'feature.reg' } |
            Should -Throw "Unsupported reg operation type 'Unknown' in 'feature.reg'"
    }
}

Describe 'Invoke-RegistryOperationsFromRegFile' {
    BeforeEach {
        $script:Params = @{}
        Mock Get-RegFileOperations { @([PSCustomObject]@{ OperationType = 'SetValue'; KeyPath = 'HKCU\One' }, [PSCustomObject]@{ OperationType = 'DeleteValue'; KeyPath = 'HKCU\Two' }) }
        Mock Invoke-RegistryOperation {}
        Mock Write-RegistryOperationAccessDeniedWarning {}
        Mock Write-Warning {}
        Mock Write-Host {}
    }

    It 'honors WhatIf without dispatching operations' {
        $script:Params = @{ WhatIf = $true }

        Invoke-RegistryOperationsFromRegFile -RegFilePath 'feature.reg'

        Should -Invoke Invoke-RegistryOperation -Times 0 -Exactly
    }

    It 'continues after one access-denied operation and emits a summary warning' {
        $script:calls = 0
        Mock Invoke-RegistryOperation {
            $script:calls++
            if ($script:calls -eq 1) { throw [System.UnauthorizedAccessException]::new('denied') }
        }

        { Invoke-RegistryOperationsFromRegFile -RegFilePath 'feature.reg' } | Should -Not -Throw
        Should -Invoke Write-RegistryOperationAccessDeniedWarning -Times 1 -Exactly
        Should -Invoke Write-Warning -Times 1 -Exactly
    }

    It 'throws when every operation is blocked by access restrictions' {
        Mock Invoke-RegistryOperation { throw [System.Security.SecurityException]::new('blocked') }

        { Invoke-RegistryOperationsFromRegFile -RegFilePath 'feature.reg' } |
            Should -Throw "Registry fallback import could not apply any operations in 'feature.reg' because all 2 operation(s) were blocked*"
    }
}

Describe 'Invoke-WithLoadedRestoreHive' {
    BeforeEach { Mock Invoke-WithTargetUserHive { param($TargetUserName) $TargetUserName } }

    It 'maps <Target> to <ExpectedUser>' -ForEach @(
        @{ Target = 'DefaultUserProfile'; ExpectedUser = 'Default' }
        @{ Target = 'User:Alice'; ExpectedUser = 'Alice' }
    ) {
        Invoke-WithLoadedRestoreHive -Target $Target -ScriptBlock {} | Should -Be $ExpectedUser
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an empty user target'; Target = 'User:'; ExpectedError = 'Invalid backup target format for user restore.' }
        @{ Case = 'a current-user target'; Target = 'CurrentUser:Alice'; ExpectedError = "Unsupported backup target 'CurrentUser:Alice'." }
    ) {
        { Invoke-WithLoadedRestoreHive -Target $Target -ScriptBlock {} } | Should -Throw $ExpectedError
    }
}

Describe 'Restore-RegistryKeySnapshot validation' {
    It 'rejects <Case> before registry mutation' -ForEach @(
        @{ Case = 'an unsupported snapshot path'; Path = 'HKCU\Software'; ExpectedError = 'Unsupported registry path in backup:*' }
        @{ Case = 'a root-level snapshot path'; Path = 'HKEY_CURRENT_USER'; ExpectedError = 'Unsupported root-level registry path in backup:*' }
    ) {
        { Restore-RegistryKeySnapshot -Snapshot ([PSCustomObject]@{ Path = $Path; Exists = $true }) } |
            Should -Throw $ExpectedError
    }
}
