BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\Restore-BackupDialogFeatureLists.ps1')
}

Describe 'New-RestoreDialogState' {
    BeforeEach {
        $script:Features = @{
            RegistryFeature = [PSCustomObject]@{ Label = 'Registry feature'; Category = 'Privacy'; RegistryKey = 'RegistryFeature.reg' }
            CustomFeature = [PSCustomObject]@{ Label = 'Custom feature'; Category = 'Privacy'; RegistryKey = '' }
            HiddenFeature = [PSCustomObject]@{ Label = 'Hidden feature'; Category = ''; RegistryKey = 'HiddenFeature.reg' }
        }
    }

    It 'creates a dialog state with the supplied values' {
        $backup = [PSCustomObject]@{ SelectedFeatures = @('RegistryFeature') }

        $state = New-RestoreDialogState -Result 'OK' -SelectedFile 'C:\Backups\backup.json' -Backup $backup

        $state.Result | Should -Be 'OK'
        $state.SelectedFile | Should -Be 'C:\Backups\backup.json'
        $state.Backup | Should -Be $backup
    }

    It 'looks up feature definitions and resolves display labels with fallbacks' {
        Get-RestoreDialogFeatureDefinition -FeatureId 'RegistryFeature' -Features $script:Features | Should -Be $script:Features.RegistryFeature
        Get-RestoreDialogFeatureDefinition -FeatureId 'MissingFeature' -Features $script:Features | Should -BeNullOrEmpty
        Get-RestoreDialogFeatureDisplayLabel -FeatureId 'RegistryFeature' -Features $script:Features | Should -Be 'Registry feature'
        Get-RestoreDialogFeatureDisplayLabel -FeatureId 'MissingFeature' -Features $script:Features | Should -Be 'MissingFeature'
        Get-RestoreDialogFeatureDisplayLabel -FeatureId '' -Features $script:Features | Should -Be 'Unknown feature'
    }

    It 'identifies visible, automatically revertible features' {
        Test-RestoreDialogFeatureCanAutoRevert -FeatureId 'RegistryFeature' -Features $script:Features | Should -BeTrue
        Test-RestoreDialogFeatureCanAutoRevert -FeatureId 'CustomFeature' -Features $script:Features | Should -BeFalse
        Test-RestoreDialogFeatureVisibleInOverview -FeatureId 'RegistryFeature' -Features $script:Features | Should -BeTrue
        Test-RestoreDialogFeatureVisibleInOverview -FeatureId 'HiddenFeature' -Features $script:Features | Should -BeFalse
    }

    It 'deduplicates and combines forward and undo feature IDs' {
        $backup = [PSCustomObject]@{
            SelectedFeatures = @('RegistryFeature', 'registryfeature', '', 'CustomFeature')
            SelectedUndoFeatures = @('CustomFeature', 'HiddenFeature', 'hiddenfeature')
        }

        Get-SelectedForwardFeatureIdsFromBackup -SelectedBackup $backup | Should -Be @('RegistryFeature', 'CustomFeature')
        Get-SelectedUndoFeatureIdsFromBackup -SelectedBackup $backup | Should -Be @('CustomFeature', 'HiddenFeature')
        Get-CombinedSelectedFeatureIdsFromBackup -SelectedBackup $backup | Should -Be @('RegistryFeature', 'CustomFeature', 'HiddenFeature')
        Get-SelectedFeatureIdsFromBackup -SelectedBackup $backup | Should -Be @('RegistryFeature', 'CustomFeature', 'HiddenFeature')
    }

    It 'separates visible feature labels into revertible and manual lists' {
        $lists = Get-RestoreBackupFeatureLists -SelectedFeatureIds @('RegistryFeature', 'CustomFeature', 'HiddenFeature', 'MissingFeature') -Features $script:Features

        $lists.Revertible.DisplayText | Should -Be '- Registry feature'
        $lists.NonRevertible.DisplayText | Should -Be '- Custom feature'
    }
}
