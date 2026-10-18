BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Add-Parameter.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Windows-BuildHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Import-ConfigToParams.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Test-ConfigConsistency.ps1')
    $script:ConfigFixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading\ExportedConfig.WithSettings.json'
    $script:SkipRegistryBackupFixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading\ExportedConfig.SkipRegistryBackup.json'
    $script:LanguagesPath = Join-Path $PSScriptRoot '..\Config\Languages'
    $script:Lang = Import-LanguageFile -LanguageCode 'en-US'
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

    It 'reports an error for malformed tweak entries' {
        $config = [PSCustomObject]@{ Version = '1.0'; Tweaks = @(@{ Value = $true }) }

        Test-ConfigConsistency -Config $config | Should -Match 'Tweaks entries must contain Name and Value properties'
    }

    It 'reports an error for deployment entries missing a required property' {
        $config = [PSCustomObject]@{ Version = '1.0'; Deployment = @(@{ Name = 'CreateRestorePoint' }) }

        Test-ConfigConsistency -Config $config | Should -Match 'Deployment entries must contain Name and Value properties'
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

Describe 'ConvertTo-ConfigBoolean' {
    It 'returns <Expected> for the <Type> value <Text>' -ForEach @(
        @{ Type = 'boolean'; Text = 'true'; Value = $true; Expected = $true }
        @{ Type = 'boolean'; Text = 'false'; Value = $false; Expected = $false }
        @{ Type = 'string'; Text = 'true'; Value = 'true'; Expected = $true }
        @{ Type = 'string'; Text = 'True'; Value = 'True'; Expected = $true }
        @{ Type = 'string'; Text = 'false'; Value = 'false'; Expected = $false }
        @{ Type = 'string'; Text = 'FALSE'; Value = 'FALSE'; Expected = $false }
        @{ Type = 'string'; Text = 'false with spaces'; Value = ' false '; Expected = $false }
        @{ Type = 'number'; Text = '1'; Value = 1; Expected = $true }
        @{ Type = 'number'; Text = '0'; Value = 0; Expected = $false }
        @{ Type = 'decimal'; Text = '1.0'; Value = [decimal]1.0; Expected = $true }
        @{ Type = 'decimal'; Text = '0.0'; Value = [decimal]0.0; Expected = $false }
        @{ Type = 'double'; Text = '1e0'; Value = [double]1; Expected = $true }
        @{ Type = 'double'; Text = '0e0'; Value = [double]0; Expected = $false }
    ) {
        ConvertTo-ConfigBoolean $Value | Should -Be $Expected
    }

    It 'returns nothing for the <Type> value <Text>' -ForEach @(
        @{ Type = 'string'; Text = '0'; Value = '0' }
        @{ Type = 'string'; Text = 'yes'; Value = 'yes' }
        @{ Type = 'string'; Text = 'empty'; Value = '' }
        @{ Type = 'number'; Text = '2'; Value = 2 }
        @{ Type = 'decimal'; Text = '1.5'; Value = [decimal]1.5 }
        @{ Type = 'double'; Text = '0.5'; Value = [double]0.5 }
        @{ Type = 'null'; Text = 'null'; Value = $null }
        @{ Type = 'array'; Text = 'an array'; Value = @($true) }
    ) {
        ConvertTo-ConfigBoolean $Value | Should -BeNullOrEmpty
    }
}

Describe 'Import-ConfigToParams deployment flags' {
    BeforeEach {
        $script:Params = @{}
        $script:ModernStandbySupported = $false
        # A config that imports nothing is rejected, so every config below also selects one real tweak.
        $script:Features = @{ DisableTelemetry = [PSCustomObject]@{ FeatureId = 'DisableTelemetry'; MinVersion = $null; MaxVersion = $null } }
        $warnings = [System.Collections.Generic.List[string]]::new()
        Mock Write-Warning { $warnings.Add([string]$Message) }
    }

    BeforeAll {
        # Writes a config with the given JSON text for the three deployment flags and imports it.
        function Import-DeploymentFlags {
            param([string]$CreateRestorePoint, [string]$SkipRegistryBackup, [string]$RestartExplorer)

            $entries = @()
            if ($CreateRestorePoint) { $entries += '{ "Name": "CreateRestorePoint", "Value": ' + $CreateRestorePoint + ' }' }
            if ($SkipRegistryBackup) { $entries += '{ "Name": "SkipRegistryBackup", "Value": ' + $SkipRegistryBackup + ' }' }
            if ($RestartExplorer) { $entries += '{ "Name": "RestartExplorer", "Value": ' + $RestartExplorer + ' }' }
            $path = Join-Path $TestDrive 'flags.json'
            Set-Content -LiteralPath $path -Value ('{ "Version": "1.0", "Tweaks": [ { "Name": "DisableTelemetry", "Value": true } ], "Deployment": [ ' + ($entries -join ', ') + ' ] }') -Encoding UTF8

            Import-ConfigToParams -ConfigPath $path -CurrentBuild 22631 | Out-Null
        }
    }

    It 'does not turn on <Flag> when the value is the text false' -ForEach @(
        @{ Flag = 'CreateRestorePoint'; Arguments = @{ CreateRestorePoint = '"false"' } }
        @{ Flag = 'SkipRegistryBackup'; Arguments = @{ SkipRegistryBackup = '"false"' } }
        @{ Flag = 'SkipRegistryBackup'; Arguments = @{ SkipRegistryBackup = '"False"' } }
    ) {
        Import-DeploymentFlags @Arguments

        $script:Params.ContainsKey($Flag) | Should -BeFalse
        $warnings | Should -HaveCount 0
    }

    It 'turns on <Flag> for the text true and for a real boolean' -ForEach @(
        @{ Flag = 'CreateRestorePoint'; Arguments = @{ CreateRestorePoint = '"true"' } }
        @{ Flag = 'CreateRestorePoint'; Arguments = @{ CreateRestorePoint = 'true' } }
        @{ Flag = 'CreateRestorePoint'; Arguments = @{ CreateRestorePoint = '1' } }
        @{ Flag = 'CreateRestorePoint'; Arguments = @{ CreateRestorePoint = '1.0' } }
        @{ Flag = 'SkipRegistryBackup'; Arguments = @{ SkipRegistryBackup = '1e0' } }
        @{ Flag = 'SkipRegistryBackup'; Arguments = @{ SkipRegistryBackup = '"True"' } }
        @{ Flag = 'SkipRegistryBackup'; Arguments = @{ SkipRegistryBackup = 'true' } }
    ) {
        Import-DeploymentFlags @Arguments

        $script:Params[$Flag] | Should -BeTrue
    }

    It 'skips the Explorer restart only when RestartExplorer is false (<Value>)' -ForEach @(
        @{ Value = 'false'; Expected = $true }
        @{ Value = '"false"'; Expected = $true }
        @{ Value = '"False"'; Expected = $true }
        @{ Value = '0'; Expected = $true }
        @{ Value = '0.0'; Expected = $true }
        @{ Value = '0e0'; Expected = $true }
        @{ Value = '1.0'; Expected = $false }
        @{ Value = 'true'; Expected = $false }
        @{ Value = '"true"'; Expected = $false }
    ) {
        Import-DeploymentFlags -RestartExplorer $Value

        $script:Params.ContainsKey('SkipExplorerRestart') | Should -Be $Expected
    }

    It 'ignores an unrecognised <Flag> value and says so' -ForEach @(
        @{ Flag = 'CreateRestorePoint'; Arguments = @{ CreateRestorePoint = '"yes"' } }
        @{ Flag = 'SkipRegistryBackup'; Arguments = @{ SkipRegistryBackup = '"0"' } }
        @{ Flag = 'RestartExplorer'; Arguments = @{ RestartExplorer = '"no"' } }
    ) {
        Import-DeploymentFlags @Arguments

        $script:Params.Keys | Where-Object { $_ -in 'CreateRestorePoint', 'SkipRegistryBackup', 'SkipExplorerRestart' } | Should -HaveCount 0
        $warnings | Should -HaveCount 1
        $warnings[0] | Should -BeLike "Ignoring deployment setting '$Flag'*expected true or false*"
    }
}

Describe 'Get-ConfigDeploymentFlag' {
    BeforeEach {
        $warnings = [System.Collections.Generic.List[string]]::new()
        Mock Write-Warning { $warnings.Add([string]$Message) }
    }

    It 'returns nothing and does not warn when the setting is missing' {
        Get-ConfigDeploymentFlag -Lookup @{ Other = $true } -Name 'SkipRegistryBackup' | Should -BeNullOrEmpty
        $warnings | Should -HaveCount 0
    }

    It 'returns <Expected> for the value <Text> without a warning' -ForEach @(
        @{ Text = 'true'; Value = $true; Expected = $true }
        @{ Text = 'false'; Value = $false; Expected = $false }
        @{ Text = '"false"'; Value = 'false'; Expected = $false }
        @{ Text = '1.0'; Value = [decimal]1.0; Expected = $true }
    ) {
        Get-ConfigDeploymentFlag -Lookup @{ SkipRegistryBackup = $Value } -Name 'SkipRegistryBackup' | Should -Be $Expected
        $warnings | Should -HaveCount 0
    }

    It 'returns nothing and warns with the name and the value for an unsupported value' {
        Get-ConfigDeploymentFlag -Lookup @{ SkipRegistryBackup = 'yes' } -Name 'SkipRegistryBackup' | Should -BeNullOrEmpty

        $warnings | Should -HaveCount 1
        $warnings[0] | Should -BeLike "Ignoring deployment setting 'SkipRegistryBackup'*expected true or false, found 'yes'*"
    }
}
