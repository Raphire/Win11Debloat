param (
    [switch]$Verbose,
    [switch]$WhatIf,
    [switch]$Dev,
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
    [switch]$DisableFastStartup,
    [switch]$DisableBitlockerAutoEncryption,
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableNotifications,
    [switch]$DisableStorageSense,
    [switch]$DisableUpdateASAP,
    [switch]$PreventUpdateAutoReboot,
    [switch]$DisableDeliveryOptimization,
    [switch]$DisableDeviceAutoAppDownload,
    [switch]$DisableBing,
    [switch]$DisableStoreSearchSuggestions,
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
	[switch]$DisableChromeAI,
    [switch]$DisableWidgets,
    [switch]$HideChat,
    [switch]$EnableEndTask,
    [switch]$EnableLastActiveClick,
    [switch]$ClearStart,
    [string]$ReplaceStart,
    [switch]$ClearStartAllUsers,
    [string]$ReplaceStartAllUsers,
    [switch]$RevertContextMenu,
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

# Check if current PowerShell environment is limited by security policies
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Error "Win11Debloat is unable to run on your system, PowerShell execution is restricted by security policies"
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit 1
}

Clear-Host
Write-Output "-------------------------------------------------------------------------------------------"
Write-Output " Win11Debloat Script"
Write-Output "-------------------------------------------------------------------------------------------"

$tempRootPath = $env:TEMP

# Every run gets its own folder and archive with a random name, so the files that are run elevated are never at a path that
# is known (or can be prepared) in advance. User data lives in %LOCALAPPDATA%\Win11Debloat, not in this folder.
$runId = [guid]::NewGuid().ToString('N')
$tempWorkPath = Join-Path $tempRootPath "Win11Debloat-$runId"
$tempArchivePath = Join-Path $tempRootPath "win11debloat-$runId.zip"
$tempChecksumsPath = Join-Path $tempRootPath "win11debloat-$runId.sha256sums"

# Read the expected SHA-256 of a file from the text of a SHA256SUMS file (lines of "<64 hex digits>  <file name>", as
# written by sha256sum). Returns $null when the file is not listed.
function Get-ExpectedFileHash([string]$SumsText, [string]$FileName) {
    foreach ($line in ($SumsText -split "`r?`n")) {
        if ($line -match '^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$' -and $Matches[2] -ceq $FileName) {
            return $Matches[1].ToLowerInvariant()
        }
    }
    return $null
}

# Check a file against an expected SHA-256 value (hex digits, any case).
function Test-FileHashMatch([string]$Path, [string]$ExpectedHash) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ieq $ExpectedHash
}

# Names of the release assets the archive is verified with. When a release does not publish both, the source archive
# GitHub generates for the release is downloaded as before, without a checksum to compare it to.
$releaseArchiveName = 'Win11Debloat.zip'
$releaseChecksumsName = 'SHA256SUMS'
$expectedArchiveHash = $null

# Download Win11Debloat from GitHub as a zip archive.
try {
    if ($Dev) {
        Write-Output "> Downloading development version of Win11Debloat..."
        $sourceUri = "https://github.com/Raphire/Win11Debloat/archive/refs/heads/master.zip"
    } else {
        Write-Output "> Downloading Win11Debloat..."
        $release = Invoke-RestMethod https://api.github.com/repos/Raphire/Win11Debloat/releases/latest
        $sourceUri = $release.zipball_url

        $archiveAsset = @($release.assets | Where-Object { $_.name -ceq $releaseArchiveName }) | Select-Object -First 1
        $checksumsAsset = @($release.assets | Where-Object { $_.name -ceq $releaseChecksumsName }) | Select-Object -First 1
        if ($archiveAsset -and $checksumsAsset) {
            Invoke-RestMethod $checksumsAsset.browser_download_url -OutFile $tempChecksumsPath
            $expectedArchiveHash = Get-ExpectedFileHash ([System.IO.File]::ReadAllText($tempChecksumsPath)) $releaseArchiveName
            Remove-Item $tempChecksumsPath -Force
            if (-not $expectedArchiveHash) {
                throw "$releaseChecksumsName does not list $releaseArchiveName."
            }
            $sourceUri = $archiveAsset.browser_download_url
        }
        else {
            Write-Warning 'This release does not publish both Win11Debloat.zip and SHA256SUMS. Downloading the source archive without SHA-256 verification.'
        }
    }
    Invoke-RestMethod $sourceUri -OutFile $tempArchivePath
}
catch {
    # Do not leave the archive or checksum file of this run behind after a failed download
    Remove-Item -Path $tempArchivePath, $tempChecksumsPath -Force -ErrorAction SilentlyContinue
    Write-Host "Unable to fetch required files from GitHub. Please check your internet connection and try again." -ForegroundColor Red
    Write-Error -ErrorRecord $_
    Write-Output ""
    Write-Output "Press enter to exit..."
    Read-Host | Out-Null
    Exit 1
}

# Do not use an archive that differs from the checksum published with the release
if ($expectedArchiveHash -and -not (Test-FileHashMatch $tempArchivePath $expectedArchiveHash)) {
    Remove-Item $tempArchivePath -Force
    Write-Host "The downloaded Win11Debloat archive does not match the SHA-256 checksum published with the release." -ForegroundColor Red
    Write-Output ""
    Write-Output "Press enter to exit..."
    Read-Host | Out-Null
    Exit 1
}

Write-Output ""
Write-Output "> Unpacking..."

# Unzip archive to Win11Debloat folder
try {
    Expand-Archive $tempArchivePath $tempWorkPath -ErrorAction Stop
}
catch {
    # Do not leave the archive and a partly unpacked folder of this run behind
    Remove-Item -Path $tempArchivePath, $tempWorkPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Unable to unpack the downloaded Win11Debloat archive." -ForegroundColor Red
    Write-Error -ErrorRecord $_ -ErrorAction Continue
    Write-Output ""
    Write-Output "Press enter to exit..."
    Read-Host | Out-Null
    Exit 1
}

# Remove archive
Remove-Item $tempArchivePath

# Move files
Get-ChildItem -Path (Join-Path $tempWorkPath '*Win11Debloat-*') -Recurse | Move-Item -Destination $tempWorkPath

# Quote a value so it survives CommandLineToArgvW parsing in the child process: double any backslash run that
# precedes a quote or the closing quote, and escape embedded quotes, before wrapping the value in quotes.
function Format-LauncherArg([string]$Value) {
    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

# Build the list of arguments to pass on to the script (excludes the -Dev switch, which only affects this launcher).
# Takes the bound parameters as input so it can be tested without running the launcher.
function Get-LauncherArgumentList([System.Collections.IDictionary]$BoundParameters) {
    foreach ($entry in $BoundParameters.GetEnumerator()) {
        if ($entry.Key -eq 'Dev') { continue }

        if ($entry.Value -is [System.Management.Automation.SwitchParameter]) {
            if ($entry.Value.IsPresent) {
                "-$($entry.Key)"
            }
        }
        else {
            "-$($entry.Key) $(Format-LauncherArg ([string]$entry.Value))"
        }
    }
}

$arguments = @(Get-LauncherArgumentList $PSBoundParameters)

Write-Output ""
Write-Output "> Launching Win11Debloat..."

# Minimize the PowerShell window when no parameters are provided
if ($arguments.Count -eq 0) {
    $windowStyle = "Minimized"
}
else {
    $windowStyle = "Normal"
}

# Remove PowerShell 7 modules from path to prevent module loading issues in the script
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $NewPSModulePath = $env:PSModulePath -split ';' | Where-Object -FilterScript { $_ -like '*WindowsPowerShell*' }
    $env:PSModulePath = $NewPSModulePath -join ';'
}

# Run Win11Debloat script with the provided arguments
$debloatScriptPath = Join-Path $tempWorkPath 'Win11Debloat.ps1'
$exitCode = 0
$debloatProcess = $null
try {
    $debloatProcess = Start-Process powershell.exe -WindowStyle $windowStyle -PassThru -ArgumentList "-executionpolicy bypass -File `"$debloatScriptPath`" $arguments" -Verb RunAs -ErrorAction Stop
}
catch {
    $exitCode = 1
    Write-Error "Failed to start Win11Debloat: $_" -ErrorAction Continue
}

# Wait for the process to finish before continuing
if ($null -ne $debloatProcess) {
    $debloatProcess.WaitForExit()
    $exitCode = $debloatProcess.ExitCode
}

# Remove the folder with the script files of this run
if (Test-Path $tempWorkPath) {
    Write-Output ""
    Write-Output "> Cleaning up..."

    Remove-Item -Path $tempWorkPath -Recurse -Force
}

Write-Output ""
Exit $exitCode
