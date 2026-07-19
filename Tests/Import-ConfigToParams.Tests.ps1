BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Add-Parameter.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Import-ConfigToParams.ps1')
    $script:ConfigFixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading\ExportedConfig.WithSettings.json'
}

Describe 'Import-ConfigToParams' {
    BeforeEach {
        $script:Params = @{}
        $script:ModernStandbySupported = $false
        $script:Features = @{}
        foreach ($featureId in @(
            'DisableSettings365Ads', 'DisableSnapAssist', 'EnableDarkMode', 'ShowSearchBoxTb',
            'DisableTelemetry', 'DisableWidgets', 'DisableLockscreenTips', 'DisableSnapLayouts',
            'DisableAISvcAutoStart', 'DisableMouseAcceleration', 'DisableCopilot', 'DisableRecall'
        )) {
            $script:Features[$featureId] = [PSCustomObject]@{ FeatureId = $featureId; MinVersion = $null; MaxVersion = $null }
        }
    }

    It 'loads the selected tweaks and deployment settings from an exported config file' {
        $result = Import-ConfigToParams -ConfigPath $script:ConfigFixturePath -CurrentBuild 22631

        $result | Should -Be (Resolve-Path -LiteralPath $script:ConfigFixturePath).Path
        foreach ($featureId in @(
            'DisableSettings365Ads', 'DisableSnapAssist', 'EnableDarkMode', 'ShowSearchBoxTb',
            'DisableTelemetry', 'DisableWidgets', 'DisableLockscreenTips', 'DisableSnapLayouts',
            'DisableAISvcAutoStart', 'DisableMouseAcceleration', 'DisableCopilot', 'DisableRecall'
        )) {
            $script:Params[$featureId] | Should -BeTrue
        }
        $script:Params['CreateRestorePoint'] | Should -BeTrue
        $script:Params.ContainsKey('SkipRegistryBackup') | Should -BeFalse
        $script:Params['SkipExplorerRestart'] | Should -BeTrue
        $script:Params.ContainsKey('User') | Should -BeFalse
        $script:Params.ContainsKey('AppRemovalTarget') | Should -BeFalse
    }
}
