BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\RegistryPathHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\GetFriendlyRegistryBackupTarget.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\ResolveUserProfilePath.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Test-TargetUserName.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\RegistryBackupValidation.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\RestoreRegistryApplyState.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\RestoreRegistryBackup.ps1')
    $script:JsonFixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading'
}

Describe 'Load-RegistryBackupFromFile' {
    It 'loads JSON and passes the parsed backup to normalization' {
        Mock Normalize-RegistryBackup { [PSCustomObject]@{ Target = 'DefaultUserProfile' } }

        $result = Load-RegistryBackupFromFile -FilePath (Join-Path $script:JsonFixturePath 'RegistryBackup.Valid.json')

        $result.Target | Should -Be 'DefaultUserProfile'
        Should -Invoke Normalize-RegistryBackup -Times 1 -Exactly
    }

    It 'parses and normalizes registry snapshots from a real backup structure' {
        Mock Test-UserNameMatch { $true }
        Mock Test-RegistryBackupMatchesSelectedFeatures { @() }

        $result = Load-RegistryBackupFromFile -FilePath (Join-Path $script:JsonFixturePath 'RegistryBackup.RealStructure.json')

        $result.Target | Should -Be 'CurrentUser:fixture-user'
        $result.SelectedFeatures | Should -Be @('RemoveApps', 'DisableStickyKeys')
        $result.SelectedUndoFeatures | Should -Be 'DisableTransparency'
        $result.RegistryKeys | Should -HaveCount 2
        $result.RegistryKeys[0].Path | Should -Be 'HKEY_CURRENT_USER\Control Panel\Accessibility\StickyKeys'
        $result.RegistryKeys[0].Values[0].Name | Should -Be 'Flags'
        $result.RegistryKeys[0].Values[0].Kind | Should -Be 'String'
        $result.RegistryKeys[0].Values[0].Data | Should -Be '510'
        $result.RegistryKeys[1].Path | Should -Be 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        $result.RegistryKeys[1].Values[0].Name | Should -Be 'EnableTransparency'
        $result.RegistryKeys[1].Values[0].Kind | Should -Be 'DWord'
        $result.RegistryKeys[1].Values[0].Data | Should -Be 0
        Should -Invoke Test-RegistryBackupMatchesSelectedFeatures -Times 1 -Exactly
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'a missing backup file'; FileName = 'missing.json'; ExpectedError = 'Backup file was not found:*' }
        @{ Case = 'an invalid JSON backup file'; FileName = 'RegistryBackup.Invalid.json'; ExpectedError = $null }
    ) {
        $path = Join-Path $script:JsonFixturePath $FileName
        $errorPattern = if ($null -ne $ExpectedError) { $ExpectedError } else { "Failed to read backup file '$path'. The file is not valid JSON." }

        { Load-RegistryBackupFromFile -FilePath $path } | Should -Throw $errorPattern
    }
}

Describe 'Normalize-RegistryBackup' {
    BeforeEach {
        $script:Features = @{ Example = [PSCustomObject]@{ FeatureId = 'Example'; RegistryKey = 'Example.reg' } }
        Mock Test-RegistryBackupMatchesSelectedFeatures { @() }
        Mock Write-Error {}
    }

    It 'normalizes a valid legacy backup without undo selections' {
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            CreatedAt = '2026-01-01T00:00:00.0000000Z'; CreatedBy = 'Win11Debloat'; ComputerName = 'PC'
            SelectedFeatures = @('Example', 'example'); RegistryKeys = @()
        }

        $result = Normalize-RegistryBackup -Backup $backup

        $result.Target | Should -Be 'DefaultUserProfile'
        $result.SelectedFeatures | Should -Be 'Example'
        $result.SelectedUndoFeatures | Should -BeNullOrEmpty
        Should -Invoke Test-RegistryBackupMatchesSelectedFeatures -Times 1 -Exactly
    }

    It 'aggregates invalid metadata and does not attempt allow-list validation without feature IDs' {
        $backup = [PSCustomObject]@{ Version = '2.0'; BackupType = 'Other'; Target = 'Unknown'; RegistryKeys = @() }

        { Normalize-RegistryBackup -Backup $backup } | Should -Throw 'Validation failed with * errors. See console output for details.'

        Should -Invoke Write-Error -Times 1 -Exactly
        Should -Invoke Test-RegistryBackupMatchesSelectedFeatures -Times 0 -Exactly
    }

    It 'reports an invalid user target as a validation failure' {
        Mock Test-TargetUserName { [PSCustomObject]@{ IsValid = $false } }
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'User:bad/user'
            SelectedFeatures = @('Example'); RegistryKeys = @()
        }

        { Normalize-RegistryBackup -Backup $backup } | Should -Throw "Validation failed: Invalid user 'User:bad/user'"
    }
}

Describe 'Restore-RegistryBackupState' {
    BeforeEach {
        $script:Params = @{}
        Mock GetFriendlyRegistryBackupTarget { 'friendly target' }
        Mock Restore-RegistryKeySnapshot {}
        Mock Invoke-WithLoadedRestoreHive {}
        Mock Write-Host {}
        $script:backup = [PSCustomObject]@{ Target = 'CurrentUser:Tester'; RegistryKeys = @([PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\One' }, [PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\Two' }) }
    }

    It 'restores every root snapshot directly for the current user' {
        (Restore-RegistryBackupState -Backup $script:backup).Result | Should -BeTrue

        Should -Invoke Restore-RegistryKeySnapshot -Times 2 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }

    It 'delegates default-profile restores through the loaded hive wrapper' {
        $script:backup.Target = 'DefaultUserProfile'
        Mock Invoke-WithLoadedRestoreHive {
            param($Target, $ScriptBlock, $ArgumentObject)
            & $ScriptBlock $ArgumentObject
        }

        (Restore-RegistryBackupState -Backup $script:backup).Result | Should -BeTrue

        Should -Invoke Invoke-WithLoadedRestoreHive -Times 1 -Exactly -ParameterFilter { $Target -eq 'DefaultUserProfile' }
        Should -Invoke Restore-RegistryKeySnapshot -Times 2 -Exactly
    }

    It 'honors WhatIf without restoring snapshots or loading a hive' {
        $script:Params = @{ WhatIf = $true }

        (Restore-RegistryBackupState -Backup $script:backup).Result | Should -BeTrue

        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }
}
