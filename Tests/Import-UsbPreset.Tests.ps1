BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Add-Parameter.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-AppsFromFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-AppDetailsFromJson.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Get-ValidatedAppList.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Import-UsbPreset.ps1')
    $script:ConfigPath = Join-Path $PSScriptRoot '..\Config'
    $script:LanguagesPath = Join-Path $script:ConfigPath 'Languages'
    $script:Lang = Import-LanguageFile -LanguageCode 'en-US'
}

Describe 'Import-UsbPreset' {
    BeforeEach {
        $script:Params = @{}
        $script:AppsListFilePath = Join-Path $script:ConfigPath 'Apps.json'
        $script:DefaultSettingsFilePath = Join-Path $script:ConfigPath 'DefaultSettings.json'
        $script:UsbPresetsFilePath = Join-Path $script:ConfigPath 'UsbPresets.json'
        $script:ModernStandbySupported = $false
        $featureData = Get-Content -LiteralPath (Join-Path $script:ConfigPath 'Features.json') -Raw | ConvertFrom-Json
        $script:Features = @{}
        foreach ($feature in $featureData.Features) {
            $script:Features[$feature.FeatureId] = $feature
        }
        Mock Get-ItemPropertyValue { 22631 }
        Mock Write-Host {}
        Mock Write-Warning {}
    }

    It 'loads current default settings and the exact default application list' {
        Import-UsbPreset -PresetName Normal | Out-Null
        $script:Params.CreateRestorePoint | Should -BeTrue
        $script:Params.DisableTelemetry | Should -BeTrue
        $script:Params.RemoveApps | Should -BeTrue
        $expectedApps = @(Import-AppsFromFile -appsFilePath $script:AppsListFilePath | Sort-Object -Unique)
        $script:Params.Apps | Should -Be ($expectedApps -join ',')
    }

    It 'adds aggressive settings and OEM apps without unsafe system switches' {
        Import-UsbPreset -PresetName Aggressive | Out-Null
        $script:Params.DisableNotifications | Should -BeTrue
        $script:Params.DisableStartRecommended | Should -BeTrue
        $script:Params.HideHome | Should -BeTrue
        @($script:Params.Apps -split ',') | Should -Contain 'DellInc.DellSupportAssistforPCs'
        foreach ($unsafeFeature in @('ForceRemoveEdge', 'DisableFastStartup', 'DisableBitlockerAutoEncryption')) {
            $script:Params.ContainsKey($unsafeFeature) | Should -BeFalse
        }
    }

    It 'preserves all Xbox and Gaming packages in the Gaming preset' {
        Import-UsbPreset -PresetName Gaming | Out-Null
        @($script:Params.Apps -split ',' | Where-Object { $_ -match '^Microsoft\.(Xbox|Gaming)' }) | Should -BeNullOrEmpty
        $script:Params.DisableDVR | Should -BeTrue
        $script:Params.DisableGameBarIntegration | Should -BeTrue
    }

    It 'never selects Store, Edge, Terminal or common daily-use apps in any preset' -ForEach @(
        @{ PresetName = 'Normal' }
        @{ PresetName = 'Aggressive' }
        @{ PresetName = 'Gaming' }
    ) {
        Import-UsbPreset -PresetName $PresetName | Out-Null
        foreach ($protectedId in @('Microsoft.WindowsStore', 'Microsoft.Edge', 'Microsoft.WindowsTerminal', 'Microsoft.WindowsCalculator', 'Microsoft.Windows.Photos', 'AD2F1837.HPSureShieldAI')) {
            @($script:Params.Apps -split ',') | Should -Not -Contain $protectedId
        }
    }

    It 'filters unsupported build ranges and Modern Standby settings' {
        $script:Features.DisableTelemetry.MinVersion = 99999
        $script:Features.DisableSuggestions | Add-Member -NotePropertyName MaxVersion -NotePropertyValue 22000 -Force
        Import-UsbPreset -PresetName Normal | Out-Null
        $script:Params.ContainsKey('DisableTelemetry') | Should -BeFalse
        $script:Params.ContainsKey('DisableSuggestions') | Should -BeFalse
        $script:Params.ContainsKey('DisableModernStandbyNetworking') | Should -BeFalse
    }

    It 'includes Modern Standby networking only when the hardware supports it' {
        $script:ModernStandbySupported = $true
        Import-UsbPreset -PresetName Normal | Out-Null
        $script:Params.DisableModernStandbyNetworking | Should -BeTrue
    }

    It 'rejects an unknown or prohibited feature before changing active parameters' -ForEach @(
        @{ FeatureName = 'NoSuchFeature' }
        @{ FeatureName = 'ForceRemoveEdge' }
        @{ FeatureName = 'DisableBitlockerAutoEncryption' }
        @{ FeatureName = 'RemoveGamingApps' }
    ) {
        $configuration = Get-Content -LiteralPath $script:UsbPresetsFilePath -Raw | ConvertFrom-Json
        $configuration.Presets.Aggressive.Settings += [PSCustomObject]@{ Name = $FeatureName; Value = $true }
        $script:UsbPresetsFilePath = Join-Path $TestDrive 'invalid-preset.json'
        $configuration | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:UsbPresetsFilePath
        { Import-UsbPreset -PresetName Aggressive } | Should -Throw
        $script:Params.Count | Should -Be 0
    }

    It 'rejects unsupported application IDs atomically' {
        Mock Get-ValidatedAppList { @() }
        { Import-UsbPreset -PresetName Normal } | Should -Throw '*unsupported application IDs*'
        $script:Params.Count | Should -Be 0
    }

    It 'rejects missing application data instead of silently skipping removal' {
        $script:AppsListFilePath = Join-Path $TestDrive 'missing.json'
        { Import-UsbPreset -PresetName Normal } | Should -Throw
        $script:Params.Count | Should -Be 0
    }

    It 'rejects an unsupported application preset atomically' {
        $configuration = Get-Content -LiteralPath $script:UsbPresetsFilePath -Raw | ConvertFrom-Json
        $configuration.Presets.Aggressive.AppPresets = @('Unknown OEM preset')
        $script:UsbPresetsFilePath = Join-Path $TestDrive 'invalid-app-preset.json'
        $configuration | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:UsbPresetsFilePath
        { Import-UsbPreset -PresetName Aggressive } | Should -Throw '*unknown application preset*'
        $script:Params.Count | Should -Be 0
    }
}
