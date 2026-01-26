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

Below is an overview of the key features and functionality offered by Win11Debloat. Please refer to [the wiki](https://github.com/Raphire/Win11Debloat/wiki/Default-Settings) for more information about the default settings preset.

> [!Tip]
> All of the changes made by Win11Debloat can easily be reverted and almost all of the apps can be reinstalled through the Microsoft Store. A full guide on how to revert changes can be found [here](https://github.com/Raphire/Win11Debloat/wiki/Reverting-Changes).

#### App Removal

- Remove a wide variety of preinstalled apps. Click [here](https://github.com/Raphire/Win11Debloat/wiki/App-Removal) for more info.

#### Privacy & Suggested Content

- Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads.
- Disable tips, tricks, suggestions & ads across Windows.
- Disable 'Windows Spotlight' and tips & tricks on the lock screen.
- Disable 'Windows Spotlight' desktop background option.
- Disable ads, suggestions and the MSN news feed in Microsoft Edge.

#### AI Features

- Disable & remove Microsoft Copilot.
- Disable Windows Recall. (W11 only)
- Disable Click to Do, AI text & image analysis tool. (W11 only)
- Disable AI Features in Edge. (W11 only)
- Disable AI Features in Paint. (W11 only)
- Disable AI Features in Notepad. (W11 only)

#### System

- Disable the Drag Tray for sharing & moving files. (W11 only)
- Restore the old Windows 10 style context menu. (W11 only)
- Turn off Enhance Pointer Precision, also known as mouse acceleration.
- Disable the Sticky Keys keyboard shortcut. (W11 only)
- Disable fast start-up to ensure a full shutdown.
- Disable network connectivity during Modern Standby to reduce battery drain. (W11 only)

#### Appearance

- Enable dark mode for system and apps.
- Disable transparency effects
- Disable animations and visual effects.

#### File Explorer

- Change the default location that File Explorer opens to.
- Show file extensions for known file types.
- Show hidden files, folders and drives.
- Hide the Home or Gallery section from the File Explorer navigation pane. (W11 only)
- Hide duplicate removable drive entries from the File Explorer navigation pane, so only the entry under 'This PC' remains.
- Add all common folders (Desktop, Downloads, etc.) back to 'This PC' in File Explorer. (W11 only)
- Hide the 3D objects, music or OneDrive folder from the File Explorer navigation pane. (W10 only)
- Hide the 'Include in library', 'Give access to' and 'Share' options from the context menu. (W10 only)

#### Taskbar

- Align taskbar icons to the left. (W11 only)
- Hide or change the search icon/box on the taskbar. (W11 only)
- Hide the taskview button from the taskbar. (W11 only)
- Disable widgets on the taskbar & lock screen.
- Hide the chat (meet now) icon from the taskbar. (W10 only)
- Enable the 'End Task' option in the taskbar right click menu. (W11 only)
- Enable the 'Last Active Click' behavior in the taskbar app area. This allows you to repeatedly click on an application's icon in the taskbar to switch focus between the open windows of that application.
- Choose how app icons are shown on the taskbar when using multiple monitors. (W11 only)
- Choose combine mode for taskbar buttons and labels. (W11 only)

#### Start

- Remove or replace all pinned apps from start for the current user, or for all existing & new users. (W11 only)
- Disable the recommended section in the start menu. (W11 only)
- Disable Bing web search & Copilot integration in Windows search.
- Disable the Phone Link mobile devices integration in the start menu. (W11 only)

#### Other

- Disable Xbox Game Bar integration & game/screen recording. This also disables `ms-gamingoverlay`/`ms-gamebar` popups if you uninstall the Xbox Game Bar.
- Disable bloat in Brave browser (AI, Crypto, News, etc.)

#### Advanced Features

- Option to [apply changes to a different user](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#running-as-another-user), instead of the currently logged in user.
- [Sysprep mode](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#sysprep-mode) to apply changes to the Windows Default user profile. Which ensures, all new users will have the changes automatically applied to them.

## License

Win11Debloat is licensed under the MIT license. See the LICENSE file for more information.
