# Win11Debloat

Win11Debloat is a simple, easy to use and lightweight powershell script that can remove pre-installed Windows bloatware apps, disable telemetry and declutter the experience by disabling or removing intrusive interface elements, ads and more. No need to painstakingly go through all the settings yourself, or remove apps one by one. Win11Debloat makes the process quick and easy!

You can pick and choose exactly which modifications you want the script to make, or use the default settings. If you are unhappy with any of the changes you can easily revert them by using the registry files that are included in the 'Regfiles' folder, all of the apps that are removed can be reinstalled from the Microsoft store.

#### Did this script help you? Please consider buying me a cup of coffee to support my work

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## Features

Win11Debloat has many options, but not all of these options are executed when running the script with the default settings. Select 'Custom mode' in the script menu if you want more granular control over the script or if you want to access all of Win11Debloat's features.

### Default Settings

- Remove the default selection of bloatware apps from [this list](#apps-that-are-removed-by-default).
- Disable telemetry, diagnostic data, app-launch tracking & targeted ads.
- Disable & remove bing search & cortana in Windows search.
- Disable tips, tricks, suggestions and ads in start, settings, notifications, Windows explorer, and on the lockscreen.
- Disable Windows Copilot. (Windows 11 only)
- Show file extensions for known file types.
- Disable the widget service & hide the icon from the taskbar.
- Hide the Chat (meet now) icon from the taskbar.
- Hide the 3D objects folder under 'This pc' in Windows explorer. (Windows 10 only)

### All Features

- Remove bloatware apps, with the option to select exactly what apps to remove or keep.
- Remove all pinned apps from the start menu. NOTE: This applies to all existing and new users. (Windows 11 only)
- Disable telemetry, diagnostic data, app-launch tracking & targeted ads.
- Disable & remove bing search & cortana in Windows search.
- Disable tips, tricks, suggestions and ads in start, settings, notifications, Windows explorer, and on the lockscreen.
- Disable Windows Copilot. (Windows 11 only)
- Restore the old Windows 10 style context menu. (Windows 11 only)
- Show hidden files, folders and drives.
- Show file extensions for known file types.
- Hide duplicate removable drive entries from the Windows explorer navigation pane, so only the entry under 'This PC' remains.
- Align taskbar icons to the left. (Windows 11 only)
- Hide or change the search icon/box on the taskbar. (Windows 11 only)
- Hide the taskview button from the taskbar. (Windows 11 only)
- Disable the widget service & hide icon from the taskbar.
- Hide the chat (meet now) icon from the taskbar.
- Hide the 3D objects, music or onedrive folder in the Windows explorer sidepanel. (Windows 10 only)
- Hide the 'Include in library', 'Give access to' and 'Share' options in the context menu. (Windows 10 only)

<br/>

> [!TIP]
> In 'custom mode' you can select exactly which apps to remove and which you want to keep!

### Apps that ARE removed by default

<details>
  <summary>Click to expand</summary>
  <blockquote>
    
    Microsoft bloat:
    - Clipchamp.Clipchamp  
    - Microsoft.3DBuilder  
    - Microsoft.549981C3F5F10 (Cortana app)
    - Microsoft.BingFinance  
    - Microsoft.BingFoodAndDrink 
    - Microsoft.BingHealthAndFitness
    - Microsoft.BingNews  
    - Microsoft.BingSearch* (Bing web search in Windows)
    - Microsoft.BingSports  
    - Microsoft.BingTranslator  
    - Microsoft.BingTravel   
    - Microsoft.BingWeather  
    - Microsoft.Getstarted (Cannot be uninstalled in Windows 11)
    - Microsoft.Messaging  
    - Microsoft.Microsoft3DViewer  
    - Microsoft.MicrosoftOfficeHub  
    - Microsoft.MicrosoftPowerBIForWindows  
    - Microsoft.MicrosoftSolitaireCollection  
    - Microsoft.MicrosoftStickyNotes  
    - Microsoft.MixedReality.Portal  
    - Microsoft.NetworkSpeedTest  
    - Microsoft.News  
    - Microsoft.Office.OneNote (Discontinued UWP version only, does not remove new MS365 versions)
    - Microsoft.Office.Sway  
    - Microsoft.OneConnect  
    - Microsoft.Print3D  
    - Microsoft.SkypeApp  
    - Microsoft.Todos  
    - Microsoft.WindowsAlarms  
    - Microsoft.WindowsFeedbackHub  
    - Microsoft.WindowsMaps  
    - Microsoft.WindowsSoundRecorder  
    - Microsoft.XboxApp (Old Xbox Console Companion App, no longer supported)
    - Microsoft.ZuneVideo  
    - MicrosoftCorporationII.MicrosoftFamily (Microsoft Family Safety)
    - MicrosoftTeams (Personal version only, does not remove MS teams for business/enterprise)

    Third party bloat:
    - ACGMediaPlayer  
    - ActiproSoftwareLLC  
    - AdobeSystemsIncorporated.AdobePhotoshopExpress  
    - Amazon.com.Amazon  
    - AmazonVideo.PrimeVideo
    - Asphalt8Airborne   
    - AutodeskSketchBook  
    - CaesarsSlotsFreeCasino  
    - COOKINGFEVER  
    - CyberLinkMediaSuiteEssentials  
    - DisneyMagicKingdoms  
    - Disney 
    - Dolby  
    - DrawboardPDF  
    - Duolingo-LearnLanguagesforFree  
    - EclipseManager  
    - Facebook  
    - FarmVille2CountryEscape  
    - fitbit  
    - Flipboard  
    - HiddenCity  
    - HULULLC.HULUPLUS  
    - iHeartRadio  
    - Instagram
    - king.com.BubbleWitch3Saga  
    - king.com.CandyCrushSaga  
    - king.com.CandyCrushSodaSaga  
    - LinkedInforWindows  
    - MarchofEmpires  
    - Netflix  
    - NYTCrossword  
    - OneCalendar  
    - PandoraMediaInc  
    - PhototasticCollage  
    - PicsArt-PhotoStudio  
    - Plex  
    - PolarrPhotoEditorAcademicEdition  
    - Royal Revolt  
    - Shazam  
    - Sidia.LiveWallpaper  
    - SlingTV  
    - Speed Test  
    - Spotify  
    - TikTok
    - TuneInRadio  
    - Twitter  
    - Viber  
    - WinZipUniversal  
    - Wunderlist  
    - XING
    
    * App is removed when disabling Bing in Windows search.
  </blockquote>
</details>

### Apps that are NOT removed by default

<details>
  <summary>Click to expand</summary>
  <blockquote>
    
    General apps that are not removed by default:
    - Microsoft.GetHelp (Required for some Windows 11 Troubleshooters)
    - Microsoft.MicrosoftEdge.Stable (Edge browser)
    - Microsoft.MSPaint (Paint 3D)
    - Microsoft.OutlookForWindows* (New mail app)
    - Microsoft.Paint (Classic Paint)
    - Microsoft.People* (Required for & included with Mail & Calendar)
    - Microsoft.ScreenSketch (Snipping Tool)
    - Microsoft.Whiteboard (Only preinstalled on devices with touchscreen and/or pen support)
    - Microsoft.Windows.Photos
    - Microsoft.WindowsCalculator
    - Microsoft.WindowsCamera
    - Microsoft.windowscommunicationsapps* (Mail & Calendar)
    - Microsoft.WindowsStore (Microsoft Store, NOTE: This app cannot be reinstalled!)
    - Microsoft.WindowsTerminal (New default terminal app in Windows 11)
    - Microsoft.YourPhone (Phone Link)
    - Microsoft.Xbox.TCUI (UI framework, removing this may break MS store, photos and certain games)
    - Microsoft.ZuneMusic (Modern Media Player)

    Gaming related apps that are not removed by default:
    - Microsoft.GamingApp* (Modern Xbox Gaming App, required for installing some games)
    - Microsoft.XboxGameOverlay* (Game overlay, required for some games)
    - Microsoft.XboxGamingOverlay* (Game overlay, required for some games)
    - Microsoft.XboxIdentityProvider (Xbox sign-in framework, required for some games)
    - Microsoft.XboxSpeechToTextOverlay (Might be required for some games, NOTE: This app cannot be reinstalled!)

    Developer related apps that are not removed by default:
    - Microsoft.PowerAutomateDesktop*
    - Microsoft.RemoteDesktop*
    - Windows.DevHome*

    * Can be removed by running the script with the relevant parameter. (See advanced method)
  </blockquote>
</details>

## Usage

> [!Warning]
> Great care went into making sure this script does not unintentionally break any OS functionality, but use at your own risk!

### Easy method

1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Navigate to the Win11Debloat folder
3. Double click the 'Run.bat' file to start the script. Note: If the console window immediately closes and nothing happens, try the advanced method below.
4. Accept the Windows UAC prompt to run the script as administrator, this is required for the script to function.
5. A new powershell window will now open, showing the Win11Debloat menu. Select either the default or custom mode to continue.
6. Carefully read through and follow the on-screen instructions.

After making the selected changes the Win11Debloat script will restart the Windows Explorer process to properly apply them. If Windows Explorer does not recover after running the script and your desktop stays black, don't worry. Just press Ctrl + Alt + Del and restart your PC.

### Advanced method

This method gives you the option to run the script with certain parameters to tailor the behaviour of the script to your needs and it allows you to run the script without requiring any user input during runtime, making it quicker and easier to deploy on a large number of systems.

1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Open powershell as an administrator.
3. Enable powershell execution by entering the following command: `Set-ExecutionPolicy Unrestricted -Scope Process`
4. In powershell, navigate to the directory where the files were extracted. Example: `cd c:\Win11Debloat`
5. Enter this into powershell to run the script: `.\Win11Debloat.ps1`
6. The Win11Debloat menu will now open. Select either the default or custom setup to continue.

To run the script with parameters simply execute the script as explained above, but add the parameters at the end with spaces in between. Example: `.\Win11Debloat.ps1 -RemoveApps -DisableBing -Silent`

A full list of parameters and what they do can be found below.

| Parameter | Description |
| :-------: | ----------- |
| -Silent                            |    Suppresses all interactive prompts, so the script will run without requiring any user input. |
| -RunDefaults                       |    Run the script with the default settings. |
| -RemoveApps                        |    Remove all bloatware apps from [this list](#apps-that-are-removed-by-default). |
| -RemoveAppsCustom                  |    Remove all apps from the 'CustomAppsList' file. IMPORTANT: Run the script with the `-RunAppConfigurator` parameter to create this file first. No apps will be removed if this file does not exist! |
| -RunAppConfigurator                |    Run the app configurator to create a 'CustomAppsList' file. Run the script with the `-RemoveAppsCustom` parameter to remove these apps. |
| -RemoveCommApps                    |    Remove the Mail, Calender, and People apps. |
| -RemoveW11Outlook                  |    Remove the new Outlook for Windows app. |
| -RemoveDevApps                     |    Remove developer-related apps such as Remote Desktop, DevHome and Power Automate. |
| -RemoveGamingApps                  |    Remove the Xbox App and Xbox Gamebar. |
| -ClearStart                        |    Remove all pinned apps from the start menu. NOTE: This applies to all existing and new users. (Windows 11 update 22H2 or later only) |
| -DisableTelemetry                  |    Disable telemetry, diagnostic data & targeted ads. |
| -DisableBing                       |    Disable & remove bing search, bing AI & cortana in Windows search. |
| -DisableSuggestions                |    Disable tips, tricks, suggestions and ads in start, settings, notifications and Windows explorer. |
| <pre>-DisableLockscreenTips</pre>  |    Disable tips & tricks on the lockscreen. |
| -RevertContextMenu                 |    Restore the old Windows 10 style context menu. (Windows 11 only) |
| -ShowHiddenFolders                 |    Show hidden files, folders and drives. |
| -ShowKnownFileExt                  |    Show file extensions for known file types. |
| -HideDupliDrive                    |    Hide duplicate removable drive entries from the Windows explorer navigation pane, so only the entry under 'This PC' remains. |
| -TaskbarAlignLeft                  |    Align taskbar icons to the left. (Windows 11 only) |
| -HideSearchTb                      |    Hide search icon from the taskbar. (Windows 11 only) |
| -ShowSearchIconTb                  |    Show search icon on the taskbar. (Windows 11 only) |
| -ShowSearchLabelTb                 |    Show search icon with label on the taskbar. (Windows 11 only) |
| -ShowSearchBoxTb                   |    Show search box on the taskbar. (Windows 11 only) |
| -HideTaskview                      |    Hide the taskview button from the taskbar. (Windows 11 only) |
| -DisableCopilot                    |    Disable Windows copilot. (Windows 11 only) |
| -DisableWidgets                    |    Disable the widget service & hide the widget (news and interests) icon from the taskbar. |
| -HideChat                          |    Hide the chat (meet now) icon from the taskbar. |
| -HideOnedrive                      |    Hide the onedrive folder in the Windows explorer sidepanel. (Windows 10 only) |
| -Hide3dObjects                     |    Hide the 3D objects folder under 'This pc' in Windows explorer. (Windows 10 only) |
| -HideMusic                         |    Hide the music folder under 'This pc' in Windows explorer. (Windows 10 only) |
| -HideIncludeInLibrary              |    Hide the 'Include in library' option in the context menu. (Windows 10 only) |
| -HideGiveAccessTo                  |    Hide the 'Give access to' option in the context menu. (Windows 10 only) |
| -HideShare                         |    Hide the 'Share' option in the context menu. (Windows 10 only) |
