# Win10Debloat
Win10Debloat is a simple powershell script that allows you to remove most pre-installed windows 10 apps, disable bing in windows search, disable tips and suggestions across the OS (such as the lockscreen, startmenu and settings) and declutter the windows explorer by hiding certain folders (such as 3D objects) from the sidebar aswell as disabling certain context menu options that a regular user would (almost) never use.

You can pick and choose which modifications you want the script to make, but the default settings should be fine for most people. All of the changes can be reverted using the registry files that are included in the 'Regfiles' folder, and all of the apps that are removed by default can easily be reinstalled from the microsoft store.

### By default, the Win10Debloat script will:
- Remove all bloatware apps from [this list](#these-apps-will-be-deleted-by-default).
- Hide the 3D objects folder under 'This pc' in windows explorer.
- Disable bing in windows search.
- Disable tips & tricks on the lockscreen. (This changes your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings.
- Disable the 'Include in library' from context menu.
- Disable the 'Give access to' from context menu.
- Disable the 'Share' from context menu. (Does not remove the onedrive share option)

### Or select the 'Advanced' option in the menu to customize the script to your needs.

## Usage
### Easy method:
1. [Download the latest version of the script](https://github.com/Raphire/Win10Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Run the script by right-clicking the 'Run.ps1' file and selecting 'Run with Powershell' option.
3. Accept the windows UAC prompt to run the script as administrator, this is required for the script to function.
4. Select either default, or advanced setup depending on what changes you want to make. Advanced setup will allow you to choose exactly which changes you want to make, and which changes you want to skip.
5. Once the script has executed, restart your pc to ensure all changes are properly applied.

### Advanced method:
This method is a bit more complicated, but it gives you the option to run the script with certain arguments to tailor the behaviour of the script to your specific needs. It also has the added benefit that the script will run without requiring any user input during runtime, allowing you to automate the process.
1. [Download the latest version of the script](https://github.com/Raphire/Win10Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Open powershell as an administrator.
3. Enable powershell execution by entering the following command: <code>Set-ExecutionPolicy Unrestricted -Force</code>
4. In powershell, navigate to the directory where the files were extracted. Example: <code>cd c:\\Win10Debloat</code>
5. Enter this into powershell to run the script: <code>.\Win10Debloat.ps1</code> To run the script with arguments simply add them at the end, as can be seen in this example: <code>.\Win10Debloat.ps1 -RemoveApps -DisableBingSearches</code>

| Argument | Description |
| --------- | ----------- |
| -RunDefaults                  |    Run the script with default settings. |
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

## Debloat Windows 10
By default, this script will remove most, but not all of the pre-installed windows 10 applications. You customize which applications are removed by this script by editing the apps list found in the 'Win10Debloat.ps1' file.

### These apps will be deleted by default:
- Microsoft.GetHelp
- Microsoft.Getstarted
- Microsoft.WindowsFeedbackHub
- Microsoft.BingNews
- Microsoft.BingFinance
- Microsoft.BingSports
- Microsoft.BingWeather
- Microsoft.BingTranslator
- Microsoft.MicrosoftOfficeHub
- Microsoft.Office.OneNote
- Microsoft.MicrosoftStickyNotes
- Microsoft.SkypeApp
- Microsoft.OneConnect
- Microsoft.Messaging
- Microsoft.WindowsSoundRecorder
- Microsoft.ZuneMusic
- Microsoft.ZuneVideo
- Microsoft.MixedReality.Portal
- Microsoft.3DBuilder
- Microsoft.Microsoft3DViewer
- Microsoft.Print3D
- Microsoft.549981C3F5F10 (Cortana)
- Microsoft.MicrosoftSolitaireCollection
- Microsoft.Asphalt8Airborne
- king.com.BubbleWitch3Saga
- king.com.CandyCrushSaga
- king.com.CandyCrushSodaSaga

### These apps will NOT be deleted by default:
- Microsoft.WindowsStore (NOTE: This app cannot be reinstalled!)
- Microsoft.WindowsCalculator
- Microsoft.Windows.Photos
- microsoft.windowscommunicationsapps (Mail & Calendar)
- Microsoft.People
- Microsoft.WindowsCamera
- Microsoft.WindowsAlarms
- Microsoft.WindowsMaps
- Microsoft.MSPaint (Paint 3D)
- Microsoft.ScreenSketch
- Microsoft.YourPhone
- Microsoft.Xbox.TCUI
- Microsoft.XboxApp
- Microsoft.XboxGameOverlay
- Microsoft.XboxGamingOverlay
- Microsoft.XboxIdentityProvider
- Microsoft.XboxSpeechToTextOverlay (NOTE: This app cannot be reinstalled from the microsoft store!)

## Declutter Windows 10
This script can also make various changes to declutter windows 10, such as:
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
