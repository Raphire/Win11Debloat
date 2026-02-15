#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$CLI,
    [switch]$Silent,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$User,
    [switch]$NoRestartExplorer,
    [switch]$CreateRestorePoint,
    [switch]$RunAppsListGenerator,
    [switch]$RunDefaults,
    [switch]$RunDefaultsLite,
    [switch]$RunSavedSettings,
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
    [switch]$DisableTelemetry,
    [switch]$DisableFastStartup,
    [switch]$DisableBitlockerAutoEncryption,
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableUpdateASAP,
    [switch]$PreventUpdateAutoReboot,
    [switch]$DisableDeliveryOptimization,
    [switch]$DisableBing,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscreenTips,
    [switch]$DisableSuggestions,
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
    [switch]$DisableStartPhoneLink,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableClickToDo,
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
    [switch]$HideShare
)



# Define script-level variables & paths
$script:Version = "2026.02.12"
$script:DefaultSettingsFilePath = "$PSScriptRoot/DefaultSettings.json"
$script:AppsListFilePath = "$PSScriptRoot/Apps.json"
$script:SavedSettingsFilePath = "$PSScriptRoot/LastUsedSettings.json"
$script:CustomAppsListFilePath = "$PSScriptRoot/CustomAppsList"
$script:DefaultLogPath = "$PSScriptRoot/Logs/Win11Debloat.log"
$script:RegfilesPath = "$PSScriptRoot/Regfiles"
$script:AssetsPath = "$PSScriptRoot/Assets"
$script:AppSelectionSchema = "$PSScriptRoot/Schemas/AppSelectionWindow.xaml"
$script:MainWindowSchema = "$PSScriptRoot/Schemas/MainWindow.xaml"
$script:MessageBoxSchema = "$PSScriptRoot/Schemas/MessageBoxWindow.xaml"
$script:AboutWindowSchema = "$PSScriptRoot/Schemas/AboutWindow.xaml"
$script:FeaturesFilePath = "$script:AssetsPath/Features.json"

$script:ControlParams = 'WhatIf', 'Confirm', 'Verbose', 'Debug', 'LogPath', 'Silent', 'Sysprep', 'User', 'NoRestartExplorer', 'RunDefaults', 'RunDefaultsLite', 'RunSavedSettings', 'RunAppsListGenerator', 'CLI', 'AppRemovalTarget'

# Script-level variables for GUI elements
$script:GuiConsoleOutput = $null
$script:GuiConsoleScrollViewer = $null
$script:GuiWindow = $null
$script:CancelRequested = $false

# Check if current powershell environment is limited by security policies
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Error "Win11Debloat is unable to run on your system, powershell execution is restricted by security policies"
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Display ASCII art launch logo in CLI
Clear-Host
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
Write-Host "                   " -NoNewline; Write-Host "   (" -ForegroundColor Yellow -NoNewline; Write-Host "'''" -ForegroundColor Red -NoNewline; Write-Host ") " -ForegroundColor Yellow -NoNewline; Write-Host "   *  *" -ForegroundColor DarkYellow
Write-Host "                   " -NoNewline; Write-Host "   ( " -ForegroundColor DarkYellow -NoNewline; Write-Host "'" -ForegroundColor Red -NoNewline; Write-Host " )   " -ForegroundColor DarkYellow -NoNewline; Write-Host "*" -ForegroundColor Yellow
Write-Host ""
Write-Host "             Win11Debloat is launching..." -ForegroundColor White
Write-Host "               Leave this window open" -ForegroundColor DarkGray
Write-Host ""

# Log script output to 'Win11Debloat.log' at the specified path
if ($LogPath -and (Test-Path $LogPath)) {
    Start-Transcript -Path "$LogPath/Win11Debloat.log" -Append -IncludeInvocationHeader -Force | Out-Null
}
else {
    Start-Transcript -Path $script:DefaultLogPath -Append -IncludeInvocationHeader -Force | Out-Null
}

# Check if script has all required files
if (-not ((Test-Path $script:DefaultSettingsFilePath) -and (Test-Path $script:AppsListFilePath) -and (Test-Path $script:RegfilesPath) -and (Test-Path $script:AssetsPath) -and (Test-Path $script:AppSelectionSchema) -and (Test-Path $script:FeaturesFilePath))) {
    Write-Error "Win11Debloat is unable to find required files, please ensure all script files are present"
    Write-Output ""
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Load feature info from file
$script:Features = @{}
try {
    $featuresData = Get-Content -Path $script:FeaturesFilePath -Raw | ConvertFrom-Json
    foreach ($feature in $featuresData.Features) {
        $script:Features[$feature.FeatureId] = $feature
    }
}
catch {
    Write-Error "Failed to load feature info from Features.json file"
    Write-Output ""
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Check if WinGet is installed & if it is, check if the version is at least v1.4
try {
    if ([int](((winget -v) -replace 'v','').split('.')[0..1] -join '') -gt 14) {
        $script:WingetInstalled = $true
    }
    else {
        $script:WingetInstalled = $false
    }
}
catch {
    $script:WingetInstalled = $false
}

# Show WinGet warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
if (-not $script:WingetInstalled -and -not $Silent) {
    Write-Warning "WinGet is not installed or outdated, this may prevent Win11Debloat from removing certain apps"
    Write-Output ""
    Write-Output "Press any key to continue anyway..."
    $null = [System.Console]::ReadKey()
}



##################################################################################################################
#                                                                                                                #
#                                          FUNCTION IMPORTS/DEFINITIONS                                          #
#                                                                                                                #
##################################################################################################################

# Load CLI functions
. "$PSScriptRoot/Scripts/CLI/ShowCLILastUsedSettings.ps1"  
. "$PSScriptRoot/Scripts/CLI/ShowCLIDefaultModeAppRemovalOptions.ps1"
. "$PSScriptRoot/Scripts/CLI/ShowCLIDefaultModeOptions.ps1"
. "$PSScriptRoot/Scripts/CLI/ShowCLIAppRemoval.ps1"
. "$PSScriptRoot/Scripts/CLI/ShowCLIMenuOptions.ps1"
. "$PSScriptRoot/Scripts/CLI/PrintPendingChanges.ps1"
. "$PSScriptRoot/Scripts/CLI/PrintHeader.ps1"

# Load GUI functions
. "$PSScriptRoot/Scripts/GUI/GetSystemUsesDarkMode.ps1"
. "$PSScriptRoot/Scripts/GUI/SetWindowThemeResources.ps1"
. "$PSScriptRoot/Scripts/GUI/AttachShiftClickBehavior.ps1"
. "$PSScriptRoot/Scripts/GUI/ApplySettingsToUiControls.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-ModernMessageBox.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-AppSelectionWindow.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-MainWindow.ps1"
. "$PSScriptRoot/Scripts/GUI/Show-AboutDialog.ps1"

# Load File I/O functions
. "$PSScriptRoot/Scripts/FileIO/LoadJsonFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/SaveSettings.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadSettings.ps1"
. "$PSScriptRoot/Scripts/FileIO/SaveCustomAppsListToFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/ValidateAppslist.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadAppsFromFile.ps1"
. "$PSScriptRoot/Scripts/FileIO/LoadAppsDetailsFromJson.ps1"

# Writes to both GUI console output and standard console
function Write-ToConsole {
    param(
        [string]$message,
        [string]$ForegroundColor = $null
    )
    
    if ($script:GuiConsoleOutput) {
        # GUI mode
        $timestamp = Get-Date -Format "HH:mm:ss"
        $script:GuiConsoleOutput.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Send, [action]{
            try {
                $runText = "[$timestamp] $message`n"
                $run = New-Object System.Windows.Documents.Run $runText

                if ($ForegroundColor) {
                    try {
                        $colorObj = [System.Windows.Media.ColorConverter]::ConvertFromString($ForegroundColor)
                        if ($colorObj) {
                            $brush = [System.Windows.Media.SolidColorBrush]::new($colorObj)
                            $run.Foreground = $brush
                        }
                    }
                    catch {
                        # Invalid color string - ignore and fall back to default
                    }
                }

                $script:GuiConsoleOutput.Inlines.Add($run)
                if ($script:GuiConsoleScrollViewer) { $script:GuiConsoleScrollViewer.ScrollToEnd() }
            }
            catch {
                # If any UI update fails, fall back to simple text append
                try { $script:GuiConsoleOutput.Text += "[$timestamp] $message`n" } catch {}
            }
        })

        # Force UI to process pending updates for real-time display
        if ($script:GuiWindow) {
            $script:GuiWindow.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
        }
    }

    try {
        if ($ForegroundColor) {
            Write-Host $message -ForegroundColor $ForegroundColor
        }
        else {
            Write-Host $message
        }
    }
    catch {
        Write-Host $message
    }
}


# Add parameter to script and write to file
function AddParameter {
    param (
        $parameterName,
        $value = $true
    )

    # Add parameter or update its value if key already exists
    if (-not $script:Params.ContainsKey($parameterName)) {
        $script:Params.Add($parameterName, $value)
    }
    else {
        $script:Params[$parameterName] = $value
    }
}


# Run winget list and return installed apps (sync or async)
function GetInstalledAppsViaWinget {
    param (
        [int]$TimeOut = 10,
        [switch]$Async
    )

    if (-not $script:WingetInstalled) { return $null }

    if ($Async) {
        $wingetListJob = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
        return @{ Job = $wingetListJob; StartTime = Get-Date }
    }
    else {
        $wingetListJob = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
        $jobDone = $wingetListJob | Wait-Job -TimeOut $TimeOut
        if (-not $jobDone) {
            Remove-Job -Job $wingetListJob -Force -ErrorAction SilentlyContinue
            return $null
        }
        $result = Receive-Job -Job $wingetListJob
        Remove-Job -Job $wingetListJob -ErrorAction SilentlyContinue
        return $result
    }
}


function GetUserName {
    if ($script:Params.ContainsKey("User")) {
        return $script:Params.Item("User")
    }

    return $env:USERNAME
}



# Returns the directory path of the specified user, exits script if user path can't be found
function GetUserDirectory {
    param (
        $userName,
        $fileName = "",
        $exitIfPathNotFound = $true
    )

    try {
        if (-not (CheckIfUserExists -userName $userName) -and $userName -ne "*") {
            Write-Error "User $userName does not exist on this system"
            AwaitKeyToExit
        }

        $userDirectoryExists = Test-Path "$env:SystemDrive\Users\$userName"
        $userPath = "$env:SystemDrive\Users\$userName\$fileName"

        if ((Test-Path $userPath) -or ($userDirectoryExists -and (-not $exitIfPathNotFound))) {
            return $userPath
        }

        $userDirectoryExists = Test-Path ($env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName")
        $userPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName\$fileName"

        if ((Test-Path $userPath) -or ($userDirectoryExists -and (-not $exitIfPathNotFound))) {
            return $userPath
        }
    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $userName. Please ensure the user exists on this system"
        AwaitKeyToExit
    }

    Write-Error "Unable to find user directory path for user $userName"
    AwaitKeyToExit
}


function CheckIfUserExists {
    param (
        $userName
    )

    if ($userName -match '[<>:"|?*]') {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($userName)) {
        return $false
    }

    try {
        $userExists = Test-Path "$env:SystemDrive\Users\$userName"

        if ($userExists) {
            return $true
        }

        $userExists = Test-Path ($env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName")

        if ($userExists) {
            return $true
        }
    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $userName. Please ensure the user exists on this system"
    }

    return $false
}


# Target is determined from $script:Params["AppRemovalTarget"] or defaults to "AllUsers"
# Target values: "AllUsers" (removes for all users + from image), "CurrentUser", or a specific username
function GetTargetUserForAppRemoval {
    if ($script:Params.ContainsKey("AppRemovalTarget")) {
        return $script:Params["AppRemovalTarget"]
    }
    
    return "AllUsers"
}


function GetFriendlyTargetUserName {
    $target = GetTargetUserForAppRemoval

    switch ($target) {
        "AllUsers" { return "all users" }
        "CurrentUser" { return "the current user" }
        default { return "user $target" }
    }
}


# Check if this machine supports S0 Modern Standby power state. Returns true if S0 Modern Standby is supported, false otherwise.
function CheckModernStandbySupport {
    $count = 0

    try {
        switch -Regex (powercfg /a) {
            ':' {
                $count += 1
            }

            '(.*S0.{1,}\))' {
                if ($count -eq 1) {
                    return $true
                }
            }
        }
    }
    catch {
        Write-Host "Error: Unable to check for S0 Modern Standby support, powercfg command failed" -ForegroundColor Red
        Write-Host ""
        Write-Host "Press any key to continue..."
        $null = [System.Console]::ReadKey()
        return $true
    }

    return $false
}


# Removes apps specified during function call based on the target scope.
function RemoveApps {
    param (
        $appslist
    )

    # Determine target from script-level params, defaulting to AllUsers
    $targetUser = GetTargetUserForAppRemoval

    Foreach ($app in $appsList) {
        if ($script:CancelRequested) {
            return
        }

        Write-ToConsole "Attempting to remove $app..."

        # Use WinGet only to remove OneDrive and Edge
        if (($app -eq "Microsoft.OneDrive") -or ($app -eq "Microsoft.Edge")) {
            if ($script:WingetInstalled -eq $false) {
                Write-ToConsole "WinGet is either not installed or is outdated, $app could not be removed" -ForegroundColor Red
                continue
            }

            $appName = $app -replace '\.', '_'

            # Uninstall app via WinGet, or create a scheduled task to uninstall it later
            if ($script:Params.ContainsKey("User")) {
                RegImport "Adding scheduled task to uninstall $app for user $(GetUserName)..." "Uninstall_$($appName).reg"
            }
            elseif ($script:Params.ContainsKey("Sysprep")) {
                RegImport "Adding scheduled task to uninstall $app after for new users..." "Uninstall_$($appName).reg"
            }
            else {
                # Uninstall app via WinGet
                winget uninstall --accept-source-agreements --disable-interactivity --id $app

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "Uninstall failed with exit code")) {
                    Write-ToConsole "Unable to uninstall Microsoft Edge via WinGet" -ForegroundColor Red

                    if ($script:GuiConsoleOutput) {
                        $result = Show-ModernMessageBox -Message 'Unable to uninstall Microsoft Edge via WinGet. Would you like to forcefully uninstall it? NOT RECOMMENDED!' -Title 'Force Uninstall Microsoft Edge?' -Button 'YesNo' -Icon 'Warning'

                        if ($result -eq 'Yes') {
                            Write-ToConsole ""
                            ForceRemoveEdge
                        }
                    }
                    elseif ($( Read-Host -Prompt "Would you like to forcefully uninstall Microsoft Edge? NOT RECOMMENDED! (y/n)" ) -eq 'y') {
                        Write-ToConsole ""
                        ForceRemoveEdge
                    }
                }
            }

            continue
        }

        # Use Remove-AppxPackage to remove all other apps
        $appPattern = '*' + $app + '*'

        try {
            switch ($targetUser) {
                "AllUsers" {
                    # Remove installed app for all existing users
                    Get-AppxPackage -Name $appPattern -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue

                    # Remove provisioned app from OS image, so the app won't be installed for any new users
                    Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $appPattern } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
                }
                "CurrentUser" {
                    # Remove installed app for current user only
                    Get-AppxPackage -Name $appPattern | Remove-AppxPackage -ErrorAction Continue
                }
                default {
                    # Target is a specific username - remove app for that user only
                    # Get the user's SID
                    $userAccount = New-Object System.Security.Principal.NTAccount($targetUser)
                    $userSid = $userAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
                    
                    # Remove the app package for the specific user
                    Get-AppxPackage -Name $appPattern -User $userSid | Remove-AppxPackage -User $userSid -ErrorAction Continue
                }
            }
        }
        catch {
            if ($DebugPreference -ne "SilentlyContinue") {
                Write-ToConsole "Something went wrong while trying to remove $app" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }
    }

    Write-ToConsole ""
}


# Forcefully removes Microsoft Edge using its uninstaller
# Credit: Based on work from loadstring1 & ave9858
function ForceRemoveEdge {
    Write-ToConsole "> Forcefully uninstalling Microsoft Edge..."

    $regView = [Microsoft.Win32.RegistryView]::Registry32
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)
    $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev').SetValue('AllowUninstall', '')

    # Create stub (This somehow allows uninstalling Edge)
    $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    New-Item $edgeStub -ItemType Directory | Out-Null
    New-Item "$edgeStub\MicrosoftEdge.exe" | Out-Null

    # Remove edge
    $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
    if ($null -ne $uninstallRegKey) {
        Write-ToConsole "Running uninstaller..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-ToConsole "Removing leftover files..."

        $edgePaths = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
            "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
            "$env:USERPROFILE\Desktop\Microsoft Edge.lnk",
            "$edgeStub"
        )

        foreach ($path in $edgePaths) {
            if (Test-Path -Path $path) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
                Write-ToConsole "  Removed $path" -ForegroundColor DarkGray
            }
        }

        Write-ToConsole "Cleaning up registry..."

        # Remove MS Edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-ToConsole "Microsoft Edge was uninstalled"
    }
    else {
        Write-ToConsole "Unable to forcefully uninstall Microsoft Edge, uninstaller could not be found" -ForegroundColor Red
    }
}


# Import & execute regfile
function RegImport {
    param (
        $message,
        $path
    )

    Write-ToConsole $message

    # Validate that the regfile exists in both locations
    if (-not (Test-Path "$script:RegfilesPath\$path") -or -not (Test-Path "$script:RegfilesPath\Sysprep\$path")) {
        Write-ToConsole "Error: Unable to find registry file: $path" -ForegroundColor Red
        Write-ToConsole ""
        return
    }

    # Reset exit code before running reg.exe for reliable success detection
    $global:LASTEXITCODE = 0

    if ($script:Params.ContainsKey("Sysprep")) {
        $defaultUserPath = GetUserDirectory -userName "Default" -fileName "NTUSER.DAT"

        reg load "HKU\Default" $defaultUserPath | Out-Null
        $regOutput = reg import "$script:RegfilesPath\Sysprep\$path" 2>&1
        reg unload "HKU\Default" | Out-Null
    }
    elseif ($script:Params.ContainsKey("User")) {
        $userPath = GetUserDirectory -userName $script:Params.Item("User") -fileName "NTUSER.DAT"

        reg load "HKU\Default" $userPath | Out-Null
        $regOutput = reg import "$script:RegfilesPath\Sysprep\$path" 2>&1
        reg unload "HKU\Default" | Out-Null
    }
    else {
        $regOutput = reg import "$script:RegfilesPath\$path" 2>&1
    }

    $hasSuccess = $LASTEXITCODE -eq 0
    
    if ($regOutput) {
        foreach ($line in $regOutput) {
            $lineText = if ($line -is [System.Management.Automation.ErrorRecord]) { $line.Exception.Message } else { $line.ToString() }
            if ($lineText -and $lineText.Length -gt 0) {
                if ($hasSuccess) {
                    Write-ToConsole $lineText
                }
                else {
                    Write-ToConsole $lineText -ForegroundColor Red
                }
            }
        }
    }

    if (-not $hasSuccess) {
        Write-ToConsole "Failed importing registry file: $path" -ForegroundColor Red
    }

    Write-ToConsole ""
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$script:AssetsPath/Start/start2.bin"
    )

    Write-ToConsole "> Removing all pinned apps from the start menu for all users..."

    # Check if template bin file exists
    if (-not (Test-Path $startMenuTemplate)) {
        Write-ToConsole "Error: Unable to clear start menu, start2.bin file missing from script folder" -ForegroundColor Red
        Write-ToConsole ""
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
        Write-ToConsole "Created LocalState folder for default user profile"
    }

    # Copy template to default profile
    Copy-Item -Path $startMenuTemplate -Destination $defaultStartMenuPath -Force
    Write-ToConsole "Replaced start menu for the default user profile"
    Write-ToConsole ""
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
        Write-ToConsole "Error: Unable to replace start menu, template file not found" -ForegroundColor Red
        return
    }

    if ([IO.Path]::GetExtension($startMenuTemplate) -ne ".bin" ) {
        Write-ToConsole "Error: Unable to replace start menu, template file is not a valid .bin file" -ForegroundColor Red
        return
    }

    $userName = [regex]::Match($startMenuBinFile, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value

    $backupBinFile = $startMenuBinFile + ".bak"

    if (Test-Path $startMenuBinFile) {
        # Backup current start menu file
        Move-Item -Path $startMenuBinFile -Destination $backupBinFile -Force
    }
    else {
        Write-ToConsole "Unable to find original start2.bin file for user $userName, no backup was created for this user" -ForegroundColor Yellow
        New-Item -ItemType File -Path $startMenuBinFile -Force
    }

    # Copy template file
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-ToConsole "Replaced start menu for user $userName"
}


# Generates a list of apps to remove based on the Apps parameter
function GenerateAppsList {
    if (-not ($script:Params["Apps"] -and $script:Params["Apps"] -is [string])) {
        return @()
    }

    $appMode = $script:Params["Apps"].toLower()

    switch ($appMode) {
        'default' {
            $appsList = LoadAppsFromFile $script:AppsListFilePath
            return $appsList
        }
        default {
            $appsList = $script:Params["Apps"].Split(',') | ForEach-Object { $_.Trim() }
            $validatedAppsList = ValidateAppslist $appsList
            return $validatedAppsList
        }
    }
}

# Executes a single parameter/feature based on its key
# Parameters:
#   $paramKey - The parameter name to execute
function ExecuteParameter {
    param (
        [string]$paramKey
    )
    
    # Check if this feature has metadata in Features.json
    $feature = $null
    if ($script:Features.ContainsKey($paramKey)) {
        $feature = $script:Features[$paramKey]
    }
    
    # If feature has RegistryKey and ApplyText, use dynamic RegImport
    if ($feature -and $feature.RegistryKey -and $feature.ApplyText) {
        RegImport $feature.ApplyText $feature.RegistryKey
        
        # Handle special cases that have additional logic after RegImport
        switch ($paramKey) {
            'DisableBing' {
                # Also remove the app package for Bing search
                RemoveApps 'Microsoft.BingSearch'
            }
            'DisableCopilot' {
                # Also remove the app package for Copilot
                RemoveApps 'Microsoft.Copilot'
            }
            'DisableWidgets' {
                # Also remove the app package for Widgets
                RemoveApps 'Microsoft.StartExperiencesApp'
            }
        }
        return
    }
    
    # Handle features without RegistryKey or with special logic
    switch ($paramKey) {
        'RemoveApps' {
            Write-ToConsole "> Removing selected apps for $(GetFriendlyTargetUserName)..."
            $appsList = GenerateAppsList

            if ($appsList.Count -eq 0) {
                Write-ToConsole "No valid apps were selected for removal" -ForegroundColor Yellow
                Write-ToConsole ""
                return
            }

            Write-ToConsole "$($appsList.Count) apps selected for removal"
            RemoveApps $appsList
        }
        'RemoveAppsCustom' {
            Write-ToConsole "> Removing selected apps..."
            $appsList = LoadAppsFromFile $script:CustomAppsListFilePath

            if ($appsList.Count -eq 0) {
                Write-ToConsole "No valid apps were selected for removal" -ForegroundColor Yellow
                Write-ToConsole ""
                return
            }

            Write-ToConsole "$($appsList.Count) apps selected for removal"
            RemoveApps $appsList
        }
        'RemoveCommApps' {
            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
            Write-ToConsole "> Removing Mail, Calendar and People apps..."
            RemoveApps $appsList
            return
        }
        'RemoveW11Outlook' {
            $appsList = 'Microsoft.OutlookForWindows'
            Write-ToConsole "> Removing new Outlook for Windows app..."
            RemoveApps $appsList
            return
        }
        'RemoveGamingApps' {
            $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
            Write-ToConsole "> Removing gaming related apps..."
            RemoveApps $appsList
            return
        }
        'RemoveHPApps' {
            $appsList = 'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl'
            Write-ToConsole "> Removing HP apps..."
            RemoveApps $appsList
            return
        }
        "ForceRemoveEdge" {
            ForceRemoveEdge
            return
        }
        'ClearStart' {
            Write-ToConsole "> Removing all pinned apps from the start menu for user $(GetUserName)..."
            ReplaceStartMenu
            Write-ToConsole ""
            return
        }
        'ReplaceStart' {
            Write-ToConsole "> Replacing the start menu for user $(GetUserName)..."
            ReplaceStartMenu $script:Params.Item("ReplaceStart")
            Write-ToConsole ""
            return
        }
        'ClearStartAllUsers' {
            ReplaceStartMenuForAllUsers
            return
        }
        'ReplaceStartAllUsers' {
            ReplaceStartMenuForAllUsers $script:Params.Item("ReplaceStartAllUsers")
            return
        }
    }
}


# Executes all selected parameters/features
# Parameters:
function ExecuteAllChanges {    
    # Create restore point if requested (CLI only - GUI handles this separately)
    if ($script:Params.ContainsKey("CreateRestorePoint")) {
        Write-ToConsole "> Attempting to create a system restore point..."
        CreateSystemRestorePoint
        Write-ToConsole ""
    }
    
    # Execute all parameters
    foreach ($paramKey in $script:Params.Keys) {
        if ($script:CancelRequested) { 
            return
        }

        if ($script:ControlParams -contains $paramKey) {
            continue
        }
        
        ExecuteParameter -paramKey $paramKey
    }
}


function CreateSystemRestorePoint {
    $SysRestore = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval"
    $failed = $false

    if ($SysRestore.RPSessionInterval -eq 0) {
        # In GUI mode, skip the prompt and just try to enable it
        if ($script:GuiConsoleOutput -or $Silent -or $( Read-Host -Prompt "System restore is disabled, would you like to enable it and create a restore point? (y/n)") -eq 'y') {
            $enableSystemRestoreJob = Start-Job {
                try {
                    Enable-ComputerRestore -Drive "$env:SystemDrive"
                }
                catch {
                    return "Error: Failed to enable System Restore: $_"
                }
                return $null
            }

            $enableSystemRestoreJobDone = $enableSystemRestoreJob | Wait-Job -TimeOut 20

            if (-not $enableSystemRestoreJobDone) {
                Remove-Job -Job $enableSystemRestoreJob -Force -ErrorAction SilentlyContinue
                Write-ToConsole "Error: Failed to enable system restore and create restore point, operation timed out" -ForegroundColor Red
                $failed = $true
            }
            else {
                $result = Receive-Job $enableSystemRestoreJob
                Remove-Job -Job $enableSystemRestoreJob -ErrorAction SilentlyContinue
                if ($result) {
                    Write-ToConsole $result -ForegroundColor Red
                    $failed = $true
                }
            }
        }
        else {
            Write-ToConsole ""
            $failed = $true
        }
    }

    if (-not $failed) {
        $createRestorePointJob = Start-Job {
            # Find existing restore points that are less than 24 hours old
            try {
                $recentRestorePoints = Get-ComputerRestorePoint | Where-Object { (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24) }
            }
            catch {
                return @{ Success = $false; Message = "Error: Unable to retrieve existing restore points: $_" }
            }

            if ($recentRestorePoints.Count -eq 0) {
                try {
                    Checkpoint-Computer -Description "Restore point created by Win11Debloat" -RestorePointType "MODIFY_SETTINGS"
                    return @{ Success = $true; Message = "System restore point created successfully" }
                }
                catch {
                    return @{ Success = $false; Message = "Error: Unable to create restore point: $_" }
                }
            }
            else {
                return @{ Success = $true; Message = "A recent restore point already exists, no new restore point was created" }
            }
        }

        $createRestorePointJobDone = $createRestorePointJob | Wait-Job -TimeOut 1

        if (-not $createRestorePointJobDone) {
            Remove-Job -Job $createRestorePointJob -Force -ErrorAction SilentlyContinue
            Write-ToConsole "Error: Failed to create system restore point, operation timed out" -ForegroundColor Red
            $failed = $true
        }
        else {
            $result = Receive-Job $createRestorePointJob
            Remove-Job -Job $createRestorePointJob -ErrorAction SilentlyContinue
            if ($result.Success) {
                Write-ToConsole $result.Message
            }
            else {
                Write-ToConsole $result.Message -ForegroundColor Red
                $failed = $true
            }
        }
    }

    # Ensure that the user is aware if creating a restore point failed, and give them the option to continue without a restore point or cancel the script
    if ($failed) {
        if ($script:GuiConsoleOutput) {
            $result = Show-ModernMessageBox "Failed to create a system restore point. Do you want to continue without a restore point?" "Restore Point Creation Failed" "YesNo" "Warning"

            if ($result -ne "Yes") {
                $script:CancelRequested = $true
                return
            }
        }
        elseif (-not $Silent) {
            Write-ToConsole "Failed to create a system restore point. Do you want to continue without a restore point? (y/n)" -ForegroundColor Yellow
            if ($( Read-Host ) -ne 'y') {
                $script:CancelRequested = $true
                return
            }
        }

        Write-ToConsole "Warning: Continuing without restore point" -ForegroundColor Yellow
    }
}


# Restart the Windows Explorer process
function RestartExplorer {
    Write-ToConsole "> Attempting to restart the Windows Explorer process to apply all changes..."
    
    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User") -or $script:Params.ContainsKey("NoRestartExplorer")) {
        Write-ToConsole "Explorer process restart was skipped, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
        return
    }

    if ($script:Params.ContainsKey("DisableMouseAcceleration")) {
        Write-ToConsole "Warning: Changes to the Enhance Pointer Precision setting will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableStickyKeys")) {
        Write-ToConsole "Warning: Changes to the Sticky Keys setting will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableAnimations")) {
        Write-ToConsole "Warning: Animations will only be disabled after a reboot" -ForegroundColor Yellow
    }

    # Only restart if the powershell process matches the OS architecture.
    # Restarting explorer from a 32bit PowerShell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem) {
        Write-ToConsole "Restarting the Windows Explorer process... (This may cause your screen to flicker)"
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-ToConsole "Unable to restart Windows Explorer process, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
    }
}


function AwaitKeyToExit {
    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "Press any key to exit..."
        $null = [System.Console]::ReadKey()
    }

    Stop-Transcript
    Exit
}



##################################################################################################################
#                                                                                                                #
#                                                  SCRIPT START                                                  #
#                                                                                                                #
##################################################################################################################



# Get current Windows build version
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

# Check if the machine supports Modern Standby, this is used to determine if the DisableModernStandbyNetworking option can be used
$script:ModernStandbySupported = CheckModernStandbySupport

$script:Params = $PSBoundParameters

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
    Write-Host "Verbose mode is enabled"
    Write-Output ""
    Write-Output "Press any key to continue..."
    $null = [System.Console]::ReadKey()

    $ProgressPreference = 'Continue'
}

if ($script:Params.ContainsKey("Sysprep")) {
    $defaultUserPath = GetUserDirectory -userName "Default"

    # Exit script if run in Sysprep mode on Windows 10
    if ($WinVersion -lt 22000) {
        Write-Error "Win11Debloat Sysprep mode is not supported on Windows 10"
        AwaitKeyToExit
    }
}

# Ensure that target user exists, if User or AppRemovalTarget parameter was provided
if ($script:Params.ContainsKey("User")) {
    $userPath = GetUserDirectory -userName $script:Params.Item("User")
}
if ($script:Params.ContainsKey("AppRemovalTarget")) {
    $userPath = GetUserDirectory -userName $script:Params.Item("AppRemovalTarget")
}

# Remove LastUsedSettings.json file if it exists and is empty
if ((Test-Path $script:SavedSettingsFilePath) -and ([String]::IsNullOrWhiteSpace((Get-content $script:SavedSettingsFilePath)))) {
    Remove-Item -Path $script:SavedSettingsFilePath -recurse
}

# Only run the app selection form if the 'RunAppsListGenerator' parameter was passed to the script
if ($RunAppsListGenerator) {
    PrintHeader "Custom Apps List Generator"

    $result = Show-AppSelectionWindow

    # Show different message based on whether the app selection was saved or cancelled
    if ($result -ne $true) {
        Write-Host "Application selection window was closed without saving." -ForegroundColor Red
    }
    else {
        Write-Output "Your app selection was saved to the 'CustomAppsList' file, found at:"
        Write-Host "$PSScriptRoot" -ForegroundColor Yellow
    }

    AwaitKeyToExit
}

# Change script execution based on provided parameters or user input
if ((-not $script:Params.Count) -or $RunDefaults -or $RunDefaultsLite -or $RunSavedSettings -or ($controlParamsCount -eq $script:Params.Count)) {
    if ($RunDefaults -or $RunDefaultsLite) {
        ShowCLIDefaultModeOptions
    }
    elseif ($RunSavedSettings) {
        if (-not (Test-Path $script:SavedSettingsFilePath)) {
            PrintHeader 'Custom Mode'
            Write-Error "Unable to find LastUsedSettings.json file, no changes were made"
            AwaitKeyToExit
        }

        ShowCLILastUsedSettings
    }
    else {
        if ($CLI) {
            $Mode = ShowCLIMenuOptions 
        }
        else {
            try {
                $result = Show-MainWindow
            
                Stop-Transcript
                Exit
            }
            catch {
                Write-Warning "Unable to load WPF GUI (not supported in this environment), falling back to CLI mode"
                if (-not $Silent) {
                    Write-Host ""
                    Write-Host "Press any key to continue..."
                    $null = [System.Console]::ReadKey()
                }

                $Mode = ShowCLIMenuOptions
            }
        }
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults and app removal options
        '1' { 
            ShowCLIDefaultModeOptions
        }

        # App removal, remove apps based on user selection
        '2' {
            ShowCLIAppRemoval
        }

        # Load last used options from the "LastUsedSettings.json" file
        '3' {
            ShowCLILastUsedSettings
        }
    }
}
else {
    PrintHeader 'Configuration'
}

# If the number of keys in ControlParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if (($controlParamsCount -eq $script:Params.Keys.Count) -or ($script:Params.Keys.Count -eq 1 -and ($script:Params.Keys -contains 'CreateRestorePoint' -or $script:Params.Keys -contains 'Apps'))) {
    Write-Output "The script completed without making any changes."
    AwaitKeyToExit
}

# Execute all selected/provided parameters using the consolidated function
# (This also handles restore point creation if requested)
ExecuteAllChanges

RestartExplorer

Write-Output ""
Write-Output ""
Write-Output ""
Write-Output "Script completed! Please check above for any errors."

AwaitKeyToExit
