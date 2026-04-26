param (
    [switch]$CLI,
    [switch]$Silent,
    [switch]$Verbose,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$User,
    [switch]$NoRestartExplorer,
    [switch]$CreateRestorePoint,
    [switch]$RunAppsListGenerator,
    [switch]$RunDefaults,
    [switch]$RunDefaultsLite,
    [switch]$RunSavedSettings,
    [string]$Config,
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
    [switch]$DisableSearchHighlights,
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
    [switch]$HideShare,
    [switch]$ShowDriveLettersFirst,
    [switch]$ShowDriveLettersLast,
    [switch]$ShowNetworkDriveLettersFirst,
    [switch]$HideDriveLetters
)

# Show error if current powershell environment does not have LanguageMode set to FullLanguage 
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
   Write-Host "Error: Win11Debloat is unable to run on your system. PowerShell execution is restricted by security policies" -ForegroundColor Red
   Write-Output ""
   Write-Output "Press enter to exit..."
   Read-Host | Out-Null
   Exit
}

Clear-Host
Write-Output "-------------------------------------------------------------------------------------------"
Write-Output " Win11Debloat Script - Get Dev"
Write-Output "-------------------------------------------------------------------------------------------"

Write-Output "> Downloading Win11Debloat for development..."

# Download latest version of Win11Debloat from GitHub master branch as zip archive
try {
    Invoke-RestMethod "https://github.com/Raphire/Win11Debloat/archive/refs/heads/master.zip" -OutFile "$env:TEMP/win11debloat.zip"
}
catch {
    Write-Host "Error: Unable to fetch master branch from GitHub. Please check your internet connection and try again." -ForegroundColor Red
    Write-Output ""
    Write-Output "Press enter to exit..."
    Read-Host | Out-Null
    Exit
}

Write-Output ""
Write-Output "> Cleaning up old Win11Debloat folder..."

# Remove old script folder if it exists, but keep config and log files
if (Test-Path "$env:TEMP/Win11Debloat") {
    Get-ChildItem -Path "$env:TEMP/Win11Debloat" -Exclude CustomAppsList,LastUsedSettings.json,Win11Debloat.log,Config,Logs | Remove-Item -Recurse -Force
}

$configDir = "$env:TEMP/Win11Debloat/Config"
$backupDir = "$env:TEMP/Win11Debloat/ConfigOld"

# Temporarily move existing config files if they exist to prevent them from being overwritten by the new script files, will be moved back after the new script is unpacked
if (Test-Path "$configDir") {
    New-Item -ItemType Directory -Path "$backupDir" -Force | Out-Null

    $filesToKeep = @(
        'CustomAppsList',
        'LastUsedSettings.json'
    )

    Get-ChildItem -Path "$configDir" -Recurse | Where-Object { $_.Name -in $filesToKeep } | Move-Item -Destination "$backupDir"

    Remove-Item "$configDir" -Recurse -Force
}

Write-Output ""
Write-Output "> Unpacking..."

# Unzip archive to Win11Debloat folder
Expand-Archive "$env:TEMP/win11debloat.zip" "$env:TEMP/Win11Debloat"

# Remove archive
Remove-Item "$env:TEMP/win11debloat.zip"

# Move files
Get-ChildItem -Path "$env:TEMP/Win11Debloat/*Win11Debloat-*" -Recurse | Move-Item -Destination "$env:TEMP/Win11Debloat"

# Add existing config files back to Config folder
if (Test-Path "$backupDir") {
    if (-not (Test-Path "$configDir")) {
        New-Item -ItemType Directory -Path "$configDir" -Force | Out-Null
    }

    Get-ChildItem -Path "$backupDir" -Recurse | Move-Item -Destination "$configDir"
    Remove-Item "$backupDir" -Recurse -Force
}

# Make list of arguments to pass on to the script
$arguments = $($PSBoundParameters.GetEnumerator() | ForEach-Object {
    if ($_.Value -eq $true) {
        "-$($_.Key)"
    } 
    else {
        "-$($_.Key) ""$($_.Value)"""
    }
})

Write-Output ""
Write-Output "> Launching Win11Debloat..."

# Minimize the powershell window when no parameters are provided
if ($arguments.Count -eq 0) {
    $windowStyle = "Minimized"
}
else {
    $windowStyle = "Normal"
}

# Remove Powershell 7 modules from path to prevent module loading issues in the script
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $NewPSModulePath = $env:PSModulePath -split ';' | Where-Object -FilterScript { $_ -like '*WindowsPowerShell*' }
    $env:PSModulePath = $NewPSModulePath -join ';'
}

# Run Win11Debloat script with the provided arguments
$debloatProcess = Start-Process powershell.exe -WindowStyle $windowStyle -PassThru -ArgumentList "-executionpolicy bypass -File $env:TEMP\Win11Debloat\Win11Debloat.ps1 $arguments" -Verb RunAs

# Wait for the process to finish before continuing
if ($null -ne $debloatProcess) {
    $debloatProcess.WaitForExit()
}

# Remove all remaining script files, except for CustomAppsList and LastUsedSettings.json files
if (Test-Path "$env:TEMP/Win11Debloat") {
    Write-Output ""
    Write-Output "> Cleaning up..."

    # Cleanup, remove Win11Debloat directory
    Get-ChildItem -Path "$env:TEMP/Win11Debloat" -Exclude CustomAppsList,LastUsedSettings.json,Win11Debloat.log,Win11Debloat-Run.log,Config,Logs | Remove-Item -Recurse -Force
}

Write-Output ""
