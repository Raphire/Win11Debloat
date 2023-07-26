# Win11Debloat

Win11Debloat is a simple and lightweight powershell script that removes pre-installed windows bloatware apps, disables telemetry and declutters the experience by disabling or removing intrusive interface elements, ads and context menu items. No need to painstakingly go through all the settings yourself, or remove apps one by one. Win11Debloat makes the process quick and simple!

You can pick and choose exactly which modifications you want the script to make, or use the default settings for your specific windows version. If you are unhappy with any of the changes you can easily revert them by using the registry files that are included in the 'Regfiles' folder, all of the apps that are removed can be reinstalled from the Microsoft store.

#### Did this script help you? Please consider buying me a cup of coffee to support my work

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## The windows 10 default settings will

- Remove all bloatware apps from [this list](#click-for-list-of-bloat-that-is-removed).
- Disable telemetry, diagnostic data & targeted ads.
- Disable bing search & cortana in windows search.
- Disable tips & tricks on the lockscreen. (This may change your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings, and sync provider ads in windows explorer.
- Disable the widget service & hide the widget (news and interests) icon on the taskbar. 
- Hide the Chat (meet now) icon from the taskbar.
- Hide the 3D objects folder under 'This pc' in windows explorer.
- Hide the 'Include in library', 'Give access to' and 'Share' options in the context menu.

## The windows 11 default settings will

- Remove all bloatware apps from [this list](#click-for-list-of-bloat-that-is-removed).
- Disable telemetry, diagnostic data & targeted ads.
- Disable bing search, bing AI & cortana in windows search.
- Disable tips & tricks on the lockscreen. (This may change your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings, and sync provider ads in windows explorer.
- Disable the widget service & hide the widget icon on the taskbar. 
- Hide the Chat icon from the taskbar.

## The 'Custom' option allows you to customize the script to your exact needs
A full list of what changes this script can make can be found [here](#improve-your-windows-experience). 

## Usage

Disclaimer: I believe this script to be completely safe to run, but use this script at your own risk!

### Easy method

1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Navigate to the Win11Debloat folder
3. Double click the 'Run.bat' file to start the script. Note: If the console window immediately closes and nothing happens, try the advanced method below.
4. Accept the windows UAC prompt to run the script as administrator, this is required for the script to function.
5. A new powershell window will now open, showing the Win11Debloat menu. Select either the default or custom setup to continue.

### Advanced method

This method gives you the option to run the script with certain parameters to tailor the behaviour of the script to your needs without requiring any user input during runtime, making it quicker and easier to deploy on a large number of systems.

1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Open powershell as an administrator.
3. Enable powershell execution by entering the following command: `Set-ExecutionPolicy Unrestricted -Force`
4. In powershell, navigate to the directory where the files were extracted. Example: `cd c:\\Win11Debloat`
5. Enter this into powershell to run the script: `.\Win11Debloat.ps1`
6. A menu will now open. Select either the default or custom setup to continue.

To run the script without any user input, simply add parameters at the end, example: `.\Win11Debloat.ps1 -RemoveApps -DisableBing`

| Parameter | Description |
| --------- | ----------- |
| -RunDefaults                  |    Run the script with windows 10 default settings. |
| -RunWin11Defaults             |    Run the script with windows 11 default settings. |
| -RemoveApps                   |    Remove all bloatware apps from [this list](#click-for-list-of-bloat-that-is-removed). |
| -DisableTelemetry             |    Disable telemetry, diagnostic data & targeted ads. |
| -DisableBing                  |    Disable bing search, bing AI & cortana in windows search. |
| -DisableLockscreenTips        |    Disable tips & tricks on the lockscreen. |
| -DisableSuggestions           |    Disable tips, tricks and suggestions in the startmenu and settings, and sync provider ads in windows explorer. |
| -TaskbarAlignLeft             |    Align taskbar icons to the left. (Windows 11 only) |
| -DisableWidgets               |    Disable the widget service & hide the widget (news and interests) icon on the taskbar. |
| -HideChat                     |    Hide the chat (meet now) icon on the taskbar. |
| -HideOnedrive                 |    Hide the onedrive folder in the windows explorer sidepanel. |
| -Hide3dObjects                |    Hide the 3D objects folder under 'This pc' in windows explorer. |
| -HideMusic                    |    Hide the music folder under 'This pc' in windows explorer. |
| -HideIncludeInLibrary         |    Hide the 'Include in library' option in the context menu. |
| -HideGiveAccessTo             |    Hide the 'Give access to' option in the context menu. |
| -HideShare                    |    Hide the 'Share' option in the context menu. |

## Debloat Windows

By default, this script removes a large selection preinstalled bloatware, while preserving actually useful apps like the calculator, mail, mediaplayer and photos. If you do end up needing any of the removed apps in the future you can easily reinstall them through the Microsoft store. A full list of what is and isn't removed can be found below, but if you're unhappy with the default selection you can customize exactly which apps are removed by the script by editing the apps list found in the ['Win11Debloat.ps1'](https://github.com/Raphire/Win11Debloat/blob/master/Win11Debloat.ps1) file.

<details>
  <summary><h4>Click for list of bloat that is removed</h4></summary>
  <blockquote>

    Microsoft bloat:
    - Microsoft.3DBuilder  
    - Microsoft.549981C3F5F10 (Cortana app)
    - Microsoft.Asphalt8Airborne  
    - Microsoft.BingFinance  
    - Microsoft.BingFoodAndDrink 
    - Microsoft.BingHealthAndFitness
    - Microsoft.BingNews  
    - Microsoft.BingSports  
    - Microsoft.BingTranslator  
    - Microsoft.BingTravel   
    - Microsoft.BingWeather  
    - Microsoft.GetHelp  
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
    - Microsoft.Office.OneNote  
    - Microsoft.Office.Sway  
    - Microsoft.OneConnect  
    - Microsoft.Print3D  
    - Microsoft.RemoteDesktop  
    - Microsoft.SkypeApp  
    - Microsoft.Todos  
    - Microsoft.WindowsAlarms  
    - Microsoft.WindowsFeedbackHub  
    - Microsoft.WindowsMaps  
    - Microsoft.WindowsSoundRecorder  
    - Microsoft.ZuneMusic  
    - Microsoft.ZuneVideo  
    - MicrosoftTeams

    Third party bloat:
    - ACGMediaPlayer  
    - ActiproSoftwareLLC  
    - AdobeSystemsIncorporated.AdobePhotoshopExpress  
    - Amazon.com.Amazon  
    - Asphalt8Airborne   
    - AutodeskSketchBook  
    - CaesarsSlotsFreeCasino  
    - Clipchamp.Clipchamp  
    - COOKINGFEVER  
    - CyberLinkMediaSuiteEssentials  
    - DisneyMagicKingdoms  
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
    
    Required or useful apps for regular desktop usage:
    - Microsoft.MSPaint (Paint 3D)
    - Microsoft.People (Required with Mail & Calendar)
    - Microsoft.ScreenSketch (Snipping Tool)
    - Microsoft.Whiteboard (Only preinstalled on devices with touchscreen and/or pen support)
    - Microsoft.Windows.Photos
    - Microsoft.WindowsCalculator
    - Microsoft.WindowsCamera
    - Microsoft.windowscommunicationsapps (Mail & Calendar)
    - Microsoft.WindowsStore (Microsoft Store, NOTE: This app cannot be reinstalled!)
    - Microsoft.YourPhone (Phone Link)
    - Microsoft.ZuneMusic (Modern Media Player)

    Required or useful apps for Microsoft store games:
    - Microsoft.GamingApp (Modern Xbox Gaming App, required for installing some PC games)
    - Microsoft.Xbox.TCUI
    - Microsoft.XboxApp (Old Xbox Console Companion App)
    - Microsoft.XboxGameOverlay
    - Microsoft.XboxGamingOverlay
    - Microsoft.XboxIdentityProvider
    - Microsoft.XboxSpeechToTextOverlay (NOTE: This app cannot be reinstalled!)
  </blockquote>
</details>

## Improve your Windows experience

This script can also make various changes to declutter & improve your overall windows experience, and protect your privacy. Such as:

- Disable telemetry, diagnostic data & targeted ads.
- Disable bing search, bing AI & cortana in windows search.
- Disable tips & tricks on the lockscreen. (This changes your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings, and sync provider ads in windows explorer.
- Align taskbar icons to the left. (Windows 11 only)
- Disable the widget service & hide the widget (news and interests) icon on the taskbar.
- Hide the chat (meet now) icon on the taskbar.
- Hide the onedrive folder in the windows explorer sidepanel. (Windows 10 only)
- Hide the 3D objects and/or music folders under 'This pc' in windows explorer. (Windows 10 only)
- Hide the 'Include in library', 'Give access to' and 'Share' options in the context menu. (Windows 10 only)

All of these changes can be individually reverted with the registry files that are included in the 'Regfiles' folder.