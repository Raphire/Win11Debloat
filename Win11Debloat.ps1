#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param 
(
    [Parameter(ValueFromPipeline = $true)][switch]$RunDefaults,
    [Parameter(ValueFromPipeline = $true)][switch]$RunWin11Defaults,
    [Parameter(ValueFromPipeline = $true)][switch]$RemoveApps,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableTelemetry,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableBingSearches,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableBing,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableLockscreenTips,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableWindowsSuggestions,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableSuggestions,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableWidgets,
    [Parameter(ValueFromPipeline = $true)][switch]$HideWidgets,
    [Parameter(ValueFromPipeline = $true)][switch]$DisableChat,
    [Parameter(ValueFromPipeline = $true)][switch]$HideChat,
    [Parameter(ValueFromPipeline = $true)][switch]$TaskbarAlignLeft,
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
    $appsFile = "$PSScriptRoot/Appslist.txt"
    Write-Output "> Removing pre-installed windows apps..."

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
    if ($RunDefaults) {
        $Mode = '1';
    }
    elseif ($RunWin11Defaults) {
        $Mode = '2';
    }
    else {
        Do { 
            Clear-Host
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output " Win11Debloat Script - Setup"
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output "(1) Run Win11Debloat with the Windows 10 default settings"
            Write-Output "(2) Run Win11Debloat with the Windows 11 default settings"
            Write-Output "(3) Custom mode: Select which changes you want Win11Debloat to make"
            Write-Output ""
            Write-Output "(0) Show information about the script"
            Write-Output ""
            Write-Output ""
            $Mode = Read-Host "Please select an option (1/2/3/0)" 

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
                Write-Output " Windows 10 default settings will:"
                Write-Output "-------------------------------------------------------------------------------------------"
                Write-Output "- Remove bloatware apps, full list can be found on github. (github.com/raphire/win11debloat)"
                Write-Output "- Disable telemetry, diagnostic data & targeted ads."
                Write-Output "- Disable bing search & cortana in windows search."
                Write-Output "- Disable tips & tricks on the lockscreen. (This may change your lockscreen wallpaper to the default)"
                Write-Output "- Disable tips, tricks and suggestions in the startmenu and settings, and ads in windows explorer."
                Write-Output "- Disable the widget service & hide the widget (news and interests) icon on the taskbar. "
                Write-Output "- Hide the Chat (meet now) icon from the taskbar."
                Write-Output "- Hide the 3D objects folder under 'This pc' in windows explorer."
                Write-Output ""
                Write-Output "-------------------------------------------------------------------------------------------"
                Write-Output " Windows 11 default settings will:"
                Write-Output "-------------------------------------------------------------------------------------------"
                Write-Output "- Remove bloatware apps, full list can be found on github. (github.com/raphire/win11debloat)"
                Write-Output "- Disable telemetry, diagnostic data & targeted ads."
                Write-Output "- Disable bing search, bing AI & cortana in windows search."
                Write-Output "- Disable tips & tricks on the lockscreen. (This may change your lockscreen wallpaper to the default)"
                Write-Output "- Disable tips, tricks and suggestions in the startmenu and settings, and ads in windows explorer."
                Write-Output "- Disable the widget service & hide the widget icon on the taskbar."
                Write-Output "- Hide the Chat icon from the taskbar."
                Write-Output ""
                Write-Output ""
                Write-Output "Press any key to go back..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
        while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3') 
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
            $PSBoundParameters.Add('DisableWidgets', $DisableWidgets) 
            $PSBoundParameters.Add('HideChat', $HideChat) 
            $PSBoundParameters.Add('Hide3dObjects', $Hide3dObjects)
        }

        '2' { 
            Clear-Host
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output " Win11Debloat Script - Windows 11 Default Configuration"
            Write-Output "-------------------------------------------------------------------------------------------"
            $PSBoundParameters.Add('RemoveApps', $RemoveApps) 
            $PSBoundParameters.Add('DisableTelemetry', $DisableTelemetry)  
            $PSBoundParameters.Add('DisableBing', $DisableBing) 
            $PSBoundParameters.Add('DisableLockscreenTips', $DisableLockscreenTips)  
            $PSBoundParameters.Add('DisableSuggestions', $DisableSuggestions) 
            $PSBoundParameters.Add('DisableWidgets', $DisableWidgets) 
            $PSBoundParameters.Add('HideChat', $HideChat) 
        }

        '3' { 
            Clear-Host
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output " Win11Debloat Script - Custom Configuration"
            Write-Output "-------------------------------------------------------------------------------------------"

            if ($( Read-Host -Prompt "Remove the pre-installed windows apps? (y/n)" ) -eq 'y') {
                $PSBoundParameters.Add('RemoveApps', $RemoveApps)   
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

            if ($( Read-Host -Prompt "Disable tips & tricks on the lockscreen? (y/n)" ) -eq 'y') {
                $PSBoundParameters.Add('DisableLockscreenTips', $DisableLockscreenTips)   
            } 

            Write-Output ""

            if ($( Read-Host -Prompt "Disable tips, tricks and suggestions in the startmenu and settings, and ads in windows explorer? (y/n)" ) -eq 'y') {
                $PSBoundParameters.Add('DisableSuggestions', $DisableSuggestions)   
            }

            Write-Output ""

            if ($( Read-Host -Prompt "Do you want to make any changes to the taskbar? (y/n)" ) -eq 'y') {
                # Only show option for taskbar alignment in windows 11
                if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 11%'"){

                    Write-Output ""

                    if ($( Read-Host -Prompt "   Align taskbar buttons to left side? (y/n)" ) -eq 'y') {
                        $PSBoundParameters.Add('TaskbarAlignLeft', $TaskbarAlignLeft)   
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Disable the widgets service and hide the widget (news and interests) icon on the taskbar? (y/n)" ) -eq 'y') {
                    $PSBoundParameters.Add('DisableWidgets', $DisableWidgets)   
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   Hide the chat (meet now) icon on the taskbar? (y/n)" ) -eq 'y') {
                    $PSBoundParameters.Add('HideChat', $HideChat)   
                }
            }

            # Only show option for disabling these specific folders in windows 10
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

            # Only show option for disabling context menu items in windows 10
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
        RemoveApps
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
        RegImport "> Disabling tips, tricks and suggestions in the startmenu and settings, and ads in windows explorer..." $PSScriptRoot\Regfiles\Disable_Windows_Suggestions.reg
        Write-Output ""
        continue
    }
    {$_ -in "HideWidgets", "DisableWidgets"} {
        RegImport "> Disabling the widget service and hiding the widget icon on the taskbar..." $PSScriptRoot\Regfiles\Disable_Widgets_Taskbar.reg
        Write-Output ""
        continue
    }
    {$_ -in "HideChat", "DisableChat"} {
        RegImport "> Hiding the chat icon on the taskbar..." $PSScriptRoot\Regfiles\Disable_Chat_Taskbar.reg
        Write-Output ""
        continue
    }
    'TaskbarAlignLeft' {
        RegImport "> Aligning taskbar buttons to the left..." $PSScriptRoot\Regfiles\Align_Taskbar_Left.reg
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
