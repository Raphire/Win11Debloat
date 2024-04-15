# Win11Debloater

This windows debloater is to be ran from Jumpcloud. It will remove the default set of applications. Switches used can also be found on the Jumpcloud command section.

![Win11Debloat Menu](/Assets/menu.png)

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
    - Microsoft.MicrosoftJournal
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
    - Microsoft.Edge (Edge browser, only removeable in the EEA)
    - Microsoft.GetHelp (Required for some Windows 11 Troubleshooters)
    - Microsoft.MSPaint (Paint 3D)
    - Microsoft.OutlookForWindows* (New mail app)
    - Microsoft.OneDrive (OneDrive consumer)
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
