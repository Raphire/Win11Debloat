BeforeAll {
    function ImportRegistryFile { param($Message, $RegistryFile) }
    function RemoveApps { param($Apps) }
    function Disable-TelemetryScheduledTasks {}
    function Enable-TelemetryScheduledTasks {}
    function GenerateAppsList { @() }
    function GetFriendlyTargetUserName { 'current user' }
    function EnableStoreSearchSuggestionsForAllUsers {}
    function EnableStoreSearchSuggestions { param($StoreAppsDatabase) }
    function GetStoreAppsDatabasePathForUser { param($UserName) 'store.db' }
    function GetUserName { 'Alice' }
    function DisableWindowsFeature { param($FeatureName) }
    function New-RegistrySettingsBackup { param($ActionableKeys, $ExtraFeatures) }
    function CreateSystemRestorePoint {}
    function EnableWindowsFeature { param($FeatureName) }
    function GetStartMenuBinPathForUser { param($UserName) 'start.bin' }
    function ReplaceStartMenu { param($startMenuBinFile, $startMenuTemplate) }
    function ReplaceStartMenuForAllUsers { param($startMenuTemplate) }
    function DisableStoreSearchSuggestionsForAllUsers {}
    function DisableStoreSearchSuggestions { param($StoreAppsDatabase) }

    . (Join-Path $PSScriptRoot '..\Scripts\Features\InvokeChanges.ps1')
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
            DisableWidgets = [PSCustomObject]@{ ApplyText = 'Disable widgets'; RegistryKey = '' }
            EnableWindowsSandbox = [PSCustomObject]@{ ApplyText = 'Enable Sandbox'; RegistryKey = '' }
            EnableWindowsSubsystemForLinux = [PSCustomObject]@{ ApplyText = 'Enable WSL'; RegistryKey = '' }
            ClearStart = [PSCustomObject]@{ ApplyText = 'Clear Start'; RegistryKey = '' }
            ReplaceStart = [PSCustomObject]@{ ApplyText = 'Replace Start'; RegistryKey = '' }
            ClearStartAllUsers = [PSCustomObject]@{ ApplyText = 'Clear Start all users'; RegistryKey = '' }
            ReplaceStartAllUsers = [PSCustomObject]@{ ApplyText = 'Replace Start all users'; RegistryKey = '' }
            DisableStoreSearchSuggestions = [PSCustomObject]@{ ApplyText = 'Disable Store suggestions'; RegistryKey = '' }
        }
        Mock ImportRegistryFile {}
        Mock RemoveApps {}
        Mock Disable-TelemetryScheduledTasks {}
        Mock GenerateAppsList { @() }
        Mock GetFriendlyTargetUserName { 'current user' }
        Mock EnableWindowsFeature {}
        Mock GetStartMenuBinPathForUser { 'start.bin' }
        Mock GetUserName { 'Alice' }
        Mock ReplaceStartMenu {}
        Mock ReplaceStartMenuForAllUsers {}
        Mock DisableStoreSearchSuggestionsForAllUsers {}
        Mock DisableStoreSearchSuggestions {}
        Mock GetStoreAppsDatabasePathForUser { 'store.db' }
        Mock Get-Process { @() }
        Mock Stop-Process {}
        Mock Write-Host {}
    }

    It 'imports a registry-backed feature' {
        Invoke-FeatureApply -FeatureId 'RegistryFeature'

        Should -Invoke ImportRegistryFile -Times 1 -Exactly -ParameterFilter { $RegistryFile -eq 'feature.reg' }
        Should -Invoke RemoveApps -Times 0 -Exactly
    }

    It 'runs the telemetry side effect after importing its registry file' {
        Invoke-FeatureApply -FeatureId 'DisableTelemetry'

        Should -Invoke ImportRegistryFile -Times 1 -Exactly
        Should -Invoke Disable-TelemetryScheduledTasks -Times 1 -Exactly
    }

    It 'does not call app removal when the generated selection is empty' {
        Invoke-FeatureApply -FeatureId 'RemoveApps'

        Should -Invoke GenerateAppsList -Times 1 -Exactly
        Should -Invoke RemoveApps -Times 0 -Exactly
    }

    It 'passes a non-empty generated selection to app removal' {
        Mock GenerateAppsList { @('One.App', 'Two.App') }

        Invoke-FeatureApply -FeatureId 'RemoveApps'

        Should -Invoke RemoveApps -Times 1 -Exactly -ParameterFilter { @($Apps).Count -eq 2 }
    }

    It 'runs registry-backed companion app removal for <FeatureId>' -ForEach @(
        @{ FeatureId = 'DisableBing'; ExpectedApps = @('Microsoft.BingSearch') }
        @{ FeatureId = 'DisableCopilot'; ExpectedApps = @('Microsoft.Copilot', 'XP9CXNGPPJ97XX') }
    ) {
        Invoke-FeatureApply -FeatureId $FeatureId
        Should -Invoke ImportRegistryFile -Times 1 -Exactly
        Should -Invoke RemoveApps -Times 1 -Exactly -ParameterFilter { @($Apps) -join ',' -eq $ExpectedApps -join ',' }
    }

    It 'uses the expected static app list for <FeatureId>' -ForEach @(
        @{ FeatureId = 'RemoveGamingApps'; MinimumCount = 3; ExpectedApp = 'Microsoft.GamingApp' }
        @{ FeatureId = 'RemoveHPApps'; MinimumCount = 10; ExpectedApp = 'AD2F1837.myHP' }
        @{ FeatureId = 'DisableWidgets'; MinimumCount = 3; ExpectedApp = 'MicrosoftWindows.Client.WebExperience' }
    ) {
        Invoke-FeatureApply -FeatureId $FeatureId
        Should -Invoke RemoveApps -Times 1 -Exactly -ParameterFilter { @($Apps).Count -ge $MinimumCount -and $Apps -contains $ExpectedApp }
    }

    It 'does not stop widget processes in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }
        Invoke-FeatureApply -FeatureId 'DisableWidgets'
        Should -Invoke Get-Process -Times 0 -Exactly
        Should -Invoke Stop-Process -Times 0 -Exactly
    }

    It 'enables the expected optional Windows features' {
        Invoke-FeatureApply -FeatureId 'EnableWindowsSandbox'
        Invoke-FeatureApply -FeatureId 'EnableWindowsSubsystemForLinux'
        Should -Invoke EnableWindowsFeature -Times 1 -Exactly -ParameterFilter { $FeatureName -eq 'Containers-DisposableClientVM' }
        Should -Invoke EnableWindowsFeature -Times 1 -Exactly -ParameterFilter { $FeatureName -eq 'VirtualMachinePlatform' }
        Should -Invoke EnableWindowsFeature -Times 1 -Exactly -ParameterFilter { $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux' }
    }

    It 'applies current-user Start layouts only when a target path resolves' {
        $script:Params = @{ ReplaceStart = 'template.bin' }
        Invoke-FeatureApply -FeatureId 'ClearStart'
        Invoke-FeatureApply -FeatureId 'ReplaceStart'
        Should -Invoke ReplaceStartMenu -Times 1 -Exactly -ParameterFilter { $startMenuBinFile -eq 'start.bin' -and -not $startMenuTemplate }
        Should -Invoke ReplaceStartMenu -Times 1 -Exactly -ParameterFilter { $startMenuBinFile -eq 'start.bin' -and $startMenuTemplate -eq 'template.bin' }

        Mock GetStartMenuBinPathForUser { $null }
        Invoke-FeatureApply -FeatureId 'ClearStart'
        Should -Invoke ReplaceStartMenu -Times 2 -Exactly
    }

    It 'applies all-user Start templates and Store-search scope correctly' {
        $script:Params = @{ ReplaceStartAllUsers = 'all-users.bin'; Sysprep = $true }
        Invoke-FeatureApply -FeatureId 'ClearStartAllUsers'
        Invoke-FeatureApply -FeatureId 'ReplaceStartAllUsers'
        Invoke-FeatureApply -FeatureId 'DisableStoreSearchSuggestions'
        Should -Invoke ReplaceStartMenuForAllUsers -Times 2 -Exactly
        Should -Invoke DisableStoreSearchSuggestionsForAllUsers -Times 1 -Exactly
        Should -Invoke DisableStoreSearchSuggestions -Times 0 -Exactly
    }
}

Describe 'Invoke-ApplyFeatures' {
    BeforeEach {
        $script:CancelRequested = $false
        $script:Features = @{
            One = [PSCustomObject]@{ ApplyText = 'Apply one' }
            Two = [PSCustomObject]@{ ApplyText = 'Apply two' }
        }
        $script:progressCalls = New-Object System.Collections.Generic.List[object]
        $script:ApplyProgressCallback = { param($Step, $Total, $Text) $script:progressCalls.Add(@($Step, $Total, $Text)) }
        Mock Invoke-FeatureApply {}
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
}

Describe 'Invoke-UndoFeatures' {
    BeforeEach {
        $script:CancelRequested = $false
        $script:ApplyProgressCallback = $null
        $script:Features = @{
            RegistryUndo = [PSCustomObject]@{ UndoLabel = 'Undo registry'; ApplyUndoText = 'Restoring registry'; RegistryUndoKey = 'undo.reg' }
            CustomUndo = [PSCustomObject]@{ UndoLabel = 'Undo custom'; ApplyUndoText = ''; RegistryUndoKey = '' }
        }
        Mock Resolve-UndoRegFilePath { param($FileName) "Undo\$FileName" }
        Mock ImportRegistryFile {}
        Mock Invoke-FeatureUndo {}
    }

    It 'imports registry undo data and still invokes custom undo side effects' {
        Invoke-UndoFeatures -FeatureIds @('RegistryUndo') -StartStep 1 -TotalSteps 1

        Should -Invoke ImportRegistryFile -Times 1 -Exactly -ParameterFilter { $RegistryFile -eq 'Undo\undo.reg' }
        Should -Invoke Invoke-FeatureUndo -Times 1 -Exactly -ParameterFilter { $FeatureId -eq 'RegistryUndo' }
    }

    It 'handles unknown and custom features without attempting a registry import' {
        Invoke-UndoFeatures -FeatureIds @('CustomUndo', 'Unknown') -StartStep 1 -TotalSteps 2

        Should -Invoke ImportRegistryFile -Times 0 -Exactly
        Should -Invoke Invoke-FeatureUndo -Times 2 -Exactly
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
        Mock EnableStoreSearchSuggestionsForAllUsers {}
        Mock EnableStoreSearchSuggestions {}
        Mock GetStoreAppsDatabasePathForUser { 'store.db' }
        Mock GetUserName { 'Alice' }
        Mock DisableWindowsFeature {}
        Mock Enable-TelemetryScheduledTasks {}
        Mock Write-Host {}
    }

    It 'undoes Store search suggestions for the selected target scope' -ForEach @(
        @{ Params = @{ Sysprep = $true }; AllUsers = 1; CurrentUser = 0 }
        @{ Params = @{}; AllUsers = 0; CurrentUser = 1 }
    ) {
        $script:Params = $Params
        Invoke-FeatureUndo -FeatureId 'DisableStoreSearchSuggestions'
        Should -Invoke EnableStoreSearchSuggestionsForAllUsers -Times $AllUsers -Exactly
        Should -Invoke EnableStoreSearchSuggestions -Times $CurrentUser -Exactly -ParameterFilter { $StoreAppsDatabase -eq 'store.db' }
    }

    It 'disables both WSL optional features in dependency-safe order' {
        $script:disabledFeatures = [System.Collections.Generic.List[string]]::new()
        Mock DisableWindowsFeature { param($FeatureName) $script:disabledFeatures.Add($FeatureName) }
        Invoke-FeatureUndo -FeatureId 'EnableWindowsSubsystemForLinux'
        $script:disabledFeatures | Should -Be @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')
    }

    It 'disables Sandbox and re-enables telemetry tasks' {
        Invoke-FeatureUndo -FeatureId 'EnableWindowsSandbox'
        Invoke-FeatureUndo -FeatureId 'DisableTelemetry'
        Should -Invoke DisableWindowsFeature -Times 1 -Exactly -ParameterFilter { $FeatureName -eq 'Containers-DisposableClientVM' }
        Should -Invoke Enable-TelemetryScheduledTasks -Times 1 -Exactly
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
        Mock CreateSystemRestorePoint {}
        Mock Invoke-ApplyFeatures {}
        Mock Invoke-UndoFeatures {}
        Mock Write-Host {}
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
        { Invoke-AllChanges } | Should -Throw 'Registry backup failed before applying changes. disk full'
        Should -Invoke Invoke-ApplyFeatures -Times 0 -Exactly
        Should -Invoke Invoke-UndoFeatures -Times 0 -Exactly
        Should -Invoke CreateSystemRestorePoint -Times 0 -Exactly
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
        Mock CreateSystemRestorePoint { $script:order.Add('restore-point') }
        Mock Invoke-ApplyFeatures { $script:order.Add('apply') }
        Invoke-AllChanges
        $script:order | Should -Be @('restore-point', 'apply')
    }
}
