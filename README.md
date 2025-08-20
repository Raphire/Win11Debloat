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
---

# Win11Debloat

[![GitHub 发布](https://img.shields.io/github/v/release/Raphire/Win11Debloat?style=for-the-badge&label=最新发布)](https://github.com/Raphire/Win11Debloat/releases/latest)
[![加入讨论](https://img.shields.io/badge/加入讨论-2D9F2D?style=for-the-badge&logo=github&logoColor=white)](https://github.com/Raphire/Win11Debloat/discussions)
[![静态徽章](https://img.shields.io/badge/文档-_?style=for-the-badge&logo=bookstack&color=grey)](https://github.com/Raphire/Win11Debloat/wiki/)

Win11Debloat 是一个简单、易于使用且轻量级的 PowerShell 脚本，允许您快速清理并提升您的 Windows 体验。它可以移除预装的大众化应用、禁用遥测、移除侵入性界面元素等等。无需您自己费力地逐个设置或移除应用。Win11Debloat 使整个过程变得快速且简单！

脚本还包含许多系统管理员会喜欢的功能。例如，支持 Windows 审核模式、可以更改其他 Windows 用户的选项以及能够在运行时无需用户输入即可运行脚本的能力。请参阅我们的[wiki](https://github.com/Raphire/Win11Debloat/wiki/)获取更多详细信息。

![Win11Debloat 菜单](/Assets/menu.png)

#### 这个脚本帮到了您吗？请考虑买我一杯咖啡以支持我的工作

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/M4M5C6UPC)

## 使用方法

> [!警告]
> 我们在确保此脚本不会无意中破坏任何操作系统功能方面付出了极大的努力，但使用风险自负！如果您遇到任何问题，请在此处[报告](https://github.com/Raphire/Win11Debloat/issues)。

### 快速方法

自动下载并运行脚本 via PowerShell。

1. 以管理员身份打开 PowerShell 或终端。
2. 将以下命令复制并粘贴到 PowerShell 中：

```PowerShell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
```

3. 等待脚本自动下载 Win11Debloat。
4. 仔细阅读并遵循屏幕上的说明。

此方法支持命令行参数来自定义脚本的运行行为。请点击[此处](https://github.com/Raphire/Win11Debloat/wiki/How-To-Use#parameters)获取更多信息。

### 传统方法

<details>
  <summary>手动下载并运行脚本。</summary><br/>

1. [下载脚本的最新版本](https://github.com/Raphire/Win11Debloat/releases/latest)，并将.ZIP 文件解压到您希望的位置。
  2. 导航到 Win11Debloat 文件夹
  3. 双击`Run.bat`文件以启动脚本。注意：如果控制台窗口立即关闭且没有任何操作，请尝试下面的高级方法。
  4. 接受 Windows UAC 提示以以管理员身份运行脚本，这是脚本正常运行的必要条件。
5. 仔细阅读并遵循屏幕上的说明。
</details>

### 高级方法

<details>
<summary>手动下载脚本并通过 PowerShell 运行脚本。建议高级用户使用。</summary><br/>

  1. [下载脚本的最新版本](https://github.com/Raphire/Win11Debloat/releases/latest)，并将.ZIP 文件解压到您希望的位置。
  2. 以管理员身份打开 PowerShell 或终端。
  3. 通过输入以下命令临时启用 PowerShell 执行：

```PowerShell
  设置执行策略为不受限制 -Scope 进程 -Force
  ```

  4. 在 PowerShell 中，导航到文件提取的目录。例如：`cd c:\Win11Debloat`
5. 现在通过输入以下命令来运行脚本：

```PowerShell
.\Win11Debloat.ps1
```

6. 仔细阅读并遵循屏幕上的说明。

此方法支持命令行参数以自定义脚本的运行行为。请点击[此处](https://github.com/Raphire/Win11Debloat/wiki/How-To-Use#parameters)获取更多信息。
</details>

## 功能

以下是 Win11Debloat 提供的关键功能和功能的概述。有关默认模式下包含哪些功能的更多信息，请参阅下面的[本节](#default-settings)。

> [!提示]
> Win11Debloat 所做的所有更改都可以轻松撤销，几乎所有应用都可以通过 Microsoft Store 重新安装。有关如何撤销更改的完整指南，请[在此处](https://github.com/Raphire/Win11Debloat/wiki/Reverting-Changes)找到。

#### 应用程序移除

- 删除各种预装应用。点击[这里](https://github.com/Raphire/Win11Debloat/wiki/App-Removal)获取更多信息。
#### 诊断、跟踪与推荐内容

- 禁用开始、设置、通知、文件资源管理器和锁屏上的提示、技巧、建议和广告。

#### 必应网络搜索、Copilot 与 AI 功能
- 禁用 Edge 中的 AI 功能（仅限 Windows 11）
#### 个性化
#### 文件资源管理器

- 显示隐藏的文件、文件夹和驱动器。

- 隐藏 3D 对象、音乐或 OneDrive 文件夹从文件资源管理器导航窗格中。（仅限 Windows 10）
- 从文件资源管理器导航窗格中隐藏重复的可移动驱动器条目，以便仅在“此电脑”下保留条目。
#### 任务栏
- 启用任务栏应用程序区域中的“上次活动点击”行为。这允许您在任务栏中反复单击应用程序图标，以在应用程序的打开窗口之间切换焦点。
#### 开始
#### 其他

- 可选择[将更改应用于不同用户](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#running-as-another-user)，而不是当前登录用户。

- [Sysprep 模式](https://github.com/Raphire/Win11Debloat/wiki/Advanced-Features#sysprep-mode)以将更改应用于 Windows 默认用户配置文件。之后，所有新用户都将自动应用这些更改。
### 默认设置
Win11Debloat 提供了一种默认模式，允许您快速轻松地应用大多数人推荐的变化。这包括卸载大多数人认为的冗余软件，移除许多令人烦恼的干扰，并禁用遥测和跟踪。要应用默认设置，像平常一样启动脚本，并在脚本菜单中选择选项 `1`。或者，您可以使用 `-RunDefaults` 参数启动脚本。示例：
```Powershell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/"))) -RunDefaults
```

#### 默认模式中包含的更改

- 删除默认预装的冗余应用。（以下为完整列表）
- 禁用开始、设置、通知、文件资源管理器和锁屏上的提示、技巧、建议和广告。
- 将“此电脑”下的 3D 对象文件夹隐藏在文件资源管理器中。（仅限 Windows 10）
#### 作为默认模式的一部分被移除的应用程序
<details>
  <summary>点击展开</summary>

<blockquote>

微软臃肿：
- Clipchamp.Clipchamp 
- Microsoft.3DBuilder
- Microsoft.549981C3F5F10（Cortana 应用）
    - Microsoft.BingFinance 
- 删除或替换当前用户或所有现有及新用户的起始页面上所有已固定的应用。（仅限 W11）
    - Microsoft.BingFoodAndDrink 

    - Microsoft.BingHealthAndFitness

- Microsoft.BingNews
- 禁用遥测、诊断数据、活动历史、应用启动跟踪和定向广告。

- Microsoft.BingSearch* (Windows 中的必应网络搜索)

- 在 Microsoft Edge 中禁用广告和 MSN 新闻源。
- 禁用“Windows spotlight”桌面背景选项。
- Microsoft.BingSports
- 微软必应翻译
- Microsoft.BingTravel

- 禁用并移除 Windows 搜索中的必应网络搜索、必应 AI 和 Cortana。

- 禁用并移除 Microsoft Copilot。（仅限 Windows 11）

- 禁用 Windows 回忆快照。（仅限 Windows 11）
- Microsoft.BingWeather
- 禁用画图中的 AI 功能。（仅限 Windows 11）
  
- 禁用记事本中的 AI 功能。（仅限 Windows 11）
- Microsoft.Copilot
- Microsoft.Getstarted（无法在 Windows 11 中卸载）
- 微软消息传递
- 启用系统和应用的暗黑模式。
- 禁用透明度、动画和视觉效果。
- 关闭增强指针精度，也称为鼠标加速。
- 禁用粘滞键键盘快捷键。（仅限 Windows 11）
- 恢复旧版 Windows 10 样式的上下文菜单。（仅限 W11）
- 从上下文菜单中隐藏“包含在库中”、“授予访问权限”和“共享”选项。（仅限 W10）
    - 微软 3D 查看器
    - 微软笔记
    - 微软办公中心

- 更改文件资源管理器默认打开的位置。

- 微软.微软 PowerBIForWindows 
- 显示已知文件类型的文件扩展名。
- 从文件资源管理器导航窗格中隐藏“主页”或“图库”部分。（仅限 Windows 11）
    
    - 微软.微软 SolitaireCollection 
    - 微软.微软 StickyNotes 
    - 微软.微软 MixedReality.Portal
- 微软网络速度测试
    - 微软新闻
- 将任务栏图标左对齐。（仅限 Windows 11）
- 隐藏或更改任务栏上的搜索图标/框。（仅限 Windows 11）
- 隐藏任务视图按钮从任务栏。（仅限 Windows 11）
- 禁用小部件服务并隐藏任务栏图标。
- 隐藏聊天（现在会议）图标从任务栏。
- 启用任务栏右键菜单中的“结束任务”选项。（仅限 Windows 11）
    - 微软办公 OneNote（仅限已停用的 UWP 版本，不会移除新的 MS365 版本）
    - 微软办公 Sway
- 微软.OneConnect
    - 微软.Print3D
- 禁用开始菜单中的推荐部分。（仅限 Windows 11）
- 禁用开始菜单中的电话链接移动设备集成。（仅限 Windows 11）
    - 微软.SkypeApp
    - 微软.Todos
- 微软.Windows 闹钟
- 禁用 Xbox 游戏/屏幕录制，这也会停止游戏覆盖弹窗。
- 禁用快速启动以确保完全关闭。
- 在现代待机期间禁用网络连接以减少电池消耗。（仅限 Windows 11）
    - 微软.Windows 反馈中心
    - 微软.Windows 地图
    - 微软.Windows 录音机
- Microsoft.XboxApp（旧版 Xbox 游戏机伴侣应用，现已不再支持）
    - Microsoft.ZuneVideo 
    - MicrosoftCorporationII.MicrosoftFamily（微软家庭安全）
    - MicrosoftTeams（MS Store 中的旧版个人版 MS Teams）
- MSTeams（新 MS Teams 应用）
    第三方冗余：
    - ACGMediaPlayer
    - ActiproSoftwareLLC
- Adobe Systems Incorporated.Adobe Photoshop Express
    - Amazon.com.Amazon
- 禁用遥测、诊断数据、活动历史、应用启动跟踪和定向广告。
    - AmazonVideo.PrimeVideo
- 在 Microsoft Edge 中禁用广告和 MSN 新闻源。
- 禁用并移除 Windows 搜索中的必应网络搜索、必应 AI 和 Cortana。

- 禁用并移除 Microsoft Copilot。（仅限 Windows 11）
- 禁用快速启动以确保完全关闭。
- 在现代待机期间禁用网络连接以减少电池消耗。（仅限 Windows 11）
- 显示已知文件类型的文件扩展名。
    - Asphalt 8 Airborne
- 禁用小部件服务并从任务栏隐藏图标。
- 从任务栏隐藏聊天（现在会议）图标。
- AutodeskSketchBook
- 凯撒免费老虎机赌场
- 烹饪狂热
- CyberLink Media Suite Essentials
- 迪士尼魔法王国
    - 迪士尼
    - 杜比
    - DrawboardPDF
- Duolingo-免费学习语言
    - EclipseManager
    - Facebook
    - 农场小镇 2：乡村逃亡
- fitbit
    - Flipboard 
    - HiddenCity
    - HULULLC.HULUPLUS
- iHeartRadio
- Instagram
- king.com.BubbleWitch3Saga
- king.com.CandyCrushSaga
- king.com.CandyCrushSodaSaga
- 领英 Windows 版
- 帝国行军
- Netflix
- 纽约时报字谜
- 一个日历
- 潘多拉媒体公司
- 照片拼贴
- PicsArt-照片工作室
    - Plex
    - Polarr 照片编辑器学术版
    - Royal Revolt
- Shazam
- Sidia.动态壁纸
- SlingTV
- 速度测试
- Spotify
    - TikTok
    - TuneInRadio
    - Twitter
- Viber
    - WinZipUniversal
    - Wunderlist
    - XING
    
* 在禁用 Windows 搜索中的 Bing 时，应用程序将被移除。
</blockquote>
</details>

#### 作为默认模式不删除的应用程序

<details>
  <summary>点击展开</summary>
  <blockquote>

  默认未删除的通用应用：
- Microsoft.Edge（Edge 浏览器，仅在欧盟经济区可移除）
    - Microsoft.GetHelp（某些 Windows 11 故障排除工具所需）
    - Microsoft.MSPaint（画图 3D）
    - Microsoft.OutlookForWindows*（新邮件应用）
- 微软.OneDrive (OneDrive 个人版)
    - 微软.Paint (经典画图)
    - 微软.People* (必需，包含在邮件和日历中)
    - 微软.ScreenSketch (截图工具)
- Microsoft.Whiteboard（仅预装在具有触摸屏和/或笔支持的设备上）
    - Microsoft.Windows.Photos
    - Microsoft.WindowsCalculator
    - Microsoft.WindowsCamera
- Microsoft.WindowsNotepad
    - Microsoft.windowscommunicationsapps* (邮件与日历)
    - Microsoft.WindowsStore (微软商店，注意：此应用无法重新安装！)
    - Microsoft.WindowsTerminal (Windows 11 中的新默认终端应用)
- Microsoft.YourPhone（手机链接）
    - Microsoft.Xbox.TCUI（用户界面框架，移除此框架可能会破坏微软商店、照片和某些游戏）
    - Microsoft.ZuneMusic（现代媒体播放器）
    - MicrosoftWindows.CrossDevice（文件资源管理器、相机等中的手机集成）

默认未删除的 HP 应用：
    - AD2F1837.HPAIExperienceCenter*
    - AD2F1837.HPConnectedMusic*
    - AD2F1837.HPConnectedPhotopoweredbySnapfish*
- AD2F1837.HPDesktopSupportUtilities*
    - AD2F1837.HPEasyClean*
    - AD2F1837.HPFileViewer*
    - AD2F1837.HPJumpStarts*
- AD2F1837.HP 硬件诊断 Windows*
    - AD2F1837.HP 电源管理*
    - AD2F1837.HP 打印机控制*
    - AD2F1837.HP 隐私设置*
- AD2F1837.HPQuickDrop*
    - AD2F1837.HPQuickTouch*
    - AD2F1837.HPRegistration*
    - AD2F1837.HPSupportAssistant*
- AD2F1837.HPSureShieldAI*
    - AD2F1837.HPSystemInformation*
    - AD2F1837.HPWelcome*
    - AD2F1837.HPWorkWell*
- AD2F1837.myHP*

    默认未删除的游戏相关应用：
    - Microsoft.GamingApp*（现代 Xbox 游戏应用，安装某些游戏所必需）
    - Microsoft.XboxGameOverlay*（游戏覆盖层，某些游戏所必需）
- Microsoft.XboxGamingOverlay*（游戏叠加层，某些游戏所需）
    - Microsoft.XboxIdentityProvider（Xbox 登录框架，某些游戏所需）
    - Microsoft.XboxSpeechToTextOverlay（可能某些游戏需要，注意：此应用无法重新安装！）

    默认未删除的开发者相关应用：
- Microsoft.PowerAutomateDesktop*
    - Microsoft.RemoteDesktop*
    - Windows.DevHome*

    * 可通过运行带有相关参数的脚本将其删除。（请参阅维基百科获取更多详细信息）
</blockquote>
</details>

## 许可证

Win11Debloat 遵循 MIT 许可证。有关更多信息，请参阅 LICENSE 文件。
