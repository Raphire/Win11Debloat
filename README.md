# Win11Debloat

[![GitHub Release](https://img.shields.io/github/v/release/Raphire/Win11Debloat?style=for-the-badge&label=Latest%20release)](https://github.com/Raphire/Win11Debloat/releases/latest)
[![Join the Discussion](https://img.shields.io/badge/Join-the%20Discussion-2D9F2D?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Raphire/Win11Debloat/discussions)
[![Static Badge](https://img.shields.io/badge/Documentation-_?style=for-the-badge&logo=bookstack&color=grey)](https://github.com/Raphire/Win11Debloat/wiki/)

 Win11Debloat is a lightweight, easy to use PowerShell script that allows you to quickly declutter and customize your Windows experience, no installation required! You can use it to remove pre-installed apps, disable telemetry, remove intrusive interface elements and much more. No need to painstakingly go through all the settings yourself or remove apps one by one. Win11Debloat makes the process quick and easy!

The script also includes many features that system administrators and power users will enjoy. Such as a powerful command-line interface, support for Windows Audit mode and the ability to make changes to other Windows users. You can also easily export & import your preferred settings, allowing you to quickly apply the same settings on all your systems. Please refer to our [wiki](https://github.com/Raphire/Win11Debloat/wiki) for more details.

![Win11Debloat Menu](/Assets/Images/menu.png)

#### Did this script help you? Please consider buying me a cup of coffee to support my work

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## Usage

> [!Warning]
> Great care went into making sure this script does not unintentionally break any OS functionality, but use at your own risk! If you run into any issues, please report them [here](https://github.com/Raphire/Win11Debloat/issues).

### Quick method

Download & run the script automatically via PowerShell.

1. Open PowerShell or Terminal.
2. Copy and paste the command below into PowerShell:

```PowerShell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
```

3. Wait for the script to automatically download and launch Win11Debloat.
4. Carefully read through and follow the on-screen instructions.

This method supports command-line parameters to customize the behaviour of the script. Please click [here](https://github.com/Raphire/Win11Debloat/wiki/Command%E2%80%90line-Interface#parameters) for more information.

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

  This method supports command-line parameters to customize the behaviour of the script. Please click [here](https://github.com/Raphire/Win11Debloat/wiki/Command%E2%80%90line-Interface#parameters) for more information.
</details>

## Features

Below is an overview of the key features and functionality offered by Win11Debloat. You can visit the [the wiki](https://github.com/Raphire/Win11Debloat/wiki) for more details.

> [!Tip]
> All of the changes made by Win11Debloat can easily be reverted and almost all of the apps can be reinstalled through the Microsoft Store. You can visit [the wiki](https://github.com/Raphire/Win11Debloat/wiki/Reverting-Changes) for more information on reverting changes.

#### App Removal

- Remove a wide variety of preinstalled apps. Click [here](https://github.com/Raphire/Win11Debloat/wiki/App-Removal) for more info.

#### Privacy & Suggested Content

- Disable telemetry, diagnostic data, activity history, app-launch tracking & targeted ads.
- Disable tips, tricks, suggestions & ads across Windows, the lock screen and Microsoft Edge.
- Disable Windows location services, app location access and Find My Device location tracking.
- Hide Microsoft 365 ads on the Settings 'Home' page, or hide the 'Home' page entirely.

#### AI Features

- Disable & remove Microsoft Copilot, Windows Recall and Click to Do.
- Prevent AI service (WSAIFabricSvc) from starting automatically.
- Disable AI Features in Edge, Paint and Notepad.

#### System

- Disable the Drag Tray for sharing & moving files.
- Restore the old Windows 10 style context menu.
- Turn off Enhance Pointer Precision (mouse acceleration).
- Disable the Sticky Keys keyboard shortcut.
- Disable Storage Sense automatic disk cleanup.
- Disable fast start-up to ensure a full shutdown.
- Disable BitLocker automatic device encryption.
- Disable network connectivity during Modern Standby to reduce battery drain.

#### Windows Update

- Prevent Windows from getting updates as soon as they're available.
- Prevent automatic restarts after updates while signed in.
- Disable sharing of downloaded updates with other PCs, also known as Delivery Optimization.
- Prevent Windows from auto-installing device companion apps.

#### Appearance

- Enable dark mode for system and apps.
- Disable transparency, animations and visual effects.

#### Start Menu & Search

- Customize the start menu by removing pinned apps, hiding recommendations, and customizing the 'All Apps' section.
- Disable the Phone Link mobile devices integration in the start menu.
- Disable Bing web search & Copilot integration and Microsoft Store app suggestions in Windows search.

#### Taskbar

- Change taskbar alignment.
- Customize or hide taskbar buttons like the search bar, taskview and more.
- Disable widgets on the taskbar & lock screen.
- Enable the 'End Task' option in the taskbar right click menu to quickly force-close apps.
- Enable the 'Last Active Click' behavior in the taskbar app area. This allows you to repeatedly click on an application's icon in the taskbar to switch focus between the open windows of that application.
- Customize how app buttons are shown on the taskbar.

#### File Explorer

- Change the default location that File Explorer opens to.
- Show file extensions for known file types.
- Show hidden files, folders and drives.
- Hide the Home, Gallery or OneDrive section from the File Explorer navigation pane.
- Hide duplicate removable drive entries from the File Explorer navigation pane, so only the entry under 'This PC' remains.
- Add all common folders (Desktop, Downloads, etc.) back to 'This PC' in File Explorer.
- Change drive letter position or visibility in File Explorer.

#### Multi-tasking

- Disable window snapping.
- Disable Snap Assist and Snap Layout suggestions when dragging or snapping windows.
- Change whether tabs are shown when snapping windows or pressing Alt+Tab.

#### Optional Windows Features

- Enable Windows Sandbox, a lightweight desktop environment for safely running applications in isolation.
- Enable Windows Subsystem for Linux which allows you to run a Linux environment directly on Windows.

#### Other

- Disable Xbox Game Bar integration & game/screen recording. This also disables `ms-gamingoverlay`/`ms-gamebar` popups if you uninstall the Xbox Game Bar.
- Disable bloat in Brave browser (AI, Crypto, News, etc.)

#### Advanced Features

- Ability to [apply changes to a different user](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#running-as-another-user), instead of the currently logged in user.
- [Sysprep mode](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#sysprep-mode) to apply changes to the Windows Default user profile. Which ensures, all new users will have the changes automatically applied to them.

## Contributing

We welcome contributions of all kinds! Please see our [Contributing Guidelines](https://github.com/Raphire/Win11Debloat/blob/master/.github/CONTRIBUTING.md) for detailed instructions on how to get started and best practices for contributing.

## License

Win11Debloat is licensed under the MIT license. See the LICENSE file for more information.
