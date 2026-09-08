BeforeAll {
    $importJsonFileScriptPath = Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1'
    $script:FixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading'
    . $importJsonFileScriptPath
}

Describe 'Import-JsonFile' {
    BeforeEach {
        Mock Write-Error {}
    }

    It 'loads valid JSON with the expected version' {
        $result = Import-JsonFile -filePath (Join-Path $script:FixturePath 'Config.Valid.json') -expectedVersion '1.0'

        $result.Name | Should -Be 'Example configuration'
    }

    It 'parses the <Kind> settings fixture' -ForEach @(
        @{ Kind = 'default'; FileName = 'DefaultSettings.Valid.json' }
        @{ Kind = 'last-used'; FileName = 'LastUsedSettings.Valid.json' }
    ) {
        $result = Import-JsonFile -filePath (Join-Path $script:FixturePath $FileName) -expectedVersion '1.0'

        $result.Settings | Should -Not -BeNullOrEmpty
        $result.Settings[0].Name | Should -Be 'Supported'
    }

    It 'returns null and reports an error for <Case>' -ForEach @(
        @{ Case = 'a version mismatch'; FileName = 'Config.VersionMismatch.json'; ExpectedVersion = '1.0'; Optional = $false; Error = 'version mismatch' }
        @{ Case = 'invalid JSON'; FileName = 'Config.Invalid.json'; ExpectedVersion = $null; Optional = $false; Error = 'Failed to parse JSON file' }
    ) {
        $filePath = Join-Path $script:FixturePath $FileName
        $result = Import-JsonFile -filePath $filePath -expectedVersion $ExpectedVersion -optionalFile:$Optional

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter { $Message -match $Error }
    }

    It 'returns null without an error for an optional missing last-used settings file' {
        $result = Import-JsonFile -filePath (Join-Path $TestDrive 'LastUsedSettings.json') -expectedVersion '1.0' -optionalFile

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Error -Times 0 -Exactly
    }

    It 'reads non-ASCII characters correctly from a UTF-8 file with no BOM, regardless of the system default encoding' {
        # Unicode escapes here, not literal accented characters: this test file has no BOM, so
        # PowerShell 5.1 would decode literal non-ASCII source characters using the system default
        # codepage too, defeating the point of the assertion on a non-UTF-8-default machine.
        $expectedName = "Espa$([char]0x00F1)ol"
        $expectedNote = "caf$([char]0x00E9), na$([char]0x00EF)ve, $([char]0x00FC)ber"

        $result = Import-JsonFile -filePath (Join-Path $script:FixturePath 'Config.Utf8NoBom.json')

        $result.Name | Should -Be $expectedName
        $result.Note | Should -Be $expectedNote
    }
}
