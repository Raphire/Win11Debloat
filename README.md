<div align="center" markdown="1">
   <sup>Special thanks to:</sup>
   <br>
   <br>
   <a href="https://www.warp.dev/windebloat">
      <img alt="Warp sponsorship" width="400" src="https://github.com/user-attachments/assets/c21102f7-bab9-4344-a731-0cf6b341cab2">
   </a>

### [Warp, the intelligent terminal for developers](https://www.warp.dev/windebloat)
[Available for MacOS, Linux, & Windows](https://www.warp.dev/windebloat)<br>

</div>
<hr>

# Win11Debloat

[![GitHub Release](https://img.shields.io/github/v/release/Raphire/Win11Debloat?style=for-the-badge&label=Latest%20release)](https://github.com/Raphire/Win11Debloat/releases/latest)
[![Join the Discussion](https://img.shields.io/badge/Join-the%20Discussion-2D9F2D?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Raphire/Win11Debloat/discussions)
[![Static Badge](https://img.shields.io/badge/Documentation-_?style=for-the-badge&logo=bookstack&color=grey)](https://github.com/Raphire/Win11Debloat/wiki/)

 Win11Debloat is a lightweight, easy to use PowerShell script that allows you to quickly declutter and improve your Windows experience. It can remove pre-installed bloatware apps, disable telemetry, remove intrusive interface elements and much more. No need to painstakingly go through all the settings yourself or remove apps one by one. Win11Debloat makes the process quick and easy!

The script also includes many features that system administrators and power users will enjoy. Such as support for Windows Audit mode, the option to make changes to other Windows users and the ability to access all of Win11Debloat's features right from the command-line. Please refer to our [wiki](https://github.com/Raphire/Win11Debloat/wiki/) for more details.

![Win11Debloat Menu](/Assets/menu.png)

#### Did this script help you? Please consider buying me a cup of coffee to support my work

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## Usage

> [!Warning]
> Great care went into making sure this script does not unintentionally break any OS functionality, but use at your own risk! If you run into any issues, please report them [here](https://github.com/Raphire/Win11Debloat/issues).

### Quick method

Download & run the script automatically via PowerShell.

1. Open PowerShell or Terminal, preferably as an administrator.
2. Copy and paste the command below into PowerShell:

```PowerShell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
```

3. Wait for the script to automatically download Win11Debloat.
4. Carefully read through and follow the on-screen instructions.

This method supports command-line parameters to customize the behaviour of the script. Please click [here](https://github.com/Raphire/Win11Debloat/wiki/How-To-Use#parameters) for more information.

### Traditional method

<details>
  <summary>Manually download & run the script.</summary><br/>

  1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/releases/latest), and extract the .ZIP file to your desired location.
  2. Navigate to the Win11Debloat folder
  3. Double click the `Run.bat` file to start the script. NOTE: If the console window immediately closes and nothing happens, try the advanced method below.
  4. Accept the Windows UAC prompt to run the script as administrator, this is required for the script to function.
  5. Carefully read through and follow the on-screen instructions.
</details>

### Advanced method

<details>
  <summary>Manually download the script & run the script via PowerShell. Recommended for advanced users.</summary><br/>

  1. [Download the latest version of the script](https://github.com/Raphire/Win11Debloat/releases/latest), and extract the .ZIP file to your desired location.
  2. Open PowerShell or Terminal as an administrator.
  3. Temporarily enable PowerShell execution by entering the following command:

  ```PowerShell
  Set-ExecutionPolicy Unrestricted -Scope Process -Force
  ```

  4. In PowerShell, navigate to the directory where the files were extracted. Example: `cd c:\Win11Debloat`
  5. Now run the script by entering the following command:

  ```PowerShell
  .\Win11Debloat.ps1
  ```

  6. Carefully read through and follow the on-screen instructions.

  This method supports command-line parameters to customize the behaviour of the script. Please click [here](https://github.com/Raphire/Win11Debloat/wiki/How-To-Use#parameters) for more information.
</details>

## Features

Below is an overview of the key features and functionality offered by Win11Debloat. For more information about what features are included in the default mode please refer to [this section](#default-settings) below.

> [!Tip]
> All of the changes made by Win11Debloat can easily be reverted and almost all of the apps can be reinstalled through the Microsoft Store. A full guide on how to revert changes can be found [here](https://github.com/Raphire/Win11Debloat/wiki/Reverting-Changes).

#### App Removal

- Remove a wide variety of preinstalled apps. Click [here](https://github.com/Raphire/Win11Debloat/wiki/App-Removal) for more info.
- Remove or replace all pinned apps from start for the current user, or for all existing & new users. (W11 only)

#### Telemetry, Tracking & Suggested Content

- Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads.
- Disable tips, tricks, suggestions & ads across Windows.
- Disable ads, suggestions and the MSN news feed in Microsoft Edge.
- Disable the 'Windows Spotlight' desktop background option.

#### Bing Web Search, Copilot & AI Features

- Disable & remove Bing web search, Bing AI and Cortana from Windows search.
- Disable & remove Microsoft Copilot.
- Disable Windows Recall. (W11 only)
- Disable Click to Do, AI text & image analysis tool. (W11 only)
- Disable AI Features in Edge. (W11 only)
- Disable AI Features in Paint. (W11 only)
- Disable AI Features in Notepad. (W11 only)

#### Personalisation

- Enable dark mode for system and apps.
- Disable transparency, animations and visual effects.
- Turn off Enhance Pointer Precision, also known as mouse acceleration.
- Disable the Sticky Keys keyboard shortcut. (W11 only)
- Restore the old Windows 10 style context menu. (W11 only)
- Hide the 'Include in library', 'Give access to' and 'Share' options from the context menu. (W10 only)

#### File Explorer

- Change the default location that File Explorer opens to.
- Show hidden files, folders and drives.
- Show file extensions for known file types.
- Hide the Home or Gallery section from the File Explorer navigation pane. (W11 only)
- Hide the 3D objects, music or OneDrive folder from the File Explorer navigation pane. (W10 only)
- Hide duplicate removable drive entries from the File Explorer navigation pane, so only the entry under 'This PC' remains.

#### Taskbar

- Align taskbar icons to the left. (W11 only)
- Choose combine mode for taskbar buttons and labels. (W11 only)
- Choose how app icons are shown on the taskbar when using multiple monitors. (W11 only)
- Hide or change the search icon/box on the taskbar. (W11 only)
- Hide the taskview button from the taskbar. (W11 only)
- Disable widgets on the taskbar & lockscreen.
- Hide the chat (meet now) icon from the taskbar. (W10 only)
- Enable the 'End Task' option in the taskbar right click menu. (W11 only)
- Enable the 'Last Active Click' behavior in the taskbar app area. This allows you to repeatedly click on an application's icon in the taskbar to switch focus between the open windows of that application.

#### Start

- Disable the recommended section in the start menu. (W11 only)
- Disable the Phone Link mobile devices integration in the start menu. (W11 only)

#### Other

- Disable Xbox Game Bar integration & game/screen recording. This also disables `ms-gamingoverlay`/`ms-gamebar` popups if you uninstall the Xbox Game Bar.
- Disable Fast Start-up to ensure a full shutdown.
- Disable network connectivity during Modern Standby to reduce battery drain. (W11 only)

#### Advanced Features

- Option to [apply changes to a different user](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#running-as-another-user), instead of the currently logged in user.
- [Sysprep mode](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#sysprep-mode) to apply changes to the Windows Default user profile. Which ensures, all new users will have the changes automatically applied to them.

### Default Settings

Win11Debloat's default mode allows you to quickly and easily apply the changes that are recommended for most people. This includes removing many annoying distractions, disabling telemetry and tracking and optionally uninstalling the default or your custom selection of apps. To apply the default settings, launch the script as you normally would and select option `1` in the script menu.

Alternatively, you can launch the script with the `-RunDefaults` or `-RunDefaultsLite` parameters to immediately run the defaults without going through the menu or the app removal options. Using the `-RunDefaults` parameter will run the script in default mode and remove the default selection of apps. While using the `-RunDefaultsLite` parameter will run the script in default mode without removing any apps. Example:
```Powershell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/"))) -RunDefaults
```
  
#### Changes included in the default mode
- Remove the default or your custom selection of apps. (See below for the default selection of apps)
- Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads.
- Disable tips, tricks, suggestions & ads across Windows.
- Disable ads, suggestions and the MSN news feed in Microsoft Edge.
- Disable & remove Bing web search, Bing AI and Cortana from Windows search.
- Disable & remove Microsoft Copilot.
- Disable Windows Recall. (W11 only)
- Disable Click to Do, AI text & image analysis tool. (W11 only)
- Disable Fast Start-up to ensure a full shutdown.
- Disable network connectivity during Modern Standby to reduce battery drain. (W11 only)
- Show file extensions for known file types.
- Hide the 3D objects folder under 'This pc' from File Explorer. (W10 only)
- Disable widgets on the taskbar & lockscreen.
- Hide the Chat (meet now) icon from the taskbar. (W10 only)

#### Apps that ARE removed by default

These apps are uninstalled when you opt to remove the default selection of apps.

<details>
  <summary>Click to expand</summary>
  <blockquote>
    
    Microsoft apps:
    - Clipchamp.Clipchamp (Video editor from Microsoft)
    - Microsoft.3DBuilder (Basic 3D modeling software)
    - Microsoft.549981C3F5F10 (Cortana app, discontinued)
    - Microsoft.BingFinance (Finance news and tracking via Bing, discontinued)
    - Microsoft.BingFoodAndDrink (Recipes and food news via Bing, discontinued)
    - Microsoft.BingHealthAndFitness (Health and fitness tracking/news via Bing, discontinued)
    - Microsoft.BingNews (News aggregator via Bing, replaced by Microsoft News/Start)
    - Microsoft.BingSports (Sports news and scores via Bing, discontinued)
    - Microsoft.BingTranslator (Translation service via Bing)
    - Microsoft.BingTravel (Travel planning and news via Bing, discontinued)
    - Microsoft.BingWeather (Weather forecast via Bing)
    - Microsoft.Copilot (AI assistant integrated into Windows)
    - Microsoft.Getstarted (Tips and introductory guide for Windows, cannot be uninstalled in Windows 11)
    - Microsoft.Messaging (Messaging app, often integrates with Skype, largely deprecated) 
    - Microsoft.Microsoft3DViewer (Viewer for 3D models)
    - Microsoft.MicrosoftJournal (Digital note-taking app optimized for pen input)
    - Microsoft.MicrosoftOfficeHub (Hub to access Microsoft Office apps and documents, precursor to Microsoft 365 app)
    - Microsoft.MicrosoftPowerBIForWindows (Business analytics service client)
    - Microsoft.MicrosoftSolitaireCollection (Collection of solitaire card games)
    - Microsoft.MicrosoftStickyNotes (Digital sticky notes app, deprecated & replaced by OneNote)
    - Microsoft.MixedReality.Portal (Portal for Windows Mixed Reality headsets)
    - Microsoft.NetworkSpeedTest (Internet connection speed test utility)
    - Microsoft.News (News aggregator. Replaced Bing News and now part of Microsoft Start)
    - Microsoft.Office.OneNote (Digital note-taking app, Universal Windows Platform version)
    - Microsoft.Office.Sway (Presentation and storytelling app)
    - Microsoft.OneConnect (Mobile Operator management app, replaced by Mobile Plans)
    - Microsoft.PowerAutomateDesktop (Desktop automation tool)
    - Microsoft.Print3D (3D printing preparation software)
    - Microsoft.SkypeApp (Skype communication app, Universal Windows Platform version)
    - Microsoft.Todos (To-do list and task management app)
    - Microsoft.Windows.DevHome (Developer dashboard and tool configuration utility, no longer supported)
    - Microsoft.WindowsAlarms (Alarms & Clock app)
    - Microsoft.WindowsFeedbackHub (App for providing feedback to Microsoft on Windows)
    - Microsoft.WindowsMaps (Mapping and navigation app)
    - Microsoft.WindowsSoundRecorder (Basic audio recording app)
    - Microsoft.XboxApp (Old Xbox Console Companion App, no longer supported)
    - Microsoft.ZuneVideo (Movies & TV app for renting/buying/playing video content. Rebranded as "Films & TV")
    - MicrosoftCorporationII.MicrosoftFamily (Family Safety App for managing family accounts and settings)
    - MicrosoftCorporationII.QuickAssist (Remote assistance tool)
    - MicrosoftTeams (Old MS Teams personal, MS Store version)
    - MSTeams (New MS Teams app. Work/School or Personal)

    Third party apps:    
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

#### Apps that are NOT removed by default

These apps will not be removed by Win11Debloat unless explicitly selected by the user.

<details>
  <summary>Click to expand</summary>
  <blockquote>

    Miscellaneous apps:
    - Microsoft.Edge (Edge browser, only removeable in the EEA)
    - Microsoft.GetHelp (Required for some Windows 11 Troubleshooters)
    - Microsoft.M365Companions (Microsoft 365 Business Calendar, Files and People mini-apps, these apps may be reinstalled if enabled by your Microsoft 365 admin)
    - Microsoft.MSPaint (Paint 3D)
    - Microsoft.OutlookForWindows (New mail app)
    - Microsoft.OneDrive (OneDrive consumer)
    - Microsoft.Paint (Classic Paint)
    - Microsoft.People (Required for & included with Mail & Calendar)
    - Microsoft.RemoteDesktop
    - Microsoft.ScreenSketch (Snipping Tool)
    - Microsoft.Whiteboard (Only preinstalled on devices with touchscreen and/or pen support)
    - Microsoft.Windows.Photos
    - Microsoft.WindowsCalculator
    - Microsoft.WindowsCamera
    - Microsoft.WindowsNotepad
    - Microsoft.windowscommunicationsapps (Mail & Calendar)
    - Microsoft.WindowsStore (Microsoft Store, NOTE: This app cannot be reinstalled!)
    - Microsoft.WindowsTerminal (New default terminal app in Windows 11)
    - Microsoft.YourPhone (Phone Link)
    - Microsoft.Xbox.TCUI (UI framework, removing this may break MS store, photos and certain games)
    - Microsoft.ZuneMusic (Modern Media Player)
    - MicrosoftWindows.CrossDevice (Phone integration within File Explorer, Camera and more)

    Gaming related apps:
    - Microsoft.GamingApp (Modern Xbox Gaming App, required for installing some games)
    - Microsoft.XboxGameOverlay (Game overlay, required for some games)
    - Microsoft.XboxGamingOverlay (Game overlay, required for some games)
    - Microsoft.XboxIdentityProvider (Xbox sign-in framework, required for some games)
    - Microsoft.XboxSpeechToTextOverlay (Might be required for some games, NOTE: This app cannot be reinstalled!)

    HP apps:
    - AD2F1837.HPAIExperienceCenter
    - AD2F1837.HPConnectedMusic
    - AD2F1837.HPConnectedPhotopoweredbySnapfish
    - AD2F1837.HPDesktopSupportUtilities
    - AD2F1837.HPEasyClean
    - AD2F1837.HPFileViewer
    - AD2F1837.HPJumpStarts
    - AD2F1837.HPPCHardwareDiagnosticsWindows
    - AD2F1837.HPPowerManager
    - AD2F1837.HPPrinterControl
    - AD2F1837.HPPrivacySettings
    - AD2F1837.HPQuickDrop
    - AD2F1837.HPQuickTouch
    - AD2F1837.HPRegistration
    - AD2F1837.HPSupportAssistant
    - AD2F1837.HPSureShieldAI
    - AD2F1837.HPSystemInformation
    - AD2F1837.HPWelcome
    - AD2F1837.HPWorkWell
    - AD2F1837.myHP
</blockquote>
</details>

## License

Win11Debloat is licensed under the MIT license. See the LICENSE file for more information.
