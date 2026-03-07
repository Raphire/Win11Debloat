# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$script:AssetsPath/Start/start2.bin"
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
    $usersStartMenuPaths = get-childitem -path $userPathString

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
        $startMenuTemplate = "$script:AssetsPath/Start/start2.bin",
        $startMenuBinFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
    )

    # Change path to correct user if a user was specified
    if ($script:Params.ContainsKey("User")) {
        $startMenuBinFile = GetUserDirectory -userName "$(GetUserName)" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin" -exitIfPathNotFound $false
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

    $userName = [regex]::Match($startMenuBinFile, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value

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