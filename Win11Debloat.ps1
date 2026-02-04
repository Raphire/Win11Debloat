#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$CLI,
    [switch]$Silent,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$User,
    [switch]$NoRestartExplorer,
    [switch]$CreateRestorePoint,
    [switch]$RunAppsListGenerator,
    [switch]$RunDefaults,
    [switch]$RunDefaultsLite,
    [switch]$RunSavedSettings,
    [string]$Apps,
    [switch]$RemoveApps,
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveHPApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableGameBarIntegration,
    [switch]$DisableTelemetry,
    [switch]$DisableFastStartup,
    [switch]$DisableBitlockerAutoEncryption,
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableBing,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscreenTips,
    [switch]$DisableSuggestions,
    [switch]$DisableEdgeAds,
    [switch]$DisableBraveBloat,
    [switch]$DisableSettings365Ads,
    [switch]$DisableSettingsHome,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$EnableDarkMode,
    [switch]$DisableTransparency,
    [switch]$DisableAnimations,
    [switch]$TaskbarAlignLeft,
    [switch]$CombineTaskbarAlways, [switch]$CombineTaskbarWhenFull, [switch]$CombineTaskbarNever,
    [switch]$CombineMMTaskbarAlways, [switch]$CombineMMTaskbarWhenFull, [switch]$CombineMMTaskbarNever,
    [switch]$MMTaskbarModeAll, [switch]$MMTaskbarModeMainActive, [switch]$MMTaskbarModeActive,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableStartRecommended,
    [switch]$DisableStartPhoneLink,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableClickToDo,
    [switch]$DisablePaintAI,
    [switch]$DisableNotepadAI,
    [switch]$DisableEdgeAI,
    [switch]$DisableWidgets,
    [switch]$HideChat,
    [switch]$EnableEndTask,
    [switch]$EnableLastActiveClick,
    [switch]$ClearStart,
    [string]$ReplaceStart,
    [switch]$ClearStartAllUsers,
    [string]$ReplaceStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$DisableDragTray,
    [switch]$DisableMouseAcceleration,
    [switch]$DisableStickyKeys,
    [switch]$HideHome,
    [switch]$HideGallery,
    [switch]$ExplorerToHome,
    [switch]$ExplorerToThisPC,
    [switch]$ExplorerToDownloads,
    [switch]$ExplorerToOneDrive,
    [switch]$AddFoldersToThisPC,
    [switch]$HideOnedrive,
    [switch]$Hide3dObjects,
    [switch]$HideMusic,
    [switch]$HideIncludeInLibrary,
    [switch]$HideGiveAccessTo,
    [switch]$HideShare
)



# Define script-level variables & paths
$script:DefaultSettingsFilePath = "$PSScriptRoot/DefaultSettings.json"
$script:AppsListFilePath = "$PSScriptRoot/Apps.json"
$script:SavedSettingsFilePath = "$PSScriptRoot/LastUsedSettings.json"
$script:CustomAppsListFilePath = "$PSScriptRoot/CustomAppsList"
$script:DefaultLogPath = "$PSScriptRoot/Win11Debloat.log"
$script:RegfilesPath = "$PSScriptRoot/Regfiles"
$script:AssetsPath = "$PSScriptRoot/Assets"
$script:AppSelectionSchema = "$script:AssetsPath/Schemas/AppSelectionWindow.xaml"
$script:MainWindowSchema = "$script:AssetsPath/Schemas/MainWindow.xaml"
$script:FeaturesFilePath = "$script:AssetsPath/Features.json"

$script:ControlParams = 'WhatIf', 'Confirm', 'Verbose', 'Debug', 'LogPath', 'Silent', 'Sysprep', 'User', 'NoRestartExplorer', 'RunDefaults', 'RunDefaultsLite', 'RunSavedSettings', 'RunAppsListGenerator', 'CLI'

# Script-level variables for GUI elements
$script:GuiConsoleOutput = $null
$script:GuiConsoleScrollViewer = $null
$script:GuiWindow = $null

# Check if current powershell environment is limited by security policies
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Error "Win11Debloat is unable to run on your system, powershell execution is restricted by security policies"
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Display ASCII art launch logo in CLI
Clear-Host
Write-Host ""
Write-Host ""
Write-Host "                   " -NoNewline; Write-Host "      ^" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "     / \" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "    /   \" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "   /     \" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "  / ===== \" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "  |" -ForegroundColor Blue -NoNewline; Write-Host "  ---  " -ForegroundColor White -NoNewline; Write-Host "|" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "  |" -ForegroundColor Blue -NoNewline; Write-Host " ( O ) " -ForegroundColor DarkCyan -NoNewline; Write-Host "|" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "  |" -ForegroundColor Blue -NoNewline; Write-Host "  ---  " -ForegroundColor White -NoNewline; Write-Host "|" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "  |       |" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host " /|       |\" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "/ |       | \" -ForegroundColor Blue
Write-Host "                   " -NoNewline; Write-Host "  |  " -ForegroundColor DarkGray -NoNewline; Write-Host "'''" -ForegroundColor Red -NoNewline; Write-Host "  |" -ForegroundColor DarkGray -NoNewline; Write-Host "    *" -ForegroundColor Yellow
Write-Host "                   " -NoNewline; Write-Host "   (" -ForegroundColor Yellow -NoNewline; Write-Host "'''" -ForegroundColor Red -NoNewline; Write-Host ") " -ForegroundColor Yellow -NoNewline; Write-Host "   *  *" -ForegroundColor DarkYellow
Write-Host "                   " -NoNewline; Write-Host "   ( " -ForegroundColor DarkYellow -NoNewline; Write-Host "'" -ForegroundColor Red -NoNewline; Write-Host " )   " -ForegroundColor DarkYellow -NoNewline; Write-Host "*" -ForegroundColor Yellow
Write-Host ""
Write-Host "             Win11Debloat is launching..." -ForegroundColor White
Write-Host "               Leave this window open" -ForegroundColor DarkGray
Write-Host ""

# Log script output to 'Win11Debloat.log' at the specified path
if ($LogPath -and (Test-Path $LogPath)) {
    Start-Transcript -Path "$LogPath/Win11Debloat.log" -Append -IncludeInvocationHeader -Force | Out-Null
}
else {
    Start-Transcript -Path $script:DefaultLogPath -Append -IncludeInvocationHeader -Force | Out-Null
}

# Check if script has all required files
if (-not ((Test-Path $script:DefaultSettingsFilePath) -and (Test-Path $script:AppsListFilePath) -and (Test-Path $script:RegfilesPath) -and (Test-Path $script:AssetsPath) -and (Test-Path $script:AppSelectionSchema) -and (Test-Path $script:FeaturesFilePath))) {
    Write-Error "Win11Debloat is unable to find required files, please ensure all script files are present"
    Write-Output ""
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Load feature info from file
$script:Features = @{}
try {
    $featuresData = Get-Content -Path $script:FeaturesFilePath -Raw | ConvertFrom-Json
    foreach ($feature in $featuresData.Features) {
        $script:Features[$feature.FeatureId] = $feature
    }
}
catch {
    Write-Error "Failed to load feature info from Features.json file"
    Write-Output ""
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Check if WinGet is installed & if it is, check if the version is at least v1.4
try {
    if ([int](((winget -v) -replace 'v','').split('.')[0..1] -join '') -gt 14) {
        $script:WingetInstalled = $true
    }
    else {
        $script:WingetInstalled = $false
    }
}
catch {
    $script:WingetInstalled = $false
}

# Show WinGet warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
if (-not $script:WingetInstalled -and -not $Silent) {
    Write-Warning "WinGet is not installed or outdated, this may prevent Win11Debloat from removing certain apps"
    Write-Output ""
    Write-Output "Press any key to continue anyway..."
    $null = [System.Console]::ReadKey()
}



##################################################################################################################
#                                                                                                                #
#                                              FUNCTION DEFINITIONS                                              #
#                                                                                                                #
##################################################################################################################



# Writes to both GUI console output and standard console
function Write-ToConsole {
    param(
        [string]$message,
        [string]$ForegroundColor = $null
    )
    
    if ($script:GuiConsoleOutput) {
        # GUI mode
        $timestamp = Get-Date -Format "HH:mm:ss"
        $script:GuiConsoleOutput.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Send, [action]{
            try {
                $runText = "[$timestamp] $message`n"
                $run = New-Object System.Windows.Documents.Run $runText

                if ($ForegroundColor) {
                    try {
                        $colorObj = [System.Windows.Media.ColorConverter]::ConvertFromString($ForegroundColor)
                        if ($colorObj) {
                            $brush = [System.Windows.Media.SolidColorBrush]::new($colorObj)
                            $run.Foreground = $brush
                        }
                    }
                    catch {
                        # Invalid color string - ignore and fall back to default
                    }
                }

                $script:GuiConsoleOutput.Inlines.Add($run)
                if ($script:GuiConsoleScrollViewer) { $script:GuiConsoleScrollViewer.ScrollToEnd() }
            }
            catch {
                # If any UI update fails, fall back to simple text append
                try { $script:GuiConsoleOutput.Text += "[$timestamp] $message`n" } catch {}
            }
        })

        # Force UI to process pending updates for real-time display
        if ($script:GuiWindow) {
            $script:GuiWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
        }
    }

    try {
        if ($ForegroundColor) {
            Write-Host $message -ForegroundColor $ForegroundColor
        }
        else {
            Write-Host $message
        }
    }
    catch {
        Write-Host $message
    }
}


# Loads a JSON file from the specified path and returns the parsed object
# Returns $null if the file doesn't exist or if parsing fails
function LoadJsonFile {
    param (
        [string]$filePath,
        [string]$expectedVersion = $null,
        [switch]$optionalFile
    )
    
    if (-not (Test-Path $filePath)) {
        if (-not $optionalFile) {
            Write-Error "File not found: $filePath"
        }
        return $null
    }
    
    try {
        $jsonContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json
        
        # Validate version if specified
        if ($expectedVersion -and $jsonContent.Version -and $jsonContent.Version -ne $expectedVersion) {
            Write-Error "$(Split-Path $filePath -Leaf) version mismatch (expected $expectedVersion, found $($jsonContent.Version))"
            return $null
        }
        
        return $jsonContent
    }
    catch {
        Write-Error "Failed to parse JSON file: $filePath"
        return $null
    }
}


# Loads settings from a JSON file and adds them to script params
# Used by command-line modes (ShowDefaultModeOptions, LoadAndShowLastUsedSettings)
function LoadSettingsToParams {
    param (
        [string]$filePath,
        [string]$expectedVersion = "1.0"
    )
    
    $settingsJson = LoadJsonFile -filePath $filePath -expectedVersion $expectedVersion
    
    if (-not $settingsJson -or -not $settingsJson.Settings) {
        throw "Failed to load settings from $(Split-Path $filePath -Leaf)"
    }

    # Get current Windows build version
    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
    
    foreach ($setting in $settingsJson.Settings) {
        if ($setting.Value -eq $false) {
            continue
        }

        $feature = $script:Features[$setting.Name]

        # Check version and feature compatibility using Features.json
        if (($feature.MinVersion -and $WinVersion -lt $feature.MinVersion) -or ($feature.MaxVersion -and $WinVersion -gt $feature.MaxVersion) -or ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and (-not $script:ModernStandbySupported))) {
           continue
        }
        
        AddParameter $setting.Name $setting.Value
    }
}


# Applies settings from a JSON object to UI controls (checkboxes and comboboxes)
# Used by LoadDefaultsBtn and LoadLastUsedBtn in the UI
function ApplySettingsToUiControls {
    param (
        $window,
        $settingsJson,
        $uiControlMappings
    )
    
    if (-not $settingsJson -or -not $settingsJson.Settings) {
        return $false
    }
    
    # First, reset all tweaks to "No Change" (index 0) or unchecked
    if ($uiControlMappings) {
        foreach ($comboName in $uiControlMappings.Keys) {
            $control = $window.FindName($comboName)
            if ($control -is [System.Windows.Controls.CheckBox]) {
                $control.IsChecked = $false
            }
            elseif ($control -is [System.Windows.Controls.ComboBox]) {
                $control.SelectedIndex = 0
            }
        }
    }
    
    # Also uncheck RestorePointCheckBox
    $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
    if ($restorePointCheckBox) {
        $restorePointCheckBox.IsChecked = $false
    }
    
    # Apply settings from JSON
    foreach ($setting in $settingsJson.Settings) {
        if ($setting.Value -ne $true) { continue }
        $paramName = $setting.Name

        # Handle RestorePointCheckBox separately
        if ($paramName -eq 'CreateRestorePoint') {
            if ($restorePointCheckBox) { $restorePointCheckBox.IsChecked = $true }
            continue
        }

        if ($uiControlMappings) {
            foreach ($comboName in $uiControlMappings.Keys) {
                $mapping = $uiControlMappings[$comboName]
                if ($mapping.Type -eq 'group') {
                    $i = 1
                    foreach ($val in $mapping.Values) {
                        if ($val.FeatureIds -contains $paramName) {
                            $control = $window.FindName($comboName)
                            if ($control -and $control.Visibility -eq 'Visible') {
                                if ($control -is [System.Windows.Controls.ComboBox]) {
                                    $control.SelectedIndex = $i
                                }
                            }
                            break
                        }
                        $i++
                    }
                }
                elseif ($mapping.Type -eq 'feature') {
                    if ($mapping.FeatureId -eq $paramName) {
                        $control = $window.FindName($comboName)
                        if ($control -and $control.Visibility -eq 'Visible') {
                            if ($control -is [System.Windows.Controls.CheckBox]) {
                                $control.IsChecked = $true
                            }
                            elseif ($control -is [System.Windows.Controls.ComboBox]) {
                                $control.SelectedIndex = 1
                            }
                        }
                    }
                }
            }
        }
    }
    
    return $true
}


# Attaches shift-click selection behavior to a checkbox in an apps panel
# Parameters:
#   - $checkbox: The checkbox to attach the behavior to
#   - $appsPanel: The StackPanel containing checkbox items
#   - $lastSelectedCheckboxRef: A reference to a variable storing the last clicked checkbox
#   - $updateStatusCallback: Optional callback to update selection status
function AttachShiftClickBehavior {
    param (
        [System.Windows.Controls.CheckBox]$checkbox,
        [System.Windows.Controls.StackPanel]$appsPanel,
        [ref]$lastSelectedCheckboxRef,
        [scriptblock]$updateStatusCallback = $null
    )

    # Use a closure to capture the parameters
    $checkbox.Add_PreviewMouseLeftButtonDown({
        param(
            $sender,
            $e
        )
        
        $isShiftPressed = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftShift) -or 
                          [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::RightShift)
        
        if ($isShiftPressed -and $null -ne $lastSelectedCheckboxRef.Value) {
            # Get all visible checkboxes in the panel
            $visibleCheckboxes = @()
            foreach ($child in $appsPanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') {
                    $visibleCheckboxes += $child
                }
            }

            # Find indices of the last selected and current checkbox
            $lastIndex = -1
            $currentIndex = -1

            for ($i = 0; $i -lt $visibleCheckboxes.Count; $i++) {
                if ($visibleCheckboxes[$i] -eq $lastSelectedCheckboxRef.Value) {
                    $lastIndex = $i
                }
                if ($visibleCheckboxes[$i] -eq $sender) {
                    $currentIndex = $i
                }
            }

            if ($lastIndex -ge 0 -and $currentIndex -ge 0 -and $lastIndex -ne $currentIndex) {
                $startIndex = [Math]::Min($lastIndex, $currentIndex)
                $endIndex = [Math]::Max($lastIndex, $currentIndex)

                $shouldDeselect = $sender.IsChecked

                # Set all checkboxes in the range to the appropriate state
                for ($i = $startIndex; $i -le $endIndex; $i++) {
                    $visibleCheckboxes[$i].IsChecked = -not $shouldDeselect
                }

                if ($updateStatusCallback) {
                    & $updateStatusCallback
                }

                # Mark the event as handled to prevent the default toggle behavior
                $e.Handled = $true
                return
            }
        }

        # Update the last selected checkbox reference for next time
        $lastSelectedCheckboxRef.Value = $sender
    }.GetNewClosure())
}


# Sets resource colors for a WPF window based on dark mode preference
function SetWindowThemeResources {
    param (
        $window,
        [bool]$usesDarkMode
    )

    if ($usesDarkMode) {
        $window.Resources.Add("BgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#202020")))
        $window.Resources.Add("FgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")))
        $window.Resources.Add("CardBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2b2b2b")))
        $window.Resources.Add("BorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#404040")))
        $window.Resources.Add("ButtonBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#404040")))
        $window.Resources.Add("CheckBoxBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#272727")))
        $window.Resources.Add("CheckBoxBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#808080")))
        $window.Resources.Add("CheckBoxHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#343434")))
        $window.Resources.Add("ComboBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#373737")))
        $window.Resources.Add("ComboHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#434343")))
        $window.Resources.Add("ComboItemBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2c2c2c")))
        $window.Resources.Add("ComboItemHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#383838")))
        $window.Resources.Add("ComboItemSelectedColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#343434")))
        $window.Resources.Add("AccentColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFD700")))
        $window.Resources.Add("ButtonDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#434343")))
        $window.Resources.Add("ButtonTextDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#989898")))
        $window.Resources.Add("SecondaryButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#393939")))
        $window.Resources.Add("SecondaryButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2a2a2a")))
        $window.Resources.Add("SecondaryButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1e1e1e")))
        $window.Resources.Add("SecondaryButtonDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3b3b3b")))
        $window.Resources.Add("SecondaryButtonTextDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#787878")))
        $window.Resources.Add("ScrollBarThumbColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3d3d3d")))
        $window.Resources.Add("ScrollBarThumbHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#4b4b4b")))
    }
    else {
        $window.Resources.Add("BgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f3f3f3")))
        $window.Resources.Add("FgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#000000")))
        $window.Resources.Add("CardBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#fbfbfb")))
        $window.Resources.Add("BorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ededed")))
        $window.Resources.Add("ButtonBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#d3d3d3")))
        $window.Resources.Add("CheckBoxBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f5f5f5")))
        $window.Resources.Add("CheckBoxBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#898989")))
        $window.Resources.Add("CheckBoxHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ececec")))
        $window.Resources.Add("ComboBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")))
        $window.Resources.Add("ComboHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f8f8f8")))
        $window.Resources.Add("ComboItemBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f9f9f9")))
        $window.Resources.Add("ComboItemHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f0f0f0")))
        $window.Resources.Add("ComboItemSelectedColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f3f3f3")))
        $window.Resources.Add("AccentColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ffae00")))
        $window.Resources.Add("ButtonDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#bfbfbf")))
        $window.Resources.Add("ButtonTextDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ffffff")))
        $window.Resources.Add("SecondaryButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#fbfbfb")))
        $window.Resources.Add("SecondaryButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f6f6f6")))
        $window.Resources.Add("SecondaryButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f0f0f0")))
        $window.Resources.Add("SecondaryButtonDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f7f7f7")))
        $window.Resources.Add("SecondaryButtonTextDisabled", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#b7b7b7")))
        $window.Resources.Add("ScrollBarThumbColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#b9b9b9")))
        $window.Resources.Add("ScrollBarThumbHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#8b8b8b")))
    }

    $window.Resources.Add("ButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#0067c0")))
    $window.Resources.Add("ButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1E88E5")))
    $window.Resources.Add("ButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3284cc")))
    $window.Resources.Add("CloseHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c")))
}


# Checks if the system is set to use dark mode for apps
function GetSystemUsesDarkMode {
    try {
        return (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme').AppsUseLightTheme -eq 0
    }
    catch {
        return $false
    }
}


# Initializes and opens the main GUI window
function OpenGUI {    
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms | Out-Null

    # Get current Windows build version
    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

    $usesDarkMode = GetSystemUsesDarkMode

    # Load XAML from file
    $xaml = Get-Content -Path $script:MainWindowSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode

    # Get named elements
    $titleBar = $window.FindName('TitleBar')
    $helpBtn = $window.FindName('HelpBtn')
    $closeBtn = $window.FindName('CloseBtn')

    # Title bar event handlers
    $titleBar.Add_MouseLeftButtonDown({
        if ($_.OriginalSource -is [System.Windows.Controls.Grid] -or $_.OriginalSource -is [System.Windows.Controls.Border] -or $_.OriginalSource -is [System.Windows.Controls.TextBlock]) {
            $window.DragMove()
        }
    })
    
    $helpBtn.Add_Click({
        Start-Process "https://github.com/Raphire/Win11Debloat/wiki"
    })

    $closeBtn.Add_Click({
        $window.Close()
    })

    # Ensure closing the window via any means properly exits the script
    $window.Add_Closing({
        Stop-Transcript
        Exit
    })

    # Implement window resize functionality
    $resizeLeft = $window.FindName('ResizeLeft')
    $resizeRight = $window.FindName('ResizeRight')
    $resizeTop = $window.FindName('ResizeTop')
    $resizeBottom = $window.FindName('ResizeBottom')
    $resizeTopLeft = $window.FindName('ResizeTopLeft')
    $resizeTopRight = $window.FindName('ResizeTopRight')
    $resizeBottomLeft = $window.FindName('ResizeBottomLeft')
    $resizeBottomRight = $window.FindName('ResizeBottomRight')

    $script:resizing = $false
    $script:resizeEdges = $null
    $script:resizeStart = $null
    $script:windowStart = $null
    $script:resizeElement = $null

    $resizeHandler = {
        param($sender, $e)
        
        $script:resizing = $true
        $script:resizeElement = $sender
        $script:resizeStart = [System.Windows.Forms.Cursor]::Position
        $script:windowStart = @{
            Left = $window.Left
            Top = $window.Top
            Width = $window.ActualWidth
            Height = $window.ActualHeight
        }
        
        # Parse direction tag into edge flags for cleaner resize logic
        $direction = $sender.Tag
        $script:resizeEdges = @{
            Left = $direction -match 'Left'
            Right = $direction -match 'Right'
            Top = $direction -match 'Top'
            Bottom = $direction -match 'Bottom'
        }
        
        $sender.CaptureMouse()
        $e.Handled = $true
    }

    $moveHandler = {
        param($sender, $e)
        if (-not $script:resizing) { return }
        
        $current = [System.Windows.Forms.Cursor]::Position
        $deltaX = $current.X - $script:resizeStart.X
        $deltaY = $current.Y - $script:resizeStart.Y

        # Handle horizontal resize
        if ($script:resizeEdges.Left) {
            $newWidth = [Math]::Max($window.MinWidth, $script:windowStart.Width - $deltaX)
            if ($newWidth -ne $window.Width) {
                $window.Left = $script:windowStart.Left + ($script:windowStart.Width - $newWidth)
                $window.Width = $newWidth
            }
        }
        elseif ($script:resizeEdges.Right) {
            $window.Width = [Math]::Max($window.MinWidth, $script:windowStart.Width + $deltaX)
        }

        # Handle vertical resize
        if ($script:resizeEdges.Top) {
            $newHeight = [Math]::Max($window.MinHeight, $script:windowStart.Height - $deltaY)
            if ($newHeight -ne $window.Height) {
                $window.Top = $script:windowStart.Top + ($script:windowStart.Height - $newHeight)
                $window.Height = $newHeight
            }
        }
        elseif ($script:resizeEdges.Bottom) {
            $window.Height = [Math]::Max($window.MinHeight, $script:windowStart.Height + $deltaY)
        }
        
        $e.Handled = $true
    }

    $releaseHandler = {
        param($sender, $e)
        if ($script:resizing -and $script:resizeElement) {
            $script:resizing = $false
            $script:resizeEdges = $null
            $script:resizeElement.ReleaseMouseCapture()
            $script:resizeElement = $null
            $e.Handled = $true
        }
    }

    # Set tags and add event handlers for resize borders
    $resizeLeft.Tag = 'Left'
    $resizeLeft.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeLeft.Add_MouseMove($moveHandler)
    $resizeLeft.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeRight.Tag = 'Right'
    $resizeRight.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeRight.Add_MouseMove($moveHandler)
    $resizeRight.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeTop.Tag = 'Top'
    $resizeTop.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeTop.Add_MouseMove($moveHandler)
    $resizeTop.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeBottom.Tag = 'Bottom'
    $resizeBottom.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeBottom.Add_MouseMove($moveHandler)
    $resizeBottom.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeTopLeft.Tag = 'TopLeft'
    $resizeTopLeft.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeTopLeft.Add_MouseMove($moveHandler)
    $resizeTopLeft.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeTopRight.Tag = 'TopRight'
    $resizeTopRight.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeTopRight.Add_MouseMove($moveHandler)
    $resizeTopRight.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeBottomLeft.Tag = 'BottomLeft'
    $resizeBottomLeft.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeBottomLeft.Add_MouseMove($moveHandler)
    $resizeBottomLeft.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeBottomRight.Tag = 'BottomRight'
    $resizeBottomRight.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeBottomRight.Add_MouseMove($moveHandler)
    $resizeBottomRight.Add_MouseLeftButtonUp($releaseHandler)

    # Integrated App Selection UI
    $appsPanel = $window.FindName('AppSelectionPanel')
    $onlyInstalledAppsBox = $window.FindName('OnlyInstalledAppsBox')
    $loadingAppsIndicator = $window.FindName('LoadingAppsIndicator')
    $appSelectionStatus = $window.FindName('AppSelectionStatus')
    $defaultAppsBtn = $window.FindName('DefaultAppsBtn')
    $clearAppSelectionBtn = $window.FindName('ClearAppSelectionBtn')
    
    # Track the last selected checkbox for shift-click range selection
    $script:MainWindowLastSelectedCheckbox = $null
    
    # Track current app loading operation to prevent race conditions
    $script:CurrentAppLoadTimer = $null
    $script:CurrentAppLoadJob = $null
    $script:CurrentAppLoadJobStartTime = $null
    
    # Apply Tab UI Elements
    $consoleOutput = $window.FindName('ConsoleOutput')
    $consoleScrollViewer = $window.FindName('ConsoleScrollViewer')
    $finishBtn = $window.FindName('FinishBtn')
    $finishBtnText = $window.FindName('FinishBtnText')
    
    # Set script-level variables for Write-ToConsole function
    $script:GuiConsoleOutput = $consoleOutput
    $script:GuiConsoleScrollViewer = $consoleScrollViewer
    $script:GuiWindow = $window

    # Updates app selection status text in the App Selection tab
    function UpdateAppSelectionStatus {
        $selectedCount = 0
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedCount++
            }
        }
        $appSelectionStatus.Text = "$selectedCount app(s) selected for removal"
    }

    # Dynamically builds Tweaks UI from Features.json
    function BuildDynamicTweaks {
        $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"

        if (-not $featuresJson) {
            [System.Windows.MessageBox]::Show("Unable to load Features.json file!","Error",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Error) | Out-Null
            Exit
        }

        # Column containers
        $col0 = $window.FindName('Column0Panel')
        $col1 = $window.FindName('Column1Panel')
        $col2 = $window.FindName('Column2Panel')
        $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }

        # Clear all columns for fully dynamic panel creation
        foreach ($col in $columns) {
            if ($col) { $col.Children.Clear() }
        }

        $script:UiControlMappings = @{}
        $script:CategoryCardMap = @{}

        function CreateLabeledCombo($parent, $labelText, $comboName, $items) {
            # If only 2 items (No Change + one option), use a checkbox instead
            if ($items.Count -eq 2) {
                $checkbox = New-Object System.Windows.Controls.CheckBox
                $checkbox.Content = $labelText
                $checkbox.Name = $comboName
                $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $labelText)
                $checkbox.IsChecked = $false
                $checkbox.Style = $window.Resources["FeatureCheckboxStyle"]
                $parent.Children.Add($checkbox) | Out-Null
                
                # Register the checkbox with the window's name scope
                try {
                    [System.Windows.NameScope]::SetNameScope($checkbox, [System.Windows.NameScope]::GetNameScope($window))
                    $window.RegisterName($comboName, $checkbox)
                }
                catch {
                    # Name might already be registered, ignore
                }
                
                return $checkbox
            }
            
            # Otherwise use a combobox for multiple options
            # Wrap label in a Border for search highlighting
            $lblBorder = New-Object System.Windows.Controls.Border
            $lblBorder.Style = $window.Resources['LabelBorderStyle']
            $lblBorderName = "$comboName`_LabelBorder"
            $lblBorder.Name = $lblBorderName
            
            $lbl = New-Object System.Windows.Controls.TextBlock
            $lbl.Text = $labelText
            $lbl.Style = $window.Resources['LabelStyle']
            $labelName = "$comboName`_Label"
            $lbl.Name = $labelName
            
            $lblBorder.Child = $lbl
            $parent.Children.Add($lblBorder) | Out-Null
            
            # Register the label border with the window's name scope
            try {
                [System.Windows.NameScope]::SetNameScope($lblBorder, [System.Windows.NameScope]::GetNameScope($window))
                $window.RegisterName($lblBorderName, $lblBorder)
            }
            catch {
                # Name might already be registered, ignore
            }

            $combo = New-Object System.Windows.Controls.ComboBox
            $combo.Name = $comboName
            $combo.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $labelText)
            foreach ($it in $items) { $cbItem = New-Object System.Windows.Controls.ComboBoxItem; $cbItem.Content = $it; $combo.Items.Add($cbItem) | Out-Null }
            $combo.SelectedIndex = 0
            $parent.Children.Add($combo) | Out-Null
            
            # Register the combo box with the window's name scope
            try {
                [System.Windows.NameScope]::SetNameScope($combo, [System.Windows.NameScope]::GetNameScope($window))
                $window.RegisterName($comboName, $combo)
            }
            catch {
                # Name might already be registered, ignore
            }
            
            return $combo
        }

        function GetOrCreateCategoryCard($category) {
            if (-not $category) { $category = 'Other' }

            if ($script:CategoryCardMap.ContainsKey($category)) { return $script:CategoryCardMap[$category] }

            # Create a new card Border + StackPanel and add to shortest column
            $target = $columns | Sort-Object @{Expression={$_.Children.Count}; Ascending=$true}, @{Expression={$columns.IndexOf($_)}; Ascending=$true} | Select-Object -First 1

            $border = New-Object System.Windows.Controls.Border
            $border.Style = $window.Resources['CategoryCardBorderStyle']
            $border.Tag = 'DynamicCategory'

            $panel = New-Object System.Windows.Controls.StackPanel
            $safe = ($category -replace '[^a-zA-Z0-9_]','_')
            $panel.Name = "Category_{0}_Panel" -f $safe

            $header = New-Object System.Windows.Controls.TextBlock
            $header.Text = $category
            $header.Style = $window.Resources['CategoryHeaderTextBlock']
            $panel.Children.Add($header) | Out-Null

            $border.Child = $panel
            $target.Children.Add($border) | Out-Null

            $script:CategoryCardMap[$category] = $panel
            return $panel
        }

        # Determine categories present (from lists and features)
        $categoriesPresent = @{}
        if ($featuresJson.UiGroups) {
            foreach ($g in $featuresJson.UiGroups) { if ($g.Category) { $categoriesPresent[$g.Category] = $true } }
        }
        foreach ($f in $featuresJson.Features) { if ($f.Category) { $categoriesPresent[$f.Category] = $true } }

        # Create cards in the order defined in Features.json Categories (if present)
        $orderedCategories = @()
        if ($featuresJson.Categories) {
            foreach ($c in $featuresJson.Categories) { if ($categoriesPresent.ContainsKey($c)) { $orderedCategories += $c } }
        } else {
            $orderedCategories = $categoriesPresent.Keys
        }

        foreach ($category in $orderedCategories) {
            # Create/get card for this category
            $panel = GetOrCreateCategoryCard -category $category
            if (-not $panel) { continue }

            # Collect groups and features for this category, then sort by priority
            $categoryItems = @()

            # Add any groups for this category
            if ($featuresJson.UiGroups) {
                $groupIndex = 0
                foreach ($group in $featuresJson.UiGroups) {
                    if ($group.Category -ne $category) { $groupIndex++; continue }
                    $categoryItems += [PSCustomObject]@{
                        Type = 'group'
                        Data = $group
                        Priority = if ($null -ne $group.Priority) { $group.Priority } else { [int]::MaxValue }
                        OriginalIndex = $groupIndex
                    }
                    $groupIndex++
                }
            }

            # Add individual features for this category
            $featureIndex = 0
            foreach ($feature in $featuresJson.Features) {
                if ($feature.Category -ne $category) { $featureIndex++; continue }
                
                # Check version and feature compatibility using Features.json
                if (($feature.MinVersion -and $WinVersion -lt $feature.MinVersion) -or ($feature.MaxVersion -and $WinVersion -gt $feature.MaxVersion) -or ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and (-not $script:ModernStandbySupported))) {
                    $featureIndex++; continue
                }

                # Skip if feature part of a group
                $inGroup = $false
                if ($featuresJson.UiGroups) {
                    foreach ($g in $featuresJson.UiGroups) { foreach ($val in $g.Values) { if ($val.FeatureIds -contains $feature.FeatureId) { $inGroup = $true; break } }; if ($inGroup) { break } }
                }
                if ($inGroup) { $featureIndex++; continue }

                $categoryItems += [PSCustomObject]@{
                    Type = 'feature'
                    Data = $feature
                    Priority = if ($null -ne $feature.Priority) { $feature.Priority } else { [int]::MaxValue }
                    OriginalIndex = $featureIndex
                }
                $featureIndex++
            }

            # Sort by priority first, then by original index for items with same/no priority
            $sortedItems = $categoryItems | Sort-Object -Property Priority, OriginalIndex

            # Render sorted items
            foreach ($item in $sortedItems) {
                if ($item.Type -eq 'group') {
                    $group = $item.Data
                    $items = @('No Change') + ($group.Values | ForEach-Object { $_.Label })
                    $comboName = 'Group_{0}Combo' -f $group.GroupId
                    $combo = CreateLabeledCombo -parent $panel -labelText $group.Label -comboName $comboName -items $items
                    $script:UiControlMappings[$comboName] = @{ Type='group'; Values = $group.Values; Label = $group.Label }
                }
                elseif ($item.Type -eq 'feature') {
                    $feature = $item.Data
                    $opt = 'Apply'
                    if ($feature.FeatureId -match '^Disable') { $opt = 'Disable' } elseif ($feature.FeatureId -match '^Enable') { $opt = 'Enable' }
                    $items = @('No Change', $opt)
                    $comboName = ("Feature_{0}_Combo" -f $feature.FeatureId) -replace '[^a-zA-Z0-9_]',''
                    $combo = CreateLabeledCombo -parent $panel -labelText ($feature.Action + ' ' + $feature.Label) -comboName $comboName -items $items
                    $script:UiControlMappings[$comboName] = @{ Type='feature'; FeatureId = $feature.FeatureId; Action = $feature.Action }
                }
            }
        }
    }

    # Helper function to complete app loading with the WinGet list
    function script:LoadAppsWithList($listOfApps) {
        $appsToAdd = GetAppsFromJson -OnlyInstalled:$onlyInstalledAppsBox.IsChecked -InstalledList $listOfApps -InitialCheckedFromJson:$false

        # Reset the last selected checkbox when loading a new list
        $script:MainWindowLastSelectedCheckbox = $null

        # Sort apps alphabetically and add to panel
        $appsToAdd | Sort-Object -Property DisplayName | ForEach-Object {
            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.Content = $_.DisplayName
            $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $_.DisplayName)
            $checkbox.Tag = $_.AppId
            $checkbox.IsChecked = $_.IsChecked
            $checkbox.ToolTip = $_.Description
            $checkbox.Style = $window.Resources["AppsPanelCheckBoxStyle"]
            
            # Store metadata in checkbox for later use
            Add-Member -InputObject $checkbox -MemberType NoteProperty -Name "SelectedByDefault" -Value $_.SelectedByDefault
            
            # Add event handler to update status
            $checkbox.Add_Checked({ UpdateAppSelectionStatus })
            $checkbox.Add_Unchecked({ UpdateAppSelectionStatus })
            
            # Attach shift-click behavior for range selection
            AttachShiftClickBehavior -checkbox $checkbox -appsPanel $appsPanel -lastSelectedCheckboxRef ([ref]$script:MainWindowLastSelectedCheckbox) -updateStatusCallback { UpdateAppSelectionStatus }
            
            $appsPanel.Children.Add($checkbox) | Out-Null
        }

        # Hide loading indicator and navigation blocker, update status
        $loadingAppsIndicator.Visibility = 'Collapsed'

        UpdateAppSelectionStatus
    }

    # Loads apps into the UI
    function LoadAppsIntoMainUI {
        # Cancel any existing load operation to prevent race conditions
        if ($script:CurrentAppLoadTimer -and $script:CurrentAppLoadTimer.IsEnabled) {
            $script:CurrentAppLoadTimer.Stop()
        }
        if ($script:CurrentAppLoadJob) {
            Remove-Job -Job $script:CurrentAppLoadJob -Force -ErrorAction SilentlyContinue
        }
        $script:CurrentAppLoadTimer = $null
        $script:CurrentAppLoadJob = $null
        $script:CurrentAppLoadJobStartTime = $null
        
        # Show loading indicator and navigation blocker, clear existing apps immediately
        $loadingAppsIndicator.Visibility = 'Visible'
        $appsPanel.Children.Clear()
        
        # Update navigation buttons to disable Next/Previous
        UpdateNavigationButtons
        
        # Force UI to update and render all changes (loading indicator, blocker, disabled buttons)
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [action]{})
        
        # Schedule the actual loading work to run after UI has updated
        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
            $listOfApps = ""

            if ($onlyInstalledAppsBox.IsChecked -and ($script:WingetInstalled -eq $true)) {
                # Start job to get list of installed apps via WinGet (async helper)
                $asyncJob = GetInstalledAppsViaWinget -Async
                $script:CurrentAppLoadJob = $asyncJob.Job
                $script:CurrentAppLoadJobStartTime = $asyncJob.StartTime
                
                # Create timer to poll job status without blocking UI
                $script:CurrentAppLoadTimer = New-Object System.Windows.Threading.DispatcherTimer
                $script:CurrentAppLoadTimer.Interval = [TimeSpan]::FromMilliseconds(100)
                
                $script:CurrentAppLoadTimer.Add_Tick({
                    # Check if this timer was cancelled (another load started)
                    if (-not $script:CurrentAppLoadJob -or -not $script:CurrentAppLoadTimer -or -not $script:CurrentAppLoadJobStartTime) {
                        if ($script:CurrentAppLoadTimer) { $script:CurrentAppLoadTimer.Stop() }
                        return
                    }
                    
                    $elapsed = (Get-Date) - $script:CurrentAppLoadJobStartTime
                    
                    # Check if job is complete or timed out (10 seconds)
                    if ($script:CurrentAppLoadJob.State -eq 'Completed') {
                        $script:CurrentAppLoadTimer.Stop()
                        $listOfApps = Receive-Job -Job $script:CurrentAppLoadJob
                        Remove-Job -Job $script:CurrentAppLoadJob -ErrorAction SilentlyContinue
                        $script:CurrentAppLoadJob = $null
                        $script:CurrentAppLoadTimer = $null
                        $script:CurrentAppLoadJobStartTime = $null
                        
                        # Continue with loading apps
                        LoadAppsWithList $listOfApps
                    }
                    elseif ($elapsed.TotalSeconds -gt 10 -or $script:CurrentAppLoadJob.State -eq 'Failed') {
                        $script:CurrentAppLoadTimer.Stop()
                        Remove-Job -Job $script:CurrentAppLoadJob -Force -ErrorAction SilentlyContinue
                        $script:CurrentAppLoadJob = $null
                        $script:CurrentAppLoadTimer = $null
                        $script:CurrentAppLoadJobStartTime = $null
                        
                        # Show error that the script was unable to get list of apps from WinGet
                        [System.Windows.MessageBox]::Show('Unable to load list of installed apps via WinGet.', 'Error', 'OK', 'Error') | Out-Null
                        $onlyInstalledAppsBox.IsChecked = $false
                        
                        # Continue with loading all apps (unchecked now)
                        LoadAppsWithList ""
                    }
                })
                
                $script:CurrentAppLoadTimer.Start()
                return  # Exit here, timer will continue the work
            }

            # If checkbox is not checked or winget not installed, load all apps immediately
            LoadAppsWithList $listOfApps
        }) | Out-Null
    }

    # Event handlers for app selection
    $onlyInstalledAppsBox.Add_Checked({
        LoadAppsIntoMainUI 
    })
    $onlyInstalledAppsBox.Add_Unchecked({
        LoadAppsIntoMainUI 
    })

    # Quick selection buttons - only select apps actually in those categories
    $defaultAppsBtn.Add_Click({
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                if ($child.SelectedByDefault -eq $true) {
                    $child.IsChecked = $true
                } else {
                    $child.IsChecked = $false
                }
            }
        }
    })

    $clearAppSelectionBtn.Add_Click({
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.IsChecked = $false
            }
        }
    })

    # Shared search highlighting configuration
    $script:SearchHighlightColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFF4CE"))
    $script:SearchHighlightColorDark = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A2A"))
    
    # Helper function to get the appropriate highlight brush based on theme
    function GetSearchHighlightBrush {
        if ($usesDarkMode) { return $script:SearchHighlightColorDark }
        return $script:SearchHighlightColor
    }
    
    # Helper function to scroll to an item if it's not visible, centering it in the viewport
    function ScrollToItemIfNotVisible {
        param (
            [System.Windows.Controls.ScrollViewer]$scrollViewer,
            [System.Windows.UIElement]$item,
            [System.Windows.UIElement]$container
        )
        
        if (-not $scrollViewer -or -not $item -or -not $container) { return }
        
        try {
            $itemPosition = $item.TransformToAncestor($container).Transform([System.Windows.Point]::new(0, 0)).Y
            $viewportHeight = $scrollViewer.ViewportHeight
            $itemHeight = $item.ActualHeight
            $currentOffset = $scrollViewer.VerticalOffset
            
            # Check if the item is currently visible in the viewport
            $itemTop = $itemPosition - $currentOffset
            $itemBottom = $itemTop + $itemHeight
            
            $isVisible = ($itemTop -ge 0) -and ($itemBottom -le $viewportHeight)
            
            # Only scroll if the item is not visible
            if (-not $isVisible) {
                # Center the item in the viewport
                $targetOffset = $itemPosition - ($viewportHeight / 2) + ($itemHeight / 2)
                $scrollViewer.ScrollToVerticalOffset([Math]::Max(0, $targetOffset))
            }
        }
        catch {
            # Fallback to simple bring into view
            $item.BringIntoView()
        }
    }
    
    # Helper function to find the parent ScrollViewer of an element
    function FindParentScrollViewer {
        param ([System.Windows.UIElement]$element)
        
        $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($element)
        while ($null -ne $parent) {
            if ($parent -is [System.Windows.Controls.ScrollViewer]) {
                return $parent
            }
            $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
        }
        return $null
    }

    # App Search Box functionality
    $appSearchBox = $window.FindName('AppSearchBox')
    $appSearchPlaceholder = $window.FindName('AppSearchPlaceholder')
    
    $appSearchBox.Add_TextChanged({
        $searchText = $appSearchBox.Text.ToLower().Trim()
        
        # Show/hide placeholder
        $appSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($appSearchBox.Text)) { 'Visible' } else { 'Collapsed' }
        
        # Clear all highlights first
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.Background = [System.Windows.Media.Brushes]::Transparent
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($searchText)) { return }
        
        # Find and highlight all matching apps
        $firstMatch = $null
        $highlightBrush = GetSearchHighlightBrush
        
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') {
                if ($child.Content.ToString().ToLower().Contains($searchText)) {
                    $child.Background = $highlightBrush
                    if ($null -eq $firstMatch) { $firstMatch = $child }
                }
            }
        }
        
        # Scroll to first match if not visible
        if ($firstMatch) {
            $scrollViewer = FindParentScrollViewer -element $appsPanel
            if ($scrollViewer) {
                ScrollToItemIfNotVisible -scrollViewer $scrollViewer -item $firstMatch -container $appsPanel
            }
        }
    })

    # Tweak Search Box functionality
    $tweakSearchBox = $window.FindName('TweakSearchBox')
    $tweakSearchPlaceholder = $window.FindName('TweakSearchPlaceholder')
    $tweakSearchBorder = $window.FindName('TweakSearchBorder')
    $tweaksScrollViewer = $window.FindName('TweaksScrollViewer')
    $tweaksGrid = $window.FindName('TweaksGrid')
    $col0 = $window.FindName('Column0Panel')
    $col1 = $window.FindName('Column1Panel')
    $col2 = $window.FindName('Column2Panel')
    
    # Monitor scrollbar visibility and adjust searchbar margin
    $tweaksScrollViewer.Add_ScrollChanged({
        if ($tweaksScrollViewer.ScrollableHeight -gt 0) {
            # The 17px accounts for the scrollbar width + some padding
            $tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0, 0, 17, 0)
        } else {
            $tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0, 0, 0, 0)
        }
    })
    
    # Helper function to clear all tweak highlights
    function ClearTweakHighlights {
        $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }
        foreach ($column in $columns) {
            foreach ($card in $column.Children) {
                if ($card -is [System.Windows.Controls.Border] -and $card.Child -is [System.Windows.Controls.StackPanel]) {
                    foreach ($control in $card.Child.Children) {
                        if ($control -is [System.Windows.Controls.CheckBox] -or 
                            ($control -is [System.Windows.Controls.Border] -and $control.Name -like '*_LabelBorder')) {
                            $control.Background = [System.Windows.Media.Brushes]::Transparent
                        }
                    }
                }
            }
        }
    }
    
    # Helper function to check if a ComboBox contains matching items
    function ComboBoxContainsMatch {
        param ([System.Windows.Controls.ComboBox]$comboBox, [string]$searchText)
        
        foreach ($item in $comboBox.Items) {
            $itemText = if ($item -is [System.Windows.Controls.ComboBoxItem]) { $item.Content.ToString().ToLower() } else { $item.ToString().ToLower() }
            if ($itemText.Contains($searchText)) { return $true }
        }
        return $false
    }
    
    $tweakSearchBox.Add_TextChanged({
        $searchText = $tweakSearchBox.Text.ToLower().Trim()
        
        # Show/hide placeholder
        $tweakSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($tweakSearchBox.Text)) { 'Visible' } else { 'Collapsed' }
        
        # Clear all highlights
        ClearTweakHighlights
        
        if ([string]::IsNullOrWhiteSpace($searchText)) { return }
        
        # Find and highlight all matching tweaks
        $firstMatch = $null
        $highlightBrush = GetSearchHighlightBrush
        $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }
        
        foreach ($column in $columns) {
            foreach ($card in $column.Children) {
                if ($card -is [System.Windows.Controls.Border] -and $card.Child -is [System.Windows.Controls.StackPanel]) {
                    $controlsList = @($card.Child.Children)
                    for ($i = 0; $i -lt $controlsList.Count; $i++) {
                        $control = $controlsList[$i]
                        $matchFound = $false
                        $controlToHighlight = $null
                        
                        if ($control -is [System.Windows.Controls.CheckBox]) {
                            if ($control.Content.ToString().ToLower().Contains($searchText)) {
                                $matchFound = $true
                                $controlToHighlight = $control
                            }
                        }
                        elseif ($control -is [System.Windows.Controls.Border] -and $control.Name -like '*_LabelBorder') {
                            $labelText = if ($control.Child) { $control.Child.Text.ToLower() } else { "" }
                            $comboBox = if ($i + 1 -lt $controlsList.Count -and $controlsList[$i + 1] -is [System.Windows.Controls.ComboBox]) { $controlsList[$i + 1] } else { $null }
                            
                            # Check label text or combo box items
                            if ($labelText.Contains($searchText) -or ($comboBox -and (ComboBoxContainsMatch -comboBox $comboBox -searchText $searchText))) {
                                $matchFound = $true
                                $controlToHighlight = $control
                            }
                        }
                        
                        if ($matchFound -and $controlToHighlight) {
                            $controlToHighlight.Background = $highlightBrush
                            if ($null -eq $firstMatch) { $firstMatch = $controlToHighlight }
                        }
                    }
                }
            }
        }
        
        # Scroll to first match if not visible
        if ($firstMatch -and $tweaksScrollViewer) {
            ScrollToItemIfNotVisible -scrollViewer $tweaksScrollViewer -item $firstMatch -container $tweaksGrid
        }
    })

    # Add Ctrl+F keyboard shortcut to focus search box on current tab
    $window.Add_KeyDown({
        param($sender, $e)
        
        # Check if Ctrl+F was pressed
        if ($e.Key -eq [System.Windows.Input.Key]::F -and 
            ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
            
            $currentTab = $tabControl.SelectedItem
            
            # Focus AppSearchBox if on App Removal tab
            if ($currentTab.Header -eq "App Removal" -and $appSearchBox) {
                $appSearchBox.Focus()
                $e.Handled = $true
            }
            # Focus TweakSearchBox if on Tweaks tab
            elseif ($currentTab.Header -eq "Tweaks" -and $tweakSearchBox) {
                $tweakSearchBox.Focus()
                $e.Handled = $true
            }
        }
    })

    # Wizard Navigation
    $tabControl = $window.FindName('MainTabControl')
    $previousBtn = $window.FindName('PreviousBtn')
    $nextBtn = $window.FindName('NextBtn')
    $userSelectionCombo = $window.FindName('UserSelectionCombo')
    $userSelectionDescription = $window.FindName('UserSelectionDescription')
    $otherUserPanel = $window.FindName('OtherUserPanel')
    $otherUsernameTextBox = $window.FindName('OtherUsernameTextBox')
    $usernameTextBoxPlaceholder = $window.FindName('UsernameTextBoxPlaceholder')
    $usernameValidationMessage = $window.FindName('UsernameValidationMessage')

    # Navigation button handlers
    function UpdateNavigationButtons {
        $currentIndex = $tabControl.SelectedIndex
        $totalTabs = $tabControl.Items.Count
        
        $homeIndex = 0
        $overviewIndex = $totalTabs - 2
        $applyIndex = $totalTabs - 1

        # Navigation button visibility
        if ($currentIndex -eq $homeIndex) {
            $nextBtn.Visibility = 'Collapsed'
            $previousBtn.Visibility = 'Collapsed'
        } elseif ($currentIndex -eq $overviewIndex) {
            $nextBtn.Visibility = 'Collapsed'
            $previousBtn.Visibility = 'Visible'
        } elseif ($currentIndex -eq $applyIndex) {
            $nextBtn.Visibility = 'Collapsed'
            $previousBtn.Visibility = 'Collapsed'
        } else {
            $nextBtn.Visibility = 'Visible'
            $previousBtn.Visibility = 'Visible'
        }
        
        # Update progress indicators
        # Tab indices: 0=Home, 1=App Removal, 2=Tweaks, 3=Overview, 4=Apply
        $blueColor = "#0067c0"
        $greyColor = "#808080"
        
        $progressIndicator1 = $window.FindName('ProgressIndicator1') # App Removal
        $progressIndicator2 = $window.FindName('ProgressIndicator2') # Tweaks
        $progressIndicator3 = $window.FindName('ProgressIndicator3') # Overview
        $bottomNavGrid = $window.FindName('BottomNavGrid')
        
        # Hide bottom navigation on home page and apply tab
        if ($currentIndex -eq 0 -or $currentIndex -eq $applyIndex) {
            $bottomNavGrid.Visibility = 'Collapsed'
        } else {
            $bottomNavGrid.Visibility = 'Visible'
        }
        
        # Update indicator colors based on current tab
        # Indicator 1 (App Removal) - tab index 1
        if ($currentIndex -ge 1) {
            $progressIndicator1.Fill = $blueColor
        } else {
            $progressIndicator1.Fill = $greyColor
        }
        
        # Indicator 2 (Tweaks) - tab index 2
        if ($currentIndex -ge 2) {
            $progressIndicator2.Fill = $blueColor
        } else {
            $progressIndicator2.Fill = $greyColor
        }
        
        # Indicator 3 (Overview) - tab index 3
        if ($currentIndex -ge 3) {
            $progressIndicator3.Fill = $blueColor
        } else {
            $progressIndicator3.Fill = $greyColor
        }
    }

    # Update user selection description and show/hide other user panel
    $userSelectionCombo.Add_SelectionChanged({
        switch ($userSelectionCombo.SelectedIndex) {
            0 { 
                $userSelectionDescription.Text = "Changes will be applied to the currently logged-in user profile."
                $otherUserPanel.Visibility = 'Collapsed'
                $usernameValidationMessage.Text = ""
            }
            1 { 
                $userSelectionDescription.Text = "Changes will be applied to a different user profile on this system."
                $otherUserPanel.Visibility = 'Visible'
                $usernameValidationMessage.Text = ""
            }
            2 { 
                $userSelectionDescription.Text = "Changes will be applied to the default user template, affecting all new users created after this point. Useful for Sysprep deployment."
                $otherUserPanel.Visibility = 'Collapsed'
                $usernameValidationMessage.Text = ""
            }
        }
    })

    $otherUsernameTextBox.Add_TextChanged({
        # Show/hide placeholder
        if ([string]::IsNullOrWhiteSpace($otherUsernameTextBox.Text)) {
            $usernameTextBoxPlaceholder.Visibility = 'Visible'
        } else {
            $usernameTextBoxPlaceholder.Visibility = 'Collapsed'
        }
        
        ValidateOtherUsername
    })

    function ValidateOtherUsername {
        # Only validate if "Other User" is selected
        if ($userSelectionCombo.SelectedIndex -ne 1) {
            return $true
        }

        $username = $otherUsernameTextBox.Text.Trim()

        $errorBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c"))
        $successBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#28a745"))

        if ($username.Length -eq 0) {
            $usernameValidationMessage.Text = "[X] Please enter a username"
            $usernameValidationMessage.Foreground = $errorBrush
            return $false
        }
        
        if ($username -eq $env:USERNAME) {
            $usernameValidationMessage.Text = "[X] Cannot enter your own username, use 'Current User' option instead"
            $usernameValidationMessage.Foreground = $errorBrush
            return $false
        }
        
        $userExists = CheckIfUserExists -Username $username

        if ($userExists) {
            $usernameValidationMessage.Text = "[OK] User found: $username"
            $usernameValidationMessage.Foreground = $successBrush
            return $true
        }

        $usernameValidationMessage.Text = "[X] User not found, please enter a valid username"
        $usernameValidationMessage.Foreground = $errorBrush
        return $false
    }

    function GenerateOverview {
        # Load Features.json
        $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"
        $overviewChangesPanel = $window.FindName('OverviewChangesPanel')
        $overviewChangesPanel.Children.Clear()
        
        $changesList = @()
        
        # Collect selected apps
        $selectedAppsCount = 0
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedAppsCount++
            }
        }
        if ($selectedAppsCount -gt 0) {
            $changesList += "Remove $selectedAppsCount selected application(s)"
        }
        
        # Collect all ComboBox/CheckBox selections from dynamically created controls
        if ($script:UiControlMappings) {
            foreach ($mappingKey in $script:UiControlMappings.Keys) {
                $control = $window.FindName($mappingKey)
                $isSelected = $false
                
                # Check if it's a checkbox or combobox
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    $isSelected = $control.IsChecked -eq $true
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $isSelected = $control.SelectedIndex -gt 0
                }
                
                if ($control -and $isSelected) {
                    $mapping = $script:UiControlMappings[$mappingKey]
                    if ($mapping.Type -eq 'group') {
                        # For combobox: SelectedIndex 0 = No Change, so subtract 1 to index into Values
                        $selectedValue = $mapping.Values[$control.SelectedIndex - 1]
                        foreach ($fid in $selectedValue.FeatureIds) {
                            $feature = $featuresJson.Features | Where-Object { $_.FeatureId -eq $fid }
                            if ($feature) { $changesList += ($feature.Action + ' ' + $feature.Label) }
                        }
                    }
                    elseif ($mapping.Type -eq 'feature') {
                        $feature = $featuresJson.Features | Where-Object { $_.FeatureId -eq $mapping.FeatureId }
                        if ($feature) { $changesList += ($feature.Action + ' ' + $feature.Label) }
                    }
                }
            }
        }
        
        if ($changesList.Count -eq 0) {
            $textBlock = New-Object System.Windows.Controls.TextBlock
            $textBlock.Text = "No changes selected"
            $textBlock.Style = $window.Resources["OverviewNoChangesTextStyle"]
            $overviewChangesPanel.Children.Add($textBlock) | Out-Null
        }
        else {
            foreach ($change in $changesList) {
                $bullet = New-Object System.Windows.Controls.TextBlock
                $bullet.Text = "- $change"
                $bullet.Style = $window.Resources["OverviewChangeBulletStyle"]
                $overviewChangesPanel.Children.Add($bullet) | Out-Null
            }
        }
    }

    $previousBtn.Add_Click({        
        if ($tabControl.SelectedIndex -gt 0) {
            $tabControl.SelectedIndex--
            UpdateNavigationButtons
        }
    })

    $nextBtn.Add_Click({        
        if ($tabControl.SelectedIndex -lt ($tabControl.Items.Count - 1)) {
            $tabControl.SelectedIndex++
            
            UpdateNavigationButtons
        }
    })

    # Handle Home Start button
    $homeStartBtn = $window.FindName('HomeStartBtn')
    $homeStartBtn.Add_Click({
        # Navigate to first tab after home (App Removal)
        $tabControl.SelectedIndex = 1
        UpdateNavigationButtons
    })

    # Handle Overview Apply Changes button - validates and immediately starts applying changes
    $overviewApplyBtn = $window.FindName('OverviewApplyBtn')
    $overviewApplyBtn.Add_Click({
        if (-not (ValidateOtherUsername)) {
            [System.Windows.MessageBox]::Show("Please enter a valid username.", "Invalid Username", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }

        $controlParamsCount = 0
        foreach ($Param in $script:ControlParams) {
            if ($script:Params.ContainsKey($Param)) {
                $controlParamsCount++
            }
        }

        # App Removal - collect selected apps from integrated UI
        $selectedApps = @()
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedApps += $child.Tag
            }
        }
        
        if ($selectedApps.Count -gt 0) {
            # Check if Microsoft Store is selected
            if ($selectedApps -contains "Microsoft.WindowsStore") {
                $result = [System.Windows.MessageBox]::Show(
                    'Are you sure you wish to uninstall the Microsoft Store? This app cannot easily be reinstalled.',
                    'Are you sure?',
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Warning
                )

                if ($result -eq [System.Windows.MessageBoxResult]::No) {
                    return
                }
            }
            
            AddParameter 'RemoveApps'
            AddParameter 'Apps' ($selectedApps -join ',')
        }

        # Apply dynamic tweaks selections
        if ($script:UiControlMappings) {
            foreach ($mappingKey in $script:UiControlMappings.Keys) {
                $control = $window.FindName($mappingKey)
                $isSelected = $false
                $selectedIndex = 0
                
                # Check if it's a checkbox or combobox
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    $isSelected = $control.IsChecked -eq $true
                    $selectedIndex = if ($isSelected) { 1 } else { 0 }
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $isSelected = $control.SelectedIndex -gt 0
                    $selectedIndex = $control.SelectedIndex
                }
                
                if ($control -and $isSelected) {
                    $mapping = $script:UiControlMappings[$mappingKey]
                    if ($mapping.Type -eq 'group') {
                        if ($selectedIndex -gt 0 -and $selectedIndex -le $mapping.Values.Count) {
                            $selectedValue = $mapping.Values[$selectedIndex - 1]
                            foreach ($fid in $selectedValue.FeatureIds) { 
                                AddParameter $fid
                            }
                        }
                    }
                    elseif ($mapping.Type -eq 'feature') {
                        AddParameter $mapping.FeatureId
                    }
                }
            }
        }

        # Check if any changes were selected
        $totalChanges = $script:Params.Count - $controlParamsCount

        # Apps parameter does not count as a change itself
        if ($script:Params.ContainsKey('Apps')) {
            $totalChanges--
        }

        if ($totalChanges -eq 0) {
            [System.Windows.MessageBox]::Show(
                'No changes have been selected, please select at least one item to proceed.',
                'No Changes Selected',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            return
        }

        # Check RestorePointCheckBox
        $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
        if ($restorePointCheckBox -and $restorePointCheckBox.IsChecked) {
            AddParameter 'CreateRestorePoint'
        }
        
        # Store selected user mode
        switch ($userSelectionCombo.SelectedIndex) {
            1 { AddParameter User ($otherUsernameTextBox.Text.Trim()) }
            2 { AddParameter Sysprep }
        }

        SaveSettings

        # Navigate to Apply tab (last tab) and start applying changes
        $tabControl.SelectedIndex = $tabControl.Items.Count - 1
        
        # Clear console and set initial status
        $consoleOutput.Text = ""

        Write-ToConsole "Applying changes to $(if ($script:Params.ContainsKey("Sysprep")) { "default user template" } else { "user $(GetUserName)" })"
        Write-ToConsole "Total changes to apply: $totalChanges"
        Write-ToConsole ""
        
        # Run changes in background to keep UI responsive
        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
            try {
                ExecuteAllChanges
                
                if (-not $script:Params.ContainsKey("Sysprep") -and -not $script:Params.ContainsKey("User") -and -not $script:Params.ContainsKey("NoRestartExplorer")) {
                    # Ask user if they want to restart Explorer now
                    $result = [System.Windows.MessageBox]::Show(
                        'Would you like to restart the Windows Explorer process now to apply all changes? Some changes may not take effect until a restart is performed.',
                        'Restart Windows Explorer?',
                        [System.Windows.MessageBoxButton]::YesNo,
                        [System.Windows.MessageBoxImage]::Question
                    )
                    
                    if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                        RestartExplorer
                    }
                    else {
                        Write-ToConsole "Explorer process restart was skipped, please manually reboot your PC to apply all changes"
                    }
                }
                
                Write-ToConsole ""
                Write-ToConsole "All changes have been applied. Please check the output above for any errors."
                
                $finishBtn.Dispatcher.Invoke([action]{
                    $finishBtn.IsEnabled = $true
                    $finishBtnText.Text = "Close Win11Debloat"
                })
            }
            catch {
                Write-ToConsole "Error: $($_.Exception.Message)"
                $finishBtn.Dispatcher.Invoke([action]{
                    $finishBtn.IsEnabled = $true
                    $finishBtnText.Text = "Close Win11Debloat"
                })
            }
        })
    })

    # Initialize UI elements on window load
    $window.Add_Loaded({
        BuildDynamicTweaks

        LoadAppsIntoMainUI

        UpdateNavigationButtons
    })

    # Add event handler for tab changes
    $tabControl.Add_SelectionChanged({
        # Regenerate overview when switching to Overview tab
        if ($tabControl.SelectedIndex -eq ($tabControl.Items.Count - 2)) {
            GenerateOverview
        }
        UpdateNavigationButtons
    })

    # Handle Load Defaults button
    $loadDefaultsBtn = $window.FindName('LoadDefaultsBtn')
    $loadDefaultsBtn.Add_Click({
        $defaultsJson = LoadJsonFile -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"

        if (-not $defaultsJson) {
            [System.Windows.MessageBox]::Show("Failed to load default settings file", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            return
        }
        
        ApplySettingsToUiControls -window $window -settingsJson $defaultsJson -uiControlMappings $script:UiControlMappings
    })

    # Handle Load Last Used settings and Load Last Used apps
    $loadLastUsedBtn = $window.FindName('LoadLastUsedBtn')
    $loadLastUsedAppsBtn = $window.FindName('LoadLastUsedAppsBtn')

    $lastUsedSettingsJson = LoadJsonFile -filePath $script:SavedSettingsFilePath -expectedVersion "1.0" -optionalFile

    $hasSettings = $false
    $appsSetting = $null
    if ($lastUsedSettingsJson -and $lastUsedSettingsJson.Settings) {
        foreach ($s in $lastUsedSettingsJson.Settings) {
            # Only count as hasSettings if a setting other than RemoveApps/Apps is present and true
            if ($s.Value -eq $true -and $s.Name -ne 'RemoveApps' -and $s.Name -ne 'Apps') { $hasSettings = $true }
            if ($s.Name -eq 'Apps' -and $s.Value) { $appsSetting = $s.Value }
        }
    }

    # Show option to load last used settings if they exist
    if ($hasSettings) {
        $loadLastUsedBtn.Add_Click({
            try {
                ApplySettingsToUiControls -window $window -settingsJson $lastUsedSettingsJson -uiControlMappings $script:UiControlMappings
            }
            catch {
                [System.Windows.MessageBox]::Show("Failed to load last used settings: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
    }
    else {
        $loadLastUsedBtn.Visibility = 'Collapsed'
    }

    # Show option to load last used apps if they exist
    if ($appsSetting -and $appsSetting.ToString().Trim().Length -gt 0) {
        $loadLastUsedAppsBtn.Add_Click({
            try {
                $savedApps = @()
                if ($appsSetting -is [string]) { $savedApps = $appsSetting.Split(',') }
                elseif ($appsSetting -is [array]) { $savedApps = $appsSetting }
                $savedApps = $savedApps | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

                foreach ($child in $appsPanel.Children) {
                    if ($child -is [System.Windows.Controls.CheckBox]) {
                        if ($savedApps -contains $child.Tag) { $child.IsChecked = $true } else { $child.IsChecked = $false }
                    }
                }
            }
            catch {
                [System.Windows.MessageBox]::Show("Failed to load last used app selection: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
    }
    else {
        $loadLastUsedAppsBtn.Visibility = 'Collapsed'
    }

    # Clear All Tweaks button
    $clearAllTweaksBtn = $window.FindName('ClearAllTweaksBtn')
    $clearAllTweaksBtn.Add_Click({
        # Reset all ComboBoxes to index 0 (No Change) and uncheck all CheckBoxes
        if ($script:UiControlMappings) {
            foreach ($comboName in $script:UiControlMappings.Keys) {
                $control = $window.FindName($comboName)
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    $control.IsChecked = $false
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $control.SelectedIndex = 0
                }
            }
        } 

        # Also uncheck RestorePointCheckBox
        $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
        if ($restorePointCheckBox) {
            $restorePointCheckBox.IsChecked = $false
        }
    })
    
    # Finish (Close Win11Debloat) button handler
    $finishBtn.Add_Click({
        $window.Close()
    })

    # Show the window
    return $window.ShowDialog()
}


# Shows application selection window that allows the user to select what apps they want to remove or keep
function OpenAppSelectionWindow {
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    $usesDarkMode = GetSystemUsesDarkMode

    # Load XAML from file
    $xaml = Get-Content -Path $script:AppSelectionSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode

    $appsPanel = $window.FindName('AppsPanel')
    $checkAllBox = $window.FindName('CheckAllBox')
    $onlyInstalledBox = $window.FindName('OnlyInstalledBox')
    $confirmBtn = $window.FindName('ConfirmBtn')
    $loadingIndicator = $window.FindName('LoadingAppsIndicator')
    $titleBar = $window.FindName('TitleBar')
    
    # Track the last selected checkbox for shift-click range selection
    $script:AppSelectionWindowLastSelectedCheckbox = $null

    # Loads apps into the apps UI
    function LoadApps {
        # Show loading indicator
        $loadingIndicator.Visibility = 'Visible'
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

        $appsPanel.Children.Clear()
        $listOfApps = ""

        if ($onlyInstalledBox.IsChecked -and ($script:WingetInstalled -eq $true)) {
            # Attempt to get a list of installed apps via WinGet, times out after 10 seconds
            $listOfApps = GetInstalledAppsViaWinget -TimeOut 10
            if (-not $listOfApps) {
                # Show error that the script was unable to get list of apps from WinGet
                [System.Windows.MessageBox]::Show('Unable to load list of installed apps via WinGet.', 'Error', 'OK', 'Error') | Out-Null
                $onlyInstalledBox.IsChecked = $false
            }
        }

        $appsToAdd = GetAppsFromJson -OnlyInstalled:$onlyInstalledBox.IsChecked -InstalledList $listOfApps -InitialCheckedFromJson

        # Reset the last selected checkbox when loading a new list
        $script:AppSelectionWindowLastSelectedCheckbox = $null

        # Sort apps alphabetically and add to panel
        $appsToAdd | Sort-Object -Property DisplayName | ForEach-Object {
            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.Content = $_.DisplayName
            $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $_.DisplayName)
            $checkbox.Tag = $_.AppId
            $checkbox.IsChecked = $_.IsChecked
            $checkbox.ToolTip = $_.Description
            $checkbox.Style = $window.Resources["AppsPanelCheckBoxStyle"]
            
            # Attach shift-click behavior for range selection
            AttachShiftClickBehavior -checkbox $checkbox -appsPanel $appsPanel -lastSelectedCheckboxRef ([ref]$script:AppSelectionWindowLastSelectedCheckbox)
            
            $appsPanel.Children.Add($checkbox) | Out-Null
        }

        # Hide loading indicator
        $loadingIndicator.Visibility = 'Collapsed'
    }

    # Event handlers
    $titleBar.Add_MouseLeftButtonDown({
        $window.DragMove()
    })

    $checkAllBox.Add_Checked({
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.IsChecked = $true
            }
        }
    })

    $checkAllBox.Add_Unchecked({
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.IsChecked = $false
            }
        }
    })

    $onlyInstalledBox.Add_Checked({ LoadApps })
    $onlyInstalledBox.Add_Unchecked({ LoadApps })

    $confirmBtn.Add_Click({
        $selectedApps = @()
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedApps += $child.Tag
            }
        }

        # Close form without saving if no apps were selected
        if ($selectedApps.Count -eq 0) {
            $window.Close()
            return
        }

        if ($selectedApps -contains "Microsoft.WindowsStore" -and -not $Silent) {
            $result = [System.Windows.MessageBox]::Show(
                'Are you sure you wish to uninstall the Microsoft Store? This app cannot easily be reinstalled.',
                'Are you sure?',
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning
            )

            if ($result -eq [System.Windows.MessageBoxResult]::No) {
                return
            }
        }

        SaveCustomAppsListToFile -appsList $selectedApps

        $window.DialogResult = $true
    })

    # Load apps after window is shown (allows UI to render first)
    $window.Add_ContentRendered({ 
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{ LoadApps })
    })

    # Show the window and return dialog result
    return $window.ShowDialog()
}


# Saves the provided appsList to the CustomAppsList file
function SaveCustomAppsListToFile {
    param (
        $appsList
    )

    $script:SelectedApps = $appsList

    # Create file that stores selected apps if it doesn't exist
    if (-not (Test-Path $script:CustomAppsListFilePath)) {
        $null = New-Item $script:CustomAppsListFilePath -ItemType File
    }

    Set-Content -Path $script:CustomAppsListFilePath -Value $script:SelectedApps
}


# Returns a validated list of apps based on the provided appsList and the supported apps from Apps.json
function ValidateAppslist {
    param (
        $appsList
    )

    $supportedAppsList = (GetAppsFromJson | ForEach-Object { $_.AppId })
    $validatedAppsList = @()

    # Validate provided appsList against supportedAppsList
    Foreach ($app in $appsList) {
        $app = $app.Trim()
        $appString = $app.Trim('*')

        if ($supportedAppsList -notcontains $appString) {
            Write-Host "Removal of app '$appString' is not supported and will be skipped" -ForegroundColor Yellow
            continue
        }

        $validatedAppsList += $appString
    }

    return $validatedAppsList
}


# Returns list of apps from the specified file, it trims the app names and removes any comments
function ReadAppslistFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    if (-not (Test-Path $appsFilePath)) {
        return $appsList
    }

    try {
        # Check if file is JSON or text format
        if ($appsFilePath -like "*.json") {
            # JSON file format
            $jsonContent = Get-Content -Path $appsFilePath -Raw | ConvertFrom-Json
            Foreach ($appData in $jsonContent.Apps) {
                $appId = $appData.AppId.Trim()
                $selectedByDefault = $appData.SelectedByDefault
                if ($selectedByDefault -and $appId.length -gt 0) {
                    $appsList += $appId
                }
            }
        }
        else {
            # Legacy text file format
            Foreach ($app in (Get-Content -Path $appsFilePath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) { 
                if (-not ($app.IndexOf('#') -eq -1)) {
                    $app = $app.Substring(0, $app.IndexOf('#'))
                }

                $app = $app.Trim()
                $appString = $app.Trim('*')
                $appsList += $appString
            }
        }

        return $appsList
    } 
    catch {
        Write-Error "Unable to read apps list from file: $appsFilePath"
        AwaitKeyToExit
    }
}

# Read Apps.json and return list of app objects with optional filtering
function GetAppsFromJson {
    param (
        [switch]$OnlyInstalled,
        [string]$InstalledList = "",
        [switch]$InitialCheckedFromJson
    )

    $apps = @()
    try {
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to read Apps.json: $_"
        return $apps
    }

    foreach ($appData in $jsonContent.Apps) {
        $appId = $appData.AppId.Trim()
        if ($appId.length -eq 0) { continue }

        if ($OnlyInstalled) {
            if (-not ($InstalledList -like ("*$appId*")) -and -not (Get-AppxPackage -Name $appId)) {
                continue
            }
            if (($appId -eq "Microsoft.Edge") -and -not ($InstalledList -like "* Microsoft.Edge *")) {
                continue
            }
        }

        $displayName = if ($appData.FriendlyName) { "$($appData.FriendlyName) ($appId)" } else { $appId }
        $isChecked = if ($InitialCheckedFromJson) { $appData.SelectedByDefault } else { $false }

        $apps += [PSCustomObject]@{
            AppId = $appId
            DisplayName = $displayName
            IsChecked = $isChecked
            Description = $appData.Description
            SelectedByDefault = $appData.SelectedByDefault
        }
    }

    return $apps
}

# Run winget list and return installed apps (sync or async)
function GetInstalledAppsViaWinget {
    param (
        [int]$TimeOut = 10,
        [switch]$Async
    )

    if (-not $script:WingetInstalled) { return $null }

    if ($Async) {
        $wingetListJob = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
        return @{ Job = $wingetListJob; StartTime = Get-Date }
    }
    else {
        $wingetListJob = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
        $jobDone = $wingetListJob | Wait-Job -TimeOut $TimeOut
        if (-not $jobDone) {
            Remove-Job -Job $wingetListJob -Force -ErrorAction SilentlyContinue
            return $null
        }
        $result = Receive-Job -Job $wingetListJob
        Remove-Job -Job $wingetListJob -ErrorAction SilentlyContinue
        return $result
    }
}


# Removes apps specified during function call from all user accounts and from the OS image.
function RemoveApps {
    param (
        $appslist
    )

    Foreach ($app in $appsList) {
        Write-ToConsole "Attempting to remove $app..."

        # Use WinGet only to remove OneDrive and Edge
        if (($app -eq "Microsoft.OneDrive") -or ($app -eq "Microsoft.Edge")) {
            if ($script:WingetInstalled -eq $false) {
                Write-ToConsole "WinGet is either not installed or is outdated, $app could not be removed" -ForegroundColor Red
                continue
            }

            $appName = $app -replace '\.', '_'

            # Uninstall app via WinGet, or create a scheduled task to uninstall it later
            if ($script:Params.ContainsKey("User")) {
                RegImport "Adding scheduled task to uninstall $app for user $(GetUserName)..." "Uninstall_$($appName).reg"
            }
            elseif ($script:Params.ContainsKey("Sysprep")) {
                RegImport "Adding scheduled task to uninstall $app after for new users..." "Uninstall_$($appName).reg"
            }
            else {
                # Uninstall app via WinGet, with any progress indicators removed from the output
                StripProgress -ScriptBlock { winget uninstall --accept-source-agreements --disable-interactivity --id $app } | Tee-Object -Variable wingetOutput

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "Uninstall failed with exit code")) {
                    Write-ToConsole "Unable to uninstall Microsoft Edge via WinGet" -ForegroundColor Red
                    Write-ToConsole ""

                    # Only prompt in CLI mode (not GUI)
                    if (-not $script:GuiConsoleOutput -and $( Read-Host -Prompt "Would you like to forcefully uninstall Microsoft Edge? NOT RECOMMENDED! (y/n)" ) -eq 'y') {
                        Write-ToConsole ""
                        ForceRemoveEdge
                    }
                }
            }

            continue
        }

        # Use Remove-AppxPackage to remove all other apps
        $app = '*' + $app + '*'

        # Remove installed app for all existing users
        try {
            Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue

            if ($DebugPreference -ne "SilentlyContinue") {
                Write-ToConsole "Removed $app for all users" -ForegroundColor DarkGray
            }
        }
        catch {
            if ($DebugPreference -ne "SilentlyContinue") {
                Write-ToConsole "Unable to remove $app for all users" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }

        # Remove provisioned app from OS image, so the app won't be installed for any new users
        try {
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
        }
        catch {
            Write-ToConsole "Unable to remove $app from windows image" -ForegroundColor Yellow
            Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
        }
    }

    Write-ToConsole ""
}


# Forcefully removes Microsoft Edge using its uninstaller
# Credit: Based on work from loadstring1 & ave9858
function ForceRemoveEdge {
    Write-ToConsole "> Forcefully uninstalling Microsoft Edge..."

    $regView = [Microsoft.Win32.RegistryView]::Registry32
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)
    $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev').SetValue('AllowUninstall', '')

    # Create stub (Creating this somehow allows uninstalling Edge)
    $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    New-Item $edgeStub -ItemType Directory | Out-Null
    New-Item "$edgeStub\MicrosoftEdge.exe" | Out-Null

    # Remove edge
    $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
    if ($null -ne $uninstallRegKey) {
        Write-ToConsole "Running uninstaller..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-ToConsole "Removing leftover files..."

        $edgePaths = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
            "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
            "$env:USERPROFILE\Desktop\Microsoft Edge.lnk",
            "$edgeStub"
        )

        foreach ($path in $edgePaths) {
            if (Test-Path -Path $path) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
                Write-ToConsole "  Removed $path" -ForegroundColor DarkGray
            }
        }

        Write-ToConsole "Cleaning up registry..."

        # Remove MS Edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-ToConsole "Microsoft Edge was uninstalled"
    }
    else {
        Write-ToConsole ""
        Write-ToConsole "Error: Unable to forcefully uninstall Microsoft Edge, uninstaller could not be found" -ForegroundColor Red
    }

    Write-ToConsole ""
}


# Execute provided command and strips progress spinners/bars from console output
function StripProgress {
    param(
        [ScriptBlock]$ScriptBlock
    )

    # Regex pattern to match spinner characters and progress bar patterns
    $progressPattern = 'Γû[Æê]|^\s+[-\\|/]\s+$'

    # Corrected regex pattern for size formatting, ensuring proper capture groups are utilized
    $sizePattern = '(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB) /\s+(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)'

    & $ScriptBlock 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "Error: $($_.Exception.Message)"
        }
        else {
            $line = $_ -replace $progressPattern, '' -replace $sizePattern, ''
            if (-not ([string]::IsNullOrWhiteSpace($line)) -and -not ($line.StartsWith('  '))) {
                $line
            }
        }
    }
}


# Check if this machine supports S0 Modern Standby power state. Returns true if S0 Modern Standby is supported, false otherwise.
function CheckModernStandbySupport {
    $count = 0

    try {
        switch -Regex (powercfg /a) {
            ':' {
                $count += 1
            }

            '(.*S0.{1,}\))' {
                if ($count -eq 1) {
                    return $true
                }
            }
        }
    }
    catch {
        Write-Host "Error: Unable to check for S0 Modern Standby support, powercfg command failed" -ForegroundColor Red
        Write-Host ""
        Write-Host "Press any key to continue..."
        $null = [System.Console]::ReadKey()
        return $true
    }

    return $false
}


function CheckIfUserExists {
    param (
        $userName
    )

    if ($userName -match '[<>:"|?*]') {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($userName)) {
        return $false
    }

    try {
        $userExists = Test-Path "$env:SystemDrive\Users\$userName"

        if ($userExists) {
            return $true
        }

        $userExists = Test-Path ($env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName")

        if ($userExists) {
            return $true
        }
    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $userName. Please ensure the user exists on this system"
    }

    return $false
}


# Returns the directory path of the specified user, exits script if user path can't be found
function GetUserDirectory {
    param (
        $userName,
        $fileName = "",
        $exitIfPathNotFound = $true
    )

    try {
        if (-not (CheckIfUserExists -userName $userName) -and $userName -ne "*") {
            Write-Error "User $userName does not exist on this system"
            AwaitKeyToExit
        }

        $userDirectoryExists = Test-Path "$env:SystemDrive\Users\$userName"
        $userPath = "$env:SystemDrive\Users\$userName\$fileName"

        if ((Test-Path $userPath) -or ($userDirectoryExists -and (-not $exitIfPathNotFound))) {
            return $userPath
        }

        $userDirectoryExists = Test-Path ($env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName")
        $userPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName\$fileName"

        if ((Test-Path $userPath) -or ($userDirectoryExists -and (-not $exitIfPathNotFound))) {
            return $userPath
        }
    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $userName. Please ensure the user exists on this system"
        AwaitKeyToExit
    }

    Write-Error "Unable to find user directory path for user $userName"
    AwaitKeyToExit
}


# Import & execute regfile
function RegImport {
    param (
        $message,
        $path
    )

    Write-ToConsole $message

    # Validate that the regfile exists in both locations
    if (-not (Test-Path "$script:RegfilesPath\$path") -or -not (Test-Path "$script:RegfilesPath\Sysprep\$path")) {
        Write-ToConsole "Error: Unable to find registry file: $path" -ForegroundColor Red
        Write-ToConsole ""
        return
    }

    # Reset exit code before running reg.exe for reliable success detection
    $global:LASTEXITCODE = 0

    if ($script:Params.ContainsKey("Sysprep")) {
        $defaultUserPath = GetUserDirectory -userName "Default" -fileName "NTUSER.DAT"

        reg load "HKU\Default" $defaultUserPath | Out-Null
        $regOutput = reg import "$script:RegfilesPath\Sysprep\$path" 2>&1
        reg unload "HKU\Default" | Out-Null
    }
    elseif ($script:Params.ContainsKey("User")) {
        $userPath = GetUserDirectory -userName $script:Params.Item("User") -fileName "NTUSER.DAT"

        reg load "HKU\Default" $userPath | Out-Null
        $regOutput = reg import "$script:RegfilesPath\Sysprep\$path" 2>&1
        reg unload "HKU\Default" | Out-Null

    }
    else {
        $regOutput = reg import "$script:RegfilesPath\$path" 2>&1
    }

    $hasSuccess = $LASTEXITCODE -eq 0
    
    if ($regOutput) {
        foreach ($line in $regOutput) {
            $lineText = if ($line -is [System.Management.Automation.ErrorRecord]) { $line.Exception.Message } else { $line.ToString() }
            if ($lineText -and $lineText.Length -gt 0) {
                if ($hasSuccess) {
                    Write-ToConsole $lineText
                }
                else {
                    Write-ToConsole $lineText -ForegroundColor Red
                }
            }
        }
    }

    if (-not $hasSuccess) {
        Write-ToConsole "Failed importing registry file: $path" -ForegroundColor Red
    }

    Write-ToConsole ""
}


# Restart the Windows Explorer process
function RestartExplorer {
    Write-ToConsole "> Attempting to restart the Windows Explorer process to apply all changes..."
    
    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User") -or $script:Params.ContainsKey("NoRestartExplorer")) {
        Write-ToConsole "Explorer process restart was skipped, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
        return
    }

    if ($script:Params.ContainsKey("DisableMouseAcceleration")) {
        Write-ToConsole "Warning: Changes to the Enhance Pointer Precision setting will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableStickyKeys")) {
        Write-ToConsole "Warning: Changes to the Sticky Keys setting will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableAnimations")) {
        Write-ToConsole "Warning: Animations will only be disabled after a reboot" -ForegroundColor Yellow
    }

    # Only restart if the powershell process matches the OS architecture.
    # Restarting explorer from a 32bit PowerShell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem) {
        Write-ToConsole "Restarting the Windows Explorer process... (This may cause your screen to flicker)"
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-ToConsole "Unable to restart Windows Explorer process, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
    }
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$script:AssetsPath/Start/start2.bin"
    )

    Write-ToConsole "> Removing all pinned apps from the start menu for all users..."

    # Check if template bin file exists
    if (-not (Test-Path $startMenuTemplate)) {
        Write-ToConsole "Error: Unable to clear start menu, start2.bin file missing from script folder" -ForegroundColor Red
        Write-ToConsole ""
        return
    }

    # Get path to start menu file for all users
    $userPathString = GetUserDirectory -userName "*" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    $usersStartMenuPaths = get-childitem -path $userPathString

    # Go through all users and replace the start menu file
    ForEach ($startMenuPath in $usersStartMenuPaths) {
        ReplaceStartMenu $startMenuTemplate "$($startMenuPath.Fullname)\start2.bin"
    }

    # Also replace the start menu file for the default user profile
    $defaultStartMenuPath = GetUserDirectory -userName "Default" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState" -exitIfPathNotFound $false

    # Create folder if it doesn't exist
    if (-not (Test-Path $defaultStartMenuPath)) {
        new-item $defaultStartMenuPath -ItemType Directory -Force | Out-Null
        Write-ToConsole "Created LocalState folder for default user profile"
    }

    # Copy template to default profile
    Copy-Item -Path $startMenuTemplate -Destination $defaultStartMenuPath -Force
    Write-ToConsole "Replaced start menu for the default user profile"
    Write-ToConsole ""
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenu {
    param (
        $startMenuTemplate = "$script:AssetsPath/Start/start2.bin",
        $startMenuBinFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
    )

    # Change path to correct user if a user was specified
    if ($script:Params.ContainsKey("User")) {
        $startMenuBinFile = GetUserDirectory -userName "$(GetUserName)" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin" -exitIfPathNotFound $false
    }

    # Check if template bin file exists
    if (-not (Test-Path $startMenuTemplate)) {
        Write-ToConsole "Error: Unable to replace start menu, template file not found" -ForegroundColor Red
        return
    }

    if ([IO.Path]::GetExtension($startMenuTemplate) -ne ".bin" ) {
        Write-ToConsole "Error: Unable to replace start menu, template file is not a valid .bin file" -ForegroundColor Red
        return
    }

    $userName = [regex]::Match($startMenuBinFile, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value

    $backupBinFile = $startMenuBinFile + ".bak"

    if (Test-Path $startMenuBinFile) {
        # Backup current start menu file
        Move-Item -Path $startMenuBinFile -Destination $backupBinFile -Force
    }
    else {
        Write-ToConsole "Unable to find original start2.bin file for user $userName, no backup was created for this user" -ForegroundColor Yellow
        New-Item -ItemType File -Path $startMenuBinFile -Force
    }

    # Copy template file
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-ToConsole "Replaced start menu for user $userName"
}


# Add parameter to script and write to file
function AddParameter {
    param (
        $parameterName,
        $value = $true
    )

    # Add parameter or update its value if key already exists
    if (-not $script:Params.ContainsKey($parameterName)) {
        $script:Params.Add($parameterName, $value)
    }
    else {
        $script:Params[$parameterName] = $value
    }
}


# Saves the current settings, excluding control parameters, to a JSON file
function SaveSettings {
    $settings = @{
        "Version" = "1.0"
        "Settings" = @()
    }
    
    foreach ($param in $script:Params.Keys) {
        if ($script:ControlParams -notcontains $param) {
            $value = $script:Params[$param]

            $settings.Settings += @{
                "Name" = $param
                "Value" = $value
            }
        }
    }

    try {
        $settings | ConvertTo-Json -Depth 10 | Set-Content $script:SavedSettingsFilePath
    }
    catch {
        Write-Output ""
        Write-Host "Error: Failed to save settings to LastUsedSettings.json file" -ForegroundColor Red
    }
}


# Prints the header for the script
function PrintHeader {
    param (
        $title
    )

    $fullTitle = " Win11Debloat Script - $title"

    if ($script:Params.ContainsKey("Sysprep")) {
        $fullTitle = "$fullTitle (Sysprep mode)"
    }
    else {
        $fullTitle = "$fullTitle (User: $(GetUserName))"
    }

    Clear-Host
    Write-Host "-------------------------------------------------------------------------------------------"
    Write-Host $fullTitle
    Write-Host "-------------------------------------------------------------------------------------------"
}


# Prints all pending changes that will be made by the script
function PrintPendingChanges {
    Write-Output "Win11Debloat will make the following changes:"

    if ($script:Params['CreateRestorePoint']) {
        Write-Output "- $($script:Features['CreateRestorePoint'].Label)"
    }
    foreach ($parameterName in $script:Params.Keys) {
        if ($script:ControlParams -contains $parameterName) {
            continue
        }

        # Print parameter description
        switch ($parameterName) {
            'Apps' {
                continue
            }
            'CreateRestorePoint' {
                continue
            }
            'RemoveApps' {
                $appsList = GenerateAppsList

                if ($appsList.Count -eq 0) {
                    Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
                    Write-Output ""
                    continue
                }

                Write-Output "- Remove $($appsList.Count) apps:"
                Write-Host $appsList -ForegroundColor DarkGray
                continue
            }
            'RemoveAppsCustom' {
                $appsList = ReadAppslistFromFile $script:CustomAppsListFilePath

                if ($appsList.Count -eq 0) {
                    Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
                    Write-Output ""
                    continue
                }

                Write-Output "- Remove $($appsList.Count) apps:"
                Write-Host $appsList -ForegroundColor DarkGray
                continue
            }
            default {
                if ($script:Features -and $script:Features.ContainsKey($parameterName)) {
                    $action = $script:Features[$parameterName].Action
                    $message = $script:Features[$parameterName].Label
                    Write-Output "- $action $message"
                }
                else {
                    # Fallback: show the parameter name if no feature description is available
                    Write-Output "- $parameterName"
                }
                continue
            }
        }
    }

    Write-Output ""
    Write-Output ""
    Write-Output "Press enter to execute the script or press CTRL+C to quit..."
    Read-Host | Out-Null
}


# Generates a list of apps to remove based on the Apps parameter
function GenerateAppsList {
    if (-not ($script:Params["Apps"] -and $script:Params["Apps"] -is [string])) {
        return @()
    }

    $appMode = $script:Params["Apps"].toLower()

    switch ($appMode) {
        'default' {
            $appsList = ReadAppslistFromFile $script:AppsListFilePath
            return $appsList
        }
        default {
            $appsList = $script:Params["Apps"].Split(',') | ForEach-Object { $_.Trim() }
            $validatedAppsList = ValidateAppslist $appsList
            return $validatedAppsList
        }
    }
}


function AwaitKeyToExit {
    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "Press any key to exit..."
        $null = [System.Console]::ReadKey()
    }

    Stop-Transcript
    Exit
}


function GetUserName {
    if ($script:Params.ContainsKey("User")) {
        return $script:Params.Item("User")
    }

    return $env:USERNAME
}


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
    
    # If feature has RegistryKey and ApplyText, use dynamic RegImport
    if ($feature -and $feature.RegistryKey -and $feature.ApplyText) {
        RegImport $feature.ApplyText $feature.RegistryKey
        
        # Handle special cases that have additional logic after RegImport
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
                # Also remove the app package for Widgets
                RemoveApps 'Microsoft.StartExperiencesApp'
            }
        }
        return
    }
    
    # Handle features without RegistryKey or with special logic
    switch ($paramKey) {
        'RemoveApps' {
            Write-ToConsole "> Removing selected apps..."
            $appsList = GenerateAppsList

            if ($appsList.Count -eq 0) {
                Write-ToConsole "No valid apps were selected for removal" -ForegroundColor Yellow
                Write-ToConsole ""
                return
            }

            Write-ToConsole "$($appsList.Count) apps selected for removal"
            RemoveApps $appsList
        }
        'RemoveAppsCustom' {
            Write-ToConsole "> Removing selected apps..."
            $appsList = ReadAppslistFromFile $script:CustomAppsListFilePath

            if ($appsList.Count -eq 0) {
                Write-ToConsole "No valid apps were selected for removal" -ForegroundColor Yellow
                Write-ToConsole ""
                return
            }

            Write-ToConsole "$($appsList.Count) apps selected for removal"
            RemoveApps $appsList
        }
        'RemoveCommApps' {
            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
            Write-ToConsole "> Removing Mail, Calendar and People apps..."
            RemoveApps $appsList
            return
        }
        'RemoveW11Outlook' {
            $appsList = 'Microsoft.OutlookForWindows'
            Write-ToConsole "> Removing new Outlook for Windows app..."
            RemoveApps $appsList
            return
        }
        'RemoveGamingApps' {
            $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
            Write-ToConsole "> Removing gaming related apps..."
            RemoveApps $appsList
            return
        }
        'RemoveHPApps' {
            $appsList = 'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl'
            Write-ToConsole "> Removing HP apps..."
            RemoveApps $appsList
            return
        }
        "ForceRemoveEdge" {
            ForceRemoveEdge
            return
        }
        'ClearStart' {
            Write-ToConsole "> Removing all pinned apps from the start menu for user $(GetUserName)..."
            ReplaceStartMenu
            Write-ToConsole ""
            return
        }
        'ReplaceStart' {
            Write-ToConsole "> Replacing the start menu for user $(GetUserName)..."
            ReplaceStartMenu $script:Params.Item("ReplaceStart")
            Write-ToConsole ""
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
    }
}


# Executes all selected parameters/features
# Parameters:
function ExecuteAllChanges {    
    # Create restore point if requested (CLI only - GUI handles this separately)
    if ($script:Params.ContainsKey("CreateRestorePoint")) {
        Write-ToConsole "> Attempting to create a system restore point..."
        CreateSystemRestorePoint
    }
    
    # Execute all parameters
    foreach ($paramKey in $script:Params.Keys) {
        if ($script:ControlParams -contains $paramKey) {
            continue
        }
        
        ExecuteParameter -paramKey $paramKey
    }
}


function CreateSystemRestorePoint {
    $SysRestore = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval"

    if ($SysRestore.RPSessionInterval -eq 0) {
        # In GUI mode, skip the prompt and just try to enable it
        if ($script:GuiConsoleOutput -or $Silent -or $( Read-Host -Prompt "System restore is disabled, would you like to enable it and create a restore point? (y/n)") -eq 'y') {
            $enableSystemRestoreJob = Start-Job {
                try {
                    Enable-ComputerRestore -Drive "$env:SystemDrive"
                }
                catch {
                    return "Error: Failed to enable System Restore: $_"
                }
                return $null
            }

            $enableSystemRestoreJobDone = $enableSystemRestoreJob | Wait-Job -TimeOut 20

            if (-not $enableSystemRestoreJobDone) {
                Remove-Job -Job $enableSystemRestoreJob -Force -ErrorAction SilentlyContinue
                Write-ToConsole "Error: Failed to enable system restore and create restore point, operation timed out" -ForegroundColor Red
                return
            }
            else {
                $result = Receive-Job $enableSystemRestoreJob
                Remove-Job -Job $enableSystemRestoreJob -ErrorAction SilentlyContinue
                if ($result) {
                    Write-ToConsole $result -ForegroundColor Red
                    return
                }
            }
        }
        else {
            Write-ToConsole ""
            return
        }
    }

    $createRestorePointJob = Start-Job {
        # Find existing restore points that are less than 24 hours old
        try {
            $recentRestorePoints = Get-ComputerRestorePoint | Where-Object { (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24) }
        }
        catch {
            return @{ Success = $false; Message = "Error: Unable to retrieve existing restore points: $_" }
        }

        if ($recentRestorePoints.Count -eq 0) {
            try {
                Checkpoint-Computer -Description "Restore point created by Win11Debloat" -RestorePointType "MODIFY_SETTINGS"
                return @{ Success = $true; Message = "System restore point created successfully" }
            }
            catch {
                return @{ Success = $false; Message = "Error: Unable to create restore point: $_" }
            }
        }
        else {
            return @{ Success = $true; Message = "A recent restore point already exists, no new restore point was created"; Warning = $true }
        }
    }

    $createRestorePointJobDone = $createRestorePointJob | Wait-Job -TimeOut 20

    if (-not $createRestorePointJobDone) {
        Remove-Job -Job $createRestorePointJob -Force -ErrorAction SilentlyContinue
        Write-ToConsole "Error: Failed to create system restore point, operation timed out" -ForegroundColor Red
    }
    else {
        $result = Receive-Job $createRestorePointJob
        Remove-Job -Job $createRestorePointJob -ErrorAction SilentlyContinue
        if ($result.Success) {
            if ($result.Warning) {
                Write-ToConsole $result.Message -ForegroundColor Yellow
            }
            else {
                Write-ToConsole $result.Message
            }
        }
        else {
            Write-ToConsole $result.Message -ForegroundColor Red
        }
    }

    Write-ToConsole ""
}


function ShowScriptMenuOptions {
    Do { 
        $ModeSelectionMessage = "Please select an option (1/2)" 

        PrintHeader 'Menu'

        Write-Host "(1) Default mode: Quickly apply the recommended changes"
        Write-Host "(2) App removal mode: Select & remove apps, without making other changes"

        # Only show this option if SavedSettings file exists
        if (Test-Path $script:SavedSettingsFilePath) {
            Write-Host "(3) Quickly apply your last used settings"
            
            $ModeSelectionMessage = "Please select an option (1/2/3)" 
        }

        Write-Host ""
        Write-Host ""

        $Mode = Read-Host $ModeSelectionMessage

        if (($Mode -eq '3') -and -not (Test-Path $script:SavedSettingsFilePath)) {
            $Mode = $null
        }
    }
    while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3')

    return $Mode
}


function ShowDefaultModeOptions {
    # Show options for removing apps, or set selection if RunDefaults or RunDefaultsLite parameter was passed
    if ($RunDefaults) {
        $RemoveAppsInput = '1'
    }
    elseif ($RunDefaultsLite) {
        $RemoveAppsInput = '0'                
    }
    else {
        $RemoveAppsInput = ShowDefaultModeAppRemovalOptions

        if ($RemoveAppsInput -eq '2' -and ($script:SelectedApps.contains('Microsoft.XboxGameOverlay') -or $script:SelectedApps.contains('Microsoft.XboxGamingOverlay')) -and 
          $( Read-Host -Prompt "Disable Game Bar integration and game/screen recording? This also stops ms-gamingoverlay and ms-gamebar popups (y/n)" ) -eq 'y') {
            $DisableGameBarIntegrationInput = $true;
        }
    }

    PrintHeader 'Default Mode'

    # Add default settings based on user input
    try {
        # Select app removal options based on user input
        switch ($RemoveAppsInput) {
            '1' {
                AddParameter 'RemoveApps'
                AddParameter 'Apps' 'Default'
            }
            '2' {
                AddParameter 'RemoveAppsCustom'

                if ($DisableGameBarIntegrationInput) {
                    AddParameter 'DisableDVR'
                    AddParameter 'DisableGameBarIntegration'
                }
            }
        }

        # Load settings from DefaultSettings.json and add to params
        LoadSettingsToParams -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"
    }
    catch {
        Write-Error "Failed to load settings from DefaultSettings.json file: $_"
        AwaitKeyToExit
    }

    SaveSettings

    # Skip change summary if Silent parameter was passed
    if ($Silent) {
        return
    }

    PrintPendingChanges
    PrintHeader 'Default Mode'
}


function ShowDefaultModeAppRemovalOptions {
    PrintHeader 'Default Mode'

    Write-Host "Please note: The default selection of apps includes Microsoft Teams, Spotify, Sticky Notes and more. Select option 2 to verify and change what apps are removed by the script" -ForegroundColor DarkGray
    Write-Host ""

    Do {
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host " (n) Don't remove any apps" -ForegroundColor Yellow
        Write-Host " (1) Only remove the default selection of apps" -ForegroundColor Yellow
        Write-Host " (2) Manually select which apps to remove" -ForegroundColor Yellow
        $RemoveAppsInput = Read-Host "Do you want to remove any apps? Apps will be removed for all users (n/1/2)"

        # Show app selection form if user entered option 3
        if ($RemoveAppsInput -eq '2') {
            $result = OpenAppSelectionWindow

            if ($result -ne $true) {
                # User cancelled or closed app selection, change RemoveAppsInput so the menu will be shown again
                Write-Host ""
                Write-Host "Cancelled application selection, please try again" -ForegroundColor Red

                $RemoveAppsInput = 'c'
            }
            
            Write-Host ""
        }
    }
    while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2')

    return $RemoveAppsInput
}


function ShowAppRemoval {
    PrintHeader "App Removal"

    Write-Output "> Opening app selection form..."

    $result = OpenAppSelectionWindow

    if ($result -eq $true) {
        Write-Output "You have selected $($script:SelectedApps.Count) apps for removal"
        AddParameter 'RemoveAppsCustom'

        SaveSettings

        # Suppress prompt if Silent parameter was passed
        if (-not $Silent) {
            Write-Output ""
            Write-Output ""
            Write-Output "Press enter to remove the selected apps or press CTRL+C to quit..."
            Read-Host | Out-Null
            PrintHeader "App Removal"
        }
    }
    else {
        Write-Host "Selection was cancelled, no apps have been removed" -ForegroundColor Red
        Write-Output ""
    }
}


function LoadAndShowLastUsedSettings {
    PrintHeader 'Custom Mode'

    try {
        # Load settings from LastUsedSettings.json and add to params
        LoadSettingsToParams -filePath $script:SavedSettingsFilePath -expectedVersion "1.0"
    }
    catch {
        Write-Error "Failed to load settings from LastUsedSettings.json file: $_"
        AwaitKeyToExit
    }

    PrintPendingChanges
    PrintHeader 'Custom Mode'
}



##################################################################################################################
#                                                                                                                #
#                                                  SCRIPT START                                                  #
#                                                                                                                #
##################################################################################################################



# Get current Windows build version
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

# Check if the machine supports Modern Standby, this is used to determine if the DisableModernStandbyNetworking option can be used
$script:ModernStandbySupported = CheckModernStandbySupport

$script:Params = $PSBoundParameters

# Add default Apps parameter when RemoveApps is requested and Apps was not explicitly provided
if ((-not $script:Params.ContainsKey("Apps")) -and $script:Params.ContainsKey("RemoveApps")) {
    $script:Params.Add('Apps', 'Default')
}

$controlParamsCount = 0

# Count how many control parameters are set, to determine if any changes were selected by the user during runtime
foreach ($Param in $script:ControlParams) {
    if ($script:Params.ContainsKey($Param)) {
        $controlParamsCount++
    }
}

# Hide progress bars for app removal, as they block Win11Debloat's output
if (-not ($script:Params.ContainsKey("Verbose"))) {
    $ProgressPreference = 'SilentlyContinue'
}
else {
    Write-Host "Verbose mode is enabled"
    Write-Output ""
    Write-Output "Press any key to continue..."
    $null = [System.Console]::ReadKey()

    $ProgressPreference = 'Continue'
}

if ($script:Params.ContainsKey("Sysprep")) {
    $defaultUserPath = GetUserDirectory -userName "Default"

    # Exit script if run in Sysprep mode on Windows 10
    if ($WinVersion -lt 22000) {
        Write-Error "Win11Debloat Sysprep mode is not supported on Windows 10"
        AwaitKeyToExit
    }
}

# Make sure all requirements for User mode are met, if User is specified
if ($script:Params.ContainsKey("User")) {
    $userPath = GetUserDirectory -userName $script:Params.Item("User")
}

# Remove LastUsedSettings.json file if it exists and is empty
if ((Test-Path $script:SavedSettingsFilePath) -and ([String]::IsNullOrWhiteSpace((Get-content $script:SavedSettingsFilePath)))) {
    Remove-Item -Path $script:SavedSettingsFilePath -recurse
}

# Only run the app selection form if the 'RunAppsListGenerator' parameter was passed to the script
if ($RunAppsListGenerator) {
    PrintHeader "Custom Apps List Generator"

    $result = OpenAppSelectionWindow

    # Show different message based on whether the app selection was saved or cancelled
    if ($result -ne $true) {
        Write-Host "Application selection window was closed without saving." -ForegroundColor Red
    }
    else {
        Write-Output "Your app selection was saved to the 'CustomAppsList' file, found at:"
        Write-Host "$PSScriptRoot" -ForegroundColor Yellow
    }

    AwaitKeyToExit
}

# Change script execution based on provided parameters or user input
if ((-not $script:Params.Count) -or $RunDefaults -or $RunDefaultsLite -or $RunSavedSettings -or ($controlParamsCount -eq $script:Params.Count)) {
    if ($RunDefaults -or $RunDefaultsLite) {
        ShowDefaultModeOptions
    }
    elseif ($RunSavedSettings) {
        if (-not (Test-Path $script:SavedSettingsFilePath)) {
            PrintHeader 'Custom Mode'
            Write-Error "Unable to find LastUsedSettings.json file, no changes were made"
            AwaitKeyToExit
        }

        LoadAndShowLastUsedSettings
    }
    else {
        if ($CLI) {
            $Mode = ShowScriptMenuOptions 
        }
        else {
            try {
                $result = OpenGUI
            
                Stop-Transcript
                Exit
            }
            catch {
                Write-Warning "Unable to load WPF GUI (not supported in this environment), falling back to CLI mode"
                if (-not $Silent) {
                    Write-Host ""
                    Write-Host "Press any key to continue..."
                    $null = [System.Console]::ReadKey()
                }

                $Mode = ShowScriptMenuOptions
            }
        }
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults and app removal options
        '1' { 
            ShowDefaultModeOptions
        }

        # App removal, remove apps based on user selection
        '2' {
            ShowAppRemoval
        }

        # Load last used options from the "LastUsedSettings.json" file
        '3' {
            LoadAndShowLastUsedSettings
        }
    }
}
else {
    PrintHeader 'Configuration'
}

# If the number of keys in ControlParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if (($controlParamsCount -eq $script:Params.Keys.Count) -or ($script:Params.Keys.Count -eq 1 -and ($script:Params.Keys -contains 'CreateRestorePoint' -or $script:Params.Keys -contains 'Apps'))) {
    Write-Output "The script completed without making any changes."
    AwaitKeyToExit
}

# Execute all selected/provided parameters using the consolidated function
# (This also handles restore point creation if requested)
ExecuteAllChanges

RestartExplorer

Write-Output ""
Write-Output ""
Write-Output ""
Write-Output "Script completed! Please check above for any errors."

AwaitKeyToExit
