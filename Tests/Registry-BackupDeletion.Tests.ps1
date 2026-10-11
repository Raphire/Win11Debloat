BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-RegFileOperations.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Resolve-UserProfilePath.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Test-TargetUserName.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Invoke-Changes.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Backup-RegistrySnapshotCapture.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Registry-BackupValidation.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Restore-RegistryApplyState.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Restore-RegistryBackup.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-FriendlyRegistryBackupTarget.ps1')
    $script:LanguagesPath = Join-Path $PSScriptRoot '..\Config\Languages'
    $script:Lang = Import-LanguageFile -LanguageCode 'en-US'
    $script:FeatureCatalog = Import-JsonFile -FilePath (Join-Path $PSScriptRoot '..\Config\Features.json')
}

Describe 'Registry backup deletion permissions' {
    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = Join-Path $PSScriptRoot '..\Regfiles'
        $script:Features = @{}
        foreach ($feature in $script:FeatureCatalog.Features) {
            $script:Features[$feature.FeatureId] = $feature
        }
    }

    It 'rejects deletion of a key that <FeatureId> only changes values under' -ForEach @(
        @{ FeatureId = 'DisableAnimations'; Path = 'HKEY_USERS\Default\Control Panel\Desktop' }
        @{ FeatureId = 'DisableLocationServices'; Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' }
    ) {
        $snapshot = [PSCustomObject]@{
            Path = $Path; Exists = $false; Values = @(); SubKeys = @()
            # An attacker-supplied permission must have no effect.
            AllowDeleteKey = $true
        }

        $errors = @(Test-RegistryBackupMatchesSelectedFeatures -SelectedFeatureIds @($FeatureId) -SelectedUndoFeatureIds @() -Target 'DefaultUserProfile' -RegistryKeys @($snapshot))

        $errors | Should -HaveCount 1
        $errors[0] | Should -Be "Backup contains an unauthorized registry key deletion: '$Path'."
    }

    It 'authorizes a tree deletion only for the selected undo operation' {
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command'; Exists = $false; Values = @(); SubKeys = @()
        }

        $applyErrors = @(Test-RegistryBackupMatchesSelectedFeatures -SelectedFeatureIds @('DisableGameBarIntegration') -SelectedUndoFeatureIds @() -Target 'DefaultUserProfile' -RegistryKeys @($snapshot))
        $undoErrors = @(Test-RegistryBackupMatchesSelectedFeatures -SelectedFeatureIds @() -SelectedUndoFeatureIds @('DisableGameBarIntegration') -Target 'DefaultUserProfile' -RegistryKeys @($snapshot))

        $applyErrors | Should -HaveCount 1
        $applyErrors[0] | Should -BeLike '*unauthorized registry key deletion*'
        $undoErrors | Should -BeNullOrEmpty
    }

    It 'uses <Target> registry paths for deletion validation' -ForEach @(
        @{ Target = 'DefaultUserProfile' }
        @{ Target = 'User:Alice' }
        @{ Target = 'CurrentUser:Alice' }
    ) {
        $isOtherProfile = $Target -eq 'DefaultUserProfile' -or $Target -like 'User:*'
        $path = if ($isOtherProfile) { 'HKEY_USERS\Default\Control Panel\Desktop' } else { 'HKEY_CURRENT_USER\Control Panel\Desktop' }
        $snapshot = [PSCustomObject]@{ Path = $path; Exists = $false; Values = @(); SubKeys = @() }

        $errors = @(Test-RegistryBackupMatchesSelectedFeatures -SelectedFeatureIds @('DisableAnimations') -SelectedUndoFeatureIds @() -Target $Target -RegistryKeys @($snapshot))

        $errors | Should -HaveCount 1
        $errors[0] | Should -BeLike '*unauthorized registry key deletion*'
    }

    It 'rejects the complete backup before restore can apply an earlier valid snapshot' {
        $filePath = Join-Path $TestDrive 'unauthorized-deletion.json'
        [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @('DisableAnimations')
            RegistryKeys = @(
                [PSCustomObject]@{
                    Path = 'HKEY_USERS\Default\Control Panel\Desktop'; Exists = $true
                    Values = @([PSCustomObject]@{ Name = 'UserPreferencesMask'; Exists = $true; Kind = 'Binary'; Data = @(144, 18, 7, 128, 16, 0, 0, 0) })
                    SubKeys = @()
                }
                [PSCustomObject]@{
                    Path = 'HKEY_USERS\Default\Control Panel\Desktop'; Exists = $false
                    # Legacy absent keys had no values; this contradictory snapshot must be rejected.
                    Values = @([PSCustomObject]@{ Name = 'UserPreferencesMask'; Exists = $false })
                    SubKeys = @()
                }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $filePath -Encoding UTF8
        Mock Restore-RegistryKeySnapshot {}
        Mock Invoke-WithLoadedRestoreHive {}
        Mock Write-Error {}

        { Restore-RegistryBackupState -Backup (Import-RegistryBackup -FilePath $filePath) } |
            Should -Throw '*unauthorized registry key deletion*'

        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }

    It 'restores an authorized deletion through the existing tree-delete helper' {
        $path = 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command'
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @(); SelectedUndoFeatures = @('DisableGameBarIntegration')
            RegistryKeys = @([PSCustomObject]@{ Path = $path; Exists = $false; Values = @(); SubKeys = @() })
        }
        $root = [PSCustomObject]@{ DeletedTrees = [System.Collections.Generic.List[string]]::new() }
        $root | Add-Member ScriptMethod DeleteSubKeyTree { param($subKey, $throwOnMissing) $this.DeletedTrees.Add($subKey) }
        Mock Get-RegistryRootKey { $root }

        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup
        Restore-RegistryKeySnapshot -Snapshot $normalized.RegistryKeys[0]

        $root.DeletedTrees | Should -Be @('ms-gamebar\shell\open\command')
    }
}

Describe 'Executable registry backup values' {
    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = Join-Path $PSScriptRoot '..\Regfiles'
        $script:Features = @{}
        foreach ($feature in $script:FeatureCatalog.Features) { $script:Features[$feature.FeatureId] = $feature }
        Mock Write-Error {}
        Mock Restore-RegistryKeySnapshot {}
        Mock Invoke-WithLoadedRestoreHive {}
    }

    It 'rejects a doctored <Case> before any restore calls' -ForEach @(
        @{ Case = 'Game Bar command'; FeatureId = 'DisableGameBarIntegration'; Undo = $false; Path = 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command'; Name = ''; Kind = 'String'; Data = 'cmd.exe /c echo doctored' }
        @{ Case = 'Game Bar services command'; FeatureId = 'DisableGameBarIntegration'; Undo = $false; Path = 'HKEY_CLASSES_ROOT\ms-gamebarservices\shell\open\command'; Name = ''; Kind = 'String'; Data = 'cmd.exe /c echo doctored' }
        @{ Case = 'undo command'; FeatureId = 'DisableGameBarIntegration'; Undo = $true; Path = 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command'; Name = ''; Kind = 'String'; Data = 'cmd.exe /c echo doctored' }
        @{ Case = 'RunOnce command'; FeatureId = 'RevertContextMenu'; Undo = $false; Path = 'HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Name = 'RestoreWin10ContextMenu'; Kind = 'String'; Data = 'cmd.exe /c echo doctored' }
        @{ Case = 'DLL path'; FeatureId = 'RevertContextMenu'; Undo = $false; Path = 'HKEY_USERS\Default\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; Name = ''; Kind = 'String'; Data = 'C:\Temp\doctored.dll' }
        @{ Case = 'COM indirection'; FeatureId = 'RevertContextMenu'; Undo = $true; Path = 'HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\TreatAs'; Name = ''; Kind = 'String'; Data = '{00000000-0000-0000-0000-000000000001}' }
        @{ Case = 'appended command arguments'; FeatureId = 'DisableGameBarIntegration'; Undo = $false; Path = 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command'; Name = ''; Kind = 'String'; Data = '%SystemRoot%/System32/systray.exe /doctored' }
        @{ Case = 'changed command kind'; FeatureId = 'DisableGameBarIntegration'; Undo = $false; Path = 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command'; Name = ''; Kind = 'ExpandString'; Data = '%SystemRoot%/System32/systray.exe' }
        @{ Case = 'undefined value kind'; FeatureId = 'DisableGameBarIntegration'; Undo = $false; Path = 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command'; Name = ''; Kind = '99'; Data = 'data' }
    ) {
        $filePath = Join-Path $TestDrive 'doctored.json'
        [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = if ($Undo) { @() } else { @($FeatureId) }
            SelectedUndoFeatures = if ($Undo) { @($FeatureId) } else { @() }
            RegistryKeys = @([PSCustomObject]@{
                Path = $Path; Exists = $true; Values = @([PSCustomObject]@{ Name = $Name; Exists = $true; Kind = $Kind; Data = $Data }); SubKeys = @()
            })
            # Backup-provided trust information must have no effect.
            TrustedValueMap = @{ Command = $Data }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $filePath -Encoding UTF8

        { Restore-RegistryBackupState -Backup (Import-RegistryBackup -FilePath $filePath) } | Should -Throw '*Validation failed*'

        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }

    It 'accepts <Case> without broadening the operation scope' -ForEach @(
        @{ Case = 'a trusted command'; Undo = $false; Exists = $true; Data = '%SystemRoot%/System32/systray.exe' }
        @{ Case = 'the trusted apply command when restoring undo'; Undo = $true; Exists = $true; Data = '%SystemRoot%/System32/systray.exe' }
        @{ Case = 'an empty executable value'; Undo = $false; Exists = $true; Data = '' }
        @{ Case = 'a missing executable value'; Undo = $false; Exists = $false; Data = $null }
    ) {
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = if ($Undo) { @() } else { @('DisableGameBarIntegration') }
            SelectedUndoFeatures = if ($Undo) { @('DisableGameBarIntegration') } else { @() }
            RegistryKeys = @([PSCustomObject]@{
                Path = 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command'; Exists = $true
                Values = @([PSCustomObject]@{ Name = ''; Exists = $Exists; Kind = if ($Exists) { 'String' } else { $null }; Data = $Data }); SubKeys = @()
            })
        }

        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup

        $normalized.RegistryKeys[0].Values[0].Data | Should -Be $Data
        $normalized.RegistryKeys[0].Values[0].Exists | Should -Be $Exists
    }

    It 'accepts the actual trusted RunOnce command' {
        $operation = @(Get-RegFileOperations -regFilePath (Join-Path $script:RegfilesPath 'Sysprep\Disable_Show_More_Options_Context_Menu.reg') | Where-Object ValueName -eq 'RestoreWin10ContextMenu')[0]
        $snapshot = [PSCustomObject]@{ Path = $operation.KeyPath; Exists = $true; Values = @([PSCustomObject]@{ Name = $operation.ValueName; Exists = $true; Kind = 'String'; Data = $operation.ValueData }); SubKeys = @() }

        @(Test-RegistryBackupMatchesSelectedFeatures -SelectedFeatureIds @('RevertContextMenu') -SelectedUndoFeatureIds @() -Target 'DefaultUserProfile' -RegistryKeys @($snapshot)) | Should -HaveCount 0
    }

    It 'keeps ordinary numeric COM visibility settings restorable' {
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_USERS\Default\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'; Exists = $true
            Values = @([PSCustomObject]@{ Name = 'System.IsPinnedToNameSpaceTree'; Exists = $true; Kind = 'DWord'; Data = 1 }); SubKeys = @()
        }

        @(Test-RegistryBackupMatchesSelectedFeatures -SelectedFeatureIds @('HideOnedrive') -SelectedUndoFeatureIds @() -Target 'DefaultUserProfile' -RegistryKeys @($snapshot)) | Should -HaveCount 0
    }

    It 'rejects misplaced children during import rather than starting restore' {
        $desktop = [PSCustomObject]@{ Path = 'HKEY_USERS\Default\Control Panel\Desktop'; Exists = $true; Values = @(); SubKeys = @() }
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'; SelectedFeatures = @('DisableAnimations')
            RegistryKeys = @($desktop, [PSCustomObject]@{
                Path = 'HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Exists = $true; Values = @(); SubKeys = @($desktop)
            })
        }

        { Restore-RegistryBackupState -Backup (ConvertTo-NormalizedRegistryBackup -Backup $backup) } | Should -Throw '*is not directly below parent*'

        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }
}

Describe 'Registry tree deletion scope' {
    BeforeEach {
        $script:DeletionPlanMap = New-RegistryBackupAllowListPlanMap -CapturePlans @(
            [PSCustomObject]@{
                Path = 'HKEY_CURRENT_USER\Software\Example'; IncludeSubKeys = $true
                CaptureAllValues = $true; AllowDeleteKey = $true; ValueNames = @()
            }
            [PSCustomObject]@{
                Path = 'HKEY_CURRENT_USER\Software\Example\Child'; IncludeSubKeys = $false
                CaptureAllValues = $false; AllowDeleteKey = $false; ValueNames = @('Enabled')
            }
        )
    }

    It 'validates deletion of <Path> as <Allowed>' -ForEach @(
        @{ Path = 'hkey_current_user/Software/Example'; Allowed = $true }
        @{ Path = 'HKEY_CURRENT_USER\Software\Example\Child'; Allowed = $true }
        @{ Path = 'HKEY_CURRENT_USER\Software\Example\Child\Nested'; Allowed = $true }
        @{ Path = 'HKEY_CURRENT_USER\Software'; Allowed = $false }
        @{ Path = 'HKEY_CURRENT_USER\Software\ExampleSibling'; Allowed = $false }
        @{ Path = 'HKEY_LOCAL_MACHINE\Software\Example'; Allowed = $false }
    ) {
        Test-RegistryKeyDeletionAllowed -NormalizedPath (Get-NormalizedRegistryPathKey -Path $Path) -PlanMap $script:DeletionPlanMap |
            Should -Be $Allowed
    }

    It 'accepts a nested deletion despite an exact value-only plan' {
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Example'; Exists = $true; Values = @()
            SubKeys = @([PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\Example\Child'; Exists = $false; Values = @(); SubKeys = @() })
        }
        $errors = New-Object 'System.Collections.Generic.List[string]'

        Test-RegistrySnapshotAgainstAllowList -Snapshot $snapshot -PlanMap $script:DeletionPlanMap -Errors $errors

        $errors | Should -BeNullOrEmpty
    }

    It 'does not grant deletion merely because all values and subkeys are captured' {
        $script:DeletionPlanMap.Values | ForEach-Object { $_.AllowDeleteKey = $false }

        Test-RegistryKeyDeletionAllowed -NormalizedPath (Get-NormalizedRegistryPathKey -Path 'HKEY_CURRENT_USER\Software\Example') -PlanMap $script:DeletionPlanMap |
            Should -BeFalse
    }

    It 'preserves an authorized descendant deletion during compatibility conversion' {
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Example'; Exists = $true; Values = @()
            SubKeys = @([PSCustomObject]@{ Path = 'HKEY_CURRENT_USER\Software\Example\Child'; Exists = $false; Values = @(); SubKeys = @() })
        }

        $converted = @(ConvertTo-CompatibleRegistryKeySnapshots -RegistryKeys @($snapshot) -PlanMap $script:DeletionPlanMap)

        $converted[0].SubKeys[0].Exists | Should -BeFalse
        $converted[0].SubKeys[0].Values | Should -HaveCount 0
    }
}

Describe 'Legacy absent-key backup compatibility' {
    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = Join-Path $PSScriptRoot '..\Regfiles'
        $script:Features = @{}
        foreach ($feature in $script:FeatureCatalog.Features) {
            $script:Features[$feature.FeatureId] = $feature
        }
        Mock Write-Error {}
    }

    It 'imports a legacy absent key for <FeatureId> as missing permitted values' -ForEach @(
        @{ FeatureId = 'RevertContextMenu'; Path = 'HKEY_USERS\Default\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; ValueNames = @('') }
        @{ FeatureId = 'DisableChromeAI'; Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Google\Chrome'; ValueNames = @('AIModeSettings', 'AutofillPredictionSettings', 'ChromeSuggestionsSettings', 'CreateThemesSettings', 'DevToolsGenAiSettings', 'FindAndFillWithGeminiSettings', 'GeminiSettings', 'GeminiSparkSettings', 'GenAILocalFoundationalModelSettings', 'HelpMeWriteSettings', 'HistorySearchSettings', 'SearchContentSharingSettings', 'SmartTabSharingSettings', 'TabCompareSettings', 'ThirdPartyAiChatSettings', 'VoiceTypingSettings') }
        @{ FeatureId = 'DisableDVR'; Path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; ValueNames = @('AllowGameDVR') }
    ) {
        $filePath = Join-Path $TestDrive "$FeatureId-legacy.json"
        [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @($FeatureId)
            RegistryKeys = @([PSCustomObject]@{ Path = $Path; Exists = $false; Values = @(); SubKeys = @() })
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $filePath -Encoding UTF8
        $originalContent = Get-Content -LiteralPath $filePath -Raw

        $normalized = Import-RegistryBackup -FilePath $filePath

        $normalized.RegistryKeys[0].Exists | Should -BeTrue
        $normalized.RegistryKeys[0].Values -is [array] | Should -BeTrue
        $normalized.RegistryKeys[0].Values | Should -HaveCount $ValueNames.Count
        @($normalized.RegistryKeys[0].Values | ForEach-Object { $_.Name } | Sort-Object) | Should -Be @($ValueNames | Sort-Object)
        @($normalized.RegistryKeys[0].Values | Where-Object { $_.Exists -or $null -ne $_.Kind -or $null -ne $_.Data }) | Should -HaveCount 0
        (Get-Content -LiteralPath $filePath -Raw) | Should -Be $originalContent
    }

    It 'rejects an unknown absent-key path instead of converting it' {
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @('DisableAnimations')
            RegistryKeys = @([PSCustomObject]@{ Path = 'HKEY_USERS\Default\Software\NotAllowedHere'; Exists = $false; Values = @(); SubKeys = @() })
        }

        { ConvertTo-NormalizedRegistryBackup -Backup $backup } | Should -Throw '*unexpected registry path*'
    }

    It 'imports a legacy value-only backup for <Target> using the correct profile paths' -ForEach @(
        @{ Target = 'CurrentUser:Alice'; Hive = 'HKEY_CURRENT_USER' }
        @{ Target = 'User:Alice'; Hive = 'HKEY_USERS\Default' }
    ) {
        Mock Test-RunningAsSystem { $false }
        Mock Test-UserNameMatch { $true }
        Mock Test-TargetUserName { [PSCustomObject]@{ IsValid = $true } }
        $path = "$Hive\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        $filePath = Join-Path $TestDrive 'legacy-profile.json'
        [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = $Target
            SelectedFeatures = @('RevertContextMenu')
            RegistryKeys = @([PSCustomObject]@{ Path = $path; Exists = $false; Values = @(); SubKeys = @() })
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $filePath -Encoding UTF8

        $normalized = Import-RegistryBackup -FilePath $filePath

        $normalized.Target | Should -Be $Target
        $normalized.RegistryKeys | Should -HaveCount 1
        $normalized.RegistryKeys[0].Path | Should -Be $path
        $normalized.RegistryKeys[0].Exists | Should -BeTrue
        $normalized.RegistryKeys[0].Values | Should -HaveCount 1
        $normalized.RegistryKeys[0].Values[0].Name | Should -Be ''
        $normalized.RegistryKeys[0].Values[0].Exists | Should -BeFalse
        if ($Target -like 'User:*') {
            Should -Invoke Test-TargetUserName -Times 1 -Exactly -ParameterFilter { $UserName -eq 'Alice' }
        }
        else {
            Should -Invoke Test-UserNameMatch -Times 1 -Exactly -ParameterFilter { $UserNameA -eq 'Alice' -and $UserNameB -eq $env:USERNAME }
        }
    }

    It 'preserves the input object when converting a legacy snapshot' {
        $snapshot = [PSCustomObject]@{ Path = 'HKEY_USERS\Default\Control Panel\Desktop'; Exists = $false; Values = @(); SubKeys = @() }
        $errors = New-Object 'System.Collections.Generic.List[string]'
        $planMap = Get-RegistryBackupValidationPlanMap -SelectedFeatureIds @('DisableAnimations') -SelectedUndoFeatureIds @() -Target 'DefaultUserProfile' -Errors $errors

        $converted = @(ConvertTo-CompatibleRegistryKeySnapshots -RegistryKeys @($snapshot) -PlanMap $planMap)

        $converted[0].Exists | Should -BeTrue
        $snapshot.Exists | Should -BeFalse
        $snapshot.Values | Should -HaveCount 0
    }

    It 'derives capture plans once for conversion and final validation' {
        Mock Get-RegistryBackupCapturePlans {
            @([PSCustomObject]@{
                Path = 'HKEY_USERS\Default\Control Panel\Desktop'; ValueNames = @('UserPreferencesMask')
                AllowDeleteKey = $false; CaptureAllValues = $false; IncludeSubKeys = $false
            })
        }
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @('DisableAnimations')
            RegistryKeys = @([PSCustomObject]@{ Path = 'HKEY_USERS\Default\Control Panel\Desktop'; Exists = $false; Values = @(); SubKeys = @() })
        }

        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup

        $normalized.RegistryKeys[0].Values[0].Name | Should -Be 'UserPreferencesMask'
        Should -Invoke Get-RegistryBackupCapturePlans -Times 1 -Exactly
    }

    It 'rejects an absent value-only key containing subkeys' {
        $path = 'HKEY_USERS\Default\Control Panel\Desktop'
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @('DisableAnimations')
            RegistryKeys = @([PSCustomObject]@{
                Path = $path; Exists = $false; Values = @()
                SubKeys = @([PSCustomObject]@{ Path = "$path\Child"; Exists = $true; Values = @(); SubKeys = @() })
            })
        }

        { ConvertTo-NormalizedRegistryBackup -Backup $backup } | Should -Throw '*Validation failed*'
        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter { $Message -like '*unauthorized registry key deletion*' }
    }
}

Describe 'Absent keys in value-only backups' {
    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = Join-Path $PSScriptRoot '..\Regfiles'
        $script:Features = @{ DisableAnimations = @($script:FeatureCatalog.Features | Where-Object FeatureId -eq 'DisableAnimations')[0] }
        $script:FakeRoot = [PSCustomObject]@{ Key = $null; DeletedTrees = [System.Collections.Generic.List[string]]::new(); CreatedKeys = [System.Collections.Generic.List[string]]::new() }
        $script:FakeRoot | Add-Member ScriptMethod OpenSubKey { param($path, $writable) $this.Key }
        $script:FakeRoot | Add-Member ScriptMethod CreateSubKey { param($path) $this.CreatedKeys.Add($path); $this.Key }
        $script:FakeRoot | Add-Member ScriptMethod DeleteSubKeyTree { param($path, $throwOnMissing) $this.DeletedTrees.Add($path) }
        Mock Get-RegistryRootKey { $script:FakeRoot }
    }

    It 'captures missing values and preserves unrelated data that appears before restore' {
        $plans = @(Get-RegistryBackupCapturePlans -SelectedRegistryFeatures @($script:Features.DisableAnimations))
        $snapshots = @(Get-RegistrySnapshotsForBackup -CapturePlans $plans)
        $snapshots | Should -HaveCount 1
        $snapshots[0].Exists | Should -BeTrue
        $snapshots[0].Values | Should -HaveCount 1
        $snapshots[0].Values[0].Name | Should -Be 'UserPreferencesMask'
        $snapshots[0].Values[0].Exists | Should -BeFalse

        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = "CurrentUser:$env:USERNAME"
            SelectedFeatures = @('DisableAnimations'); RegistryKeys = $snapshots
        } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        function Test-RunningAsSystem { $false }
        function Test-UserNameMatch { $true }
        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup

        $script:FakeRoot.Key = [PSCustomObject]@{
            Values = @{ UserPreferencesMask = 'applied'; Wallpaper = 'keep' }
            Children = @('UnrelatedChild')
        }
        $script:FakeRoot.Key | Add-Member ScriptMethod DeleteValue { param($name, $throwOnMissing) $this.Values.Remove($name) }
        $script:FakeRoot.Key | Add-Member ScriptMethod Close {}

        Restore-RegistryKeySnapshot -Snapshot $normalized.RegistryKeys[0]

        $script:FakeRoot.Key.Values.ContainsKey('UserPreferencesMask') | Should -BeFalse
        $script:FakeRoot.Key.Values.Wallpaper | Should -Be 'keep'
        $script:FakeRoot.Key.Children | Should -Be @('UnrelatedChild')
        $script:FakeRoot.DeletedTrees | Should -HaveCount 0
    }

    It 'records missing default and named values without requesting a tree deletion' {
        $snapshot = Get-RegistryKeySnapshot -KeyPath 'HKEY_CURRENT_USER\Software\Example' -ValueNames @('', 'Enabled')

        $snapshot.Exists | Should -BeTrue
        $snapshot.Values | Should -HaveCount 2
        @($snapshot.Values | Where-Object { $_.Name -eq '' }) | Should -HaveCount 1
        @($snapshot.Values | Where-Object { $_.Exists }) | Should -HaveCount 0
    }

    It 'does not create a still-absent key when restoring <Case> missing values' -ForEach @(
        @{ Case = 'new'; Legacy = $false }
        @{ Case = 'legacy'; Legacy = $true }
    ) {
        $snapshot = if ($Legacy) {
            $errors = New-Object 'System.Collections.Generic.List[string]'
            $planMap = Get-RegistryBackupValidationPlanMap -SelectedFeatureIds @('DisableAnimations') -SelectedUndoFeatureIds @() -Target 'CurrentUser' -Errors $errors
            @(ConvertTo-CompatibleRegistryKeySnapshots -RegistryKeys @([PSCustomObject]@{
                Path = 'HKEY_CURRENT_USER\Control Panel\Desktop'; Exists = $false; Values = @(); SubKeys = @()
            }) -PlanMap $planMap)[0]
        }
        else {
            Get-RegistryKeySnapshot -KeyPath 'HKEY_CURRENT_USER\Control Panel\Desktop' -ValueNames @('UserPreferencesMask')
        }

        Restore-RegistryKeySnapshot -Snapshot $snapshot

        $script:FakeRoot.CreatedKeys | Should -HaveCount 0
        $script:FakeRoot.DeletedTrees | Should -HaveCount 0
    }

    It 'restores legacy missing values without removing unrelated data' {
        $errors = New-Object 'System.Collections.Generic.List[string]'
        $planMap = Get-RegistryBackupValidationPlanMap -SelectedFeatureIds @('DisableAnimations') -SelectedUndoFeatureIds @() -Target 'CurrentUser' -Errors $errors
        $snapshot = @(ConvertTo-CompatibleRegistryKeySnapshots -RegistryKeys @([PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Control Panel\Desktop'; Exists = $false; Values = @(); SubKeys = @()
        }) -PlanMap $planMap)[0]
        $script:FakeRoot.Key = [PSCustomObject]@{ Values = @{ UserPreferencesMask = 'applied'; Wallpaper = 'keep' }; Children = @('UnrelatedChild') }
        $script:FakeRoot.Key | Add-Member ScriptMethod DeleteValue { param($name, $throwOnMissing) $this.Values.Remove($name) }
        $script:FakeRoot.Key | Add-Member ScriptMethod Close {}

        Restore-RegistryKeySnapshot -Snapshot $snapshot

        $script:FakeRoot.Key.Values.ContainsKey('UserPreferencesMask') | Should -BeFalse
        $script:FakeRoot.Key.Values.Wallpaper | Should -Be 'keep'
        $script:FakeRoot.Key.Children | Should -Be @('UnrelatedChild')
        $script:FakeRoot.CreatedKeys | Should -HaveCount 0
        $script:FakeRoot.DeletedTrees | Should -HaveCount 0
    }
}
