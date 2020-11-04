# Win10Debloat
A simple powershell script that allows you to remove most pre-installed windows 10 apps, hide the 3d objects, onedrive and music folder from 'This pc' in windows explorer and disable the 'Share', 'Give access to' and 'Include in library' options in the context menu.

## How to run
Step 1. Download the script by clicking the green 'Code' button on the main github page, and extract the .ZIP file to your preferred location.

Step 2. Run the script by right-clicking the 'Run.ps1' file and selecting 'Run with Powershell' option.

Step 3. Next, accept the windows UAC prompt to run the script as administrator, this is required for the script to function.

Step 4. The script will now ask which changes you would like it to make, and start executing them.

Step 5. Once the script has executed, restart your pc to ensure all changes are properly applied.

Step 6. Done!

## Apps that can be removed
By default, this script will remove most, but not all of the pre-installed windows 10 applications. You configure which applications are removed by this script by editing the apps list found in the 'Win10Debloat.ps1' file.

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

## Other Optional Changes
- Hide the onedrive folder in the windows explorer sidebar.
- Hide the 3D objects folder under 'This pc' in windows explorer.
- Hide the music folder under 'This pc' in windows explorer.
- Disable the 'Include in library' from context menu.
- Disable the 'Give access to' from context menu.
- Disable the 'Share' from context menu.

These changes can be reverted with the registry files that are included in the 'Regfiles' folder.
