#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(ValueFromPipeline = $true)][switch]$Silent,
    [Parameter(ValueFromPipeline = $true)][switch]$RunDefaults,
    [Parameter(ValueFromPipeline = $true)][switch]$RunWin11Defaults,
    [Parameter(ValueFromPipeline = $true)][switch]$RemoveApps,
    [Parameter(ValueFromPipeline = $true)][switch]$RemoveGamingApps,
    [Parameter(ValueFromPipeline = $true)][switch]$RemoveCommApps,
    [Parameter(ValueFromPipeline = $true)][switch]$RemoveDevApps,
    [Parameter(ValueFromPipeline = $true)][switch]$RemoveW11Outlook,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableTelemetry,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableBingSearches,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableBing,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableLockscrTips,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableLockscreenTips,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableWindowsSuggestions,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableSuggestions,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowHiddenFolders,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowKnownFileExt,
    [Parameter(ValueFromPipeline = $true)][switch]$HideDupliDrive,
    [Parameter(ValueFromPipeline = $true)][switch]$TaskbarAlignLeft,
    [Parameter(ValueFromPipeline = $true)][switch]$HideSearchTb,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowSearchIconTb,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowSearchLabelTb,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowSearchBoxTb,
    [Parameter(ValueFromPipeline = $true)][switch]$HideTaskview,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableCopilot,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableWidgets,
    [Parameter(ValueFromPipeline = $true)][switch]$HideWidgets,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableChat,
    [Parameter(ValueFromPipeline = $true)][switch]$HideChat,
    [Parameter(ValueFromPipeline = $true)][switch]$ClearStart,
    [Parameter(ValueFromPipeline = $true)][switch]$RevertContextMenu,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableOnedrive,
    [Parameter(ValueFromPipeline = $true)][switch]$HideOnedrive,
    [Parameter(ValueFromPipeline = $true)][switch]$Disable3dObjects,
    [Parameter(ValueFromPipeline = $true)][switch]$Hide3dObjects,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableMusic,
    [Parameter(ValueFromPipeline = $true)][switch]$HideMusic,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableIncludeInLibrary,
    [Parameter(ValueFromPipeline = $true)][switch]$HideIncludeInLibrary,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableGiveAccessTo,
    [Parameter(ValueFromPipeline = $true)][switch]$HideGiveAccessTo,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableShare,
    [Parameter(ValueFromPipeline = $true)][switch]$HideShare
)


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
    $initialFormWindowState = New-Object System.Windows.Forms.FormWindowState

    # saveButton eventHandler
    $handler_saveButton_Click= 
    {
        $global:SelectedApps = $selectionBox.CheckedItems

        # Create file that stores selected apps if it doesn't exist
        if (!(Test-Path "$PSScriptRoot/CustomAppsList")) {
            $null = New-Item "$PSScriptRoot/CustomAppsList"
        } 

        Set-Content -Path "$PSScriptRoot/CustomAppsList" -Value $global:SelectedApps

        $form.Close()
    }

    # cancelButton eventHandler
    $handler_cancelButton_Click= 
    {
        $form.Close()
    }

    $load_Apps=
    {
        # Correct the initial state of the form to prevent the .Net maximized form issue
        $form.WindowState = $initialFormWindowState

        # Show loading indicator
        $loadingLabel.Visible = $true
        $form.Refresh()

        # Clear selectionBox before adding any new items
        $selectionBox.Items.Clear()

        # Set filePath where Appslist can be found
        $appsFile = "$PSScriptRoot/Appslist.txt"

        # Go through appslist and add items one by one to the selectionBox
        Foreach ($app in (Get-Content -Path $appsFile | Where-Object { $_ -notmatch '^\s*$' } )) { 
            $appChecked = $true

            # Remove first # if it exists and set AppChecked to false
            if ($app.StartsWith('#')) {
                $app = $app.TrimStart("#")
                $appChecked = $false
            }
            # Remove any comments from the Appname
            if (-not ($app.IndexOf('#') -eq -1)) {
                $app = $app.Substring(0, $app.IndexOf('#'))
            }
            # Remove any remaining spaces from the Appname
            if (-not ($app.IndexOf(' ') -eq -1)) {
                $app = $app.Substring(0, $app.IndexOf(' '))
            }

            $appString = $app.Trim('*')

            # Make sure appString is not empty
            if ($appString.length -gt 0) {
                if($onlyInstalledCheckBox.Checked) {
                    # onlyInstalledCheckBox is checked, check if app is installed before adding to selectionBox
                    $installed = Get-AppxPackage -Name $app

                    if($installed.length -eq 0) {
                        # App is not installed, continue to next item without adding this app to the selectionBox
                        continue
                    }
                }

                # Add the app to the selectionBox and set it's checked status
                $selectionBox.Items.Add($appString, $appChecked) | Out-Null
            }
        }
        
        # Hide loading indicator
        $loadingLabel.Visible = $false

        # Sort selectionBox alphabetically
        $selectionBox.Sorted = $true;
    }

    $form.Text = "Win11Debloat Application Selection"
    $form.Name = "appSelectionForm"
    $form.DataBindings.DefaultDataSourceUpdateMode = 0
    $form.ClientSize = New-Object System.Drawing.Size(400,485)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false

    $button1.TabIndex = 4
    $button1.Name = "saveButton"
    $button1.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $button1.UseVisualStyleBackColor = $True
    $button1.Text = "Save"
    $button1.Location = New-Object System.Drawing.Point(27,454)
    $button1.Size = New-Object System.Drawing.Size(75,23)
    $button1.DataBindings.DefaultDataSourceUpdateMode = 0
    $button1.add_Click($handler_saveButton_Click)

    $form.Controls.Add($button1)

    $button2.TabIndex = 5
    $button2.Name = "cancelButton"
    $button2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $button2.UseVisualStyleBackColor = $True
    $button2.Text = "Cancel"
    $button2.Location = New-Object System.Drawing.Point(129,454)
    $button2.Size = New-Object System.Drawing.Size(75,23)
    $button2.DataBindings.DefaultDataSourceUpdateMode = 0
    $button2.add_Click($handler_cancelButton_Click)

    $form.Controls.Add($button2)

    $label.Location = New-Object System.Drawing.Point(13,5)
    $label.Size = New-Object System.Drawing.Size(400,20)
    $label.Text = 'Check apps that you wish to remove, uncheck apps that you wish to keep'

    $form.Controls.Add($label)

    $loadingLabel.Location = New-Object System.Drawing.Point(16,28)
    $loadingLabel.Size = New-Object System.Drawing.Size(200,418)
    $loadingLabel.Text = 'Loading...'
    $loadingLabel.BackColor = "White"
    $loadingLabel.Visible = $false

    $form.Controls.Add($loadingLabel)

    $onlyInstalledCheckBox.TabIndex = 6
    $onlyInstalledCheckBox.Location = New-Object System.Drawing.Point(230,456)
    $onlyInstalledCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $onlyInstalledCheckBox.Text = 'Only show installed apps'
    $onlyInstalledCheckBox.add_CheckedChanged($load_Apps)

    $form.Controls.Add($onlyInstalledCheckBox)

    $selectionBox.FormattingEnabled = $True
    $selectionBox.DataBindings.DefaultDataSourceUpdateMode = 0
    $selectionBox.Name = "selectionBox"
    $selectionBox.Location = New-Object System.Drawing.Point(13,25)
    $selectionBox.Size = New-Object System.Drawing.Size(374,424)
    $selectionBox.TabIndex = 3

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


# Reads list of apps from file and removes them for all user accounts and from the OS image.
function RemoveApps {
    param (
        $appsFile,
        $message
    )

    Write-Output $message

    # Get list of apps from file at the path provided, and remove them one by one
    Foreach ($app in (Get-Content -Path $appsFile | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) { 
        # Remove any spaces before and after the Appname
        $app = $app.Trim()

        # Remove any comments from the Appname
        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }
        # Remove any remaining spaces from the Appname
        if (-not ($app.IndexOf(' ') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf(' '))
        }
        
        $appString = $app.Trim('*')
        Write-Output "Attempting to remove $appString..."

        # Remove installed app for all existing users
        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage

        # Remove provisioned app from OS image, so the app won't be installed for any new users
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
    }

    Write-Output ""
}


# Removes apps specified during function call from all user accounts and from the OS image.
function RemoveSpecificApps {
    param (
        $appslist
    )

    Foreach ($app in $appsList) { 
        Write-Output "Attempting to remove $app..."

        $app = '*' + $app + '*'

        # Remove installed app for all existing users
        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage

        # Remove provisioned app from OS image, so the app won't be installed for any new users
        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
    }
}


# Import & execute regfile
function RegImport {
    param (
        $message,
        $path
    )

    Write-Output $message
    reg import $path
    Write-Output ""
}


# Stop & Restart the Windows explorer process
function RestartExplorer {
    Write-Output "> Restarting Windows explorer to apply all changes. Note: This may cause some flickering."

    Start-Sleep 0.5

    taskkill /f /im explorer.exe

    Start-Process explorer.exe

    Write-Output ""
}


# Clear all pinned apps from the start menu. 
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ClearStartMenu {
    param (
        $message
    )

    Write-Output $message

    # Path to start menu template
    $startmenuTemplate = "$PSScriptRoot/Start/start2.bin"

    # Get all user profile folders
    $usersStartMenu = get-childitem -path "C:\Users\*\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"

    # Copy Start menu to all users folders
    ForEach ($startmenu in $usersStartMenu) {
        $startmenuBinFile = $startmenu.Fullname + "\start2.bin"

        # Check if bin file exists
        if(Test-Path $startmenuBinFile) {
            Copy-Item -Path $startmenuTemplate -Destination $startmenu -Force

            $cpyMsg = "Replaced start menu for user " + $startmenu.Fullname.Split("\")[2]
            Write-Output $cpyMsg
        }
        else {
            # Bin file doesn't exist, indicating the user is not running the correct version of Windows. Exit function
            Write-Output "Error: Start menu file not found. Please make sure you're running Windows 11 22H2 or later"
            return
        }
    }

    # Also apply start menu template to the default profile

    # Path to default profile
    $defaultProfile = "C:\Users\default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"

    # Create folder if it doesn't exist
    if (-not(Test-Path $defaultProfile)) {
        new-item $defaultProfile -ItemType Directory -Force | Out-Null
        Write-Output "Created LocalState folder for default user"
    }

    # Copy template to default profile
    Copy-Item -Path $startmenuTemplate -Destination $defaultProfile -Force
    Write-Output "Copied start menu template to default user folder"
    Write-Output ""
}


# Add parameter to script and write to file
function AddParameter {
    param (
        $parameterName,
        $message
    )

    # Add key if it doesn't already exist
    if (-not $global:Params.ContainsKey($parameterName)) {
        $global:Params.Add($parameterName, $true)
    }

    # Create or clear file that stores last used settings
    if (!(Test-Path "$PSScriptRoot/LastSettings")) {
        $null = New-Item "$PSScriptRoot/LastSettings"
    } 
    elseif ($global:FirstSelection) {
        $null = Clear-Content "$PSScriptRoot/LastSettings"
    }
    
    $global:FirstSelection = $false

    # Create entry and add it to the file
    $entry = $parameterName + "#- " + $message
    Add-Content -Path "$PSScriptRoot/LastSettings" -Value $entry
}


function PrintHeader {
    param (
        $title
    )

    $fullTitle = " Win11Debloat Script - " + $title

    Clear-Host
    Write-Output "-------------------------------------------------------------------------------------------"
    Write-Output $fullTitle
    Write-Output "-------------------------------------------------------------------------------------------"
}


function PrintFromFile {
    param (
        $path
    )

    Clear-Host

    # Get & print script menu from file
    Foreach ($line in (Get-Content -Path $path )) {   
        Write-Output $line
    }
}


# Hide progress bars for app removal, as they block Win11Debloat's output
$ProgressPreference = 'SilentlyContinue'

$global:Params = $PSBoundParameters;
$global:FirstSelection = $true
$SPParams = 'WhatIf', 'Confirm', 'Verbose', 'Silent'
$SPParamCount = 0

# Count how many SPParams exist within Params
foreach ($Param in $SPParams) {
    if ($global:Params.ContainsKey($Param)) {
        $SPParamCount++
    }
}

# Remove LastSetting file if it's empty
if ((Test-Path "$PSScriptRoot/LastSettings") -and ([String]::IsNullOrWhiteSpace((Get-content "$PSScriptRoot/LastSettings")))) {
    Remove-Item -Path "$PSScriptRoot/LastSettings" -recurse
}

# Change script execution based on provided parameters or user input
if ((-not $global:Params.Count) -or $RunDefaults -or $RunWin11Defaults -or ($SPParamCount -eq $global:Params.Count)) {
    if ($RunDefaults -or $RunWin11Defaults) {
        $Mode = '1';
    }
    else {
        # Show menu and wait for user input, loops until valid input is provided
        Do { 
            $ModeSelectionMessage = "Please select an option (1/2/0)" 

            # Get & print script menu from file
            PrintFromFile "$PSScriptRoot/Menus/Menu"

            # Only show this option if LastSettings file exists
            if (Test-Path "$PSScriptRoot/LastSettings") {
                Write-Output "(3) New: Run the script with the settings from last time"
                $ModeSelectionMessage = "Please select an option (1/2/3/0)" 
            }

            Write-Output ""
            Write-Output "(0) Show information about the script"
            Write-Output ""
            Write-Output ""

            $Mode = Read-Host $ModeSelectionMessage

            # Show information based on user input, Suppress user prompt if Silent parameter was passed
            if ($Mode -eq '0') {
                # Get & print script information from file
                PrintFromFile "$PSScriptRoot/Menus/Info"

                Write-Output "Press any key to go back..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            elseif (-not $Silent -and ($Mode -eq '1')) {
                # Get & print default settings info from file
                PrintFromFile "$PSScriptRoot/Menus/DefaultSettings"

                Write-Output "Press enter to execute the script or press CTRL+C to quit..."
                Read-Host | Out-Null
            }
            elseif (($Mode -eq '3')) {
                if (Test-Path "$PSScriptRoot/LastSettings") {
                    if(-not $Silent) {
                        PrintHeader 'Setup'
                        Write-Output "Win11Debloat will make the following changes:"

                        # Get & print default settings info from file
                        Foreach ($line in (Get-Content -Path "$PSScriptRoot/LastSettings" )) { 
                            # Remove any spaces before and after the Appname
                            $line = $line.Trim()
                        
                            # Check if line has # char, show description, add parameter
                            if (-not ($line.IndexOf('#') -eq -1)) {
                                Write-Output $line.Substring(($line.IndexOf('#') + 1), ($line.Length - $line.IndexOf('#') - 1))
                                $paramName = $line.Substring(0, $line.IndexOf('#'))

                                # Print list of apps slated for removal if paramName is RemoveAppsCustom and CustomAppsList exists
                                if(($paramName -eq "RemoveAppsCustom") -and (Test-Path "$PSScriptRoot/CustomAppsList")) {
                                    $appsList = @()

                                    # Get apps list from file
                                    Foreach ($app in (Get-Content -Path "$PSScriptRoot/CustomAppsList" )) { 
                                        # Remove any spaces before and after the app name
                                        $app = $app.Trim()

                                        $appsList += $app
                                    }

                                    Write-Host $appsList -ForegroundColor Gray
                                }

                                if(-not $global:Params.ContainsKey($ParameterName)){
                                    $global:Params.Add($paramName, $true)
                                }
                            }
                        }

                        Write-Output ""
                        Write-Output "Press enter to execute the script or press CTRL+C to quit..."
                        Read-Host | Out-Null
                    }
                } 
                else {
                    $Mode = $null;
                }
            }
        }
        while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3') 
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, no user input required, all (relevant) options are added
        '1' { 
            $DefaultParameterNames = 'RemoveApps','DisableTelemetry','DisableBing','DisableLockscreenTips','DisableSuggestions','ShowKnownFileExt','DisableWidgets','HideChat','DisableCopilot'

            PrintHeader 'Default Configuration'

            # Add default parameters if they don't already exist
            foreach ($ParameterName in $DefaultParameterNames) {
                if(-not $global:Params.ContainsKey($ParameterName)){
                    $global:Params.Add($ParameterName, $true)
                }
            }

            # Only add this option for Windows 10 users, if it doesn't already exist
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -and (-not $global:Params.ContainsKey('Hide3dObjects'))) {
                $global:Params.Add('Hide3dObjects', $Hide3dObjects)
            }
        }

        # Custom mode, add options based on user input
        '2' { 
            # Get current Windows build version to compare against features
            $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

            PrintHeader 'Custom Configuration'

            # Show options for removing apps, only continue on valid input
            Do {
                Write-Host "Options:" -ForegroundColor Yellow
                Write-Host " (n) Don't remove any apps" -ForegroundColor Yellow
                Write-Host " (1) Only remove the default selection of bloatware apps from 'Appslist.txt'" -ForegroundColor Yellow
                Write-Host " (2) Remove default selection of bloatware apps, aswell as mail & calendar apps, developer apps and gaming apps"  -ForegroundColor Yellow
                Write-Host " (3) Specify which apps to remove and which to keep" -ForegroundColor Yellow
                $RemoveCommAppInput = Read-Host "Remove any pre-installed apps? (n/1/2/3)" 

                # Show app selection form if user entered option 3
                if ($RemoveCommAppInput -eq '3') {
                    $result = ShowAppSelectionForm

                    if($result -ne [System.Windows.Forms.DialogResult]::OK) {
                        # User cancelled or closed app selection, show error and change RemoveCommAppInput so the menu will be shown again
                        Write-Output ""
                        Write-Host "Cancelled application selection, please try again" -ForegroundColor Red

                        $RemoveCommAppInput = 'c'
                    }
                    
                    Write-Output ""
                }
            }
            while ($RemoveCommAppInput -ne 'n' -and $RemoveCommAppInput -ne '0' -and $RemoveCommAppInput -ne '1' -and $RemoveCommAppInput -ne '2' -and $RemoveCommAppInput -ne '3') 

            # Select correct option based on user input
            switch ($RemoveCommAppInput) {
                '1' {
                    AddParameter 'RemoveApps' 'Remove default selection of bloatware apps'
                }
                '2' {
                    AddParameter 'RemoveApps' 'Remove default selection of bloatware apps'
                    AddParameter 'RemoveCommApps' 'Remove the Mail, Calender, and People apps'
                    AddParameter 'RemoveW11Outlook' 'Remove the new Outlook for Windows app'
                    AddParameter 'RemoveDevApps' 'Remove developer-related apps'
                    AddParameter 'RemoveGamingApps' 'Remove the Xbox App and Xbox Gamebar'
                }
                '3' {
                    Write-Output "$($global:SelectedApps.Count) apps have been selected for removal"

                    AddParameter 'RemoveAppsCustom' "Remove $($global:SelectedApps.Count) apps:"
                }
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($( Read-Host -Prompt "Remove all pinned apps from the start menu? This applies to all existing and new users and can't be reverted (y/n)" ) -eq 'y') {
                    AddParameter 'ClearStart' 'Remove all pinned apps from the start menu for new and existing users'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable telemetry, diagnostic data, app-launch tracking and targeted ads? (y/n)" ) -eq 'y') {
                AddParameter 'DisableTelemetry' 'Disable telemetry, diagnostic data & targeted ads'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable & remove bing search, bing AI & cortana in Windows search? (y/n)" ) -eq 'y') {
                AddParameter 'DisableBing' 'Disable & remove bing search, bing AI & cortana in Windows search'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable tips, tricks, suggestions and ads in start, settings, notifications, explorer and lockscreen? (y/n)" ) -eq 'y') {
                AddParameter 'DisableSuggestions' 'Disable tips, tricks, suggestions and ads in start, settings, notifications and Windows explorer'
                AddParameter 'DisableLockscreenTips' 'Disable tips & tricks on the lockscreen'
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($( Read-Host -Prompt "Disable Windows Copilot? This applies to all users (y/n)" ) -eq 'y') {
                    AddParameter 'DisableCopilot' 'Disable Windows copilot'
                }
            }

            # Only show this option for Windows 11 users running build 22000 or later
            if ($WinVersion -ge 22000){
                Write-Output ""

                if ($( Read-Host -Prompt "Restore the old Windows 10 style context menu? (y/n)" ) -eq 'y') {
                    AddParameter 'RevertContextMenu' 'Restore the old Windows 10 style context menu'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Do you want to make any changes to the taskbar and related services? (y/n)" ) -eq 'y') {
                # Only show these specific options for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
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

                if ($( Read-Host -Prompt "   Disable the widgets service and hide the icon from the taskbar? (y/n)" ) -eq 'y') {
                    AddParameter 'DisableWidgets' 'Disable the widget service & hide the widget (news and interests) icon from the taskbar'
                }

                # Only show this options for Windows users running build 22621 or earlier
                if ($WinVersion -le 22621){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the chat (meet now) icon from the taskbar? (y/n)" ) -eq 'y') {
                        AddParameter 'HideChat' 'Hide the chat (meet now) icon from the taskbar'
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Do you want to make any changes to Windows explorer? (y/n)" ) -eq 'y') {
                Write-Output ""

                if ($( Read-Host -Prompt "   Show hidden files, folders and drives? (y/n)" ) -eq 'y') {
                    AddParameter 'ShowHiddenFolders' 'Show hidden files, folders and drives'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Show file extensions for known file types? (y/n)" ) -eq 'y') {
                    AddParameter 'ShowKnownFileExt' 'Show file extensions for known file types'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Hide duplicate removable drive entries from the Windows explorer sidepane so they only show under This PC? (y/n)" ) -eq 'y') {
                    AddParameter 'HideDupliDrive' 'Hide duplicate removable drive entries from the Windows explorer navigation pane'
                }

                # Only show option for disabling these specific folders for Windows 10 users
                if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
                    Write-Output ""

                    if ($( Read-Host -Prompt "Do you want to hide any folders from the Windows explorer sidepane? (y/n)" ) -eq 'y') {
                        Write-Output ""

                        if ($( Read-Host -Prompt "   Hide the onedrive folder from the Windows explorer sidepane? (y/n)" ) -eq 'y') {
                            AddParameter 'HideOnedrive' 'Hide the onedrive folder in the Windows explorer sidepanel'
                        }

                        Write-Output ""
                        
                        if ($( Read-Host -Prompt "   Hide the 3D objects folder from the Windows explorer sidepane? (y/n)" ) -eq 'y') {
                            AddParameter 'Hide3dObjects' "Hide the 3D objects folder under 'This pc' in Windows explorer" 
                        }
                        
                        Write-Output ""

                        if ($( Read-Host -Prompt "   Hide the music folder from the Windows explorer sidepane? (y/n)" ) -eq 'y') {
                            AddParameter 'HideMusic' "Hide the music folder under 'This pc' in Windows explorer"
                        }
                    }
                }
            }

            # Only show option for disabling context menu items for Windows 10 users
            if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
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

            # Suppress prompt if Silent parameter was passed
            if (-not $Silent) {
                Write-Output ""
                Write-Output ""
                Write-Output ""
                Write-Output "Press enter to confirm your choices and execute the script or press CTRL+C to quit..."
                Read-Host | Out-Null
            }

            PrintHeader 'Custom Configuration'
        }

        # Run with options from last time, loaded from 'LastSettings' file
        '3' {
            PrintHeader 'Custom Configuration'
        }
    }
}
else {
    PrintHeader 'Custom Configuration'
}


# If the number of keys in SPParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if ($SPParamCount -eq $global:Params.Keys.Count) {
    Write-Output "The script completed without making any changes."
    
    # Suppress prompt if Silent parameter was passed
    if(-not $Silent) {
        Write-Output ""
        Write-Output "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
else {
    # Execute all selected/provided parameters
    switch ($global:Params.Keys) {
        'RemoveApps' {
            RemoveApps "$PSScriptRoot/Appslist.txt" "> Removing pre-installed Windows bloatware..."
            continue
        }
        'RemoveAppsCustom' {
            if (Test-Path "$PSScriptRoot/CustomAppsList") {
                $appsList = @()

                # Get apps list from file
                Foreach ($app in (Get-Content -Path "$PSScriptRoot/CustomAppsList" )) { 
                    # Remove any spaces before and after the app name
                    $app = $app.Trim()

                    $appsList += $app
                }

                Write-Output "> Removing $($appsList.Count) apps..."
                RemoveSpecificApps $appsList
            }
            else {
                Write-Host "> Unable to find CustomAppsList file, no apps have been removed!" -ForegroundColor Red
            }

            Write-Output ""
            continue
        }
        'RemoveCommApps' {
            Write-Output "> Removing Mail, Calendar and People apps..."
            
            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
            RemoveSpecificApps $appsList

            Write-Output ""
            continue
        }
        'RemoveW11Outlook' {
            Write-Output "> Removing new Outlook for Windows app..."
            
            $appsList = 'Microsoft.OutlookForWindows'
            RemoveSpecificApps $appsList

            Write-Output ""
            continue
        }
        'RemoveDevApps' {
            Write-Output "> Removing developer-related related apps..."

            $appsList = 'Microsoft.PowerAutomateDesktop', 'Microsoft.RemoteDesktop', 'Windows.DevHome'
            RemoveSpecificApps $appsList

            Write-Output ""

            continue
        }
        'RemoveGamingApps' {
            Write-Output "> Removing gaming related apps..."

            $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
            RemoveSpecificApps $appsList

            Write-Output ""

            continue
        }
        'ClearStart' {
            ClearStartMenu "> Removing all pinned apps from the start menu..."
            continue
        }
        'DisableTelemetry' {
            RegImport "> Disabling telemetry, diagnostic data, app-launch tracking and targeted ads..." $PSScriptRoot\Regfiles\Disable_Telemetry.reg
            continue
        }
        {$_ -in "DisableBingSearches", "DisableBing"} {
            RegImport "> Disabling bing search, bing AI & cortana in Windows search..." $PSScriptRoot\Regfiles\Disable_Bing_Cortana_In_Search.reg
            
            # Also remove the app package for bing search
            $appsList = 'Microsoft.BingSearch'
            RemoveSpecificApps $appsList

            Write-Output ""

            continue
        }
        {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
            RegImport "> Disabling tips & tricks on the lockscreen..." $PSScriptRoot\Regfiles\Disable_Lockscreen_Tips.reg
            continue
        }
        {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
            RegImport "> Disabling tips, tricks, suggestions and ads across Windows..." $PSScriptRoot\Regfiles\Disable_Windows_Suggestions.reg
            continue
        }
        'RevertContextMenu' {
            RegImport "> Restoring the old Windows 10 style context menu..." $PSScriptRoot\Regfiles\Disable_Show_More_Options_Context_Menu.reg
            continue
        }
        'TaskbarAlignLeft' {
            RegImport "> Aligning taskbar buttons to the left..." $PSScriptRoot\Regfiles\Align_Taskbar_Left.reg
            continue
        }
        'HideSearchTb' {
            RegImport "> Hiding the search icon from the taskbar..." $PSScriptRoot\Regfiles\Hide_Search_Taskbar.reg
            continue
        }
        'ShowSearchIconTb' {
            RegImport "> Changing taskbar search to icon only..." $PSScriptRoot\Regfiles\Show_Search_Icon.reg
            continue
        }
        'ShowSearchLabelTb' {
            RegImport "> Changing taskbar search to icon with label..." $PSScriptRoot\Regfiles\Show_Search_Icon_And_Label.reg
            continue
        }
        'ShowSearchBoxTb' {
            RegImport "> Changing taskbar search to search box..." $PSScriptRoot\Regfiles\Show_Search_Box.reg
            continue
        }
        'HideTaskview' {
            RegImport "> Hiding the taskview button from the taskbar..." $PSScriptRoot\Regfiles\Hide_Taskview_Taskbar.reg
            continue
        }
        'DisableCopilot' {
            RegImport "> Disabling Windows copilot..." $PSScriptRoot\Regfiles\Disable_Copilot.reg
            continue
        }
        {$_ -in "HideWidgets", "DisableWidgets"} {
            RegImport "> Disabling the widget service and hiding the widget icon from the taskbar..." $PSScriptRoot\Regfiles\Disable_Widgets_Taskbar.reg
            continue
        }
        {$_ -in "HideChat", "DisableChat"} {
            RegImport "> Hiding the chat icon from the taskbar..." $PSScriptRoot\Regfiles\Disable_Chat_Taskbar.reg
            continue
        }
        'ShowHiddenFolders' {
            RegImport "> Unhiding hidden files, folders and drives..." $PSScriptRoot\Regfiles\Show_Hidden_Folders.reg
            continue
        }
        'ShowKnownFileExt' {
            RegImport "> Enabling file extensions for known file types..." $PSScriptRoot\Regfiles\Show_Extensions_For_Known_File_Types.reg
            continue
        }
        'HideDupliDrive' {
            RegImport "> Hiding duplicate removable drive entries from the Windows explorer navigation pane..." $PSScriptRoot\Regfiles\Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg
            continue
        }
        {$_ -in "HideOnedrive", "DisableOnedrive"} {
            RegImport "> Hiding the onedrive folder from the Windows explorer navigation pane..." $PSScriptRoot\Regfiles\Hide_Onedrive_Folder.reg
            continue
        }
        {$_ -in "Hide3dObjects", "Disable3dObjects"} {
            RegImport "> Hiding the 3D objects folder from the Windows explorer navigation pane..." $PSScriptRoot\Regfiles\Hide_3D_Objects_Folder.reg
            continue
        }
        {$_ -in "HideMusic", "DisableMusic"} {
            RegImport "> Hiding the music folder from the Windows explorer navigation pane..." $PSScriptRoot\Regfiles\Hide_Music_folder.reg
            continue
        }
        {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
            RegImport "> Hiding 'Include in library' in the context menu..." $PSScriptRoot\Regfiles\Disable_Include_in_library_from_context_menu.reg
            continue
        }
        {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
            RegImport "> Hiding 'Give access to' in the context menu..." $PSScriptRoot\Regfiles\Disable_Give_access_to_context_menu.reg
            continue
        }
        {$_ -in "HideShare", "DisableShare"} {
            RegImport "> Hiding 'Share' in the context menu..." $PSScriptRoot\Regfiles\Disable_Share_from_context_menu.reg
            continue
        }
    }

    RestartExplorer

    Write-Output ""
    Write-Output ""
    Write-Output "Script completed successfully!"

    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
