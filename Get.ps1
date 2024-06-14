#Requires -RunAsAdministrator

param (
    [switch]$Silent,
    [switch]$RunAppConfigurator,
    [switch]$RunDefaults, [switch]$RunWin11Defaults,
    [switch]$RemoveApps, 
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveDevApps,
    [switch]$RemoveW11Outlook,
    [switch]$DisableDVR,
    [switch]$DisableTelemetry,
    [switch]$DisableBingSearches, [switch]$DisableBing,
    [switch]$DisableLockscrTips, [switch]$DisableLockscreenTips,
    [switch]$DisableWindowsSuggestions, [switch]$DisableSuggestions,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$TaskbarAlignLeft,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableWidgets,
    [switch]$HideWidgets,
    [switch]$DisableChat,
    [switch]$HideChat,
    [switch]$ClearStart,
    [switch]$RevertContextMenu,
    [switch]$DisableOnedrive, [switch]$HideOnedrive,
    [switch]$Disable3dObjects, [switch]$Hide3dObjects,
    [switch]$DisableMusic, [switch]$HideMusic,
    [switch]$DisableIncludeInLibrary, [switch]$HideIncludeInLibrary,
    [switch]$DisableGiveAccessTo, [switch]$HideGiveAccessTo,
    [switch]$DisableShare, [switch]$HideShare
)

Clear-Host
Write-Output "-------------------------------------------------------------------------------------------"
Write-Output " Win11Debloat Script - Get"
Write-Output "-------------------------------------------------------------------------------------------"

# Navigate to user temp directory
cd $env:TEMP

Write-Output "> Downloading Win11Debloat..."

# Download latest version of Win11Debloat from github as zip archive
wget http://github.com/raphire/win11debloat/archive/master.zip -O win11debloat-temp.zip

# Unzip archive to Win11Debloat folder
Expand-Archive win11debloat-temp.zip Win11Debloat

# Remove archive
rm win11debloat-temp.zip

# Make list of arguments to pass on to the script
$args = $($PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key)"})

Write-Output ""

# Run Win11Debloat script with the provided arguments
Write-Output "> Running Win11Debloat..."
$debloatProcess = Start-Process powershell.exe -PassThru -ArgumentList "-executionpolicy bypass -File .\Win11Debloat\Win11Debloat-master\Win11Debloat.ps1 $args"
$debloatProcess.WaitForExit()

Write-Output ""

# Cleanup, remove Win11Debloat directory
Write-Output "> Cleaning up..."
Remove-Item -LiteralPath "Win11Debloat" -Force -Recurse
