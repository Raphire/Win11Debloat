BeforeAll {
    $loadJsonFileScriptPath = Join-Path $PSScriptRoot '..\Scripts\FileIO\LoadJsonFile.ps1'
    $script:FixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading'
    . $loadJsonFileScriptPath
}

Describe 'LoadJsonFile' {
    BeforeEach {
        Mock Write-Error {}
    }

    It 'loads valid JSON with the expected version' {
        $result = LoadJsonFile -filePath (Join-Path $script:FixturePath 'Config.Valid.json') -expectedVersion '1.0'

        $result.Name | Should -Be 'Example configuration'
    }

    It 'parses the <Kind> settings fixture' -ForEach @(
        @{ Kind = 'default'; FileName = 'DefaultSettings.Valid.json' }
        @{ Kind = 'last-used'; FileName = 'LastUsedSettings.Valid.json' }
    ) {
        $result = LoadJsonFile -filePath (Join-Path $script:FixturePath $FileName) -expectedVersion '1.0'

        $result.Settings | Should -Not -BeNullOrEmpty
        $result.Settings[0].Name | Should -Be 'Supported'
    }

    It 'returns null and reports an error for <Case>' -ForEach @(
        @{ Case = 'a version mismatch'; FileName = 'Config.VersionMismatch.json'; ExpectedVersion = '1.0'; Optional = $false; Error = 'version mismatch' }
        @{ Case = 'invalid JSON'; FileName = 'Config.Invalid.json'; ExpectedVersion = $null; Optional = $false; Error = 'Failed to parse JSON file' }
    ) {
        $filePath = Join-Path $script:FixturePath $FileName
        $result = LoadJsonFile -filePath $filePath -expectedVersion $ExpectedVersion -optionalFile:$Optional

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter { $Message -match $Error }
    }

    It 'returns null without an error for an optional missing last-used settings file' {
        $result = LoadJsonFile -filePath (Join-Path $TestDrive 'LastUsedSettings.json') -expectedVersion '1.0' -optionalFile

        $result | Should -BeNullOrEmpty
        Should -Invoke Write-Error -Times 0 -Exactly
    }
}
