BeforeAll {
    function Invoke-WithTargetUserHive { param($TargetUserName, $ScriptBlock, $ArgumentObject) }
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-RegFileOperations.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Apply-RegistryRegFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Restore-RegistryApplyState.ps1')
}

Describe 'Convert-RegOperationToValueKind' {
    It 'converts <Case> to a registry-compatible value' -ForEach @(
        @{ Case = 'an unsigned DWord'; ValueName = $null; ValueType = 'DWord'; ValueData = [uint32]::MaxValue; ExpectedName = ''; ExpectedKind = [Microsoft.Win32.RegistryValueKind]::DWord; ExpectedValue = -1 }
        @{ Case = 'an unsigned QWord'; ValueName = 'Big'; ValueType = 'QWord'; ValueData = [uint64]::MaxValue; ExpectedName = 'Big'; ExpectedKind = [Microsoft.Win32.RegistryValueKind]::QWord; ExpectedValue = -1L }
        @{ Case = 'a string value'; ValueName = 'Name'; ValueType = 'String'; ValueData = 42; ExpectedName = 'Name'; ExpectedKind = [Microsoft.Win32.RegistryValueKind]::String; ExpectedValue = '42' }
        @{ Case = 'an expandable string value'; ValueName = 'Path'; ValueType = 'Hex2'; ValueData = 'test%PATH%'; ExpectedName = 'Path'; ExpectedKind = [Microsoft.Win32.RegistryValueKind]::ExpandString; ExpectedValue = 'test%PATH%' }
        @{ Case = 'a binary value'; ValueName = 'Bytes'; ValueType = 'Binary'; ValueData = @(1, 255); ExpectedName = 'Bytes'; ExpectedKind = [Microsoft.Win32.RegistryValueKind]::Binary; ExpectedValue = [byte[]](1, 255) }
        @{ Case = 'a multi-string value'; ValueName = 'List'; ValueType = 'Hex7'; ValueData = @('a', 'b', 'c'); ExpectedName = 'List'; ExpectedKind = [Microsoft.Win32.RegistryValueKind]::MultiString; ExpectedValue = [string[]]@('a', 'b', 'c') }
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
            Should -Throw "对 'HKCU\X' 应用注册表操作时遇到不受支持的值类型 'Hex9'。"
    }
}

Describe 'Get-RegistryKeyForOperation' {
    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an unsupported path format'; RegistryPath = 'HKCU\Software\Example'; ExpectedError = '不支持的注册表路径：*' }
        @{ Case = 'an unsupported registry hive'; RegistryPath = 'HKEY_UNKNOWN\Software\Example'; ExpectedError = "*注册表配置单元 'HKEY_UNKNOWN' 不受支持。*" }
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
            Should -Throw "'feature.reg' 中的注册表操作类型 'Unknown' 不受支持。"
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
            Should -Throw "备用导入方式也无法应用 'feature.reg' 中的任何操作，全部 2 项操作均被访问权限限制阻止。*"
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
        @{ Case = 'an empty user target'; Target = 'User:'; ExpectedError = '用户恢复的备份目标格式无效。' }
        @{ Case = 'a current-user target'; Target = 'CurrentUser:Alice'; ExpectedError = "不支持的备份目标：'CurrentUser:Alice'。" }
    ) {
        { Invoke-WithLoadedRestoreHive -Target $Target -ScriptBlock {} } | Should -Throw $ExpectedError
    }
}

Describe 'Restore-RegistryKeySnapshot - validation' {
    It 'rejects <Case> before registry mutation' -ForEach @(
        @{ Case = 'an unsupported snapshot path'; Path = 'HKCU\Software'; ExpectedError = '备份中的注册表路径不受支持：*' }
        @{ Case = 'a root-level snapshot path'; Path = 'HKEY_CURRENT_USER'; ExpectedError = '备份中的根级注册表路径不受支持：*' }
    ) {
        { Restore-RegistryKeySnapshot -Snapshot ([PSCustomObject]@{ Path = $Path; Exists = $true }) } |
            Should -Throw $ExpectedError
    }
}

Describe 'Invoke-RegistryDeleteValueOperation' {
    It 'deletes the default value and always closes an opened registry key' {
        $calls = [System.Collections.Generic.List[string]]::new()
        $key = [PSCustomObject]@{}
        $key | Add-Member -MemberType ScriptMethod -Name DeleteValue -Value { param($Name, $ThrowOnMissing) $calls.Add("delete:${Name}:$ThrowOnMissing") }
        $key | Add-Member -MemberType ScriptMethod -Name Close -Value { $calls.Add('close') }

        Invoke-RegistryDeleteValueOperation -Operation ([PSCustomObject]@{ KeyPath = 'HKCU\Software\Test'; ValueName = $null }) -KeyInfo ([PSCustomObject]@{ Key = $key })

        $calls | Should -Be @('delete::False', 'close')
    }
}

Describe 'Invoke-RegistrySetValueOperation' {
    It 'throws for an unavailable set-value key before attempting conversion' {
        Mock Convert-RegOperationToValueKind { throw 'conversion should not run' }

        { Invoke-RegistrySetValueOperation -Operation ([PSCustomObject]@{ KeyPath = 'HKCU\Software\Test' }) -KeyInfo ([PSCustomObject]@{ Key = $null }) } |
            Should -Throw "无法打开或创建注册表项*"
        Should -Invoke Convert-RegOperationToValueKind -Times 0 -Exactly
    }
}

Describe 'Write-RegistryOperationAccessDeniedWarning' {
    It 'formats the default registry value in access-denied warnings' {
        Mock Write-Warning {}

        Write-RegistryOperationAccessDeniedWarning -Operation ([PSCustomObject]@{ OperationType = 'DeleteValue'; KeyPath = 'HKCU\Software\Test'; ValueName = $null }) -ExceptionMessage 'denied'

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match "值 '（默认）'" -and $Message -match 'denied' }
    }
}
