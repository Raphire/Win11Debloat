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
$script:Version = "2026.03.15"
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
. "$PSScriptRoot/Scripts/GUI/Show-Bubble.ps1"

# Helper functions
. "$PSScriptRoot/Scripts/Helpers/AddParameter.ps1"
. "$PSScriptRoot/Scripts/Helpers/CheckIfUserExists.ps1"
. "$PSScriptRoot/Scripts/Helpers/CheckModernStandbySupport.ps1"
. "$PSScriptRoot/Scripts/Helpers/GenerateAppsList.ps1"
. "$PSScriptRoot/Scripts/Helpers/GetFriendlyTargetUserName.ps1"
. "$PSScriptRoot/Scripts/Helpers/GetTargetUserForAppRemoval.ps1"
. "$PSScriptRoot/Scripts/Helpers/GetUserDirectory.ps1"
. "$PSScriptRoot/Scripts/Helpers/GetUserName.ps1"

# Threading functions
. "$PSScriptRoot/Scripts/Threading/DoEvents.ps1"
. "$PSScriptRoot/Scripts/Threading/Invoke-NonBlocking.ps1"



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
