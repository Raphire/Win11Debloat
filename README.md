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

 Win11Debloat is a simple, easy to use and lightweight PowerShell script that allows you to quickly declutter and improve your Windows experience. It can remove pre-installed bloatware apps, disable telemetry, remove intrusive interface elements and much more. No need to painstakingly go through all the settings yourself or remove apps one by one. Win11Debloat makes the process quick and easy!

The script also includes many features that system administrators will enjoy. Such as support for Windows Audit mode, the option to make changes to other Windows users and the ability to run the script without requiring user input during runtime. Please refer to our [wiki](https://github.com/Raphire/Win11Debloat/wiki/) for more details.

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
- Disable tips, tricks, suggestions and ads in start, settings, notifications, File Explorer, and on the lockscreen.
- Disable ads and the MSN news feed in Microsoft Edge.
- Disable the 'Windows Spotlight' desktop background option.

#### Bing Web Search, Copilot & AI Features

- Disable & remove Bing web search, Bing AI and Cortana from Windows search.
- Disable & remove Microsoft Copilot.
- Disable Windows Recall snapshots. (W11 only)
- Disable AI Features in Edge (W11 only)
- Disable AI Features in Paint (W11 only)
- Disable AI Features in Notepad (W11 only)

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
- Hide or change the search icon/box on the taskbar. (W11 only)
- Hide the taskview button from the taskbar. (W11 only)
- Disable widgets on the taskbar & lockscreen.
- Hide the chat (meet now) icon from the taskbar.
- Enable the 'End Task' option in the taskbar right click menu. (W11 only)
- Enable the 'Last Active Click' behavior in the taskbar app area. This allows you to repeatedly click on an application's icon in the taskbar to switch focus between the open windows of that application.

#### Start

- Disable the recommended section in the start menu. (W11 only)
- Disable the Phone Link mobile devices integration in the start menu. (W11 only)

#### Other

- Disable Xbox game/screen recording, this also stops gaming overlay popups.
- Disable Fast Start-up to ensure a full shutdown.
- Disable network connectivity during Modern Standby to reduce battery drain. (W11 only)
- Option to [apply changes to a different user](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#running-as-another-user), instead of the currently logged in user.
- [Sysprep mode](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#sysprep-mode) to apply changes to the Windows Default user profile. Afterwards, all new users will have the changes automatically applied to them.

### Default Settings

Win11Debloat offers a default mode that allows you to quickly and easily apply the changes that are recommended for most people. This includes uninstalling apps that most would consider bloatware, removing many annoying distractions and disabling telemetry and tracking. To apply the default settings, launch the script as you normally would and select option `1` in the script menu. Alternatively, you can launch the script with the `-RunDefaults` parameter. Example:

```Powershell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/"))) -RunDefaults
```
  
#### Changes included in the default mode
- Remove the default selection of bloatware apps. (See below for full list)
- Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads.
- Disable tips, tricks, suggestions and ads in start, settings, notifications, File Explorer, and on the lockscreen.
- Disable ads, suggestions and the MSN news feed in Microsoft Edge.
- Disable & remove Bing web search, Bing AI and Cortana from Windows search.
- Disable & remove Microsoft Copilot.
- Disable Windows Recall snapshots. (W11 only)
- Disable Fast Start-up to ensure a full shutdown.
- Disable network connectivity during Modern Standby to reduce battery drain. (W11 only)
- Show file extensions for known file types.
- Hide the 3D objects folder under 'This pc' from File Explorer. (W10 only)
- Disable widgets on the taskbar & lockscreen.
- Hide the Chat (meet now) icon from the taskbar.

#### Apps that ARE removed as part of the default mode

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
    - Microsoft.Copilot
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
    - Microsoft.StartExperiencesApp** (Widgets app)
    - Microsoft.SkypeApp  
    - Microsoft.Todos  
    - Microsoft.WindowsAlarms  
    - Microsoft.WindowsFeedbackHub  
    - Microsoft.WindowsMaps  
    - Microsoft.WindowsSoundRecorder  
    - Microsoft.XboxApp (Old Xbox Console Companion App, no longer supported)
    - Microsoft.ZuneVideo  
    - MicrosoftCorporationII.MicrosoftFamily (Microsoft Family Safety)
    - MicrosoftCorporationII.QuickAssist (Remote assistance tool)
    - MicrosoftTeams (Old personal version of MS Teams from the MS Store)
    - MSTeams (New MS Teams app)

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
    
    * Removed when disabling Bing web search, Bing AI and Cortana from Windows search
    ** Removed when disabling widgets on the taskbar & lockscreen
</blockquote>
</details>

#### Apps that are NOT removed as part of the default mode

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
    - Microsoft.WindowsNotepad
    - Microsoft.windowscommunicationsapps* (Mail & Calendar)
    - Microsoft.WindowsStore (Microsoft Store, NOTE: This app cannot be reinstalled!)
    - Microsoft.WindowsTerminal (New default terminal app in Windows 11)
    - Microsoft.YourPhone (Phone Link)
    - Microsoft.Xbox.TCUI (UI framework, removing this may break MS store, photos and certain games)
    - Microsoft.ZuneMusic (Modern Media Player)
    - MicrosoftWindows.CrossDevice (Phone integration within File Explorer, Camera and more)

    HP apps that are not removed by default:
    - AD2F1837.HPAIExperienceCenter*
    - AD2F1837.HPConnectedMusic*
    - AD2F1837.HPConnectedPhotopoweredbySnapfish*
    - AD2F1837.HPDesktopSupportUtilities*
    - AD2F1837.HPEasyClean*
    - AD2F1837.HPFileViewer*
    - AD2F1837.HPJumpStarts*
    - AD2F1837.HPPCHardwareDiagnosticsWindows*
    - AD2F1837.HPPowerManager*
    - AD2F1837.HPPrinterControl*
    - AD2F1837.HPPrivacySettings*
    - AD2F1837.HPQuickDrop*
    - AD2F1837.HPQuickTouch*
    - AD2F1837.HPRegistration*
    - AD2F1837.HPSupportAssistant*
    - AD2F1837.HPSureShieldAI*
    - AD2F1837.HPSystemInformation*
    - AD2F1837.HPWelcome*
    - AD2F1837.HPWorkWell*
    - AD2F1837.myHP*

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

    * Can be removed by running the script with the relevant parameter. (Please refer to the wiki for more details)
</blockquote>
</details>

## License

Win11Debloat is licensed under the MIT license. See the LICENSE file for more information.
