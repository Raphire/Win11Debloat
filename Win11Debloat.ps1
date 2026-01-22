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
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableBing,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscreenTips,
    [switch]$DisableSuggestions,
    [switch]$DisableEdgeAds,
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
    [switch]$DisableWidgets, [switch]$HideWidgets,
    [switch]$HideChat, [switch]$DisableChat,
    [switch]$EnableEndTask,
    [switch]$EnableLastActiveClick,
    [switch]$ClearStart,
    [string]$ReplaceStart,
    [switch]$ClearStartAllUsers,
    [string]$ReplaceStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$DisableMouseAcceleration,
    [switch]$DisableStickyKeys,
    [switch]$HideHome,
    [switch]$HideGallery,
    [switch]$ExplorerToHome,
    [switch]$ExplorerToThisPC,
    [switch]$ExplorerToDownloads,
    [switch]$ExplorerToOneDrive,
    [switch]$AddFoldersToThisPC,
    [switch]$HideOnedrive, [switch]$DisableOnedrive,
    [switch]$Hide3dObjects, [switch]$Disable3dObjects,
    [switch]$HideMusic, [switch]$DisableMusic,
    [switch]$HideIncludeInLibrary, [switch]$DisableIncludeInLibrary,
    [switch]$HideGiveAccessTo, [switch]$DisableGiveAccessTo,
    [switch]$HideShare, [switch]$DisableShare
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
$script:MainMenuWindowSchema = "$script:AssetsPath/Schemas/MainMenuWindow.xaml"
$script:FeaturesFilePath = "$script:AssetsPath/Features.json"

$script:ControlParams = 'WhatIf', 'Confirm', 'Verbose', 'Debug', 'LogPath', 'Silent', 'Sysprep', 'User', 'NoRestartExplorer', 'RunDefaults', 'RunDefaultsLite', 'RunSavedSettings', 'RunAppsListGenerator', 'CLI'

# Check if current powershell environment is limited by security policies
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Error "Win11Debloat is unable to run on your system, powershell execution is restricted by security policies"
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Check if script does not see file dependencies
if (-not ((Test-Path $script:DefaultSettingsFilePath) -and (Test-Path $script:AppsListFilePath) -and (Test-Path $script:RegfilesPath) -and (Test-Path $script:AssetsPath) -and (Test-Path $script:AppSelectionSchema) -and (Test-Path $script:FeaturesFilePath))) {
    Write-Error "Win11Debloat is unable to find required files, please ensure all script files are present"
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
    AwaitKeyToExit
}

# Log script output to 'Win11Debloat.log' at the specified path
if ($LogPath -and (Test-Path $LogPath)) {
    Start-Transcript -Path "$LogPath/Win11Debloat.log" -Append -IncludeInvocationHeader -Force | Out-Null
}
else {
    Start-Transcript -Path $script:DefaultLogPath -Append -IncludeInvocationHeader -Force | Out-Null
}



##################################################################################################################
#                                                                                                                #
#                                              FUNCTION DEFINITIONS                                              #
#                                                                                                                #
##################################################################################################################



# Loads a JSON file from the specified path and returns the parsed object
# Returns $null if the file doesn't exist or if parsing fails
function LoadJsonFile {
    param (
        [string]$filePath,
        [string]$expectedVersion = $null
    )
    
    if (-not (Test-Path $filePath)) {
        Write-Error "File not found: $filePath"
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
    
    foreach ($setting in $settingsJson.Settings) {
        if ($setting.Value -eq $false) {
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


# Shows application selection window that allows the user to select what apps they want to remove or keep
function ShowAppSelectionWindow {
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    # Detect system theme (dark or light mode)
    $usesDarkMode = $false
    try {
        $appsTheme = Get-ItemPropertyValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
        $usesDarkMode = ($appsTheme -eq 0)
    }
    catch {
        $usesDarkMode = $false
    }

    # Load XAML from file
    $xaml = Get-Content -Path $script:AppSelectionSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()

    # Set colors based on theme (Windows 11 color scheme) as dynamic resources
    if ($usesDarkMode) {
        $window.Resources.Add("BgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#272727")))
        $window.Resources.Add("FgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")))
        $window.Resources.Add("BorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#363636")))
        $window.Resources.Add("LoadingBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#CC1C1C1C")))
        $window.Resources.Add("TitleBarBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#202020")))
        $window.Resources.Add("CloseHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c")))
        $window.Resources.Add("ListBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1f1f1f")))
        $window.Resources.Add("ButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3379d9")))
        $window.Resources.Add("ButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#559ce4")))
        $window.Resources.Add("SecondaryButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#343434")))
        $window.Resources.Add("SecondaryButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3D3D3D")))
        $fgColor = "#FFFFFF"
    }
    else {
        $window.Resources.Add("BgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f9f9f9")))
        $window.Resources.Add("FgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1A1A1A")))
        $window.Resources.Add("BorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#eaeaea")))
        $window.Resources.Add("LoadingBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#F0F3F3F3")))
        $window.Resources.Add("TitleBarBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#eaeaea")))
        $window.Resources.Add("CloseHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c")))
        $window.Resources.Add("ListBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FAFAFA")))
        $window.Resources.Add("ButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3379d9")))
        $window.Resources.Add("ButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#559ce4")))
        $window.Resources.Add("SecondaryButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")))
        $window.Resources.Add("SecondaryButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#eaeaea")))
        $fgColor = "#1A1A1A"
    }

    $appsPanel = $window.FindName('AppSelectionPanel')
    $checkAllBox = $window.FindName('CheckAllBox')
    $onlyInstalledBox = $window.FindName('OnlyInstalledBox')
    $confirmBtn = $window.FindName('ConfirmBtn')
    $cancelBtn = $window.FindName('CancelBtn')
    $loadingIndicator = $window.FindName('LoadingIndicator')
    $titleBar = $window.FindName('TitleBar')
    $closeBtn = $window.FindName('CloseBtn')

    # Helper function to complete app loading with the winget list
    function LoadAppsWithWingetList($listOfApps) {
        # Store apps data for sorting
        $appsToAdd = @()

        # Read JSON file and parse apps
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
        
        # Go through appslist and collect apps
        Foreach ($appData in $jsonContent.Apps) {
            $appId = $appData.AppId.Trim()
            $friendlyName = $appData.FriendlyName
            $description = $appData.Description
            $appChecked = $appData.SelectedByDefault

            if ($appId.length -gt 0) {
                if ($onlyInstalledBox.IsChecked) {
                    # Only include app if it's installed
                    if (-not ($listOfApps -like ("*$appId*")) -and -not (Get-AppxPackage -Name $appId)) {
                        continue
                    }
                    if (($appId -eq "Microsoft.Edge") -and -not ($listOfApps -like "* Microsoft.Edge *")) {
                        continue
                    }
                }

                # Combine friendly name and app ID for display
                $displayName = if ($friendlyName) { "$friendlyName ($appId)" } else { $appId }
                $appsToAdd += [PSCustomObject]@{ AppId = $appId; DisplayName = $displayName; IsChecked = $appChecked; Description = $description }
            }
        }

        # Sort apps alphabetically and add to panel
        $appsToAdd | Sort-Object -Property DisplayName | ForEach-Object {
            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.Content = $_.DisplayName
            $checkbox.Tag = $_.AppId
            $checkbox.IsChecked = $_.IsChecked
            $checkbox.ToolTip = $_.Description
            $checkbox.Foreground = $fgColor
            $checkbox.Margin = "2,3,2,3"
            $appsPanel.Children.Add($checkbox) | Out-Null
        }

        # Hide loading indicator
        $loadingIndicator.Visibility = 'Collapsed'
    }

    # Function to load apps into the panel
    function LoadApps {
        # Disable confirm button during loading to prevent premature actions
        $confirmBtn.IsEnabled = $false
        
        # Show loading indicator and force UI update
        $loadingIndicator.Visibility = 'Visible'
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

        $appsPanel.Children.Clear()
        $listOfApps = ""

        if ($onlyInstalledBox.IsChecked -and ($script:WingetInstalled -eq $true)) {
            # Start job to get list of installed apps via winget
            $job = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
            $jobStartTime = Get-Date
            
            # Create timer to poll job status without blocking UI
            $pollTimer = New-Object System.Windows.Threading.DispatcherTimer
            $pollTimer.Interval = [TimeSpan]::FromMilliseconds(100)
            
            $pollTimer.Add_Tick({
                $elapsed = (Get-Date) - $jobStartTime
                
                # Check if job is complete or timed out (10 seconds)
                if ($job.State -eq 'Completed') {
                    $pollTimer.Stop()
                    $listOfApps = Receive-Job -Job $job
                    Remove-Job -Job $job
                    
                    # Continue with loading apps
                    LoadAppsWithWingetList $listOfApps
                    $confirmBtn.IsEnabled = $true
                }
                elseif ($elapsed.TotalSeconds -gt 10 -or $job.State -eq 'Failed') {
                    $pollTimer.Stop()
                    Remove-Job -Job $job -Force
                    
                    # Show error that the script was unable to get list of apps from winget
                    [System.Windows.MessageBox]::Show('Unable to load list of installed apps via winget.', 'Error', 'OK', 'Error') | Out-Null
                    $onlyInstalledBox.IsChecked = $false
                    
                    # Continue with loading all apps (unchecked now)
                    LoadAppsWithWingetList ""
                    $confirmBtn.IsEnabled = $true
                }
            }.GetNewClosure())
            
            $pollTimer.Start()
            return  # Exit here, timer will continue the work
        }
        
        # If checkbox is not checked or winget not installed, load all apps immediately
        LoadAppsWithWingetList $listOfApps
        $confirmBtn.IsEnabled = $true
    }

    # Event handlers
    $titleBar.Add_MouseLeftButtonDown({
        $window.DragMove()
    })

    $closeBtn.Add_Click({
        $window.Close()
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

        $script:SelectedApps = $selectedApps

        # Create file that stores selected apps if it doesn't exist
        if (-not (Test-Path $script:CustomAppsListFilePath)) {
            $null = New-Item $script:CustomAppsListFilePath -ItemType File
        }

        Set-Content -Path $script:CustomAppsListFilePath -Value $script:SelectedApps

        $window.DialogResult = $true
    })

    $cancelBtn.Add_Click({
        $window.Close()
    })

    # Load apps after window is shown (allows UI to render first)
    $window.Add_ContentRendered({ 
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{ LoadApps })
    })

    # Show the window and return dialog result
    return $window.ShowDialog()
}


# Returns a validated list of apps based on the provided appsList and the supported apps from Apps.json
function ValidateAppslist {
    param (
        $appsList
    )

    $supportedAppsList = @()
    $validatedAppsList = @()

    # Generate a list of supported apps from Apps.json
    $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
    Foreach ($appData in $jsonContent.Apps) {
        $appId = $appData.AppId.Trim()
        if ($appId.length -gt 0) {
            $supportedAppsList += $appId
        }
    }

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


# Removes apps specified during function call from all user accounts and from the OS image.
function RemoveApps {
    param (
        $appslist
    )

    Foreach ($app in $appsList) {
        Write-Output "Attempting to remove $app..."

        # Use winget only to remove OneDrive and Edge
        if (($app -eq "Microsoft.OneDrive") -or ($app -eq "Microsoft.Edge")) {
            if ($script:WingetInstalled -eq $false) {
                Write-Host "WinGet is either not installed or is outdated, $app could not be removed" -ForegroundColor Red
                continue
            }

            $appName = $app -replace '\.', '_'

            # Uninstall app via winget, or create a scheduled task to uninstall it later
            if ($script:Params.ContainsKey("User")) {
                RegImport "Adding scheduled task to uninstall $app for user $(GetUserName)..." "Uninstall_$($appName).reg"
            }
            elseif ($script:Params.ContainsKey("Sysprep")) {
                RegImport "Adding scheduled task to uninstall $app after new users log in..." "Uninstall_$($appName).reg"
            }
            else {
                # Uninstall app via winget, with any progress indicators removed from the output
                StripProgress -ScriptBlock { winget uninstall --accept-source-agreements --disable-interactivity --id $app } | Tee-Object -Variable wingetOutput

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "Uninstall failed with exit code")) {
                    Write-Host "Unable to uninstall Microsoft Edge via Winget" -ForegroundColor Red
                    Write-Output ""

                    if ($( Read-Host -Prompt "Would you like to forcefully uninstall Microsoft Edge? NOT RECOMMENDED! (y/n)" ) -eq 'y') {
                        Write-Output ""
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
                Write-Host "Removed $app for all users" -ForegroundColor DarkGray
            }
        }
        catch {
            if ($DebugPreference -ne "SilentlyContinue") {
                Write-Host "Unable to remove $app for all users" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }

        # Remove provisioned app from OS image, so the app won't be installed for any new users
        try {
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
        }
        catch {
            Write-Host "Unable to remove $app from windows image" -ForegroundColor Yellow
            Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
        }
    }

    Write-Output ""
}


# Forcefully removes Microsoft Edge using its uninstaller
# Credit: Based on work from loadstring1 & ave9858
function ForceRemoveEdge {
    Write-Output "> Forcefully uninstalling Microsoft Edge..."

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
        Write-Output "Running uninstaller..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-Output "Removing leftover files..."

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
                Write-Host "  Removed $path" -ForegroundColor DarkGray
            }
        }

        Write-Output "Cleaning up registry..."

        # Remove MS Edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-Output "Microsoft Edge was uninstalled"
    }
    else {
        Write-Output ""
        Write-Host "Error: Unable to forcefully uninstall Microsoft Edge, uninstaller could not be found" -ForegroundColor Red
    }

    Write-Output ""
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


# Returns the directory path of the specified user, exits script if user path can't be found
function GetUserDirectory {
    param (
        $userName,
        $fileName = "",
        $exitIfPathNotFound = $true
    )

    try {
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

    if ($script:Params.ContainsKey("Sysprep")) {
        $defaultUserPath = GetUserDirectory -userName "Default" -fileName "NTUSER.DAT"

        reg load "HKU\Default" $defaultUserPath | Out-Null
        reg import "$script:RegfilesPath\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null
    }
    elseif ($script:Params.ContainsKey("User")) {
        $userPath = GetUserDirectory -userName $script:Params.Item("User") -fileName "NTUSER.DAT"

        reg load "HKU\Default" $userPath | Out-Null
        reg import "$script:RegfilesPath\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null

    }
    else {
        reg import "$script:RegfilesPath\$path"  
    }

    Write-ToConsole ""
}


# Restart the Windows Explorer process
function RestartExplorer {
    Write-Output "> Attempting to restart the Windows Explorer process to apply all changes..."
    
    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User") -or $script:Params.ContainsKey("NoRestartExplorer")) {
        Write-Host "Process restart was skipped, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
        return
    }

    if ($script:Params.ContainsKey("DisableMouseAcceleration")) {
        Write-Host "Warning: Changes to the Enhance Pointer Precision setting will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableStickyKeys")) {
        Write-Host "Warning: Changes to the Sticky Keys setting will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableAnimations")) {
        Write-Host "Warning: Animations will only be disabled after a reboot" -ForegroundColor Yellow
    }

    # Only restart if the powershell process matches the OS architecture.
    # Restarting explorer from a 32bit PowerShell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem) {
        Write-Output "Restarting the Windows Explorer process... (This may cause your screen to flicker)"
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Host "Unable to restart Windows Explorer process, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
    }
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$script:AssetsPath/Start/start2.bin"
    )

    Write-Output "> Removing all pinned apps from the start menu for all users..."

    # Check if template bin file exists
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Error: Unable to clear start menu, start2.bin file missing from script folder" -ForegroundColor Red
        Write-Output ""
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
        Write-Output "Created LocalState folder for default user profile"
    }

    # Copy template to default profile
    Copy-Item -Path $startMenuTemplate -Destination $defaultStartMenuPath -Force
    Write-Output "Replaced start menu for the default user profile"
    Write-Output ""
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
        Write-Host "Error: Unable to replace start menu, template file not found" -ForegroundColor Red
        return
    }

    if ([IO.Path]::GetExtension($startMenuTemplate) -ne ".bin" ) {
        Write-Host "Error: Unable to replace start menu, template file is not a valid .bin file" -ForegroundColor Red
        return
    }

    $userName = [regex]::Match($startMenuBinFile, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value

    $backupBinFile = $startMenuBinFile + ".bak"

    if (Test-Path $startMenuBinFile) {
        # Backup current start menu file
        Move-Item -Path $startMenuBinFile -Destination $backupBinFile -Force
    }
    else {
        Write-Host "Unable to find original start2.bin file for user $userName, no backup was created for this user" -ForegroundColor Yellow
        New-Item -ItemType File -Path $startMenuBinFile -Force
    }

    # Copy template file
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-Output "Replaced start menu for user $userName"
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


function CreateSystemRestorePoint {
    Write-Output "> Attempting to create a system restore point..."

    $SysRestore = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval"

    if ($SysRestore.RPSessionInterval -eq 0) {
        if ($Silent -or $( Read-Host -Prompt "System restore is disabled, would you like to enable it and create a restore point? (y/n)") -eq 'y') {
            $enableSystemRestoreJob = Start-Job {
                try {
                    Enable-ComputerRestore -Drive "$env:SystemDrive"
                }
                catch {
                    Write-Host "Error: Failed to enable System Restore: $_" -ForegroundColor Red
                    return
                }
            }

            $enableSystemRestoreJobDone = $enableSystemRestoreJob | Wait-Job -TimeOut 20

            if (-not $enableSystemRestoreJobDone) {
                Write-Host "Error: Failed to enable system restore and create restore point, operation timed out" -ForegroundColor Red
                return
            }
            else {
                Receive-Job $enableSystemRestoreJob
            }
        }
        else {
            Write-Output ""
            return
        }
    }

    $createRestorePointJob = Start-Job {
        # Find existing restore points that are less than 24 hours old
        try {
            $recentRestorePoints = Get-ComputerRestorePoint | Where-Object { (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24) }
        }
        catch {
            Write-Host "Error: Unable to retrieve existing restore points: $_" -ForegroundColor Red
            return
        }

        if ($recentRestorePoints.Count -eq 0) {
            try {
                Checkpoint-Computer -Description "Restore point created by Win11Debloat" -RestorePointType "MODIFY_SETTINGS"
                Write-Output "System restore point created successfully"
            }
            catch {
                Write-Host "Error: Unable to create restore point: $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "A recent restore point already exists, no new restore point was created" -ForegroundColor Yellow
        }
    }

    $createRestorePointJobDone = $createRestorePointJob | Wait-Job -TimeOut 20

    if (-not $createRestorePointJobDone) {
        Write-Host "Error: Failed to create system restore point, operation timed out" -ForegroundColor Red
    }
    else {
        Receive-Job $createRestorePointJob
    }

    Write-Output ""
}


function ShowScriptMenuOptions {
    Do { 
        $ModeSelectionMessage = "Please select an option (1/2/3/0)" 

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


function ShowScriptUI {
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    # Get current Windows build version
    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

    # Detect system theme (dark or light mode)
    $usesDarkMode = $false
    try {
        $usesDarkMode = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme').AppsUseLightTheme -eq 0
    }
    catch {}

    # Load XAML from file
    $xamlPath = "$script:AssetsPath/Schemas/MainMenuWindow.xaml"
    $xaml = Get-Content -Path $xamlPath -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [System.Windows.Markup.XamlReader]::Load($reader)
    $reader.Close()

    # Set colors based on theme
    if ($usesDarkMode) {
        $window.Resources.Add("BgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#303030")))
        $window.Resources.Add("FgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#E0E0E0")))
        $window.Resources.Add("BorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#404040")))
        $window.Resources.Add("ButtonBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#404040")))
        $window.Resources.Add("TitleBarBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#202020")))
        $window.Resources.Add("ComboBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2A2A2A")))
        $window.Resources.Add("ComboHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2C2C2C")))
        $window.Resources.Add("AccentColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFD700")))
        $window.Resources.Add("ButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#0067c0")))
        $window.Resources.Add("ButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1E88E5")))
        $window.Resources.Add("ButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3284cc")))
        $window.Resources.Add("SecondaryButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2a2a2a")))
        $window.Resources.Add("SecondaryButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#2d2d2d")))
        $window.Resources.Add("SecondaryButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#272727")))
        $window.Resources.Add("CloseHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c")))
        $window.Resources.Add("ScrollBarThumbColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3d3d3d")))
        $window.Resources.Add("ScrollBarThumbHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#4b4b4b")))
    }
    else {
        $window.Resources.Add("BgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#fdfdfd")))
        $window.Resources.Add("FgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#000000")))
        $window.Resources.Add("BorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ededed")))
        $window.Resources.Add("ButtonBorderColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#d3d3d3")))
        $window.Resources.Add("TitleBarBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#f3f3f3")))
        $window.Resources.Add("ComboBgColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")))
        $window.Resources.Add("ComboHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#fafafa")))
        $window.Resources.Add("AccentColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#ffae00")))
        $window.Resources.Add("ButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#0067c0")))
        $window.Resources.Add("ButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1E88E5")))
        $window.Resources.Add("ButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3284cc")))
        $window.Resources.Add("SecondaryButtonBg", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#fefefe")))
        $window.Resources.Add("SecondaryButtonHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#fafafa")))
        $window.Resources.Add("SecondaryButtonPressed", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF")))
        $window.Resources.Add("CloseHover", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#c42b1c")))
        $window.Resources.Add("ScrollBarThumbColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#b9b9b9")))
        $window.Resources.Add("ScrollBarThumbHoverColor", [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#8b8b8b")))
    }

    # Get named elements
    $titleBar = $window.FindName('TitleBar')
    $closeBtn = $window.FindName('CloseBtn')
    $helpBtn = $window.FindName('HelpBtn')

    # Title bar event handlers
    $titleBar.Add_MouseLeftButtonDown({
        $window.DragMove()
    })

    $closeBtn.Add_Click({
        $window.Close()
    })
    
    $helpBtn.Add_Click({
        Start-Process "https://github.com/Raphire/Win11Debloat/wiki"
    })

    # Integrated App Selection UI
    $appsPanel = $window.FindName('AppSelectionPanel')
    $onlyInstalledAppsBox = $window.FindName('OnlyInstalledAppsBox')
    $loadingAppsIndicator = $window.FindName('LoadingAppsIndicator')
    $appSelectionStatus = $window.FindName('AppSelectionStatus')
    $defaultAppsBtn = $window.FindName('DefaultAppsBtn')
    $loadLastUsedAppsBtn = $window.FindName('LoadLastUsedAppsBtn')
    $clearAppSelectionBtn = $window.FindName('ClearAppSelectionBtn')
    
    # Apply Tab UI Elements
    $consoleOutput = $window.FindName('ConsoleOutput')
    $consoleScrollViewer = $window.FindName('ConsoleScrollViewer')
    $applyStatusText = $window.FindName('ApplyStatusText')
    $applyProgressBar = $window.FindName('ApplyProgressBar')
    $applyProgressText = $window.FindName('ApplyProgressText')
    $startApplyBtn = $window.FindName('StartApplyBtn')
    $finishBtn = $window.FindName('FinishBtn')
    
    # Function to write to console output in UI
    function Write-ToConsole {
        param(
            [string]$message
        )
        
        if ($consoleOutput) {
            $timestamp = Get-Date -Format "HH:mm:ss"
            $consoleOutput.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Send, [action]{
                $consoleOutput.Text += "[$timestamp] $message`n"
                # Auto-scroll to bottom
                $consoleScrollViewer.ScrollToEnd()
            })
        }
        
        # Also write to actual console for logging
        Write-Host $message
    }

    # Function to update selection status
    function UpdateAppSelectionStatus {
        $selectedCount = 0
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedCount++
            }
        }
        $appSelectionStatus.Text = "$selectedCount app(s) selected for removal"
    }

    # Function to dynamically build Tweaks UI from Features.json
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
                $checkbox.Margin = '0,0,0,10'
                $checkbox.Padding = '0,2'
                $checkbox.IsChecked = $false
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
            $lbl = New-Object System.Windows.Controls.TextBlock
            $lbl.Text = $labelText
            $lbl.Style = $window.Resources['LabelStyle']
            $labelName = "$comboName`_Label"
            $lbl.Name = $labelName
            $parent.Children.Add($lbl) | Out-Null
            
            # Register the label with the window's name scope
            try {
                [System.Windows.NameScope]::SetNameScope($lbl, [System.Windows.NameScope]::GetNameScope($window))
                $window.RegisterName($labelName, $lbl)
            }
            catch {
                # Name might already be registered, ignore
            }

            $combo = New-Object System.Windows.Controls.ComboBox
            $combo.Name = $comboName
            $combo.Margin = '0,0,0,10'
            foreach ($it in $items) { $cbItem = New-Object System.Windows.Controls.ComboBoxItem; $cbItem.Content = $it; $combo.Items.Add($cbItem) | Out-Null }
            $combo.SelectedIndex = 0
            $parent.Children.Add($combo) | Out-Null
            
            # Register the combo box with the window's name scope so FindName works
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
            $target = $columns | Sort-Object { $_.Children.Count } | Select-Object -First 1

            $border = New-Object System.Windows.Controls.Border
            $border.BorderBrush = $window.Resources['BorderColor']
            $border.BorderThickness = 1
            $border.CornerRadius = New-Object System.Windows.CornerRadius(4)
            $border.Background = $window.Resources['BgColor']
            $border.Padding = '16,12'
            $border.Margin = '0,0,0,16'
            $border.Tag = 'DynamicCategory'

            $panel = New-Object System.Windows.Controls.StackPanel
            $safe = ($category -replace '[^a-zA-Z0-9_]','_')
            $panel.Name = "Category_{0}_Panel" -f $safe

            $header = New-Object System.Windows.Controls.TextBlock
            $header.Text = $category
            $header.FontWeight = 'Bold'
            $header.FontSize = 14
            $header.Margin = '0,0,0,10'
            $header.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'FgColor')
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

            # Add any groups for this category (in original order)
            if ($featuresJson.UiGroups) {
                foreach ($group in $featuresJson.UiGroups) {
                    if ($group.Category -ne $category) { continue }
                    $items = @('No Change') + ($group.Values | ForEach-Object { $_.Label })
                    $comboName = 'Group_{0}Combo' -f $group.GroupId
                    $combo = CreateLabeledCombo -parent $panel -labelText $group.Label -comboName $comboName -items $items
                    $script:UiControlMappings[$comboName] = @{ Type='group'; Values = $group.Values; Label = $group.Label }
                }
            }

            # Add individual features for this category, preserving Features.json order
            foreach ($feature in $featuresJson.Features) {
                if ($feature.Category -ne $category) { continue }
                
                # Check version and feature compatibility using Features.json
                if (($feature.MinVersion -and $WinVersion -lt $feature.MinVersion) -or ($feature.MaxVersion -and $WinVersion -gt $feature.MaxVersion) -or ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and (-not $script:ModernStandbySupported))) {
                    continue
                }

                # Skip if feature part of a group
                $inGroup = $false
                if ($featuresJson.UiGroups) {
                    foreach ($g in $featuresJson.UiGroups) { foreach ($val in $g.Values) { if ($val.FeatureIds -contains $feature.FeatureId) { $inGroup = $true; break } }; if ($inGroup) { break } }
                }
                if ($inGroup) { continue }

                $opt = 'Apply'
                if ($feature.FeatureId -match '^Disable') { $opt = 'Disable' } elseif ($feature.FeatureId -match '^Enable') { $opt = 'Enable' }
                $items = @('No Change', $opt)
                $comboName = ("Feature_{0}_Combo" -f $feature.FeatureId) -replace '[^a-zA-Z0-9_]',''
                $combo = CreateLabeledCombo -parent $panel -labelText ($feature.Action + ' ' + $feature.Label) -comboName $comboName -items $items
                $script:UiControlMappings[$comboName] = @{ Type='feature'; FeatureId = $feature.FeatureId; Action = $feature.Action }
            }
        }
    }

    # Helper function to complete app loading with the winget list
    function script:LoadAppsWithList($listOfApps) {
        # Store apps data for sorting
        $appsToAdd = @()

        # Read JSON file and parse apps
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
        
        # Go through appslist and collect apps
        Foreach ($appData in $jsonContent.Apps) {
            $appId = $appData.AppId.Trim()
            $friendlyName = $appData.FriendlyName
            $description = $appData.Description
            $appChecked = $false  # Start with nothing checked

            if ($appId.length -gt 0) {
                if ($onlyInstalledAppsBox.IsChecked) {
                    # Only include app if it's installed
                    if (-not ($listOfApps -like ("*$appId*")) -and -not (Get-AppxPackage -Name $appId)) {
                        continue
                    }
                    if (($appId -eq "Microsoft.Edge") -and -not ($listOfApps -like "* Microsoft.Edge *")) {
                        continue
                    }
                }

                # Combine friendly name and app ID for display
                $displayName = if ($friendlyName) { "$friendlyName ($appId)" } else { $appId }
                $appsToAdd += [PSCustomObject]@{ 
                    AppId = $appId
                    DisplayName = $displayName
                    IsChecked = $appChecked
                    Description = $description
                    SelectedByDefault = $appData.SelectedByDefault
                    IsGamingApp = $appData.IsGamingApp
                    IsCommApp = $appData.IsCommApp
                }
            }
        }

        # Sort apps alphabetically and add to panel
        $appsToAdd | Sort-Object -Property DisplayName | ForEach-Object {
            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.Content = $_.DisplayName
            $checkbox.Tag = $_.AppId
            $checkbox.IsChecked = $_.IsChecked
            $checkbox.ToolTip = $_.Description
            $checkbox.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, "FgColor")
            $checkbox.Margin = "2,3,2,3"
            
            # Store metadata in checkbox for later use
            Add-Member -InputObject $checkbox -MemberType NoteProperty -Name "SelectedByDefault" -Value $_.SelectedByDefault
            Add-Member -InputObject $checkbox -MemberType NoteProperty -Name "IsGamingApp" -Value $_.IsGamingApp
            Add-Member -InputObject $checkbox -MemberType NoteProperty -Name "IsCommApp" -Value $_.IsCommApp
            
            # Add event handler to update status
            $checkbox.Add_Checked({ UpdateAppSelectionStatus })
            $checkbox.Add_Unchecked({ UpdateAppSelectionStatus })
            
            $appsPanel.Children.Add($checkbox) | Out-Null
        }

        # Hide loading indicator and navigation blocker, update status
        $loadingAppsIndicator.Visibility = 'Collapsed'

        UpdateAppSelectionStatus
    }

    # Function to load apps into the panel
    function LoadAppsIntoMainUI {
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
            $job = $null
            $jobStartTime = $null

            if ($onlyInstalledAppsBox.IsChecked -and ($script:WingetInstalled -eq $true)) {
                # Start job to get list of installed apps via winget
                $job = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
                $jobStartTime = Get-Date
                
                # Create timer to poll job status without blocking UI
                $pollTimer = New-Object System.Windows.Threading.DispatcherTimer
                $pollTimer.Interval = [TimeSpan]::FromMilliseconds(100)
                
                $pollTimer.Add_Tick({
                    $elapsed = (Get-Date) - $jobStartTime
                    
                    # Check if job is complete or timed out (10 seconds)
                    if ($job.State -eq 'Completed') {
                        $pollTimer.Stop()
                        $listOfApps = Receive-Job -Job $job
                        Remove-Job -Job $job
                        
                        # Continue with loading apps
                        LoadAppsWithList $listOfApps
                    }
                    elseif ($elapsed.TotalSeconds -gt 10 -or $job.State -eq 'Failed') {
                        $pollTimer.Stop()
                        Remove-Job -Job $job -Force
                        
                        # Show error that the script was unable to get list of apps from winget
                        [System.Windows.MessageBox]::Show('Unable to load list of installed apps via winget.', 'Error', 'OK', 'Error') | Out-Null
                        $onlyInstalledAppsBox.IsChecked = $false
                        
                        # Continue with loading all apps (unchecked now)
                        LoadAppsWithList ""
                    }
                }.GetNewClosure())
                
                $pollTimer.Start()
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

    # Load Last Used App Selection button - only visible if CustomAppsList exists and has content
    if ((Test-Path $script:CustomAppsListFilePath)) {
        try {
            $savedApps = ReadAppslistFromFile $script:CustomAppsListFilePath
            if ($savedApps -and $savedApps.Count -gt 0) {
                $loadLastUsedAppsBtn.Add_Click({
                    try {
                        $savedApps = ReadAppslistFromFile $script:CustomAppsListFilePath
                        foreach ($child in $appsPanel.Children) {
                            if ($child -is [System.Windows.Controls.CheckBox]) {
                                if ($savedApps -contains $child.Tag) {
                                    $child.IsChecked = $true
                                } else {
                                    $child.IsChecked = $false
                                }
                            }
                        }
                    }
                    catch {
                        [System.Windows.MessageBox]::Show("Failed to load last used app selection: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                    }
                })
            }
            else {
                # Hide the button if CustomAppsList is empty
                $loadLastUsedAppsBtn.Visibility = 'Collapsed'
            }
        }
        catch {
            # Hide the button if there's an error reading the file
            $loadLastUsedAppsBtn.Visibility = 'Collapsed'
        }
    }
    else {
        # Hide the button if CustomAppsList doesn't exist
        $loadLastUsedAppsBtn.Visibility = 'Collapsed'
    }

    $clearAppSelectionBtn.Add_Click({
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.IsChecked = $false
            }
        }
    })

    # App Search Box functionality
    $appSearchBox = $window.FindName('AppSearchBox')
    $appSearchPlaceholder = $window.FindName('AppSearchPlaceholder')
    $highlightColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFF4CE"))
    $highlightColorDark = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#4A4A2A"))
    
    $appSearchBox.Add_TextChanged({
        $searchText = $appSearchBox.Text.ToLower().Trim()
        
        # Show/hide placeholder
        if ([string]::IsNullOrWhiteSpace($appSearchBox.Text)) {
            $appSearchPlaceholder.Visibility = 'Visible'
        } else {
            $appSearchPlaceholder.Visibility = 'Collapsed'
        }
        
        # Clear all highlights first
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.Background = [System.Windows.Media.Brushes]::Transparent
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($searchText)) {
            return
        }
        
        # Find and highlight all matching apps
        $firstMatch = $null
        $usesDarkMode = $window.Resources["BgColor"].Color.R -lt 128
        $highlightBrush = if ($usesDarkMode) { $highlightColorDark } else { $highlightColor }
        
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                # Only consider visible apps (not filtered out by installed filter)
                if ($child.Visibility -eq 'Visible') {
                    $appName = $child.Content.ToString().ToLower()
                    if ($appName.Contains($searchText)) {
                        # Highlight the matching app
                        $child.Background = $highlightBrush
                        
                        # Remember first match for scrolling
                        if ($null -eq $firstMatch) {
                            $firstMatch = $child
                        }
                    }
                }
            }
        }
        
        # Scroll to first match - centered
        if ($firstMatch) {
            # Get the ScrollViewer that contains the apps panel
            $scrollViewer = $null
            $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($appsPanel)
            while ($parent -ne $null) {
                if ($parent -is [System.Windows.Controls.ScrollViewer]) {
                    $scrollViewer = $parent
                    break
                }
                $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
            }
            
            if ($scrollViewer) {
                # Calculate the position to scroll to for centering
                $itemPosition = $firstMatch.TransformToAncestor($appsPanel).Transform([System.Windows.Point]::new(0, 0)).Y
                $viewportHeight = $scrollViewer.ViewportHeight
                $itemHeight = $firstMatch.ActualHeight
                
                # Center the item in the viewport
                $targetOffset = $itemPosition - ($viewportHeight / 2) + ($itemHeight / 2)
                $scrollViewer.ScrollToVerticalOffset([Math]::Max(0, $targetOffset))
            } else {
                # Fallback to simple bring into view
                $firstMatch.BringIntoView()
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

        if ($username.Length -eq 0) {
            $usernameValidationMessage.Text = "[X] Please enter a username"
            $usernameValidationMessage.Foreground = "#c42b1c"
            return $false
        }
        
        if ($username -eq $env:USERNAME) {
            $usernameValidationMessage.Text = "[X] Cannot enter your own username. Use 'Current User' option instead."
            $usernameValidationMessage.Foreground = "#c42b1c"
            return $false
        }
        
        try {
            $userProfile = Get-LocalUser -Name $username -ErrorAction Stop
            return $true
        }
        catch {
            $usernameValidationMessage.Text = "[X] User not found. Please enter a valid username."
            $usernameValidationMessage.Foreground = "#c42b1c"
            return $false
        }
    }

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
        
        # Hide bottom navigation and progress indicators on home page
        if ($currentIndex -eq 0) {
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
            $textBlock.Text = "No changes selected."
            $textBlock.Foreground = $window.Resources["FgColor"]
            $textBlock.FontStyle = "Italic"
            $textBlock.Margin = "0,0,0,8"
            $overviewChangesPanel.Children.Add($textBlock) | Out-Null
        }
        else {
            foreach ($change in $changesList) {
                $bullet = New-Object System.Windows.Controls.TextBlock
                $bullet.Text = "- $change"
                $bullet.Foreground = $window.Resources["FgColor"]
                $bullet.Margin = "0,0,0,8"
                $bullet.TextWrapping = "Wrap"
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

    # Handle Overview Apply Changes button
    $overviewApplyBtn = $window.FindName('OverviewApplyBtn')
    $overviewApplyBtn.Add_Click({
        if (-not (ValidateOtherUsername)) {
            [System.Windows.MessageBox]::Show("Please enter a valid username for 'Other User' selection.", "Invalid Username", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }

        # Navigate to Apply tab (last tab)
        $tabControl.SelectedIndex = $tabControl.Items.Count - 1
        UpdateNavigationButtons
    })

    # Load all apps on startup and build tweaks UI dynamically
    $window.Add_Loaded({
        # Build dynamic tweaks controls
        BuildDynamicTweaks

        # Load all apps (not just installed ones)
        LoadAppsIntoMainUI

        # Initialize navigation buttons
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
        }
        
        ApplySettingsToUiControls -window $window -settingsJson $defaultsJson -uiControlMappings $script:UiControlMappings
    })

    # Handle Load Last Used button
    $loadLastUsedBtn = $window.FindName('LoadLastUsedBtn')
    $lastUsedJson = LoadJsonFile -filePath $script:SavedSettingsFilePath -expectedVersion "1.0"
    
    # Check if file exists and has settings with Value = true
    $hasSettings = $false
    if ($lastUsedJson -and $lastUsedJson.Settings) {
        foreach ($setting in $lastUsedJson.Settings) {
            if ($setting.Value -eq $true) {
                $hasSettings = $true
                break
            }
        }
    }
    
    if ($hasSettings) {
        $loadLastUsedBtn.Add_Click({
            try {
                $lastUsedJson = LoadJsonFile -filePath $script:SavedSettingsFilePath -expectedVersion "1.0"
                if ($lastUsedJson) {
                    ApplySettingsToUiControls -window $window -settingsJson $lastUsedJson -uiControlMappings $script:UiControlMappings
                }
                else {
                    [System.Windows.MessageBox]::Show("Failed to load last used settings file", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
                }
            }
            catch {
                [System.Windows.MessageBox]::Show("Failed to load last used settings: $_", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        })
    }
    else {
        # Hide the button if LastUsedSettings.json doesn't exist or has no settings
        $loadLastUsedBtn.Visibility = 'Collapsed'
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

    # Start Apply button handler (on Apply tab)
    $startApplyBtn.Add_Click({
        # Calculate control params count
        $controlParamsCount = 0
        foreach ($Param in $script:ControlParams) {
            if ($script:Params.ContainsKey($Param)) {
                $controlParamsCount++
            }
        }
        
        # Disable navigation during apply
        $previousBtn.IsEnabled = $false
        $nextBtn.IsEnabled = $false
        $startApplyBtn.IsEnabled = $false
        
        # Clear console
        $consoleOutput.Text = ""
        $applyStatusText.Text = "Applying changes..."
        $applyProgressText.Text = "Processing..."

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
                    # Re-enable navigation buttons
                    $previousBtn.IsEnabled = $true
                    $nextBtn.IsEnabled = $true
                    $startApplyBtn.IsEnabled = $true

                    return
                }
            }
            
            $script:SelectedApps = $selectedApps
            AddParameter 'RemoveApps'
            AddParameter 'Apps' ($script:SelectedApps -join ',')
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
        if ($totalChanges -eq 0) {
            [System.Windows.MessageBox]::Show(
                'No changes have been selected. Please select at least one app to remove or one tweak to apply before continuing.',
                'No Changes Selected',
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            )
            
            # Re-enable navigation buttons
            $previousBtn.IsEnabled = $true
            $nextBtn.IsEnabled = $true
            $startApplyBtn.IsEnabled = $true
            
            return
        }
        
        # Store selected user mode
        switch ($userSelectionCombo.SelectedIndex) {
            1 { AddParameter User ($otherUsernameTextBox.Text.Trim()) }
            2 { AddParameter Sysprep }
        }

        SaveSettings

        Write-ToConsole "Starting configuration..."
        Write-ToConsole "Total changes to apply: $totalChanges"
        
        # Run changes in background to keep UI responsive
        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
            try {
                $script:ApplyFromUI = $true
                
                # Calculate total steps (exclude control parameters)
                $totalSteps = $script:Params.Count - $controlParamsCount
                $currentStep = 0
                
                # Get parent width for progress bar
                $progressBarParent = $applyProgressBar.Parent
                $maxWidth = 0
                $progressBarParent.Dispatcher.Invoke([action]{ $maxWidth = $progressBarParent.ActualWidth })
                
                # Function to update progress
                $updateProgress = {
                    param($step, $total)
                    $progressBarParent.Dispatcher.Invoke([action]{
                        $progressPercent = ($step / $total) * 100
                        $applyProgressBar.Width = ($maxWidth * $progressPercent / 100)
                        $stepPadded = $step.ToString().PadLeft($total.ToString().Length, '0')
                        $applyProgressText.Text = "Completed $stepPadded of $total changes"
                    })
                }
                
                Write-ToConsole "Applying configuration..."
                Write-ToConsole ""
                
                # Create restore point if requested
                if ($script:Params.ContainsKey("CreateRestorePoint")) {
                    Write-ToConsole "Creating system restore point..."
                    
                    $SysRestore = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction SilentlyContinue
                    
                    if ($SysRestore.RPSessionInterval -eq 0) {
                        try {
                            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -Value 1440 -ErrorAction Stop
                            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPGlobalInterval" -Value 1440 -ErrorAction Stop
                            Write-ToConsole "Enabled system restore point creation"
                        }
                        catch {
                            Write-ToConsole "Warning: Could not enable system restore"
                        }
                    }
                    
                    $createRestorePointJob = Start-Job {
                        try {
                            Enable-ComputerRestore -Drive "$env:SYSTEMDRIVE" -ErrorAction SilentlyContinue | Out-Null
                            Checkpoint-Computer -Description "Win11Debloat restore point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
                            return $true
                        }
                        catch {
                            return $false
                        }
                    }
                    
                    $createRestorePointJobDone = $createRestorePointJob | Wait-Job -TimeOut 20
                    
                    if (-not $createRestorePointJobDone) {
                        Write-ToConsole "Warning: Restore point creation timed out"
                    }
                    else {
                        $result = Receive-Job -Job $createRestorePointJob
                        if ($result) {
                            Write-ToConsole "System restore point created successfully"
                        }
                        else {
                            Write-ToConsole "Warning: Failed to create restore point"
                        }
                    }
                    Write-ToConsole ""
                }
                
                # Execute all selected/provided parameters
                foreach ($paramKey in $script:Params.Keys) {
                    if ($script:ControlParams -contains $paramKey) {
                        continue
                    }
                    
                    $currentStep++
                    & $updateProgress $currentStep $totalSteps
                    
                    switch ($paramKey) {
                        'RemoveApps' {
                            Write-ToConsole "Removing selected apps..."
                            $appsList = GenerateAppsList
                            if ($appsList.Count -gt 0) {
                                Write-ToConsole "$($appsList.Count) apps selected for removal"
                                $appIndex = 0
                                foreach ($app in $appsList) {
                                    $appIndex++
                                    $appIndexPadded = $appIndex.ToString().PadLeft($appsList.Count.ToString().Length, '0')
                                    Write-ToConsole "[$appIndexPadded/$($appsList.Count)] Removing $app..."
                                    
                                    # Update status text
                                    $applyStatusText.Dispatcher.Invoke([action]{
                                        $applyStatusText.Text = "Removing apps... [$appIndexPadded/$($appsList.Count)]"
                                    })
                                    
                                    RemoveApps @($app)
                                    
                                    # Update progress bar for each app
                                    $subProgress = $currentStep + ($appIndex / $appsList.Count)
                                    & $updateProgress ([Math]::Floor($subProgress)) $totalSteps
                                    
                                    # Force UI to process pending updates
                                    $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
                                }
                            }
                            Write-ToConsole ""
                            continue
                        }
                        'RemoveAppsCustom' {
                            Write-ToConsole "Removing selected apps..."
                            $appsList = ReadAppslistFromFile $script:CustomAppsListFilePath
                            if ($appsList.Count -gt 0) {
                                Write-ToConsole "$($appsList.Count) apps selected for removal"
                                $appIndex = 0
                                foreach ($app in $appsList) {
                                    $appIndex++
                                    $appIndexPadded = $appIndex.ToString().PadLeft($appsList.Count.ToString().Length, ' ')
                                    Write-ToConsole "[$appIndexPadded/$($appsList.Count)] Removing $app..."
                                    
                                    # Update status text
                                    $applyStatusText.Dispatcher.Invoke([action]{
                                        $applyStatusText.Text = "Removing apps... [$appIndexPadded/$($appsList.Count)]"
                                    })
                                    
                                    RemoveApps @($app)
                                    
                                    # Update progress bar for each app
                                    $subProgress = $currentStep + ($appIndex / $appsList.Count)
                                    & $updateProgress ([Math]::Floor($subProgress)) $totalSteps
                                    
                                    # Force UI to process pending updates
                                    $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
                                }
                            }
                            Write-ToConsole ""
                            continue
                        }
                        'RemoveCommApps' {
                            Write-ToConsole "Removing Mail, Calendar and People apps..."
                            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
                            RemoveApps $appsList
                            Write-ToConsole ""
                            continue
                        }
                        'RemoveW11Outlook' {
                            Write-ToConsole "Removing new Outlook for Windows app..."
                            $appsList = 'Microsoft.OutlookForWindows'
                            RemoveApps $appsList
                            Write-ToConsole ""
                            continue
                        }
                        'RemoveGamingApps' {
                            Write-ToConsole "Removing gaming related apps..."
                            $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
                            RemoveApps $appsList
                            Write-ToConsole ""
                            continue
                        }
                        'RemoveHPApps' {
                            Write-ToConsole "Removing HP apps..."
                            $appsList = 'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl'
                            RemoveApps $appsList
                            Write-ToConsole ""
                            continue
                        }
                        "ForceRemoveEdge" {
                            Write-ToConsole "Force removing Microsoft Edge..."
                            ForceRemoveEdge
                            Write-ToConsole ""
                            continue
                        }
                        'DisableDVR' {
                            Write-ToConsole "Disabling Xbox game/screen recording..."
                            RegImport "" "Disable_DVR.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableGameBarIntegration' {
                            Write-ToConsole "Disabling Game Bar integration..."
                            RegImport "" "Disable_Game_Bar_Integration.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableTelemetry' {
                            Write-ToConsole "Disabling telemetry, diagnostic data and targeted ads..."
                            RegImport "" "Disable_Telemetry.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
                            Write-ToConsole "Disabling tips, tricks and suggestions across Windows..."
                            RegImport "" "Disable_Windows_Suggestions.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableEdgeAds' {
                            Write-ToConsole "Disabling ads and suggestions in Microsoft Edge..."
                            RegImport "" "Disable_Edge_Ads_And_Suggestions.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
                            Write-ToConsole "Disabling tips & tricks on the lockscreen..."
                            RegImport "" "Disable_Lockscreen_Tips.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableDesktopSpotlight' {
                            Write-ToConsole "Disabling Windows Spotlight desktop background..."
                            RegImport "" "Disable_Desktop_Spotlight.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableSettings365Ads' {
                            Write-ToConsole "Disabling Microsoft 365 ads in Settings..."
                            RegImport "" "Disable_Settings_365_Ads.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableSettingsHome' {
                            Write-ToConsole "Disabling the Settings Home page..."
                            RegImport "" "Disable_Settings_Home.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "DisableBingSearches", "DisableBing"} {
                            Write-ToConsole "Disabling Bing web search and Cortana..."
                            RegImport "" "Disable_Bing_Cortana_In_Search.reg"
                            $appsList = 'Microsoft.BingSearch'
                            RemoveApps $appsList
                            Write-ToConsole ""
                            continue
                        }
                        'DisableCopilot' {
                            Write-ToConsole "Disabling Microsoft Copilot..."
                            RegImport "" "Disable_Copilot.reg"
                            $appsList = 'Microsoft.Copilot'
                            RemoveApps $appsList
                            Write-ToConsole ""
                            continue
                        }
                        'DisableRecall' {
                            Write-ToConsole "Disabling Windows Recall..."
                            RegImport "" "Disable_AI_Recall.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableClickToDo' {
                            Write-ToConsole "Disabling Click to Do..."
                            RegImport "" "Disable_Click_to_Do.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableEdgeAI' {
                            Write-ToConsole "Disabling AI features in Microsoft Edge..."
                            RegImport "" "Disable_Edge_AI_Features.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisablePaintAI' {
                            Write-ToConsole "Disabling AI features in Paint..."
                            RegImport "" "Disable_Paint_AI_Features.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableNotepadAI' {
                            Write-ToConsole "Disabling AI features in Notepad..."
                            RegImport "" "Disable_Notepad_AI_Features.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'RevertContextMenu' {
                            Write-ToConsole "Restoring Windows 10 style context menu..."
                            RegImport "" "Disable_Show_More_Options_Context_Menu.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableMouseAcceleration' {
                            Write-ToConsole "Turning off Enhanced Pointer Precision..."
                            RegImport "" "Disable_Enhance_Pointer_Precision.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableStickyKeys' {
                            Write-ToConsole "Disabling Sticky Keys keyboard shortcut..."
                            RegImport "" "Disable_Sticky_Keys_Shortcut.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableFastStartup' {
                            Write-ToConsole "Disabling Fast Start-up..."
                            RegImport "" "Disable_Fast_Startup.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableModernStandbyNetworking' {
                            Write-ToConsole "Disabling network during Modern Standby..."
                            RegImport "" "Disable_Modern_Standby_Networking.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ClearStart' {
                            Write-ToConsole "Clearing start menu for user $(GetUserName)..."
                            ReplaceStartMenu
                            Write-ToConsole ""
                            continue
                        }
                        'ReplaceStart' {
                            Write-ToConsole "Replacing start menu for user $(GetUserName)..."
                            ReplaceStartMenu $script:Params.Item("ReplaceStart")
                            Write-ToConsole ""
                            continue
                        }
                        'ClearStartAllUsers' {
                            Write-ToConsole "Clearing start menu for all users..."
                            ReplaceStartMenuForAllUsers
                            Write-ToConsole ""
                            continue
                        }
                        'ReplaceStartAllUsers' {
                            Write-ToConsole "Replacing start menu for all users..."
                            ReplaceStartMenuForAllUsers $script:Params.Item("ReplaceStartAllUsers")
                            Write-ToConsole ""
                            continue
                        }
                        'DisableStartRecommended' {
                            Write-ToConsole "Disabling start menu recommended section..."
                            RegImport "" "Disable_Start_Recommended.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableStartPhoneLink' {
                            Write-ToConsole "Disabling Phone Link in start menu..."
                            RegImport "" "Disable_Phone_Link_In_Start.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'EnableDarkMode' {
                            Write-ToConsole "Enabling dark mode..."
                            RegImport "" "Enable_Dark_Mode.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableTransparency' {
                            Write-ToConsole "Disabling transparency effects..."
                            RegImport "" "Disable_Transparency.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'DisableAnimations' {
                            Write-ToConsole "Disabling animations and visual effects..."
                            RegImport "" "Disable_Animations.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'TaskbarAlignLeft' {
                            Write-ToConsole "Aligning taskbar buttons to the left..."
                            RegImport "" "Align_Taskbar_Left.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'CombineTaskbarAlways' {
                            Write-ToConsole "Setting taskbar to always combine buttons..."
                            RegImport "" "Combine_Taskbar_Always.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'CombineTaskbarWhenFull' {
                            Write-ToConsole "Setting taskbar to combine when full..."
                            RegImport "" "Combine_Taskbar_When_Full.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'CombineTaskbarNever' {
                            Write-ToConsole "Setting taskbar to never combine buttons..."
                            RegImport "" "Combine_Taskbar_Never.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'CombineMMTaskbarAlways' {
                            Write-ToConsole "Setting secondary taskbars to always combine buttons..."
                            RegImport "" "Combine_MMTaskbar_Always.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'CombineMMTaskbarWhenFull' {
                            Write-ToConsole "Setting secondary taskbars to combine when full..."
                            RegImport "" "Combine_MMTaskbar_When_Full.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'CombineMMTaskbarNever' {
                            Write-ToConsole "Setting secondary taskbars to never combine buttons..."
                            RegImport "" "Combine_MMTaskbar_Never.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'MMTaskbarModeAll' {
                            Write-ToConsole "Setting taskbar to show app icons on all taskbars..."
                            RegImport "" "MMTaskbarMode_All.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'MMTaskbarModeMainActive' {
                            Write-ToConsole "Setting taskbar to show on main and active..."
                            RegImport "" "MMTaskbarMode_Main_Active.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'MMTaskbarModeActive' {
                            Write-ToConsole "Setting taskbar to only show on active..."
                            RegImport "" "MMTaskbarMode_Active.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'HideSearchTb' {
                            Write-ToConsole "Hiding search icon from taskbar..."
                            RegImport "" "Hide_Search_Taskbar.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ShowSearchIconTb' {
                            Write-ToConsole "Showing search icon on taskbar..."
                            RegImport "" "Show_Search_Icon.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ShowSearchLabelTb' {
                            Write-ToConsole "Changing taskbar search to icon with label..."
                            RegImport "" "Show_Search_Icon_And_Label.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ShowSearchBoxTb' {
                            Write-ToConsole "Changing taskbar search to search box..."
                            RegImport "" "Show_Search_Box.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'HideTaskview' {
                            Write-ToConsole "Hiding taskview button from taskbar..."
                            RegImport "" "Hide_Taskview_Taskbar.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "HideWidgets", "DisableWidgets"} {
                            Write-ToConsole "Disabling widgets..."
                            RegImport "" "Disable_Widgets_Service.reg"
                            $appsList = 'Microsoft.StartExperiencesApp'
                            RemoveApps $appsList
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "HideChat", "DisableChat"} {
                            Write-ToConsole "Hiding chat icon from taskbar..."
                            RegImport "" "Disable_Chat_Taskbar.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'EnableEndTask' {
                            Write-ToConsole "Enabling End Task in taskbar menu..."
                            RegImport "" "Enable_End_Task.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'EnableLastActiveClick' {
                            Write-ToConsole "Enabling Last Active Click behavior..."
                            RegImport "" "Enable_Last_Active_Click.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ExplorerToHome' {
                            Write-ToConsole "Setting File Explorer to open to Home..."
                            RegImport "" "Launch_File_Explorer_To_Home.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ExplorerToThisPC' {
                            Write-ToConsole "Setting File Explorer to open to This PC..."
                            RegImport "" "Launch_File_Explorer_To_This_PC.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ExplorerToDownloads' {
                            Write-ToConsole "Setting File Explorer to open to Downloads..."
                            RegImport "" "Launch_File_Explorer_To_Downloads.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ExplorerToOneDrive' {
                            Write-ToConsole "Setting File Explorer to open to OneDrive..."
                            RegImport "" "Launch_File_Explorer_To_OneDrive.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ShowHiddenFolders' {
                            Write-ToConsole "Unhiding hidden files and folders..."
                            RegImport "" "Show_Hidden_Folders.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'ShowKnownFileExt' {
                            Write-ToConsole "Enabling file extensions for known file types..."
                            RegImport "" "Show_Extensions_For_Known_File_Types.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'AddFoldersToThisPC' {
                            Write-ToConsole "Adding common folders to This PC..."
                            RegImport "" "Add_All_Folders_Under_This_PC.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'HideHome' {
                            Write-ToConsole "Hiding Home from File Explorer..."
                            RegImport "" "Hide_Home_from_Explorer.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'HideGallery' {
                            Write-ToConsole "Hiding Gallery from File Explorer..."
                            RegImport "" "Hide_Gallery_from_Explorer.reg"
                            Write-ToConsole ""
                            continue
                        }
                        'HideDupliDrive' {
                            Write-ToConsole "Hiding duplicate removable drives..."
                            RegImport "" "Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "HideOnedrive", "DisableOnedrive"} {
                            Write-ToConsole "Hiding OneDrive folder..."
                            RegImport "" "Hide_Onedrive_Folder.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "Hide3dObjects", "Disable3dObjects"} {
                            Write-ToConsole "Hiding 3D Objects folder..."
                            RegImport "" "Hide_3D_Objects_Folder.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "HideMusic", "DisableMusic"} {
                            Write-ToConsole "Hiding Music folder..."
                            RegImport "" "Hide_Music_folder.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
                            Write-ToConsole "Hiding Include in Library from context menu..."
                            RegImport "" "Disable_Include_in_library_from_context_menu.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
                            Write-ToConsole "Hiding Give Access To from context menu..."
                            RegImport "" "Disable_Give_access_to_context_menu.reg"
                            Write-ToConsole ""
                            continue
                        }
                        {$_ -in "HideShare", "DisableShare"} {
                            Write-ToConsole "Hiding Share from context menu..."
                            RegImport "" "Disable_Share_from_context_menu.reg"
                            Write-ToConsole ""
                            continue
                        }
                        default {
                            Write-ToConsole "ERROR: No matching case for parameter: $paramKey (Type: $($paramKey.GetType().Name))"
                        }
                    }
                }
                
                Write-ToConsole ""
                Write-ToConsole "Configuration complete!"
                Write-ToConsole "All changes have been applied successfully."
                
                # Ask user if they want to restart Explorer now
                $result = [System.Windows.MessageBox]::Show(
                    'Configuration complete! Would you like to restart Windows Explorer now to apply all changes? You can also restart it later manually.',
                    'Restart Windows Explorer?',
                    [System.Windows.MessageBoxButton]::YesNo,
                    [System.Windows.MessageBoxImage]::Question
                )
                
                if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
                    Write-ToConsole "Restarting Windows Explorer..."
                    RestartExplorer
                    Write-ToConsole "Windows Explorer restarted successfully"
                }
                else {
                    Write-ToConsole "Skipped Explorer restart - you can restart it manually later"
                }
                
                $applyStatusText.Dispatcher.Invoke([action]{
                    $applyStatusText.Text = "Changes applied successfully!"
                })
                $applyProgressText.Dispatcher.Invoke([action]{
                    $applyProgressText.Text = "Completed"
                })
                $startApplyBtn.Dispatcher.Invoke([action]{
                    $startApplyBtn.Visibility = 'Collapsed'
                })
                $finishBtn.Dispatcher.Invoke([action]{
                    $finishBtn.Visibility = 'Visible'
                })
            }
            catch {
                Write-ToConsole "Error: $($_.Exception.Message)"
                $applyStatusText.Dispatcher.Invoke([action]{
                    $applyStatusText.Text = "An error occurred"
                })
                $startApplyBtn.Dispatcher.Invoke([action]{
                    $startApplyBtn.IsEnabled = $true
                })
            }
        })
    })
    
    # Finish button handler
    $finishBtn.Add_Click({
        $window.Close()
    })

    # Show the window
    return $window.ShowDialog()
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
            $result = ShowAppSelectionWindow

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

    $result = ShowAppSelectionWindow

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



# Check if winget is installed & if it is, check if the version is at least v1.4
if ((Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*") -and ([int](((winget -v) -replace 'v','').split('.')[0..1] -join '') -gt 14)) {
    $script:WingetInstalled = $true
}
else {
    $script:WingetInstalled = $false

    # Show warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
    if (-not $Silent) {
        Write-Warning "Winget is not installed or outdated, this may prevent Win11Debloat from removing certain apps"
        Write-Output ""
        Write-Output "Press any key to continue anyway..."
        $null = [System.Console]::ReadKey()
    }
}

# Get current Windows build version to compare against features
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

    $result = ShowAppSelectionWindow

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
            $result = ShowScriptUI
            Exit
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

# Create a system restore point if the CreateRestorePoint parameter was passed
if ($script:Params.ContainsKey("CreateRestorePoint")) {
    CreateSystemRestorePoint
}

# Execute all selected/provided parameters
switch ($script:Params.Keys) {
    'RemoveApps' {
        Write-Output "> Removing selected apps..."
        $appsList = GenerateAppsList

        if ($appsList.Count -eq 0) {
            Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        Write-Output "$($appsList.Count) apps selected for removal"
        RemoveApps $appsList
        continue
    }
    'RemoveAppsCustom' {
        Write-Output "> Removing selected apps..."
        $appsList = ReadAppslistFromFile $script:CustomAppsListFilePath

        if ($appsList.Count -eq 0) {
            Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        Write-Output "$($appsList.Count) apps selected for removal"
        RemoveApps $appsList
        continue
    }
    'RemoveCommApps' {
        $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
        Write-Output "> Removing Mail, Calendar and People apps..."
        RemoveApps $appsList
        continue
    }
    'RemoveW11Outlook' {
        $appsList = 'Microsoft.OutlookForWindows'
        Write-Output "> Removing new Outlook for Windows app..."
        RemoveApps $appsList
        continue
    }
    'RemoveGamingApps' {
        $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
        Write-Output "> Removing gaming related apps..."
        RemoveApps $appsList
        continue
    }
    'RemoveHPApps' {
        $appsList = 'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl'
        Write-Output "> Removing HP apps..."
        RemoveApps $appsList
        continue
    }
    "ForceRemoveEdge" {
        ForceRemoveEdge
        continue
    }
    'DisableDVR' {
        RegImport "> Disabling Xbox game/screen recording..." "Disable_DVR.reg"
        continue
    }
    'DisableGameBarIntegration' {
        RegImport "> Disabling Game Bar integration..." "Disable_Game_Bar_Integration.reg"
        continue
    }
    'DisableTelemetry' {
        RegImport "> Disabling telemetry, diagnostic data, activity history, app-launch tracking and targeted ads..." "Disable_Telemetry.reg"
        continue
    }
    {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
        RegImport "> Disabling tips, tricks, suggestions and ads across Windows..." "Disable_Windows_Suggestions.reg"
        continue
    }
    'DisableEdgeAds' {
        RegImport "> Disabling ads, suggestions and the MSN news feed in Microsoft Edge..." "Disable_Edge_Ads_And_Suggestions.reg"
        continue
    }
    {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
        RegImport "> Disabling tips & tricks on the lockscreen..." "Disable_Lockscreen_Tips.reg"
        continue
    }
    'DisableDesktopSpotlight' {
        RegImport "> Disabling the 'Windows Spotlight' desktop background option..." "Disable_Desktop_Spotlight.reg"
        continue
    }
    'DisableSettings365Ads' {
        RegImport "> Disabling Microsoft 365 ads in Settings Home..." "Disable_Settings_365_Ads.reg"
        continue
    }
    'DisableSettingsHome' {
        RegImport "> Disabling the Settings Home page..." "Disable_Settings_Home.reg"
        continue
    }
    {$_ -in "DisableBingSearches", "DisableBing"} {
        RegImport "> Disabling Bing web search, Bing AI and Cortana from Windows search..." "Disable_Bing_Cortana_In_Search.reg"

        # Also remove the app package for Bing search
        $appsList = 'Microsoft.BingSearch'
        RemoveApps $appsList
        continue
    }
    'DisableCopilot' {
        RegImport "> Disabling Microsoft Copilot..." "Disable_Copilot.reg"

        # Also remove the app package for Copilot
        $appsList = 'Microsoft.Copilot'
        RemoveApps $appsList
        continue
    }
    'DisableRecall' {
        if ($WinVersion -lt 22000) {
            Write-Output "> Disabling Windows Recall..."
            Write-Host "Feature is not available on Windows 10" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        RegImport "> Disabling Windows Recall..." "Disable_AI_Recall.reg"
        continue
    }
    'DisableClickToDo' {
        if ($WinVersion -lt 22000) {
            Write-Output "> Disabling Click to Do..."
            Write-Host "Feature is not available on Windows 10" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        RegImport "> Disabling Click to Do..." "Disable_Click_to_Do.reg"
        continue
    }
    'DisableEdgeAI' {
        RegImport "> Disabling AI features in Microsoft Edge..." "Disable_Edge_AI_Features.reg"
        continue
    }
    'DisablePaintAI' {
        RegImport "> Disabling AI features in Paint..." "Disable_Paint_AI_Features.reg"
        continue
    }
    'DisableNotepadAI' {
        RegImport "> Disabling AI features in Notepad..." "Disable_Notepad_AI_Features.reg"
        continue
    }
    'RevertContextMenu' {
        RegImport "> Restoring the old Windows 10 style context menu..." "Disable_Show_More_Options_Context_Menu.reg"
        continue
    }
    'DisableMouseAcceleration' {
        RegImport "> Turning off Enhanced Pointer Precision..." "Disable_Enhance_Pointer_Precision.reg"
        continue
    }
    'DisableStickyKeys' {
        RegImport "> Disabling the Sticky Keys keyboard shortcut..." "Disable_Sticky_Keys_Shortcut.reg"
        continue
    }
    'DisableFastStartup' {
        RegImport "> Disabling Fast Start-up..." "Disable_Fast_Startup.reg"
        continue
    }
    'DisableModernStandbyNetworking' {
        if (-not $script:ModernStandbySupported) {
            Write-Output "> Disabling network connectivity during Modern Standby..."
            Write-Host "Device does not support modern standby" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        RegImport "> Disabling network connectivity during Modern Standby..." "Disable_Modern_Standby_Networking.reg"
        continue
    }
    'ClearStart' {
        Write-Output "> Removing all pinned apps from the start menu for user $(GetUserName)..."
        ReplaceStartMenu
        Write-Output ""
        continue
    }
    'ReplaceStart' {
        Write-Output "> Replacing the start menu for user $(GetUserName)..."
        ReplaceStartMenu $script:Params.Item("ReplaceStart")
        Write-Output ""
        continue
    }
    'ClearStartAllUsers' {
        ReplaceStartMenuForAllUsers
        continue
    }
    'ReplaceStartAllUsers' {
        ReplaceStartMenuForAllUsers $script:Params.Item("ReplaceStartAllUsers")
        continue
    }
    'DisableStartRecommended' {
        RegImport "> Disabling the start menu recommended section..." "Disable_Start_Recommended.reg"
        continue
    }
    'DisableStartPhoneLink' {
        RegImport "> Disabling the Phone Link mobile devices integration in the start menu..." "Disable_Phone_Link_In_Start.reg"
        continue
    }
    'EnableDarkMode' {
        RegImport "> Enabling dark mode for system and apps..." "Enable_Dark_Mode.reg"
        continue
    }
    'DisableTransparency' {
        RegImport "> Disabling transparency effects..." "Disable_Transparency.reg"
        continue
    }
    'DisableAnimations' {
        RegImport "> Disabling animations and visual effects..." "Disable_Animations.reg"
        continue
    }
    'TaskbarAlignLeft' {
        RegImport "> Aligning taskbar buttons to the left..." "Align_Taskbar_Left.reg"
        continue
    }
    'CombineTaskbarAlways' {
        RegImport "> Setting the taskbar on the main display to always combine buttons and hide labels..." "Combine_Taskbar_Always.reg"
        continue
    }
    'CombineTaskbarWhenFull' {
        RegImport "> Setting the taskbar on the main display to only combine buttons and hide labels when the taskbar is full..." "Combine_Taskbar_When_Full.reg"
        continue
    }
    'CombineTaskbarNever' {
        RegImport "> Setting the taskbar on the main display to never combine buttons or hide labels..." "Combine_Taskbar_Never.reg"
        continue
    }
    'CombineMMTaskbarAlways' {
        RegImport "> Setting the taskbar on secondary displays to always combine buttons and hide labels..." "Combine_MMTaskbar_Always.reg"
        continue
    }
    'CombineMMTaskbarWhenFull' {
        RegImport "> Setting the taskbar on secondary displays to only combine buttons and hide labels when the taskbar is full..." "Combine_MMTaskbar_When_Full.reg"
        continue
    }
    'CombineMMTaskbarNever' {
        RegImport "> Setting the taskbar on secondary displays to never combine buttons or hide labels..." "Combine_MMTaskbar_Never.reg"
        continue
    }
    'MMTaskbarModeAll' {
        RegImport "> Setting the taskbar to only show app icons on main taskbar..." "MMTaskbarMode_All.reg"
        continue
    }
    'MMTaskbarModeMainActive' {
        RegImport "> Setting the taskbar to show app icons on all taskbars..." "MMTaskbarMode_Main_Active.reg"
        continue
    }
    'MMTaskbarModeActive' {
        RegImport "> Setting the taskbar to only show app icons on the taskbar where the window is open..." "MMTaskbarMode_Active.reg"
        continue
    }
    'HideSearchTb' {
        RegImport "> Hiding the search icon from the taskbar..." "Hide_Search_Taskbar.reg"
        continue
    }
    'ShowSearchIconTb' {
        RegImport "> Changing taskbar search to icon only..." "Show_Search_Icon.reg"
        continue
    }
    'ShowSearchLabelTb' {
        RegImport "> Changing taskbar search to icon with label..." "Show_Search_Icon_And_Label.reg"
        continue
    }
    'ShowSearchBoxTb' {
        RegImport "> Changing taskbar search to search box..." "Show_Search_Box.reg"
        continue
    }
    'HideTaskview' {
        RegImport "> Hiding the taskview button from the taskbar..." "Hide_Taskview_Taskbar.reg"
        continue
    }
    {$_ -in "HideWidgets", "DisableWidgets"} {
        RegImport "> Disabling widgets on the taskbar & lockscreen..." "Disable_Widgets_Service.reg"

        # Also remove the app package for Widgets
        $appsList = 'Microsoft.StartExperiencesApp'
        RemoveApps $appsList
        continue
    }
    {$_ -in "HideChat", "DisableChat"} {
        if ($WinVersion -ge 22000) {
            Write-Output "> Hiding the chat icon from the taskbar..."
            Write-Host "Feature is not available on Windows 11" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        RegImport "> Hiding the chat icon from the taskbar..." "Disable_Chat_Taskbar.reg"
        continue
    }
    'EnableEndTask' {
        RegImport "> Enabling the 'End Task' option in the taskbar right click menu..." "Enable_End_Task.reg"
        continue
    }
    'EnableLastActiveClick' {
        RegImport "> Enabling the 'Last Active Click' behavior in the taskbar app area..." "Enable_Last_Active_Click.reg"
        continue
    }
    'ExplorerToHome' {
        RegImport "> Changing the default location that File Explorer opens to `Home`..." "Launch_File_Explorer_To_Home.reg"
        continue
    }
    'ExplorerToThisPC' {
        RegImport "> Changing the default location that File Explorer opens to `This PC`..." "Launch_File_Explorer_To_This_PC.reg"
        continue
    }
    'ExplorerToDownloads' {
        RegImport "> Changing the default location that File Explorer opens to `Downloads`..." "Launch_File_Explorer_To_Downloads.reg"
        continue
    }
    'ExplorerToOneDrive' {
        RegImport "> Changing the default location that File Explorer opens to `OneDrive`..." "Launch_File_Explorer_To_OneDrive.reg"
        continue
    }
    'ShowHiddenFolders' {
        RegImport "> Unhiding hidden files, folders and drives..." "Show_Hidden_Folders.reg"
        continue
    }
    'ShowKnownFileExt' {
        RegImport "> Enabling file extensions for known file types..." "Show_Extensions_For_Known_File_Types.reg"
        continue
    }
    'AddFoldersToThisPC' {
        RegImport "> Adding all common folders (Desktop, Downloads, etc.) back to `This PC` in File Explorer..." "Add_All_Folders_Under_This_PC.reg"
        continue
    }
    'HideHome' {
        RegImport "> Hiding the home section from the File Explorer navigation pane..." "Hide_Home_from_Explorer.reg"
        continue
    }
    'HideGallery' {
        RegImport "> Hiding the gallery section from the File Explorer navigation pane..." "Hide_Gallery_from_Explorer.reg"
        continue
    }
    'HideDupliDrive' {
        RegImport "> Hiding duplicate removable drive entries from the File Explorer navigation pane..." "Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg"
        continue
    }
    {$_ -in "HideOnedrive", "DisableOnedrive"} {
        RegImport "> Hiding the OneDrive folder from the File Explorer navigation pane..." "Hide_Onedrive_Folder.reg"
        continue
    }
    {$_ -in "Hide3dObjects", "Disable3dObjects"} {
        if ($WinVersion -ge 22000) {
            Write-Output "> Hiding the 3D objects folder from the File Explorer navigation pane..."
            Write-Host "Feature is not available on Windows 11" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        RegImport "> Hiding the 3D objects folder from the File Explorer navigation pane..." "Hide_3D_Objects_Folder.reg"
        continue
    }
    {$_ -in "HideMusic", "DisableMusic"} {
        RegImport "> Hiding the music folder from the File Explorer navigation pane..." "Hide_Music_folder.reg"
        continue
    }
    {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
        RegImport "> Hiding 'Include in library' in the context menu..." "Disable_Include_in_library_from_context_menu.reg"
        continue
    }
    {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
        RegImport "> Hiding 'Give access to' in the context menu..." "Disable_Give_access_to_context_menu.reg"
        continue
    }
    {$_ -in "HideShare", "DisableShare"} {
        RegImport "> Hiding 'Share' in the context menu..." "Disable_Share_from_context_menu.reg"
        continue
    }
}

RestartExplorer

Write-Output ""
Write-Output ""
Write-Output ""
Write-Output "Script completed! Please check above for any errors."

AwaitKeyToExit
