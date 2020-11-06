# Win10Debloat
Win10Debloat is a simple powershell script that allows you to remove most pre-installed windows 10 apps, disable bing in windows search, disable tips and suggestions across the OS (such as the lockscreen, startmenu and settings) and declutter the windows explorer by hiding certain folders (such as 3D objects) from the sidebar aswell as disabling certain context menu options that a regular user would (almost) never use.

You can pick and choose which modifications you want the script to make, but the default settings should be fine for most people. All of the changes can be reverted using the registry files that are included in the 'Regfiles' folder, and most if not all of the apps that are removed by default can easily be reinstalled from the microsoft store.

### By default, the Win10Debloat script will:
- Remove all bloatware apps from [this list](#these-apps-will-be-deleted-by-default).
- Hide the 3D objects folder under 'This pc' in windows explorer.
- Disable bing in windows search.
- Disable tips & tricks on the lockscreen. (This changes your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings.
- Disable the 'Include in library' from context menu.
- Disable the 'Give access to' from context menu.
- Disable the 'Share' from context menu.

## Usage
1. [Download the script](https://github.com/Raphire/Win10Debloat/archive/master.zip), and extract the .ZIP file to your desired location.
2. Run the script by right-clicking the 'Run.ps1' file and selecting 'Run with Powershell' option.
3. Accept the windows UAC prompt to run the script as administrator, this is required for the script to function.
4. Select either default, or advanced setup depending on what changes you want to make. Advanced setup will allow you to choose exactly which changes you want to make, and which changes you want to skip.
5. Once the script has executed, restart your pc to ensure all changes are properly applied.

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
- Microsoft.XboxApp
- Microsoft.XboxGameOverlay
- Microsoft.XboxGamingOverlay
- Microsoft.XboxSpeechToTextOverlay

## Declutter Windows 10
This script can also make various changes to declutter windows 10, such as:
- Hide the onedrive folder in the windows explorer sidebar.
- Hide the 3D objects folder under 'This pc' in windows explorer.
- Hide the music folder under 'This pc' in windows explorer.
- Disable bing in windows search.
- Disable tips & tricks on the lockscreen. (This changes your lockscreen wallpaper to the windows default)
- Disable tips, tricks and suggestions in the startmenu and settings.
- Disable the 'Include in library' from context menu.
- Disable the 'Give access to' from context menu.
- Disable the 'Share' from context menu.

All of these changes can be reverted with the registry files that are included in the 'Regfiles' folder.
