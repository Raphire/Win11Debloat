BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-RegFileOperations.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\User-HiveHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Invoke-Changes.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Backup-RegistryFeatureSelection.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Save-ToFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Backup-RegistryState.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Backup-RegistrySnapshotCapture.ps1')
}

Describe 'Get-SelectedFeatures' {
    BeforeEach {
        $script:Features = @{
            First = [PSCustomObject]@{ FeatureId = 'One'; RegistryKey = 'one.reg' }
            Duplicate = [PSCustomObject]@{ FeatureId = 'one'; RegistryKey = 'duplicate.reg' }
            Empty = $null
        }
    }

    It 'keeps the first matching feature and ignores unknown, null, and duplicate keys' {
        $result = @(Get-SelectedFeatures -ActionableKeys @('missing', 'First', 'Duplicate', 'Empty'))

        $result | Should -HaveCount 1
        $result[0].RegistryKey | Should -Be 'one.reg'
    }
}

Describe 'Get-RegistryBackupPayload' {
    BeforeEach {
        Mock Get-RegistryBackedFeatures { param($Features) @($Features | Where-Object RegistryKey) }
        Mock Get-RegistryBackupCapturePlans { @([PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\Example' }) }
        Mock Get-RegistrySnapshotsForBackup { @([PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\Example'; Exists = $true }) }
        Mock Get-RegistryBackupTargetDescription { 'CurrentUser:Tester' }
        $env:COMPUTERNAME = 'TestComputer'
    }

    It 'builds a versioned payload and preserves distinct apply and undo IDs' {
        $apply = @([PSCustomObject]@{ FeatureId = 'One'; RegistryKey = 'one.reg' }, [PSCustomObject]@{ FeatureId = 'one'; RegistryKey = 'other.reg' })
        $undo = @([PSCustomObject]@{ FeatureId = 'UndoOne'; RegistryUndoKey = 'undo.reg' })

        $result = Get-RegistryBackupPayload -SelectedFeatures $apply -UndoFeatures $undo -CreatedAt ([datetime]'2026-01-02T03:04:05Z')

        $result.Version | Should -Be '1.0'
        $result.BackupType | Should -Be 'RegistryState'
        $result.Target | Should -Be 'CurrentUser:Tester'
        $result.SelectedFeatures | Should -Be 'One'
        $result.SelectedUndoFeatures | Should -Be 'UndoOne'
        $result.RegistryKeys | Should -HaveCount 1
    }

    It 'does not add SelectedUndoFeatures when no undo features were supplied' {
        $result = Get-RegistryBackupPayload -SelectedFeatures @() -UndoFeatures @() -CreatedAt (Get-Date)

        $result.ContainsKey('SelectedUndoFeatures') | Should -BeFalse
    }
}

Describe 'New-RegistrySettingsBackup' {
    BeforeEach {
        $script:RegistryBackupsPath = Join-Path $TestDrive 'Backups'
        $script:Features = @{ Feature = [PSCustomObject]@{ FeatureId = 'Feature'; RegistryKey = 'feature.reg' } }
        Mock Get-RegistryBackupPayload { @{ Version = '1.0' } }
        Mock Save-ToFile { $true }
        Mock Write-Host {}
    }

    It 'returns null and does not write when no selected feature has registry data' {
        $script:Features.Feature.RegistryKey = ''

        New-RegistrySettingsBackup -ActionableKeys @('Feature') | Should -BeNullOrEmpty
        Should -Invoke Save-ToFile -Times 0 -Exactly
    }

    It 'creates the backup directory and saves a generated payload' {
        $result = New-RegistrySettingsBackup -ActionableKeys @('Feature')

        $result | Should -Match 'Win11Debloat-RegistryBackup-\d{8}_\d{6}\.json$'
        Test-Path -LiteralPath $script:RegistryBackupsPath | Should -BeTrue
        Should -Invoke Save-ToFile -Times 1 -Exactly -ParameterFilter { $FilePath -eq $result -and $MaxDepth -eq 25 }
    }

    It 'throws when persistence reports failure' {
        Mock Save-ToFile { $false }

        { New-RegistrySettingsBackup -ActionableKeys @('Feature') } | Should -Throw 'Failed to save registry backup to *'
    }
}

Describe 'Add-RegistryPlanOperation' {
    It 'merges duplicate value operations and upgrades a key deletion to a recursive capture' {
        $plans = @{}
        Add-RegistryPlanOperation -PlanMap $plans -Operation ([PSCustomObject]@{ KeyPath = 'HKEY_CURRENT_USER\Software\Example'; OperationType = 'SetValue'; ValueName = 'One' })
        Add-RegistryPlanOperation -PlanMap $plans -Operation ([PSCustomObject]@{ KeyPath = 'HKEY_CURRENT_USER\Software\Example'; OperationType = 'DeleteValue'; ValueName = 'one' })
        Add-RegistryPlanOperation -PlanMap $plans -Operation ([PSCustomObject]@{ KeyPath = 'HKEY_CURRENT_USER\Software\Example'; OperationType = 'DeleteKey'; ValueName = $null })

        $plan = $plans['hkey_current_user\software\example']
        $plan.IncludeSubKeys | Should -BeTrue
        $plan.CaptureAllValues | Should -BeTrue
        $plan.ValueNames | Should -HaveCount 1
    }

    It '<Case>' -ForEach @(
        @{ Case = 'uses an explicit undo key'; RegistryUndoKey = 'undo.reg'; RegistryKey = 'apply.reg'; Expected = 'Undo/undo.reg' }
        @{ Case = 'falls back to a relative regular registry key'; RegistryUndoKey = ''; RegistryKey = 'apply.reg'; Expected = 'apply.reg' }
        @{ Case = 'preserves a rooted regular registry key'; RegistryUndoKey = ''; RegistryKey = 'C:\temp\apply.reg'; Expected = 'C:\temp\apply.reg' }
    ) {
        $script:RegfilesPath = $TestDrive
        function Resolve-UndoRegFilePath { param($FileName) "Undo/$FileName" }

        $expectedPath = if ([System.IO.Path]::IsPathRooted($Expected)) { $Expected } else { Join-Path $TestDrive $Expected }
        Resolve-RegistryBackupUndoFilePath -Feature ([PSCustomObject]@{ RegistryUndoKey = $RegistryUndoKey; RegistryKey = $RegistryKey }) |
            Should -Be $expectedPath
    }
}

Describe 'Get-RegistryBackupCapturePlans' {
    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = $TestDrive
        $script:applyPath = Join-Path $TestDrive 'apply.reg'
        $script:undoPath = Join-Path $TestDrive 'undo.reg'
        '' | Set-Content -LiteralPath $script:applyPath
        '' | Set-Content -LiteralPath $script:undoPath
        Mock Get-RegistryFilePathForFeature { $script:applyPath }
        Mock Resolve-RegistryBackupUndoFilePath { $script:undoPath }
        Mock Get-RegFileOperations {
            param($regFilePath)
            if ($regFilePath -eq $script:applyPath) {
                @(
                    [PSCustomObject]@{ KeyPath = 'HKEY_CURRENT_USER\Software\Example'; OperationType = 'SetValue'; ValueName = 'Enabled' }
                    [PSCustomObject]@{ KeyPath = $null; OperationType = 'SetValue'; ValueName = 'Ignored' }
                )
            }
            else {
                @([PSCustomObject]@{ KeyPath = 'hkey_current_user\software\example'; OperationType = 'DeleteValue'; ValueName = 'Removed' })
            }
        }
    }

    It 'merges apply and undo operations for the same path and ignores operations without a path' {
        $plans = @(Get-RegistryBackupCapturePlans `
            -SelectedRegistryFeatures @([PSCustomObject]@{ RegistryKey = 'apply.reg' }) `
            -UndoRegistryFeatures @([PSCustomObject]@{ RegistryUndoKey = 'undo.reg' }))

        $plans | Should -HaveCount 1
        $plans[0].ValueNames | Should -Contain 'Enabled'
        $plans[0].ValueNames | Should -Contain 'Removed'
        $plans[0].ValueNames | Should -Not -Contain 'Ignored'
    }

    It 'passes Sysprep selection through to registry-file resolution' {
        Get-RegistryBackupCapturePlans -SelectedRegistryFeatures @([PSCustomObject]@{ RegistryKey = 'apply.reg' }) -UseSysprepRegFiles | Out-Null

        Should -Invoke Get-RegistryFilePathForFeature -Times 1 -Exactly -ParameterFilter { $UseSysprepRegFiles }
    }

    It 'throws a descriptive error when an apply registry file is missing' {
        Mock Get-RegistryFilePathForFeature { Join-Path $TestDrive 'missing.reg' }

        { Get-RegistryBackupCapturePlans -SelectedRegistryFeatures @([PSCustomObject]@{ RegistryKey = 'missing.reg' }) } |
            Should -Throw 'Unable to find registry file for backup: missing.reg*'
        Should -Invoke Get-RegFileOperations -Times 0 -Exactly
    }

    It 'throws a descriptive error when an undo registry file is missing' {
        Mock Resolve-RegistryBackupUndoFilePath { Join-Path $TestDrive 'missing-undo.reg' }

        { Get-RegistryBackupCapturePlans -UndoRegistryFeatures @([PSCustomObject]@{ RegistryUndoKey = 'missing-undo.reg' }) } |
            Should -Throw 'Unable to find registry undo file for backup: missing-undo.reg*'
    }

    It 'skips undo features that do not resolve to a registry file' {
        Mock Resolve-RegistryBackupUndoFilePath { $null }

        @(Get-RegistryBackupCapturePlans -UndoRegistryFeatures @([PSCustomObject]@{ RegistryUndoKey = ''; RegistryKey = '' })) |
            Should -HaveCount 0
        Should -Invoke Get-RegFileOperations -Times 0 -Exactly
    }
}

Describe 'Get-RegistrySnapshotsForBackup' {
    BeforeEach {
        $script:Params = @{}
        Mock Get-RegistryKeySnapshot {
            param($KeyPath)
            [PSCustomObject]@{ Path = $KeyPath; Exists = $true }
        }
        Mock Invoke-WithLoadedBackupHive {
            param($ScriptBlock, $ArgumentObject)
            & $ScriptBlock $ArgumentObject
        }
    }

    It 'returns an empty collection without touching the registry when there are no plans' {
        @(Get-RegistrySnapshotsForBackup -CapturePlans @()) | Should -HaveCount 0
        Should -Invoke Get-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedBackupHive -Times 0 -Exactly
    }

    It 'captures each plan directly for the current user' {
        $plans = @(
            [PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\One'; CaptureAllValues = $true; ValueNames = @(); IncludeSubKeys = $true }
            [PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\Two'; CaptureAllValues = $false; ValueNames = @('Value'); IncludeSubKeys = $false }
        )

        @(Get-RegistrySnapshotsForBackup -CapturePlans $plans) | Should -HaveCount 2
        Should -Invoke Get-RegistryKeySnapshot -Times 2 -Exactly
        Should -Invoke Invoke-WithLoadedBackupHive -Times 0 -Exactly
    }

    It 'captures through the loaded-hive wrapper in <Case>' -ForEach @(
        @{ Case = 'User mode'; Params = @{ User = 'Alice' } }
        @{ Case = 'Sysprep mode'; Params = @{ Sysprep = $true } }
    ) {
        $script:Params = $Params
        $plan = [PSCustomObject]@{ Path = 'HKEY_USERS\Default\Software\Example'; CaptureAllValues = $false; ValueNames = @('Value'); IncludeSubKeys = $false }

        @(Get-RegistrySnapshotsForBackup -CapturePlans @($plan)) | Should -HaveCount 1
        Should -Invoke Invoke-WithLoadedBackupHive -Times 1 -Exactly
        Should -Invoke Get-RegistryKeySnapshot -Times 1 -Exactly
    }
}

Describe 'Invoke-WithLoadedBackupHive' {
    BeforeEach {
        Mock Invoke-WithTargetUserHive { param($TargetUserName) $TargetUserName }
    }

    It 'targets <ExpectedUser> in <Case>' -ForEach @(
        @{ Case = 'Sysprep mode'; Params = @{ Sysprep = $true }; ExpectedUser = 'Default' }
        @{ Case = 'User mode'; Params = @{ User = 'Alice' }; ExpectedUser = 'Alice' }
    ) {
        $script:Params = $Params
        Invoke-WithLoadedBackupHive -ScriptBlock { } | Should -Be $ExpectedUser
    }
}
