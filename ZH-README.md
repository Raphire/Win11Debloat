# Win11Debloat

[Chinese](/ZH-README.md)

[English](/README.md)

Win11Debloat 是一个简洁、易用、轻量的 PowerShell 脚本，可以删除预装的 Windows 垃圾软件、禁用遥测功能，并通过禁用或移除烦人的界面元素、广告等，帮助简化系统体验。无需手动逐一查找设置或删除应用，Win11Debloat 使整个过程快速、简单！

该脚本还包含许多系统管理员会喜欢的功能，比如支持 Windows 审核模式，能够在执行时无需用户输入即可运行脚本。

![Win11Debloat 菜单](/Assets/menu.png)

#### 如果本脚本对你有帮助，考虑请我喝杯咖啡，支持我的工作

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## 特性

> [!Tip]  
> Win11Debloat 所做的所有更改都可以轻松恢复，几乎所有应用都可以通过 Microsoft Store 重新安装。如何恢复更改的完整指南可以在 [这里](https://github.com/Raphire/Win11Debloat/discussions/114) 找到。

#### 应用删除

- 删除各种垃圾软件应用。
- 删除当前用户或所有现有及新用户的所有固定应用。（仅限 Windows 11）

#### 遥测、跟踪和推荐内容

- 禁用遥测、诊断数据、活动历史记录、应用启动跟踪和定向广告。
- 禁用开始菜单、设置、通知、文件资源管理器和锁屏上的提示、技巧、建议和广告。

#### Bing 网络搜索、Copilot 和更多

- 禁用并移除 Bing 网络搜索和 Cortana（Windows 搜索中的个人助理）。
- 禁用并移除 Windows Copilot。（仅限 Windows 11）
- 禁用 Windows Recall 快照。（仅限 Windows 11）

#### 文件资源管理器

- 更改文件资源管理器打开的默认位置。
- 显示隐藏的文件、文件夹和驱动器。
- 显示已知文件类型的文件扩展名。
- 隐藏文件资源管理器导航窗格中的“家庭”或“画廊”部分。（仅限 Windows 11）
- 隐藏文件资源管理器导航窗格中的 3D 对象、音乐或 OneDrive 文件夹。（仅限 Windows 10）
- 隐藏文件资源管理器导航窗格中的重复可移动驱动器条目，只保留“此电脑”下的条目。

#### 任务栏

- 将任务栏图标对齐到左侧。（仅限 Windows 11）
- 隐藏或更改任务栏上的搜索图标/搜索框。（仅限 Windows 11）
- 隐藏任务视图按钮。（仅限 Windows 11）
- 禁用小工具服务并隐藏图标。
- 隐藏任务栏中的聊天（即“立即会议”）图标。

#### 右键菜单

- 恢复 Windows 10 风格的右键菜单。（仅限 Windows 11）
- 隐藏右键菜单中的“包含到库”、“给予访问权限”和“共享”选项。（仅限 Windows 10）

#### 其他

- 禁用 Xbox 游戏/屏幕录制。（也会停止游戏叠加层的弹出）
- Sysprep 模式：将更改应用到 Windows 默认用户配置文件，仅影响新用户账户。

## 默认模式

默认模式应用推荐的更改，适用于大多数用户。详细内容请展开下面的部分查看。

<details>
  <summary>点击展开</summary>
  <blockquote>
    
    默认模式应用以下更改：
    - 删除默认选择的垃圾软件应用。（下方有完整列表）
    - 禁用遥测、诊断数据、活动历史记录、应用启动跟踪和定向广告。
    - 禁用开始菜单、设置、通知、文件资源管理器和锁屏上的提示、技巧、建议和广告。
    - 禁用并移除 Bing 网络搜索和 Cortana（Windows 搜索中的个人助理）。
    - 禁用 Windows Copilot。（仅限 Windows 11）
    - 显示已知文件类型的文件扩展名。
    - 隐藏文件资源管理器中的 3D 对象文件夹。（仅限 Windows 10）
    - 禁用小工具服务并隐藏图标。
    - 隐藏任务栏中的聊天（即“立即会议”）图标。
  </blockquote>

<details>
  <summary>点击展开</summary>
  <blockquote>
    
    默认删除的应用：
      - Microsoft 垃圾软件：
      - Clipchamp.Clipchamp
      - Microsoft.3DBuilder
      - Microsoft.549981C3F5F10（Cortana 应用）
      - Microsoft.BingFinance
      - Microsoft.BingFoodAndDrink
      - Microsoft.BingHealthAndFitness
      - Microsoft.BingNews
      - Microsoft.BingSearch*（Windows 中的 Bing 网络搜索）
      - Microsoft.BingSports
      - Microsoft.BingTranslator
      - Microsoft.BingTravel
      - Microsoft.BingWeather
      - Microsoft.Getstarted（无法在 Windows 11 中卸载）
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
      - Microsoft.Office.OneNote（仅删除停用的 UWP 版本，不删除新的 MS365 版本）
      - Microsoft.Office.Sway
      - Microsoft.OneConnect
      - Microsoft.Print3D
      - Microsoft.SkypeApp
      - Microsoft.Todos
      - Microsoft.WindowsAlarms
      - Microsoft.WindowsFeedbackHub
      - Microsoft.WindowsMaps
      - Microsoft.WindowsSoundRecorder
      - Microsoft.XboxApp（旧版 Xbox 控制台伴侣应用，不再支持）
      - Microsoft.ZuneVideo
      - MicrosoftCorporationII.MicrosoftFamily（Microsoft 家庭安全）
      - MicrosoftTeams（旧版 MS Teams 应用）
      - MSTeams（新版 MS Teams 应用）

    第三方垃圾软件：
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
    * 当禁用 Windows 搜索中的 Bing 时，应用也会被移除。
  </blockquote>
</details>

#### 默认未删除的应用

<details>
  <summary>点击展开</summary>
  <blockquote>
    
    默认未删除的常规应用：
    - Microsoft.Edge（Edge 浏览器，仅在欧洲经济区可以删除）
    - Microsoft.GetHelp（某些 Windows 11 故障排除工具所需）
    - Microsoft.MSPaint（Paint 3D）
    - Microsoft.OutlookForWindows*（新版邮件应用）
    - Microsoft.OneDrive（OneDrive 个人版）
    - Microsoft.Paint（经典画图）
    - Microsoft.People*（邮件和日历所需）
    - Microsoft.ScreenSketch（截图工具）
    - Microsoft.Whiteboard（仅在支持触摸屏和/或笔输入的设备上预装）
    - Microsoft.Windows.Photos
    - Microsoft.WindowsCalculator
    - Microsoft.WindowsCamera
    - Microsoft.WindowsNotepad
    - Microsoft.windowscommunicationsapps*（邮件与日历）
    - Microsoft.WindowsStore（Microsoft Store，注：此应用无法重新安装！）
    - Microsoft.WindowsTerminal（Windows 11 新默认终端应用）
    - Microsoft.YourPhone（手机链接）
    - Microsoft.Xbox.TCUI（UI 框架，删除此应用可能会导致 Microsoft Store、照片和某些游戏功能丧失）
    - Microsoft.ZuneMusic（现代媒体播放器）
    - MicrosoftWindows.CrossDevice（文件资源管理器中的手机集成功能、相机等）
    
    默认未删除的与游戏相关的应用：
    - Microsoft.GamingApp*（现代 Xbox 游戏应用，安装某些游戏所需）
    - Microsoft.XboxGameOverlay*（游戏叠加层，某些游戏所需）
    - Microsoft.XboxGamingOverlay*（游戏叠加层，某些游戏所需）
    - Microsoft.XboxIdentityProvider（Xbox 登录框架，某些游戏所需）
    - Microsoft.XboxSpeechToTextOverlay（可能是某些游戏所需，注：此应用无法重新安装！）
    
    默认未删除的开发者相关应用：
    - Microsoft.PowerAutomateDesktop*
    - Microsoft.RemoteDesktop*
    - Windows.DevHome*
    
    标注了 * 的应用可以通过运行脚本并使用相关参数进行删除。（见下文参数部分）
  </blockquote>
 </details>
</details>

## 使用方法

> [!Warning]  
> 本脚本经过精心设计，以确保不会无意中破坏任何操作系统功能，但请自行承担风险使用！

### 快速方法

通过 PowerShell 自动下载并运行脚本。执行后，脚本的所有痕迹将自动删除。

1. 以管理员身份打开 PowerShell。
2. 复制并粘贴以下代码到 PowerShell 中，按回车键运行脚本：

```powershell
& ([scriptblock]::Create((irm "https://win11debloat.raphi.re/")))
```

3. 等待脚本自动下载 Win11Debloat。
4. 一个新的 PowerShell 窗口将打开，显示 Win11Debloat 菜单。你可以选择默认模式或自定义模式继续。
5. 仔细阅读并按照屏幕上的说明操作。

此方法支持 [参数](#参数)。要使用参数，只需按照上面的方法运行脚本，但在末尾添加参数，参数之间用空格分隔。例如：

```powershell
& ([scriptblock]::Create((irm "https://win11debloat.raphi.re/"))) -RunDefaults -Silent
```

### 传统方法

手动下载并运行脚本。

1. [下载脚本的最新版本](https://github.com/Raphire/Win11Debloat/archive/master.zip)，并将 ZIP 文件解压到你选择的位置。
2. 导航到 Win11Debloat 文件夹。
3. 双击 `Run.bat` 文件以启动脚本。**注意：** 如果控制台窗口立即关闭且没有任何反应，请尝试下面的高级方法。
4. 接受 Windows UAC 提示，以管理员身份运行脚本，这是脚本正常运行所必需的。
5. 一个新的 PowerShell 窗口将打开，显示 Win11Debloat 菜单。选择默认模式或自定义模式继续。
6. 仔细阅读并按照屏幕上的说明操作。

### 高级方法

手动下载脚本并通过 PowerShell 运行脚本。仅建议高级用户使用此方法。

1. [下载脚本的最新版本](https://github.com/Raphire/Win11Debloat/archive/master.zip)，并将 ZIP 文件解压到你选择的位置。
2. 以管理员身份打开 PowerShell。
3. 临时启用 PowerShell 执行策略，输入以下命令：

```powershell
Set-ExecutionPolicy Unrestricted -Scope Process
```

4. 在 PowerShell 中，导航到文件解压的目录。例如：`cd c:\Win11Debloat`
5. 现在运行脚本，输入以下命令：

```powershell
.\Win11Debloat.ps1
```

6. 现在 Win11Debloat 菜单将打开。选择默认模式或自定义模式继续。
7. 仔细阅读并按照屏幕上的说明操作。

此方法支持 [参数](#参数)。要使用参数，只需按照上面的方法运行脚本，但在末尾添加参数，参数之间用空格分隔。例如：

```powershell
.\Win11Debloat.ps1 -RemoveApps -DisableBing -Silent
```

### 参数

快速和高级使用方法支持开关参数。以下是所有支持的参数及其功能的表格：

### 参数

快速和高级使用方法支持切换参数。下面是所有支持的参数及其功能的表格：

| 参数               | 描述                                                                 |
| :----------------: | -------------------------------------------------------------------- |
| -Silent            | 禁用所有交互提示，脚本将无需用户输入即可运行。                       |
| -Sysprep           | 在 Sysprep 模式下运行脚本。所有更改将应用到 Windows 默认用户配置文件，并且只影响新用户帐户。 |
| -RunDefaults       | 使用默认设置运行脚本。                                               |
| -RemoveApps        | 删除默认选择的 bloatware 应用。                                       |
| -RemoveAppsCustom  | 删除在 'CustomAppsList' 文件中指定的所有应用。重要提示：你可以通过运行带有 `-RunAppConfigurator` 参数的脚本生成自定义列表。如果该文件不存在，则不会删除任何应用！ |
| -RunAppConfigurator| 运行应用配置器以生成一个要删除的应用列表，该列表将保存到 'CustomAppsList' 文件中。使用 `-RemoveAppsCustom` 参数运行脚本将删除所选应用。 |
| -RemoveCommApps    | 删除邮件、日历和联系人应用。                                           |
| -RemoveW11Outlook  | 删除新版 Outlook for Windows 应用。                                   |
| -RemoveDevApps     | 删除开发者相关的应用，如远程桌面、DevHome 和 Power Automate。        |
| -RemoveGamingApps  | 删除 Xbox 应用和 Xbox 游戏栏。                                         |
| -ForceRemoveEdge   | 强制删除 Microsoft Edge，此选项会保留核心、WebView 和更新组件以确保兼容性。不推荐使用！ |
| -DisableDVR        | 禁用 Xbox 游戏/屏幕录制功能并停止游戏叠加层弹窗。                     |
| -ClearStart        | 删除当前用户的所有开始菜单固定应用（仅适用于 Windows 11 更新 22H2 或更高版本）。 |
| -ClearStartAllUsers| 删除所有现有和新用户的所有开始菜单固定应用（仅适用于 Windows 11 更新 22H2 或更高版本）。 |
| -DisableTelemetry  | 禁用遥测、诊断数据和定向广告。                                       |
| -DisableBing       | 禁用并移除 Bing 网页搜索、Bing AI 和 Cortana 在 Windows 搜索中的功能。 |
| -DisableSuggestions| 禁用开始菜单、设置、通知和文件资源管理器中的提示、技巧、建议和广告。 |
| <pre>-DisableLockscreenTips</pre> | 禁用锁屏上的提示和技巧。                                        |
| -RevertContextMenu | 恢复 Windows 10 样式的右键菜单。（仅适用于 Windows 11）             |
| -ShowHiddenFolders | 显示隐藏的文件、文件夹和驱动器。                                     |
| -ShowKnownFileExt  | 显示已知文件类型的文件扩展名。                                       |
| -HideDupliDrive    | 隐藏文件资源管理器导航窗格中的重复可移动驱动器条目，只保留 '此电脑' 下的条目。 |
| -TaskbarAlignLeft  | 将任务栏图标对齐到左侧。（仅适用于 Windows 11）                     |
| -HideSearchTb      | 隐藏任务栏上的搜索图标。（仅适用于 Windows 11）                     |
| -ShowSearchIconTb  | 在任务栏上显示搜索图标。（仅适用于 Windows 11）                     |
| -ShowSearchLabelTb | 在任务栏上显示带标签的搜索图标。（仅适用于 Windows 11）             |
| -ShowSearchBoxTb   | 在任务栏上显示搜索框。（仅适用于 Windows 11）                       |
| -HideTaskview      | 隐藏任务栏上的任务视图按钮。（仅适用于 Windows 11）                 |
| -HideChat          | 隐藏任务栏上的聊天（立即通话）图标。                                 |
| -DisableWidgets    | 禁用小组件服务并隐藏任务栏上的小组件（新闻和兴趣）图标。            |
| -DisableCopilot    | 禁用并移除 Windows Copilot。（仅适用于 Windows 11）                  |
| -DisableRecall     | 禁用 Windows Recall 快照功能。（仅适用于 Windows 11）               |
| -HideHome          | 隐藏文件资源管理器导航窗格中的“主页”部分，并在文件资源管理器的文件夹选项中添加切换选项。（仅适用于 Windows 11） |
| -HideGallery       | 隐藏文件资源管理器导航窗格中的“画廊”部分，并在文件资源管理器的文件夹选项中添加切换选项。（仅适用于 Windows 11） |
| -ExplorerToHome    | 将文件资源管理器的默认打开页面更改为“主页”。                       |
| -ExplorerToThisPC  | 将文件资源管理器的默认打开页面更改为“此电脑”。                   |
| -ExplorerToDownloads| 将文件资源管理器的默认打开页面更改为“下载”。                     |
| -ExplorerToOneDrive| 将文件资源管理器的默认打开页面更改为“OneDrive”。                 |
| -HideOnedrive      | 隐藏文件资源管理器导航窗格中的 OneDrive 文件夹。（仅适用于 Windows 10） |
| -Hide3dObjects     | 隐藏文件资源管理器中“此电脑”下的 3D 对象文件夹。（仅适用于 Windows 10） |
| -HideMusic         | 隐藏文件资源管理器中“此电脑”下的音乐文件夹。（仅适用于 Windows 10） |
| -HideIncludeInLibrary| 隐藏右键菜单中的“添加到库”选项。（仅适用于 Windows 10）         |
| -HideGiveAccessTo  | 隐藏右键菜单中的“共享访问”选项。（仅适用于 Windows 10）           |
| -HideShare         | 隐藏右键菜单中的“共享”选项。（仅适用于 Windows 10）               |
