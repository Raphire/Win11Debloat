# Win10Debloat
Win10Debloat is a simple and lightweight powershell script that removes pre-installed windows 10/11 bloatware apps, disables telemetry and declutters the experience by disabling or removing intrusive interface elements, ads and context menu items. No need to painstakingly go through all the settings yourself, or removing apps one by one. Win10Debloat makes the process quick and simple! 

You can pick and choose exactly which modifications you want the script to make, but the default settings should be fine for most people. All of the changes can be easily reverted using the registry files that are included in the 'Regfiles' folder, and all of the apps that are removed by default can be reinstalled from the microsoft store.

### The windows 10 default settings will:
- Remove all bloatware apps from [this list](#these-apps-will-be-deleted-by-default).
- Disable telemetry, diagnostic data & targeted ads.
- Disable bing & cortana in windows search.
- Disable tips & tricks on the lockscreen. (This may change your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings, and sync provider ads in windows explorer.
- Hide the Chat (meet now) & Widget (news and interests) icons from the taskbar.
- Hide the 3D objects folder under 'This pc' in windows explorer.
- Disable the 'Include in library' from context menu.
- Disable the 'Give access to' from context menu.
- Disable the 'Share' from context menu. (Does not remove the onedrive share option)

### The windows 11 default settings will:
- Remove all bloatware apps from [this list](#these-apps-will-be-deleted-by-default).
- Disable telemetry, diagnostic data & targeted ads.
- Disable bing & cortana in windows search.
- Disable tips & tricks on the lockscreen. (This may change your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings, and sync provider ads in windows explorer.
- Hide the Chat & Widget icons from the taskbar.

### Or select the 'Custom' option in the menu to customize the script to your needs.

## Donate a cup of coffee to support my work
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## Usage
Disclaimer: I believe this script to be completely safe to run, but use this script at your own risk!

### Easy method:
1. [Download the latest version of the script](https://github.com/Raphire/Win10Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Navigate to the Win10Debloat folder
3. Double click the 'Run.bat' file to start the script.
4. Accept the windows UAC prompt to run the script as administrator, this is required for the script to function.
5. Select either default, or custom setup depending on what changes you want to make. Custom setup will allow you to choose exactly which changes you want to make, and which changes you want to skip.

### Advanced method:
This method gives you the option to run the script with certain arguments to tailor the behaviour of the script to your needs without requiring any user input during runtime, making it quicker and easier to deploy on a large number of systems.
1. [Download the latest version of the script](https://github.com/Raphire/Win10Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Open powershell as an administrator.
3. Enable powershell execution by entering the following command: <code>Set-ExecutionPolicy Unrestricted -Force</code>
4. In powershell, navigate to the directory where the files were extracted. Example: <code>cd c:\\Win10Debloat</code>
5. Enter this into powershell to run the script: <code>.\Win10Debloat.ps1</code> To run the script without any user input you can add arguments at the end, for example: <code>.\Win10Debloat.ps1 -RemoveApps -DisableBing</code>

| Argument | Description |
| --------- | ----------- |
| -RunDefaults                  |    Run the script with windows 10 default settings. |
| -RunWin11Defaults             |    Run the script with windows 11 default settings. |
| -RemoveApps                   |    Remove all bloatware apps from [this list](#these-apps-will-be-deleted-by-default). |
| -DisableTelemetry             |    Disable telemetry, diagnostic data & targeted ads. |
| -DisableBing                  |    Disable bing & cortana in windows search. |
| -DisableLockscreenTips        |    Disable tips & tricks on the lockscreen. |
| -DisableWindowsSuggestions    |    Disable tips, tricks and suggestions in the startmenu and settings, and sync provider ads in windows explorer. |
| -DisableChat                  |    Hide the chat (meet now) icon on the taskbar. |
| -DisableWidgets               |    Hide the widget (news and interests) icon on the taskbar. |
| -DisableOnedrive              |    Hide the onedrive folder in the windows explorer sidepanel. |
| -Disable3dObjects             |    Hide the 3D objects folder under 'This pc' in windows explorer. |
| -DisableMusic                 |    Hide the music folder under 'This pc' in windows explorer. |
| -DisableIncludeInLibrary      |    Disable the 'Include in library' option in the context menu. |
| -DisableGiveAccessTo          |    Disable the 'Give access to' option in the context menu. |
| -DisableShare                 |    Disable the 'Share' option in the context menu. |

## Debloat Windows 10/11
By default, this script only removes apps that most people are unlikely to ever need or use. You can of course customize which apps are removed by this script by editing the apps list found in the 'Win10Debloat.ps1' file.

### These apps will be deleted by default:
- 2FE3CB00.PICSART-PHOTOSTUDIO
- 9E2F88E3.TWITTER
- AdobeSystemsIncorporated.AdobePhotoshopExpress
- Clipchamp.Clipchamp
- Duolingo-LearnLanguagesforFree
- Facebook
- Flipboard
- HULULLC.HULUPLUS
- Microsoft.3DBuilder
- Microsoft.549981C3F5F10 (Cortana)
- Microsoft.Asphalt8Airborne
- Microsoft.BingFinance
- Microsoft.BingNews
- Microsoft.BingSports
- Microsoft.BingTranslator
- Microsoft.BingWeather
- Microsoft.GetHelp
- Microsoft.Getstarted
- Microsoft.Messaging
- Microsoft.Microsoft3DViewer
- Microsoft.MicrosoftOfficeHub
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
- Microsoft.WindowsAlarms
- Microsoft.WindowsFeedbackHub
- Microsoft.WindowsMaps
- Microsoft.WindowsSoundRecorder
- Microsoft.ZuneMusic
- Microsoft.ZuneVideo
- PandoraMediaInc
- Royal Revolt
- SpotifyAB.SpotifyMusic
- Twitter
- Wunderlist
- king.com.BubbleWitch3Saga
- king.com.CandyCrushSaga
- king.com.CandyCrushSodaSaga

### These apps will NOT be deleted by default:
- Microsoft.MSPaint (Paint 3D)
- Microsoft.People
- Microsoft.ScreenSketch
- Microsoft.Windows.Photos
- Microsoft.WindowsCalculator
- Microsoft.WindowsCamera
- microsoft.windowscommunicationsapps (Mail & Calendar)
- Microsoft.WindowsStore (NOTE: This app cannot be reinstalled!)
- Microsoft.Xbox.TCUI
- Microsoft.XboxApp
- Microsoft.XboxGameOverlay
- Microsoft.XboxGamingOverlay
- Microsoft.XboxIdentityProvider
- Microsoft.XboxSpeechToTextOverlay (NOTE: This app cannot be reinstalled from the microsoft store!)
- Microsoft.YourPhone

## Declutter Windows 10/11
This script can also make various changes to declutter windows 10/11, such as:
- Disable telemetry, diagnostic data & targeted ads.
- Disable bing & cortana in windows search.
- Disable tips & tricks on the lockscreen. (This changes your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings, and sync provider ads in windows explorer.
- Hide the chat (meet now) icon on the taskbar.
- Hide the widget (news and interests) icon on the taskbar.
- Hide the onedrive folder in the windows explorer sidepanel.
- Hide the 3D objects folder under 'This pc' in windows explorer.
- Hide the music folder under 'This pc' in windows explorer.
- Disable the 'Include in library' option in the context menu.
- Disable the 'Give access to' option in the context menu.
- Disable the 'Share' from context menu. (Does not remove the onedrive share option)

All of these changes can be reverted with the registry files that are included in the 'Regfiles' folder.
