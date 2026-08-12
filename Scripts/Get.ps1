param (
    [switch]$Verbose,
    [switch]$WhatIf,
    [switch]$Dev,
    [switch]$CLI,
    [switch]$Silent,
    [switch]$Sysprep,
    [string]$LogPath,
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
    [switch]$DisableNotifications,
    [switch]$DisableStorageSense,
    [switch]$DisableUpdateASAP,
    [switch]$PreventUpdateAutoReboot,
    [switch]$DisableDeliveryOptimization,
    [switch]$DisableDeviceAutoAppDownload,
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
Write-Output " Win11Debloat Script"
Write-Output "-------------------------------------------------------------------------------------------"

# The archive is downloaded by the elevated bootstrap directly into an Administrators/SYSTEM-only
# staging directory, never into a location a non-elevated process can modify. A pre-elevation
# download to %TEMP% would let an attacker swap the archive before use, and hashing it in the
# non-elevated context would only fingerprint the attacker's file, so both are avoided entirely.

# Make list of arguments to pass on to the script (exclude the -Dev switch, which only affects this launcher)
$arguments = $($PSBoundParameters.GetEnumerator() | Where-Object { $_.Key -ne 'Dev' } | ForEach-Object {
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

<#
    .SYNOPSIS
        Escapes a value for safe embedding inside a single-quoted PowerShell string literal.

    .DESCRIPTION
        Doubles any embedded single quotes and wraps the result in single quotes, so the
        value is always treated as a literal string when spliced into generated script text.

    .PARAMETER Value
        The string value to escape and wrap.

    .OUTPUTS
        System.String. The single-quoted, escaped string literal.
#>
function Format-EmbeddedLiteral([string]$Value) {
    return "'" + ($Value -replace "'", "''") + "'"
}

# The bootstrap below runs elevated. It downloads, unpacks and executes the script inside a
# directory that only Administrators and SYSTEM can write to, so that the archive and the unpacked
# script files cannot be tampered with by non-elevated processes before or during elevated execution.
#
# Inputs are injected as a header of escaped single-quoted literals (built via Format-EmbeddedLiteral)
# concatenated ahead of the static body. This avoids placeholder-token substitution, where an input
# value that happened to contain a token string could be corrupted by a later replacement pass.
$bootstrapHeader = @"
`$ErrorActionPreference = 'Stop'
`$isDev = $(if ($Dev) { '$true' } else { '$false' })
`$scriptArgs = $(Format-EmbeddedLiteral ($arguments -join ' '))
`$debloatWindowStyle = $(Format-EmbeddedLiteral $windowStyle)
"@

$bootstrapBody = @'
try {
    # Serialize concurrent launcher invocations: the staging directory and the Config,
    # Logs and Backups folders inside it are shared between runs
    $bootstrapMutex = New-Object System.Threading.Mutex($false, 'Global\Win11DebloatBootstrap')
    $mutexAcquired = $false
    try {
        $mutexAcquired = $bootstrapMutex.WaitOne()
    }
    catch [System.Threading.AbandonedMutexException] {
        # A previous holder exited without releasing; ownership is still acquired
        $mutexAcquired = $true
    }

    try {
        # Resolve ProgramData through the known-folder API instead of the environment,
        # which a non-elevated process can override via HKCU\Environment
        $programDataPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::CommonApplicationData)
        $stagingRoot = Join-Path $programDataPath 'Win11Debloat'

        $adminSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
        $systemSid = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)
        $trustedOwnerSids = @($adminSid.Value, $systemSid.Value)

        # Secure the staging directory against a staging-path swap (TOCTOU) by a non-elevated
        # process. %ProgramData% is world-writable at the root, so an attacker could pre-plant a
        # junction or a directory they own at this path. We close that as follows:
        #   1. Reject and delete any reparse point (junction/symlink) at the path, without
        #      following it into its target.
        #   2. Refuse to adopt an existing real directory that is not already owned by
        #      Administrators or SYSTEM - a non-elevated user's pre-created folder is owned by
        #      that user, so a non-trusted owner means the directory is hostile.
        #   3. Create the directory when absent and apply an Administrators/SYSTEM-only ACL.
        #   4. Re-verify after the ACL is in place: because the ACL now blocks non-elevated
        #      writers, a directory that is still a non-reparse, admin-owned directory here
        #      could not have been swapped by an attacker during the securing sequence.
        $existingStaging = Get-Item -LiteralPath $stagingRoot -Force -ErrorAction SilentlyContinue
        if ($existingStaging -and ($existingStaging.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            if ($existingStaging.Attributes -band [System.IO.FileAttributes]::Directory) {
                [System.IO.Directory]::Delete($stagingRoot, $false)
            }
            else {
                [System.IO.File]::Delete($stagingRoot)
            }
            $existingStaging = $null
        }

        if ($existingStaging) {
            $existingOwner = $existingStaging.GetAccessControl().GetOwner([System.Security.Principal.SecurityIdentifier]).Value
            if ($trustedOwnerSids -notcontains $existingOwner) {
                throw "Refusing to use staging directory '$stagingRoot': it already exists but is not owned by Administrators or SYSTEM (owner SID: $existingOwner). A non-elevated process may have created it. Remove it manually and re-run."
            }
        }
        else {
            New-Item -ItemType Directory -Path $stagingRoot | Out-Null
        }

        # Take ownership of the staging directory and restrict it to Administrators and SYSTEM.
        $acl = New-Object System.Security.AccessControl.DirectorySecurity
        $acl.SetOwner($adminSid)
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($sid in @($adminSid, $systemSid)) {
            $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sid, [System.Security.AccessControl.FileSystemRights]::FullControl, 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
        }
        Set-Acl -Path $stagingRoot -AclObject $acl

        # Post-securing verification: confirm the ACL landed on the intended object and not a
        # reparse point swapped in during the sequence above
        $securedStaging = Get-Item -LiteralPath $stagingRoot -Force
        $securedOwner = $securedStaging.GetAccessControl().GetOwner([System.Security.Principal.SecurityIdentifier]).Value
        if (($securedStaging.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or ($trustedOwnerSids -notcontains $securedOwner)) {
            throw "Staging directory '$stagingRoot' failed post-securing verification and may have been tampered with. Aborting for safety."
        }

        # Download the archive over TLS directly into the protected directory. Because only
        # Administrators and SYSTEM can write here, the archive cannot be swapped between download
        # and use, so the TLS-authenticated GitHub download is the integrity boundary.
        $stagedArchive = Join-Path $stagingRoot 'win11debloat.zip'
        try {
            if ($isDev) {
                Write-Output "> Downloading development version of Win11Debloat..."
                $sourceUri = "https://github.com/Raphire/Win11Debloat/archive/refs/heads/master.zip"
            }
            else {
                Write-Output "> Downloading Win11Debloat..."
                $sourceUri = (Invoke-RestMethod https://api.github.com/repos/Raphire/Win11Debloat/releases/latest).zipball_url
            }
            Invoke-RestMethod $sourceUri -OutFile $stagedArchive
        }
        catch {
            throw "Unable to fetch required files from GitHub. Please check your internet connection and try again. ($($_.Exception.Message))"
        }

        # One-time migration of configs, logs and backups from the old temp folder location
        $legacyWorkPath = Join-Path $env:TEMP 'Win11Debloat'
        foreach ($dirName in 'Config', 'Logs', 'Backups') {
            $legacyDir = Join-Path $legacyWorkPath $dirName
            $newDir = Join-Path $stagingRoot $dirName
            if ((Test-Path $legacyDir) -and -not (Test-Path $newDir)) {
                Copy-Item -Path $legacyDir -Destination $newDir -Recurse -Force
            }
        }

        # Remove old script files if they exist, but keep configs, logs and backups
        Write-Output "> Cleaning up old script files..."
        Get-ChildItem -Path $stagingRoot -Exclude Config, Logs, Backups, win11debloat.zip | Remove-Item -Recurse -Force

        $configDir = Join-Path $stagingRoot 'Config'
        $backupDir = Join-Path $stagingRoot 'ConfigOld'

        # Temporarily move existing config files to prevent them from being overwritten by the new script files
        if (Test-Path $configDir) {
            Write-Output ""
            Write-Output "> Backing up existing config files..."

            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

            $filesToKeep = @(
                'LastUsedSettings.json'
            )

            Get-ChildItem -Path $configDir -Recurse | Where-Object { $_.Name -in $filesToKeep } | Move-Item -Destination $backupDir
            Remove-Item $configDir -Recurse -Force
        }

        Write-Output ""
        Write-Output "> Unpacking..."

        # Restore the preserved config files in a finally block, so they are moved back
        # into the Config folder even when unpacking fails midway
        try {
            Expand-Archive -LiteralPath $stagedArchive -DestinationPath $stagingRoot -Force
            Remove-Item -LiteralPath $stagedArchive -Force

            # Move the contents of the extracted release folder up into the staging root
            $extractedRoot = Get-ChildItem -Path $stagingRoot -Directory -Filter '*Win11Debloat-*' | Select-Object -First 1
            if ($null -eq $extractedRoot) {
                throw "The downloaded archive did not contain the expected Win11Debloat folder."
            }
            Get-ChildItem -Path $extractedRoot.FullName -Force | Move-Item -Destination $stagingRoot -Force
            Remove-Item -LiteralPath $extractedRoot.FullName -Recurse -Force
        }
        finally {
            # Add existing config files back to Config folder
            if (Test-Path $backupDir) {
                if (-not (Test-Path $configDir)) {
                    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                }

                Write-Output ""
                Write-Output "> Restoring existing config files..."

                Get-ChildItem -Path $backupDir -Recurse | Move-Item -Destination $configDir -Force
                Remove-Item $backupDir -Recurse -Force
            }
        }

        Write-Output ""
        Write-Output "> Launching Win11Debloat..."

        # Run Win11Debloat script with the provided arguments (already elevated)
        $debloatScriptPath = Join-Path $stagingRoot 'Win11Debloat.ps1'
        $debloatProcess = Start-Process powershell.exe -WindowStyle $debloatWindowStyle -Wait -PassThru -ArgumentList "-executionpolicy bypass -File `"$debloatScriptPath`" $scriptArgs"

        if ($null -ne $debloatProcess -and $debloatProcess.ExitCode -ne 0) {
            throw "Win11Debloat.ps1 exited with code $($debloatProcess.ExitCode). Script files were kept in '$stagingRoot' for inspection, logs can be found in '$(Join-Path $stagingRoot 'Logs')'."
        }

        # Remove all remaining script files, except for configs, logs and backups
        Write-Output ""
        Write-Output "> Cleaning up..."
        Get-ChildItem -Path $stagingRoot -Exclude Config, Logs, Backups | Remove-Item -Recurse -Force
    }
    finally {
        if ($mutexAcquired) {
            $bootstrapMutex.ReleaseMutex()
        }
        $bootstrapMutex.Dispose()
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Output ""
    Write-Output "Press enter to exit..."
    Read-Host | Out-Null
    Exit 1
}
'@

$bootstrap = $bootstrapHeader + "`n" + $bootstrapBody

$encodedBootstrap = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($bootstrap))

# Elevate and run the bootstrap, which downloads, unpacks and launches Win11Debloat
$elevatedProcess = Start-Process powershell.exe -PassThru -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedBootstrap"

# Wait for the process to finish before continuing
$bootstrapExitCode = 0
if ($null -ne $elevatedProcess) {
    $elevatedProcess.WaitForExit()
    $bootstrapExitCode = $elevatedProcess.ExitCode
}

Write-Output ""

# Propagate a bootstrap failure (download, integrity, extraction, or script failure) as a nonzero exit code
if ($bootstrapExitCode -ne 0) {
    Exit $bootstrapExitCode
}
