# Win10Debloat
A simple powershell script that allows you to remove most pre-installed windows 10 apps, remove the 3d objects, onedrive and music folder from This PC in windows explorer and remove some context menu options.

## Removable Apps
By default, the script doesn't remove all of the default windows 10 apps, such as the windows store and the calculator. You can edit the apps list in the Win10Debloat.ps1 script to customize which apps you want to keep, and which apps you want the script to remove.

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
- Microsoft.WindowsCamera
- Microsoft.WindowsAlarms
- Microsoft.WindowsMaps
- Microsoft.MSPaint
- Microsoft.YourPhone
- Microsoft.XboxApp
- Microsoft.XboxGameOverlay
- Microsoft.XboxGamingOverlay
- Microsoft.XboxSpeechToTextOverlay

## Other Optional Changes
- Disable the onedrive folder in the windows explorer sidebar.
- Disable the 3D objects folder under 'This pc' in windows explorer.
- Disable the music folder under 'This pc' in windows explorer.
- Remove 'Include in library' from context menu.
- Remove 'Give access to' from context menu.
- Remove 'Share' from context menu.
