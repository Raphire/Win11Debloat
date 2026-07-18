BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\MainWindow-Deployment.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\Get-SystemUsesDarkMode.ps1')
}

Describe 'Get-UndoFeatureLabel' {
    BeforeEach {
        $script:UndoFeatureLabelLookup = @{ DisableTelemetry = 'Enable telemetry' }
        $script:FeatureLabelLookup = @{ DisableTelemetry = 'Disable telemetry'; DisableWidgets = 'Disable widgets' }
    }

    It 'prefers undo labels and falls back to feature labels' {
        Get-UndoFeatureLabel -FeatureId 'DisableTelemetry' | Should -Be 'Enable telemetry'
        Get-UndoFeatureLabel -FeatureId 'DisableWidgets' | Should -Be 'Disable widgets'
    }

    It 'reads selected app IDs from string or array settings and removes blanks' {
        $stringSettings = [PSCustomObject]@{ Settings = @([PSCustomObject]@{ Name = 'Apps'; Value = ' One.App, ,Two.App ' }) }
        $arraySettings = [PSCustomObject]@{ Settings = @([PSCustomObject]@{ Name = 'Apps'; Value = @(' One.App ', '', 'Two.App') }) }

        Get-SavedAppIdsFromSettingsJson -SettingsJson $stringSettings | Should -Be @('One.App', 'Two.App')
        Get-SavedAppIdsFromSettingsJson -SettingsJson $arraySettings | Should -Be @('One.App', 'Two.App')
        Get-SavedAppIdsFromSettingsJson -SettingsJson ([PSCustomObject]@{ Settings = @() }) | Should -BeNullOrEmpty
    }

    It 'returns the AppsUseLightTheme registry preference and fails closed' {
        Mock Get-ItemProperty { [PSCustomObject]@{ AppsUseLightTheme = 0 } }
        Get-SystemUsesDarkMode | Should -BeTrue

        Mock Get-ItemProperty { throw 'Registry unavailable' }
        Get-SystemUsesDarkMode | Should -BeFalse
    }
}
