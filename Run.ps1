Write-Output "Attempting to launch script with admin privileges..."

PowerShell -NoProfile -ExecutionPolicy Unrestricted -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Unrestricted -File ""$PSScriptRoot\Win10Debloat.ps1""' -Verb RunAs}";

<#------------------------------------------------------------------------------------------------------------------------------------------------>
It's possible to tweak the behaviour of the script by running the script with one or more of the arguments in the ArgumentList as shown below. 
This allows you to tailor the behaviour of the script to your needs without any user input during runtime, making it quicker and easier to deploy.

The example below configures the script to only remove apps and disable bing in windows search:

PowerShell -NoProfile -ExecutionPolicy Unrestricted -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile 
                                                                                                         -ExecutionPolicy Unrestricted 
                                                                                                         -File ""$PSScriptRoot\Win10Debloat.ps1""
                                                                                                         -RemoveApps
                                                                                                         -DisableBing' 
                                                                                          -Verb RunAs}";

Supported Arguments:
-RunDefaults                  |    Run the script with windows 10 default settings.
-RunWin11Defaults             |    Run the script with windows 11 default settings.
-RemoveApps                   |    Remove all bloatware apps from the list found in README.md.
-DisableTelemetry             |    Disable telemetry, diagnostic data & targeted ads.
-DisableBing                  |    Disable bing & cortana in windows search.
-DisableLockscreenTips        |    Disable tips & tricks on the lockscreen.
-DisableWindowsSuggestions    |    Disable tips, tricks and suggestions in the startmenu and settings, and ads in windows explorer.
-DisableOnedrive              |    Hide the onedrive folder in the windows explorer sidepanel.
-DisableChat                  |    Hide the chat icon on the taskbar.
-DisableWidgets               |    Hide the widget icon on the taskbar.
-Disable3dObjects             |    Hide the 3D objects folder under 'This pc' in windows explorer.
-DisableMusic                 |    Hide the music folder under 'This pc' in windows explorer.
-DisableIncludeInLibrary      |    Disable the 'Include in library' option in the context menu.
-DisableGiveAccessTo          |    Disable the 'Give access to' option in the context menu.
-DisableShare                 |    Disable the 'Share' option in the context menu.
<------------------------------------------------------------------------------------------------------------------------------------------------#>
