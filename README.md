# Win10Debloat
Win10Debloat is a simple and lightweight powershell script that removes pre-installed windows 10/11 bloatware apps and declutters the experience by disabling or removing intrusive interface elements and context menu items. The script is specifically designed to be simple, quick and most importantly safe to run, it does not touch any essential windows files, settings or programs that could cause issues in the future.

You can pick and choose exactly which modifications you want the script to make, but the default settings should be fine for most people. All of the changes can be reverted using the registry files that are included in the 'Regfiles' folder, and all of the apps that are removed by default can easily be reinstalled from the microsoft store.

### The windows 10 default settings will:
- Remove all bloatware apps from [this list](#these-apps-will-be-deleted-by-default).
- Hide the 3D objects folder under 'This pc' in windows explorer.
- Disable bing in windows search.
- Disable tips & tricks on the lockscreen. (This changes your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings.
- Disable the 'Include in library' from context menu.
- Disable the 'Give access to' from context menu.
- Disable the 'Share' from context menu. (Does not remove the onedrive share option)

### The windows 11 default settings will:
- Remove all bloatware apps from [this list](#these-apps-will-be-deleted-by-default).
- Disable bing in windows search.
- Disable tips & tricks on the lockscreen. (This changes your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings.

### Or select the 'Advanced' option in the menu to customize the script to your needs.

## Donate a cup of coffee to support my work
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## Usage
Disclaimer: I believe this script to be completely safe to run, but use this script at your own risk!

### Easy method:
1. [Download the latest version of the script](https://github.com/Raphire/Win10Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Run the script by right-clicking the 'Run.ps1' file and selecting the 'Run with Powershell' option.
3. Accept the windows UAC prompt to run the script as administrator, this is required for the script to function.
4. Select either default, or advanced setup depending on what changes you want to make. Advanced setup will allow you to choose exactly which changes you want to make, and which changes you want to skip.
5. Once the script has executed, restart your pc to ensure all changes are properly applied.

### Advanced method:
This method is a bit more complicated, but it gives you the option to run the script with certain arguments to tailor the behaviour of the script to your specific needs. It also has the added benefit that the script will run without requiring any user input during runtime, allowing you to automate the process.
1. [Download the latest version of the script](https://github.com/Raphire/Win10Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Open powershell as an administrator.
3. Enable powershell execution by entering the following command: <code>Set-ExecutionPolicy Unrestricted -Force</code>
4. In powershell, navigate to the directory where the files were extracted. Example: <code>cd c:\\Win10Debloat</code>
5. Enter this into powershell to run the script: <code>.\Win10Debloat.ps1</code> To run the script without any user input you can add arguments at the end, for example: <code>.\Win10Debloat.ps1 -RemoveApps -DisableBingSearches</code>

| Argument | Description |
| --------- | ----------- |
| -RunDefaults                  |    Run the script with windows 10 default settings. |
| -RunWin11Defaults             |    Run the script with windows 11 default settings. |
| -RemoveApps                   |    Remove all bloatware apps from [this list](#these-apps-will-be-deleted-by-default). |
| -DisableOnedrive              |    Hide the onedrive folder in the windows explorer sidebar. |
| -Disable3dObjects             |    Hide the 3D objects folder under 'This pc' in windows explorer. |
| -DisableMusic                 |    Hide the music folder under 'This pc' in windows explorer. |
| -DisableBingSearches          |    Disable bing in windows search. |
| -DisableLockscreenTips        |    Disable tips & tricks on the lockscreen. |
| -DisableWindowsSuggestions    |    Disable tips, tricks and suggestions in the startmenu and settings. |
| -DisableIncludeInLibrary      |    Disable the 'Include in library' option in the context menu. |
| -DisableGiveAccessTo          |    Disable the 'Give access to' option in the context menu. |
| -DisableShare                 |    Disable the 'Share' option in the context menu. |

## Debloat Windows 10/11
By default, this script will remove most, but not all of the pre-installed windows 10/11 applications. You customize which applications are removed by this script by editing the apps list found in the 'Win10Debloat.ps1' file.

### These apps will be deleted by default:
- king.com.BubbleWitch3Saga
- king.com.CandyCrushSaga
- king.com.CandyCrushSodaSaga
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
- Microsoft.Office.OneNote
- Microsoft.OneConnect
- Microsoft.Print3D
- Microsoft.SkypeApp
- Microsoft.WindowsFeedbackHub
- Microsoft.WindowsSoundRecorder
- Microsoft.ZuneMusic
- Microsoft.ZuneVideo

### These apps will NOT be deleted by default:
- Microsoft.MSPaint (Paint 3D)
- Microsoft.People
- Microsoft.ScreenSketch
- Microsoft.Windows.Photos
- Microsoft.WindowsAlarms
- Microsoft.WindowsCalculator
- Microsoft.WindowsCamera
- microsoft.windowscommunicationsapps (Mail & Calendar)
- Microsoft.WindowsMaps
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
- Hide the onedrive folder in the windows explorer sidebar.
- Hide the 3D objects folder under 'This pc' in windows explorer.
- Hide the music folder under 'This pc' in windows explorer.
- Disable bing in windows search.
- Disable tips & tricks on the lockscreen. (This changes your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings.
- Disable the 'Include in library' option in the context menu.
- Disable the 'Give access to' option in the context menu.
- Disable the 'Share' from context menu. (Does not remove the onedrive share option)

All of these changes can be reverted with the registry files that are included in the 'Regfiles' folder.
