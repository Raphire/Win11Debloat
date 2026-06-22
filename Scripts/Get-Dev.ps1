param (
    [switch]$CLI,
    [switch]$Silent,
    [switch]$Verbose,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$User,
    [switch]$NoRestartExplorer,
    [switch]$CreateRestorePoint,
    [switch]$RunDefaults,
    [switch]$RunDefaultsLite,
    [switch]$RunSavedSettings,
    [string]$Config,
    [string]$Apps,
    [string]$AppRemovalTarget,
    [switch]$RemoveApps,
    [switch]$RemoveGamingApps,
    [switch]$RemoveHPApps,
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
    [switch]$DisableStartAllApps, [switch]$StartAllAppsCategory, [switch]$StartAllAppsGrid, [switch]$StartAllAppsList,
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

$tempRootPath = $env:TEMP
$tempWorkPath = Join-Path $tempRootPath 'Win11Debloat'
$tempArchivePath = Join-Path $tempRootPath 'win11debloat.zip'

Write-Output "> Downloading Win11Debloat for development..."

# Download latest version of Win11Debloat from GitHub master branch as zip archive
try {
    Invoke-RestMethod "https://github.com/Raphire/Win11Debloat/archive/refs/heads/master.zip" -OutFile $tempArchivePath
}
catch {
    Write-Host "Error: Unable to fetch master branch from GitHub. Please check your internet connection and try again." -ForegroundColor Red
    Write-Output ""
    Write-Output "Press enter to exit..."
    Read-Host | Out-Null
    Exit
}

# Migrate old user data from previous runs to AppData before cleanup
if (Test-Path $tempWorkPath) {
    $appDataPath = Join-Path $env:LOCALAPPDATA 'Win11Debloat'
    if (-not (Test-Path $appDataPath)) { New-Item -ItemType Directory -Path $appDataPath -Force | Out-Null }

    $oldBackupsDir = Join-Path $tempWorkPath 'Backups'
    $oldLogsDir = Join-Path $tempWorkPath 'Logs'
    $oldSettingsFile = Join-Path $tempWorkPath 'Config\LastUsedSettings.json'

    if ((Test-Path $oldBackupsDir) -and (Get-ChildItem -Path $oldBackupsDir -ErrorAction SilentlyContinue)) {
        $newBackupsDir = Join-Path $appDataPath 'Backups'
        if (-not (Test-Path $newBackupsDir)) { New-Item -ItemType Directory -Path $newBackupsDir -Force | Out-Null }
        Get-ChildItem -Path $oldBackupsDir | Move-Item -Destination $newBackupsDir -Force -ErrorAction SilentlyContinue
    }
    if ((Test-Path $oldLogsDir) -and (Get-ChildItem -Path $oldLogsDir -ErrorAction SilentlyContinue)) {
        $newLogsDir = Join-Path $appDataPath 'Logs'
        if (-not (Test-Path $newLogsDir)) { New-Item -ItemType Directory -Path $newLogsDir -Force | Out-Null }
        Get-ChildItem -Path $oldLogsDir | Move-Item -Destination $newLogsDir -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $oldSettingsFile) {
        Move-Item -Path $oldSettingsFile -Destination $appDataPath -Force -ErrorAction SilentlyContinue
    }

    Write-Output ""
    Write-Output "> Cleaning up old Win11Debloat folder..."

    Remove-Item $tempWorkPath -Recurse -Force
}

Write-Output ""
Write-Output "> Unpacking..."

# Unzip archive to Win11Debloat folder
Expand-Archive $tempArchivePath $tempWorkPath

# Remove archive
Remove-Item $tempArchivePath

# Move files
Get-ChildItem -Path (Join-Path $tempWorkPath '*Win11Debloat-*') -Recurse | Move-Item -Destination $tempWorkPath

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
$debloatScriptPath = Join-Path $tempWorkPath 'Win11Debloat.ps1'
$debloatProcess = Start-Process powershell.exe -WindowStyle $windowStyle -PassThru -ArgumentList "-executionpolicy bypass -File `"$debloatScriptPath`" $arguments" -Verb RunAs

# Wait for the process to finish before continuing
if ($null -ne $debloatProcess) {
    $debloatProcess.WaitForExit()
}

# Remove all remaining script files
if (Test-Path $tempWorkPath) {
    Write-Output ""
    Write-Output "> Cleaning up..."

    Remove-Item $tempWorkPath -Recurse -Force
}

Write-Output ""
