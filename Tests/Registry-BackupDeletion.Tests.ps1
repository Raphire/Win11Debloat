BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Registry-PathHelpers.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-RegFileOperations.ps1')
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
                [PSCustomObject]@{ Path = 'HKEY_USERS\Default\Control Panel\Desktop'; Exists = $false; Values = @(); SubKeys = @() }
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
}

Describe 'Absent keys in value-only backups' {
    BeforeEach {
        $script:Params = @{}
        $script:RegfilesPath = Join-Path $PSScriptRoot '..\Regfiles'
        $script:Features = @{ DisableAnimations = @($script:FeatureCatalog.Features | Where-Object FeatureId -eq 'DisableAnimations')[0] }
        $script:FakeRoot = [PSCustomObject]@{ Key = $null; DeletedTrees = [System.Collections.Generic.List[string]]::new() }
        $script:FakeRoot | Add-Member ScriptMethod OpenSubKey { param($path, $writable) $this.Key }
        $script:FakeRoot | Add-Member ScriptMethod CreateSubKey { param($path) $this.Key }
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
}
