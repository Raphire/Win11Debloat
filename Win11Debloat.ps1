#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$Silent,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$User,
    [switch]$NoRestartExplorer,
    [switch]$CreateRestorePoint,
    [switch]$RunAppsListGenerator, [switch]$RunAppConfigurator,
    [switch]$RunDefaults,
    [switch]$RunDefaultsLite,
    [switch]$RunSavedSettings,
    [string]$Apps,
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
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableBing, [switch]$DisableBingSearches,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscreenTips, [switch]$DisableLockscrTips,
    [switch]$DisableSuggestions, [switch]$DisableWindowsSuggestions,
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
    [switch]$DisableWidgets, [switch]$HideWidgets,
    [switch]$HideChat, [switch]$DisableChat,
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
    [switch]$AddFoldersToThisPC,
    [switch]$HideOnedrive, [switch]$DisableOnedrive,
    [switch]$Hide3dObjects, [switch]$Disable3dObjects,
    [switch]$HideMusic, [switch]$DisableMusic,
    [switch]$HideIncludeInLibrary, [switch]$DisableIncludeInLibrary,
    [switch]$HideGiveAccessTo, [switch]$DisableGiveAccessTo,
    [switch]$HideShare, [switch]$DisableShare
)



# Define script-level variables & paths
$script:DefaultSettingsFilePath = "$PSScriptRoot/DefaultSettings.json"
$script:AppsListFilePath = "$PSScriptRoot/Appslist.txt"
$script:SavedSettingsFilePath = "$PSScriptRoot/LastUsedSettings.json"
$script:CustomAppsListFilePath = "$PSScriptRoot/CustomAppsList"
$script:DefaultLogPath = "$PSScriptRoot/Win11Debloat.log"
$script:RegfilesPath = "$PSScriptRoot/Regfiles"
$script:AssetsPath = "$PSScriptRoot/Assets"

$script:ControlParams = 'WhatIf', 'Confirm', 'Verbose', 'Debug', 'LogPath', 'Silent', 'Sysprep', 'User', 'NoRestartExplorer', 'RunDefaults', 'RunDefaultsLite', 'RunSavedSettings', 'RunAppsListGenerator'
$script:Features = @{
    "RemoveApps" = "Remove the apps specified in the 'Apps' parameter"
    "Apps" = "The selection of apps to remove, specified as a comma separated list. Use 'Default' (or omit) to use the default apps list"
    "RemoveAppsCustom" = "Remove custom selection of apps"
    "RemoveCommApps" = "Remove the Mail, Calendar, and People apps"
    "RemoveW11Outlook" = "Remove the new Outlook for Windows app"
    "RemoveGamingApps" = "Remove the Xbox App and Xbox Gamebar"
    "RemoveHPApps" = "Remove HP OEM applications"
    "CreateRestorePoint" = "Create a system restore point"
    "DisableTelemetry" = "Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads"
    "DisableSuggestions" = "Disable tips, tricks, suggestions and ads in start, settings, notifications and File Explorer"
    "DisableEdgeAds" = "Disable ads, suggestions and the MSN news feed in Microsoft Edge"
    "DisableLockscreenTips" = "Disable tips & tricks on the lockscreen"
    "DisableBing" = "Disable & remove Bing web search, Bing AI and Cortana from Windows search"
    "DisableCopilot" = "Disable & remove Microsoft Copilot"
    "DisableRecall" = "Disable Windows Recall (Windows 11 only)"
    "DisableClickToDo" = "Disable Click to Do, AI text & image analysis (Windows 11 only)"
    "DisableWidgets" = "Disable widgets on the taskbar & lockscreen"
    "HideChat" = "Hide the chat (meet now) icon from the taskbar (Windows 10 only)"
    "ShowKnownFileExt" = "Show file extensions for known file types"
    "DisableFastStartup" = "Disable Fast Start-up"
    "Hide3dObjects" = "Hide the 3D objects folder under 'This PC' in File Explorer (Windows 10 only)"
    "DisableModernStandbyNetworking" = "Disable network connectivity during Modern Standby (If supported)"
    "DisableDVR" = "Disable Xbox game/screen recording"
    "DisableGameBarIntegration" = "Disable Game Bar integration"
    "ClearStart" = "Remove all pinned apps from the start menu for this user only"
    "ClearStartAllUsers" = "Remove all pinned apps from the start menu for all existing and new users"
    "ReplaceStart" = "Replace the start menu layout for this user only with the provided template file"
    "ReplaceStartAllUsers" = "Replace the start menu layout for all existing and new users with the provided template file"
    "DisableStartRecommended" = "Disable the recommended section in the start menu (Windows 11 only)"
    "DisableStartPhoneLink" = "Disable the Phone Link mobile devices integration in the start menu"
    "DisableSettings365Ads" = "Disable Microsoft 365 ads in Settings Home (Windows 11 only)"
    "DisableSettingsHome" = "Completely hide the Settings 'Home' page (Windows 11 only)"
    "DisableEdgeAI" = "Disable AI features in Microsoft Edge (Windows 11 only)"
    "DisablePaintAI" = "Disable AI features in Paint (Windows 11 only)"
    "DisableNotepadAI" = "Disable AI features in Notepad (Windows 11 only)"
    "EnableDarkMode" = "Enable dark mode for system and apps"
    "RevertContextMenu" = "Restore the old Windows 10 style context menu (Windows 11 only)"
    "DisableMouseAcceleration" = "Turn off Enhance Pointer Precision (mouse acceleration)"
    "DisableStickyKeys" = "Disable the Sticky Keys keyboard shortcut (Windows 11 only)"
    "DisableDesktopSpotlight" = "Disable the Windows Spotlight desktop background option"
    "TaskbarAlignLeft" = "Align taskbar icons to the left (Windows 11 only)"
    "CombineTaskbarAlways" = "Always combine taskbar buttons and hide labels for the main display (Windows 11 only)"
    "CombineMMTaskbarAlways" = "Always combine taskbar buttons and hide labels for secondary displays (Windows 11 only)"
    "CombineTaskbarWhenFull" = "Combine taskbar buttons and hide labels when taskbar is full for the main display (Windows 11 only)"
    "CombineMMTaskbarWhenFull" = "Combine taskbar buttons and hide labels when taskbar is full for secondary displays (Windows 11 only)"
    "CombineTaskbarNever" = "Never combine taskbar buttons and show labels for the main display (Windows 11 only)"
    "CombineMMTaskbarNever" = "Never combine taskbar buttons and show labels for secondary displays (Windows 11 only)"
    "MMTaskbarModeAll" = "Show app icons on all taskbars (Windows 11 only)"
    "MMTaskbarModeMainActive" = "Show app icons on main taskbar and on taskbar where the windows is open (Windows 11 only)"
    "MMTaskbarModeActive" = "Show app icons only on taskbar where the window is open (Windows 11 only)"
    "HideSearchTb" = "Hide search icon from the taskbar (Windows 11 only)"
    "ShowSearchIconTb" = "Show search icon on the taskbar (Windows 11 only)"
    "ShowSearchLabelTb" = "Show search icon with label on the taskbar (Windows 11 only)"
    "ShowSearchBoxTb" = "Show search box on the taskbar (Windows 11 only)"
    "HideTaskview" = "Hide the taskview button from the taskbar (Windows 11 only)"
    "EnableEndTask" = "Enable the 'End Task' option in the taskbar right click menu (Windows 11 only)"
    "EnableLastActiveClick" = "Enable the 'Last Active Click' behavior in the taskbar app area"
    "ShowHiddenFolders" = "Show hidden files, folders and drives"
    "ExplorerToHome" = "Change the default location that File Explorer opens to 'Home'"
    "ExplorerToThisPC" = "Change the default location that File Explorer opens to 'This PC'"
    "ExplorerToDownloads" = "Change the default location that File Explorer opens to 'Downloads'"
    "ExplorerToOneDrive" = "Change the default location that File Explorer opens to 'OneDrive'"
    "AddFoldersToThisPC" = "Add all common folders (Desktop, Downloads, etc.) back to 'This PC' in File Explorer"
    "HideHome" = "Hide the Home section from the File Explorer sidepanel (Windows 11 only)"
    "HideGallery" = "Hide the Gallery section from the File Explorer sidepanel (Windows 11 only)"
    "HideDupliDrive" = "Hide duplicate removable drive entries from the File Explorer sidepanel"
    "DisableTransparency" = "Disable transparency effects"
    "DisableAnimations" = "Disable animations and visual effects"
    "ForceRemoveEdge" = "Forcefully uninstall Microsoft Edge. NOT RECOMMENDED!"
    "HideIncludeInLibrary" = "Hide the 'Include in library' option in the context menu (Windows 10 only)"
    "HideGiveAccessTo" = "Hide the 'Give access to' option in the context menu (Windows 10 only)"
    "HideShare" = "Hide the 'Share' option in the context menu (Windows 10 only)"
    "HideOnedrive" = "Hide the OneDrive folder in the File Explorer sidepanel (Windows 10 only)"
    "HideMusic" = "Hide the music folder under 'This PC' in File Explorer (Windows 10 only)"
}

# Check if current powershell environment is limited by security policies
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Error "Win11Debloat is unable to run on your system, powershell execution is restricted by security policies"
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Check if script does not see file dependencies
if (-not ((Test-Path $script:DefaultSettingsFilePath) -and (Test-Path $script:AppsListFilePath) -and (Test-Path $script:RegfilesPath) -and (Test-Path $script:AssetsPath))) {
    Write-Error "Win11Debloat is unable to find required files, please ensure all script files are present"
    Write-Output "Press any key to exit..."
    $null = [System.Console]::ReadKey()
    Exit
}

# Log script output to 'Win11Debloat.log' at the specified path
if ($LogPath -and (Test-Path $LogPath)) {
    Start-Transcript -Path "$LogPath/Win11Debloat.log" -Append -IncludeInvocationHeader -Force | Out-Null
}
else {
    Start-Transcript -Path $script:DefaultLogPath -Append -IncludeInvocationHeader -Force | Out-Null
}



##################################################################################################################
#                                                                                                                #
#                                              FUNCTION DEFINITIONS                                              #
#                                                                                                                #
##################################################################################################################



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

    $script:SelectionBoxIndex = -1

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

        # Close form without saving if no apps were selected
        if ($script:SelectedApps.Count -eq 0) {
            $form.Close()
            return
        }

        # Create file that stores selected apps if it doesn't exist
        if (-not (Test-Path $script:CustomAppsListFilePath)) {
            $null = New-Item $script:CustomAppsListFilePath
        }

        Set-Content -Path $script:CustomAppsListFilePath -Value $script:SelectedApps

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
        $script:SelectionBoxIndex = $selectionBox.SelectedIndex
    }

    $selectionBox_MouseDown=
    {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if ([System.Windows.Forms.Control]::ModifierKeys -eq [System.Windows.Forms.Keys]::Shift) {
                if ($script:SelectionBoxIndex -ne -1) {
                    $topIndex = $script:SelectionBoxIndex

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
            elseif ($script:SelectionBoxIndex -ne $selectionBox.SelectedIndex) {
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
        $script:SelectionBoxIndex = -1
        $checkUncheckCheckBox.Checked = $False

        # Show loading indicator
        $loadingLabel.Visible = $true
        $form.Refresh()

        # Clear selectionBox before adding any new items
        $selectionBox.Items.Clear()

        $listOfApps = ""

        if ($onlyInstalledCheckBox.Checked -and ($script:WingetInstalled -eq $true)) {
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
        Foreach ($app in (Get-Content -Path $script:AppsListFilePath | Where-Object { $_ -notmatch '^\s*$' -and $_ -notmatch '^#  .*' -and $_ -notmatch '^# -* #' } )) { 
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

                # Add the app to the selectionBox and set its checked status
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


# Returns a validated list of apps based on the provided appsList and the supported apps from Appslist.txt
function ValidateAppslist {
    param (
        $appsList
    )

    $supportedAppsList = @()
    $validatedAppsList = @()

    # Generate a list of supported apps from AppsList.txt
    Foreach ($app in (Get-Content -Path $script:AppsListFilePath | Where-Object { $_ -notmatch '^\s*$' -and $_ -notmatch '^#  .*' -and $_ -notmatch '^# -* #' } )) {
        $app = $app.TrimStart("#")

        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }

        $app = $app.Trim()
        $appString = $app.Trim('*')
        $supportedAppsList += $appString
    }

    # Validate provided appsList against supportedAppsList
    Foreach ($app in $appsList) {
        $app = $app.Trim()
        $appString = $app.Trim('*')

        if ($supportedAppsList -notcontains $appString) {
            Write-Host "Removal of app '$appString' is not supported and will be skipped" -ForegroundColor Yellow
            continue
        }

        $validatedAppsList += $appString
    }

    return $validatedAppsList
}


# Returns list of apps from the specified file, it trims the app names and removes any comments
function ReadAppslistFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    if (-not (Test-Path $appsFilePath)) {
        return $appsList
    }

    Foreach ($app in (Get-Content -Path $appsFilePath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) { 
        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }

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

        # Use winget only to remove OneDrive and Edge
        if (($app -eq "Microsoft.OneDrive") -or ($app -eq "Microsoft.Edge")) {
            if ($script:WingetInstalled -eq $false) {
                Write-Host "WinGet is either not installed or is outdated, $app could not be removed" -ForegroundColor Red
                continue
            }

            $appName = $app -replace '\.', '_'

            # Uninstall app via winget, or create a scheduled task to uninstall it later
            if ($script:Params.ContainsKey("User")) {
                RegImport "Adding scheduled task to uninstall $app for user $(GetUserName)..." "Uninstall_$($appName).reg"
            }
            elseif ($script:Params.ContainsKey("Sysprep")) {
                RegImport "Adding scheduled task to uninstall $app after new users log in..." "Uninstall_$($appName).reg"
            }
            else {
                # Uninstall app via winget, with any progress indicators removed from the output
                StripProgress -ScriptBlock { winget uninstall --accept-source-agreements --disable-interactivity --id $app } | Tee-Object -Variable wingetOutput

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "Uninstall failed with exit code")) {
                    Write-Host "Unable to uninstall Microsoft Edge via Winget" -ForegroundColor Red
                    Write-Output ""

                    if ($( Read-Host -Prompt "Would you like to forcefully uninstall Microsoft Edge? NOT RECOMMENDED! (y/n)" ) -eq 'y') {
                        Write-Output ""
                        ForceRemoveEdge
                    }
                }
            }

            continue
        }

        # Use Remove-AppxPackage to remove all other apps
        $app = '*' + $app + '*'

        # Remove installed app for all existing users
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

        # Remove provisioned app from OS image, so the app won't be installed for any new users
        try {
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
        }
        catch {
            Write-Host "Unable to remove $app from windows image" -ForegroundColor Yellow
            Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
        }
    }

    Write-Output ""
}


# Forcefully removes Microsoft Edge using its uninstaller
# Credit: Based on work from loadstring1 & ave9858
function ForceRemoveEdge {
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
function StripProgress {
    param(
        [ScriptBlock]$ScriptBlock
    )

    # Regex pattern to match spinner characters and progress bar patterns
    $progressPattern = 'Γû[Æê]|^\s+[-\\|/]\s+$'

    # Corrected regex pattern for size formatting, ensuring proper capture groups are utilized
    $sizePattern = '(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB) /\s+(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)'

    & $ScriptBlock 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "Error: $($_.Exception.Message)"
        }
        else {
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

    try {
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
        reg import "$script:RegfilesPath\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null
    }
    elseif ($script:Params.ContainsKey("User")) {
        $userPath = GetUserDirectory -userName $script:Params.Item("User") -fileName "NTUSER.DAT"

        reg load "HKU\Default" $userPath | Out-Null
        reg import "$script:RegfilesPath\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null

    }
    else {
        reg import "$script:RegfilesPath\$path"  
    }

    Write-Output ""
}


# Restart the Windows Explorer process
function RestartExplorer {
    Write-Output "> Attempting to restart the Windows Explorer process to apply all changes..."
    
    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User") -or $script:Params.ContainsKey("NoRestartExplorer")) {
        Write-Host "Process restart was skipped, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
        return
    }

    if ($script:Params.ContainsKey("DisableMouseAcceleration")) {
        Write-Host "Warning: Changes to the Enhance Pointer Precision setting will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableStickyKeys")) {
        Write-Host "Warning: Changes to the Sticky Keys setting will only take effect after a reboot" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableAnimations")) {
        Write-Host "Warning: Animations will only be disabled after a reboot" -ForegroundColor Yellow
    }

    # Only restart if the powershell process matches the OS architecture.
    # Restarting explorer from a 32bit PowerShell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem) {
        Write-Output "Restarting the Windows Explorer process... (This may cause your screen to flicker)"
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Host "Unable to restart Windows Explorer process, please manually reboot your PC to apply all changes" -ForegroundColor Yellow
    }
}


# Replace the startmenu for all users, when using the default startmenuTemplate this clears all pinned apps
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$script:AssetsPath/Start/start2.bin"
    )

    Write-Output "> Removing all pinned apps from the start menu for all users..."

    # Check if template bin file exists
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

    Write-Output "Replaced start menu for user $userName"
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


# Saves the current settings, excluding control parameters, to a JSON file
function SaveSettings {
    $settings = @{
        "Version" = "1.0"
        "Settings" = @()
    }
    
    foreach ($param in $script:Params.Keys) {
        if ($script:ControlParams -notcontains $param) {
            $value = $script:Params[$param]

            $settings.Settings += @{
                "Name" = $param
                "Value" = $value
            }
        }
    }

    try {
        $settings | ConvertTo-Json -Depth 10 | Set-Content $script:SavedSettingsFilePath
    }
    catch {
        Write-Output ""
        Write-Host "Error: Failed to save settings to LastUsedSettings.json file" -ForegroundColor Red
    }
}


# Prints the header for the script
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
    Write-Host "-------------------------------------------------------------------------------------------"
    Write-Host $fullTitle
    Write-Host "-------------------------------------------------------------------------------------------"
}


# Prints the contents of a file to the console
function PrintFromFile {
    param (
        $path,
        $title,
        $printHeader = $true
    )

    if ($printHeader) {
        Clear-Host

        PrintHeader $title
    }

    # Get & print script menu from file
    Foreach ($line in (Get-Content -Path $path )) {   
        Write-Host $line
    }
}


# Prints all pending changes that will be made by the script
function PrintPendingChanges {
    Write-Output "Win11Debloat will make the following changes:"

    if ($script:Params['CreateRestorePoint']) {
        Write-Output "- $($script:Features['CreateRestorePoint'])"
    }
    foreach ($parameterName in $script:Params.Keys) {
        if ($script:ControlParams -contains $parameterName) {
            continue
        }

        # Print parameter description
        switch ($parameterName) {
            'Apps' {
                continue
            }
            'CreateRestorePoint' {
                continue
            }
            'RemoveApps' {
                $appsList = GenerateAppsList

                if ($appsList.Count -eq 0) {
                    Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
                    Write-Output ""
                    continue
                }

                Write-Output "- Remove $($appsList.Count) apps:"
                Write-Host $appsList -ForegroundColor DarkGray
                continue
            }
            'RemoveAppsCustom' {
                $appsList = ReadAppslistFromFile $script:CustomAppsListFilePath

                if ($appsList.Count -eq 0) {
                    Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
                    Write-Output ""
                    continue
                }

                Write-Output "- Remove $($appsList.Count) apps:"
                Write-Host $appsList -ForegroundColor DarkGray
                continue
            }
            default {
                if ($script:Features -and $script:Features.ContainsKey($parameterName)) {
                    $message = $script:Features[$parameterName]
                    Write-Output "- $message"
                }
                else {
                    # Fallback: show the parameter name if no feature description is available
                    Write-Output "- $parameterName"
                }
                continue
            }
        }
    }

    Write-Output ""
    Write-Output ""
    Write-Output "Press enter to execute the script or press CTRL+C to quit..."
    Read-Host | Out-Null
}


# Generates a list of apps to remove based on the Apps parameter
function GenerateAppsList {
    if (-not ($script:Params["Apps"] -and $script:Params["Apps"] -is [string])) {
        return @()
    }

    $appMode = $script:Params["Apps"].toLower()

    switch ($appMode) {
        'default' {
            $appsList = ReadAppslistFromFile $script:AppsListFilePath
            return $appsList
        }
        default {
            $appsList = $script:Params["Apps"].Split(',') | ForEach-Object { $_.Trim() }
            $validatedAppsList = ValidateAppslist $appsList
            return $validatedAppsList
        }
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
                }
                catch {
                    Write-Host "Error: Failed to enable System Restore: $_" -ForegroundColor Red
                    return
                }
            }

            $enableSystemRestoreJobDone = $enableSystemRestoreJob | Wait-Job -TimeOut 20

            if (-not $enableSystemRestoreJobDone) {
                Write-Host "Error: Failed to enable system restore and create restore point, operation timed out" -ForegroundColor Red
                return
            }
            else {
                Receive-Job $enableSystemRestoreJob
            }
        }
        else {
            Write-Output ""
            return
        }
    }

    $createRestorePointJob = Start-Job {
        # Find existing restore points that are less than 24 hours old
        try {
            $recentRestorePoints = Get-ComputerRestorePoint | Where-Object { (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24) }
        }
        catch {
            Write-Host "Error: Unable to retrieve existing restore points: $_" -ForegroundColor Red
            return
        }

        if ($recentRestorePoints.Count -eq 0) {
            try {
                Checkpoint-Computer -Description "Restore point created by Win11Debloat" -RestorePointType "MODIFY_SETTINGS"
                Write-Output "System restore point created successfully"
            }
            catch {
                Write-Host "Error: Unable to create restore point: $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "A recent restore point already exists, no new restore point was created" -ForegroundColor Yellow
        }
    }

    $createRestorePointJobDone = $createRestorePointJob | Wait-Job -TimeOut 20

    if (-not $createRestorePointJobDone) {
        Write-Host "Error: Failed to create system restore point, operation timed out" -ForegroundColor Red
    }
    else {
        Receive-Job $createRestorePointJob
    }

    Write-Output ""
}


function ShowScriptMenuOptions {
    Do { 
        $ModeSelectionMessage = "Please select an option (1/2/3/0)" 

        PrintHeader 'Menu'

        Write-Host "(1) Default mode: Quickly apply the recommended changes"
        Write-Host "(2) Custom mode: Manually select what changes to make"
        Write-Host "(3) App removal mode: Select & remove apps, without making other changes"

        # Only show this option if SavedSettings file exists
        if (Test-Path $script:SavedSettingsFilePath) {
            Write-Host "(4) Quickly apply your last used settings"
            
            $ModeSelectionMessage = "Please select an option (1/2/3/4/0)" 
        }

        Write-Host ""
        Write-Host "(0) Show more information"
        Write-Host ""
        Write-Host ""

        $Mode = Read-Host $ModeSelectionMessage

        if ($Mode -eq '0') {
            # Print information screen from file
            PrintFromFile "$script:AssetsPath/Menus/Info" "Information"

            Write-Host "Press any key to go back..."
            $null = [System.Console]::ReadKey()
        }
        elseif (($Mode -eq '4') -and -not (Test-Path $script:SavedSettingsFilePath)) {
            $Mode = $null
        }
    }
    while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3' -and $Mode -ne '4')

    return $Mode
}


function ShowDefaultModeOptions {
    # Show options for removing apps, or set selection if RunDefaults or RunDefaultsLite parameter was passed
    if ($RunDefaults) {
        $RemoveAppsInput = '1'
    }
    elseif ($RunDefaultsLite) {
        $RemoveAppsInput = '0'                
    }
    else {
        $RemoveAppsInput = ShowDefaultModeAppRemovalOptions

        if ($RemoveAppsInput -eq '2' -and ($script:SelectedApps.contains('Microsoft.XboxGameOverlay') -or $script:SelectedApps.contains('Microsoft.XboxGamingOverlay')) -and 
          $( Read-Host -Prompt "Disable Game Bar integration and game/screen recording? This also stops ms-gamingoverlay and ms-gamebar popups (y/n)" ) -eq 'y') {
            $DisableGameBarIntegrationInput = $true;
        }
    }

    PrintHeader 'Default Mode'

    # Add default settings based on user input
    try {
        $defaultSettings = (Get-Content -Path $script:DefaultSettingsFilePath -Raw | ConvertFrom-Json)
        if (-not $defaultSettings.Version -or $defaultSettings.Version -ne "1.0") {
            Write-Error "DefaultSettings.json version mismatch (expected 1.0, found $($defaultSettings.Version))"
            AwaitKeyToExit
        }

        # Select app removal options based on user input
        switch ($RemoveAppsInput) {
            '1' {
                AddParameter 'RemoveApps'
                AddParameter 'Apps' 'Default'
            }
            '2' {
                AddParameter 'RemoveAppsCustom'

                if ($DisableGameBarIntegrationInput) {
                    AddParameter 'DisableDVR'
                    AddParameter 'DisableGameBarIntegration'
                }
            }
        }

        Foreach ($setting in $defaultSettings.Settings) {
            if ($setting.Value -eq $false) {
                continue
            }
    
            AddParameter $setting.Name $setting.Value
        }
    }
    catch {
        Write-Error "Failed to load settings from DefaultSettings.json file"
        AwaitKeyToExit
    }

    SaveSettings

    # Skip change summary if Silent parameter was passed
    if ($Silent) {
        return
    }

    PrintPendingChanges
    PrintHeader 'Default Mode'
}


function ShowDefaultModeAppRemovalOptions {
    PrintHeader 'Default Mode'

    Write-Host "Please note: The default selection of apps includes Microsoft Teams, Spotify, Sticky Notes and more. Select option 2 to verify and change what apps are removed by the script" -ForegroundColor DarkGray
    Write-Host ""

    Do {
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host " (n) Don't remove any apps" -ForegroundColor Yellow
        Write-Host " (1) Only remove the default selection of apps" -ForegroundColor Yellow
        Write-Host " (2) Manually select which apps to remove" -ForegroundColor Yellow
        $RemoveAppsInput = Read-Host "Do you want to remove any apps? Apps will be removed for all users (n/1/2)"

        # Show app selection form if user entered option 3
        if ($RemoveAppsInput -eq '2') {
            $result = ShowAppSelectionForm

            if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
                # User cancelled or closed app selection, change RemoveAppsInput so the menu will be shown again
                Write-Host ""
                Write-Host "Cancelled application selection, please try again" -ForegroundColor Red

                $RemoveAppsInput = 'c'
            }
            
            Write-Host ""
        }
    }
    while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2')

    return $RemoveAppsInput
}


function ShowCustomModeOptions {
    # Get current Windows build version to compare against features
    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

    PrintHeader 'Custom Mode'

    AddParameter 'CreateRestorePoint'

    # Show options for removing apps, only continue on valid input
    Do {
        Write-Host "Options:" -ForegroundColor Yellow
        Write-Host " (n) Don't remove any apps" -ForegroundColor Yellow
        Write-Host " (1) Only remove the default selection of apps" -ForegroundColor Yellow
        Write-Host " (2) Remove the default selection of apps, as well as mail & calendar apps and gaming related apps"  -ForegroundColor Yellow
        Write-Host " (3) Manually select which apps to remove" -ForegroundColor Yellow
        $RemoveAppsInput = Read-Host "Do you want to remove any apps? Apps will be removed for all users (n/1/2/3)"

        # Show app selection form if user entered option 3
        if ($RemoveAppsInput -eq '3') {
            $result = ShowAppSelectionForm

            if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
                # User cancelled or closed app selection, change RemoveAppsInput so the menu will be shown again
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
            AddParameter 'RemoveApps'
            AddParameter 'Apps' 'Default'
        }
        '2' {
            AddParameter 'RemoveApps'
            AddParameter 'Apps' 'Default'
            AddParameter 'RemoveCommApps'
            AddParameter 'RemoveW11Outlook'
            AddParameter 'RemoveGamingApps'

            Write-Output ""

            if ($(Read-Host -Prompt "Disable Game Bar integration and game/screen recording? This also stops ms-gamingoverlay and ms-gamebar popups (y/n)" ) -eq 'y') {
                AddParameter 'DisableDVR'
                AddParameter 'DisableGameBarIntegration'
            }
        }
        '3' {
            Write-Output "You have selected $($script:SelectedApps.Count) apps for removal"

            AddParameter 'RemoveAppsCustom'

            Write-Output ""

            if ($(Read-Host -Prompt "Disable Game Bar integration and game/screen recording? This also stops ms-gamingoverlay and ms-gamebar popups (y/n)" ) -eq 'y') {
                AddParameter 'DisableDVR'
                AddParameter 'DisableGameBarIntegration'
            }
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable telemetry, diagnostic data, activity history, app-launch tracking and targeted ads? (y/n)" ) -eq 'y') {
        AddParameter 'DisableTelemetry'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable tips, tricks, suggestions and ads in start, settings, notifications, explorer, lockscreen and Edge? (y/n)" ) -eq 'y') {
        AddParameter 'DisableSuggestions'
        AddParameter 'DisableEdgeAds'
        AddParameter 'DisableSettings365Ads'
        AddParameter 'DisableLockscreenTips'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable & remove Bing web search, Bing AI and Cortana from Windows search? (y/n)" ) -eq 'y') {
        AddParameter 'DisableBing'
    }

    # Only show this option for Windows 11 users running build 22621 or later
    if ($WinVersion -ge 22621) {
        Write-Output ""

        # Show options for disabling/removing AI features, only continue on valid input
        Do {
            Write-Host "Options:" -ForegroundColor Yellow
            Write-Host " (n) Don't disable any AI features" -ForegroundColor Yellow
            Write-Host " (1) Disable Microsoft Copilot, Windows Recall and Click to Do" -ForegroundColor Yellow
            Write-Host " (2) Disable Microsoft Copilot, Windows Recall, Click to Do and AI features in Microsoft Edge, Paint and Notepad"  -ForegroundColor Yellow
            $DisableAIInput = Read-Host "Do you want to disable any AI features? This applies to all users (n/1/2)"
        }
        while ($DisableAIInput -ne 'n' -and $DisableAIInput -ne '0' -and $DisableAIInput -ne '1' -and $DisableAIInput -ne '2')

        # Select correct option based on user input
        switch ($DisableAIInput) {
            '1' {
                AddParameter 'DisableCopilot'
                AddParameter 'DisableRecall'
                AddParameter 'DisableClickToDo'
            }
            '2' {
                AddParameter 'DisableCopilot'
                AddParameter 'DisableRecall'
                AddParameter 'DisableClickToDo'
                AddParameter 'DisableEdgeAI'
                AddParameter 'DisablePaintAI'
                AddParameter 'DisableNotepadAI'
            }
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable Windows Spotlight background on desktop? (y/n)" ) -eq 'y') {
        AddParameter 'DisableDesktopSpotlight'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Enable dark mode for system and apps? (y/n)" ) -eq 'y') {
        AddParameter 'EnableDarkMode'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable transparency, animations and visual effects? (y/n)" ) -eq 'y') {
        AddParameter 'DisableTransparency'
        AddParameter 'DisableAnimations'
    }

    # Only show this option for Windows 11 users running build 22000 or later
    if ($WinVersion -ge 22000) {
        Write-Output ""

        if ($( Read-Host -Prompt "Restore the old Windows 10 style context menu? (y/n)" ) -eq 'y') {
            AddParameter 'RevertContextMenu'
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Turn off Enhance Pointer Precision, also known as mouse acceleration? (y/n)" ) -eq 'y') {
        AddParameter 'DisableMouseAcceleration'
    }

    # Only show this option for Windows 11 users running build 26100 or later
    if ($WinVersion -ge 26100) {
        Write-Output ""

        if ($( Read-Host -Prompt "Disable the Sticky Keys keyboard shortcut? (y/n)" ) -eq 'y') {
            AddParameter 'DisableStickyKeys'
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Disable Fast Start-up? This applies to all users (y/n)" ) -eq 'y') {
        AddParameter 'DisableFastStartup'
    }

    # Only show this option for Windows 11 users running build 22000 or later, and if the machine has at least one battery
    if (($WinVersion -ge 22000) -and $script:ModernStandbySupported) {
        Write-Output ""

        if ($( Read-Host -Prompt "Disable network connectivity during Modern Standby? This applies to all users (y/n)" ) -eq 'y') {
            AddParameter 'DisableModernStandbyNetworking'
        }
    }

    # Only show option for disabling context menu items for Windows 10 users or if the user opted to restore the Windows 10 context menu
    if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -or $script:Params.ContainsKey('RevertContextMenu')) {
        Write-Output ""

        if ($( Read-Host -Prompt "Do you want to disable any context menu options? (y/n)" ) -eq 'y') {
            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the 'Include in library' option in the context menu? (y/n)" ) -eq 'y') {
                AddParameter 'HideIncludeInLibrary'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the 'Give access to' option in the context menu? (y/n)" ) -eq 'y') {
                AddParameter 'HideGiveAccessTo'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the 'Share' option in the context menu? (y/n)" ) -eq 'y') {
                AddParameter 'HideShare'
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
                    AddParameter 'ClearStartAllUsers'
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
                        AddParameter 'ClearStart'
                    }
                    '2' {
                        AddParameter 'ClearStartAllUsers'
                    }
                }
            }

            # Don't show option for users running build 26200 and above, as this setting was removed in this build
            if ($WinVersion -lt 26200) {
                Write-Output ""

                if ($( Read-Host -Prompt "   Disable the recommended section in the start menu? This applies to all users (y/n)" ) -eq 'y') {
                    AddParameter 'DisableStartRecommended'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Disable the Phone Link mobile devices integration in the start menu? (y/n)" ) -eq 'y') {
                AddParameter 'DisableStartPhoneLink'
            }
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "Do you want to make any changes to the taskbar and related services? (y/n)" ) -eq 'y') {
        # Only show these specific options for Windows 11 users running build 22000 or later
        if ($WinVersion -ge 22000) {
            Write-Output ""

            if ($( Read-Host -Prompt "   Align taskbar buttons to the left side? (y/n)" ) -eq 'y') {
                AddParameter 'TaskbarAlignLeft'
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
                    AddParameter 'HideSearchTb'
                }
                '2' {
                    AddParameter 'ShowSearchIconTb'
                }
                '3' {
                    AddParameter 'ShowSearchLabelTb'
                }
                '4' {
                    AddParameter 'ShowSearchBoxTb'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the taskview button from the taskbar? (y/n)" ) -eq 'y') {
                AddParameter 'HideTaskview'
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "   Disable the widgets service to remove widgets on the taskbar & lockscreen? (y/n)" ) -eq 'y') {
            AddParameter 'DisableWidgets'
        }

        # Only show this options for Windows users running build 22621 or earlier
        if ($WinVersion -le 22621) {
            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the chat (meet now) icon from the taskbar? (y/n)" ) -eq 'y') {
                AddParameter 'HideChat'
            }
        }

        # Only show this options for Windows users running build 22631 or later
        if ($WinVersion -ge 22631) {
            Write-Output ""

            if ($( Read-Host -Prompt "   Enable the 'End Task' option in the taskbar right click menu? (y/n)" ) -eq 'y') {
                AddParameter 'EnableEndTask'
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "   Enable the 'Last Active Click' behavior in the taskbar app area? (y/n)" ) -eq 'y') {
            AddParameter 'EnableLastActiveClick'
        }

        # Only show these specific options for Windows 11 users running build 22000 or later
        if ($WinVersion -ge 22000) {
            # Show options for combine icon on taskbar, only continue on valid input
            Do {
                Write-Output ""
                Write-Host "   Options:" -ForegroundColor Yellow
                Write-Host "    (n) No change" -ForegroundColor Yellow
                Write-Host "    (1) Always" -ForegroundColor Yellow
                Write-Host "    (2) When taskbar is full" -ForegroundColor Yellow
                Write-Host "    (3) Never" -ForegroundColor Yellow
                $TbCombineTaskbar = Read-Host "   Combine taskbar buttons and hide labels? (n/1/2/3)"
            }
            while ($TbCombineTaskbar -ne 'n' -and $TbCombineTaskbar -ne '0' -and $TbCombineTaskbar -ne '1' -and $TbCombineTaskbar -ne '2' -and $TbCombineTaskbar -ne '3')

            # Select correct taskbar goup option based on user input
            switch ($TbCombineTaskbar) {
                '1' {
                    AddParameter 'CombineTaskbarAlways'
                    AddParameter 'CombineMMTaskbarAlways'
                }
                '2' {
                    AddParameter 'CombineTaskbarWhenFull'
                    AddParameter 'CombineMMTaskbarWhenFull'
                }
                '3' {
                    AddParameter 'CombineTaskbarNever'
                    AddParameter 'CombineMMTaskbarNever'
                }
            }

            # Show options for changing on what taskbar(s) app icons are shown, only continue on valid input
            Do {
                Write-Output ""
                Write-Host "   Options:" -ForegroundColor Yellow
                Write-Host "    (n) No change" -ForegroundColor Yellow
                Write-Host "    (1) Show app icons on all taskbars" -ForegroundColor Yellow
                Write-Host "    (2) Show app icons on main taskbar and on taskbar where the windows is open" -ForegroundColor Yellow
                Write-Host "    (3) Show app icons only on taskbar where the window is open" -ForegroundColor Yellow
                $TbCombineTaskbar = Read-Host "   Change how to show app icons on the taskbar when using multiple monitors? (n/1/2/3)"
            }
            while ($TbCombineTaskbar -ne 'n' -and $TbCombineTaskbar -ne '0' -and $TbCombineTaskbar -ne '1' -and $TbCombineTaskbar -ne '2' -and $TbCombineTaskbar -ne '3')

            # Select correct taskbar goup option based on user input
            switch ($TbCombineTaskbar) {
                '1' {
                    AddParameter 'MMTaskbarModeAll'
                }
                '2' {
                    AddParameter 'MMTaskbarModeMainActive'
                }
                '3' {
                    AddParameter 'MMTaskbarModeActive'
                }
            }
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
                AddParameter 'ExplorerToHome'
            }
            '2' {
                AddParameter 'ExplorerToThisPC'
            }
            '3' {
                AddParameter 'ExplorerToDownloads'
            }
            '4' {
                AddParameter 'ExplorerToOneDrive'
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "   Show hidden files, folders and drives? (y/n)" ) -eq 'y') {
            AddParameter 'ShowHiddenFolders'
        }

        Write-Output ""

        if ($( Read-Host -Prompt "   Show file extensions for known file types? (y/n)" ) -eq 'y') {
            AddParameter 'ShowKnownFileExt'
        }

        # Only show this option for Windows 11 users running build 22000 or later
        if ($WinVersion -ge 22000) {
            Write-Output ""

            if ($( Read-Host -Prompt "   Add all common folders (Desktop, Downloads, etc.) back to 'This PC' in File Explorer? (y/n)" ) -eq 'y') {
                AddParameter 'AddFoldersToThisPC'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the Home section from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                AddParameter 'HideHome'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "   Hide the Gallery section from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                AddParameter 'HideGallery'
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "   Hide duplicate removable drive entries from the File Explorer sidepanel so they only show under 'This PC'? (y/n)" ) -eq 'y') {
            AddParameter 'HideDupliDrive'
        }

        # Only show option for disabling these specific folders for Windows 10 users
        if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") {
            Write-Output ""

            if ($( Read-Host -Prompt "Do you want to hide any folders from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                Write-Output ""

                if ($( Read-Host -Prompt "   Hide the OneDrive folder from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                    AddParameter 'HideOnedrive'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Hide the 3D objects folder from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                    AddParameter 'Hide3dObjects'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Hide the music folder from the File Explorer sidepanel? (y/n)" ) -eq 'y') {
                    AddParameter 'HideMusic'
                }
            }
        }
    }
    
    # Only save settings if any changes were selected by the user
    if ($script:Params.Keys.Count -gt 1) {
        SaveSettings
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


function ShowAppRemoval {
    PrintHeader "App Removal"

    Write-Output "> Opening app selection form..."

    $result = ShowAppSelectionForm

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Output "You have selected $($script:SelectedApps.Count) apps for removal"
        AddParameter 'RemoveAppsCustom'

        SaveSettings

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


function LoadAndShowLastUsedSettings {
    PrintHeader 'Custom Mode'

    try {
        $savedSettings = (Get-Content -Path $script:SavedSettingsFilePath -Raw | ConvertFrom-Json)
        if ($savedSettings.Version -and $savedSettings.Version -ne "1.0") {
            Write-Error "LastUsedSettings.json version mismatch (expected 1.0, found $($savedSettings.Version))"
            AwaitKeyToExit
        }

        if (-not $savedSettings.Settings) {
            throw
        }

        # Add settings from LastUsedSettings.json to Params
        Foreach ($parameter in $savedSettings.Settings) {
            $parameterName = $parameter.Name
            $value = $parameter.Value
    
            # Skip parameters that are set to false in the config
            if ($value -eq $false) {
                continue
            }
    
            # Add parameter to Params
            if (-not $script:Params.ContainsKey($parameterName)) {
                $script:Params.Add($parameterName, $value)
            }
            else {
                $script:Params[$parameterName] = $value
            }
        }
    }
    catch {
        Write-Error "Failed to load settings from LastUsedSettings.json file"
        AwaitKeyToExit
    }

    PrintPendingChanges
    PrintHeader 'Custom Mode'
}



##################################################################################################################
#                                                                                                                #
#                                                  SCRIPT START                                                  #
#                                                                                                                #
##################################################################################################################



# Check if winget is installed & if it is, check if the version is at least v1.4
if ((Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*") -and ([int](((winget -v) -replace 'v','').split('.')[0..1] -join '') -gt 14)) {
    $script:WingetInstalled = $true
}
else {
    $script:WingetInstalled = $false

    # Show warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
    if (-not $Silent) {
        Write-Warning "Winget is not installed or outdated, this may prevent Win11Debloat from removing certain apps"
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

# Make sure all requirements for User mode are met, if User is specified
if ($script:Params.ContainsKey("User")) {
    $userPath = GetUserDirectory -userName $script:Params.Item("User")
}

# Remove LastUsedSettings.json file if it exists and is empty
if ((Test-Path $script:SavedSettingsFilePath) -and ([String]::IsNullOrWhiteSpace((Get-content $script:SavedSettingsFilePath)))) {
    Remove-Item -Path $script:SavedSettingsFilePath -recurse
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
if ((-not $script:Params.Count) -or $RunDefaults -or $RunDefaultsLite -or $RunSavedSettings -or ($controlParamsCount -eq $script:Params.Count)) {
    if ($RunDefaults -or $RunDefaultsLite) {
        $Mode = '1'
    }
    elseif ($RunSavedSettings) {
        if (-not (Test-Path $script:SavedSettingsFilePath)) {
            PrintHeader 'Custom Mode'
            Write-Error "Unable to find LastUsedSettings.json file, no changes were made"
            AwaitKeyToExit
        }

        $Mode = '4'
    }
    else {
        $Mode = ShowScriptMenuOptions 
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults and app removal options
        '1' { 
            ShowDefaultModeOptions
        }

        # Custom mode, shows all available options for user selection
        '2' { 
            ShowCustomModeOptions
        }

        # App removal, remove apps based on user selection
        '3' {
            ShowAppRemoval
        }

        # Load last used options from the "LastUsedSettings.json" file
        '4' {
            LoadAndShowLastUsedSettings
        }
    }
}
else {
    PrintHeader 'Custom Mode'
}

# If the number of keys in ControlParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if (($controlParamsCount -eq $script:Params.Keys.Count) -or ($script:Params.Keys.Count -eq 1 -and ($script:Params.Keys -contains 'CreateRestorePoint' -or $script:Params.Keys -contains 'Apps'))) {
    Write-Output "The script completed without making any changes."
    AwaitKeyToExit
}

# Create a system restore point if the CreateRestorePoint parameter was passed
if ($script:Params.ContainsKey("CreateRestorePoint")) {
    CreateSystemRestorePoint
}

# Execute all selected/provided parameters
switch ($script:Params.Keys) {
    'RemoveApps' {
        Write-Output "> Removing selected apps..."
        $appsList = GenerateAppsList

        if ($appsList.Count -eq 0) {
            Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        Write-Output "$($appsList.Count) apps selected for removal"
        RemoveApps $appsList
        continue
    }
    'RemoveAppsCustom' {
        Write-Output "> Removing selected apps..."
        $appsList = ReadAppslistFromFile $script:CustomAppsListFilePath

        if ($appsList.Count -eq 0) {
            Write-Host "No valid apps were selected for removal" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        Write-Output "$($appsList.Count) apps selected for removal"
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
    'DisableGameBarIntegration' {
        RegImport "> Disabling Game Bar integration..." "Disable_Game_Bar_Integration.reg"
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
        if ($WinVersion -lt 22000) {
            Write-Output "> Disabling Windows Recall..."
            Write-Host "Feature is not available on Windows 10" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        RegImport "> Disabling Windows Recall..." "Disable_AI_Recall.reg"
        continue
    }
    'DisableClickToDo' {
        if ($WinVersion -lt 22000) {
            Write-Output "> Disabling Click to Do..."
            Write-Host "Feature is not available on Windows 10" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

        RegImport "> Disabling Click to Do..." "Disable_Click_to_Do.reg"
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
        if (-not $script:ModernStandbySupported) {
            Write-Output "> Disabling network connectivity during Modern Standby..."
            Write-Host "Device does not support modern standby" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

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
    'CombineTaskbarAlways' {
        RegImport "> Setting the taskbar on the main display to always combine buttons and hide labels..." "Combine_Taskbar_Always.reg"
        continue
    }
    'CombineTaskbarWhenFull' {
        RegImport "> Setting the taskbar on the main display to only combine buttons and hide labels when the taskbar is full..." "Combine_Taskbar_When_Full.reg"
        continue
    }
    'CombineTaskbarNever' {
        RegImport "> Setting the taskbar on the main display to never combine buttons or hide labels..." "Combine_Taskbar_Never.reg"
        continue
    }
    'CombineMMTaskbarAlways' {
        RegImport "> Setting the taskbar on secondary displays to always combine buttons and hide labels..." "Combine_MMTaskbar_Always.reg"
        continue
    }
    'CombineMMTaskbarWhenFull' {
        RegImport "> Setting the taskbar on secondary displays to only combine buttons and hide labels when the taskbar is full..." "Combine_MMTaskbar_When_Full.reg"
        continue
    }
    'CombineMMTaskbarNever' {
        RegImport "> Setting the taskbar on secondary displays to never combine buttons or hide labels..." "Combine_MMTaskbar_Never.reg"
        continue
    }
    'MMTaskbarModeAll' {
        RegImport "> Setting the taskbar to only show app icons on main taskbar..." "MMTaskbarMode_All.reg"
        continue
    }
    'MMTaskbarModeMainActive' {
        RegImport "> Setting the taskbar to show app icons on all taskbars..." "MMTaskbarMode_Main_Active.reg"
        continue
    }
    'MMTaskbarModeActive' {
        RegImport "> Setting the taskbar to only show app icons on the taskbar where the window is open..." "MMTaskbarMode_Active.reg"
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
        if ($WinVersion -ge 22000) {
            Write-Output "> Hiding the chat icon from the taskbar..."
            Write-Host "Feature is not available on Windows 11" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

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
    'AddFoldersToThisPC' {
        RegImport "> Adding all common folders (Desktop, Downloads, etc.) back to `This PC` in File Explorer..." "Add_All_Folders_Under_This_PC.reg"
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
    'HideOnedrive' {
        RegImport "> Hiding the OneDrive folder from the File Explorer navigation pane..." "Hide_Onedrive_Folder.reg"
        continue
    }    
    'DisableOnedrive' {
        RegImport "> Disabling OneDrive-Install for new users..." "Uninstall_Microsoft_Onedrive.reg"
        continue
    }
    {$_ -in "Hide3dObjects", "Disable3dObjects"} {
        if ($WinVersion -ge 22000) {
            Write-Output "> Hiding the 3D objects folder from the File Explorer navigation pane..."
            Write-Host "Feature is not available on Windows 11" -ForegroundColor Yellow
            Write-Output ""
            continue
        }

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
