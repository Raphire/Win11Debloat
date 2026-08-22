BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Add-Parameter.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Import-ConfigToParams.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Test-ConfigConsistency.ps1')
    $script:ConfigFixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading\ExportedConfig.WithSettings.json'
    $script:SkipRegistryBackupFixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading\ExportedConfig.SkipRegistryBackup.json'
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

    It 'imports SkipRegistryBackup when deployment settings request it' {
        Import-ConfigToParams -ConfigPath $script:SkipRegistryBackupFixturePath -CurrentBuild 22631 | Out-Null

        $script:Params['SkipRegistryBackup'] | Should -BeTrue
    }
}

Describe 'Test-ConfigConsistency' {
    It 'reports an error for an empty config' {
        Test-ConfigConsistency -Config $null | Should -Match 'empty or could not be read'
    }

    It 'reports an error for a config missing a Version' {
        $config = [PSCustomObject]@{ Tweaks = @( @{ Name = 'DisableTelemetry'; Value = $true } ) }
        Test-ConfigConsistency -Config $config | Should -Match 'missing a Version'
    }

    It 'reports an error for a config with no importable data' {
        $config = [PSCustomObject]@{ Version = '1.0' }
        Test-ConfigConsistency -Config $config | Should -Match 'no importable data'
    }

    It 'reports an error for invalid app entries' {
        $config = [PSCustomObject]@{ Version = '1.0'; Apps = 42 }

        Test-ConfigConsistency -Config $config | Should -Match 'Apps entries must be strings'
    }

    It 'reports an error for nonnumeric deployment indexes' {
        $config = [PSCustomObject]@{
            Version = '1.0'
            Deployment = @(@{ Name = 'AppRemovalScopeIndex'; Value = 'all' })
        }

        Test-ConfigConsistency -Config $config | Should -Match 'AppRemovalScopeIndex must be a supported numeric value'
    }

    It 'reports an error for out-of-range deployment indexes' {
        $config = [PSCustomObject]@{
            Version = '1.0'
            Deployment = @(@{ Name = 'UserSelectionIndex'; Value = 3 })
        }

        Test-ConfigConsistency -Config $config | Should -Match 'UserSelectionIndex must be a supported numeric value'
    }

    It 'returns null for a consistent all-users scope' {
        $config = [PSCustomObject]@{
            Version = '1.0'
            Deployment = @(
                @{ Name = 'UserSelectionIndex'; Value = 0 }
                @{ Name = 'AppRemovalScopeIndex'; Value = 0 }
            )
        }
        Test-ConfigConsistency -Config $config | Should -BeNullOrEmpty
    }

    It 'returns null for target-user scope combined with Other User and a username' {
        $config = [PSCustomObject]@{
            Version = '1.0'
            Deployment = @(
                @{ Name = 'UserSelectionIndex'; Value = 1 }
                @{ Name = 'OtherUsername'; Value = 'jdoe' }
                @{ Name = 'AppRemovalScopeIndex'; Value = 2 }
            )
        }
        Test-ConfigConsistency -Config $config | Should -BeNullOrEmpty
    }

    It 'returns null for current-user-only scope combined with Current User' {
        $config = [PSCustomObject]@{
            Version = '1.0'
            Deployment = @(
                @{ Name = 'UserSelectionIndex'; Value = 0 }
                @{ Name = 'AppRemovalScopeIndex'; Value = 1 }
            )
        }
        Test-ConfigConsistency -Config $config | Should -BeNullOrEmpty
    }

    It 'reports an error for current-user-only scope without Current User selected' {
        $config = [PSCustomObject]@{
            Version = '1.0'
            Deployment = @(
                @{ Name = 'UserSelectionIndex'; Value = 1 }
                @{ Name = 'AppRemovalScopeIndex'; Value = 1 }
            )
        }
        Test-ConfigConsistency -Config $config | Should -Match "requires the deployment target 'Current User'"
    }

    It 'reports an error for target-user scope without Other User selected' {
        $config = [PSCustomObject]@{
            Version = '1.0'
            Deployment = @(
                @{ Name = 'UserSelectionIndex'; Value = 0 }
                @{ Name = 'AppRemovalScopeIndex'; Value = 2 }
            )
        }
        Test-ConfigConsistency -Config $config | Should -Match "requires the deployment target 'Other User'"
    }

    It 'reports an error for target-user scope with a blank username' {
        $config = [PSCustomObject]@{
            Version = '1.0'
            Deployment = @(
                @{ Name = 'UserSelectionIndex'; Value = 1 }
                @{ Name = 'OtherUsername'; Value = '   ' }
                @{ Name = 'AppRemovalScopeIndex'; Value = 2 }
            )
        }
        Test-ConfigConsistency -Config $config | Should -Match "requires an 'OtherUsername' value"
    }
}
