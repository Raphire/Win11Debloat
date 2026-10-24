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
        Mock Write-Warning {}
        $script:RegfilesPath = Join-Path $PSScriptRoot '..\Regfiles'
        $script:Features = @{}
        foreach ($feature in $script:FeatureCatalog.Features) {
            $script:Features[$feature.FeatureId] = $feature
        }
    }

    It 'skips retired Drag Tray data in an existing backup (undo: <Undo>, absent key: <Absent>)' -ForEach @(
        @{ Undo = $false; Absent = $false }
        @{ Undo = $true; Absent = $false }
        @{ Undo = $false; Absent = $true }
    ) {
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @(if (-not $Undo) { 'DisableDragTray' })
            SelectedUndoFeatures = @(if ($Undo) { 'DisableDragTray' })
            RegistryKeys = @([PSCustomObject]@{
                Path = 'HKEY_USERS\Default\Software\Microsoft\Windows\CurrentVersion\CDP'
                Exists = -not $Absent
                Values = @(if (-not $Absent) { [PSCustomObject]@{ Name = 'DragTrayEnabled'; Exists = $true; Kind = 'DWord'; Data = 1 } })
                SubKeys = @()
            })
        }

        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup

        $normalized.RegistryKeys | Should -BeNullOrEmpty
        # Restore normalizes a second time, so skipping must be idempotent.
        (ConvertTo-NormalizedRegistryBackup -Backup $normalized).RegistryKeys | Should -BeNullOrEmpty
    }

    It 'warns for each unknown value beside a retired value' {
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CDP'
            Exists = $true
            Values = @(
                [PSCustomObject]@{ Name = 'DragTrayEnabled'; Exists = $true; Kind = 'DWord'; Data = 1 }
                [PSCustomObject]@{ Name = 'OtherValue'; Exists = $true; Kind = 'DWord'; Data = 1 }
            )
            SubKeys = @()
        }

        $normalized = @(ConvertTo-CompatibleRegistryKeySnapshots -RegistryKeys @($snapshot) -PlanMap @{})

        $normalized | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*DragTrayEnabled*' }
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*OtherValue*' }
    }

    It 'ignores additional unknown features without retirement definitions' {
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @('RetiredOne'); SelectedUndoFeatures = @('RetiredTwo')
            RegistryKeys = @([PSCustomObject]@{
                Path = 'HKEY_USERS\Default\Software\Retired'; Exists = $true; SubKeys = @()
                Values = @('First', 'Second', 'Third' | ForEach-Object {
                    [PSCustomObject]@{ Name = $_; Exists = $true; Kind = 'DWord'; Data = 1 }
                })
            })
        }

        (ConvertTo-NormalizedRegistryBackup -Backup $backup).RegistryKeys | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "*feature 'RetiredOne'*" }
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "*feature 'RetiredTwo'*" }
        Should -Invoke Write-Warning -Times 3 -Exactly -ParameterFilter { $Message -like '*registry value*' }
    }

    It 'preserves known values while dropping unknown values and child keys' {
        $path = 'HKEY_USERS\Default\Control Panel\Desktop'
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @('DisableAnimations', 'UnknownFeature')
            RegistryKeys = @([PSCustomObject]@{
                Path = $path; Exists = $true
                Values = @(
                    [PSCustomObject]@{ Name = 'UserPreferencesMask'; Exists = $true; Kind = 'Binary'; Data = @(144, 18, 7, 128, 16, 0, 0, 0) }
                    [PSCustomObject]@{ Name = 'OldSetting'; Exists = $true; Kind = 'Invalid'; Data = 'ignored' }
                )
                SubKeys = @([PSCustomObject]@{
                    Path = "$path\OldChild"; Exists = $true; SubKeys = @()
                    Values = @([PSCustomObject]@{ Name = ''; Exists = $true; Kind = 'String'; Data = 'ignored' })
                })
            })
        }

        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup
        $normalized.RegistryKeys | Should -HaveCount 1
        $normalized.RegistryKeys[0].Values | Should -HaveCount 1
        $normalized.RegistryKeys[0].Values[0].Name | Should -Be 'UserPreferencesMask'
        $normalized.RegistryKeys[0].SubKeys | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*OldSetting*' }
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*OldChild*(Default)*' }

        $backup.RegistryKeys[0].Values[0].Data = @(256)
        Mock Write-Error {}
        { ConvertTo-NormalizedRegistryBackup -Backup $backup } | Should -Throw '*Validation failed*'
    }

    It 'drops an emptied known key without creating or deleting it (exists: <Exists>)' -ForEach @(
        @{ Exists = $true }
        @{ Exists = $false }
    ) {
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @('DisableAnimations')
            RegistryKeys = @([PSCustomObject]@{
                Path = 'HKEY_USERS\Default\Control Panel\Desktop'; Exists = $Exists; SubKeys = @()
                Values = @([PSCustomObject]@{ Name = 'OldSetting'; Exists = $false })
            })
        }

        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup
        $normalized.RegistryKeys | Should -BeNullOrEmpty
        (ConvertTo-NormalizedRegistryBackup -Backup $normalized).RegistryKeys | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*OldSetting*' }
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

    It 'requires confirmation or blocks a doctored <Case> before any restore calls' -ForEach @(
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
            SelectedFeatures = @(if (-not $Undo) { $FeatureId })
            SelectedUndoFeatures = @(if ($Undo) { $FeatureId })
            RegistryKeys = @([PSCustomObject]@{
                Path = $Path; Exists = $true; Values = @([PSCustomObject]@{ Name = $Name; Exists = $true; Kind = $Kind; Data = $Data }); SubKeys = @()
            })
            # Backup-provided trust information must have no effect.
            TrustedValueMap = @{ Command = $Data }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $filePath -Encoding UTF8

        if ($Case -eq 'undefined value kind') {
            { Import-RegistryBackup -FilePath $filePath } | Should -Throw '*Validation failed*'
        }
        else {
            $normalized = Import-RegistryBackup -FilePath $filePath
            $normalized.ExecutableValueWarnings | Should -HaveCount 1
            { Restore-RegistryBackupState -Backup $normalized } | Should -Throw '*requires explicit confirmation*'
        }

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
            SelectedFeatures = @(if (-not $Undo) { 'DisableGameBarIntegration' })
            SelectedUndoFeatures = @(if ($Undo) { 'DisableGameBarIntegration' })
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
            RegistryKeys = @([PSCustomObject]@{
                Path = $desktop.Path; Exists = $true; Values = @(); SubKeys = @($desktop)
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

    It 'ignores an unknown absent-key path instead of converting or deleting it' {
        Mock Write-Warning {}
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @('DisableAnimations')
            RegistryKeys = @([PSCustomObject]@{ Path = 'HKEY_USERS\Default\Software\NotAllowedHere'; Exists = $false; Values = @(); SubKeys = @() })
        }

        (ConvertTo-NormalizedRegistryBackup -Backup $backup).RegistryKeys | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*NotAllowedHere*' }
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

    It 'skips an unknown child and its emptied absent parent without requesting deletion' {
        Mock Write-Warning {}
        $path = 'HKEY_USERS\Default\Control Panel\Desktop'
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = 'DefaultUserProfile'
            SelectedFeatures = @('DisableAnimations')
            RegistryKeys = @([PSCustomObject]@{
                Path = $path; Exists = $false; Values = @()
                SubKeys = @([PSCustomObject]@{ Path = "$path\Child"; Exists = $true; Values = @(); SubKeys = @() })
            })
        }

        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup

        $normalized.RegistryKeys | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq "Skipping unknown backup registry key '$path\Child'." }
        Should -Invoke Write-Error -Times 0 -Exactly
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
        $script:FakeRoot.Key | Add-Member ScriptMethod GetValueNames { @($this.Values.Keys) }
        $script:FakeRoot.Key | Add-Member ScriptMethod GetSubKeyNames { @($this.Children) }

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
        $script:FakeRoot.Key | Add-Member ScriptMethod GetValueNames { @($this.Values.Keys) }
        $script:FakeRoot.Key | Add-Member ScriptMethod GetSubKeyNames { @($this.Children) }

        Restore-RegistryKeySnapshot -Snapshot $snapshot

        $script:FakeRoot.Key.Values.ContainsKey('UserPreferencesMask') | Should -BeFalse
        $script:FakeRoot.Key.Values.Wallpaper | Should -Be 'keep'
        $script:FakeRoot.Key.Children | Should -Be @('UnrelatedChild')
        $script:FakeRoot.CreatedKeys | Should -HaveCount 0
        $script:FakeRoot.DeletedTrees | Should -HaveCount 0
    }
}

Describe 'Executable registry restore confirmation' {
    BeforeAll {
        function New-ExecutableTestBackup {
            param($FeatureId = 'DisableGameBarIntegration', $Path = 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command', $Name = '', $Data = 'cmd.exe /c echo custom', $Kind = 'String', $Target = 'DefaultUserProfile')
            [PSCustomObject]@{
                Version = '1.0'; BackupType = 'RegistryState'; Target = $Target
                SelectedFeatures = @($FeatureId); SelectedUndoFeatures = @()
                RegistryKeys = @([PSCustomObject]@{
                    Path = $Path; Exists = $true; SubKeys = @()
                    Values = @([PSCustomObject]@{ Name = $Name; Exists = $true; Kind = $Kind; Data = $Data })
                })
                # These untrusted fields must never bypass validation or confirmation.
                ExecutableValueWarnings = @(); Approved = $true
            }
        }
    }

    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = Join-Path $PSScriptRoot '..\Regfiles'
        $script:Features = @{}
        foreach ($feature in $script:FeatureCatalog.Features) { $script:Features[$feature.FeatureId] = $feature }
        Mock Write-Error {}
        Mock Restore-RegistryKeySnapshot {}
        Mock Invoke-WithLoadedRestoreHive {
            param($Target, $ScriptBlock, $ArgumentObject)
            & $ScriptBlock $ArgumentObject
        }
    }

    It 'accepts the shipped <File> search command for a HideSearchTb backup' -ForEach @(
        @{ File = 'Hide_Search_Taskbar.reg' }
        @{ File = 'Show_Search_Icon.reg' }
        @{ File = 'Show_Search_Icon_And_Label.reg' }
        @{ File = 'Show_Search_Box.reg' }
    ) {
        $op = @(Get-RegFileOperations -regFilePath (Join-Path $script:RegfilesPath "Sysprep\$File") | Where-Object ValueName -eq 'SetTaskbarSearchbox')[0]
        $backup = New-ExecutableTestBackup -FeatureId 'HideSearchTb' -Path $op.KeyPath -Name $op.ValueName -Data $op.ValueData
        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup
        $normalized.ExecutableValueWarnings | Should -HaveCount 0
        (Restore-RegistryBackupState -Backup $normalized -ConfirmUntrustedValues { throw 'Unexpected prompt' }).Result | Should -BeTrue
    }

    It 'validates shipped and altered handlers for <FeatureId>' -ForEach @(
        @{ FeatureId = 'HideShare' }
        @{ FeatureId = 'HideGiveAccessTo' }
        @{ FeatureId = 'HideIncludeInLibrary' }
    ) {
        $file = Resolve-RegistryBackupUndoFilePath -Feature $script:Features[$FeatureId]
        foreach ($op in @(Get-RegFileOperations -regFilePath $file | Where-Object OperationType -eq 'SetValue')) {
            Test-RegistryValueMayExecuteCode -Path $op.KeyPath -ValueName $op.ValueName -KindName $op.ValueType | Should -BeTrue
            $backup = New-ExecutableTestBackup -FeatureId $FeatureId -Path $op.KeyPath -Name $op.ValueName -Data $op.ValueData
            (ConvertTo-NormalizedRegistryBackup -Backup $backup).ExecutableValueWarnings | Should -HaveCount 0
            $backup.RegistryKeys[0].Values[0].Data = '{00000000-0000-0000-0000-000000000001}'
            (ConvertTo-NormalizedRegistryBackup -Backup $backup).ExecutableValueWarnings | Should -HaveCount 1
        }
    }

    It 'cancels without writes or hive loading when the callback returns <Response>' -ForEach @(
        @{ Response = $false }
        @{ Response = $null }
        @{ Response = 'true' }
    ) {
        Mock Write-Host {}
        $backup = New-ExecutableTestBackup
        (Restore-RegistryBackupState -Backup $backup -ConfirmUntrustedValues { $Response }).Result | Should -BeFalse
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like 'Registry restore canceled:*' }
        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }

    It 'shows all mismatches before writes and restores only after explicit approval' {
        Mock Write-Host {}
        $backup = New-ExecutableTestBackup
        $backup.RegistryKeys += (New-ExecutableTestBackup -Path 'HKEY_CLASSES_ROOT\ms-gamebarservices\shell\open\command' -Data 'custom.exe').RegistryKeys
        $script:confirmationCount = 0
        $confirm = {
            param($mismatches)
            $script:confirmationCount++
            $mismatches | Should -HaveCount 2
            $mismatches[0].Path | Should -Be 'HKEY_CLASSES_ROOT\ms-gamebar\shell\open\command'
            $mismatches[0].Name | Should -Be ''
            $mismatches[0].Kind | Should -Be 'String'
            $mismatches[0].Data | Should -Be 'cmd.exe /c echo custom'
            Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
            Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
            return $true
        }
        (Restore-RegistryBackupState -Backup $backup -ConfirmUntrustedValues $confirm).Result | Should -BeTrue
        $script:confirmationCount | Should -Be 1
        Should -Invoke Write-Host -Times 2 -Exactly -ParameterFilter { $Object -like 'Unrecognized executable registry setting:*' }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -eq 'User approved restoring the unrecognized executable settings.' }
        Should -Invoke Restore-RegistryKeySnapshot -Times 2 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 1 -Exactly
    }

    It 'requires fresh confirmation on every restore even when backup flags claim approval' {
        $backup = ConvertTo-NormalizedRegistryBackup -Backup (New-ExecutableTestBackup)
        $backup.ExecutableValueWarnings = @()
        { Restore-RegistryBackupState -Backup $backup } | Should -Throw '*requires explicit confirmation*'
        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }

    It 'skips <Case> with a warning and never restores it or asks for confirmation' -ForEach @(
        @{ Case = 'an unauthorized path' }
        @{ Case = 'an unauthorized value name' }
    ) {
        Mock Write-Warning {}
        $backup = New-ExecutableTestBackup
        if ($Case -eq 'an unauthorized path') {
            $backup.RegistryKeys[0].Path = 'HKEY_LOCAL_MACHINE\Software\Unrelated'
        }
        else {
            $backup.RegistryKeys[0].Values[0].Name = 'Unrelated'
        }

        $result = Restore-RegistryBackupState -Backup $backup -ConfirmUntrustedValues { throw 'Confirmation must not be reached' }

        $result.Result | Should -BeTrue
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like 'Skipping unknown backup registry value *Unrelated*' }
        Should -Invoke Write-Error -Times 0 -Exactly
        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 1 -Exactly -ParameterFilter { @($ArgumentObject.RegistryKeys).Count -eq 0 }
    }

    It 'does not permit overriding <Case>' -ForEach @(
        @{ Case = 'an unauthorized tree deletion' }
        @{ Case = 'an invalid kind' }
        @{ Case = 'a misplaced child' }
    ) {
        $backup = New-ExecutableTestBackup
        switch ($Case) {
            'an unauthorized tree deletion' { $backup.RegistryKeys[0].Exists = $false }
            'an invalid kind' { $backup.RegistryKeys[0].Values[0].Kind = '99' }
            'a misplaced child' { $backup.RegistryKeys[0].SubKeys = (New-ExecutableTestBackup -Path 'HKEY_CLASSES_ROOT\ms-gamebarservices\shell\open\command').RegistryKeys }
        }
        { Restore-RegistryBackupState -Backup $backup -ConfirmUntrustedValues { throw 'Confirmation must not be reached' } } | Should -Throw '*Validation failed*'
        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }

    It 'honors WhatIf without prompting, writes, or hive loading' {
        $script:Params = @{ WhatIf = $true }
        (Restore-RegistryBackupState -Backup (New-ExecutableTestBackup) -ConfirmUntrustedValues { throw 'Unexpected prompt' }).Result | Should -BeTrue
        Should -Invoke Restore-RegistryKeySnapshot -Times 0 -Exactly
        Should -Invoke Invoke-WithLoadedRestoreHive -Times 0 -Exactly
    }
}

Describe 'Trusted empty-key cleanup' {
    BeforeEach {
        function Test-RunningAsSystem { $false }
        Mock Test-TargetUserName { [PSCustomObject]@{ IsValid = $true } }
        $script:Params = @{}
        $script:RegfilesPath = Join-Path $PSScriptRoot '..\Regfiles'
        $script:Features = @{}
        foreach ($feature in $script:FeatureCatalog.Features) { $script:Features[$feature.FeatureId] = $feature }
        $script:CleanupRoot = [PSCustomObject]@{
            Key = $null
            DeletedKeys = [System.Collections.Generic.List[string]]::new()
        }
        $script:CleanupRoot | Add-Member ScriptMethod OpenSubKey { param($path, $writable) $this.Key }
        $script:CleanupRoot | Add-Member ScriptMethod DeleteSubKey { param($path, $throwOnMissing) $this.DeletedKeys.Add($path) }
        $script:CleanupRoot | Add-Member ScriptMethod DeleteSubKeyTree { throw 'Recursive deletion must not be used' }
        $script:CleanupRoot | Add-Member ScriptMethod CreateSubKey { throw 'Absent cleanup must not create keys' }
        Mock Invoke-RegistryEmptyKeyDeletion {
            param($RootKey, $SubKeyPath)
            if ($RootKey.Key.Values.Count -gt 0 -or $RootKey.Key.Children) { return 145 }
            $RootKey.DeletedKeys.Add($SubKeyPath)
            return 0
        }
        Mock Get-RegistryRootKey { $script:CleanupRoot }
        Mock Write-Error {}
    }

    It 'removes an originally absent context-menu key after JSON import and revalidation for <Target>' -ForEach @(
        @{ Target = 'DefaultUserProfile'; Hive = 'HKEY_USERS\Default' }
        @{ Target = 'User:Alice'; Hive = 'HKEY_USERS\Default' }
        @{ Target = 'CurrentUser'; Hive = 'HKEY_CURRENT_USER' }
    ) {
        $path = "$Hive\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
        $snapshot = Get-RegistryKeySnapshot -KeyPath $path -ValueNames @('')
        $snapshot.OriginallyAbsent | Should -BeTrue
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'
            Target = if ($Target -eq 'CurrentUser') { "CurrentUser:$env:USERNAME" } else { $Target }
            SelectedFeatures = @('RevertContextMenu'); RegistryKeys = @($snapshot)
        } | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup
        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $normalized
        $normalized.RegistryKeys[0].RemoveEmptyKey | Should -BeTrue
        $script:CleanupRoot.Key = [PSCustomObject]@{ Values = @{ '' = '' } }
        $script:CleanupRoot.Key | Add-Member ScriptMethod DeleteValue { param($name, $throwOnMissing) $this.Values.Remove($name) }
        $script:CleanupRoot.Key | Add-Member ScriptMethod GetValueNames { @($this.Values.Keys) }
        $script:CleanupRoot.Key | Add-Member ScriptMethod GetSubKeyNames { @() }
        $script:CleanupRoot.Key | Add-Member ScriptMethod Close {}

        Restore-RegistryKeySnapshot -Snapshot $normalized.RegistryKeys[0]

        $script:CleanupRoot.Key.Values.Count | Should -Be 0
        $script:CleanupRoot.DeletedKeys | Should -HaveCount 1
        $script:CleanupRoot.DeletedKeys[0] | Should -BeLike '*\InprocServer32'
    }

    It 'preserves a key with <Case>' -ForEach @(
        @{ Case = 'an unrelated value'; ExtraValue = $true; Child = $false }
        @{ Case = 'an unrelated child'; ExtraValue = $false; Child = $true }
    ) {
        $path = 'HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        $snapshot = Get-RegistryKeySnapshot -KeyPath $path -ValueNames @('')
        $errors = New-Object 'System.Collections.Generic.List[string]'
        $plans = Get-RegistryBackupValidationPlanMap -SelectedFeatureIds @('RevertContextMenu') -SelectedUndoFeatureIds @() -Target 'CurrentUser' -Errors $errors
        $snapshot = @(ConvertTo-CompatibleRegistryKeySnapshots -RegistryKeys @([PSCustomObject]$snapshot) -PlanMap $plans)[0]
        $script:CleanupRoot.Key = [PSCustomObject]@{ Values = @{ '' = '' }; Children = @(if ($Child) { 'KeepChild' }) }
        if ($ExtraValue) { $script:CleanupRoot.Key.Values['KeepValue'] = 'keep' }
        $script:CleanupRoot.Key | Add-Member ScriptMethod DeleteValue { param($name, $throwOnMissing) $this.Values.Remove($name) }
        $script:CleanupRoot.Key | Add-Member ScriptMethod GetValueNames { @($this.Values.Keys) }
        $script:CleanupRoot.Key | Add-Member ScriptMethod GetSubKeyNames { @($this.Children) }
        $script:CleanupRoot.Key | Add-Member ScriptMethod Close {}

        Restore-RegistryKeySnapshot -Snapshot $snapshot

        $script:CleanupRoot.Key.Values.ContainsKey('') | Should -BeFalse
        if ($ExtraValue) { $script:CleanupRoot.Key.Values['KeepValue'] | Should -Be 'keep' }
        if ($Child) { $script:CleanupRoot.Key.Children | Should -Be 'KeepChild' }
        $script:CleanupRoot.DeletedKeys | Should -HaveCount 0
    }

    It 'derives legacy absent-key cleanup from the trusted plan' {
        $path = 'HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        $errors = New-Object 'System.Collections.Generic.List[string]'
        $plans = Get-RegistryBackupValidationPlanMap -SelectedFeatureIds @('RevertContextMenu') -SelectedUndoFeatureIds @() -Target 'CurrentUser' -Errors $errors
        $snapshot = [PSCustomObject]@{ Path = $path; Exists = $false; Values = @(); SubKeys = @() }
        $normalized = @(ConvertTo-CompatibleRegistryKeySnapshots -RegistryKeys @($snapshot) -PlanMap $plans)[0]
        $normalized.RemoveEmptyKey | Should -BeTrue
        $normalized.OriginallyAbsent | Should -BeTrue
    }

    It 'does not trust a backup-supplied cleanup flag for an originally existing key' {
        $path = 'HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        $snapshot = [PSCustomObject]@{
            Path = $path; Exists = $true; RemoveEmptyKey = $true
            Values = @([PSCustomObject]@{ Name = ''; Exists = $false }); SubKeys = @()
        }
        $backup = [PSCustomObject]@{
            Version = '1.0'; BackupType = 'RegistryState'; Target = "CurrentUser:$env:USERNAME"
            SelectedFeatures = @('RevertContextMenu'); RegistryKeys = @($snapshot)
        }
        $normalized = ConvertTo-NormalizedRegistryBackup -Backup $backup
        $normalized.RegistryKeys[0].RemoveEmptyKey | Should -BeFalse
        $script:CleanupRoot.Key = [PSCustomObject]@{ Values = @{} }
        $script:CleanupRoot.Key | Add-Member ScriptMethod DeleteValue { param($name, $throwOnMissing) $this.Values.Remove($name) }
        $script:CleanupRoot.Key | Add-Member ScriptMethod Close {}

        Restore-RegistryKeySnapshot -Snapshot $normalized.RegistryKeys[0]

        $script:CleanupRoot.DeletedKeys | Should -HaveCount 0
    }

    It 'does not authorize cleanup for a descendant of a recursive plan' {
        $path = 'HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\TreatAs'
        $snapshot = [PSCustomObject]@{ Path = $path; Exists = $true; OriginallyAbsent = $true; Values = @(); SubKeys = @() }
        $errors = New-Object 'System.Collections.Generic.List[string]'
        $plans = Get-RegistryBackupValidationPlanMap -SelectedFeatureIds @() -SelectedUndoFeatureIds @('RevertContextMenu') -Target 'CurrentUser' -Errors $errors
        $normalized = @(ConvertTo-CompatibleRegistryKeySnapshots -RegistryKeys @($snapshot) -PlanMap $plans)[0]
        $normalized.RemoveEmptyKey | Should -BeFalse
    }
}

Describe 'Empty-key cleanup when registry contents change' {
    BeforeEach {
        . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1')
        $script:ConcurrentKey = [PSCustomObject]@{ Values = @{}; Children = @(); Closed = $false }
        $script:ConcurrentKey | Add-Member ScriptMethod GetValueNames { @($this.Values.Keys) }
        $script:ConcurrentKey | Add-Member ScriptMethod GetSubKeyNames { @($this.Children) }
        $script:ConcurrentKey | Add-Member ScriptMethod DeleteValue { param($name, $missing) $this.Values.Remove($name) }
        $script:ConcurrentKey | Add-Member ScriptMethod Close { $this.Closed = $true }
        $script:ConcurrentRoot = [PSCustomObject]@{ Key = $script:ConcurrentKey }
        $script:ConcurrentRoot | Add-Member ScriptMethod OpenSubKey { param($path, $writable) $this.Key }
        $script:ConcurrentRoot | Add-Member ScriptMethod DeleteSubKey { throw 'Unconditional key deletion must not be used' }
        Mock Invoke-RegistryEmptyKeyDeletion { 0 }
    }

    It 'retains a value added after the restore emptiness check' {
        $script:ConcurrentKey.Values[''] = 'applied'
        $script:ConcurrentKey | Add-Member ScriptMethod Close { $this.Values['KeepValue'] = 'concurrent data' } -Force
        Mock Invoke-RegistryEmptyKeyDeletion {
            $script:ConcurrentKey.Values['KeepValue'] | Should -Be 'concurrent data'
            return 145
        }
        $snapshot = [PSCustomObject]@{
            Path = 'HKEY_CURRENT_USER\Software\Example'; Exists = $true; RemoveEmptyKey = $true
            Values = @([PSCustomObject]@{ Name = ''; Exists = $false }); SubKeys = @()
        }

        Restore-RegistryKeySnapshotAtPath -Snapshot $snapshot -RootKey $script:ConcurrentRoot -SubKeyPath 'Software\Example'

        $script:ConcurrentKey.Values['KeepValue'] | Should -Be 'concurrent data'
        Should -Invoke Invoke-RegistryEmptyKeyDeletion -Times 1 -Exactly
    }

    It 'retains a child key added before empty-only deletion' {
        $script:ConcurrentKey.Children = @('KeepChild')
        Mock Invoke-RegistryEmptyKeyDeletion { 145 }

        { Remove-RegistryEmptyKeyIfExists -RootKey $script:ConcurrentRoot -SubKeyPath 'Software\Example' } | Should -Not -Throw

        $script:ConcurrentKey.Children | Should -Be 'KeepChild'
        $script:ConcurrentKey.Closed | Should -BeTrue
    }

    It 'accepts native status <Status> without reopening the key' -ForEach @(
        @{ Status = 0 }
        @{ Status = 2 }
        @{ Status = 3 }
    ) {
        Mock Invoke-RegistryEmptyKeyDeletion { $Status }
        $script:ConcurrentRoot | Add-Member ScriptMethod OpenSubKey { throw 'Key should not be reopened' } -Force

        { Remove-RegistryEmptyKeyIfExists -RootKey $script:ConcurrentRoot -SubKeyPath 'Software\Example' } | Should -Not -Throw
    }

    It 'does not hide a native error when the key is still empty' {
        Mock Invoke-RegistryEmptyKeyDeletion { 5 }

        { Remove-RegistryEmptyKeyIfExists -RootKey $script:ConcurrentRoot -SubKeyPath 'Software\Example' } | Should -Throw
        $script:ConcurrentKey.Closed | Should -BeTrue
    }

    It 'accepts a key that disappears after the native call' {
        Mock Invoke-RegistryEmptyKeyDeletion { 145 }
        $script:ConcurrentRoot.Key = $null

        { Remove-RegistryEmptyKeyIfExists -RootKey $script:ConcurrentRoot -SubKeyPath 'Software\Example' } | Should -Not -Throw
    }
}
