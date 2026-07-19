BeforeAll {
    $regFileOperationsScriptPath = Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-RegFileOperations.ps1'
    . $regFileOperationsScriptPath
}

Describe 'Convert-RegValueData' {
    It 'parses <ValueType> as an unsigned integer' -ForEach @(
        @{ ValueType = 'DWord'; ValueData = 'dword:ffffffff'; Expected = [uint32]::MaxValue }
        @{ ValueType = 'QWord'; ValueData = 'qword:ffffffffffffffff'; Expected = [uint64]::MaxValue }
    ) {
        $result = Convert-RegValueData -valueData $ValueData

        $result.OperationType | Should -Be 'SetValue'
        $result.ValueType | Should -Be $ValueType
        $result.ValueData | Should -Be $Expected
    }

    It 'parses registry strings and unescapes quotes and backslashes' {
        $result = Convert-RegValueData -valueData '"C:\\Tools\\\"Quoted\""'

        $result.ValueType | Should -Be 'String'
        $result.ValueData | Should -Be 'C:\Tools\"Quoted"'
    }

    It 'parses <Case>' -ForEach @(
        @{ Case = 'binary hex data'; ValueData = 'hex:01,ff'; ExpectedType = 'Binary'; Expected = [byte[]](1, 255) }
        @{ Case = 'expandable-string hex data'; ValueData = 'hex(2):25,00,54,00,45,00,4d,00,50,00,25,00,00,00'; ExpectedType = 'Hex2'; Expected = '%TEMP%' }
        @{ Case = 'multi-string hex data'; ValueData = 'hex(7):6f,00,6e,00,65,00,00,00,74,00,77,00,6f,00,00,00,00,00'; ExpectedType = 'Hex7'; Expected = @('one', 'two') }
    ) {
        $result = Convert-RegValueData -valueData $ValueData

        $result.ValueType | Should -Be $ExpectedType
        $result.ValueData | Should -Be $Expected
    }

    It '<Case>' -ForEach @(
        @{ Case = 'parses a registry value deletion'; ValueData = '-'; ExpectedOperation = 'DeleteValue' }
        @{ Case = 'ignores unsupported data'; ValueData = 'hex(b):not-hex'; ExpectedOperation = $null }
        @{ Case = 'rejects hex data with an empty byte token'; ValueData = 'hex:01,,ff'; ExpectedOperation = $null }
    ) {
        $result = Convert-RegValueData -valueData $ValueData
        if ($ExpectedOperation) {
            $result.OperationType | Should -Be $ExpectedOperation
            $result.ValueType | Should -BeNullOrEmpty
        }
        else {
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Convert-HexStringToByteArray' {
    It 'rejects empty and malformed hex tokens' -ForEach @('01,,ff', ',01', '01,', '01,gg') {
        Convert-HexStringToByteArray -hexValue $_ | Should -BeNullOrEmpty
    }

    It 'converts byte arrays to registry strings and multi-strings' {
        Convert-RegistryByteArrayToString -byteData ([byte[]](65, 0, 0, 0)) | Should -Be 'A'
        Convert-RegistryByteArrayToMultiString -byteData ([byte[]](65, 0, 0, 0, 66, 0, 0, 0, 0, 0)) | Should -Be @('A', 'B')
    }
}

Describe 'Get-RegFileOperations' {
    It 'warns when it skips malformed registry value data' {
        $regFilePath = Join-Path $TestDrive 'malformed.reg'
        @'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Example]
"Broken"=hex:01,,ff
'@ | Set-Content -LiteralPath $regFilePath -Encoding UTF8

        Mock Write-Warning {}
        @(Get-RegFileOperations -regFilePath $regFilePath) | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "Skipping unsupported or malformed registry value 'Broken'*" }
    }

    It 'parses key deletion, value deletion, and continued hex values' {
        $regFilePath = Join-Path $TestDrive 'settings.reg'
        @'
Windows Registry Editor Version 5.00

[-HKEY_CURRENT_USER\Software\Example\Removed]

[HKEY_CURRENT_USER\Software\Example]
"Enabled"=dword:00000001
@=-
"Bytes"=hex:01,\
  02,03
'@ | Set-Content -LiteralPath $regFilePath -Encoding UTF8

        $operations = @(Get-RegFileOperations -regFilePath $regFilePath)

        $operations.Count | Should -Be 4
        $operations[0].OperationType | Should -Be 'DeleteKey'
        $operations[1].ValueName | Should -Be 'Enabled'
        $operations[1].ValueData | Should -Be 1
        $operations[2].OperationType | Should -Be 'DeleteValue'
        $operations[2].ValueName | Should -Be ''
        $operations[3].ValueData | Should -Be ([byte[]](1, 2, 3))
    }

    It 'handles comments, default-value assignment, malformed lines, and deleted-key contents' {
        $regFilePath = Join-Path $TestDrive 'edge-cases.reg'
        @'
Windows Registry Editor Version 5.00
; comment

[HKEY_CURRENT_USER\Software\Example]
@="default"
malformed line

[-HKEY_CURRENT_USER\Software\Removed]
"Ignored"="value"
'@ | Set-Content -LiteralPath $regFilePath -Encoding UTF8

        $operations = @(Get-RegFileOperations -regFilePath $regFilePath)

        $operations | Should -HaveCount 2
        $operations[0].OperationType | Should -Be 'SetValue'
        $operations[0].ValueName | Should -Be ''
        $operations[0].ValueData | Should -Be 'default'
        $operations[1].OperationType | Should -Be 'DeleteKey'
    }

}
