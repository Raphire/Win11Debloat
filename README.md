# Win10Debloat
A simple powershell script that allows you to remove most pre-installed windows 10 apps, hide the 3d objects, onedrive and music folder from 'This pc' in windows explorer and disable the 'Share', 'Give access to' and 'Include in library' options in the context menu.

## How to run
Step 1. To download the script, first click the green download button in the top right, next click 'Download ZIP'.

Step 2. Unzip the downloaded file to a location of your choosing and navigate to that location.

Step 3. Right-click the 'Run.ps1' file and select 'Run with Powershell'.

Step 4. Accept the UAC prompt asking for administrator permissions, this is required for the script to function.

Step 5. The script will now ask which changes you would like it to make, after which the script will start to execute them.

Step 6. Once the script has executed, simply restart your pc to ensure all changes are properly applied.

Step 7. Done!

## Removable Apps
By default, this script will not remove all of the pre-installed windows 10 applications. You configure which applications are removed by this script by editing the apps list found in the 'Win10Debloat.ps1' file.

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

It's possible to revert these optional changes with the registry files that are included in the 'Regfiles' folder.