BeforeAll {
    $registryPathHelperScriptPath = Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1'
    $validationScriptPath = Join-Path $PSScriptRoot '..\Scripts\Features\Registry-BackupValidation.ps1'

    . $registryPathHelperScriptPath
    . $validationScriptPath
}

Describe 'Get-NormalizedSelectedFeatureIdsFromBackup' {
    It 'returns distinct feature IDs without changing their first occurrence' {
        $backup = [PSCustomObject]@{
            SelectedFeatures = @('DisableTelemetry', 'disabletelemetry', 'DisableCopilot')
        }

        $result = Get-NormalizedSelectedFeatureIdsFromBackup -Backup $backup

        $result.Errors | Should -BeNullOrEmpty
        $result.SelectedFeatures | Should -Be @('DisableTelemetry', 'DisableCopilot')
    }

    It 'reports missing SelectedFeatures' {
        $result = Get-NormalizedSelectedFeatureIdsFromBackup -Backup ([PSCustomObject]@{})

        $result.SelectedFeatures | Should -BeNullOrEmpty
        $result.Errors | Should -Contain 'Missing property: SelectedFeatures'
    }

    It 'reports non-string and empty feature IDs' {
        $backup = [PSCustomObject]@{
            SelectedFeatures = @('DisableTelemetry', '', 42, $null)
        }

        $result = Get-NormalizedSelectedFeatureIdsFromBackup -Backup $backup

        $result.SelectedFeatures | Should -Be 'DisableTelemetry'
        $result.Errors | Should -Contain 'SelectedFeatures must contain non-empty string feature IDs.'
    }
}

Describe 'Get-NormalizedSelectedUndoFeatureIdsFromBackup' {
    It 'allows backups created before SelectedUndoFeatures was introduced' {
        $result = Get-NormalizedSelectedUndoFeatureIdsFromBackup -Backup ([PSCustomObject]@{})

        $result.SelectedUndoFeatures | Should -BeNullOrEmpty
        $result.Errors | Should -BeNullOrEmpty
    }

    It 'deduplicates undo feature IDs case-insensitively' {
        $backup = [PSCustomObject]@{
            SelectedUndoFeatures = @('EnableTelemetry', 'enabletelemetry')
        }

        $result = Get-NormalizedSelectedUndoFeatureIdsFromBackup -Backup $backup

        $result.Errors | Should -BeNullOrEmpty
        $result.SelectedUndoFeatures | Should -Be 'EnableTelemetry'
    }
}

Describe 'Get-SelectedRegistryFeaturesForBackupValidation' {
    BeforeEach {
        $script:Features = @{
            ApplyFeature = [PSCustomObject]@{ Id = 'ApplyFeature'; RegistryKey = 'ApplyFeature.reg' }
            UndoFeature = [PSCustomObject]@{ Id = 'UndoFeature'; RegistryKey = 'UndoFeature.reg'; RegistryUndoKey = 'UndoFeature.undo.reg' }
            FallbackUndoFeature = [PSCustomObject]@{ Id = 'FallbackUndoFeature'; RegistryKey = 'FallbackUndoFeature.reg'; RegistryUndoKey = '' }
            CustomFeature = [PSCustomObject]@{ Id = 'CustomFeature'; RegistryKey = '' }
        }
    }

    It 'creates a case-insensitive registry value-name set' {
        $valueNames = ConvertTo-RegistryValueNameSet -ValueNames @('Enabled', 'enabled', 'Mode')

        $valueNames.Count | Should -Be 2
        $valueNames.Contains('ENABLED') | Should -BeTrue
        $valueNames.Contains('mode') | Should -BeTrue
    }

    It 'selects registry-backed apply features and reports unknown IDs' {
        $errors = New-Object System.Collections.Generic.List[string]

        $result = @(Get-SelectedRegistryFeaturesForBackupValidation -SelectedFeatureIds @('ApplyFeature', 'CustomFeature', 'MissingFeature') -IsUndoFeature:$false -Errors $errors)

        $result.Id | Should -Be 'ApplyFeature'
        $errors | Should -Contain "Selected feature 'MissingFeature' was not found in the current feature catalog."
    }

    It 'uses undo registry keys and falls back to apply keys when needed' {
        $errors = New-Object System.Collections.Generic.List[string]

        $result = @(Get-SelectedRegistryFeaturesForBackupValidation -SelectedFeatureIds @('UndoFeature', 'FallbackUndoFeature') -IsUndoFeature:$true -Errors $errors)

        $result.Id | Should -Be @('UndoFeature', 'FallbackUndoFeature')
        $errors | Should -BeNullOrEmpty
    }
}

Describe 'Test-RegistryValueKindNameSupported' {
    It 'accepts supported registry value kind <KindName>' -ForEach @(
        @{ KindName = 'dword' }
        @{ KindName = 'QWord' }
        @{ KindName = 'MultiString' }
    ) {
        Test-RegistryValueKindNameSupported -KindName $KindName | Should -BeTrue
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'a null kind name'; KindName = $null }
        @{ Case = 'an empty kind name'; KindName = '' }
        @{ Case = 'the Unknown registry kind'; KindName = 'Unknown' }
        @{ Case = 'the unsupported None registry kind'; KindName = 'None' }
        @{ Case = 'an invalid registry kind name'; KindName = 'NotARegistryValueKind' }
    ) {
        Test-RegistryValueKindNameSupported -KindName $KindName | Should -BeFalse
    }
}

Describe 'Test-RegistryValueDataMatchesKind' {
    It 'accepts <Case>' -ForEach @(
        @{ Case = 'the largest DWord'; Kind = 'DWord'; Data = [uint32]::MaxValue }
        @{ Case = 'the largest QWord'; Kind = 'QWord'; Data = [uint64]::MaxValue }
        @{ Case = 'non-empty Binary bytes'; Kind = 'Binary'; Data = @(0, 255) }
        @{ Case = 'empty Binary bytes'; Kind = 'Binary'; Data = [byte[]]::new(0) }
        @{ Case = 'a string array'; Kind = 'MultiString'; Data = @('one', 'two') }
    ) {
        Test-RegistryValueDataMatchesKind -KindName $Kind -Data $Data | Should -BeTrue
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an overflowing DWord'; Kind = 'DWord'; Data = '4294967296' }
        @{ Case = 'a negative QWord'; Kind = 'QWord'; Data = -1 }
        @{ Case = 'null Binary data'; Kind = 'Binary'; Data = $null }
        @{ Case = 'an invalid binary byte'; Kind = 'Binary'; Data = @(0, 256) }
        @{ Case = 'an object in a MultiString'; Kind = 'MultiString'; Data = @('one', [PSCustomObject]@{}) }
    ) {
        Test-RegistryValueDataMatchesKind -KindName $Kind -Data $Data | Should -BeFalse
    }
}

Describe 'Get-NormalizedRegistryValueName' {
    It 'normalizes a null value name to the default registry value' {
        Get-NormalizedRegistryValueName -ValueName $null | Should -Be ''
        Get-RegistryValueReferenceForError -SnapshotPath 'HKEY_CURRENT_USER\Software\Example' -ValueName '' |
            Should -Be 'HKEY_CURRENT_USER\Software\Example\\(Default)'
    }

    It 'keeps a named registry value in the error reference' {
        Get-RegistryValueReferenceForError -SnapshotPath 'HKEY_CURRENT_USER\Software\Example' -ValueName 'Setting' |
            Should -Be 'HKEY_CURRENT_USER\Software\Example\\Setting'
    }
}

Describe 'Normalize-RegistryKeySnapshot' {
    It 'normalizes nested snapshots and supplies value defaults' {
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Example'
            Exists = $true
            Values = @(
                [PSCustomObject]@{ Name = 'Enabled'; Kind = 'DWord'; Data = 1 }
                [PSCustomObject]@{ Name = 'Removed'; Exists = $false }
            )
            SubKeys = @(
                [PSCustomObject]@{
                    Path = 'HKEY_CURRENT_USER\Software\Example\Child'
                    Exists = $true
                }
            )
        }

        $result = Normalize-RegistryKeySnapshot -Snapshot $snapshot

        $result.Path | Should -Be 'HKEY_CURRENT_USER\Software\Example'
        $result.Exists | Should -BeTrue
        $result.Values.Count | Should -Be 2
        $result.Values[0].Exists | Should -BeTrue
        $result.Values[0].Kind | Should -Be 'DWord'
        $result.Values[1].Exists | Should -BeFalse
        $result.Values[1].Kind | Should -BeNullOrEmpty
        $result.Values[1].Data | Should -BeNullOrEmpty
        $result.SubKeys[0].Path | Should -Be 'HKEY_CURRENT_USER\Software\Example\Child'
        $result.SubKeys[0].Values | Should -BeNullOrEmpty
    }

    It 'rejects a snapshot without a registry path' {
        { Normalize-RegistryKeySnapshot -Snapshot ([PSCustomObject]@{ Exists = $true }) } |
            Should -Throw 'Backup validation failed: Registry key snapshot is missing Path.'
    }
}

Describe 'Test-RegistrySnapshotAgainstAllowList' {
    It 'normalizes path separators and hive casing' {
        Get-NormalizedRegistryPathKey -Path 'hkey_current_user/Software/Example/' |
            Should -Match '^HKEY_CURRENT_USER\\+Software\\Example$'
    }

    It 'matches configured value names case-insensitively' {
        $planMap = New-RegistryBackupAllowListPlanMap -CapturePlans @(
            [PSCustomObject]@{
                Path = 'HKEY_CURRENT_USER\Software\Example'
                IncludeSubKeys = $false
                CaptureAllValues = $false
                ValueNames = @('Enabled')
            }
        )
        $planMatch = Find-RegistryAllowListPlanMatch -NormalizedPath (Get-NormalizedRegistryPathKey -Path 'HKEY_CURRENT_USER\Software\Example') -PlanMap $planMap

        Test-RegistryValueAllowedByPlan -PlanMatch $planMatch -ValueName 'enabled' | Should -BeTrue
        Test-RegistryValueAllowedByPlan -PlanMatch $planMatch -ValueName 'Unexpected' | Should -BeFalse
    }

    It 'allows configured values at an exact path' {
        $planMap = New-RegistryBackupAllowListPlanMap -CapturePlans @(
            [PSCustomObject]@{
                Path = 'HKEY_CURRENT_USER\Software\Example'
                IncludeSubKeys = $false
                CaptureAllValues = $false
                ValueNames = @('Enabled')
            }
        )
        $errors = New-Object 'System.Collections.Generic.List[string]'
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Example'
            Values = @([PSCustomObject]@{ Name = 'Enabled'; Exists = $true; Kind = 'DWord'; Data = 1 })
            SubKeys = @()
        }

        Test-RegistrySnapshotAgainstAllowList -Snapshot $snapshot -PlanMap $planMap -Errors $errors

        $errors | Should -BeNullOrEmpty
    }

    It 'rejects corrupt value data even when its path and kind are allowed' {
        $planMap = New-RegistryBackupAllowListPlanMap -CapturePlans @(
            [PSCustomObject]@{
                Path = 'HKEY_CURRENT_USER\Software\Example'
                IncludeSubKeys = $false
                CaptureAllValues = $false
                ValueNames = @('Bytes')
            }
        )
        $errors = New-Object 'System.Collections.Generic.List[string]'
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Example'
            Values = @([PSCustomObject]@{ Name = 'Bytes'; Exists = $true; Kind = 'Binary'; Data = @(1, 256) })
            SubKeys = @()
        }

        Test-RegistrySnapshotAgainstAllowList -Snapshot $snapshot -PlanMap $planMap -Errors $errors

        $errors | Should -HaveCount 1
        $errors[0] | Should -BeLike "Backup contains invalid registry data for kind 'Binary'*"
    }

    It 'allows all values in descendants of a recursive plan' {
        $planMap = New-RegistryBackupAllowListPlanMap -CapturePlans @(
            [PSCustomObject]@{
                Path = 'HKEY_CURRENT_USER\Software\Example'
                IncludeSubKeys = $true
                CaptureAllValues = $true
                ValueNames = @()
            }
        )
        $errors = New-Object 'System.Collections.Generic.List[string]'
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Example\Child'
            Values = @([PSCustomObject]@{ Name = 'Unlisted'; Exists = $true; Kind = 'String'; Data = 'value' })
            SubKeys = @()
        }

        Test-RegistrySnapshotAgainstAllowList -Snapshot $snapshot -PlanMap $planMap -Errors $errors

        $errors | Should -BeNullOrEmpty
    }

    It 'reports unexpected paths and values' {
        $planMap = New-RegistryBackupAllowListPlanMap -CapturePlans @(
            [PSCustomObject]@{
                Path = 'HKEY_CURRENT_USER\Software\Example'
                IncludeSubKeys = $false
                CaptureAllValues = $false
                ValueNames = @('Enabled')
            }
        )
        $errors = New-Object 'System.Collections.Generic.List[string]'
        $unexpectedPathSnapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Unexpected'
            Values = @()
            SubKeys = @()
        }
        $unexpectedValueSnapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Example'
            Values = @([PSCustomObject]@{ Name = 'Unexpected'; Exists = $true; Kind = 'String'; Data = 'value' })
            SubKeys = @()
        }

        Test-RegistrySnapshotAgainstAllowList -Snapshot $unexpectedPathSnapshot -PlanMap $planMap -Errors $errors
        Test-RegistrySnapshotAgainstAllowList -Snapshot $unexpectedValueSnapshot -PlanMap $planMap -Errors $errors

        $errors | Should -Contain "Backup contains unexpected registry path 'HKEY_CURRENT_USER\Software\Unexpected' that is not allowed by SelectedFeatures."
        $errors | Should -Contain "Backup contains unexpected value 'Unexpected' under 'HKEY_CURRENT_USER\Software\Example'."
    }
}
