[CmdletBinding(SupportsShouldProcess)]
param 
(
    [Parameter(ValueFromPipeline=$true)][switch]$RunDefaults,
    [Parameter(ValueFromPipeline=$true)][switch]$RunWin11Defaults,
    [Parameter(ValueFromPipeline=$true)][switch]$RemoveApps,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableTelemetry,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableBingSearches,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableLockscreenTips,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableWindowsSuggestions,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableChat,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableWidgets,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableOnedrive,
    [Parameter(ValueFromPipeline=$true)][switch]$Disable3dObjects,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableMusic,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableIncludeInLibrary,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableGiveAccessTo,
    [Parameter(ValueFromPipeline=$true)][switch]$DisableShare
)

# Removes all apps in the list
function RemoveApps
{
    Write-Output "> Removing pre-installed windows 10 apps..."

    $apps = @(
        # These apps will be uninstalled by default:
        #
        # If you wish to KEEP any of the apps below simply add a # character
        # in front of the specific app in the list below.
        "2FE3CB00.PICSART-PHOTOSTUDIO"
        "9E2F88E3.TWITTER"
        "AdobeSystemsIncorporated.AdobePhotoshopExpress"
        "Facebook.InstagramBeta"
        "HULULLC.HULUPLUS"
        "Clipchamp.Clipchamp*"
        "*Microsoft.GetHelp*"
        "*Microsoft.Getstarted*"
        "*Microsoft.WindowsFeedbackHub*"
        "*Microsoft.BingNews*"
        "*Microsoft.BingFinance*"
        "*Microsoft.BingSports*"
        "*Microsoft.BingWeather*"
        "*Microsoft.BingTranslator*"
        "*Microsoft.MicrosoftOfficeHub*"
        "*Microsoft.Office.OneNote*"
        "*Microsoft.MicrosoftStickyNotes*"
        "*Microsoft.SkypeApp*"
        "*Microsoft.OneConnect*"
        "*Microsoft.Messaging*"
        "*Microsoft.WindowsSoundRecorder*"
        "*Microsoft.ZuneMusic*"
        "*Microsoft.ZuneVideo*"
        "*Microsoft.MixedReality.Portal*"
        "*Microsoft.3DBuilder*"
        "*Microsoft.Microsoft3DViewer*"
        "*Microsoft.Print3D*"
        "*Microsoft.549981C3F5F10*"   #Cortana app
        "*Microsoft.MicrosoftSolitaireCollection*"
        "*Microsoft.Asphalt8Airborne*"
        "*king.com.BubbleWitch3Saga*"
        "*king.com.CandyCrushSodaSaga*"
        "*king.com.CandyCrushSaga*"
        


        # These apps will NOT be uninstalled by default:
        # 
        # If you wish to REMOVE any of the apps below simply remove the #
        # character in front of the specific app in the list below.
        #"*Microsoft.WindowsStore*"   # NOTE: This app cannot be reinstalled!
        #"*Microsoft.WindowsCalculator*"
        #"*Microsoft.Windows.Photos*"
        #"*Microsoft.WindowsCamera*"
        #"*Microsoft.WindowsAlarms*"
        #"*Microsoft.WindowsMaps*"
        #"*microsoft.windowscommunicationsapps*"   # Mail & Calendar
        #"*Microsoft.People*"
        #"*Microsoft.ScreenSketch*"
        #"*Microsoft.MSPaint*"   # Paint 3D
        #"*Microsoft.YourPhone*"
        #"*Microsoft.Xbox.TCUI*"
        #"*Microsoft.XboxApp*"
        #"*Microsoft.XboxGameOverlay*"
        #"*Microsoft.XboxGamingOverlay*"
        #"*Microsoft.XboxIdentityProvider*"
        #"*Microsoft.XboxSpeechToTextOverlay*"   # NOTE: This app may not be able to be reinstalled!
    )

    foreach ($app in $apps) {
        Write-Output "Attempting to remove $app"

        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage
    }
}

# Import & execute regfile
function RegImport
{
    param 
    (
        $Message,
        $Path
    )

    Write-Output $Message
    reg import $path
}

# Change mode based on provided parameters or user input
if((-NOT $PSBoundParameters.Count) -or $RunDefaults -or $RunWin11Defaults -or (($PSBoundParameters.Count -eq 1) -and ($PSBoundParameters.ContainsKey('WhatIf') -or $PSBoundParameters.ContainsKey('Confirm') -or $PSBoundParameters.ContainsKey('Verbose'))))
{
    if($RunDefaults)
    {
        $Mode = '1';
    }
    elseif($RunWin11Defaults)
    {
        $Mode = '2';
    }
    else
    {
        Clear
        Write-Output "-------------------------------------------------------------------------------------------"
        Write-Output " Win10Debloat Script - Setup"
        Write-Output "-------------------------------------------------------------------------------------------"
        Write-Output "(1) Run Win10Debloat with the Windows 10 default settings"
        Write-Output "(2) Run Win10Debloat with the Windows 11 default settings"
        Write-Output "(3) Advanced: Choose which changes you want Win10Debloat to make"
        Write-Output ""

        Do { $Mode = Read-Host "Please select an option (1/2/3)" }
        while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3')
    }

    # Add execution parameters based on the mode
    switch($Mode)
    {
        '1' 
        { 
            Clear
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output " Win10Debloat Script - Windows 10 Default Configuration"
            Write-Output "-------------------------------------------------------------------------------------------"
            $PSBoundParameters.Add('RemoveApps', $RemoveApps) 
            $PSBoundParameters.Add('DisableTelemetry', $DisableTelemetry)  
            $PSBoundParameters.Add('DisableBingSearches', $DisableBingSearches) 
            $PSBoundParameters.Add('DisableLockscreenTips', $DisableLockscreenTips)  
            $PSBoundParameters.Add('DisableWindowsSuggestions', $DisableWindowsSuggestions)  
            $PSBoundParameters.Add('DisableChat', $DisableChat) 
            $PSBoundParameters.Add('DisableWidgets', $DisableWidgets) 
            $PSBoundParameters.Add('Disable3dObjects', $Disable3dObjects)   
            $PSBoundParameters.Add('DisableIncludeInLibrary', $DisableIncludeInLibrary)   
            $PSBoundParameters.Add('DisableGiveAccessTo', $DisableGiveAccessTo)  
            $PSBoundParameters.Add('DisableShare', $DisableShare)  
        }
        '2' 
        { 
            Clear
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output " Win10Debloat Script - Windows 11 Default Configuration"
            Write-Output "-------------------------------------------------------------------------------------------"
            $PSBoundParameters.Add('RemoveApps', $RemoveApps) 
            $PSBoundParameters.Add('DisableTelemetry', $DisableTelemetry)  
            $PSBoundParameters.Add('DisableBingSearches', $DisableBingSearches) 
            $PSBoundParameters.Add('DisableLockscreenTips', $DisableLockscreenTips)  
            $PSBoundParameters.Add('DisableWindowsSuggestions', $DisableWindowsSuggestions) 
            $PSBoundParameters.Add('DisableChat', $DisableChat) 
            $PSBoundParameters.Add('DisableWidgets', $DisableWidgets) 
        }
        '3' 
        { 
            Clear
            Write-Output "-------------------------------------------------------------------------------------------"
            Write-Output " Win10Debloat Script - Advanced Configuration"
            Write-Output "-------------------------------------------------------------------------------------------"

            if($( Read-Host -Prompt "Remove the pre-installed windows 10 apps? (y/n)" ) -eq 'y')
            {
                $PSBoundParameters.Add('RemoveApps', $RemoveApps)   
            }

            if($( Read-Host -Prompt "Disable telemetry, diagnostic data and targeted ads? (y/n)" ) -eq 'y')
            {
                $PSBoundParameters.Add('DisableTelemetry', $DisableTelemetry)   
            }

            if($( Read-Host -Prompt "Disable bing in windows search? (y/n)" ) -eq 'y')
            {
                $PSBoundParameters.Add('DisableBingSearches', $DisableBingSearches)   
            }

            if($( Read-Host -Prompt "Disable tips & tricks on the lockscreen? (y/n)" ) -eq 'y')
            {
                $PSBoundParameters.Add('DisableLockscreenTips', $DisableLockscreenTips)   
            } 

            if($( Read-Host -Prompt "Disable tips, tricks and suggestions in the startmenu and settings, and ads in windows explorer? (y/n)" ) -eq 'y')
            {
                $PSBoundParameters.Add('DisableWindowsSuggestions', $DisableWindowsSuggestions)   
            }

            if($( Read-Host -Prompt "Do you want to hide any icons from the taskbar? (y/n)" ) -eq 'y')
            {
                if($( Read-Host -Prompt "Hide the chat (meet now) icon on the taskbar? (y/n)" ) -eq 'y')
                {
                    $PSBoundParameters.Add('DisableChat', $DisableChat)   
                }

                if($( Read-Host -Prompt "Hide the widget (news and interests) icon on the taskbar? (y/n)" ) -eq 'y')
                {
                    $PSBoundParameters.Add('DisableWidgets', $DisableWidgets)   
                }
            }

            if($( Read-Host -Prompt "Do you want to hide any folders from the windows explorer sidepanel? (y/n)" ) -eq 'y')
            {
                if($( Read-Host -Prompt "Hide the onedrive folder in windows explorer? (y/n)" ) -eq 'y')
                {
                    $PSBoundParameters.Add('DisableOnedrive', $DisableOnedrive)   
                }

                if($( Read-Host -Prompt "Hide the 3D objects folder in windows explorer? (y/n)" ) -eq 'y')
                {
                    $PSBoundParameters.Add('Disable3dObjects', $Disable3dObjects)   
                }

                if($( Read-Host -Prompt "Hide the music folder in windows explorer? (y/n)" ) -eq 'y')
                {
                    $PSBoundParameters.Add('DisableMusic', $DisableMusic)   
                }
            }

            if($( Read-Host -Prompt "Do you want to disable any context menu options? (y/n)" ) -eq 'y')
            {
                if($( Read-Host -Prompt "Disable the 'Include in library' option in the context menu? (y/n)" ) -eq 'y')
                {
                    $PSBoundParameters.Add('DisableIncludeInLibrary', $DisableIncludeInLibrary)   
                }

                if($( Read-Host -Prompt "Disable the 'Give access to' option in the context menu? (y/n)" ) -eq 'y')
                {
                    $PSBoundParameters.Add('DisableGiveAccessTo', $DisableGiveAccessTo)   
                }

                if($( Read-Host -Prompt "Disable the 'Share' option in the context menu? (y/n)" ) -eq 'y')
                {
                    $PSBoundParameters.Add('DisableShare', $DisableShare)   
                }
            }

            Write-Output "" 
        }
    }
}
else
{
    Clear
    Write-Output "-------------------------------------------------------------------------------------------"
    Write-Output " Win10Debloat Script - Custom Configuration"
    Write-Output "-------------------------------------------------------------------------------------------"
}

# Execute all selected/provided parameters
switch ($PSBoundParameters.Keys)
{
    'RemoveApps' 
    {
        RemoveApps
    }
    'DisableTelemetry'
    {
        RegImport "> Disabling telemetry, diagnostic data and targeted ads..." $PSScriptRoot\Regfiles\Disable_Telemetry.reg
    }
    'DisableBingSearches'
    {
        RegImport "> Disabling bing in windows search..." $PSScriptRoot\Regfiles\Disable_Bing_Searches.reg
    }
    'DisableLockscreenTips'
    {
        RegImport "> Disabling tips & tricks on the lockscreen..." $PSScriptRoot\Regfiles\Disable_Lockscreen_Tips.reg
    }
    'DisableWindowsSuggestions'
    {
        RegImport "> Disabling tips, tricks and suggestions in the startmenu and settings, and ads in windows explorer..." $PSScriptRoot\Regfiles\Disable_Windows_Suggestions.reg
    }
    'DisableChat'
    {
        RegImport "> Hiding the chat icon on the taskbar..." $PSScriptRoot\Regfiles\Disable_Chat_Taskbar.reg
    }
    'DisableWidgets'
    {
        RegImport "> Hiding the widget icon on the taskbar..." $PSScriptRoot\Regfiles\Disable_Widgets_Taskbar.reg
    }
    'DisableOnedrive'
    {
        RegImport "> Hiding the onedrive folder in windows explorer..." $PSScriptRoot\Regfiles\Hide_Onedrive_Folder.reg
    }
    'Disable3dObjects'
    {
        RegImport "> Hiding the 3D objects folder in windows explorer..." $PSScriptRoot\Regfiles\Hide_3D_Objects_Folder.reg
    }
    'DisableMusic'
    {
        RegImport "> Hiding the music folder in windows explorer..." $PSScriptRoot\Regfiles\Hide_Music_folder.reg
    }
    'DisableIncludeInLibrary'
    {
        RegImport "> Disabling 'Include in library' in the context menu..." $PSScriptRoot\Regfiles\Disable_Include_in_library_from_context_menu.reg
    }
    'DisableGiveAccessTo'
    {
        RegImport "> Disabling 'Give access to' in the context menu..." $PSScriptRoot\Regfiles\Disable_Give_access_to_context_menu.reg
    }
    'DisableShare'
    {
        RegImport "> Disabling 'Share' in the context menu..." $PSScriptRoot\Regfiles\Disable_Share_from_context_menu.reg
    }
}

Write-Output ""
Write-Output "Script completed! Please restart your PC to make sure all changes are properly applied."
Write-Output ""
Write-Output "Press any key to continue..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
