<#
    .SYNOPSIS
        Applies a single feature/debloat operation.

    .DESCRIPTION
        Handles two categories of features:
        - Registry-backed: imports the .reg file via ImportRegistryFile, then runs
        any post-import side effects (e.g., removing companion app packages).
        - Custom logic: app removal, Windows optional features, start menu
        replacement, and other special-case features.
#>
function Invoke-FeatureApply {
    param(
        [Parameter(Mandatory)]
        [string]$FeatureId
    )

    # Resolve feature metadata from Features.json
    $feature = $script:Features[$FeatureId]
    $applyText = $feature.ApplyText

    # ---- Registry-backed features: import .reg file, then handle side effects ----
    if ($feature.RegistryKey) {
        ImportRegistryFile "> $applyText..." $feature.RegistryKey

        # Post-import side effects for specific features
        switch ($FeatureId) {
            'DisableBing' {
                # Also remove the app package for Bing search
                RemoveApps @('Microsoft.BingSearch')
            }
            'DisableCopilot' {
                # Also remove the app packages for Copilot
                RemoveApps @('Microsoft.Copilot', 'XP9CXNGPPJ97XX')
            }
            'DisableTelemetry' {
                # Also disable telemetry scheduled tasks
                Disable-TelemetryScheduledTasks
            }
        }
        return
    }

    # ---- Custom features (no registry backing, or special handling required) ----
    switch ($FeatureId) {
        'RemoveApps' {
            Write-Host "> $applyText for $(GetFriendlyTargetUserName)..."
            $appsList = GenerateAppsList

            if ($appsList.Count -eq 0) {
                Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
                Write-Host ""
                return
            }

            Write-Host "$($appsList.Count) apps selected for removal"
            RemoveApps $appsList
            return
        }
        'RemoveGamingApps' {
            $appsList = @('Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay')
            Write-Host "> $applyText..."
            RemoveApps $appsList
            return
        }
        'RemoveHPApps' {
            $appsList = @('AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl')
            Write-Host "> $applyText..."
            RemoveApps $appsList
            return
        }
        'DisableWidgets' {
            Write-Host "> $applyText..."
            # Stop widgets related processes before removing the app packages to prevent potential issues
            if (-not $script:Params.ContainsKey("WhatIf")) {
                Get-Process *Widget* -ErrorAction SilentlyContinue | Stop-Process
            }

            RemoveApps @('Microsoft.StartExperiencesApp','MicrosoftWindows.Client.WebExperience','Microsoft.WidgetsPlatformRuntime')
            return
        }
        'EnableWindowsSandbox' {
            Write-Host "> $applyText..."
            EnableWindowsFeature "Containers-DisposableClientVM"
            Write-Host ""
            return
        }
        'EnableWindowsSubsystemForLinux' {
            Write-Host "> $applyText..."
            EnableWindowsFeature "VirtualMachinePlatform"
            EnableWindowsFeature "Microsoft-Windows-Subsystem-Linux"
            Write-Host ""
            return
        }
        'ClearStart' {
            Write-Host "> $applyText for user $(GetUserName)..."
            $startMenuBinFile = GetStartMenuBinPathForUser -UserName (GetUserName)
            if (-not [string]::IsNullOrWhiteSpace($startMenuBinFile)) {
                ReplaceStartMenu -startMenuBinFile $startMenuBinFile
            }
            Write-Host ""
            return
        }
        'ReplaceStart' {
            Write-Host "> $applyText for user $(GetUserName)..."
            $startMenuBinFile = GetStartMenuBinPathForUser -UserName (GetUserName)
            if (-not [string]::IsNullOrWhiteSpace($startMenuBinFile)) {
                ReplaceStartMenu -startMenuBinFile $startMenuBinFile -startMenuTemplate $script:Params.Item("ReplaceStart")
            }
            Write-Host ""
            return
        }
        'ClearStartAllUsers' {
            ReplaceStartMenuForAllUsers
            return
        }
        'ReplaceStartAllUsers' {
            ReplaceStartMenuForAllUsers -startMenuTemplate $script:Params.Item("ReplaceStartAllUsers")
            return
        }
        'DisableStoreSearchSuggestions' {
            if ($script:Params.ContainsKey("Sysprep")) {
                Write-Host "> Disabling Microsoft Store search suggestions in the start menu for all users..."
                DisableStoreSearchSuggestionsForAllUsers
                Write-Host ""
                return
            }

            Write-Host "> Disabling Microsoft Store search suggestions for user $(GetUserName)..."
            $storeDb = GetStoreAppsDatabasePathForUser -UserName (GetUserName)
            if ($storeDb) {
                DisableStoreSearchSuggestions -StoreAppsDatabase $storeDb
            }
            Write-Host ""
            return
        }
    }
}


<#
    .SYNOPSIS
        Undoes a single feature that has no RegistryUndoKey.

    .DESCRIPTION
        Handles undo for features that require custom logic rather than a simple
        .reg file import. Features with a RegistryUndoKey are handled directly
        via ImportRegistryFile in Invoke-UndoFeatures.
#>
function Invoke-FeatureUndo {
    param(
        [Parameter(Mandatory)]
        [string]$FeatureId
    )

    $feature = if ($script:Features.ContainsKey($FeatureId)) { $script:Features[$FeatureId] } else { $null }

    switch ($FeatureId) {
        'DisableStoreSearchSuggestions' {
            if ($script:Params.ContainsKey('Sysprep')) {
                Write-Host "> Re-enabling Microsoft Store search suggestions in the start menu for all users..."
                EnableStoreSearchSuggestionsForAllUsers
                Write-Host ""
                return
            }

            Write-Host "> Re-enabling Microsoft Store search suggestions for user $(GetUserName)..."
            $storeDb = GetStoreAppsDatabasePathForUser -UserName (GetUserName)
            if ($storeDb) {
                EnableStoreSearchSuggestions -StoreAppsDatabase $storeDb
            }
            Write-Host ""
            return
        }
        'EnableWindowsSandbox' {
            Write-Host "> $($feature.ApplyUndoText)..."
            DisableWindowsFeature 'Containers-DisposableClientVM'
            Write-Host ""
            return
        }
        'EnableWindowsSubsystemForLinux' {
            Write-Host "> $($feature.ApplyUndoText)..."
            DisableWindowsFeature 'Microsoft-Windows-Subsystem-Linux'
            DisableWindowsFeature 'VirtualMachinePlatform'
            Write-Host ""
            return
        }
        'DisableTelemetry' {
            # Also re-enable telemetry scheduled tasks
            Enable-TelemetryScheduledTasks
            return
        }
    }
}


<#
    .SYNOPSIS
        Resolves the path of an undo .reg file relative to $script:RegfilesPath.

    .DESCRIPTION
        Checks the Undo/ subfolder first, then falls back to the root Regfiles/
        folder. This allows undo files to be organized separately from apply files.
#>
function Resolve-UndoRegFilePath {
    param([string]$FileName)

    $undoSubPath = Join-Path 'Undo' $FileName
    if (Test-Path (Join-Path $script:RegfilesPath $undoSubPath)) {
        return $undoSubPath
    }
    return $FileName
}


<#
.SYNOPSIS
    Applies a list of features, reporting progress for each.

.DESCRIPTION
    Iterates through the provided feature IDs and calls Invoke-FeatureApply
    for each. Handles progress callbacks (GUI mode) and cancellation checks.
    This is called by Invoke-AllChanges during the apply phase.
#>
function Invoke-ApplyFeatures {
    param(
        [Parameter(Mandatory)]
        [string[]]$FeatureIds,
        [Parameter(Mandatory)]
        [int]$StartStep,
        [Parameter(Mandatory)]
        [int]$TotalSteps
    )

    if ($FeatureIds.Count -eq 0) { return }

    $step = $StartStep
    foreach ($featureId in $FeatureIds) {
        if ($script:CancelRequested) { return }

        # Resolve display name for the progress indicator
        $f = $script:Features[$featureId]
        $displayName = $f.ApplyText

        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $step $TotalSteps $displayName
        }

        Invoke-FeatureApply -FeatureId $featureId
        $step++
    }
}


<#
    .SYNOPSIS
        Undoes a list of features, reporting progress for each.

    .DESCRIPTION
        Iterates through the provided feature IDs. Features with a RegistryUndoKey
        are handled by importing the undo .reg file; all others delegate to
        Invoke-FeatureUndo for custom undo logic.
        This is called by Invoke-AllChanges during the undo phase.
#>
function Invoke-UndoFeatures {
    param(
        [Parameter(Mandatory)]
        [string[]]$FeatureIds,
        [Parameter(Mandatory)]
        [int]$StartStep,
        [Parameter(Mandatory)]
        [int]$TotalSteps
    )

    if ($FeatureIds.Count -eq 0) { return }

    $step = $StartStep
    foreach ($featureId in $FeatureIds) {
        if ($script:CancelRequested) { return }

        $f = if ($script:Features.ContainsKey($featureId)) { $script:Features[$featureId] } else { $null }
        $undoLabel = if ($f -and $f.UndoLabel) { $f.UndoLabel } else { $featureId }
        $undoText = if ($f -and $f.ApplyUndoText) { $f.ApplyUndoText } else { $undoLabel }

        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $step $TotalSteps $undoText
        }

        if ($f -and $f.RegistryUndoKey) {
            ImportRegistryFile "> $undoText" (Resolve-UndoRegFilePath $f.RegistryUndoKey)
        }

        Invoke-FeatureUndo -FeatureId $featureId
        $step++
    }
}


<#
    .SYNOPSIS
        Main orchestrator: applies and undoes all selected features.

    .DESCRIPTION
        Sequenced in four phases:
        1. Registry backup
        2. System restore point
        3. Apply phase - applies all selected features via Invoke-ApplyFeatures
        4. Undo phase - undoes selected features via Invoke-UndoFeatures

        Progress is reported through $script:ApplyProgressCallback when set
        (used by the GUI modal). Cancellation is checked between each step.
#>
function Invoke-AllChanges {
    # Guard: prevent running as SYSTEM account without explicit target user
    $isSystem = ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18')
    if ($isSystem -and -not $script:Params.ContainsKey("User") -and -not $script:Params.ContainsKey("Sysprep")) {
        throw "Win11Debloat is running as the SYSTEM account. Use the '-User' or '-Sysprep' parameter to target a specific user."
    }

    $script:RegistryImportFailures = 0

    # ---- Gather work items ----
    $applyIds = @()
    foreach ($key in $script:Params.Keys) {
        if ($script:ControlParams -contains $key) { continue }
        if ($key -eq 'Apps') { continue }
        if ($key -eq 'CreateRestorePoint') { continue }
        $applyIds += $key
    }
    $undoIds = @($script:UndoParams.Keys)

    # ---- Determine if registry backup is needed ----
    $needsBackup = $false
    foreach ($id in $applyIds) {
        $f = $script:Features[$id]
        if ($f -and -not [string]::IsNullOrWhiteSpace([string]$f.RegistryKey)) {
            $needsBackup = $true
            break
        }
    }
    if (-not $needsBackup) {
        foreach ($id in $undoIds) {
            $f = if ($script:Features.ContainsKey($id)) { $script:Features[$id] } else { $null }
            if ($f -and $f.RegistryUndoKey) { $needsBackup = $true; break }
        }
    }

    # ---- Calculate total progress steps ----
    $totalSteps = $applyIds.Count + $undoIds.Count
    if ($needsBackup) { $totalSteps++ }
    if ($script:Params.ContainsKey("CreateRestorePoint")) { $totalSteps++ }
    $step = 0

    # ================================================================
    # Phase 1: Registry backup
    # ================================================================
    if ($needsBackup) {
        $step++
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $step $totalSteps "Creating registry backup..."
        }

        if ($script:Params.ContainsKey("WhatIf")) {
            Write-Host "[WhatIf] Create registry backup" -ForegroundColor Cyan
        }
        else {
            Write-Host "> Creating registry backup..."
            try {
                $undoSyntheticFeatures = @($undoIds | ForEach-Object {
                    $f = if ($script:Features.ContainsKey($_)) { $script:Features[$_] } else { $null }
                    if ($f -and $f.RegistryUndoKey) {
                        [PSCustomObject]@{ FeatureId = $_; RegistryKey = (Resolve-UndoRegFilePath $f.RegistryUndoKey) }
                    }
                } | Where-Object { $_ })
                New-RegistrySettingsBackup -ActionableKeys $applyIds -ExtraFeatures $undoSyntheticFeatures | Out-Null
            }
            catch {
                throw "Registry backup failed before applying changes. $($_.Exception.Message)"
            }
        }
    }

    # ================================================================
    # Phase 2: System restore point
    # ================================================================
    if ($script:Params.ContainsKey("CreateRestorePoint")) {
        $step++
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $step $totalSteps "Creating system restore point, this may take a moment..."
        }
        if ($script:Params.ContainsKey("WhatIf")) {
            Write-Host "[WhatIf] Create system restore point" -ForegroundColor Cyan
            Write-Host ""
        }
        else {
            Write-Host "> Creating a system restore point..."
            CreateSystemRestorePoint
            Write-Host ""
        }
    }

    # ================================================================
    # Phase 3: Apply features
    # ================================================================
    if ($applyIds.Count -gt 0) {
        Invoke-ApplyFeatures -FeatureIds $applyIds -StartStep ($step + 1) -TotalSteps $totalSteps
        $step += $applyIds.Count
    }

    # ================================================================
    # Phase 4: Undo features
    # ================================================================
    if ($undoIds.Count -gt 0) {
        Invoke-UndoFeatures -FeatureIds $undoIds -StartStep ($step + 1) -TotalSteps $totalSteps
        $step += $undoIds.Count
    }

    # ================================================================
    # Final: Report registry import failures
    # ================================================================
    if ($script:RegistryImportFailures -gt 0) {
        Write-Host ""
        Write-Host "$($script:RegistryImportFailures) registry import change(s) failed. See output above for details." -ForegroundColor Yellow
    }
}
