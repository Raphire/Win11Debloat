# Executes a single parameter/feature based on its key
# Parameters:
#   $paramKey - The parameter name to execute
function ExecuteParameter {
    param (
        [string]$paramKey
    )
    
    # Check if this feature has metadata in Features.json
    $feature = $null
    if ($script:Features.ContainsKey($paramKey)) {
        $feature = $script:Features[$paramKey]
    }
    
    # If feature has RegistryKey and ApplyText, use dynamic ImportRegistryFile
    if ($feature -and $feature.RegistryKey -and $feature.ApplyText) {
        ImportRegistryFile "> $($feature.ApplyText)..." $feature.RegistryKey
        
        # Handle special cases that have additional logic after ImportRegistryFile
        switch ($paramKey) {
            'DisableBing' {
                # Also remove the app package for Bing search
                RemoveApps @('Microsoft.BingSearch')
            }
            'DisableCopilot' {
                # Also remove the app package for Copilot
                RemoveApps @('Microsoft.Copilot')
            }
        }
        return
    }
    
    # Handle features without RegistryKey or with special logic
    switch ($paramKey) {
        'RemoveApps' {
            Write-Host "> $($feature.ApplyText) for $(GetFriendlyTargetUserName)..."
            $appsList = GenerateAppsList

            if ($appsList.Count -eq 0) {
                Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
                Write-Host ""
                return
            }

            Write-Host "$($appsList.Count) apps selected for removal"
            RemoveApps $appsList
        }
        'RemoveAppsCustom' {
            Write-Host "> $($feature.ApplyText)..."
            $appsList = LoadAppsFromFile $script:CustomAppsListFilePath

            if ($appsList.Count -eq 0) {
                Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
                Write-Host ""
                return
            }

            Write-Host "$($appsList.Count) apps selected for removal"
            RemoveApps $appsList
        }
        'RemoveGamingApps' {
            $appsList = @('Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay')
            Write-Host "> $($feature.ApplyText)..."
            RemoveApps $appsList
            return
        }
        'RemoveHPApps' {
            $appsList = @('AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl')
            Write-Host "> $($feature.ApplyText)..."
            RemoveApps $appsList
            return
        }
        'DisableWidgets' {
            Write-Host "> $($feature.ApplyText)..."
            # Stop widgets related processes before removing the app packages to prevent potential issues
            Get-Process *Widget* -ErrorAction SilentlyContinue | Stop-Process

            RemoveApps @('Microsoft.StartExperiencesApp','MicrosoftWindows.Client.WebExperience','Microsoft.WidgetsPlatformRuntime')
        }
        'EnableWindowsSandbox' {
            Write-Host "> $($feature.ApplyText)..."
            EnableWindowsFeature "Containers-DisposableClientVM"
            Write-Host ""
            return
        }
        'EnableWindowsSubsystemForLinux' {
            Write-Host "> $($feature.ApplyText)..."
            EnableWindowsFeature "VirtualMachinePlatform"
            EnableWindowsFeature "Microsoft-Windows-Subsystem-Linux"
            Write-Host ""
            return
        }
        'ClearStart' {
            Write-Host "> $($feature.ApplyText) for user $(GetUserName)..."
            $startMenuBinFile = GetStartMenuBinPathForUser -UserName (GetUserName)
            ReplaceStartMenu -startMenuBinFile $startMenuBinFile
            Write-Host ""
            return
        }
        'ReplaceStart' {
            Write-Host "> $($feature.ApplyText) for user $(GetUserName)..."
            $startMenuBinFile = GetStartMenuBinPathForUser -UserName (GetUserName)
            ReplaceStartMenu -startMenuBinFile $startMenuBinFile -startMenuTemplate $script:Params.Item("ReplaceStart")
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
            DisableStoreSearchSuggestions
            Write-Host ""
            return
        }
    }
}


# Executes all selected parameters/features
function ExecuteAllChanges {
    # When running as SYSTEM, require -User or -Sysprep to prevent applying
    # changes to the SYSTEM profile instead of a real user.
    $isSystem = ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18')
    if ($isSystem -and -not $script:Params.ContainsKey("User") -and -not $script:Params.ContainsKey("Sysprep")) {
        throw "Win11Debloat is running as the SYSTEM account. Use the '-User' or '-Sysprep' parameter to target a specific user."
    }

    $script:RegistryImportFailures = 0

    # Build list of actionable parameters (skip control params and data-only params)
    $actionableKeys = @()
    foreach ($paramKey in $script:Params.Keys) {
        if ($script:ControlParams -contains $paramKey) { continue }
        if ($paramKey -eq 'Apps') { continue }
        if ($paramKey -eq 'CreateRestorePoint') { continue }
        $actionableKeys += $paramKey
    }

    $hasRegistryBackedFeature = $false
    foreach ($paramKey in $actionableKeys) {
        if (-not $script:Features.ContainsKey($paramKey)) { continue }

        $feature = $script:Features[$paramKey]
        if ($feature -and -not [string]::IsNullOrWhiteSpace([string]$feature.RegistryKey)) {
            $hasRegistryBackedFeature = $true
            break
        }
    }
    # Undo operations that write registry values also require a backup
    if (-not $hasRegistryBackedFeature) {
        foreach ($featureId in $script:UndoParams.Keys) {
            $f = if ($script:Features.ContainsKey($featureId)) { $script:Features[$featureId] } else { $null }
            if ($f -and $f.RegistryUndoKey) { $hasRegistryBackedFeature = $true; break }
        }
    }
    
    $totalSteps = $actionableKeys.Count + $script:UndoParams.Count
    if ($hasRegistryBackedFeature) { $totalSteps++ }
    if ($script:Params.ContainsKey("CreateRestorePoint")) { $totalSteps++ }
    $currentStep = 0

    if ($hasRegistryBackedFeature) {
        $currentStep++
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $currentStep $totalSteps "Creating registry backup..."
        }

        Write-Host "> Creating registry backup..."
        try {
            $undoSyntheticFeatures = @($script:UndoParams.Keys | ForEach-Object {
                $f = if ($script:Features.ContainsKey($_)) { $script:Features[$_] } else { $null }
                if ($f -and $f.RegistryUndoKey) {
                    [PSCustomObject]@{ FeatureId = $_; RegistryKey = (Resolve-UndoRegFilePath $f.RegistryUndoKey) }
                }
            } | Where-Object { $_ })
            New-RegistrySettingsBackup -ActionableKeys $actionableKeys -ExtraFeatures $undoSyntheticFeatures | Out-Null
        }
        catch {
            throw "Registry backup failed before applying changes. $($_.Exception.Message)"
        }
    }
    
    # Create restore point if requested (CLI only - GUI handles this separately)
    if ($script:Params.ContainsKey("CreateRestorePoint")) {
        $currentStep++
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $currentStep $totalSteps "Creating system restore point, this may take a moment..."
        }
        Write-Host "> Creating a system restore point..."
        CreateSystemRestorePoint
        Write-Host ""
    }
    
    # Execute all parameters
    foreach ($paramKey in $actionableKeys) {
        if ($script:CancelRequested) { return }

        $currentStep++
        
        # Get friendly name for the step
        $stepName = $paramKey
        if ($script:Features.ContainsKey($paramKey)) {
            $feature = $script:Features[$paramKey]
            if ($feature.ApplyText) {
                # Prefer explicit ApplyText when provided
                $stepName = $feature.ApplyText
            } elseif ($feature.Label) {
                # Fallback: use label from Features.json
                $stepName = $feature.Label
            }
        }
        
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $currentStep $totalSteps $stepName
        }
        
        ExecuteParameter -paramKey $paramKey
    }

    # Execute all undo operations
    foreach ($featureId in $script:UndoParams.Keys) {
        if ($script:CancelRequested) { return }

        $f = if ($script:Features.ContainsKey($featureId)) { $script:Features[$featureId] } else { $null }
        $undoLabel = if ($f -and $f.UndoLabel) { $f.UndoLabel } else { $featureId }
        $applyUndoText = if ($f -and $f.ApplyUndoText) { $f.ApplyUndoText } else { $undoLabel }

        $currentStep++
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $currentStep $totalSteps $applyUndoText
        }

        if ($f -and $f.RegistryUndoKey) {
            ImportRegistryFile "> $applyUndoText" (Resolve-UndoRegFilePath $f.RegistryUndoKey)
        } else {
            Invoke-UndoFeatureAction -FeatureId $featureId
        }
    }

    if ($script:RegistryImportFailures -gt 0) {
        Write-Host ""
        Write-Host "$($script:RegistryImportFailures) registry import change(s) failed. See output above for details." -ForegroundColor Yellow
    }
}

# Resolves the path of an undo reg file relative to $script:RegfilesPath.
# Checks the Undo/ subfolder first, then falls back to the root Regfiles/ folder.
function Resolve-UndoRegFilePath {
    param ([string]$FileName)
    $undoSubPath = Join-Path 'Undo' $FileName
    if (Test-Path (Join-Path $script:RegfilesPath $undoSubPath)) {
        return $undoSubPath
    }
    return $FileName
}

function Invoke-UndoFeatureAction {
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
            EnableStoreSearchSuggestions
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
        default {
            Write-Host "> No undo action defined for $FeatureId, skipping..." -ForegroundColor Yellow
            Write-Host ""
            return
        }
    }
}
