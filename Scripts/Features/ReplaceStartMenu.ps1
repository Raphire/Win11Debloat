<#
    .SYNOPSIS
    Replaces the start menu layout for all user profiles.

    .DESCRIPTION
    Iterates over every existing user profile and the Default user profile,
    replacing each user's start2.bin file with the specified template. When
    using the default template, this clears all pinned apps from the start menu.

    Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/

    .PARAMETER startMenuTemplate
    Path to the .bin template file to apply. Defaults to the blank template
    bundled with the script (Assets/Start/start2.bin).

    .EXAMPLE
    ReplaceStartMenuForAllUsers

    .EXAMPLE
    ReplaceStartMenuForAllUsers -startMenuTemplate "C:\CustomLayout.bin"
#>
function ReplaceStartMenuForAllUsers {
    param (
        [string]$startMenuTemplate = "$script:AssetsPath\Start\start2.bin"
    )

    Write-Host "> Removing all pinned apps from the start menu for all users..."

    # Check if template bin file exists
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Error: Unable to clear start menu, start2.bin file missing from script folder" -ForegroundColor Red
        Write-Host ""
        return
    }

    # Get path to start menu file for all users
    $userPathString = GetUserDirectory -userName "*" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    $usersStartMenuPaths = Get-ChildItem -Path $userPathString -ErrorAction SilentlyContinue

    # Go through all users and replace the start menu file
    ForEach ($startMenuPath in $usersStartMenuPaths) {
        ReplaceStartMenu -startMenuBinFile "$($startMenuPath.Fullname)\start2.bin" -startMenuTemplate $startMenuTemplate
    }

    # Also replace the start menu file for the default user profile
    $defaultStartMenuPath = GetUserDirectory -userName "Default" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState" -exitIfPathNotFound $false

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Replace Start Menu for Default user profile with template $startMenuTemplate" -ForegroundColor Cyan
        return
    }

    # Create folder if it doesn't exist
    if (-not (Test-Path $defaultStartMenuPath)) {
        new-item $defaultStartMenuPath -ItemType Directory -Force | Out-Null
        Write-Host "Created LocalState folder for default user profile"
    }

    # Copy template to default profile
    ReplaceStartMenu -startMenuBinFile "$($defaultStartMenuPath)\start2.bin" -startMenuTemplate $startMenuTemplate
    Write-Host "Replaced start menu for the default user profile"
    Write-Host ""
}


<#
    .SYNOPSIS
    Replaces the start menu layout for a single user.

    .DESCRIPTION
    Backs up the current start2.bin file (if it exists), then copies the
    specified template over it. When using the default template this clears
    all pinned apps from the start menu. Validates that the template file
    exists and has a .bin extension before proceeding.

    Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/

    .PARAMETER startMenuBinFile
    The full path to the user's start2.bin file to replace.

    .PARAMETER startMenuTemplate
    Path to the .bin template file to apply. Defaults to the blank template
    bundled with the script (Assets/Start/start2.bin).

    .EXAMPLE
    ReplaceStartMenu -startMenuBinFile "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"

    .EXAMPLE
    ReplaceStartMenu -startMenuBinFile "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin" -startMenuTemplate "C:\CustomLayout.bin"
#>
function ReplaceStartMenu {
    param (
        [Parameter(Mandatory)]
        [string]$startMenuBinFile,
        [string]$startMenuTemplate = "$script:AssetsPath\Start\start2.bin"
    )

    # Check if template bin file exists
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Error: Unable to replace start menu, template file not found" -ForegroundColor Red
        return
    }

    if ([IO.Path]::GetExtension($startMenuTemplate) -ne ".bin") {
        Write-Host "Error: Unable to replace start menu, template file is not a valid .bin file" -ForegroundColor Red
        return
    }

    $userName = GetStartMenuUserNameFromPath -StartMenuBinFile $startMenuBinFile

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Replace Start Menu for user $userName with template $startMenuTemplate" -ForegroundColor Cyan
        return
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFileName = "Win11Debloat-StartBackup-$timestamp.bak"
    $startMenuDir = Split-Path $startMenuBinFile -Parent
    $backupBinFile = Join-Path $startMenuDir $backupFileName

    if (Test-Path $startMenuBinFile) {
        # Backup current start menu file
        Copy-Item -Path $startMenuBinFile -Destination $backupBinFile -Force
        Write-Verbose "Start menu backup for user $userName saved to $backupFileName"
    }
    else {
        Write-Host "Unable to find original start2.bin file for user $userName, no backup was created for this user" -ForegroundColor Yellow
        New-Item -ItemType File -Path $startMenuBinFile -Force
    }

    # Copy template file
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-Host "Replaced start menu for user $userName"
}

<#
    .SYNOPSIS
    Returns the full path to the start menu bin file for a given user.

    .DESCRIPTION
    Resolves the path to the start2.bin file for the specified username.
    When no username is provided or the value is empty, falls back to
    the current user's local app data path via $env:LOCALAPPDATA.

    .PARAMETER UserName
    The target username. Pass an empty string or omit to resolve for the current user.

    .EXAMPLE
    GetStartMenuBinPathForUser -UserName "Jeff"

    .EXAMPLE
    GetStartMenuBinPathForUser -UserName "Default"
#>
function GetStartMenuBinPathForUser {
    param(
        [string]$UserName
    )

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
    }

    return (GetUserDirectory -userName $UserName -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin" -exitIfPathNotFound $false)
}

<#
    .SYNOPSIS
    Extracts the username from a start2.bin file path.

    .DESCRIPTION
    Parses a typical C:\Users\<UserName>\AppData\... path and returns the
    username portion. Returns 'unknown' if the path does not match the
    expected pattern.

    .PARAMETER StartMenuBinFile
    The full path to a start2.bin file.

    .EXAMPLE
    GetStartMenuUserNameFromPath -StartMenuBinFile "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
#>
function GetStartMenuUserNameFromPath {
    param(
        [string]$StartMenuBinFile
    )

    $resolvedUserName = [regex]::Match($StartMenuBinFile, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value
    if ([string]::IsNullOrWhiteSpace($resolvedUserName)) {
        return 'unknown'
    }

    return $resolvedUserName
}


<#
    .SYNOPSIS
    Returns the path to the latest start menu backup file for the given scope.

    .DESCRIPTION
    Resolves the LocalState folder for the specified scope and returns the
    full path to the most recent Win11Debloat-StartBackup-*.bak file, or
    $null if no backup exists.

    For CurrentUser, uses $env:LOCALAPPDATA directly. For AllUsers, scans
    every user profile.

    .PARAMETER Scope
    The scope to check: CurrentUser or AllUsers.

    .EXAMPLE
    $backupPath = Get-StartMenuBackupPath -Scope 'CurrentUser'

    .EXAMPLE
    $backupPath = Get-StartMenuBackupPath -Scope 'AllUsers'
#>
function Get-StartMenuBackupPath {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string]$Scope
    )

    if ($Scope -eq 'CurrentUser') {
        $localStateDir = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
        $latestBackup = Get-ChildItem -Path (Join-Path $localStateDir 'Win11Debloat-StartBackup-*.bak') -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if ($latestBackup) { return $latestBackup.FullName }
        return $null
    }
    else {
        $userPathString = GetUserDirectory -userName "*" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
        $usersStartMenuPaths = Get-ChildItem -Path $userPathString -ErrorAction SilentlyContinue
        foreach ($startMenuPath in $usersStartMenuPaths) {
            $latestBackup = Get-ChildItem -Path (Join-Path $startMenuPath.FullName 'Win11Debloat-StartBackup-*.bak') -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending |
                Select-Object -First 1
            if ($latestBackup) { return $latestBackup.FullName }
        }
        return $null
    }
}


<#
    .SYNOPSIS
    Restores a user's start menu from a backup file.

    .DESCRIPTION
    Moves the current start2.bin to a .restore.bak safety copy, then copies
    the specified backup file into place. Returns a PSCustomObject with
    UserName, Result ($true/$false), and Message properties describing
    the outcome.

    .PARAMETER StartMenuBinFile
    The full path to the user's start2.bin file to restore.

    .PARAMETER BackupFilePath
    Path to the backup file to restore from. If omitted, automatically
    finds the latest Win11Debloat-StartBackup-*.bak file.

    .EXAMPLE
    RestoreStartMenuFromBackup -StartMenuBinFile "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"

    .EXAMPLE
    RestoreStartMenuFromBackup -StartMenuBinFile "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin" -BackupFilePath "C:\Backups\Win11Debloat-StartBackup-20260101_120000.bak"
#>
function RestoreStartMenuFromBackup {
    param(
        [Parameter(Mandatory)]
        [string]$StartMenuBinFile,
        [string]$BackupFilePath
    )

    $userName = GetStartMenuUserNameFromPath -StartMenuBinFile $StartMenuBinFile
    $backupBinFile = if ([string]::IsNullOrWhiteSpace($BackupFilePath)) {
        # Auto-detect latest backup in the same folder as the start2.bin
        $startMenuDir = Split-Path $StartMenuBinFile -Parent
        $latestBackup = Get-ChildItem -Path (Join-Path $startMenuDir 'Win11Debloat-StartBackup-*.bak') -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            Select-Object -First 1

        if ($latestBackup) { $latestBackup.FullName } else { $null }
    }
    else {
        $BackupFilePath
    }
    $restoreTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $restoreBackupFileName = "Win11Debloat-StartRestore-$restoreTimestamp.bak"
    $currentBinBackup = Join-Path (Split-Path $StartMenuBinFile -Parent) $restoreBackupFileName

    if ([string]::IsNullOrWhiteSpace($backupBinFile)) {
        return [PSCustomObject]@{
            UserName = $userName
            Result = $false
            Message = "No start menu backup file found for user $userName."
        }
    }

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Restore start menu for user $userName from backup $backupBinFile" -ForegroundColor Cyan
        return [PSCustomObject]@{
            UserName = $userName
            Result = $true
            Message = "[WhatIf] Restored start menu for user $userName."
        }
    }

    if (-not (Test-Path -LiteralPath $backupBinFile)) {
        return [PSCustomObject]@{
            UserName = $userName
            Result = $false
            Message = "No start menu backup file found for user $userName."
        }
    }

    try {
        if (Test-Path -LiteralPath $StartMenuBinFile) {
            Move-Item -Path $StartMenuBinFile -Destination $currentBinBackup -Force
        }

        Copy-Item -Path $backupBinFile -Destination $StartMenuBinFile -Force
        return [PSCustomObject]@{
            UserName = $userName
            Result = $true
            Message = "Restored start menu for user $userName."
        }
    }
    catch {
        return [PSCustomObject]@{
            UserName = $userName
            Result = $false
            Message = "Failed to restore start menu for user $userName. $($_.Exception.Message)"
        }
    }
}

<#
    .SYNOPSIS
    Restores the start menu for the current target user from a backup.

    .DESCRIPTION
    Resolves the start2.bin path for the currently logged-in user, then
    delegates to RestoreStartMenuFromBackup.

    .PARAMETER BackupFilePath
    Path to the backup file to restore from. If omitted, automatically
    finds the latest Win11Debloat-StartBackup-*.bak file.

    .EXAMPLE
    RestoreStartMenu

    .EXAMPLE
    RestoreStartMenu -BackupFilePath "C:\Backups\Win11Debloat-StartBackup-20260101_120000.bak"
#>
function RestoreStartMenu {
    param(
        [string]$BackupFilePath
    )

    $targetUserName = $env:USERNAME
    $startMenuBinFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"

    Write-Host "Restoring start menu for user $targetUserName from backup..."

    return RestoreStartMenuFromBackup -StartMenuBinFile $startMenuBinFile -BackupFilePath $BackupFilePath
}

<#
    .SYNOPSIS
    Restores the start menu for all user profiles from a backup.

    .DESCRIPTION
    Iterates over every existing user profile and restores each user's
    start2.bin from the latest backup in their LocalState folder. For the
    Default user profile, removes the start2.bin file (which was previously
    copied from a template) so that new profiles revert to the system
    default start menu.

    .PARAMETER BackupFilePath
    Path to the backup file to restore from. If omitted, automatically
    finds the latest Win11Debloat-StartBackup-*.bak in each user's
    LocalState folder.

    .EXAMPLE
    RestoreStartMenuForAllUsers

    .EXAMPLE
    RestoreStartMenuForAllUsers -BackupFilePath "C:\Backups\Win11Debloat-StartBackup-20260101_120000.bak"
#>
function RestoreStartMenuForAllUsers {
    param(
        [string]$BackupFilePath
    )

    $userPathString = GetUserDirectory -userName "*" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    $usersStartMenuPaths = Get-ChildItem -Path $userPathString -ErrorAction SilentlyContinue
    $results = @()

    Write-Host "Restoring start menu for all users from backup..."

    foreach ($startMenuPath in $usersStartMenuPaths) {
        $startMenuBinFile = Join-Path $startMenuPath.FullName 'start2.bin'
        $results += RestoreStartMenuFromBackup -StartMenuBinFile $startMenuBinFile -BackupFilePath $BackupFilePath
    }

    $defaultStartMenuPath = GetUserDirectory -userName "Default" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState" -exitIfPathNotFound $false

    if (Test-Path $defaultStartMenuPath) {
        $defaultStartMenuBinFile = Join-Path $defaultStartMenuPath 'start2.bin'
        if (Test-Path -LiteralPath $defaultStartMenuBinFile) {
            if ($script:Params.ContainsKey("WhatIf")) {
                Write-Host "[WhatIf] Remove start2.bin for the default user profile" -ForegroundColor Cyan
                $results += [PSCustomObject]@{
                    UserName = 'Default'
                    Result   = $true
                    Message  = '[WhatIf] Removed start2.bin for the default user profile.'
                }
            }
            else {
                try {
                    Remove-Item -LiteralPath $defaultStartMenuBinFile -Force
                    $results += [PSCustomObject]@{
                        UserName = 'Default'
                        Result   = $true
                        Message  = 'Removed start2.bin for the default user profile.'
                    }
                }
                catch {
                    $results += [PSCustomObject]@{
                        UserName = 'Default'
                        Result   = $false
                        Message  = "Failed to remove start2.bin for the default user profile. $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    if ($results.Count -eq 0) {
        $results += [PSCustomObject]@{
            UserName = 'unknown'
            Result = $false
            Message = 'No user start menu locations were found.'
        }
    }

    return $results
}