BeforeAll {
    function Test-RunningAsSystem { $false }
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-FriendlyRegistryBackupTarget.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Resolve-UserProfilePath.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Test-TargetUserName.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Registry-BackupValidation.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Restore-RegistryApplyState.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Restore-RegistryBackup.ps1')
    $script:JsonFixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading'
    $script:LanguagesPath = Join-Path $PSScriptRoot '..\Config\Languages'
    $script:Lang = Import-LanguageFile -LanguageCode 'en-US'
}

Describe 'Import-RegistryBackup' {
    It 'loads JSON and passes the parsed backup to normalization' {
        Mock ConvertTo-NormalizedRegistryBackup { [PSCustomObject]@{ Target = 'DefaultUserProfile' } }

        $result = Import-RegistryBackup -FilePath (Join-Path $script:JsonFixturePath 'RegistryBackup.Valid.json')

        $result.Target | Should -Be 'DefaultUserProfile'
        Should -Invoke ConvertTo-NormalizedRegistryBackup -Times 1 -Exactly
    }

    It 'parses and normalizes registry snapshots from a real backup structure' {
        Mock Test-UserNameMatch { $true }
        Mock Get-RegistryBackupValidationPlanMap { @{} }
        Mock ConvertTo-CompatibleRegistryKeySnapshots { param($RegistryKeys) $RegistryKeys }
        Mock Test-RegistryBackupAgainstAllowList { @() }

        $result = Import-RegistryBackup -FilePath (Join-Path $script:JsonFixturePath 'RegistryBackup.RealStructure.json')

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
        Should -Invoke Test-RegistryBackupAgainstAllowList -Times 1 -Exactly
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'a missing backup file'; FileName = 'missing.json'; ExpectedError = 'Backup file was not found:*' }
        @{ Case = 'an invalid JSON backup file'; FileName = 'RegistryBackup.Invalid.json'; ExpectedError = $null }
    ) {
        $path = Join-Path $script:JsonFixturePath $FileName
        $errorPattern = if ($null -ne $ExpectedError) { $ExpectedError } else { "Failed to read backup file '$path'. The file is not valid JSON." }

        { Import-RegistryBackup -FilePath $path } | Should -Throw $errorPattern
    }
}

Describe 'ConvertTo-NormalizedRegistryBackup' {
    BeforeEach {
        $script:Features = @{ Example = [PSCustomObject]@{ FeatureId = 'Example'; RegistryKey = 'Example.reg' } }
        Mock Get-RegistryBackupValidationPlanMap { @{} }
        Mock ConvertTo-CompatibleRegistryKeySnapshots { param($RegistryKeys) $RegistryKeys }
        Mock Test-RegistryBackupAgainstAllowList { @() }
        Mock Write-Error {}
    }

    It 'normalizes a valid legacy backup without undo selections' {
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            CreatedAt = '2026-01-01T00:00:00.0000000Z'; CreatedBy = 'Win11Debloat'; ComputerName = 'PC'
            SelectedFeatures = @('Example', 'example'); RegistryKeys = @()
        }

        $result = ConvertTo-NormalizedRegistryBackup -Backup $backup

        $result.Target | Should -Be 'DefaultUserProfile'
        $result.SelectedFeatures -is [array] | Should -BeTrue
        $result.SelectedFeatures | Should -Be 'Example'
        $result.SelectedUndoFeatures | Should -BeNullOrEmpty
        Should -Invoke Test-RegistryBackupAgainstAllowList -Times 1 -Exactly
    }

    It 'aggregates invalid metadata and does not attempt allow-list validation without feature IDs' {
        $backup = [PSCustomObject]@{ Version = '2.0'; BackupType = 'Other'; Target = 'Unknown'; RegistryKeys = @() }

        { ConvertTo-NormalizedRegistryBackup -Backup $backup } | Should -Throw 'Validation failed with * errors. See console output for details.'

        Should -Invoke Write-Error -Times 1 -Exactly
        Should -Invoke Test-RegistryBackupAgainstAllowList -Times 0 -Exactly
    }

    It 'reports an invalid user target as a validation failure' {
        Mock Test-TargetUserName { [PSCustomObject]@{ IsValid = $false } }
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'User:bad/user'
            SelectedFeatures = @('Example'); RegistryKeys = @()
        }

        { ConvertTo-NormalizedRegistryBackup -Backup $backup } | Should -Throw "Validation failed: Invalid user 'User:bad/user'"
    }

    It 'does not allow current-user backup restore when running as SYSTEM' {
        Mock Test-RunningAsSystem { $true }
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'CurrentUser:Alice'
            SelectedFeatures = @('Example'); RegistryKeys = @()
        }

        { ConvertTo-NormalizedRegistryBackup -Backup $backup } |
            Should -Throw "Validation failed: Backup was made for 'Alice' and is user-scoped*"
    }
}

Describe 'Restore-RegistryBackupState' {
    BeforeEach {
        $script:Params = @{}
        Mock Get-FriendlyRegistryBackupTarget { 'friendly target' }
        Mock Restore-RegistryKeySnapshot {}
        Mock Invoke-WithLoadedRestoreHive {}
        Mock Write-Host {}
        Mock Test-UserNameMatch { $true }
        Mock Write-Error {}
        Mock Get-RegistryBackupValidationPlanMap { @{} }
        Mock ConvertTo-CompatibleRegistryKeySnapshots { param($RegistryKeys) $RegistryKeys }
        Mock Test-RegistryBackupAgainstAllowList { @() }
        $script:backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'CurrentUser:Tester'; SelectedFeatures = @('Example')
            RegistryKeys = @(
                [PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\One'; Exists = $true; Values = @(); SubKeys = @() }
                [PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\Two'; Exists = $true; Values = @(); SubKeys = @() }
            )
        }
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

    It 'rejects a malformed later root before any writes or hive loading for <Target>' -ForEach @(
        @{ Target = 'CurrentUser:Tester'; InvalidKind = $false; ExpectedError = '*is not directly below parent*' }
        @{ Target = 'DefaultUserProfile'; InvalidKind = $false; ExpectedError = '*is not directly below parent*' }
        @{ Target = 'User:Alice'; InvalidKind = $false; ExpectedError = '*is not directly below parent*' }
        @{ Target = 'DefaultUserProfile'; InvalidKind = $true; ExpectedError = '*Unsupported registry value kind*' }
    ) {
        Mock Test-TargetUserName { [PSCustomObject]@{ IsValid = $true } }
        $first = [PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\One'; Exists = $true; Values = @(); SubKeys = @() }
        $second = [PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\Two'; Exists = $true; Values = @(); SubKeys = @() }
        if ($InvalidKind) {
            $second.Values = @([PSCustomObject]@{ Name = 'Setting'; Exists = $true; Kind = '99'; Data = 'data' })
        }
        else {
            $second.SubKeys = @([PSCustomObject]@{ Path = $first.Path; Exists = $true; Values = @(); SubKeys = @() })
        }
        $script:backup.Target = $Target
        $script:backup.RegistryKeys = @($first, $second)

        { Restore-RegistryBackupState -Backup $script:backup } | Should -Throw $ExpectedError

        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }

    It 'rejects conflicting duplicate root snapshots before restore' {
        $script:backup.RegistryKeys = @($script:backup.RegistryKeys[0], $script:backup.RegistryKeys[0])

        { Restore-RegistryBackupState -Backup $script:backup } | Should -Throw '*duplicate registry root path*'

        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
    }
}

Describe 'Restore executable warning dialog' {
    BeforeAll {
        Add-Type -AssemblyName PresentationFramework
        . (Join-Path $PSScriptRoot '..\Scripts\GUI\Show-MessageBox.ps1')
        . (Join-Path $PSScriptRoot '..\Scripts\GUI\Show-RestoreBackupDialog.ps1')
        . (Join-Path $PSScriptRoot '..\Scripts\GUI\Show-RestoreBackupWindow.ps1')
    }

    BeforeEach {
        $script:Params = @{}
        Mock Write-Host {}
        Mock Show-RestoreBackupDialog {
            @{ Result = 'RestoreRegistry'; Backup = [PSCustomObject]@{ Target = 'DefaultUserProfile' } }
        }
        Mock Restore-RegistryBackupState {
            param($Backup, $ConfirmUntrustedValues)
            $approved = & $ConfirmUntrustedValues @(
                [PSCustomObject]@{ Path = 'HKEY_CLASSES_ROOT\test\shell\open\command'; Name = ''; Kind = 'String'; Data = 'custom.exe /argument' }
            )
            [PSCustomObject]@{ Result = $approved }
        }
    }

    It 'offers cancellation by default and includes source and executable details' {
        Mock Show-MessageBox { 'Cancel' }
        $result = Show-RestoreBackupWindow
        $result.RestoredRegistry | Should -BeFalse
        Should -Invoke Show-MessageBox -Times 1 -Exactly -ParameterFilter {
            $DefaultResult -eq 'Cancel' -and $Button -eq 'OKCancel' -and $Icon -eq 'Warning' -and
            $Message -like '*Do not restore registry backups obtained from unofficial sources*' -and
            $Message -like '*HKEY_CLASSES_ROOT\test\shell\open\command*' -and
            $Message -like '*String*' -and $Message -like '*custom.exe /argument*'
        }
    }

    It 'continues only when the warning is explicitly accepted' {
        Mock Show-MessageBox { 'OK' }
        $result = Show-RestoreBackupWindow
        $result.RestoredRegistry | Should -BeTrue
        Should -Invoke Show-MessageBox -Times 1 -Exactly -ParameterFilter { $DefaultResult -eq 'Cancel' }
    }
}
