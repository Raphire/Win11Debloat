param (
    [switch]$Silent,
    [switch]$Verbose,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$User,
    [switch]$CreateRestorePoint,
    [switch]$RunAppsListGenerator, [switch]$RunAppConfigurator,
    [switch]$RunDefaults, [switch]$RunWin11Defaults,
    [switch]$RunSavedSettings,
    [switch]$RemoveApps, 
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveDevApps,
    [switch]$RemoveHPApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableTelemetry,
    [switch]$DisableFastStartup,
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableBingSearches, [switch]$DisableBing,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscrTips, [switch]$DisableLockscreenTips,
    [switch]$DisableWindowsSuggestions, [switch]$DisableSuggestions,
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
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableStartRecommended,
    [switch]$DisableStartPhoneLink,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisablePaintAI,
    [switch]$DisableNotepadAI,
    [switch]$DisableEdgeAI,
    [switch]$DisableWidgets, [switch]$HideWidgets,
    [switch]$DisableChat, [switch]$HideChat,
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
    [switch]$DisableOnedrive, [switch]$HideOnedrive,
    [switch]$Disable3dObjects, [switch]$Hide3dObjects,
    [switch]$DisableMusic, [switch]$HideMusic,
    [switch]$DisableIncludeInLibrary, [switch]$HideIncludeInLibrary,
    [switch]$DisableGiveAccessTo, [switch]$HideGiveAccessTo,
    [switch]$DisableShare, [switch]$HideShare
)

# 如果當前的 powershell 環境沒有將 LanguageMode 設定為 FullLanguage，則顯示錯誤
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
   Write-Host "错误：Win11Debloat 无法在您的系统上运行。PowerShell 执行受到安全策略的限制" -ForegroundColor Red
   Write-Output ""
   Write-Output "按 Enter 键退出..."
   Read-Host | Out-Null
   Exit
}

Clear-Host
Write-Output "-------------------------------------------------------------------------------------------"
Write-Output " Win11Debloat  Script - Get"
Write-Output "-------------------------------------------------------------------------------------------"

Write-Output "> 正在下载 Win11Debloat..."

# 從 github 下載最新版本的 Win11Debloat 為 zip 壓縮檔
Invoke-RestMethod https://api.github.com/repos/Raphire/Win11Debloat/zipball/2025.08.16 -OutFile "$env:TEMP/win11debloat.zip"

# 如果舊的腳本資料夾存在，則移除，但保留 CustomAppsList 和 SavedSettings 檔案
if (Test-Path "$env:TEMP/Win11Debloat") {
    Write-Output ""
    Write-Output "> 正在清理旧的 Win11Debloat 文件夹..."
    Get-ChildItem -Path "$env:TEMP/Win11Debloat" -Exclude CustomAppsList,SavedSettings,Win11Debloat.log | Remove-Item -Recurse -Force
}

Write-Output ""
Write-Output "> 正在解压..."

# 將壓縮檔解壓縮到 Win11Debloat 資料夾
Expand-Archive "$env:TEMP/win11debloat.zip" "$env:TEMP/Win11Debloat"

# 移除壓縮檔
Remove-Item "$env:TEMP/win11debloat.zip"

# 移動檔案
Get-ChildItem -Path "$env:TEMP/Win11Debloat/Raphire-Win11Debloat-*" -Recurse | Move-Item -Destination "$env:TEMP/Win11Debloat"

# 製作要傳遞給腳本的參數清單
$arguments = $($PSBoundParameters.GetEnumerator() | ForEach-Object {
    if ($_.Value -eq $true) {
        "-$($_.Key)"
    } 
    else {
         "-$($_.Key) ""$($_.Value)"""
    }
})

Write-Output ""
Write-Output "> 正在運行 Win11Debloat..."

# 運行 Win11Debloat 腳本，並傳遞提供的參數
$debloatProcess = Start-Process powershell.exe -PassThru -ArgumentList "-executionpolicy bypass -File $env:TEMP\Win11Debloat\Win11Debloat.ps1 $arguments" -Verb RunAs

# 等待進程完成後再繼續
if ($null -ne $debloatProcess) {
    $debloatProcess.WaitForExit()
}

# 移除所有剩餘的腳本檔案，但保留 CustomAppsList 和 SavedSettings 檔案
if (Test-Path "$env:TEMP/Win11Debloat") {
    Write-Output ""
    Write-Output "> 正在清理..."

    # 清理，移除 Win11Debloat 目錄
    Get-ChildItem -Path "$env:TEMP/Win11Debloat" -Exclude CustomAppsList,SavedSettings,Win11Debloat.log | Remove-Item -Recurse -Force
}

Write-Output ""