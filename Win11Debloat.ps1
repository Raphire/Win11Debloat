[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$CLI,
    [switch]$Silent,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$Language,
    [string]$User,
    [Alias('NoRestartExplorer')]
    [switch]$SkipExplorerRestart,
    [switch]$CreateRestorePoint,
    [switch]$SkipRegistryBackup,
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
    [switch]$DisableDeviceAutoAppDownload,
    [switch]$DisableBing,
    [switch]$DisableNotifications,
    [switch]$DisableStoreSearchSuggestions,
    [switch]$DisableSearchHighlights,
    [switch]$DisableDesktopSpotlight,
    [switch]$HideDesktopSpotlightIcon,
    [switch]$EnableDesktopSpotlight,
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

# Win11Debloat depends on Windows PowerShell 5.1 cmdlets (the Appx module's Get-AppxPackage /
# Remove-AppxPackage, and Get-ComputerRestorePoint) that do not load in PowerShell 7 (pwsh), where the
# Appx module fails with "Operation is not supported on this platform" (0x80131539). Without this guard
# the run continues and silently fails to remove any apps while still reporting success. See issue #675.
if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Host "Win11Debloat 需要 Windows PowerShell 5.1，当前使用的是 PowerShell $($PSVersionTable.PSVersion)（pwsh／Core 版）。" -ForegroundColor Red
    Write-Host "应用卸载和系统还原点功能依赖 PowerShell 7 中不可用的模块，因此无法在当前环境中正常运行。" -ForegroundColor Red
    Write-Host "请使用 Windows PowerShell（powershell.exe）重新运行此脚本。" -ForegroundColor Yellow
    exit 1
}

# Check if script is running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# If script is not running as administrator ask user if they want to allow it
if (-not $isAdmin) {
    Write-Host "Win11Debloat 必须以管理员身份运行。" -ForegroundColor Red

    $choice = Read-Host "是否以管理员身份重新启动？（输入 y 确认，n 取消）"

    if ($choice -match '^[Yy]$') {
        # Win32-safe escaping for arguments to pass to elevated process
        function Format-ElevatedArg([string]$Value) {
            $escaped = $Value -replace '(\\*)"', '$1$1\"'
            $escaped = $escaped -replace '(\\+)$', '$1$1'
            return '"' + $escaped + '"'
        }

        $elevatedArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Format-ElevatedArg $PSCommandPath))

        foreach ($paramName in $PSBoundParameters.Keys) {
            $paramValue = $PSBoundParameters[$paramName]

            if ($paramValue -is [System.Management.Automation.SwitchParameter]) {
                if ($paramValue.IsPresent) {
                    $elevatedArgs += "-$paramName"
                }
            }
            else {
                $elevatedArgs += "-$paramName"
                $elevatedArgs += (Format-ElevatedArg $paramValue)
            }
        }

        if ($MyInvocation.UnboundArguments.Count -gt 0) {
            foreach ($unboundArg in $MyInvocation.UnboundArguments) {
                $elevatedArgs += (Format-ElevatedArg "$unboundArg")
            }
        }

        try {
            Start-Process powershell -ArgumentList $elevatedArgs -Verb RunAs -ErrorAction Stop
        }
        catch {
            Write-Error "无法以管理员身份启动 Win11Debloat：$_"
            Exit 1
        }

        Exit 0
    }

    Exit 1
}

# Define script-level variables & paths
$script:Version = "2026.08.24"
$configPath = Join-Path $PSScriptRoot 'Config'
$logsPath = Join-Path $PSScriptRoot 'Logs'
$schemasPath = Join-Path $PSScriptRoot 'Schemas'
$scriptsPath = Join-Path $PSScriptRoot 'Scripts'

$script:AppsListFilePath = Join-Path $configPath 'Apps.json'
$script:DefaultSettingsFilePath = Join-Path $configPath 'DefaultSettings.json'
$script:FeaturesFilePath = Join-Path $configPath 'Features.json'
$script:SavedSettingsFilePath = Join-Path $configPath 'LastUsedSettings.json'
$script:LanguagesPath = Join-Path $configPath 'Languages'
$script:DefaultLanguagePath = Join-Path $script:LanguagesPath 'en-US'
$script:DefaultLogPath = Join-Path $logsPath 'Win11Debloat.log'
$script:RegfilesPath = Join-Path $PSScriptRoot 'Regfiles'
$script:RegistryBackupsPath = Join-Path $PSScriptRoot 'Backups'
$script:AssetsPath = Join-Path $PSScriptRoot 'Assets'
$script:AppSelectionSchema = Join-Path $schemasPath 'AppSelectionWindow.xaml'
$script:MainWindowSchema = Join-Path $schemasPath 'MainWindow.xaml'
$script:MessageBoxSchema = Join-Path $schemasPath 'MessageBox.xaml'
$script:AboutWindowSchema = Join-Path $schemasPath 'AboutWindow.xaml'
$script:ApplyChangesWindowSchema = Join-Path $schemasPath 'ApplyChangesWindow.xaml'
$script:SharedStylesSchema = Join-Path $schemasPath 'SharedStyles.xaml'
$script:BubbleHintSchema = Join-Path $schemasPath 'BubbleHint.xaml'
$script:ImportExportConfigSchema = Join-Path $schemasPath 'ImportExportConfigWindow.xaml'
$script:RestoreBackupWindowSchema = Join-Path $schemasPath 'RestoreBackupWindow.xaml'
$script:LoadAppsDetailsScriptPath = Join-Path (Join-Path $scriptsPath 'FileIO') 'Import-AppDetailsFromJson.ps1'
$script:TestAppInWingetListScriptPath = Join-Path (Join-Path $scriptsPath 'AppRemoval') 'Test-AppInWingetList.ps1'
$script:ImportLanguageFileScriptPath = Join-Path (Join-Path $scriptsPath 'FileIO') 'Import-LanguageFile.ps1'

$script:ControlParams = 'WhatIf', 'Confirm', 'Verbose', 'Debug', 'LogPath', 'Language', 'Silent', 'Sysprep', 'User', 'SkipExplorerRestart', 'SkipRegistryBackup', 'RunDefaults', 'RunDefaultsLite', 'RunSavedSettings', 'Config', 'CLI', 'AppRemovalTarget'

# Script-level variables for GUI elements
$script:GuiWindow = $null
$script:CancelRequested = $false
$script:ApplyProgressCallback = $null
$script:ApplySubStepCallback = $null
$script:RegistryImportFailures = 0
$script:AppRemovalFailures = 0
$script:AppRemovalVerificationUnavailable = $false

# Check if current PowerShell environment is limited by security policies
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Error "安全策略限制了 PowerShell 的执行，Win11Debloat 无法在此系统上运行。"
    Write-Output "按任意键退出……"
    $null = [System.Console]::ReadKey()
    Exit 1
}

Clear-Host

# Ensure required Windows command paths are present in PATH for this session.
$system32Path = "$env:SystemRoot\System32"
if ($env:PATH -notmatch "(?i)(^|;)$([regex]::Escape($system32Path))(?=;|$)") {
    $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot;" + $env:PATH
    Write-Warning "PATH 环境变量中缺少 System32 路径，已为本次运行补上。"
}

# Display ASCII art launch logo in CLI
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
Write-Host "                   " -NoNewline; Write-Host "    (" -ForegroundColor Yellow -NoNewline; Write-Host "'''" -ForegroundColor Red -NoNewline; Write-Host ") " -ForegroundColor Yellow -NoNewline; Write-Host "   *  *" -ForegroundColor DarkYellow
Write-Host "                   " -NoNewline; Write-Host "    ( " -ForegroundColor DarkYellow -NoNewline; Write-Host "'" -ForegroundColor Red -NoNewline; Write-Host " )   " -ForegroundColor DarkYellow -NoNewline; Write-Host "*" -ForegroundColor Yellow
Write-Host ""
Write-Host "             正在启动 Win11Debloat……" -ForegroundColor White
Write-Host "                请保持此窗口打开" -ForegroundColor DarkGray
Write-Host ""
Write-Host ""

# Log script output to 'Win11Debloat.log' at the specified path
if ($LogPath -and (Test-Path $LogPath)) {
    Start-Transcript -Path (Join-Path $LogPath 'Win11Debloat.log') -Append -IncludeInvocationHeader -Force | Out-Null
}
else {
    Start-Transcript -Path $script:DefaultLogPath -Append -IncludeInvocationHeader -Force | Out-Null
}

# When Group Policy overrides Run.bat's Process-scope Bypass, marked PowerShell source files
# can prompt as they are dot-sourced. Outside -WhatIf, remove Mark-of-the-Web only from marked
# .ps1, .psm1, and .psd1 files under Scripts; leave all other downloaded files untouched.
# See issue #720.
if (-not $WhatIfPreference) {
    $gpoExecutionPolicySet = (Get-ExecutionPolicy -Scope MachinePolicy) -ne 'Undefined' -or
        (Get-ExecutionPolicy -Scope UserPolicy) -ne 'Undefined'

    if ($gpoExecutionPolicySet) {
        $markedScriptFiles = @(Get-ChildItem -LiteralPath $scriptsPath -Recurse -File |
            Where-Object { $_.Extension -in '.ps1', '.psm1', '.psd1' } |
            Where-Object {
                Get-Item -LiteralPath $_.FullName -Stream * -ErrorAction SilentlyContinue |
                    Where-Object { $_.Stream -eq 'Zone.Identifier' }
            })

        if ($markedScriptFiles.Count -gt 0) {
            Write-Host "正在解除 $($markedScriptFiles.Count) 个 PowerShell 文件的下载锁定……"
            $unblockErrors = @()
            $markedScriptFiles | Unblock-File -ErrorAction SilentlyContinue -ErrorVariable +unblockErrors

            if ($unblockErrors.Count -gt 0) {
                Write-Warning "有 $($unblockErrors.Count) 个 PowerShell 文件未能解除下载锁定。"
            }
            else {
                Write-Host "已成功解除所有文件的下载锁定。"
            }
        }
    }
}

# Check if the device is domain-joined and warn the user (Group Policy may override changes)
try {
    $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($null -ne $computerSystem -and $computerSystem.PartOfDomain) {
        Write-Warning "此电脑已加入域，组策略可能会覆盖 Win11Debloat 所做的更改。"
    }
}
catch { }

# Check if script has all required files
if (-not ((Test-Path $script:DefaultSettingsFilePath) -and (Test-Path $script:AppsListFilePath) -and (Test-Path $script:RegfilesPath) -and (Test-Path $script:AssetsPath) -and (Test-Path $script:AppSelectionSchema) -and (Test-Path $script:ApplyChangesWindowSchema) -and (Test-Path $script:SharedStylesSchema) -and (Test-Path $script:BubbleHintSchema) -and (Test-Path $script:RestoreBackupWindowSchema) -and (Test-Path $script:FeaturesFilePath) -and (Test-Path $script:DefaultLanguagePath))) {
    Write-Error "Win11Debloat 未找到所需文件，请确认程序文件完整。"
    Write-Output "按任意键退出……"
    $null = [System.Console]::ReadKey()
    Exit 1
}

# Load feature info from file
$script:Features = @{}
try {
    $featuresData = Get-Content -Path $script:FeaturesFilePath -Raw | ConvertFrom-Json
    foreach ($feature in $featuresData.Features) {
        if ([string]::IsNullOrWhiteSpace([string]$feature.FeatureId) -or [string]::IsNullOrWhiteSpace([string]$feature.Label) -or [string]::IsNullOrWhiteSpace([string]$feature.ApplyText)) {
            Write-Warning "Features.json 中的功能 '$($feature.FeatureId)' 缺少 FeatureId、Label 或 ApplyText，将跳过该功能。"
            continue
        }
        $script:Features[$feature.FeatureId] = $feature
    }
}
catch {
    Write-Error "无法从 Features.json 文件加载功能信息。"
    Write-Output "按任意键退出……"
    $null = [System.Console]::ReadKey()
    Exit 1
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
    Write-Error "无法判断 WinGet 是否已安装，winget 命令执行失败：$_"
    $script:WingetInstalled = $false
}

# Show WinGet warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
if (-not $script:WingetInstalled -and -not $Silent) {
    Write-Warning "WinGet 未安装或版本过旧，这可能导致 Win11Debloat 无法移除部分应用。"
    Write-Output ""
    Write-Output "按任意键仍然继续……"
    $null = [System.Console]::ReadKey()
}



##################################################################################################################
#                                                                                                                #
#                                                FUNCTION IMPORTS                                                #
#                                                                                                                #
##################################################################################################################

# App removal functions
. "$PSScriptRoot/Scripts/AppRemoval/Invoke-ForceRemoveEdge.ps1"
. "$PSScriptRoot/Scripts/AppRemoval/Remove-SelectedApps.ps1"
. "$PSScriptRoot/Scripts/AppRemoval/Get-WingetInstalledApps.ps1"
. "$PSScriptRoot/Scripts/AppRemoval/Test-AppInWingetList.ps1"

# CLI functions
. "$PSScriptRoot/Scripts/CLI/Wait-ForKeyPress.ps1"
. "$PSScriptRoot/Scripts/CLI/Show-CliLastUsedSettings.ps1"
. "$PSScriptRoot/Scripts/CLI/Show-CliDefaultModeAppRemovalOptions.ps1"
. "$PSScriptRoot/Scripts/CLI/Show-CliDefaultModeOptions.ps1"
. "$PSScriptRoot/Scripts/CLI/Show-CliAppRemoval.ps1"
. "$PSScriptRoot/Scripts/CLI/Show-CliMenuOptions.ps1"
. "$PSScriptRoot/Scripts/CLI/Write-PendingChanges.ps1"
. "$PSScriptRoot/Scripts/CLI/Write-CliHeader.ps1"

# Features functions
. "$PSScriptRoot/Scripts/Features/Get-CurrentTweakState.ps1"
. "$PSScriptRoot/Scripts/Features/Invoke-Changes.ps1"
. "$PSScriptRoot/Scripts/Features/Invoke-SystemRestorePoint.ps1"
. "$PSScriptRoot/Scripts/Features/Backup-RegistryFeatureSelection.ps1"
. "$PSScriptRoot/Scripts/Features/Backup-RegistrySnapshotCapture.ps1"
. "$PSScriptRoot/Scripts/Features/Backup-RegistryState.ps1"
. "$PSScriptRoot/Scripts/Features/Registry-BackupValidation.ps1"
. "$PSScriptRoot/Scripts/Features/Restore-RegistryApplyState.ps1"
. "$PSScriptRoot/Scripts/Features/Restore-RegistryBackup.ps1"
. "$PSScriptRoot/Scripts/Features/Set-StoreSearchSuggestions.ps1"
. "$PSScriptRoot/Scripts/Features/Telemetry-ScheduledTasks.ps1"
. "$PSScriptRoot/Scripts/Features/Windows-OptionalFeatures.ps1"
. "$PSScriptRoot/Scripts/Features/Import-RegistryFile.ps1"
. "$PSScriptRoot/Scripts/Features/Replace-StartMenu.ps1"
. "$PSScriptRoot/Scripts/Features/Invoke-RestartExplorer.ps1"

# File I/O functions
. "$PSScriptRoot/Scripts/FileIO/Import-JsonFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/Import-LanguageFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/Save-ToFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/Save-Settings.ps1"
. "$PSScriptRoot/Scripts/FileIO/Import-Settings.ps1"
. "$PSScriptRoot/Scripts/FileIO/Get-ValidatedAppList.ps1"
. "$PSScriptRoot/Scripts/FileIO/Import-AppsFromFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/Import-AppDetailsFromJson.ps1"
. "$PSScriptRoot/Scripts/FileIO/Import-AppPresetsFromJson.ps1"

# GUI functions
. "$PSScriptRoot/Scripts/GUI/Get-SystemUsesDarkMode.ps1"
. "$PSScriptRoot/Scripts/GUI/Set-WindowThemeResources.ps1"
. "$PSScriptRoot/Scripts/GUI/Attach-ShiftClickBehavior.ps1"
. "$PSScriptRoot/Scripts/GUI/Apply-SettingsToUiControls.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-MessageBox.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-ImportExportConfigWindow.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-ApplyModal.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-AppSelectionWindow.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-RestoreBackupWindow.ps1"
. "$PSScriptRoot/Scripts/GUI/Restore-BackupDialogFeatureLists.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-RestoreBackupDialog.ps1"
. "$PSScriptRoot/Scripts/GUI/MainWindow-WindowChrome.ps1"
. "$PSScriptRoot/Scripts/GUI/MainWindow-AppSelection.ps1"
. "$PSScriptRoot/Scripts/GUI/MainWindow-TweaksBuilder.ps1"
. "$PSScriptRoot/Scripts/GUI/MainWindow-Navigation.ps1"
. "$PSScriptRoot/Scripts/GUI/MainWindow-Deployment.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-MainWindow.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-AboutDialog.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-Bubble.ps1"

# Helper functions
. "$PSScriptRoot/Scripts/Helpers/Add-Parameter.ps1"
. "$PSScriptRoot/Scripts/Helpers/Resolve-UserProfilePath.ps1"
. "$PSScriptRoot/Scripts/Helpers/User-HiveHelpers.ps1"
. "$PSScriptRoot/Scripts/Helpers/Test-UserProfileExists.ps1"
. "$PSScriptRoot/Scripts/Helpers/Test-ModernStandbySupport.ps1"
. "$PSScriptRoot/Scripts/Helpers/Generate-AppsList.ps1"
. "$PSScriptRoot/Scripts/Helpers/Get-FriendlyRegistryBackupTarget.ps1"
. "$PSScriptRoot/Scripts/Helpers/Get-FriendlyTargetUserName.ps1"
. "$PSScriptRoot/Scripts/Helpers/Get-RebootFeatureLabels.ps1"
. "$PSScriptRoot/Scripts/Helpers/Import-ConfigToParams.ps1"
. "$PSScriptRoot/Scripts/Helpers/Test-ConfigConsistency.ps1"
. "$PSScriptRoot/Scripts/Helpers/Get-TargetUserForAppRemoval.ps1"
. "$PSScriptRoot/Scripts/Helpers/Get-RegFileOperations.ps1"
. "$PSScriptRoot/Scripts/Helpers/Test-TargetUserName.ps1"
. "$PSScriptRoot/Scripts/Helpers/Get-UserDirectory.ps1"
. "$PSScriptRoot/Scripts/Helpers/Get-UserName.ps1"
. "$PSScriptRoot/Scripts/Helpers/Registry-PathHelpers.ps1"
. "$PSScriptRoot/Scripts/Helpers/Apply-RegistryRegFile.ps1"
. "$PSScriptRoot/Scripts/Helpers/Confirm-UnsafeAppRemoval.ps1"

# Threading functions
. "$PSScriptRoot/Scripts/Threading/Invoke-DoEvents.ps1"
. "$PSScriptRoot/Scripts/Threading/Invoke-NonBlocking.ps1"



##################################################################################################################
#                                                                                                                #
#                                                  SCRIPT START                                                  #
#                                                                                                                #
##################################################################################################################



# Get current Windows build version
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

# Check if the machine supports Modern Standby, this is used to determine if the DisableModernStandbyNetworking option can be used
$script:ModernStandbySupported = Test-ModernStandbySupport

# Load the GUI's language content. -Language overrides the current user's system UI culture,
# falling back to en-US either way if the requested language isn't available.
$script:Lang = if ($Language) { Import-LanguageFile -LanguageCode $Language } else { Import-LanguageFile }

# 命令行摘要也使用语言包中的功能名称。
foreach ($feature in $script:Features.Values) {
    $feature.Label = Get-Translation -Key $feature.FeatureId -Field 'Label' -Section 'Features'
}

$script:Params = $PSBoundParameters
$script:UndoParams = @{}

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
    Write-Host "已启用详细输出模式。"
    Write-Output ""
    Write-Output "按任意键继续……"
    $null = [System.Console]::ReadKey()

    $ProgressPreference = 'Continue'
}

if ($script:Params.ContainsKey("Sysprep")) {
    Get-UserDirectory -userName "Default" | Out-Null

    # Exit script if run in Sysprep mode on Windows 10
    if ($WinVersion -lt 22000) {
        Write-Error "Windows 10 不支持 Win11Debloat 的 Sysprep 系统部署模式。"
        Wait-ForKeyPress -ExitCode 1
    }
}

# Ensure that target user exists, if User or AppRemovalTarget parameter was provided
if ($script:Params.ContainsKey("User")) {
    Get-UserDirectory -userName $script:Params.Item("User") | Out-Null
}
if ($script:Params.ContainsKey("AppRemovalTarget")) {
    $appRemovalTargetValue = $script:Params.Item("AppRemovalTarget")
    # 'AllUsers' / 'CurrentUser' are sentinel scope values, not real usernames - don't resolve them as a profile
    if ($appRemovalTargetValue -notin @('AllUsers', 'CurrentUser')) {
        Get-UserDirectory -userName $appRemovalTargetValue | Out-Null
    }
}

# Remove LastUsedSettings.json file if it exists and is empty
if ((Test-Path $script:SavedSettingsFilePath) -and ([String]::IsNullOrWhiteSpace((Get-content $script:SavedSettingsFilePath)))) {
    Remove-Item -Path $script:SavedSettingsFilePath -Force
}

# Default to CLI mode for deployment-targeted parameters.
$launchInCLI = $CLI -or $script:Params.ContainsKey("User") -or $script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("AppRemovalTarget")

# Change script execution based on provided parameters or user input
if ((-not $script:Params.Count) -or $RunDefaults -or $RunDefaultsLite -or $RunSavedSettings -or $Config -or ($controlParamsCount -eq $script:Params.Count)) {
    if ($RunDefaults -or $RunDefaultsLite) {
        Show-CliDefaultModeOptions
    }
    elseif ($RunSavedSettings) {
        if (-not (Test-Path $script:SavedSettingsFilePath)) {
            Write-CliHeader '自定义模式'
            Write-Error "未找到 LastUsedSettings.json 文件，未进行任何更改。"
            Wait-ForKeyPress -ExitCode 1
        }

        Show-CliLastUsedSettings
    }
    elseif ($Config) {
        try {
            Import-ConfigToParams -ConfigPath $Config -CurrentBuild $WinVersion -ExpectedVersion '1.0'
        }
        catch {
            Write-Error "$_"
            Wait-ForKeyPress -ExitCode 1
        }

        if (-not $Silent) {
            Write-CliHeader '自定义模式'
            Write-PendingChanges
            Write-CliHeader '自定义模式'
        }
    }
    else {
        if ($launchInCLI) {
            $Mode = Show-CliMenuOptions
        }
        else {
            try {
                $result = Show-MainWindow
            
                try {
                    Stop-Transcript
                }
                catch { }

                Exit
            }
            catch {
                Write-Warning "图形界面无法启动：$($_.Exception.Message)"
                Write-Verbose "图形界面故障详情：$($_.Exception.ToString())"
                if (-not $Silent) {
                    Write-Host ""
                    Write-Host "按任意键继续使用命令行模式……"
                    $null = [System.Console]::ReadKey()
                }

                $Mode = Show-CliMenuOptions
            }
        }
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults and app removal options
        '1' { 
            Show-CliDefaultModeOptions
        }

        # App removal, remove apps based on user selection
        '2' {
            Show-CliAppRemoval
        }

        # Load last used options from the "LastUsedSettings.json" file
        '3' {
            Show-CliLastUsedSettings
        }
    }
}
else {
    Write-CliHeader 'Configuration'
}

# If the number of keys in ControlParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if (($controlParamsCount -eq $script:Params.Keys.Count) -or ($script:Params.Keys.Count -eq 1 -and ($script:Params.Keys -contains 'CreateRestorePoint' -or $script:Params.Keys -contains 'Apps'))) {
    Write-Output "脚本已结束，未进行任何更改。"
    Wait-ForKeyPress
}

# Execute all selected/provided parameters using the consolidated function
# (This also handles restore point creation if requested)
Invoke-AllChanges

if ($script:CancelRequested) {
    Write-Warning "用户已取消操作，其余更改均未执行。"
    Wait-ForKeyPress
}

# Restart Explorer process unless running in Sysprep or User context
if (-not ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User"))) {
    Invoke-RestartExplorer
}

Write-Output ""
Write-Output ""
Write-Output ""
Write-Output "脚本已执行完毕！请检查上方是否有错误提示。"

Wait-ForKeyPress
