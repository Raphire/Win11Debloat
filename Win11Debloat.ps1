#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$Silent,
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


# Show error if current powershell environment is limited by security policies
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Host "Error: Win11Debloat is unable to run on your system, powershell execution is restricted by security policies" -ForegroundColor Red
    AwaitKeyToExit
}

# Log script output to 'Win11Debloat.log' at the specified path
if ($LogPath -and (Test-Path $LogPath)) {
    Start-Transcript -Path "$LogPath/Win11Debloat.log" -Append -IncludeInvocationHeader -Force | Out-Null
}
else {
    Start-Transcript -Path "$PSScriptRoot/Win11Debloat.log" -Append -IncludeInvocationHeader -Force | Out-Null
}

# Shows application selection form that allows the user to select what apps they want to remove or keep
function ShowAppSelectionForm {
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
    [reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null

    # Initialise form objects
    $form = New-Object System.Windows.Forms.Form
    $label = New-Object System.Windows.Forms.Label
    $button1 = New-Object System.Windows.Forms.Button
    $button2 = New-Object System.Windows.Forms.Button
    $selectionBox = New-Object System.Windows.Forms.CheckedListBox 
    $loadingLabel = New-Object System.Windows.Forms.Label
    $onlyInstalledCheckBox = New-Object System.Windows.Forms.CheckBox
    $checkUncheckCheckBox = New-Object System.Windows.Forms.CheckBox
    $initialFormWindowState = New-Object System.Windows.Forms.FormWindowState

    $script:selectionBoxIndex = -1

    # saveButton eventHandler
    $handler_saveButton_Click= 
    {
        if ($selectionBox.CheckedItems -contains "Microsoft.WindowsStore" -and -not $Silent) {
            $warningSelection = [System.Windows.Forms.Messagebox]::Show('Are you sure you wish to uninstall the Microsoft Store? This app cannot easily be reinstalled.', 'Are you sure?', 'YesNo', 'Warning')
        
            if ($warningSelection -eq 'No') {
                return
            }
        }

        $script:SelectedApps = $selectionBox.CheckedItems

        # Create file that stores selected apps if it doesn't exist
        if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
            $null = New-Item "$PSScriptRoot/CustomAppsList"
        } 

        Set-Content -Path "$PSScriptRoot/CustomAppsList" -Value $script:SelectedApps

        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    }

    # cancelButton eventHandler
    $handler_cancelButton_Click= 
    {
        $form.Close()
    }

    $selectionBox_SelectedIndexChanged= 
    {
        $script:selectionBoxIndex = $selectionBox.SelectedIndex
    }

    $selectionBox_MouseDown=
    {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if ([System.Windows.Forms.Control]::ModifierKeys -eq [System.Windows.Forms.Keys]::Shift) {
                if ($script:selectionBoxIndex -ne -1) {
                    $topIndex = $script:selectionBoxIndex

                    if ($selectionBox.SelectedIndex -gt $topIndex) {
                        for (($i = ($topIndex)); $i -le $selectionBox.SelectedIndex; $i++) {
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                    elseif ($topIndex -gt $selectionBox.SelectedIndex) {
                        for (($i = ($selectionBox.SelectedIndex)); $i -le $topIndex; $i++) {
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                }
            }
            elseif ($script:selectionBoxIndex -ne $selectionBox.SelectedIndex) {
                $selectionBox.SetItemChecked($selectionBox.SelectedIndex, -not $selectionBox.GetItemChecked($selectionBox.SelectedIndex))
            }
        }
    }

    $check_All=
    {
        for (($i = 0); $i -lt $selectionBox.Items.Count; $i++) {
            $selectionBox.SetItemChecked($i, $checkUncheckCheckBox.Checked)
        }
    }

    $load_Apps=
    {
        # Correct the initial state of the form to prevent the .Net maximized form issue
        $form.WindowState = $initialFormWindowState

        # Reset state to default before loading appslist again
        $script:selectionBoxIndex = -1
        $checkUncheckCheckBox.Checked = $False

        # Show loading indicator
        $loadingLabel.Visible = $true
        $form.Refresh()

        # Clear selectionBox before adding any new items
        $selectionBox.Items.Clear()

        # Set filePath where Appslist can be found
        $appsFile = "$PSScriptRoot/Appslist.txt"
        $listOfApps = ""

        if ($onlyInstalledCheckBox.Checked -and ($script:wingetInstalled -eq $true)) {
            # Attempt to get a list of installed apps via winget, times out after 10 seconds
            $job = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
            $jobDone = $job | Wait-Job -TimeOut 10

            if (-not $jobDone) {
                # Show error that the script was unable to get list of apps from winget
                [System.Windows.MessageBox]::Show('Unable to load list of installed apps via winget, some apps may not be displayed in the list.', 'Error', 'Ok', 'Error')
            }
            else {
                # Add output of job (list of apps) to $listOfApps
                $listOfApps = Receive-Job -Job $job
            }
        }

        # Go through appslist and add items one by one to the selectionBox
        Foreach ($app in (Get-Content -Path $appsFile | Where-Object { $_ -notmatch '^\s*$' -and $_ -notmatch '^#  .*' -and $_ -notmatch '^# -* #' } )) { 
            $appChecked = $true

            # Remove first # if it exists and set appChecked to false
            if ($app.StartsWith('#')) {
                $app = $app.TrimStart("#")
                $appChecked = $false
            }

            # Remove any comments from the Appname
            if (-not ($app.IndexOf('#') -eq -1)) {
                $app = $app.Substring(0, $app.IndexOf('#'))
            }
            
            # Remove leading and trailing spaces and `*` characters from Appname
            $app = $app.Trim()
            $appString = $app.Trim('*')

            # Make sure appString is not empty
            if ($appString.length -gt 0) {
                if ($onlyInstalledCheckBox.Checked) {
                    # onlyInstalledCheckBox is checked, check if app is installed before adding it to selectionBox
                    if (-not ($listOfApps -like ("*$appString*")) -and -not (Get-AppxPackage -Name $app)) {
                        # App is not installed, continue with next item
                        continue
                    }
                    if (($appString -eq "Microsoft.Edge") -and -not ($listOfApps -like "* Microsoft.Edge *")) {
                        # App is not installed, continue with next item
                        continue
                    }
                }

                # Add the app to the selectionBox and set it's checked status
                $selectionBox.Items.Add($appString, $appChecked) | Out-Null
            }
        }
        
        # Hide loading indicator
        $loadingLabel.Visible = $False

        # Sort selectionBox alphabetically
        $selectionBox.Sorted = $True
    }

    $form.Text = "Win11Debloat Application Selection"
    $form.Name = "appSelectionForm"
    $form.DataBindings.DefaultDataSourceUpdateMode = 0
    $form.ClientSize = New-Object System.Drawing.Size(400,502)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $False

    $button1.TabIndex = 4
    $button1.Name = "saveButton"
    $button1.UseVisualStyleBackColor = $True
    $button1.Text = "Confirm"
    $button1.Location = New-Object System.Drawing.Point(27,472)
    $button1.Size = New-Object System.Drawing.Size(75,23)
    $button1.DataBindings.DefaultDataSourceUpdateMode = 0
    $button1.add_Click($handler_saveButton_Click)

    $form.Controls.Add($button1)

    $button2.TabIndex = 5
    $button2.Name = "cancelButton"
    $button2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $button2.UseVisualStyleBackColor = $True
    $button2.Text = "Cancel"
    $button2.Location = New-Object System.Drawing.Point(129,472)
    $button2.Size = New-Object System.Drawing.Size(75,23)
    $button2.DataBindings.DefaultDataSourceUpdateMode = 0
    $button2.add_Click($handler_cancelButton_Click)

    $form.Controls.Add($button2)

    $label.Location = New-Object System.Drawing.Point(13,5)
    $label.Size = New-Object System.Drawing.Size(400,14)
    $Label.Font = 'Microsoft Sans Serif,8'
    $label.Text = 'Check apps that you wish to remove, uncheck apps that you wish to keep'

    $form.Controls.Add($label)

    $loadingLabel.Location = New-Object System.Drawing.Point(16,46)
    $loadingLabel.Size = New-Object System.Drawing.Size(300,418)
    $loadingLabel.Text = 'Loading apps...'
    $loadingLabel.BackColor = "White"
    $loadingLabel.Visible = $false

    $form.Controls.Add($loadingLabel)

    $onlyInstalledCheckBox.TabIndex = 6
    $onlyInstalledCheckBox.Location = New-Object System.Drawing.Point(230,474)
    $onlyInstalledCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $onlyInstalledCheckBox.Text = 'Only show installed apps'
    $onlyInstalledCheckBox.add_CheckedChanged($load_Apps)

    $form.Controls.Add($onlyInstalledCheckBox)

    $checkUncheckCheckBox.TabIndex = 7
    $checkUncheckCheckBox.Location = New-Object System.Drawing.Point(16,22)
    $checkUncheckCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $checkUncheckCheckBox.Text = 'Check/Uncheck all'
    $checkUncheckCheckBox.add_CheckedChanged($check_All)

    $form.Controls.Add($checkUncheckCheckBox)

    $selectionBox.FormattingEnabled = $True
    $selectionBox.DataBindings.DefaultDataSourceUpdateMode = 0
    $selectionBox.Name = "selectionBox"
    $selectionBox.Location = New-Object System.Drawing.Point(13,43)
    $selectionBox.Size = New-Object System.Drawing.Size(374,424)
    $selectionBox.TabIndex = 3
    $selectionBox.add_SelectedIndexChanged($selectionBox_SelectedIndexChanged)
    $selectionBox.add_Click($selectionBox_MouseDown)

    $form.Controls.Add($selectionBox)

    # Save the initial state of the form
    $initialFormWindowState = $form.WindowState

    # Load apps into selectionBox
    $form.add_Load($load_Apps)

    # Focus selectionBox when form opens
    $form.Add_Shown({$form.Activate(); $selectionBox.Focus()})

    # Show the Form
    return $form.ShowDialog()
}


# Returns list of apps from the specified file, it trims the app names and removes any comments
function ReadAppslistFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    # Get list of apps from file at the path provided, and remove them one by one
    Foreach ($app in (Get-Content -Path $appsFilePath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) { 
        # Remove any comments from the Appname
        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }

        # Remove any spaces before and after the Appname
        $app = $app.Trim()
        
        $appString = $app.Trim('*')
        $appsList += $appString
    }

    return $appsList
}


# Removes apps specified during function call from all user accounts and from the OS image.
function RemoveApps {
    param (
        $appslist
    )

    Foreach ($app in $appsList) { 
        Write-Output "Attempting to remove $app..."

        if (($app -eq "Microsoft.OneDrive") -or ($app -eq "Microsoft.Edge")) {
            # Use winget to remove OneDrive and Edge
            if ($script:wingetInstalled -eq $false) {
                Write-Host "Error: WinGet is either not installed or is outdated, $app could not be removed" -ForegroundColor Red
            }
            else {
                # Uninstall app via winget
                Strip-Progress -ScriptBlock { winget uninstall --accept-source-agreements --disable-interactivity --id $app } | Tee-Object -Variable wingetOutput 

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "Uninstall failed with exit code")) {
                    Write-Host "Unable to uninstall Microsoft Edge via Winget" -ForegroundColor Red
                    Write-Output ""

                    if ($( Read-Host -Prompt "Would you like to forcefully uninstall Edge? NOT RECOMMENDED! (y/n)" ) -eq 'y') {
                        Write-Output ""
                        ForceRemoveEdge
                    }
                }
            }
        }
        else {
            # Use Remove-AppxPackage to remove all other apps
            $app = '*' + $app + '*'

            # Remove installed app for all existing users
            if ($WinVersion -ge 22000) {
                # Windows 11 build 22000 or later
                try {
                    Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue

                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "Removed $app for all users" -ForegroundColor DarkGray
                    }
                }
                catch {
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "Unable to remove $app for all users" -ForegroundColor Yellow
                        Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                    }
                }
            }
            else {
                # Windows 10
                try {
                    Get-AppxPackage -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue
                    
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "Removed $app for current user" -ForegroundColor DarkGray
                    }
                }
                catch {
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "Unable to remove $app for current user" -ForegroundColor Yellow
                        Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                    }
                }
                
                try {
                    Get-AppxPackage -Name $app -PackageTypeFilter Main, Bundle, Resource -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "Removed $app for all users" -ForegroundColor DarkGray
                    }
                }
                catch {
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "Unable to remove $app for all users" -ForegroundColor Yellow
                        Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                    }
                }
            }

            # Remove provisioned app from OS image, so the app won't be installed for any new users
            try {
                Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
            }
            catch {
                Write-Host "Unable to remove $app from windows image" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }
    }
            
    Write-Output ""
}


# Forcefully removes Microsoft Edge using it's uninstaller
function ForceRemoveEdge {
    # Based on work from loadstring1 & ave9858
    Write-Output "> Forcefully uninstalling Microsoft Edge..."

    $regView = [Microsoft.Win32.RegistryView]::Registry32
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)
    $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev').SetValue('AllowUninstall', '')

    # Create stub (Creating this somehow allows uninstalling Edge)
    $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    New-Item $edgeStub -ItemType Directory | Out-Null
    New-Item "$edgeStub\MicrosoftEdge.exe" | Out-Null

    # Remove edge
    $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
    if ($null -ne $uninstallRegKey) {
        Write-Output "Running uninstaller..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-Output "Removing leftover files..."

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
                Write-Host "  Removed $path" -ForegroundColor DarkGray
            }
        }

        Write-Output "Cleaning up registry..."

        # Remove MS Edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-Output "Microsoft Edge was uninstalled"
    }
    else {
        Write-Output ""
        Write-Host "Error: Unable to forcefully uninstall Microsoft Edge, uninstaller could not be found" -ForegroundColor Red
    }
    
    Write-Output ""
}


# Execute provided command and strips progress spinners/bars from console output
function Strip-Progress {
    param(
        [ScriptBlock]$ScriptBlock
    )

    # Regex pattern to match spinner characters and progress bar patterns
    $progressPattern = 'Γû[Æê]|^\s+[-\\|/]\s+$'

    # Corrected regex pattern for size formatting, ensuring proper capture groups are utilized
    $sizePattern = '(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB) /\s+(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)'

    & $ScriptBlock 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "ERROR: $($_.Exception.Message)"
        } else {
            $line = $_ -replace $progressPattern, '' -replace $sizePattern, ''
            if (-not ([string]::IsNullOrWhiteSpace($line)) -and -not ($line.StartsWith('  '))) {
                $line
            }
        }
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


# Returns the directory path of the specified user, exits script if user path can't be found
function GetUserDirectory {
    param (
        $userName,
        $fileName = "",
        $exitIfPathNotFound = $true
    )

    $userDirectoryExists = Test-Path "$env:SystemDrive\Users\$userName"
    $userPath = "$env:SystemDrive\Users\$userName\$fileName"

    if ((Test-Path $userPath) -or ($userDirectoryExists -and (-not $exitIfPathNotFound))) {
        return $userPath
    }

    $userDirectoryExists = Test-Path $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName"
    $userPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$userName\$fileName"

    if ((Test-Path $userPath) -or ($userDirectoryExists -and (-not $exitIfPathNotFound))) {
        return $userPath
    }

    Write-Host "Error: Unable to find user directory path for user $userName" -ForegroundColor Red
    AwaitKeyToExit
}


# Import & execute regfile
function RegImport {
    param (
        $message,
        $path
    )

    Write-Output $message

    if ($script:Params.ContainsKey("Sysprep")) {
        $defaultUserPath = GetUserDirectory -userName "Default" -fileName "NTUSER.DAT"
        
        reg load "HKU\Default" $defaultUserPath | Out-Null
        reg import "$PSScriptRoot\Regfiles\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null
    }
    elseif ($script:Params.ContainsKey("User")) {
        $userPath = GetUserDirectory -userName $script:Params.Item("User") -fileName "NTUSER.DAT"
        
        reg load "HKU\Default" $userPath | Out-Null
        reg import "$PSScriptRoot\Regfiles\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null
        
    }
    else {
        reg import "$PSScriptRoot\Regfiles\$path"  
    }

    Write-Output ""
}


# Restart the Windows Explorer process
function RestartExplorer {
    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")) {
        return
    }

    Write-Output "> Restarting Windows Explorer process to apply all changes... (This may cause some flickering)"

    if ($script:Params.ContainsKey("DisableMouseAcceleration")) {
        Write-Host "Warning: The Enhance Pointer Precision setting changes will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableStickyKeys")) {
        Write-Host "Warning: The Sticky Keys setting changes will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableAnimations")) {
        Write-Host "Warning: Animations will only be disabled after a reboot" -ForegroundColor Yellow
    }

    # Only restart if the powershell process matches the OS architecture.
    # Restarting explorer from a 32bit PowerShell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem) {
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Warning "Unable to restart Windows Explorer process, please manually reboot your PC to apply all changes."
    }
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$PSScriptRoot/Assets/Start/start2.bin"
    )

    Write-Output "> Removing all pinned apps from the start menu for all users..."

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Error: Unable to clear start menu, start2.bin file missing from script folder" -ForegroundColor Red
        Write-Output ""
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
        Write-Output "Created LocalState folder for default user profile"
    }

    # Copy template to default profile
    Copy-Item -Path $startMenuTemplate -Destination $defaultStartMenuPath -Force
    Write-Output "Replaced start menu for the default user profile"
    Write-Output ""
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenu {
    param (
        $startMenuTemplate = "$PSScriptRoot/Assets/Start/start2.bin",
        $startMenuBinFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
    )

    # Change path to correct user if a user was specified
    if ($script:Params.ContainsKey("User")) {
        $startMenuBinFile = GetUserDirectory -userName "$(GetUserName)" -fileName "AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
    }

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "Error: Unable to replace start menu, template file not found" -ForegroundColor Red
        return
    }

    if ([IO.Path]::GetExtension($startMenuTemplate) -ne ".bin" ) {
        Write-Host "Error: Unable to replace start menu, template file is not a valid .bin file" -ForegroundColor Red
        return
    }

    $userName = [regex]::Match($startMenuBinFile, '(?:Users\\)([^\\]+)(?:\\AppData)').Groups[1].Value

    # Check if bin file exists, return early if it doesn't
    if (-not (Test-Path $startMenuBinFile)) {
        Write-Host "Error: Unable to replace start menu for user $userName, original start2.bin file not found" -ForegroundColor Red
        return
    }

    $backupBinFile = $startMenuBinFile + ".bak"

    # Backup current start menu file
    Move-Item -Path $startMenuBinFile -Destination $backupBinFile -Force

    # Copy template file
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-Output "Replaced start menu for user $userName"
}


# Add parameter to script and write to file
function AddParameter {
    param (
        $parameterName,
        $message
    )

    # Add key if it doesn't already exist
    if (-not $script:Params.ContainsKey($parameterName)) {
        $script:Params.Add($parameterName, $true)
    }

    # Create or clear file that stores last used settings
    if (-not (Test-Path "$PSScriptRoot/SavedSettings")) {
        $null = New-Item "$PSScriptRoot/SavedSettings"
    } 
    elseif ($script:FirstSelection) {
        $null = Clear-Content "$PSScriptRoot/SavedSettings"
    }
    
    $script:FirstSelection = $false

    # Create entry and add it to the file
    $entry = "$parameterName#- $message"
    Add-Content -Path "$PSScriptRoot/SavedSettings" -Value $entry
}


function PrintHeader {
    param (
        $title
    )

    $fullTitle = " Win11Debloat Script - $title"

    if ($script:Params.ContainsKey("Sysprep")) {
        $fullTitle = "$fullTitle (Sysprep mode)"
    }
    else {
        $fullTitle = "$fullTitle (User: $(GetUserName))"
    }

    Clear-Host
    Write-Output "-------------------------------------------------------------------------------------------"
    Write-Output $fullTitle
    Write-Output "-------------------------------------------------------------------------------------------"
}


function PrintFromFile {
    param (
        $path,
        $title
    )

    Clear-Host

    PrintHeader $title

    # Get & print script menu from file
    Foreach ($line in (Get-Content -Path $path )) {   
        Write-Output $line
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


function GetUserName {
    if ($script:Params.ContainsKey("User")) { 
        return $script:Params.Item("User") 
    }
    
    return $env:USERNAME
}


function CreateSystemRestorePoint {
    Write-Output "> Attempting to create a system restore point..."
    
    $SysRestore = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval"

    if ($SysRestore.RPSessionInterval -eq 0) {
        if ($Silent -or $( Read-Host -Prompt "System restore is disabled, would you like to enable it and create a restore point? (y/n)") -eq 'y') {
            $enableSystemRestoreJob = Start-Job { 
                try {
                    Enable-ComputerRestore -Drive "$env:SystemDrive"
                } catch {
                    Write-Host "Error: Failed to enable System Restore: $_" -ForegroundColor Red
                    Write-Output ""
                    return
                }
            }
    
            $enableSystemRestoreJobDone = $enableSystemRestoreJob | Wait-Job -TimeOut 20

            if (-not $enableSystemRestoreJobDone) {
                Write-Host "Error: Failed to enable system restore and create restore point, operation timed out" -ForegroundColor Red
                Write-Output ""
                Write-Output "Press any key to continue anyway..."
                $null = [System.Console]::ReadKey()
                return
            } else {
                Receive-Job $enableSystemRestoreJob
            }
        } else {
            Write-Output ""
            return
        }
    }

    $createRestorePointJob = Start-Job { 
        # Find existing restore points that are less than 24 hours old
        try {
            $recentRestorePoints = Get-ComputerRestorePoint | Where-Object { (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24) }
        } catch {
            Write-Host "Error: Unable to retrieve existing restore points: $_" -ForegroundColor Red
            Write-Output ""
            return
        }
    
        if ($recentRestorePoints.Count -eq 0) {
            try {
                Checkpoint-Computer -Description "Restore point created by Win11Debloat" -RestorePointType "MODIFY_SETTINGS"
                Write-Output "System restore point created successfully"
            } catch {
                Write-Host "Error: Unable to create restore point: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "A recent restore point already exists, no new restore point was created." -ForegroundColor Yellow
        }
    }
    
    $createRestorePointJobDone = $createRestorePointJob | Wait-Job -TimeOut 20

    if (-not $createRestorePointJobDone) {
        Write-Host "Error: Failed to create system restore point, operation timed out" -ForegroundColor Red
        Write-Output ""
        Write-Output "Press any key to continue anyway..."
        $null = [System.Console]::ReadKey()
    } else {
        Receive-Job $createRestorePointJob
    }

    Write-Output ""
}


function DisplayCustomModeOptions {
    # Get current Windows build version to compare against features
    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
            
    PrintHeader 'Custom Mode'

    AddParameter 'CreateRestorePoint' 'Create a system restore point'

    # Show options for removing apps, only continue on valid input
    Do {
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host " (n) Don't remove any apps" -ForegroundColor Yellow
        Write-Host " (1) Only remove the default selection of bloatware apps from 'Appslist.txt'" -ForegroundColor Yellow
        Write-Host " (2) Remove default selection of bloatware apps, as well as mail & calendar apps, developer apps and gaming apps"  -ForegroundColor Yellow
        Write-Host " (3) Manually select which apps to remove" -ForegroundColor Yellow
        $RemoveAppsInput = Read-Host "Do you want to remove any apps? Apps will be removed for all users (n/1/2/3)"

        # Show app selection form if user entered option 3
        if ($RemoveAppsInput -eq '3') {
            $result = ShowAppSelectionForm

            if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
                # User cancelled or closed app selection, show error and change RemoveAppsInput so the menu will be shown again
                Write-Output ""
                Write-Host "Cancelled application selection, please try again" -ForegroundColor Red

                $RemoveAppsInput = 'c'
            }
            
            Write-Output ""
        }
    }
    while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2' -and $RemoveAppsInput -ne '3') 

    # Select correct option based on user input
    switch ($RemoveAppsInput) {
        '1' {
            AddParameter 'RemoveApps' 'Remove default selection of bloatware apps'
        }
        '2' {
            AddParameter 'RemoveApps' 'Remove default selection of bloatware apps'
            AddParameter 'RemoveCommApps' 'Remove the Mail, Calendar, and People apps'
            AddParameter 'RemoveW11Outlook' 'Remove the new Outlook for Windows app'
            AddParameter 'RemoveDevApps' 'Remove developer-related apps'
            AddParameter 'RemoveGamingApps' 'Remove the Xbox App and Xbox Gamebar'
            AddParameter 'DisableDVR' 'Disable Xbox game/screen recording'
        }
        '3' {
            Write-Output "You have selected $($script:SelectedApps.Count) apps for removal"

            AddParameter 'RemoveAppsCustom' "Remove $($script:SelectedApps.Count) apps:"

            Write-Output ""

            if ($( Read-Host -Prompt "Disable Xbox game/screen recording? This also stops gaming overlay popups (y/n)" ) -eq 'y') {
                AddParameter 'DisableDVR' 'Disable Xbox game/screen recording'
            }
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable telemetry, diagnostic data, activity history, app-launch tracking and targeted ads? (y/n)" ) -eq 'y') {
        AddParameter 'DisableTelemetry' 'Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable tips, tricks, suggestions and ads in start, settings, notifications, explorer, lockscreen and Edge? (y/n)" ) -eq 'y') {
        AddParameter 'DisableSuggestions' 'Disable tips, tricks, suggestions and ads in start, settings, notifications and File Explorer'
        AddParameter 'DisableEdgeAds' 'Disable ads, suggestions and the MSN news feed in Microsoft Edge'
        AddParameter 'DisableSettings365Ads' 'Disable Microsoft 365 ads in Settings Home'
        AddParameter 'DisableLockscreenTips' 'Disable tips & tricks on the lockscreen'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable & remove Bing web search, Bing AI and Cortana from Windows search? (y/n)" ) -eq 'y') {
        AddParameter 'DisableBing' 'Disable & remove Bing web search, Bing AI and Cortana from Windows search'
    }

    # Only show this option for Windows 11 users running build 22621 or later
    if ($WinVersion -ge 22621) {
        Write-Output ""

        # Show options for disabling/removing AI features, only continue on valid input
        Do {
            Write-Host "Options:" -ForegroundColor Yellow
            Write-Host " (n) Don't disable any AI features" -ForegroundColor Yellow
            Write-Host " (1) Disable Microsoft Copilot and Windows Recall snapshots" -ForegroundColor Yellow
            Write-Host " (2) Disable Microsoft Copilot, Windows Recall snapshots and AI features in Microsoft Edge, Paint and Notepad"  -ForegroundColor Yellow
            $DisableAIInput = Read-Host "Do you want to disable any AI features? This applies to all users (n/1/2)"
        }
        while ($DisableAIInput -ne 'n' -and $DisableAIInput -ne '0' -and $DisableAIInput -ne '1' -and $DisableAIInput -ne '2') 

        # Select correct option based on user input
        switch ($DisableAIInput) {
            '1' {
                AddParameter 'DisableCopilot' 'Disable & remove Microsoft Copilot'
                AddParameter 'DisableRecall' 'Disable Windows Recall snapshots'
            }
            '2' {
                AddParameter 'DisableCopilot' 'Disable & remove Microsoft Copilot'
                AddParameter 'DisableRecall' 'Disable Windows Recall snapshots'
                AddParameter 'DisableEdgeAI' 'Disable AI features in Edge'
                AddParameter 'DisablePaintAI' 'Disable AI features in Paint'
                AddParameter 'DisableNotepadAI' 'Disable AI features in Notepad'
            }
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable Windows Spotlight background on desktop? (y/n)" ) -eq 'y') {
        AddParameter 'DisableDesktopSpotlight' 'Disable the Windows Spotlight desktop background option.'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Enable dark mode for system and apps? (y/n)" ) -eq 'y') {
        AddParameter 'EnableDarkMode' 'Enable dark mode for system and apps'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable transparency, animations and visual effects? (y/n)" ) -eq 'y') {
        AddParameter 'DisableTransparency' 'Disable transparency effects'
        AddParameter 'DisableAnimations' 'Disable animations and visual effects'
    }

    # Only show this option for Windows 11 users running build 22000 or later
    if ($WinVersion -ge 22000) {
        Write-Output ""

        if ($( Read-Host -Prompt "Restore the old Windows 10 style context menu? (y/n)" ) -eq 'y') {
            AddParameter 'RevertContextMenu' 'Restore the old Windows 10 style context menu'
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Turn off Enhance Pointer Precision, also known as mouse acceleration? (y/n)" ) -eq 'y') {
        AddParameter 'DisableMouseAcceleration' 'Turn off Enhance Pointer Precision (mouse acceleration)'
    }

    # Only show this option for Windows 11 users running build 26100 or later
    if ($WinVersion -ge 26100) {
        Write-Output ""

        if ($( Read-Host -Prompt "Disable the Sticky Keys keyboard shortcut? (y/n)" ) -eq 'y') {
            AddParameter 'DisableStickyKeys' 'Disable the Sticky Keys keyboard shortcut'
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable Fast Start-up? This applies to all users (y/n)" ) -eq 'y') {
        AddParameter 'DisableFastStartup' 'Disable Fast Start-up'
    }

    # Only show this option for Windows 11 users running build 22000 or later, and if the machine has at least one battery
    if (($WinVersion -ge 22000) -and $script:ModernStandbySupported) {
        Write-Output ""

        if ($( Read-Host -Prompt "Disable network connectivity during Modern Standby? This applies to all users (y/n)" ) -eq 'y') {
            AddParameter 'DisableModernStandbyNetworking' 'Disable network connectivity during Modern Standby'
        }
    }

    # Only show option for disabling context menu items for Windows 10 users or if the user opted to restore the Windows 10 context menu
    if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -or $script:Params.ContainsKey('RevertContextMenu')) {
        Write-Output ""

        if ($( Read-Host -Prompt "Do you want to disable any context menu options? (y/n)" ) -eq 'y') {
            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the 'Include in library' option in the context menu? (y/n)" ) -eq 'y') {
                AddParameter 'HideIncludeInLibrary' "Hide the 'Include in library' option in the context menu"
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the 'Give access to' option in the context menu? (y/n)" ) -eq 'y') {
                AddParameter 'HideGiveAccessTo' "Hide the 'Give access to' option in the context menu"
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the 'Share' option in the context menu? (y/n)" ) -eq 'y') {
                AddParameter 'HideShare' "Hide the 'Share' option in the context menu"
            }
        }
    }

    # Only show this option for Windows 11 users running build 22621 or later
    if ($WinVersion -ge 22621) {
        Write-Output ""

        if ($( Read-Host -Prompt "Do you want to make any changes to the start menu? (y/n)" ) -eq 'y') {
            Write-Output ""

            if ($script:Params.ContainsKey("Sysprep")) {
                if ($( Read-Host -Prompt "Remove all pinned apps from the start menu for all existing and new users? (y/n)" ) -eq 'y') {
                    AddParameter 'ClearStartAllUsers' 'Remove all pinned apps from the start menu for existing and new users'
                }
            }
            else {
                Do {
                    Write-Host "   Options:" -ForegroundColor Yellow
                    Write-Host "    (n) Don't remove any pinned apps from the start menu" -ForegroundColor Yellow
                    Write-Host "    (1) Remove all pinned apps from the start menu for this user only ($(GetUserName))" -ForegroundColor Yellow
                    Write-Host "    (2) Remove all pinned apps from the start menu for all existing and new users"  -ForegroundColor Yellow
                    $ClearStartInput = Read-Host "   Remove all pinned apps from the start menu? (n/1/2)" 
                }
                while ($ClearStartInput -ne 'n' -and $ClearStartInput -ne '0' -and $ClearStartInput -ne '1' -and $ClearStartInput -ne '2') 

                # Select correct option based on user input
                switch ($ClearStartInput) {
                    '1' {
                        AddParameter 'ClearStart' "Remove all pinned apps from the start menu for this user only"
                    }
                    '2' {
                        AddParameter 'ClearStartAllUsers' "Remove all pinned apps from the start menu for all existing and new users"
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Disable the recommended section in the start menu? This applies to all users (y/n)" ) -eq 'y') {
                AddParameter 'DisableStartRecommended' 'Disable the recommended section in the start menu.'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Disable the Phone Link mobile devices integration in the start menu? (y/n)" ) -eq 'y') {
                AddParameter 'DisableStartPhoneLink' 'Disable the Phone Link mobile devices integration in the start menu.'
            }
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Do you want to make any changes to the taskbar and related services? (y/n)" ) -eq 'y') {
        # Only show these specific options for Windows 11 users running build 22000 or later
        if ($WinVersion -ge 22000) {
            Write-Output ""

            if ($( Read-Host -Prompt "   Align taskbar buttons to the left side? (y/n)" ) -eq 'y') {
                AddParameter 'TaskbarAlignLeft' 'Align taskbar icons to the left'
            }

            # Show options for search icon on taskbar, only continue on valid input
            Do {
                Write-Output ""
                Write-Host "   Options:" -ForegroundColor Yellow
                Write-Host "    (n) No change" -ForegroundColor Yellow
                Write-Host "    (1) Hide search icon from the taskbar" -ForegroundColor Yellow
                Write-Host "    (2) Show search icon on the taskbar" -ForegroundColor Yellow
                Write-Host "    (3) Show search icon with label on the taskbar" -ForegroundColor Yellow
                Write-Host "    (4) Show search box on the taskbar" -ForegroundColor Yellow
                $TbSearchInput = Read-Host "   Hide or change the search icon on the taskbar? (n/1/2/3/4)" 
            }
            while ($TbSearchInput -ne 'n' -and $TbSearchInput -ne '0' -and $TbSearchInput -ne '1' -and $TbSearchInput -ne '2' -and $TbSearchInput -ne '3' -and $TbSearchInput -ne '4') 

            # Select correct taskbar search option based on user input
            switch ($TbSearchInput) {
                '1' {
                    AddParameter 'HideSearchTb' 'Hide search icon from the taskbar'
                }
                '2' {
                    AddParameter 'ShowSearchIconTb' 'Show search icon on the taskbar'
                }
                '3' {
                    AddParameter 'ShowSearchLabelTb' 'Show search icon with label on the taskbar'
                }
                '4' {
                    AddParameter 'ShowSearchBoxTb' 'Show search box on the taskbar'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the taskview button from the taskbar? (y/n)" ) -eq 'y') {
                AddParameter 'HideTaskview' 'Hide the taskview button from the taskbar'
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "   Disable the widgets service to remove widgets on the taskbar & lockscreen? (y/n)" ) -eq 'y') {
            AddParameter 'DisableWidgets' 'Disable widgets on the taskbar & lockscreen'
        }

        # Only show this options for Windows users running build 22621 or earlier
        if ($WinVersion -le 22621) {
            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the chat (meet now) icon from the taskbar? (y/n)" ) -eq 'y') {
                AddParameter 'HideChat' 'Hide the chat (meet now) icon from the taskbar'
            }
        }
        
        # Only show this options for Windows users running build 22631 or later
        if ($WinVersion -ge 22631) {
            Write-Output ""

            if ($( Read-Host -Prompt "   Enable the 'End Task' option in the taskbar right click menu? (y/n)" ) -eq 'y') {
                AddParameter 'EnableEndTask' "Enable the 'End Task' option in the taskbar right click menu"
            }
        }
        
        Write-Output ""
        if ($( Read-Host -Prompt "   Enable the 'Last Active Click' behavior in the taskbar app area? (y/n)" ) -eq 'y') {
            AddParameter 'EnableLastActiveClick' "Enable the 'Last Active Click' behavior in the taskbar app area"
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Do you want to make any changes to File Explorer? (y/n)" ) -eq 'y') {
        # Show options for changing the File Explorer default location
        Do {
            Write-Output ""
            Write-Host "   Options:" -ForegroundColor Yellow
            Write-Host "    (n) No change" -ForegroundColor Yellow
            Write-Host "    (1) Open File Explorer to 'Home'" -ForegroundColor Yellow
            Write-Host "    (2) Open File Explorer to 'This PC'" -ForegroundColor Yellow
            Write-Host "    (3) Open File Explorer to 'Downloads'" -ForegroundColor Yellow
            Write-Host "    (4) Open File Explorer to 'OneDrive'" -ForegroundColor Yellow
            $ExplSearchInput = Read-Host "   Change the default location that File Explorer opens to? (n/1/2/3/4)" 
        }
        while ($ExplSearchInput -ne 'n' -and $ExplSearchInput -ne '0' -and $ExplSearchInput -ne '1' -and $ExplSearchInput -ne '2' -and $ExplSearchInput -ne '3' -and $ExplSearchInput -ne '4') 

        # Select correct taskbar search option based on user input
        switch ($ExplSearchInput) {
            '1' {
                AddParameter 'ExplorerToHome' "Change the default location that File Explorer opens to 'Home'"
            }
            '2' {
                AddParameter 'ExplorerToThisPC' "Change the default location that File Explorer opens to 'This PC'"
            }
            '3' {
                AddParameter 'ExplorerToDownloads' "Change the default location that File Explorer opens to 'Downloads'"
            }
            '4' {
                AddParameter 'ExplorerToOneDrive' "Change the default location that File Explorer opens to 'OneDrive'"
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "   Show hidden files, folders and drives? (y/n)" ) -eq 'y') {
            AddParameter 'ShowHiddenFolders' 'Show hidden files, folders and drives'
        }

        Write-Output ""

        if ($( Read-Host -Prompt "   Show file extensions for known file types? (y/n)" ) -eq 'y') {
            AddParameter 'ShowKnownFileExt' 'Show file extensions for known file types'
        }

        # Only show this option for Windows 11 users running build 22000 or later
        if ($WinVersion -ge 22000) {
            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the Home section from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                AddParameter 'HideHome' 'Hide the Home section from the File Explorer sidepanel'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the Gallery section from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                AddParameter 'HideGallery' 'Hide the Gallery section from the File Explorer sidepanel'
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "   Hide duplicate removable drive entries from the File Explorer sidepanel so they only show under This PC? (y/n)" ) -eq 'y') {
            AddParameter 'HideDupliDrive' 'Hide duplicate removable drive entries from the File Explorer sidepanel'
        }

        # Only show option for disabling these specific folders for Windows 10 users
        if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") {
            Write-Output ""

            if ($( Read-Host -Prompt "Do you want to hide any folders from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                Write-Output ""

                if ($( Read-Host -Prompt "   Hide the OneDrive folder from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                    AddParameter 'HideOnedrive' 'Hide the OneDrive folder in the File Explorer sidepanel'
                }

                Write-Output ""
                
                if ($( Read-Host -Prompt "   Hide the 3D objects folder from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                    AddParameter 'Hide3dObjects' "Hide the 3D objects folder under 'This pc' in File Explorer" 
                }
                
                Write-Output ""

                if ($( Read-Host -Prompt "   Hide the music folder from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                    AddParameter 'HideMusic' "Hide the music folder under 'This pc' in File Explorer"
                }
            }
        }
    }

    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output ""
        Write-Output ""
        Write-Output "Press enter to confirm your choices and execute the script or press CTRL+C to quit..."
        Read-Host | Out-Null
    }

    PrintHeader 'Custom Mode'
}



##################################################################################################################
#                                                                                                                #
#                                                  SCRIPT START                                                  #
#                                                                                                                #
##################################################################################################################



# Check if winget is installed & if it is, check if the version is at least v1.4
if ((Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*") -and ([int](((winget -v) -replace 'v','').split('.')[0..1] -join '') -gt 14)) {
    $script:wingetInstalled = $true
}
else {
    $script:wingetInstalled = $false

    # Show warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
    if (-not $Silent) {
        Write-Warning "Winget is not installed or outdated. This may prevent Win11Debloat from removing certain apps."
        Write-Output ""
        Write-Output "Press any key to continue anyway..."
        $null = [System.Console]::ReadKey()
    }
}

# Get current Windows build version to compare against features
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

# Check if the machine supports Modern Standby, this is used to determine if the DisableModernStandbyNetworking option can be used
$script:ModernStandbySupported = CheckModernStandbySupport

$script:Params = $PSBoundParameters
$script:FirstSelection = $true
$SPParams = 'WhatIf', 'Confirm', 'Verbose', 'Silent', 'Sysprep', 'Debug', 'User', 'CreateRestorePoint', 'LogPath'
$SPParamCount = 0

# Count how many SPParams exist within Params
# This is later used to check if any options were selected
foreach ($Param in $SPParams) {
    if ($script:Params.ContainsKey($Param)) {
        $SPParamCount++
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
        Write-Host "Error: Win11Debloat Sysprep mode is not supported on Windows 10" -ForegroundColor Red
        AwaitKeyToExit
    }
}

# Make sure all requirements for User mode are met, if User is specified
if ($script:Params.ContainsKey("User")) {
    $userPath = GetUserDirectory -userName $script:Params.Item("User")
}

# Remove SavedSettings file if it exists and is empty
if ((Test-Path "$PSScriptRoot/SavedSettings") -and ([String]::IsNullOrWhiteSpace((Get-content "$PSScriptRoot/SavedSettings")))) {
    Remove-Item -Path "$PSScriptRoot/SavedSettings" -recurse
}

# Only run the app selection form if the 'RunAppsListGenerator' parameter was passed to the script
if ($RunAppConfigurator -or $RunAppsListGenerator) {
    PrintHeader "Custom Apps List Generator"

    $result = ShowAppSelectionForm

    # Show different message based on whether the app selection was saved or cancelled
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "Application selection window was closed without saving." -ForegroundColor Red
    }
    else {
        Write-Output "Your app selection was saved to the 'CustomAppsList' file, found at:"
        Write-Host "$PSScriptRoot" -ForegroundColor Yellow
    }

    AwaitKeyToExit
}

# Change script execution based on provided parameters or user input
if ((-not $script:Params.Count) -or $RunDefaults -or $RunWin11Defaults -or $RunSavedSettings -or ($SPParamCount -eq $script:Params.Count)) {
    if ($RunDefaults -or $RunWin11Defaults) {
        $Mode = '1'
    }
    elseif ($RunSavedSettings) {
        if (-not (Test-Path "$PSScriptRoot/SavedSettings")) {
            PrintHeader 'Custom Mode'
            Write-Host "Error: No saved settings found, no changes were made" -ForegroundColor Red
            AwaitKeyToExit
        }

        $Mode = '4'
    }
    else {
        # Show menu and wait for user input, loops until valid input is provided
        Do { 
            $ModeSelectionMessage = "Please select an option (1/2/3/0)" 

            PrintHeader 'Menu'

            Write-Output "(1) Default mode: Quickly apply the recommended changes"
            Write-Output "(2) Custom mode: Manually select what changes to make"
            Write-Output "(3) App removal mode: Select & remove apps, without making other changes"

            # Only show this option if SavedSettings file exists
            if (Test-Path "$PSScriptRoot/SavedSettings") {
                Write-Output "(4) Apply saved custom settings from last time"
                
                $ModeSelectionMessage = "Please select an option (1/2/3/4/0)" 
            }

            Write-Output ""
            Write-Output "(0) Show more information"
            Write-Output ""
            Write-Output ""

            $Mode = Read-Host $ModeSelectionMessage

            if ($Mode -eq '0') {
                # Print information screen from file
                PrintFromFile "$PSScriptRoot/Assets/Menus/Info" "Information"

                Write-Output "Press any key to go back..."
                $null = [System.Console]::ReadKey()
            }
            elseif (($Mode -eq '4') -and -not (Test-Path "$PSScriptRoot/SavedSettings")) {
                $Mode = $null
            }
        }
        while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3' -and $Mode -ne '4') 
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults after confirmation
        '1' { 
            # Show the default settings with confirmation, unless Silent parameter was passed
            if (-not $Silent) {
                PrintFromFile "$PSScriptRoot/Assets/Menus/DefaultSettings" "Default Mode"

                Write-Output "Press enter to execute the script or press CTRL+C to quit..."
                Read-Host | Out-Null
            }

            $DefaultParameterNames = 'CreateRestorePoint','RemoveApps','DisableTelemetry','DisableBing','DisableLockscreenTips','DisableSuggestions','DisableEdgeAds','ShowKnownFileExt','DisableWidgets','HideChat','DisableCopilot','DisableFastStartup'

            PrintHeader 'Default Mode'

            # Add default parameters, if they don't already exist
            foreach ($ParameterName in $DefaultParameterNames) {
                if (-not $script:Params.ContainsKey($ParameterName)) {
                    $script:Params.Add($ParameterName, $true)
                }
            }

            # Only add this option for Windows 10 users, if it doesn't already exist
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -and (-not $script:Params.ContainsKey('Hide3dObjects'))) {
                $script:Params.Add('Hide3dObjects', $Hide3dObjects)
            }

            # Only add these options for Windows 11 users (build 22000+), if it doesn't already exist
            if ($WinVersion -ge 22000) {
                if ($script:ModernStandbySupported -and (-not $script:Params.ContainsKey('DisableModernStandbyNetworking'))) {
                    $script:Params.Add('DisableModernStandbyNetworking', $true)
                }

                if (-not $script:Params.ContainsKey('DisableRecall')) {
                    $script:Params.Add('DisableRecall', $true)
                }
            } 
        }

        # Custom mode, show & add options based on user input
        '2' { 
            DisplayCustomModeOptions
        }

        # App removal, remove apps based on user selection
        '3' {
            PrintHeader "App Removal"

            $result = ShowAppSelectionForm

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                Write-Output "You have selected $($script:SelectedApps.Count) apps for removal"
                AddParameter 'RemoveAppsCustom' "Remove $($script:SelectedApps.Count) apps:"

                # Suppress prompt if Silent parameter was passed
                if (-not $Silent) {
                    Write-Output ""
                    Write-Output ""
                    Write-Output "Press enter to remove the selected apps or press CTRL+C to quit..."
                    Read-Host | Out-Null
                    PrintHeader "App Removal"
                }
            }
            else {
                Write-Host "Selection was cancelled, no apps have been removed" -ForegroundColor Red
                Write-Output ""
            }
        }

        # Load custom options from the "SavedSettings" file
        '4' {
            PrintHeader 'Custom Mode'
            Write-Output "Win11Debloat will make the following changes:"

            # Print the saved settings info from file
            Foreach ($line in (Get-Content -Path "$PSScriptRoot/SavedSettings" )) { 
                # Remove any spaces before and after the line
                $line = $line.Trim()
            
                # Check if the line contains a comment
                if (-not ($line.IndexOf('#') -eq -1)) {
                    $parameterName = $line.Substring(0, $line.IndexOf('#'))

                    # Print parameter description and add parameter to Params list
                    if ($parameterName -eq "RemoveAppsCustom") {
                        if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
                            # Apps file does not exist, skip
                            continue
                        }
                        
                        $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
                        Write-Output "- Remove $($appsList.Count) apps:"
                        Write-Host $appsList -ForegroundColor DarkGray
                    }
                    else {
                        Write-Output $line.Substring(($line.IndexOf('#') + 1), ($line.Length - $line.IndexOf('#') - 1))
                    }

                    if (-not $script:Params.ContainsKey($parameterName)) {
                        $script:Params.Add($parameterName, $true)
                    }
                }
            }

            if (-not $Silent) {
                Write-Output ""
                Write-Output ""
                Write-Output "Press enter to execute the script or press CTRL+C to quit..."
                Read-Host | Out-Null
            }

            PrintHeader 'Custom Mode'
        }
    }
}
else {
    PrintHeader 'Custom Mode'
}

# If the number of keys in SPParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if ($SPParamCount -eq $script:Params.Keys.Count) {
    Write-Output "The script completed without making any changes."

    AwaitKeyToExit
}

# Execute all selected/provided parameters
switch ($script:Params.Keys) {
    'CreateRestorePoint' {
        CreateSystemRestorePoint
        continue
    }
    'RemoveApps' {
        $appsList = ReadAppslistFromFile "$PSScriptRoot/Appslist.txt" 
        Write-Output "> Removing default selection of $($appsList.Count) apps..."
        RemoveApps $appsList
        continue
    }
    'RemoveAppsCustom' {
        if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
            Write-Host "> Error: Could not load custom apps list from file, no apps were removed" -ForegroundColor Red
            Write-Output ""
            continue
        }
        
        $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
        Write-Output "> Removing $($appsList.Count) apps..."
        RemoveApps $appsList
        continue
    }
    'RemoveCommApps' {
        $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
        Write-Output "> Removing Mail, Calendar and People apps..."
        RemoveApps $appsList
        continue
    }
    'RemoveW11Outlook' {
        $appsList = 'Microsoft.OutlookForWindows'
        Write-Output "> Removing new Outlook for Windows app..."
        RemoveApps $appsList
        continue
    }
    'RemoveDevApps' {
        $appsList = 'Microsoft.PowerAutomateDesktop', 'Microsoft.RemoteDesktop', 'Windows.DevHome'
        Write-Output "> Removing developer-related related apps..."
        RemoveApps $appsList
        continue
    }
    'RemoveGamingApps' {
        $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
        Write-Output "> Removing gaming related apps..."
        RemoveApps $appsList
        continue
    }
    'RemoveHPApps' {
        $appsList = 'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl'
        Write-Output "> Removing HP apps..."
        RemoveApps $appsList
        continue
    }
    "ForceRemoveEdge" {
        ForceRemoveEdge
        continue
    }
    'DisableDVR' {
        RegImport "> Disabling Xbox game/screen recording..." "Disable_DVR.reg"
        continue
    }
    'DisableTelemetry' {
        RegImport "> Disabling telemetry, diagnostic data, activity history, app-launch tracking and targeted ads..." "Disable_Telemetry.reg"
        continue
    }
    {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
        RegImport "> Disabling tips, tricks, suggestions and ads across Windows..." "Disable_Windows_Suggestions.reg"
        continue
    }
    'DisableEdgeAds' {
        RegImport "> Disabling ads, suggestions and the MSN news feed in Microsoft Edge..." "Disable_Edge_Ads_And_Suggestions.reg"
        continue
    }
    {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
        RegImport "> Disabling tips & tricks on the lockscreen..." "Disable_Lockscreen_Tips.reg"
        continue
    }
    'DisableDesktopSpotlight' {
        RegImport "> Disabling the 'Windows Spotlight' desktop background option..." "Disable_Desktop_Spotlight.reg"
        continue
    }
    'DisableSettings365Ads' {
        RegImport "> Disabling Microsoft 365 ads in Settings Home..." "Disable_Settings_365_Ads.reg"
        continue
    }
    'DisableSettingsHome' {
        RegImport "> Disabling the Settings Home page..." "Disable_Settings_Home.reg"
        continue
    }
    {$_ -in "DisableBingSearches", "DisableBing"} {
        RegImport "> Disabling Bing web search, Bing AI and Cortana from Windows search..." "Disable_Bing_Cortana_In_Search.reg"
        
        # Also remove the app package for Bing search
        $appsList = 'Microsoft.BingSearch'
        RemoveApps $appsList
        continue
    }
    'DisableCopilot' {
        RegImport "> Disabling Microsoft Copilot..." "Disable_Copilot.reg"

        # Also remove the app package for Copilot
        $appsList = 'Microsoft.Copilot'
        RemoveApps $appsList
        continue
    }
    'DisableRecall' {
        RegImport "> Disabling Windows Recall snapshots..." "Disable_AI_Recall.reg"
        continue
    }
    'DisableEdgeAI' {
        RegImport "> Disabling AI features in Microsoft Edge..." "Disable_Edge_AI_Features.reg"
        continue
    }
    'DisablePaintAI' {
        RegImport "> Disabling AI features in Paint..." "Disable_Paint_AI_Features.reg"
        continue
    }
    'DisableNotepadAI' {
        RegImport "> Disabling AI features in Notepad..." "Disable_Notepad_AI_Features.reg"
        continue
    }
    'RevertContextMenu' {
        RegImport "> Restoring the old Windows 10 style context menu..." "Disable_Show_More_Options_Context_Menu.reg"
        continue
    }
    'DisableMouseAcceleration' {
        RegImport "> Turning off Enhanced Pointer Precision..." "Disable_Enhance_Pointer_Precision.reg"
        continue
    }
    'DisableStickyKeys' {
        RegImport "> Disabling the Sticky Keys keyboard shortcut..." "Disable_Sticky_Keys_Shortcut.reg"
        continue
    }
    'DisableFastStartup' {
        RegImport "> Disabling Fast Start-up..." "Disable_Fast_Startup.reg"
        continue
    }
    'DisableModernStandbyNetworking' {
        RegImport "> Disabling network connectivity during Modern Standby..." "Disable_Modern_Standby_Networking.reg"
        continue
    }
    'ClearStart' {
        Write-Output "> Removing all pinned apps from the start menu for user $(GetUserName)..."
        ReplaceStartMenu
        Write-Output ""
        continue
    }
    'ReplaceStart' {
        Write-Output "> Replacing the start menu for user $(GetUserName)..."
        ReplaceStartMenu $script:Params.Item("ReplaceStart")
        Write-Output ""
        continue
    }
    'ClearStartAllUsers' {
        ReplaceStartMenuForAllUsers
        continue
    }
    'ReplaceStartAllUsers' {
        ReplaceStartMenuForAllUsers $script:Params.Item("ReplaceStartAllUsers")
        continue
    }
    'DisableStartRecommended' {
        RegImport "> Disabling the start menu recommended section..." "Disable_Start_Recommended.reg"
        continue
    }
    'DisableStartPhoneLink' {
        RegImport "> Disabling the Phone Link mobile devices integration in the start menu..." "Disable_Phone_Link_In_Start.reg"
        continue
    }
    'EnableDarkMode' {
        RegImport "> Enabling dark mode for system and apps..." "Enable_Dark_Mode.reg"
        continue
    }
    'DisableTransparency' {
        RegImport "> Disabling transparency effects..." "Disable_Transparency.reg"
        continue
    }
    'DisableAnimations' {
        RegImport "> Disabling animations and visual effects..." "Disable_Animations.reg"
        continue
    }
    'TaskbarAlignLeft' {
        RegImport "> Aligning taskbar buttons to the left..." "Align_Taskbar_Left.reg"
        continue
    }
    'HideSearchTb' {
        RegImport "> Hiding the search icon from the taskbar..." "Hide_Search_Taskbar.reg"
        continue
    }
    'ShowSearchIconTb' {
        RegImport "> Changing taskbar search to icon only..." "Show_Search_Icon.reg"
        continue
    }
    'ShowSearchLabelTb' {
        RegImport "> Changing taskbar search to icon with label..." "Show_Search_Icon_And_Label.reg"
        continue
    }
    'ShowSearchBoxTb' {
        RegImport "> Changing taskbar search to search box..." "Show_Search_Box.reg"
        continue
    }
    'HideTaskview' {
        RegImport "> Hiding the taskview button from the taskbar..." "Hide_Taskview_Taskbar.reg"
        continue
    }
    {$_ -in "HideWidgets", "DisableWidgets"} {
        RegImport "> Disabling widgets on the taskbar & lockscreen..." "Disable_Widgets_Service.reg"

        # Also remove the app package for Widgets
        $appsList = 'Microsoft.StartExperiencesApp'
        RemoveApps $appsList
        continue
    }
    {$_ -in "HideChat", "DisableChat"} {
        RegImport "> Hiding the chat icon from the taskbar..." "Disable_Chat_Taskbar.reg"
        continue
    }
    'EnableEndTask' {
        RegImport "> Enabling the 'End Task' option in the taskbar right click menu..." "Enable_End_Task.reg"
        continue
    }
    'EnableLastActiveClick' {
        RegImport "> Enabling the 'Last Active Click' behavior in the taskbar app area..." "Enable_Last_Active_Click.reg"
        continue
    }
    'ExplorerToHome' {
        RegImport "> Changing the default location that File Explorer opens to `Home`..." "Launch_File_Explorer_To_Home.reg"
        continue
    }
    'ExplorerToThisPC' {
        RegImport "> Changing the default location that File Explorer opens to `This PC`..." "Launch_File_Explorer_To_This_PC.reg"
        continue
    }
    'ExplorerToDownloads' {
        RegImport "> Changing the default location that File Explorer opens to `Downloads`..." "Launch_File_Explorer_To_Downloads.reg"
        continue
    }
    'ExplorerToOneDrive' {
        RegImport "> Changing the default location that File Explorer opens to `OneDrive`..." "Launch_File_Explorer_To_OneDrive.reg"
        continue
    }
    'ShowHiddenFolders' {
        RegImport "> Unhiding hidden files, folders and drives..." "Show_Hidden_Folders.reg"
        continue
    }
    'ShowKnownFileExt' {
        RegImport "> Enabling file extensions for known file types..." "Show_Extensions_For_Known_File_Types.reg"
        continue
    }
    'HideHome' {
        RegImport "> Hiding the home section from the File Explorer navigation pane..." "Hide_Home_from_Explorer.reg"
        continue
    }
    'HideGallery' {
        RegImport "> Hiding the gallery section from the File Explorer navigation pane..." "Hide_Gallery_from_Explorer.reg"
        continue
    }
    'HideDupliDrive' {
        RegImport "> Hiding duplicate removable drive entries from the File Explorer navigation pane..." "Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg"
        continue
    }
    {$_ -in "HideOnedrive", "DisableOnedrive"} {
        RegImport "> Hiding the OneDrive folder from the File Explorer navigation pane..." "Hide_Onedrive_Folder.reg"
        continue
    }
    {$_ -in "Hide3dObjects", "Disable3dObjects"} {
        RegImport "> Hiding the 3D objects folder from the File Explorer navigation pane..." "Hide_3D_Objects_Folder.reg"
        continue
    }
    {$_ -in "HideMusic", "DisableMusic"} {
        RegImport "> Hiding the music folder from the File Explorer navigation pane..." "Hide_Music_folder.reg"
        continue
    }
    {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
        RegImport "> Hiding 'Include in library' in the context menu..." "Disable_Include_in_library_from_context_menu.reg"
        continue
    }
    {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
        RegImport "> Hiding 'Give access to' in the context menu..." "Disable_Give_access_to_context_menu.reg"
        continue
    }
    {$_ -in "HideShare", "DisableShare"} {
        RegImport "> Hiding 'Share' in the context menu..." "Disable_Share_from_context_menu.reg"
        continue
    }
}

RestartExplorer

Write-Output ""
Write-Output ""
Write-Output ""
Write-Output "Script completed! Please check above for any errors."

AwaitKeyToExit
