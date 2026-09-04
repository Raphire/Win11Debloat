BeforeAll {
    function Import-RegistryFile { param($Message, $path) }
    function Remove-SelectedApps { param($Apps) $true }
    function Invoke-ForceRemoveEdge { $true }
    function Disable-TelemetryScheduledTasks { $true }
    function Enable-TelemetryScheduledTasks { $true }
    function Generate-AppsList { @() }
    function Get-FriendlyTargetUserName { 'current user' }
    function Set-StoreSearchSuggestionsEnabledForAllUsers { $true }
    function Set-StoreSearchSuggestionsEnabled { param($StoreAppsDatabase) $true }
    function Get-StoreAppsDatabasePathForUser { param($UserName) 'store.db' }
    function Get-UserName { 'Alice' }
    function Disable-WindowsFeature { param($FeatureName) $true }
    function New-RegistrySettingsBackup { param($ActionableKeys, $ExtraFeatures) }
    function Invoke-SystemRestorePoint {}
    function Enable-WindowsFeature { param($FeatureName) $true }
    function Get-StartMenuBinPathForUser { param($UserName) 'start.bin' }
    function Replace-StartMenu { param($startMenuBinFile, $startMenuTemplate) $true }
    function Replace-StartMenuForAllUsers { param($startMenuTemplate) $true }
    function Set-StoreSearchSuggestionsDisabledForAllUsers { $true }
    function Set-StoreSearchSuggestionsDisabled { param($StoreAppsDatabase) $true }

    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Invoke-Changes.ps1')

    # Builds a $script:Lang fixture whose Features section mirrors $script:Features exactly,
    # so Get-Translation resolves the same ApplyText/UndoLabel/ApplyUndoText text the fake
    # FeatureIds in this file's fixtures expect, without duplicating per-test lookup data.
    function Sync-TestLangFeatures {
        $langFeatures = @{}
        foreach ($featureId in $script:Features.Keys) {
            $feature = $script:Features[$featureId]
            $entry = @{}
            foreach ($field in 'ApplyText', 'UndoLabel', 'ApplyUndoText') {
                if ($null -ne $feature.$field) { $entry[$field] = [string]$feature.$field }
            }
            $langFeatures[$featureId] = [PSCustomObject]$entry
        }

        $script:Lang = [PSCustomObject]@{
            LanguageCode = 'en-US'
            Chrome       = [PSCustomObject]@{}
            Features     = [PSCustomObject]$langFeatures
            UiGroups     = [PSCustomObject]@{}
            Categories   = [PSCustomObject]@{}
        }
    }
}

Describe 'Resolve-UndoRegFilePath' {
    BeforeEach {
        $script:RegfilesPath = $TestDrive
        New-Item -ItemType Directory -Path (Join-Path $TestDrive 'Undo') -Force | Out-Null
    }

    It '<Case>' -ForEach @(
        @{ Case = 'prefers an existing file in Undo'; FileName = 'feature.reg'; CreateUndoFile = $true; Expected = 'Undo\feature.reg' }
        @{ Case = 'falls back to the original file name'; FileName = 'missing.reg'; CreateUndoFile = $false; Expected = 'missing.reg' }
    ) {
        if ($CreateUndoFile) {
            '' | Set-Content -LiteralPath (Join-Path $TestDrive "Undo\$FileName")
        }

        Resolve-UndoRegFilePath -FileName $FileName | Should -Be $Expected
    }
}

Describe 'Invoke-FeatureApply' {
    BeforeEach {
        $script:Params = @{}
        $script:Features = @{
            RegistryFeature = [PSCustomObject]@{ ApplyText = 'Apply registry feature'; RegistryKey = 'feature.reg' }
            DisableTelemetry = [PSCustomObject]@{ ApplyText = 'Disable telemetry'; RegistryKey = 'telemetry.reg' }
            DisableBing = [PSCustomObject]@{ ApplyText = 'Disable Bing'; RegistryKey = 'bing.reg' }
            DisableCopilot = [PSCustomObject]@{ ApplyText = 'Disable Copilot'; RegistryKey = 'copilot.reg' }
            RemoveApps = [PSCustomObject]@{ ApplyText = 'Remove apps'; RegistryKey = '' }
            RemoveGamingApps = [PSCustomObject]@{ ApplyText = 'Remove gaming'; RegistryKey = '' }
            RemoveHPApps = [PSCustomObject]@{ ApplyText = 'Remove HP'; RegistryKey = '' }
            ForceRemoveEdge = [PSCustomObject]@{ ApplyText = 'Force remove Edge'; RegistryKey = '' }
            DisableWidgets = [PSCustomObject]@{ ApplyText = 'Disable widgets'; RegistryKey = '' }
            EnableWindowsSandbox = [PSCustomObject]@{ ApplyText = 'Enable Sandbox'; RegistryKey = '' }
            EnableWindowsSubsystemForLinux = [PSCustomObject]@{ ApplyText = 'Enable WSL'; RegistryKey = '' }
            ClearStart = [PSCustomObject]@{ ApplyText = 'Clear Start'; RegistryKey = '' }
            ReplaceStart = [PSCustomObject]@{ ApplyText = 'Replace Start'; RegistryKey = '' }
            ClearStartAllUsers = [PSCustomObject]@{ ApplyText = 'Clear Start all users'; RegistryKey = '' }
            ReplaceStartAllUsers = [PSCustomObject]@{ ApplyText = 'Replace Start all users'; RegistryKey = '' }
            DisableStoreSearchSuggestions = [PSCustomObject]@{ ApplyText = 'Disable Store suggestions'; RegistryKey = '' }
        }
        Sync-TestLangFeatures
        Mock Import-RegistryFile { $true }
        Mock Remove-SelectedApps { $true }
        Mock Invoke-ForceRemoveEdge { $true }
        Mock Disable-TelemetryScheduledTasks { $true }
        Mock Generate-AppsList { @() }
        Mock Get-FriendlyTargetUserName { 'current user' }
        Mock Enable-WindowsFeature { $true }
        Mock Get-StartMenuBinPathForUser { 'start.bin' }
        Mock Get-UserName { 'Alice' }
        Mock Replace-StartMenu { $true }
        Mock Replace-StartMenuForAllUsers { $true }
        Mock Set-StoreSearchSuggestionsDisabledForAllUsers { $true }
        Mock Set-StoreSearchSuggestionsDisabled { $true }
        Mock Get-StoreAppsDatabasePathForUser { 'store.db' }
        Mock Get-Process { @() }
        Mock Stop-Process { param($InputObject) }
        Mock Write-Host {}
    }

    It 'imports a registry-backed feature' {
        Invoke-FeatureApply -FeatureId 'RegistryFeature'

        Should -Invoke Import-RegistryFile -Times 1 -Exactly -ParameterFilter { $path -eq 'feature.reg' }
        Should -Invoke Remove-SelectedApps -Times 0 -Exactly
    }

    It 'runs the telemetry side effect after importing its registry file' {
        Invoke-FeatureApply -FeatureId 'DisableTelemetry'

        Should -Invoke Import-RegistryFile -Times 1 -Exactly
        Should -Invoke Disable-TelemetryScheduledTasks -Times 1 -Exactly
    }

    It 'returns false without side effects when a registry import fails' {
        Mock Import-RegistryFile { $false }

        Invoke-FeatureApply -FeatureId 'DisableTelemetry' | Should -BeFalse

        Should -Invoke Disable-TelemetryScheduledTasks -Times 0 -Exactly
    }

    It 'does not call app removal when the generated selection is empty' {
        Invoke-FeatureApply -FeatureId 'RemoveApps'

        Should -Invoke Generate-AppsList -Times 1 -Exactly
        Should -Invoke Remove-SelectedApps -Times 0 -Exactly
    }

    It 'passes a non-empty generated selection to app removal' {
        Mock Generate-AppsList { @('One.App', 'Two.App') }

        Invoke-FeatureApply -FeatureId 'RemoveApps'

        Should -Invoke Remove-SelectedApps -Times 1 -Exactly -ParameterFilter { @($Apps).Count -eq 2 }
    }

    It 'runs registry-backed companion app removal for <FeatureId>' -ForEach @(
        @{ FeatureId = 'DisableBing'; ExpectedApps = @('Microsoft.BingSearch') }
        @{ FeatureId = 'DisableCopilot'; ExpectedApps = @('Microsoft.Copilot', 'XP9CXNGPPJ97XX') }
    ) {
        Invoke-FeatureApply -FeatureId $FeatureId
        Should -Invoke Import-RegistryFile -Times 1 -Exactly
        Should -Invoke Remove-SelectedApps -Times 1 -Exactly -ParameterFilter { @($Apps) -join ',' -eq $ExpectedApps -join ',' }
    }

    It 'forcefully removes Edge when requested' {
        Invoke-FeatureApply -FeatureId 'ForceRemoveEdge'

        Should -Invoke Invoke-ForceRemoveEdge -Times 1 -Exactly
        Should -Invoke Import-RegistryFile -Times 0 -Exactly
        Should -Invoke Remove-SelectedApps -Times 0 -Exactly
    }

    It 'returns false when applying a feature throws' {
        Mock Invoke-ForceRemoveEdge { throw 'access denied' }
        Mock Write-Warning {}

        Invoke-FeatureApply -FeatureId 'ForceRemoveEdge' | Should -BeFalse

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match "Failed to apply 'Force remove Edge'.*access denied" }
    }

    It 'returns false for an unknown feature' {
        Mock Write-Warning {}

        Invoke-FeatureApply -FeatureId 'Unknown' | Should -BeFalse

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match "Unknown feature 'Unknown'.*could not be applied" }
    }

    It 'uses the expected static app list for <FeatureId>' -ForEach @(
        @{ FeatureId = 'RemoveGamingApps'; MinimumCount = 3; ExpectedApp = 'Microsoft.GamingApp' }
        @{ FeatureId = 'RemoveHPApps'; MinimumCount = 10; ExpectedApp = 'AD2F1837.myHP' }
        @{ FeatureId = 'DisableWidgets'; MinimumCount = 3; ExpectedApp = 'MicrosoftWindows.Client.WebExperience' }
    ) {
        Invoke-FeatureApply -FeatureId $FeatureId
        Should -Invoke Remove-SelectedApps -Times 1 -Exactly -ParameterFilter { @($Apps).Count -ge $MinimumCount -and $Apps -contains $ExpectedApp }
    }

    It 'does not stop widget processes in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }
        Invoke-FeatureApply -FeatureId 'DisableWidgets'
        Should -Invoke Get-Process -Times 0 -Exactly
        Should -Invoke Stop-Process -Times 0 -Exactly
    }

    It 'stops widget processes before removing widget packages' {
        $widget = [PSCustomObject]@{ Name = 'WidgetService' }
        Mock Get-Process { $widget }

        Invoke-FeatureApply -FeatureId 'DisableWidgets'

        Should -Invoke Stop-Process -Times 1 -Exactly
    }

    It 'stops widget processes without a confirmation prompt' {
        Mock Get-Process { [PSCustomObject]@{ Name = 'Widgets' } }

        Invoke-FeatureApply -FeatureId 'DisableWidgets'

        Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $Force -and $ErrorAction -eq 'SilentlyContinue' }
    }

    It 'enables the expected optional Windows features' {
        Invoke-FeatureApply -FeatureId 'EnableWindowsSandbox'
        Invoke-FeatureApply -FeatureId 'EnableWindowsSubsystemForLinux'
        Should -Invoke Enable-WindowsFeature -Times 1 -Exactly -ParameterFilter { $FeatureName -eq 'Containers-DisposableClientVM' }
        Should -Invoke Enable-WindowsFeature -Times 1 -Exactly -ParameterFilter { $FeatureName -eq 'VirtualMachinePlatform' }
        Should -Invoke Enable-WindowsFeature -Times 1 -Exactly -ParameterFilter { $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux' }
    }

    It 'applies current-user Start layouts only when a target path resolves' {
        $script:Params = @{ ReplaceStart = 'template.bin' }
        Invoke-FeatureApply -FeatureId 'ClearStart'
        Invoke-FeatureApply -FeatureId 'ReplaceStart'
        Should -Invoke Replace-StartMenu -Times 1 -Exactly -ParameterFilter { $startMenuBinFile -eq 'start.bin' -and -not $startMenuTemplate }
        Should -Invoke Replace-StartMenu -Times 1 -Exactly -ParameterFilter { $startMenuBinFile -eq 'start.bin' -and $startMenuTemplate -eq 'template.bin' }

        Mock Get-StartMenuBinPathForUser { $null }
        Invoke-FeatureApply -FeatureId 'ClearStart'
        Should -Invoke Replace-StartMenu -Times 2 -Exactly
    }

    It 'applies all-user Start templates correctly' {
        $script:Params = @{ ReplaceStartAllUsers = 'all-users.bin' }
        Invoke-FeatureApply -FeatureId 'ClearStartAllUsers'
        Invoke-FeatureApply -FeatureId 'ReplaceStartAllUsers'
        Should -Invoke Replace-StartMenuForAllUsers -Times 2 -Exactly
        Should -Invoke Replace-StartMenuForAllUsers -Times 1 -Exactly -ParameterFilter { $null -eq $startMenuTemplate }
        Should -Invoke Replace-StartMenuForAllUsers -Times 1 -Exactly -ParameterFilter { $startMenuTemplate -eq 'all-users.bin' }
    }

    It 'applies Store-search scope to all users during Sysprep' {
        $script:Params = @{ Sysprep = $true }
        Invoke-FeatureApply -FeatureId 'DisableStoreSearchSuggestions'

        Should -Invoke Set-StoreSearchSuggestionsDisabledForAllUsers -Times 1 -Exactly
        Should -Invoke Set-StoreSearchSuggestionsDisabled -Times 0 -Exactly
    }

    It 'does not update Store search suggestions when the current user database cannot be resolved' {
        Mock Get-StoreAppsDatabasePathForUser { $null }

        Invoke-FeatureApply -FeatureId 'DisableStoreSearchSuggestions'

        Should -Invoke Set-StoreSearchSuggestionsDisabled -Times 0 -Exactly
    }
}

Describe 'Invoke-ApplyFeatures' {
    BeforeEach {
        $script:CancelRequested = $false
        $script:Features = @{
            One = [PSCustomObject]@{ ApplyText = 'Apply one' }
            Two = [PSCustomObject]@{ ApplyText = 'Apply two' }
        }
        Sync-TestLangFeatures
        $script:progressCalls = New-Object System.Collections.Generic.List[object]
        $script:ApplyProgressCallback = { param($Step, $Total, $Text) $script:progressCalls.Add(@($Step, $Total, $Text)) }
        Mock Invoke-FeatureApply { $true }
    }

    It 'reports progress and applies each feature in order' {
        Invoke-ApplyFeatures -FeatureIds @('One', 'Two') -StartStep 3 -TotalSteps 5

        Should -Invoke Invoke-FeatureApply -Times 2 -Exactly
        $script:progressCalls | Should -HaveCount 2
        $script:progressCalls[0] | Should -Be @(3, 5, 'Apply one')
        $script:progressCalls[1] | Should -Be @(4, 5, 'Apply two')
    }

    It 'stops before processing work when cancellation was requested' {
        $script:CancelRequested = $true

        Invoke-ApplyFeatures -FeatureIds @('One', 'Two') -StartStep 1 -TotalSteps 2

        Should -Invoke Invoke-FeatureApply -Times 0 -Exactly
        $script:progressCalls | Should -HaveCount 0
    }

    It 'counts a failed feature application and continues with later features' {
        $script:FeatureFailures = 0
        Mock Invoke-FeatureApply {
            param($FeatureId)
            return ($FeatureId -ne 'One')
        }

        Invoke-ApplyFeatures -FeatureIds @('One', 'Two') -StartStep 1 -TotalSteps 2

        $script:FeatureFailures | Should -Be 1
        Should -Invoke Invoke-FeatureApply -Times 2 -Exactly
    }
}

Describe 'Invoke-UndoFeatures' {
    BeforeEach {
        $script:CancelRequested = $false
        $script:ApplyProgressCallback = $null
        $script:Features = @{
            RegistryUndo = [PSCustomObject]@{ UndoLabel = 'Undo registry'; ApplyUndoText = 'Restoring registry'; RegistryUndoKey = 'undo.reg' }
            CustomUndo = [PSCustomObject]@{ UndoLabel = 'Undo custom'; ApplyUndoText = ''; RegistryUndoKey = '' }
        }
        Sync-TestLangFeatures
        Mock Resolve-UndoRegFilePath { param($FileName) "Undo\$FileName" }
        Mock Import-RegistryFile { $true }
        Mock Invoke-FeatureUndo { $true }
    }

    It 'delegates registry-backed undo work to the feature undo handler' {
        Invoke-UndoFeatures -FeatureIds @('RegistryUndo') -StartStep 1 -TotalSteps 1

        Should -Invoke Invoke-FeatureUndo -Times 1 -Exactly -ParameterFilter { $FeatureId -eq 'RegistryUndo' }
    }

    It 'handles unknown and custom features without attempting a registry import' {
        Invoke-UndoFeatures -FeatureIds @('CustomUndo', 'Unknown') -StartStep 1 -TotalSteps 2

        Should -Invoke Import-RegistryFile -Times 0 -Exactly
        Should -Invoke Invoke-FeatureUndo -Times 2 -Exactly
    }

    It 'counts one failure when a feature undo fails' {
        $script:FeatureFailures = 0
        Mock Invoke-FeatureUndo { $false }

        Invoke-UndoFeatures -FeatureIds @('RegistryUndo') -StartStep 1 -TotalSteps 1

        $script:FeatureFailures | Should -Be 1
        Should -Invoke Invoke-FeatureUndo -Times 1 -Exactly
    }

    It 'stops before undoing when cancellation is requested' {
        $script:CancelRequested = $true

        Invoke-UndoFeatures -FeatureIds @('RegistryUndo') -StartStep 1 -TotalSteps 1

        Should -Invoke Import-RegistryFile -Times 0 -Exactly
        Should -Invoke Invoke-FeatureUndo -Times 0 -Exactly
    }
}

Describe 'Invoke-FeatureUndo' {
    BeforeEach {
        $script:Params = @{}
        $script:Features = @{
            EnableWindowsSandbox = [PSCustomObject]@{ ApplyUndoText = 'Disable Sandbox' }
            EnableWindowsSubsystemForLinux = [PSCustomObject]@{ ApplyUndoText = 'Disable WSL' }
            DisableTelemetry = [PSCustomObject]@{}
            DisableStoreSearchSuggestions = [PSCustomObject]@{}
        }
        Mock Set-StoreSearchSuggestionsEnabledForAllUsers { $true }
        Mock Set-StoreSearchSuggestionsEnabled { $true }
        Mock Get-StoreAppsDatabasePathForUser { 'store.db' }
        Mock Get-UserName { 'Alice' }
        Mock Disable-WindowsFeature { $true }
        Mock Enable-TelemetryScheduledTasks { $true }
        Mock Import-RegistryFile { $true }
        Mock Resolve-UndoRegFilePath { param($FileName) "Undo\$FileName" }
        Mock Write-Host {}
    }

    It 'undoes Store search suggestions for the selected target scope' -ForEach @(
        @{ Params = @{ Sysprep = $true }; AllUsers = 1; CurrentUser = 0 }
        @{ Params = @{}; AllUsers = 0; CurrentUser = 1 }
    ) {
        $script:Params = $Params
        Invoke-FeatureUndo -FeatureId 'DisableStoreSearchSuggestions'
        Should -Invoke Set-StoreSearchSuggestionsEnabledForAllUsers -Times $AllUsers -Exactly
        Should -Invoke Set-StoreSearchSuggestionsEnabled -Times $CurrentUser -Exactly -ParameterFilter { $StoreAppsDatabase -eq 'store.db' }
    }

    It 'disables both WSL optional features in dependency-safe order' {
        $script:disabledFeatures = [System.Collections.Generic.List[string]]::new()
        Mock Disable-WindowsFeature { param($FeatureName) $script:disabledFeatures.Add($FeatureName); $true }
        Invoke-FeatureUndo -FeatureId 'EnableWindowsSubsystemForLinux'
        $script:disabledFeatures | Should -Be @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')
    }

    It 'disables Sandbox and re-enables telemetry tasks' {
        $script:Features.DisableTelemetry = [PSCustomObject]@{ ApplyUndoText = 'Enable telemetry'; RegistryUndoKey = 'enable-telemetry.reg' }
        Invoke-FeatureUndo -FeatureId 'EnableWindowsSandbox'
        Invoke-FeatureUndo -FeatureId 'DisableTelemetry'
        Should -Invoke Disable-WindowsFeature -Times 1 -Exactly -ParameterFilter { $FeatureName -eq 'Containers-DisposableClientVM' }
        Should -Invoke Enable-TelemetryScheduledTasks -Times 1 -Exactly
        Should -Invoke Import-RegistryFile -Times 1 -Exactly -ParameterFilter { $path -eq 'Undo\enable-telemetry.reg' }
    }

    It 'returns false without side effects when a registry undo import fails' {
        $script:Features.DisableTelemetry = [PSCustomObject]@{ ApplyUndoText = 'Enable telemetry'; RegistryUndoKey = 'enable-telemetry.reg' }
        Mock Import-RegistryFile { $false }

        Invoke-FeatureUndo -FeatureId 'DisableTelemetry' | Should -BeFalse

        Should -Invoke Enable-TelemetryScheduledTasks -Times 0 -Exactly
    }

    It 'warns and returns false for an unknown feature' {
        Mock Write-Warning {}

        Invoke-FeatureUndo -FeatureId 'Unknown' | Should -BeFalse

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match "Unknown feature 'Unknown'.*could not be undone" }
    }
}

Describe 'Invoke-AllChanges' {
    BeforeEach {
        $script:Params = @{ RegistryApply = $true; CustomApply = $true }
        $script:UndoParams = @{ RegistryUndo = $true }
        $script:ControlParams = @('WhatIf', 'Silent', 'User', 'Sysprep')
        $script:Features = @{
            RegistryApply = [PSCustomObject]@{ RegistryKey = 'apply.reg' }
            CustomApply = [PSCustomObject]@{ RegistryKey = '' }
            RegistryUndo = [PSCustomObject]@{ RegistryUndoKey = 'undo.reg' }
        }
        $script:CancelRequested = $false
        $script:ApplyProgressCallback = $null
        Mock Test-RunningAsSystem { $false }
        Mock Resolve-UndoRegFilePath { param($FileName) "Undo\$FileName" }
        Mock New-RegistrySettingsBackup {}
        Mock Invoke-SystemRestorePoint { $true }
        Mock Invoke-ApplyFeatures {}
        Mock Invoke-UndoFeatures {}
        Mock Write-Host {}
        Mock Write-Warning {}
    }

    It 'backs up registry work before applying and undoing selected features' {
        $script:order = [System.Collections.Generic.List[string]]::new()
        Mock New-RegistrySettingsBackup { $script:order.Add('backup') }
        Mock Invoke-ApplyFeatures { $script:order.Add('apply') }
        Mock Invoke-UndoFeatures { $script:order.Add('undo') }

        Invoke-AllChanges

        $script:order | Should -Be @('backup', 'apply', 'undo')
        Should -Invoke New-RegistrySettingsBackup -Times 1 -Exactly -ParameterFilter {
            $ActionableKeys -contains 'RegistryApply' -and @($ExtraFeatures).Count -eq 1 -and $ExtraFeatures[0].RegistryKey -eq 'Undo\undo.reg'
        }
    }

    It 'prevents every mutation when registry backup creation fails' {
        Mock New-RegistrySettingsBackup { throw 'disk full' }
        { Invoke-AllChanges } | Should -Throw 'Registry backup failed before applying changes.*disk full'
        Should -Invoke Invoke-ApplyFeatures -Times 0 -Exactly
        Should -Invoke Invoke-UndoFeatures -Times 0 -Exactly
        Should -Invoke Invoke-SystemRestorePoint -Times 0 -Exactly
    }

    It 'does not create a registry backup when explicitly skipped' {
        $script:Params['SkipRegistryBackup'] = $true

        Invoke-AllChanges

        Should -Invoke New-RegistrySettingsBackup -Times 0 -Exactly
        Should -Invoke Invoke-ApplyFeatures -Times 1 -Exactly
        Should -Invoke Invoke-UndoFeatures -Times 1 -Exactly
    }

    It 'does not run when cancellation was already requested' {
        $script:CancelRequested = $true
        Invoke-AllChanges
        Should -Invoke New-RegistrySettingsBackup -Times 0 -Exactly
        Should -Invoke Invoke-ApplyFeatures -Times 0 -Exactly
        Should -Invoke Invoke-UndoFeatures -Times 0 -Exactly
    }

    It 'does not enter the undo phase when cancellation occurs during apply' {
        Mock Invoke-ApplyFeatures { $script:CancelRequested = $true }
        Invoke-AllChanges
        Should -Invoke Invoke-ApplyFeatures -Times 1 -Exactly
        Should -Invoke Invoke-UndoFeatures -Times 0 -Exactly
    }

    It 'rejects SYSTEM execution without an explicit user target' {
        Mock Test-RunningAsSystem { $true }
        { Invoke-AllChanges } | Should -Throw "Win11Debloat is running as the SYSTEM account*"
        Should -Invoke New-RegistrySettingsBackup -Times 0 -Exactly
    }

    It 'allows SYSTEM execution with an explicit target and filters control parameters from features' {
        Mock Test-RunningAsSystem { $true }
        $script:Params = @{ User = 'Alice'; WhatIf = $true; CustomApply = $true }
        Invoke-AllChanges
        Should -Invoke New-RegistrySettingsBackup -Times 0 -Exactly
        Should -Invoke Invoke-ApplyFeatures -Times 1 -Exactly -ParameterFilter {
            @($FeatureIds).Count -eq 1 -and $FeatureIds[0] -eq 'CustomApply'
        }
    }

    It 'sequences an optional restore point before feature application' {
        $script:Params = @{ CreateRestorePoint = $true; CustomApply = $true }
        $script:UndoParams = @{}
        $script:order = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-SystemRestorePoint { $script:order.Add('restore-point'); $true }
        Mock Invoke-ApplyFeatures { $script:order.Add('apply') }
        Invoke-AllChanges
        $script:order | Should -Be @('restore-point', 'apply')
    }

    It 'counts a restore point failure as a feature failure when the user chooses to continue' {
        $script:Params = @{ CreateRestorePoint = $true; CustomApply = $true }
        $script:UndoParams = @{}
        Mock Invoke-SystemRestorePoint { $false }

        Invoke-AllChanges

        $script:FeatureFailures | Should -Be 1
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match '1 feature change\(s\) failed\.' }
    }

    It 'reports app removal failures after all requested work completes' {
        $script:Params = @{ CustomApply = $true }
        $script:UndoParams = @{}
        Mock Invoke-ApplyFeatures { $script:AppRemovalFailures = 2 }

        Invoke-AllChanges

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match '2 app removal\(s\) failed' }
    }

    It 'warns when app removals could not be verified' {
        $script:Params = @{ CustomApply = $true }
        $script:UndoParams = @{}
        Mock Invoke-ApplyFeatures { $script:AppRemovalVerificationUnavailable = $true }
        Mock Write-Warning {}

        Invoke-AllChanges

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -eq 'Unable to verify if all apps were uninstalled successfully.' }
    }

}
