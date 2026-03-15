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
    [string]$AppRemovalTarget,
    [switch]$RemoveApps,
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveHPApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableGameBarIntegration,
    [switch]$EnableWindowsSandbox,
    [switch]$EnableWindowsSubsystemForLinux,
    [switch]$DisableTelemetry,
    [switch]$DisableSearchHistory,
    [switch]$DisableFastStartup,
    [switch]$DisableBitlockerAutoEncryption,
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableStorageSense,
    [switch]$DisableUpdateASAP,
    [switch]$PreventUpdateAutoReboot,
    [switch]$DisableDeliveryOptimization,
    [switch]$DisableBing,
    [switch]$DisableStoreSearchSuggestions,
    [switch]$DisableSearchHighlights,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscreenTips,
    [switch]$DisableSuggestions,
    [switch]$DisableLocationServices,
    [switch]$DisableFindMyDevice,
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
    [switch]$DisableStartAllApps,
    [switch]$DisableStartPhoneLink,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableClickToDo,
    [switch]$DisableAISvcAutoStart,
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
    [switch]$DisableWindowSnapping,
    [switch]$DisableSnapAssist,
    [switch]$DisableSnapLayouts,
    [switch]$HideTabsInAltTab, [switch]$Show3TabsInAltTab, [switch]$Show5TabsInAltTab, [switch]$Show20TabsInAltTab,
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
$script:Version = "2026.03.09"
$script:AppsListFilePath = "$PSScriptRoot/Config/Apps.json"
$script:DefaultSettingsFilePath = "$PSScriptRoot/Config/DefaultSettings.json"
$script:FeaturesFilePath = "$PSScriptRoot/Config/Features.json"
$script:SavedSettingsFilePath = "$PSScriptRoot/Config/LastUsedSettings.json"
$script:CustomAppsListFilePath = "$PSScriptRoot/Config/CustomAppsList"
$script:DefaultLogPath = "$PSScriptRoot/Logs/Win11Debloat.log"
$script:RegfilesPath = "$PSScriptRoot/Regfiles"
$script:AssetsPath = "$PSScriptRoot/Assets"
$script:AppSelectionSchema = "$PSScriptRoot/Schemas/AppSelectionWindow.xaml"
$script:MainWindowSchema = "$PSScriptRoot/Schemas/MainWindow.xaml"
$script:MessageBoxSchema = "$PSScriptRoot/Schemas/MessageBoxWindow.xaml"
$script:AboutWindowSchema = "$PSScriptRoot/Schemas/AboutWindow.xaml"
$script:ApplyChangesWindowSchema = "$PSScriptRoot/Schemas/ApplyChangesWindow.xaml"
$script:SharedStylesSchema = "$PSScriptRoot/Schemas/SharedStyles.xaml"
$script:BubbleHintSchema = "$PSScriptRoot/Schemas/BubbleHint.xaml"
$script:LoadAppsDetailsScriptPath = "$PSScriptRoot/Scripts/FileIO/LoadAppsDetailsFromJson.ps1"

$script:ControlParams = 'WhatIf', 'Confirm', 'Verbose', 'Debug', 'LogPath', 'Silent', 'Sysprep', 'User', 'NoRestartExplorer', 'RunDefaults', 'RunDefaultsLite', 'RunSavedSettings', 'RunAppsListGenerator', 'CLI', 'AppRemovalTarget'

# Script-level variables for GUI elements
$script:GuiWindow = $null
$script:CancelRequested = $false
$script:ApplyProgressCallback = $null
$script:ApplySubStepCallback = $null

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
if (-not ((Test-Path $script:DefaultSettingsFilePath) -and (Test-Path $script:AppsListFilePath) -and (Test-Path $script:RegfilesPath) -and (Test-Path $script:AssetsPath) -and (Test-Path $script:AppSelectionSchema) -and (Test-Path $script:ApplyChangesWindowSchema) -and (Test-Path $script:SharedStylesSchema) -and (Test-Path $script:BubbleHintSchema) -and (Test-Path $script:FeaturesFilePath))) {
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
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $script:WingetInstalled = $true
    }
    else {
        $script:WingetInstalled = $false
    }
}
catch {
    Write-Error "Unable to determine if WinGet is installed, winget command failed: $_"
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
#                                                FUNCTION IMPORTS                                                #
#                                                                                                                #
##################################################################################################################

# App removal functions
. "$PSScriptRoot/Scripts/AppRemoval/ForceRemoveEdge.ps1"
. "$PSScriptRoot/Scripts/AppRemoval/RemoveApps.ps1"
. "$PSScriptRoot/Scripts/AppRemoval/GetInstalledAppsViaWinget.ps1"

# CLI functions
. "$PSScriptRoot/Scripts/CLI/AwaitKeyToExit.ps1"
. "$PSScriptRoot/Scripts/CLI/ShowCLILastUsedSettings.ps1"  
. "$PSScriptRoot/Scripts/CLI/ShowCLIDefaultModeAppRemovalOptions.ps1"
. "$PSScriptRoot/Scripts/CLI/ShowCLIDefaultModeOptions.ps1"
. "$PSScriptRoot/Scripts/CLI/ShowCLIAppRemoval.ps1"
. "$PSScriptRoot/Scripts/CLI/ShowCLIMenuOptions.ps1"
. "$PSScriptRoot/Scripts/CLI/PrintPendingChanges.ps1"
. "$PSScriptRoot/Scripts/CLI/PrintHeader.ps1"

# Features functions
. "$PSScriptRoot/Scripts/Features/ExecuteChanges.ps1"
. "$PSScriptRoot/Scripts/Features/CreateSystemRestorePoint.ps1"
. "$PSScriptRoot/Scripts/Features/DisableStoreSearchSuggestions.ps1"
. "$PSScriptRoot/Scripts/Features/EnableWindowsFeature.ps1"
. "$PSScriptRoot/Scripts/Features/ImportRegistryFile.ps1"
. "$PSScriptRoot/Scripts/Features/ReplaceStartMenu.ps1"
. "$PSScriptRoot/Scripts/Features/RestartExplorer.ps1"

# File I/O functions
. "$PSScriptRoot/Scripts/FileIO/LoadJsonFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/SaveSettings.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadSettings.ps1"
. "$PSScriptRoot/Scripts/FileIO/SaveCustomAppsListToFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/ValidateAppslist.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadAppsFromFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadAppsDetailsFromJson.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadAppPresetsFromJson.ps1"

# GUI functions
. "$PSScriptRoot/Scripts/GUI/GetSystemUsesDarkMode.ps1"
. "$PSScriptRoot/Scripts/GUI/SetWindowThemeResources.ps1"
. "$PSScriptRoot/Scripts/GUI/AttachShiftClickBehavior.ps1"
. "$PSScriptRoot/Scripts/GUI/ApplySettingsToUiControls.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-MessageBox.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-ApplyModal.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-AppSelectionWindow.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-MainWindow.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-AboutDialog.ps1"

# Load File I/O functions
. "$PSScriptRoot/Scripts/FileIO/LoadJsonFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/SaveSettings.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadSettings.ps1"
. "$PSScriptRoot/Scripts/FileIO/SaveCustomAppsListToFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/ValidateAppslist.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadAppsFromFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadAppsDetailsFromJson.ps1"

# Processes all pending WPF window messages (input, render, etc.) to keep the UI responsive
# during long-running operations on the UI thread. Equivalent to Application.DoEvents().
function DoEvents {
    if (-not $script:GuiWindow) { return }
    $frame = [System.Windows.Threading.DispatcherFrame]::new()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [System.Windows.Threading.DispatcherOperationCallback]{
            param($f)
            $f.Continue = $false
            return $null
        },
        $frame
    )
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}


# Runs a scriptblock in a background PowerShell runspace while keeping the UI responsive.
# In GUI mode, the work executes on a separate thread and the UI thread pumps messages (~60fps).
# In CLI mode, the scriptblock runs directly in the current session.
function Invoke-NonBlocking {
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @()
    )

    if (-not $script:GuiWindow) {
        return (& $ScriptBlock @ArgumentList)
    }

    $ps = [powershell]::Create()
    try {
        $null = $ps.AddScript($ScriptBlock.ToString())
        foreach ($arg in $ArgumentList) {
            $null = $ps.AddArgument($arg)
        }

        $handle = $ps.BeginInvoke()

        while (-not $handle.IsCompleted) {
            DoEvents
            Start-Sleep -Milliseconds 16
        }

        $result = $ps.EndInvoke($handle)

        if ($result.Count -eq 0) { return $null }
        if ($result.Count -eq 1) { return $result[0] }
        return @($result)
    }
    finally {
        $ps.Dispose()
    }
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


function GetUserName {
    if ($script:Params.ContainsKey("User")) {
        return $script:Params.Item("User")
    }

    return $env:USERNAME
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


# Target is determined from $script:Params["AppRemovalTarget"] or defaults to "AllUsers"
# Target values: "AllUsers" (removes for all users + from image), "CurrentUser", or a specific username
function GetTargetUserForAppRemoval {
    if ($script:Params.ContainsKey("AppRemovalTarget")) {
        return $script:Params["AppRemovalTarget"]
    }
    
    return "AllUsers"
}


function GetFriendlyTargetUserName {
    $target = GetTargetUserForAppRemoval

    switch ($target) {
        "AllUsers" { return "all users" }
        "CurrentUser" { return "the current user" }
        default { return "user $target" }
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


# Generates a list of apps to remove based on the Apps parameter
function GenerateAppsList {
    if (-not ($script:Params["Apps"] -and $script:Params["Apps"] -is [string])) {
        return @()
    }

    $appMode = $script:Params["Apps"].toLower()

    switch ($appMode) {
        'default' {
            $appsList = LoadAppsFromFile $script:AppsListFilePath
            return $appsList
        }
        default {
            $appsList = $script:Params["Apps"].Split(',') | ForEach-Object { $_.Trim() }
            $validatedAppsList = ValidateAppslist $appsList
            return $validatedAppsList
        }
    }
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
                # Also remove the app package for Widgets
                RemoveApps 'Microsoft.StartExperiencesApp'
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
# Parameters:
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

# Ensure that target user exists, if User or AppRemovalTarget parameter was provided
if ($script:Params.ContainsKey("User")) {
    $userPath = GetUserDirectory -userName $script:Params.Item("User")
}
if ($script:Params.ContainsKey("AppRemovalTarget")) {
    $userPath = GetUserDirectory -userName $script:Params.Item("AppRemovalTarget")
}

# Remove LastUsedSettings.json file if it exists and is empty
if ((Test-Path $script:SavedSettingsFilePath) -and ([String]::IsNullOrWhiteSpace((Get-content $script:SavedSettingsFilePath)))) {
    Remove-Item -Path $script:SavedSettingsFilePath -recurse
}

# Only run the app selection form if the 'RunAppsListGenerator' parameter was passed to the script
if ($RunAppsListGenerator) {
    PrintHeader "Custom Apps List Generator"

    $result = Show-AppSelectionWindow

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
        ShowCLIDefaultModeOptions
    }
    elseif ($RunSavedSettings) {
        if (-not (Test-Path $script:SavedSettingsFilePath)) {
            PrintHeader 'Custom Mode'
            Write-Error "Unable to find LastUsedSettings.json file, no changes were made"
            AwaitKeyToExit
        }

        ShowCLILastUsedSettings
    }
    else {
        if ($CLI) {
            $Mode = ShowCLIMenuOptions 
        }
        else {
            try {
                $result = Show-MainWindow
            
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

                $Mode = ShowCLIMenuOptions
            }
        }
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults and app removal options
        '1' { 
            ShowCLIDefaultModeOptions
        }

        # App removal, remove apps based on user selection
        '2' {
            ShowCLIAppRemoval
        }

        # Load last used options from the "LastUsedSettings.json" file
        '3' {
            ShowCLILastUsedSettings
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
