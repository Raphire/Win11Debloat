# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$script:AssetsPath\Start\start2.bin"
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
        ReplaceStartMenu $startMenuTemplate "$($startMenuPath.Fullname)\start2.bin"
    }

    # Also replace the start menu file for the default user profile
    $defaultStartMenuPath = GetUserDirectory -userName "Default" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState" -exitIfPathNotFound $false

    # Create folder if it doesn't exist
    if (-not (Test-Path $defaultStartMenuPath)) {
        new-item $defaultStartMenuPath -ItemType Directory -Force | Out-Null
        Write-Host "Created LocalState folder for default user profile"
    }

    # Copy template to default profile
    Copy-Item -Path $startMenuTemplate -Destination $defaultStartMenuPath -Force
    Write-Host "Replaced start menu for the default user profile"
    Write-Host ""
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenu {
    param (
        $startMenuTemplate = "$script:AssetsPath\Start\start2.bin",
        $startMenuBinFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
    )

    # Change path to correct user if a user was specified
    if ($script:Params.ContainsKey("User")) {
        $startMenuBinFile = GetStartMenuBinPathForUser -UserName (GetUserName)
    }

    # Check if template bin file exists
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Error: Unable to replace start menu, template file not found" -ForegroundColor Red
        return
    }

    if ([IO.Path]::GetExtension($startMenuTemplate) -ne ".bin" ) {
        Write-Host "Error: Unable to replace start menu, template file is not a valid .bin file" -ForegroundColor Red
        return
    }

    $userName = GetStartMenuUserNameFromPath -StartMenuBinFile $startMenuBinFile

    $backupBinFile = $startMenuBinFile + ".bak"

    if (Test-Path $startMenuBinFile) {
        # Backup current start menu file
        Move-Item -Path $startMenuBinFile -Destination $backupBinFile -Force
    }
    else {
        Write-Host "Unable to find original start2.bin file for user $userName, no backup was created for this user" -ForegroundColor Yellow
        New-Item -ItemType File -Path $startMenuBinFile -Force
    }

    # Copy template file
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-Host "Replaced start menu for user $userName"
}

function GetStartMenuBinPathForUser {
    param(
        [string]$UserName
    )

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
    }

    return (GetUserDirectory -userName $UserName -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin" -exitIfPathNotFound $false)
}

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



function RestoreStartMenuFromBackup {
    param(
        [Parameter(Mandatory)]
        [string]$StartMenuBinFile,
        [Parameter(Mandatory = $false)]
        [string]$BackupFilePath
    )

    $userName = GetStartMenuUserNameFromPath -StartMenuBinFile $StartMenuBinFile
    $backupBinFile = if ([string]::IsNullOrWhiteSpace($BackupFilePath)) {
        $StartMenuBinFile + '.bak'
    }
    else {
        $BackupFilePath
    }
    $currentBinBackup = $StartMenuBinFile + '.restore.bak'

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

function RestoreStartMenu {
    param(
        [Parameter(Mandatory = $false)]
        [string]$BackupFilePath
    )

    $targetUserName = GetUserName
    $startMenuBinFile = GetStartMenuBinPathForUser -UserName $targetUserName

    Write-Host "Restoring start menu for user $targetUserName from backup..."

    return RestoreStartMenuFromBackup -StartMenuBinFile $startMenuBinFile -BackupFilePath $BackupFilePath
}

function RestoreStartMenuForAllUsers {
    param(
        [Parameter(Mandatory = $false)]
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

    if ($results.Count -eq 0) {
        $results += [PSCustomObject]@{
            UserName = 'unknown'
            Result = $false
            Message = 'No user start menu locations were found.'
        }
    }

    return $results
}