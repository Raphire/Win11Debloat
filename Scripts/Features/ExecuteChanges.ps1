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
        ImportRegistryFile "> $($feature.ApplyText)" $feature.RegistryKey
        
        # Handle special cases that have additional logic after ImportRegistryFile
        switch ($paramKey) {
            'DisableBing' {
                # Also remove the app package for Bing search
                RemoveApps 'Microsoft.BingSearch'
            }
            'DisableCopilot' {
                # Also remove the app package for Copilot
                RemoveApps 'Microsoft.Copilot'
            }
            'DisableWidgets' {
                # Also remove the app packages for Widgets
                RemoveApps 'Microsoft.StartExperiencesApp','MicrosoftWindows.Client.WebExperience','Microsoft.WidgetsPlatformRuntime'
            }
        }
        return
    }
    
    # Handle features without RegistryKey or with special logic
    switch ($paramKey) {
        'RemoveApps' {
            Write-Host "> Removing selected apps for $(GetFriendlyTargetUserName)..."
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
            Write-Host "> Removing selected apps..."
            $appsList = LoadAppsFromFile $script:CustomAppsListFilePath

            if ($appsList.Count -eq 0) {
                Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
                Write-Host ""
                return
            }

            Write-Host "$($appsList.Count) apps selected for removal"
            RemoveApps $appsList
        }
        'RemoveCommApps' {
            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
            Write-Host "> Removing Mail, Calendar and People apps..."
            RemoveApps $appsList
            return
        }
        'RemoveW11Outlook' {
            $appsList = 'Microsoft.OutlookForWindows'
            Write-Host "> Removing new Outlook for Windows app..."
            RemoveApps $appsList
            return
        }
        'RemoveGamingApps' {
            $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
            Write-Host "> Removing gaming related apps..."
            RemoveApps $appsList
            return
        }
        'RemoveHPApps' {
            $appsList = 'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl'
            Write-Host "> Removing HP apps..."
            RemoveApps $appsList
            return
        }
        "EnableWindowsSandbox" {
            Write-Host "> Enabling Windows Sandbox..."
            EnableWindowsFeature "Containers-DisposableClientVM"
            Write-Host ""
            return
        }
        "EnableWindowsSubsystemForLinux" {
            Write-Host "> Enabling Windows Subsystem for Linux..."
            EnableWindowsFeature "VirtualMachinePlatform"
            EnableWindowsFeature "Microsoft-Windows-Subsystem-Linux"
            Write-Host ""
            return
        }
        'ClearStart' {
            Write-Host "> Removing all pinned apps from the start menu for user $(GetUserName)..."
            ReplaceStartMenu
            Write-Host ""
            return
        }
        'ReplaceStart' {
            Write-Host "> Replacing the start menu for user $(GetUserName)..."
            ReplaceStartMenu $script:Params.Item("ReplaceStart")
            Write-Host ""
            return
        }
        'ClearStartAllUsers' {
            ReplaceStartMenuForAllUsers
            return
        }
        'ReplaceStartAllUsers' {
            ReplaceStartMenuForAllUsers $script:Params.Item("ReplaceStartAllUsers")
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
    # Build list of actionable parameters (skip control params and data-only params)
    $actionableKeys = @()
    foreach ($paramKey in $script:Params.Keys) {
        if ($script:ControlParams -contains $paramKey) { continue }
        if ($paramKey -eq 'Apps') { continue }
        if ($paramKey -eq 'CreateRestorePoint') { continue }
        $actionableKeys += $paramKey
    }
    
    $totalSteps = $actionableKeys.Count
    if ($script:Params.ContainsKey("CreateRestorePoint")) { $totalSteps++ }
    $currentStep = 0
    
    # Create restore point if requested (CLI only - GUI handles this separately)
    if ($script:Params.ContainsKey("CreateRestorePoint")) {
        $currentStep++
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $currentStep $totalSteps "Creating system restore point"
        }
        Write-Host "> Attempting to create a system restore point..."
        CreateSystemRestorePoint
        Write-Host ""
    }
    
    # Execute all parameters
    foreach ($paramKey in $actionableKeys) {
        if ($script:CancelRequested) { 
            return
        }

        $currentStep++
        
        # Get friendly name for the step
        $stepName = $paramKey
        if ($script:Features.ContainsKey($paramKey)) {
            $feature = $script:Features[$paramKey]
            if ($feature.ApplyText) {
                # Prefer explicit ApplyText when provided
                $stepName = $feature.ApplyText
            } elseif ($feature.Label) {
                # Fallback: construct a name from Action and Label, or just Label
                if ($feature.Action) {
                    $stepName = "$($feature.Action) $($feature.Label)"
                } else {
                    $stepName = $feature.Label
                }
            }
        }
        
        if ($script:ApplyProgressCallback) {
            & $script:ApplyProgressCallback $currentStep $totalSteps $stepName
        }
        
        ExecuteParameter -paramKey $paramKey
    }
}