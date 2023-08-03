#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param 
(
    [Parameter(ValueFromPipeline = $true)][switch]$RunDefaults,
    [Parameter(ValueFromPipeline = $true)][switch]$RunWin11Defaults,
    [Parameter(ValueFromPipeline = $true)][switch]$RemoveApps,
    [Parameter(ValueFromPipeline = $true)][switch]$RemoveGamingApps,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableTelemetry,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableBingSearches,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableBing,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableLockscreenTips,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableWindowsSuggestions,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableSuggestions,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowHiddenFolders,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowKnownFileExt,
    [Parameter(ValueFromPipeline = $true)][switch]$TaskbarAlignLeft,
    [Parameter(ValueFromPipeline = $true)][switch]$HideSearchTb,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowSearchIconTb,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowSearchLabelTb,
    [Parameter(ValueFromPipeline = $true)][switch]$ShowSearchBoxTb,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableWidgets,
    [Parameter(ValueFromPipeline = $true)][switch]$HideWidgets,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableChat,
    [Parameter(ValueFromPipeline = $true)][switch]$HideChat,
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

# Removes all apps in the list
function RemoveApps {
    param(
        $appsFile,
        $message
    )

    Write-Output $message

    Foreach ($app in (Get-Content -Path $appsFile | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) 
    { 
        $app = $app.Trim()

        if (-Not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }
        if (-Not ($app.IndexOf(' ') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf(' '))
        }
        
        Write-Output "Attempting to remove $app"

        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage

        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
    }
}

# Import & execute regfile
function RegImport {
    param 
    (
        $Message,
        $Path
    )

    Write-Output $Message
    reg import $path
}

# Change mode based on provided parameters or user input
if ((-NOT $PSBoundParameters.Count) -or $RunDefaults -or $RunWin11Defaults -or (($PSBoundParameters.Count -eq 1) -and ($PSBoundParameters.ContainsKey('WhatIf') -or $PSBoundParameters.ContainsKey('Confirm') -or $PSBoundParameters.ContainsKey('Verbose')))) {
    if ($RunDefaults -or $RunWin11Defaults) {
        $Mode = '1';
    }
    else {
        Do { 
            Clear-Host
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output " Win11Debloat Script - Setup"
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output "(1) Run Win11Debloat with the default settings"
            Write-Output "(2) Custom mode: Select which changes you want Win11Debloat to make"
            Write-Output ""
            Write-Output "(0) Show information about the script"
            Write-Output ""
            Write-Output ""
            $Mode = Read-Host "Please select an option (1/2/0)" 

            if ($Mode -eq '0') {
                Clear-Host
                Write-Output "-------------------------------------------------------------------------------------------"
                Write-Output " Win11Debloat - Information"
                Write-Output "-------------------------------------------------------------------------------------------"
                Write-Output "Win11Debloat is a simple and lightweight powershell script that removes pre-installed"
                Write-Output "windows bloatware apps, disables telemetry and declutters the experience by disabling"
                Write-Output "or removing intrusive interface elements, ads and context menu items. No need to"
                Write-Output "painstakingly go through all the settings yourself, or removing apps one by one!"
                Write-Output ""
                Write-Output "-------------------------------------------------------------------------------------------"
                Write-Output " The default settings will"
                Write-Output "-------------------------------------------------------------------------------------------"
                Write-Output "- Remove bloatware apps, the list can be found in the 'Appslist.txt' file."
                Write-Output "- Disable telemetry, diagnostic data & targeted ads."
                Write-Output "- Disable bing search & cortana in windows search."
                Write-Output "- Disable tips & tricks on the lockscreen. (This may change your lockscreen wallpaper to the default)"
                Write-Output "- Disable tips, tricks and suggestions in the start menu and settings, and ads in windows explorer."
                Write-Output "- Show file extensions for known file types."
                Write-Output "- Disable the widget service & hide the widget (news and interests) icon from the taskbar. "
                Write-Output "- Hide the Chat (meet now) icon from the taskbar."
                Write-Output "- Hide the 3D objects folder in windows explorer. (Windows 10 only)"
                Write-Output ""
                Write-Output "-------------------------------------------------------------------------------------------"
                Write-Output " The custom mode has more options, in custom mode you can"
                Write-Output "-------------------------------------------------------------------------------------------"
                Write-Output "- Remove bloatware apps, the list can be found in the 'Appslist.txt' file."
                Write-Output "- Remove gaming-related apps, the list can be found in the 'GamingAppslist.txt' file."
                Write-Output "- Disable telemetry, diagnostic data & targeted ads."
                Write-Output "- Disable bing search & cortana in windows search."
                Write-Output "- Disable tips & tricks on the lockscreen. (This may change your lockscreen wallpaper to the default)"
                Write-Output "- Disable tips, tricks and suggestions in the start menu and settings, and ads in windows explorer."
                Write-Output "- Show hidden files, folders and drives."
                Write-Output "- Show file extensions for known file types."
                Write-Output "- Align taskbar icons to the left. (Windows 11 only)"
                Write-Output "- Hide or change the search icon/box on the taskbar. (Windows 11 only)"
                Write-Output "- Disable the widget service & hide the widget (news and interests) icon from the taskbar. "
                Write-Output "- Hide the Chat (meet now) icon from the taskbar."
                Write-Output "- Hide the 3D objects, music or onedrive folders in windows explorer. (Windows 10 only)"
                Write-Output "- Hide the 'Include in library', 'Give access to' and 'Share' options in the context menu. (Windows 10 only)"
                Write-Output ""
                Write-Output ""
                Write-Output "Press any key to go back..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        while ($Mode -ne '1' -and $Mode -ne '2') 
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        '1' { 
            Clear-Host
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output " Win11Debloat Script - Windows 10 Default Configuration"
            Write-Output "-------------------------------------------------------------------------------------------"
            $PSBoundParameters.Add('RemoveApps', $RemoveApps) 
            $PSBoundParameters.Add('DisableTelemetry', $DisableTelemetry)  
            $PSBoundParameters.Add('DisableBing', $DisableBing) 
            $PSBoundParameters.Add('DisableLockscreenTips', $DisableLockscreenTips)  
            $PSBoundParameters.Add('DisableSuggestions', $DisableSuggestions)  
            $PSBoundParameters.Add('ShowKnownFileExt', $ShowKnownFileExt) 
            $PSBoundParameters.Add('DisableWidgets', $DisableWidgets) 
            $PSBoundParameters.Add('HideChat', $HideChat) 

            # Only add option for windows 10 users
            if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
                $PSBoundParameters.Add('Hide3dObjects', $Hide3dObjects)
            }
        }

        '2' { 
            Clear-Host
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output " Win11Debloat Script - Custom Configuration"
            Write-Output "-------------------------------------------------------------------------------------------"

            if ($( Read-Host -Prompt "Remove the pre-installed windows apps? (y/n)" ) -eq 'y') {
                $PSBoundParameters.Add('RemoveApps', $RemoveApps)   

                Write-Output ""

                if ($( Read-Host -Prompt "   Also remove gaming-related apps such as the Xbox App and Xbox Gamebar? (y/n)" ) -eq 'y') {
                    $PSBoundParameters.Add('RemoveGamingApps', $RemoveGamingApps)
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable telemetry, diagnostic data and targeted ads? (y/n)" ) -eq 'y') {
                $PSBoundParameters.Add('DisableTelemetry', $DisableTelemetry)   
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable bing search, bing AI & cortana in windows search? (y/n)" ) -eq 'y') {
                $PSBoundParameters.Add('DisableBing', $DisableBing)   
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable tips, tricks and suggestions in the start menu, settings and windows explorer? (y/n)" ) -eq 'y') {
                $PSBoundParameters.Add('DisableSuggestions', $DisableSuggestions)   
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Disable tips & tricks on the lockscreen? (y/n)" ) -eq 'y') {
                $PSBoundParameters.Add('DisableLockscreenTips', $DisableLockscreenTips)   
            } 

            Write-Output ""

            if ($( Read-Host -Prompt "Do you want to make any changes to the taskbar and start menu? (y/n)" ) -eq 'y') {
                # Only show option for taskbar alignment for windows 11 users
                if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 11%'"){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Align taskbar buttons to left side? (y/n)" ) -eq 'y') {
                        $PSBoundParameters.Add('TaskbarAlignLeft', $TaskbarAlignLeft)   
                    }

                    Do {
                        Write-Output ""
                        Write-Output "   Options:"
                        Write-Output "    (0) No change"
                        Write-Output "    (1) Hide search icon from the taskbar"
                        Write-Output "    (2) Show search icon on the taskbar"
                        Write-Output "    (3) Show search icon with label on the taskbar"
                        Write-Output "    (4) Show search box on the taskbar"
                        $TbSearchInput = Read-Host "   Hide or change the search icon on the taskbar? (0/1/2/3/4)" 
                    }
                    while ($TbSearchInput -ne 'n' -and $TbSearchInput -ne '0' -and $TbSearchInput -ne '1' -and $TbSearchInput -ne '2' -and $TbSearchInput -ne '3' -and $TbSearchInput -ne '4') 

                    # Select correct taskbar search option based on user input
                    switch ($TbSearchInput) {
                        '1' {
                            $PSBoundParameters.Add('HideSearchTb', $HideSearchTb) 
                        }
                        '2' {
                            $PSBoundParameters.Add('ShowSearchIconTb', $ShowSearchIconTb) 
                        }
                        '3' {
                            $PSBoundParameters.Add('ShowSearchLabelTb', $ShowSearchLabelTb) 
                        }
                        '4' {
                            $PSBoundParameters.Add('ShowSearchBoxTb', $ShowSearchBoxTb) 
                        }

                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Disable the widgets service and hide the widget (news and interests) icon from the taskbar? (y/n)" ) -eq 'y') {
                    $PSBoundParameters.Add('DisableWidgets', $DisableWidgets)   
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Hide the chat (meet now) icon from the taskbar? (y/n)" ) -eq 'y') {
                    $PSBoundParameters.Add('HideChat', $HideChat)   
                }
            }

            if ($( Read-Host -Prompt "Do you want to make any changes to windows explorer? (y/n)" ) -eq 'y') {
                Write-Output ""

                if ($( Read-Host -Prompt "   Show hidden files, folders and drives? (y/n)" ) -eq 'y') {
                    $PSBoundParameters.Add('ShowHiddenFolders', $ShowHiddenFolders)   
                }

                if ($( Read-Host -Prompt "   Show file extensions for known file types? (y/n)" ) -eq 'y') {
                    $PSBoundParameters.Add('ShowKnownFileExt', $ShowKnownFileExt)   
                }
            }

            # Only show option for disabling these specific folders for windows 10 users
            if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
                Write-Output ""

                if ($( Read-Host -Prompt "Do you want to hide any folders from the windows explorer sidepanel? (y/n)" ) -eq 'y') {
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the onedrive folder in windows explorer? (y/n)" ) -eq 'y') {
                        $PSBoundParameters.Add('HideOnedrive', $HideOnedrive)   
                    }

                    Write-Output ""
                    
                    if ($( Read-Host -Prompt "   Hide the 3D objects folder in windows explorer? (y/n)" ) -eq 'y') {
                        $PSBoundParameters.Add('Hide3dObjects', $Hide3dObjects)   
                    }
                    
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the music folder in windows explorer? (y/n)" ) -eq 'y') {
                        $PSBoundParameters.Add('HideMusic', $HideMusic)   
                    }
                }
            }

            # Only show option for disabling context menu items for windows 10 users
            if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
                Write-Output ""

                if ($( Read-Host -Prompt "Do you want to disable any context menu options? (y/n)" ) -eq 'y') {
                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the 'Include in library' option in the context menu? (y/n)" ) -eq 'y') {
                        $PSBoundParameters.Add('HideIncludeInLibrary', $HideIncludeInLibrary)   
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the 'Give access to' option in the context menu? (y/n)" ) -eq 'y') {
                        $PSBoundParameters.Add('HideGiveAccessTo', $HideGiveAccessTo)   
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Hide the 'Share' option in the context menu? (y/n)" ) -eq 'y') {
                        $PSBoundParameters.Add('HideShare', $HideShare)   
                    }
                }
            }

            Write-Output "" 
        }
    }
}
else {
    Clear-Host
    Write-Output "-------------------------------------------------------------------------------------------"
    Write-Output " Win11Debloat Script - Custom Configuration"
    Write-Output "-------------------------------------------------------------------------------------------"
}

# Execute all selected/provided parameters
switch ($PSBoundParameters.Keys) {
    'RemoveApps' {
        RemoveApps "$PSScriptRoot/Appslist.txt" "> Removing pre-installed windows apps..."
        Write-Output ""
        continue
    }
    'RemoveGamingApps' {
        RemoveApps "$PSScriptRoot/GamingAppslist.txt" "> Removing gaming-related windows apps..."
        Write-Output ""
        continue
    }
    'DisableTelemetry' {
        RegImport "> Disabling telemetry, diagnostic data and targeted ads..." $PSScriptRoot\Regfiles\Disable_Telemetry.reg
        Write-Output ""
        continue
    }
    'DisableBingSearches' {
        RegImport "> Disabling bing search, bing AI & cortana in windows search..." $PSScriptRoot\Regfiles\Disable_Bing_Cortana_In_Search.reg
        Write-Output ""
        continue
    }
    'DisableBing' {
        RegImport "> Disabling bing search, bing AI & cortana in windows search..." $PSScriptRoot\Regfiles\Disable_Bing_Cortana_In_Search.reg
        Write-Output ""
        continue
    }
    'DisableLockscreenTips' {
        RegImport "> Disabling tips & tricks on the lockscreen..." $PSScriptRoot\Regfiles\Disable_Lockscreen_Tips.reg
        Write-Output ""
        continue
    }
    {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
        RegImport "> Disabling tips, tricks and suggestions in the start menu, settings and  windows explorer..." $PSScriptRoot\Regfiles\Disable_Windows_Suggestions.reg
        Write-Output ""
        continue
    }
    'TaskbarAlignLeft' {
        RegImport "> Aligning taskbar buttons to the left..." $PSScriptRoot\Regfiles\Align_Taskbar_Left.reg
        Write-Output ""
        continue
    }
    'HideSearchTb' {
        RegImport "> Hiding the search icon from the taskbar..." $PSScriptRoot\Regfiles\Hide_Search_Taskbar.reg
        Write-Output ""
        continue
    }
    'ShowSearchIconTb' {
        RegImport "> Changing taskbar search to icon only..." $PSScriptRoot\Regfiles\Show_Search_Icon.reg
        Write-Output ""
        continue
    }
    'ShowSearchLabelTb' {
        RegImport "> Changing taskbar search to icon with label..." $PSScriptRoot\Regfiles\Show_Search_Icon_And_Label.reg
        Write-Output ""
        continue
    }
    'ShowSearchBoxTb' {
        RegImport "> Changing taskbar search to search box..." $PSScriptRoot\Regfiles\Show_Search_Box.reg
        Write-Output ""
        continue
    }
    {$_ -in "HideWidgets", "DisableWidgets"} {
        RegImport "> Disabling the widget service and hiding the widget icon from the taskbar..." $PSScriptRoot\Regfiles\Disable_Widgets_Taskbar.reg
        Write-Output ""
        continue
    }
    {$_ -in "HideChat", "DisableChat"} {
        RegImport "> Hiding the chat icon from the taskbar..." $PSScriptRoot\Regfiles\Disable_Chat_Taskbar.reg
        Write-Output ""
        continue
    }
    'ShowHiddenFolders' {
        RegImport "> Unhiding hidden files, folders and drives..." $PSScriptRoot\Regfiles\Show_Hidden_Folders.reg
        Write-Output ""
        continue
    }
    'ShowKnownFileExt' {
        RegImport "> Enabling file extensions for known file types..." $PSScriptRoot\Regfiles\Show_Extensions_For_Known_File_Types.reg
        Write-Output ""
        continue
    }
    {$_ -in "HideOnedrive", "DisableOnedrive"} {
        RegImport "> Hiding the onedrive folder in windows explorer..." $PSScriptRoot\Regfiles\Hide_Onedrive_Folder.reg
        Write-Output ""
        continue
    }
    {$_ -in "Hide3dObjects", "Disable3dObjects"} {
        RegImport "> Hiding the 3D objects folder in windows explorer..." $PSScriptRoot\Regfiles\Hide_3D_Objects_Folder.reg
        Write-Output ""
        continue
    }
    {$_ -in "HideMusic", "DisableMusic"} {
        RegImport "> Hiding the music folder in windows explorer..." $PSScriptRoot\Regfiles\Hide_Music_folder.reg
        Write-Output ""
        continue
    }
    {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
        RegImport "> Hiding 'Include in library' in the context menu..." $PSScriptRoot\Regfiles\Disable_Include_in_library_from_context_menu.reg
        Write-Output ""
        continue
    }
    {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
        RegImport "> Hiding 'Give access to' in the context menu..." $PSScriptRoot\Regfiles\Disable_Give_access_to_context_menu.reg
        Write-Output ""
        continue
    }
    {$_ -in "HideShare", "DisableShare"} {
        RegImport "> Hiding 'Share' in the context menu..." $PSScriptRoot\Regfiles\Disable_Share_from_context_menu.reg
        Write-Output ""
        continue
    }
}

Write-Output ""
Write-Output ""
Write-Output "Script completed! Please restart your PC to make sure all changes are properly applied."
Write-Output ""
Write-Output ""
Write-Output "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
