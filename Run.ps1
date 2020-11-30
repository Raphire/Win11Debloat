Write-Output "Attempting to launch script with admin privileges..."

PowerShell -NoProfile -ExecutionPolicy Unrestricted -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Unrestricted -File ""$PSScriptRoot\Win10Debloat.ps1""' -Verb RunAs}";

<#------------------------------------------------------------------------------------------------------------------------------------------------>
It's possible to tweak the behaviour of the script by adding arguments to the ArgumentList, a full list of arguments is shown below. 
This has the added benefit that the script will run without requiring any user input during runtime, allowing you to automate the process.

The example below configures the script to only remove apps and disable bing in windows search:

PowerShell -NoProfile -ExecutionPolicy Unrestricted -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile 
                                                                                                         -ExecutionPolicy Unrestricted 
                                                                                                         -File ""$PSScriptRoot\Win10Debloat.ps1""
                                                                                                         -RemoveApps
                                                                                                         -DisableBingSearches' 
                                                                                          -Verb RunAs}";

Supported Arguments:
-RunDefaults                  |    Run the script with default settings    
-RemoveApps                   |    Remove configured apps
-DisableOnedrive              |    Hide the onedrive folder in the windows explorer sidebar.
-Disable3dObjects             |    Hide the 3D objects folder under 'This pc' in windows explorer. 
-DisableMusic                 |    Hide the music folder under 'This pc' in windows explorer.
-DisableBingSearches          |    Disable bing in windows search.
-DisableLockscreenTips        |    Disable tips & tricks on the lockscreen. 
-DisableWindowsSuggestions    |    Disable tips, tricks and suggestions in the startmenu and settings.
-DisableIncludeInLibrary      |    Disable the 'Include in library' option in the context menu.
-DisableGiveAccessTo          |    Disable the 'Give access to' option in the context menu.
-DisableShare                 |    Disable the 'Share' option in the context menu.
<------------------------------------------------------------------------------------------------------------------------------------------------#>
