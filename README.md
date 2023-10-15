# Win11Debloat

Win11Debloat is a simple and lightweight powershell script that removes pre-installed windows bloatware apps, disables telemetry and declutters the experience by disabling or removing intrusive interface elements, ads and more. No need to painstakingly go through all the settings yourself, or remove apps one by one. Win11Debloat makes the process quick and easy!

You can pick and choose exactly which modifications you want the script to make, or use the default settings. If you are unhappy with any of the changes you can easily revert them by using the registry files that are included in the 'Regfiles' folder, all of the apps that are removed can be reinstalled from the Microsoft store.

#### Did this script help you? Please consider buying me a cup of coffee to support my work

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## Selecting the default settings will

- Remove all bloatware apps from [this list](#click-for-list-of-bloat-that-is-removed).
- Disable telemetry, diagnostic data, app-launch tracking & targeted ads.
- Disable bing search & cortana in windows search.
- Disable tips, tricks, suggestions and ads in start, settings, notifications, windows explorer, and on the lockscreen.
- Show file extensions for known file types.
- Disable the widget service & hide the widget (news and interests) icon from the taskbar. 
- Hide the Chat (meet now) icon from the taskbar.
- Hide the 3D objects folder under 'This pc' in windows explorer. (Windows 10 only)

## Selecting the custom configuration mode will

Give you access to even more options and allow you to customize the script to your exact needs. 

In this mode you'll be able to make any of the following changes:
- Remove all bloatware apps from [this list](#click-for-list-of-bloat-that-is-removed) and optionally also remove gaming-related apps.
- Disable telemetry, diagnostic data, app-launch tracking & targeted ads.
- Disable bing search, bing AI & cortana in windows search.
- Disable tips, tricks, suggestions and ads in start, settings, notifications, windows explorer, and on the lockscreen.
- Show hidden files, folders and drives.
- Show file extensions for known file types.
- Hide duplicate removable drive entries from the windows explorer navigation pane, so only the entry under 'This PC' remains.
- Remove all pinned apps from the start menu. NOTE: This applies to all existing and new users. (Windows 11 update 22H2 or later only)
- Align taskbar icons to the left. (Windows 11 only)
- Hide or change the search icon/box on the taskbar. (Windows 11 only)
- Hide the taskview button from the taskbar. (Windows 11 only)
- Disable Windows copilot. (Windows 11 only)
- Disable the widget service & hide the widget (news and interests) icon from the taskbar.
- Hide the chat (meet now) icon from the taskbar.
- Hide the 3D objects, music or onedrive folder in the windows explorer sidepanel. (Windows 10 only)
- Hide the 'Include in library', 'Give access to' and 'Share' options in the context menu. (Windows 10 only)

All of these changes can be individually reverted with the registry files that are included in the 'Regfiles' folder.

## Usage

Disclaimer: I believe this script to be completely safe to run, in fact, great care went into making sure this script does not break any OS functionality. But use this script at your own risk!

### Easy method

1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Navigate to the Win11Debloat folder
3. Double click the 'Run.bat' file to start the script. Note: If the console window immediately closes and nothing happens, try the advanced method below.
4. Accept the windows UAC prompt to run the script as administrator, this is required for the script to function.
5. A new powershell window will now open, showing the Win11Debloat menu. Select either the default or custom setup to continue.

### Advanced method

This method gives you the option to run the script with certain parameters to tailor the behaviour of the script to your needs and it allows you to run the script without requiring any user input during runtime, making it quicker and easier to deploy on a large number of systems.

1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Open powershell as an administrator.
3. Enable powershell execution by entering the following command: `Set-ExecutionPolicy Unrestricted -Scope Process`
4. In powershell, navigate to the directory where the files were extracted. Example: `cd c:\Win11Debloat`
5. Enter this into powershell to run the script: `.\Win11Debloat.ps1`
6. A menu will now open. Select either the default or custom setup to continue.

To run the script without any user input, simply add parameters at the end, example: `.\Win11Debloat.ps1 -RemoveApps -DisableBing -Silent`

| Parameter | Description |
| --------- | ----------- |
| -Silent                       |    Suppresses all interactive prompts, so the script will run without requiring any user input. |
| -RunDefaults                  |    Run the script with the default settings. |
| -RemoveApps                   |    Remove all bloatware apps from [this list](#click-for-list-of-bloat-that-is-removed). |
| -RemoveGamingApps             |    Remove the Xbox App and Xbox Gamebar. |
| -DisableTelemetry             |    Disable telemetry, diagnostic data & targeted ads. |
| -DisableBing                  |    Disable bing search, bing AI & cortana in windows search. |
| -DisableLockscreenTips        |    Disable tips & tricks on the lockscreen. |
| -DisableSuggestions           |    Disable tips, tricks, suggestions and ads in start, settings, notifications and windows explorer. |
| -ShowHiddenFolders            |    Show hidden files, folders and drives. |
| -ShowKnownFileExt             |    Show file extensions for known file types. |
| -HideDupliDrive               |    Hide duplicate removable drive entries from the windows explorer navigation pane, so only the entry under 'This PC' remains. |
| -TaskbarAlignLeft             |    Align taskbar icons to the left. (Windows 11 only) |
| -HideSearchTb                 |    Hide search icon from the taskbar. (Windows 11 only) |
| -ShowSearchIconTb             |    Show search icon on the taskbar. (Windows 11 only) |
| -ShowSearchLabelTb            |    Show search icon with label on the taskbar. (Windows 11 only) |
| -ShowSearchBoxTb              |    Show search box on the taskbar. (Windows 11 only) |
| -HideTaskview                 |    Hide the taskview button from the taskbar. (Windows 11 only) |
| -DisableCopilot               |    Disable Windows copilot (Windows 11 only) |
| -DisableWidgets               |    Disable the widget service & hide the widget (news and interests) icon from the taskbar. |
| -HideChat                     |    Hide the chat (meet now) icon from the taskbar. |
| -ClearStart                   |    Remove all pinned apps from the start menu. NOTE: This applies to all existing and new users. (Windows 11 update 22H2 or later only) |
| -HideOnedrive                 |    Hide the onedrive folder in the windows explorer sidepanel. (Windows 10 only) |
| -Hide3dObjects                |    Hide the 3D objects folder under 'This pc' in windows explorer. (Windows 10 only) |
| -HideMusic                    |    Hide the music folder under 'This pc' in windows explorer. (Windows 10 only) |
| -HideIncludeInLibrary         |    Hide the 'Include in library' option in the context menu. (Windows 10 only) |
| -HideGiveAccessTo             |    Hide the 'Give access to' option in the context menu. (Windows 10 only) |
| -HideShare                    |    Hide the 'Share' option in the context menu. (Windows 10 only) |

## Debloat Windows

By default, this script removes a large selection preinstalled bloatware, while preserving actually useful apps like the calculator, mail, media player and photos. If you do end up needing any of the removed apps in the future you can easily reinstall them through the Microsoft store. A full list of what is and isn't removed can be found below, but if you're unhappy with the default selection you can customize exactly which apps are removed by the script by editing the apps list found in the ['Appslist.txt'](https://github.com/Raphire/Win11Debloat/blob/master/Appslist.txt) and ['GamingAppslist.txt'](https://github.com/Raphire/Win11Debloat/blob/master/GamingAppslist.txt) files.

<details open>
  <summary><h4>Click for list of bloat that is removed</h4></summary>
  <blockquote>

    Microsoft bloat:
    - Clipchamp.Clipchamp  
    - Microsoft.3DBuilder  
    - Microsoft.549981C3F5F10 (Cortana app)
    - Microsoft.BingFinance  
    - Microsoft.BingFoodAndDrink 
    - Microsoft.BingHealthAndFitness
    - Microsoft.BingNews  
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
  </blockquote>
</details>

<details>
  <summary><h4>Click for list of what is NOT removed</h4></summary>
  <blockquote>
    
    Apps that are required or useful for most users:
    - Microsoft.GetHelp (Required for some Windows 11 Troubleshooters)
    - Microsoft.MSPaint (Paint 3D)
    - Microsoft.OutlookForWindows (New mail app)
    - Microsoft.Paint (Classic Paint)
    - Microsoft.People (Required for & included with Mail & Calendar)
    - Microsoft.RemoteDesktop  
    - Microsoft.ScreenSketch (Snipping Tool)
    - Microsoft.Whiteboard (Only preinstalled on devices with touchscreen and/or pen support)
    - Microsoft.Windows.Photos
    - Microsoft.WindowsCalculator
    - Microsoft.WindowsCamera
    - Microsoft.windowscommunicationsapps (Mail & Calendar)
    - Microsoft.WindowsStore (Microsoft Store, NOTE: This app cannot be reinstalled!)
    - Microsoft.WindowsTerminal (New default terminal app in windows 11)
    - Microsoft.YourPhone (Phone Link)
    - Microsoft.Xbox.TCUI (UI framework, removing this may break MS store, photos and certain games)
    - Microsoft.ZuneMusic (Modern Media Player)

    Apps that are required or useful for gaming:
    - Microsoft.GamingApp* (Modern Xbox Gaming App, required for installing some games)
    - Microsoft.XboxGameOverlay* (Game overlay, required for some games)
    - Microsoft.XboxGamingOverlay* (Game overlay, required for some games)
    - Microsoft.XboxIdentityProvider (Xbox sign-in framework, required for some games)
    - Microsoft.XboxSpeechToTextOverlay (Might be required for some games, NOTE: This app cannot be reinstalled!)

    * Can be removed in custom mode or by running the script with the '-RemoveGamingApps' parameter.
  </blockquote>
</details>