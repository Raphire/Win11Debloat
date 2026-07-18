BeforeAll {
    $registryPathHelperScriptPath = Join-Path $PSScriptRoot '..\Scripts\Helpers\RegistryPathHelpers.ps1'
    $validationScriptPath = Join-Path $PSScriptRoot '..\Scripts\Features\RegistryBackupValidation.ps1'

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
        @{ Case = 'an invalid registry kind name'; KindName = 'NotARegistryValueKind' }
    ) {
        Test-RegistryValueKindNameSupported -KindName $KindName | Should -BeFalse
    }
}

Describe 'Test-RegistryValueDataSupported' {
    It 'accepts <Case>' -ForEach @(
        @{ Case = 'the largest DWord'; Kind = 'DWord'; Data = [uint32]::MaxValue }
        @{ Case = 'the largest QWord'; Kind = 'QWord'; Data = [uint64]::MaxValue }
        @{ Case = 'valid binary bytes'; Kind = 'Binary'; Data = @(0, 255) }
        @{ Case = 'a string array'; Kind = 'MultiString'; Data = @('one', 'two') }
        @{ Case = 'null None data'; Kind = 'None'; Data = $null }
    ) {
        Test-RegistryValueDataSupported -KindName $Kind -Data $Data | Should -BeTrue
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'an overflowing DWord'; Kind = 'DWord'; Data = '4294967296' }
        @{ Case = 'a negative QWord'; Kind = 'QWord'; Data = -1 }
        @{ Case = 'an invalid binary byte'; Kind = 'Binary'; Data = @(0, 256) }
        @{ Case = 'an object in a MultiString'; Kind = 'MultiString'; Data = @('one', [PSCustomObject]@{}) }
        @{ Case = 'data for a None value'; Kind = 'None'; Data = 1 }
    ) {
        Test-RegistryValueDataSupported -KindName $Kind -Data $Data | Should -BeFalse
    }
}

Describe 'registry value name helpers' {
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

Describe 'registry path and allow-list helpers' {
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
