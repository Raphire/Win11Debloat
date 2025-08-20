#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param (
    [switch]$Silent,
    [switch]$Sysprep,
    [string]$LogPath,
    [string]$User,
    [switch]$CreateRestorePoint,
    [switch]$RunAppsListGenerator, [switch]$RunAppConfigurator,
    [switch]$RunDefaults, [switch]$RunWin11Defaults,
    [switch]$RunSavedSettings,
    [switch]$RemoveApps, 
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveDevApps,
    [switch]$RemoveHPApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableTelemetry,
    [switch]$DisableFastStartup,
    [switch]$DisableModernStandbyNetworking,
    [switch]$DisableBingSearches, [switch]$DisableBing,
    [switch]$DisableDesktopSpotlight,
    [switch]$DisableLockscrTips, [switch]$DisableLockscreenTips,
    [switch]$DisableWindowsSuggestions, [switch]$DisableSuggestions,
    [switch]$DisableEdgeAds,
    [switch]$DisableSettings365Ads,
    [switch]$DisableSettingsHome,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$EnableDarkMode,
    [switch]$DisableTransparency,
    [switch]$DisableAnimations,
    [switch]$TaskbarAlignLeft,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableStartRecommended,
    [switch]$DisableStartPhoneLink,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisablePaintAI,
    [switch]$DisableNotepadAI,
    [switch]$DisableEdgeAI,
    [switch]$DisableWidgets, [switch]$HideWidgets,
    [switch]$DisableChat, [switch]$HideChat,
    [switch]$EnableEndTask,
    [switch]$EnableLastActiveClick,
    [switch]$ClearStart,
    [string]$ReplaceStart,
    [switch]$ClearStartAllUsers,
    [string]$ReplaceStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$DisableMouseAcceleration,
    [switch]$DisableStickyKeys,
    [switch]$HideHome,
    [switch]$HideGallery,
    [switch]$ExplorerToHome,
    [switch]$ExplorerToThisPC,
    [switch]$ExplorerToDownloads,
    [switch]$ExplorerToOneDrive,
    [switch]$DisableOnedrive, [switch]$HideOnedrive,
    [switch]$Disable3dObjects, [switch]$Hide3dObjects,
    [switch]$DisableMusic, [switch]$HideMusic,
    [switch]$DisableIncludeInLibrary, [switch]$HideIncludeInLibrary,
    [switch]$DisableGiveAccessTo, [switch]$HideGiveAccessTo,
    [switch]$DisableShare, [switch]$HideShare
)


# 如果目前的 Powershell 環境受到安全性原則限制，則顯示錯誤。
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Host "错误：Win11Debloat 无法在您的系统上运行，Powershell 执行受到安全策略限制" -ForegroundColor Red
    AwaitKeyToExit
}

# 將指令碼輸出記錄到指定路徑下的 'Win11Debloat.log'。
if ($LogPath -and (Test-Path $LogPath)) {
    Start-Transcript -Path "$LogPath/Win11Debloat.log" -Append -IncludeInvocationHeader -Force | Out-Null
}
else {
    Start-Transcript -Path "$PSScriptRoot/Win11Debloat.log" -Append -IncludeInvocationHeader -Force | Out-Null
}

# 顯示應用程式選擇表單，讓使用者選擇他們想要移除或保留的應用程式。
function ShowAppSelectionForm {
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
    [reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null

    # 初始化表單物件
    $form = New-Object System.Windows.Forms.Form
    $label = New-Object System.Windows.Forms.Label
    $button1 = New-Object System.Windows.Forms.Button
    $button2 = New-Object System.Windows.Forms.Button
    $selectionBox = New-Object System.Windows.Forms.CheckedListBox 
    $loadingLabel = New-Object System.Windows.Forms.Label
    $onlyInstalledCheckBox = New-Object System.Windows.Forms.CheckBox
    $checkUncheckCheckBox = New-Object System.Windows.Forms.CheckBox
    $initialFormWindowState = New-Object System.Windows.Forms.FormWindowState

    $script:selectionBoxIndex = -1

    # saveButton 事件處理器
    $handler_saveButton_Click= 
    {
        if ($selectionBox.CheckedItems -contains "Microsoft.WindowsStore" -and -not $Silent) {
            $warningSelection = [System.Windows.Forms.Messagebox]::Show('您确定要卸载 Microsoft Store 吗？此应用无法轻松重新安装。', '您确定吗？', 'YesNo', 'Warning')
        
            if ($warningSelection -eq 'No') {
                return
            }
        }

        $script:SelectedApps = $selectionBox.CheckedItems

        # 如果檔案不存在，則建立用於儲存所選應用程式的檔案
        if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
            $null = New-Item "$PSScriptRoot/CustomAppsList"
        } 

        Set-Content -Path "$PSScriptRoot/CustomAppsList" -Value $script:SelectedApps

        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    }

    # cancelButton 事件處理器
    $handler_cancelButton_Click= 
    {
        $form.Close()
    }

    $selectionBox_SelectedIndexChanged= 
    {
        $script:selectionBoxIndex = $selectionBox.SelectedIndex
    }

    $selectionBox_MouseDown=
    {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if ([System.Windows.Forms.Control]::ModifierKeys -eq [System.Windows.Forms.Keys]::Shift) {
                if ($script:selectionBoxIndex -ne -1) {
                    $topIndex = $script:selectionBoxIndex

                    if ($selectionBox.SelectedIndex -gt $topIndex) {
                        for (($i = ($topIndex)); $i -le $selectionBox.SelectedIndex; $i++) {
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                    elseif ($topIndex -gt $selectionBox.SelectedIndex) {
                        for (($i = ($selectionBox.SelectedIndex)); $i -le $topIndex; $i++) {
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                }
            }
            elseif ($script:selectionBoxIndex -ne $selectionBox.SelectedIndex) {
                $selectionBox.SetItemChecked($selectionBox.SelectedIndex, -not $selectionBox.GetItemChecked($selectionBox.SelectedIndex))
            }
        }
    }

    $check_All=
    {
        for (($i = 0); $i -lt $selectionBox.Items.Count; $i++) {
            $selectionBox.SetItemChecked($i, $checkUncheckCheckBox.Checked)
        }
    }

    $load_Apps=
    {
        # 校正表單的初始狀態，以防止 .Net 最大化表單問題
        $form.WindowState = $initialFormWindowState

        # 重新載入 appslist 之前，將狀態重設為預設值
        $script:selectionBoxIndex = -1
        $checkUncheckCheckBox.Checked = $False

        # 顯示載入指示器
        $loadingLabel.Visible = $true
        $form.Refresh()

        # 在新增任何新項目之前清除 selectionBox
        $selectionBox.Items.Clear()

        # 設定 Appslist 檔案路徑
        $appsFile = "$PSScriptRoot/Appslist.txt"
        $listOfApps = ""

        if ($onlyInstalledCheckBox.Checked -and ($script:wingetInstalled -eq $true)) {
            # 嘗試透過 winget 取得已安裝應用程式的清單，10 秒後逾時
            $job = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
            $jobDone = $job | Wait-Job -TimeOut 10

            if (-not $jobDone) {
                # 顯示錯誤，說明指令碼無法從 winget 取得應用程式清單
                [System.Windows.MessageBox]::Show('无法通过 winget 加载已安装应用的列表，某些应用可能不会显示在列表中。', '错误', '确定', '错误')
            }
            else {
                # 將工作輸出 (應用程式清單) 新增到 $listOfApps
                $listOfApps = Receive-Job -Job $job
            }
        }

        # 逐一瀏覽 appslist，並將項目新增到 selectionBox
        Foreach ($app in (Get-Content -Path $appsFile | Where-Object { $_ -notmatch '^\s*$' -and $_ -notmatch '^#  .*' -and $_ -notmatch '^# -* #' } )) { 
            $appChecked = $true

            # 如果存在第一個 #，則將其移除並將 appChecked 設為 false
            if ($app.StartsWith('#')) {
                $app = $app.TrimStart("#")
                $appChecked = $false
            }

            # 移除 Appname 中的任何註解
            if (-not ($app.IndexOf('#') -eq -1)) {
                $app = $app.Substring(0, $app.IndexOf('#'))
            }
            
            # 移除 Appname 前後的多餘空格和 `*` 字元
            $app = $app.Trim()
            $appString = $app.Trim('*')

            # 確保 appString 不為空
            if ($appString.length -gt 0) {
                if ($onlyInstalledCheckBox.Checked) {
                    # onlyInstalledCheckBox 已勾選，在新增到 selectionBox 之前檢查應用程式是否已安裝
                    if (-not ($listOfApps -like ("*$appString*")) -and -not (Get-AppxPackage -Name $app)) {
                        # 應用程式未安裝，繼續下一個項目
                        continue
                    }
                    if (($appString -eq "Microsoft.Edge") -and -not ($listOfApps -like "* Microsoft.Edge *")) {
                        # 應用程式未安裝，繼續下一個項目
                        continue
                    }
                }

                # 將應用程式新增到 selectionBox 並設定其勾選狀態
                $selectionBox.Items.Add($appString, $appChecked) | Out-Null
            }
        }
        
        # 隱藏載入指示器
        $loadingLabel.Visible = $False

        # 按字母順序排序 selectionBox
        $selectionBox.Sorted = $True
    }

    $form.Text = "Win11Debloat 应用选择"
    $form.Name = "appSelectionForm"
    $form.DataBindings.DefaultDataSourceUpdateMode = 0
    $form.ClientSize = New-Object System.Drawing.Size(400,502)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $False

    $button1.TabIndex = 4
    $button1.Name = "saveButton"
    $button1.UseVisualStyleBackColor = $True
    $button1.Text = "确认"
    $button1.Location = New-Object System.Drawing.Point(27,472)
    $button1.Size = New-Object System.Drawing.Size(75,23)
    $button1.DataBindings.DefaultDataSourceUpdateMode = 0
    $button1.add_Click($handler_saveButton_Click)

    $form.Controls.Add($button1)

    $button2.TabIndex = 5
    $button2.Name = "cancelButton"
    $button2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $button2.UseVisualStyleBackColor = $True
    $button2.Text = "取消"
    $button2.Location = New-Object System.Drawing.Point(129,472)
    $button2.Size = New-Object System.Drawing.Size(75,23)
    $button2.DataBindings.DefaultDataSourceUpdateMode = 0
    $button2.add_Click($handler_cancelButton_Click)

    $form.Controls.Add($button2)

    $label.Location = New-Object System.Drawing.Point(13,5)
    $label.Size = New-Object System.Drawing.Size(400,14)
    $Label.Font = 'Microsoft Sans Serif,8'
    $label.Text = '勾选您希望移除的应用，取消勾选您希望保留的应用'

    $form.Controls.Add($label)

    $loadingLabel.Location = New-Object System.Drawing.Point(16,46)
    $loadingLabel.Size = New-Object System.Drawing.Size(300,418)
    $loadingLabel.Text = '正在加载应用...'
    $loadingLabel.BackColor = "White"
    $loadingLabel.Visible = $false

    $form.Controls.Add($loadingLabel)

    $onlyInstalledCheckBox.TabIndex = 6
    $onlyInstalledCheckBox.Location = New-Object System.Drawing.Point(230,474)
    $onlyInstalledCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $onlyInstalledCheckBox.Text = '仅显示已安装的应用'
    $onlyInstalledCheckBox.add_CheckedChanged($load_Apps)

    $form.Controls.Add($onlyInstalledCheckBox)

    $checkUncheckCheckBox.TabIndex = 7
    $checkUncheckCheckBox.Location = New-Object System.Drawing.Point(16,22)
    $checkUncheckCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $checkUncheckCheckBox.Text = '全部勾选/取消勾选'
    $checkUncheckCheckBox.add_CheckedChanged($check_All)

    $form.Controls.Add($checkUncheckCheckBox)

    $selectionBox.FormattingEnabled = $True
    $selectionBox.DataBindings.DefaultDataSourceUpdateMode = 0
    $selectionBox.Name = "selectionBox"
    $selectionBox.Location = New-Object System.Drawing.Point(13,43)
    $selectionBox.Size = New-Object System.Drawing.Size(374,424)
    $selectionBox.TabIndex = 3
    $selectionBox.add_SelectedIndexChanged($selectionBox_SelectedIndexChanged)
    $selectionBox.add_Click($selectionBox_MouseDown)

    $form.Controls.Add($selectionBox)

    # 儲存表單的初始狀態
    $initialFormWindowState = $form.WindowState

    # 將應用程式載入到 selectionBox 中
    $form.add_Load($load_Apps)

    # 表單開啟時，將焦點放在 selectionBox 上
    $form.Add_Shown({$form.Activate(); $selectionBox.Focus()})

    # 顯示表單
    return $form.ShowDialog()
}


# 傳回指定檔案中的應用程式清單，它會修剪應用程式名稱並移除任何註解
function ReadAppslistFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    # 取得指定路徑檔案中的應用程式清單，然後逐一移除
    Foreach ($app in (Get-Content -Path $appsFilePath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) { 
        # 移除 Appname 中的任何註解
        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }

        # 移除 Appname 前後的多餘空格
        $app = $app.Trim()
        
        $appString = $app.Trim('*')
        $appsList += $appString
    }

    return $appsList
}


# 移除函數呼叫期間為所有使用者帳戶和 OS 映像指定的應用程式。
function RemoveApps {
    param (
        $appslist
    )

    Foreach ($app in $appsList) { 
        Write-Output "正在尝试移除 $app..."

        if (($app -eq "Microsoft.OneDrive") -or ($app -eq "Microsoft.Edge")) {
            # 使用 winget 移除 OneDrive 和 Edge
            if ($script:wingetInstalled -eq $false) {
                Write-Host "错误：WinGet 未安装或已过时，$app 无法移除" -ForegroundColor Red
            }
            else {
                # 透過 winget 解除安裝應用程式
                Strip-Progress -ScriptBlock { winget uninstall --accept-source-agreements --disable-interactivity --id $app } | Tee-Object -Variable wingetOutput 

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "Uninstall failed with exit code")) {
                    Write-Host "无法通过 Winget 卸载 Microsoft Edge" -ForegroundColor Red
                    Write-Output ""

                    if ($( Read-Host -Prompt "您想要强制卸载 Edge 吗？强烈不建议！ (y/n)" ) -eq 'y') {
                        Write-Output ""
                        ForceRemoveEdge
                    }
                }
            }
        }
        else {
            # 使用 Remove-AppxPackage 移除所有其他應用程式
            $app = '*' + $app + '*'

            # 為所有現有使用者移除已安裝的應用程式
            if ($WinVersion -ge 22000) {
                # Windows 11 组建 22000 或更新版本
                try {
                    Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue

                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "已为所有用户移除 $app" -ForegroundColor DarkGray
                    }
                }
                catch {
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "无法为所有用户移除 $app" -ForegroundColor Yellow
                        Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                    }
                }
            }
            else {
                # Windows 10
                try {
                    Get-AppxPackage -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue
                    
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "已为当前用户移除 $app" -ForegroundColor DarkGray
                    }
                }
                catch {
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "无法为当前用户移除 $app" -ForegroundColor Yellow
                        Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                    }
                }
                
                try {
                    Get-AppxPackage -Name $app -PackageTypeFilter Main, Bundle, Resource -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "已为所有用户移除 $app" -ForegroundColor DarkGray
                    }
                }
                catch {
                    if ($DebugPreference -ne "SilentlyContinue") {
                        Write-Host "无法为所有用户移除 $app" -ForegroundColor Yellow
                        Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                    }
                }
            }

            # 從 OS 映像中移除佈建的應用程式，以便不會為任何新使用者安裝此應用程式
            try {
                Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
            }
            catch {
                Write-Host "无法从 Windows 映像中移除 $app" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }
    }
            
    Write-Output ""
}


# 使用其解除安裝程式強制移除 Microsoft Edge
function ForceRemoveEdge {
    # 根據 loadstring1 和 ave9858 的工作
    Write-Output "> 正在强制卸载 Microsoft Edge..."

    $regView = [Microsoft.Win32.RegistryView]::Registry32
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)
    $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev').SetValue('AllowUninstall', '')

    # 建立存根 (以某種方式建立此存根允許解除安裝 Edge)
    $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    New-Item $edgeStub -ItemType Directory | Out-Null
    New-Item "$edgeStub\MicrosoftEdge.exe" | Out-Null

    # 移除 Edge
    $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
    if ($null -ne $uninstallRegKey) {
        Write-Output "正在执行卸载程序..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-Output "正在移除残留文件..."

        $edgePaths = @(
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
            "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
            "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
            "$env:USERPROFILE\Desktop\Microsoft Edge.lnk",
            "$edgeStub"
        )

        foreach ($path in $edgePaths) {
            if (Test-Path -Path $path) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  已移除 $path" -ForegroundColor DarkGray
            }
        }

        Write-Output "正在清理注册表..."

        # 從自動啟動中移除 ms edge
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-Output "Microsoft Edge 已卸载"
    }
    else {
        Write-Output ""
        Write-Host "错误：无法强制卸载 Microsoft Edge，找不到卸载程序" -ForegroundColor Red
    }
    
    Write-Output ""
}


# 執行提供的命令並從控制台輸出中移除進度微調器/列
function Strip-Progress {
    param(
        [ScriptBlock]$ScriptBlock
    )

    # 用於比對微調器字元和進度列模式的 Regex 模式
    $progressPattern = 'Γû[Æê]|^\s+[-\\|/]\s+$'

    # 校正用於大小格式設定的 regex 模式，確保正確使用擷取群組
    $sizePattern = '(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB) /\s+(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)'

    & $ScriptBlock 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "错误：$($_.Exception.Message)"
        } else {
            $line = $_ -replace $progressPattern, '' -replace $sizePattern, ''
            if (-not ([string]::IsNullOrWhiteSpace($line)) -and -not ($line.StartsWith('  '))) {
                $line
            }
        }
    }
}


# 匯入並執行 regfile
function RegImport {
    param (
        $message,
        $path
    )

    Write-Output $message

    if ($script:Params.ContainsKey("Sysprep")) {
        $defaultUserPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), '\Default\NTUSER.DAT'
        
        reg load "HKU\Default" $defaultUserPath | Out-Null
        reg import "$PSScriptRoot\Regfiles\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null
    }
    elseif ($script:Params.ContainsKey("User")) {
        $userPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$($script:Params.Item("User"))\NTUSER.DAT"
        
        reg load "HKU\Default" $userPath | Out-Null
        reg import "$PSScriptRoot\Regfiles\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null
        
    }
    else {
        reg import "$PSScriptRoot\Regfiles\$path"  
    }

    Write-Output ""
}


# 重新啟動 Windows 檔案總管程式
function RestartExplorer {
    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")) {
        return
    }

    Write-Output "> 正在重新启动 Windows 资源管理器以应用所有更改... (这可能会导致一些闪烁)"

    if ($script:Params.ContainsKey("DisableMouseAcceleration")) {
        Write-Host "警告：增强指针精确度设置更改只会在重启后生效" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableStickyKeys")) {
        Write-Host "警告：粘滞键设置更改只会在重启后生效" -ForegroundColor Yellow
    }

    if ($script:Params.ContainsKey("DisableAnimations")) {
        Write-Host "警告：动画只会在重启后禁用" -ForegroundColor Yellow
    }

    # 只有在 powershell 程式與 OS 架構相符時才重新啟動。
    # 從 32 位元 PowerShell 視窗重新啟動檔案總管在 64 位元 OS 上會失敗
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem) {
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Warning "无法重新启动 Windows 资源管理器，请手动重新启动您的电脑以应用所有更改。"
    }
}


# 為所有使用者取代開始功能表，當使用預設 startmenuTemplate 時，這會清除所有釘選的應用程式
# 參考資料：https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenuForAllUsers {
    param (
        $startMenuTemplate = "$PSScriptRoot/Assets/Start/start2.bin"
    )

    Write-Output "> 正在为所有用户移除开始菜单中的所有固定应用..."

    # 檢查範本 bin 檔案是否存在，如果不存在則提前返回
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "错误：无法清除开始菜单，script 文件夹中缺少 start2.bin 文件" -ForegroundColor Red
        Write-Output ""
        return
    }

    # 取得所有使用者的開始功能表檔案路徑
    $userPathString = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\*\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
    $usersStartMenuPaths = get-childitem -path $userPathString

    # 逐一瀏覽所有使用者並取代開始功能表檔案
    ForEach ($startMenuPath in $usersStartMenuPaths) {
        ReplaceStartMenu $startMenuTemplate "$($startMenuPath.Fullname)\start2.bin"
    }

    # 也為預設使用者設定檔取代開始功能表檔案
    $defaultStartMenuPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), '\Default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState'

    # 如果資料夾不存在，則建立它
    if (-not (Test-Path $defaultStartMenuPath)) {
        new-item $defaultStartMenuPath -ItemType Directory -Force | Out-Null
        Write-Output "已为默认用户配置文件创建 LocalState 文件夹"
    }

    # 將範本複製到預設設定檔
    Copy-Item -Path $startMenuTemplate -Destination $defaultStartMenuPath -Force
    Write-Output "已为默认用户配置文件替换开始菜单"
    Write-Output ""
}


# 為所有使用者取代開始功能表，當使用預設 startmenuTemplate 時，這會清除所有釘選的應用程式
# 參考資料：https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ReplaceStartMenu {
    param (
        $startMenuTemplate = "$PSScriptRoot/Assets/Start/start2.bin",
        $startMenuBinFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
    )

    # 如果指定了使用者，則將路徑變更為正確的使用者
    if ($script:Params.ContainsKey("User")) {
        $startMenuBinFile = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$(GetUserName)\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
    }

    # 檢查範本 bin 檔案是否存在，如果不存在則提前返回
    if (-not (Test-Path $startMenuTemplate)) {
        Write-Host "错误：无法替换开始菜单，找不到模板文件" -ForegroundColor Red
        return
    }

    if ([IO.Path]::GetExtension($startMenuTemplate) -ne ".bin" ) {
        Write-Host "错误：无法替换开始菜单，模板文件不是有效的 .bin 文件" -ForegroundColor Red
        return
    }

    # 檢查 bin 檔案是否存在，如果不存在則提前返回
    if (-not (Test-Path $startMenuBinFile)) {
        Write-Host "错误：无法为用户 $(GetUserName) 替换开始菜单，找不到原始的 start2.bin 文件" -ForegroundColor Red
        return
    }

    $backupBinFile = $startMenuBinFile + ".bak"

    # 備份目前的開始功能表檔案
    Move-Item -Path $startMenuBinFile -Destination $backupBinFile -Force

    # 複製範本檔案
    Copy-Item -Path $startMenuTemplate -Destination $startMenuBinFile -Force

    Write-Output "已为用户 $(GetUserName) 替换开始菜单"
}


# 將參數新增到指令碼並寫入檔案
function AddParameter {
    param (
        $parameterName,
        $message
    )

    # 如果金鑰不存在，則新增金鑰
    if (-not $script:Params.ContainsKey($parameterName)) {
        $script:Params.Add($parameterName, $true)
    }

    # 建立或清除儲存上次使用設定的檔案
    if (-not (Test-Path "$PSScriptRoot/SavedSettings")) {
        $null = New-Item "$PSScriptRoot/SavedSettings"
    } 
    elseif ($script:FirstSelection) {
        $null = Clear-Content "$PSScriptRoot/SavedSettings"
    }
    
    $script:FirstSelection = $false

    # 建立項目並將其新增到檔案中
    $entry = "$parameterName#- $message"
    Add-Content -Path "$PSScriptRoot/SavedSettings" -Value $entry
}


function PrintHeader {
    param (
        $title
    )

    $fullTitle = " Win11Debloat 脚本 - $title"

    if ($script:Params.ContainsKey("Sysprep")) {
        $fullTitle = "$fullTitle (Sysprep 模式)"
    }
    else {
        $fullTitle = "$fullTitle (用户：$(GetUserName))"
    }

    Clear-Host
    Write-Output "-------------------------------------------------------------------------------------------"
    Write-Output $fullTitle
    Write-Output "-------------------------------------------------------------------------------------------"
}


function PrintFromFile {
    param (
        $path,
        $title
    )

    Clear-Host

    PrintHeader $title

    # 從檔案中取得並列印指令碼功能表
    Foreach ($line in (Get-Content -Path $path )) {   
        Write-Output $line
    }
}


function AwaitKeyToExit {
    # 如果傳遞了 Silent 參數，則抑制提示
    if (-not $Silent) {
        Write-Output ""
        Write-Output "按任意键结束..."
        $null = [System.Console]::ReadKey()
    }

    Stop-Transcript
    Exit
}


function GetUserName {
    if ($script:Params.ContainsKey("User")) { 
        return $script:Params.Item("User") 
    }
    
    return $env:USERNAME
}


function CreateSystemRestorePoint {
    Write-Output "> 正在尝试创建系统还原点..."
    
    $SysRestore = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval"

    if ($SysRestore.RPSessionInterval -eq 0) {
        if ($Silent -or $( Read-Host -Prompt "系统还原已禁用，您想要启用它并创建还原点吗？(y/n)") -eq 'y') {
            $enableSystemRestoreJob = Start-Job { 
                try {
                    Enable-ComputerRestore -Drive "$env:SystemDrive"
                } catch {
                    Write-Host "错误：启用系统还原失败：$_" -ForegroundColor Red
                    Write-Output ""
                    return
                }
            }
    
            $enableSystemRestoreJobDone = $enableSystemRestoreJob | Wait-Job -TimeOut 20

            if (-not $enableSystemRestoreJobDone) {
                Write-Host "错误：启用系统还原并创建还原点失败，作业超时" -ForegroundColor Red
                Write-Output ""
                Write-Output "按任意键继续..."
                $null = [System.Console]::ReadKey()
                return
            } else {
                Receive-Job $enableSystemRestoreJob
            }
        } else {
            Write-Output ""
            return
        }
    }

    $createRestorePointJob = Start-Job { 
        # 尋找 24 小時內建立的現有還原點
        try {
            $recentRestorePoints = Get-ComputerRestorePoint | Where-Object { (Get-Date) - [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationTime) -le (New-TimeSpan -Hours 24) }
        } catch {
            Write-Host "错误：无法检索现有还原点：$_" -ForegroundColor Red
            Write-Output ""
            return
        }
    
        if ($recentRestorePoints.Count -eq 0) {
            try {
                Checkpoint-Computer -Description "由 Win11Debloat 创建的还原点" -RestorePointType "MODIFY_SETTINGS"
                Write-Output "系统还原点已成功创建"
            } catch {
                Write-Host "错误：无法创建还原点：$_" -ForegroundColor Red
            }
        } else {
            Write-Host "已存在最近的还原点，未创建新的还原点。" -ForegroundColor Yellow
        }
    }
    
    $createRestorePointJobDone = $createRestorePointJob | Wait-Job -TimeOut 20

    if (-not $createRestorePointJobDone) {
        Write-Host "错误：创建系统还原点失败，作业超时" -ForegroundColor Red
        Write-Output ""
        Write-Output "按任意键继续..."
        $null = [System.Console]::ReadKey()
    } else {
        Receive-Job $createRestorePointJob
    }

    Write-Output ""
}


function DisplayCustomModeOptions {
    # 取得目前的 Windows 組建版本以與功能比較
    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
            
    PrintHeader '自定义模式'

    AddParameter 'CreateRestorePoint' '创建系统还原点'

    # 顯示移除應用程式的選項，僅在有效輸入時繼續
    Do {
        Write-Host "选项：" -ForegroundColor Yellow
        Write-Host " (n) 不移除任何应用" -ForegroundColor Yellow
        Write-Host " (1) 仅移除 'Appslist.txt' 中的默认精简应用选择" -ForegroundColor Yellow
        Write-Host " (2) 移除默认精简应用选择，以及邮件和日历应用、开发人员应用和游戏应用"  -ForegroundColor Yellow
        Write-Host " (3) 手动选择要移除哪些应用" -ForegroundColor Yellow
        $RemoveAppsInput = Read-Host "您要移除任何应用吗？应用将为所有用户移除 (n/1/2/3)"

        # 如果使用者輸入選項 3，則顯示應用程式選擇表單
        if ($RemoveAppsInput -eq '3') {
            $result = ShowAppSelectionForm

            if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
                # 使用者取消或關閉了應用程式選擇，顯示錯誤並變更 RemoveAppsInput，以便再次顯示功能表
                Write-Output ""
                Write-Host "已取消应用选择，请再试一次" -ForegroundColor Red

                $RemoveAppsInput = 'c'
            }
            
            Write-Output ""
        }
    }
    while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2' -and $RemoveAppsInput -ne '3') 

    # 根據使用者輸入選擇正確的選項
    switch ($RemoveAppsInput) {
        '1' {
            AddParameter 'RemoveApps' '移除默认精简应用选择'
        }
        '2' {
            AddParameter 'RemoveApps' '移除默认精简应用选择'
            AddParameter 'RemoveCommApps' '移除邮件、日历和联系人应用'
            AddParameter 'RemoveW11Outlook' '移除新的 Windows 版 Outlook 应用'
            AddParameter 'RemoveDevApps' '移除与开发人员相关的应用'
            AddParameter 'RemoveGamingApps' '移除 Xbox 应用和 Xbox Gamebar'
            AddParameter 'DisableDVR' '禁用 Xbox 游戏/屏幕录像'
        }
        '3' {
            Write-Output "您已选择 $($script:SelectedApps.Count) 个应用要移除"

            AddParameter 'RemoveAppsCustom' "移除 $($script:SelectedApps.Count) 个应用："

            Write-Output ""

            if ($( Read-Host -Prompt "禁用 Xbox 游戏/屏幕录像？这也会停止游戏叠加式窗口弹出窗口 (y/n)" ) -eq 'y') {
                AddParameter 'DisableDVR' '禁用 Xbox 游戏/屏幕录像'
            }
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "禁用遥测、诊断数据、活动日志、应用启动跟踪和目标广告？(y/n)" ) -eq 'y') {
        AddParameter 'DisableTelemetry' '禁用遥测、诊断数据、活动日志、应用启动跟踪和目标广告'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "禁用开始、设置、通知、文件资源管理器、锁屏和 Edge 中的提示、技巧、建议和广告？(y/n)" ) -eq 'y') {
        AddParameter 'DisableSuggestions' '禁用开始、设置、通知和文件资源管理器中的提示、技巧、建议和广告'
        AddParameter 'DisableEdgeAds' '禁用 Microsoft Edge 中的广告和 MSN 新闻摘要'
        AddParameter 'DisableSettings365Ads' '禁用“设置主页”中的 Microsoft 365 广告'
        AddParameter 'DisableLockscreenTips' '禁用锁屏上的提示和技巧'
    }

Write-Output ""

    if ($( Read-Host -Prompt "禁用并从 Windows 搜索中移除 Bing 网页搜索、Bing AI 和 Cortana？(y/n)" ) -eq 'y') {
        AddParameter 'DisableBing' '禁用并从 Windows 搜索中移除 Bing 网页搜索、Bing AI 和 Cortana'
    }

    # 僅適用於 Windows 11 22621 或更高版本的使用者
    if ($WinVersion -ge 22621) {
        Write-Output ""

        # 顯示禁用/移除 AI 功能的選項，僅在有效輸入時繼續
        Do {
            Write-Host "选项：" -ForegroundColor Yellow
            Write-Host " (n) 不禁用任何 AI 功能" -ForegroundColor Yellow
            Write-Host " (1) 禁用 Microsoft Copilot 和 Windows Recall 快照" -ForegroundColor Yellow
            Write-Host " (2) 禁用 Microsoft Copilot、Windows Recall 快照以及 Microsoft Edge、画图和记事本中的 AI 功能"  -ForegroundColor Yellow
            $DisableAIInput = Read-Host "您想要禁用任何 AI 功能吗？这会应用于所有用户 (n/1/2)"
        }
        while ($DisableAIInput -ne 'n' -and $DisableAIInput -ne '0' -and $DisableAIInput -ne '1' -and $DisableAIInput -ne '2') 

        # 根據使用者輸入選擇正確的選項
        switch ($DisableAIInput) {
            '1' {
                AddParameter 'DisableCopilot' '禁用并移除 Microsoft Copilot'
                AddParameter 'DisableRecall' '禁用 Windows Recall 快照'
            }
            '2' {
                AddParameter 'DisableCopilot' '禁用并移除 Microsoft Copilot'
                AddParameter 'DisableRecall' '禁用 Windows Recall 快照'
                AddParameter 'DisableEdgeAI' '禁用 Edge 中的 AI 功能'
                AddParameter 'DisablePaintAI' '禁用画图中的 AI 功能'
                AddParameter 'DisableNotepadAI' '禁用记事本中的 AI 功能'
            }
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "禁用桌面上的 Windows 聚焦背景吗？(y/n)" ) -eq 'y') {
        AddParameter 'DisableDesktopSpotlight' '禁用“Windows 聚焦”桌面背景选项'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "为系统和应用启用深色模式吗？(y/n)" ) -eq 'y') {
        AddParameter 'EnableDarkMode' '为系统和应用启用深色模式'
    }

    Write-Output ""

    if ($( Read-Host -Prompt "禁用透明度、动画和视觉效果吗？(y/n)" ) -eq 'y') {
        AddParameter 'DisableTransparency' '禁用透明效果'
        AddParameter 'DisableAnimations' '禁用动画和视觉效果'
    }

    # 僅適用於 Windows 11 22000 或更高版本的使用者
    if ($WinVersion -ge 22000) {
        Write-Output ""

        if ($( Read-Host -Prompt "恢复旧的 Windows 10 风格的右键菜单吗？(y/n)" ) -eq 'y') {
            AddParameter 'RevertContextMenu' '恢复旧的 Windows 10 风格的右键菜单'
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "关闭“增强指针精准度”（也称为鼠标加速）吗？(y/n)" ) -eq 'y') {
        AddParameter 'DisableMouseAcceleration' '关闭“增强指针精准度”（鼠标加速）'
    }

    # 僅適用於 Windows 11 26100 或更高版本的使用者
    if ($WinVersion -ge 26100) {
        Write-Output ""

        if ($( Read-Host -Prompt "禁用粘滞键键盘快捷键吗？(y/n)" ) -eq 'y') {
            AddParameter 'DisableStickyKeys' '禁用粘滞键键盘快捷键'
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "禁用快速启动吗？这会应用于所有用户 (y/n)" ) -eq 'y') {
        AddParameter 'DisableFastStartup' '禁用快速启动'
    }

    # 僅適用於 Windows 11 22000 或更高版本的使用者，且機器至少有一塊電池
    if (($WinVersion -ge 22000) -and $script:BatteryInstalled) {
        Write-Output ""

        if ($( Read-Host -Prompt "在“新式待机”期间禁用网络连接以减少电量消耗吗？(y/n)" ) -eq 'y') {
            AddParameter 'DisableModernStandbyNetworking' '在“新式待机”期间禁用网络连接'
        }
    }

    # 僅在 Windows 10 使用者或使用者選擇恢復 Windows 10 右鍵菜單時顯示禁用右鍵菜單選項
    if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -or $script:Params.ContainsKey('RevertContextMenu')) {
        Write-Output ""

        if ($( Read-Host -Prompt "您想要禁用任何右键菜单选项吗？(y/n)" ) -eq 'y') {
            Write-Output ""

            if ($( Read-Host -Prompt "    在右键菜单中隐藏“包括到库中”选项吗？(y/n)" ) -eq 'y') {
                AddParameter 'HideIncludeInLibrary' "在右键菜单中隐藏“包括到库中”选项"
            }

            Write-Output ""

            if ($( Read-Host -Prompt "    在右键菜单中隐藏“授予访问权限”选项吗？(y/n)" ) -eq 'y') {
                AddParameter 'HideGiveAccessTo' "在右键菜单中隐藏“授予访问权限”选项"
            }

            Write-Output ""

            if ($( Read-Host -Prompt "    在右键菜单中隐藏“共享”选项吗？(y/n)" ) -eq 'y') {
                AddParameter 'HideShare' "在右键菜单中隐藏“共享”选项"
            }
        }
    }

    # 僅適用於 Windows 11 22621 或更高版本的使用者
    if ($WinVersion -ge 22621) {
        Write-Output ""

        if ($( Read-Host -Prompt "您想要对“开始”菜单进行任何更改吗？(y/n)" ) -eq 'y') {
            Write-Output ""

            if ($script:Params.ContainsKey("Sysprep")) {
                if ($( Read-Host -Prompt "为所有现有和新用户移除“开始”菜单中的所有已固定应用吗？(y/n)" ) -eq 'y') {
                    AddParameter 'ClearStartAllUsers' '为所有现有和新用户移除“开始”菜单中的所有已固定应用'
                }
            }
            else {
                Do {
                    Write-Host "    选项：" -ForegroundColor Yellow
                    Write-Host "    (n) 不从“开始”菜单中移除任何已固定应用" -ForegroundColor Yellow
                    Write-Host "    (1) 仅为此用户移除“开始”菜单中的所有已固定应用 ($(GetUserName))" -ForegroundColor Yellow
                    Write-Host "    (2) 为所有现有和新用户移除“开始”菜单中的所有已固定应用"  -ForegroundColor Yellow
                    $ClearStartInput = Read-Host "    移除“开始”菜单中的所有已固定应用吗？(n/1/2)" 
                }
                while ($ClearStartInput -ne 'n' -and $ClearStartInput -ne '0' -and $ClearStartInput -ne '1' -and $ClearStartInput -ne '2') 

                # 根據使用者輸入選擇正確的選項
                switch ($ClearStartInput) {
                    '1' {
                        AddParameter 'ClearStart' "仅为此用户移除“开始”菜单中的所有已固定应用"
                    }
                    '2' {
                        AddParameter 'ClearStartAllUsers' "为所有现有和新用户移除“开始”菜单中的所有已固定应用"
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "    禁用“开始”菜单中的“推荐”部分吗？这会应用于所有用户 (y/n)" ) -eq 'y') {
                AddParameter 'DisableStartRecommended' '禁用“开始”菜单中的“推荐”部分'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "    禁用“开始”菜单中的“手机连接”移动设备集成吗？(y/n)" ) -eq 'y') {
                AddParameter 'DisableStartPhoneLink' '禁用“开始”菜单中的“手机连接”移动设备集成'
            }
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "您想要对任务栏和相关服务进行任何更改吗？(y/n)" ) -eq 'y') {
        # 僅適用於 Windows 11 22000 或更高版本的使用者
        if ($WinVersion -ge 22000) {
            Write-Output ""

            if ($( Read-Host -Prompt "    将任务栏按钮左对齐吗？(y/n)" ) -eq 'y') {
                AddParameter 'TaskbarAlignLeft' '将任务栏图标左对齐'
            }

            # 顯示任務欄上搜索圖標的選項，僅在有效輸入時繼續
            Do {
                Write-Output ""
                Write-Host "    选项：" -ForegroundColor Yellow
                Write-Host "    (n) 不做更改" -ForegroundColor Yellow
                Write-Host "    (1) 从任务栏隐藏搜索图标" -ForegroundColor Yellow
                Write-Host "    (2) 在任务栏上显示搜索图标" -ForegroundColor Yellow
                Write-Host "    (3) 在任务栏上显示带标签的搜索图标" -ForegroundColor Yellow
                Write-Host "    (4) 在任务栏上显示搜索框" -ForegroundColor Yellow
                $TbSearchInput = Read-Host "    隐藏或更改任务栏上的搜索图标吗？(n/1/2/3/4)" 
            }
            while ($TbSearchInput -ne 'n' -and $TbSearchInput -ne '0' -and $TbSearchInput -ne '1' -and $TbSearchInput -ne '2' -and $TbSearchInput -ne '3' -and $TbSearchInput -ne '4') 

            # 根據使用者輸入選擇正確的任務欄搜索選項
            switch ($TbSearchInput) {
                '1' {
                    AddParameter 'HideSearchTb' '从任务栏隐藏搜索图标'
                }
                '2' {
                    AddParameter 'ShowSearchIconTb' '在任务栏上显示搜索图标'
                }
                '3' {
                    AddParameter 'ShowSearchLabelTb' '在任务栏上显示带标签的搜索图标'
                }
                '4' {
                    AddParameter 'ShowSearchBoxTb' '在任务栏上显示搜索框'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "    从任务栏隐藏任务视图按钮吗？(y/n)" ) -eq 'y') {
                AddParameter 'HideTaskview' '从任务栏隐藏任务视图按钮'
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "    禁用小组件服务并从任务栏隐藏其图标吗？(y/n)" ) -eq 'y') {
            AddParameter 'DisableWidgets' '禁用小组件服务并从任务栏隐藏小组件（新闻和兴趣）图标'
        }

        # 僅適用於 Windows 22621 或更早版本的使用者
        if ($WinVersion -le 22621) {
            Write-Output ""

            if ($( Read-Host -Prompt "    从任务栏隐藏聊天（立即开会）图标吗？(y/n)" ) -eq 'y') {
                AddParameter 'HideChat' '从任务栏隐藏聊天（立即开会）图标'
            }
        }
        
        # 僅適用於 Windows 22631 或更高版本的使用者
        if ($WinVersion -ge 22631) {
            Write-Output ""

            if ($( Read-Host -Prompt "    在任务栏右键菜单中启用“结束任务”选项吗？(y/n)" ) -eq 'y') {
                AddParameter 'EnableEndTask' "在任务栏右键菜单中启用“结束任务”选项"
            }
        }
        
        Write-Output ""
        if ($( Read-Host -Prompt "    在任务栏应用区域中启用“上次活动点击”行为吗？(y/n)" ) -eq 'y') {
            AddParameter 'EnableLastActiveClick' "在任务栏应用区域中启用“上次活动点击”行为"
        }
    }

    Write-Output ""

    if ($( Read-Host -Prompt "您想要对文件资源管理器进行任何更改吗？(y/n)" ) -eq 'y') {
        # 顯示更改文件資源管理器預設位置的選項
        Do {
            Write-Output ""
            Write-Host "    选项：" -ForegroundColor Yellow
            Write-Host "    (n) 不做更改" -ForegroundColor Yellow
            Write-Host "    (1) 打开文件资源管理器到“主页”" -ForegroundColor Yellow
            Write-Host "    (2) 打开文件资源管理器到“此电脑”" -ForegroundColor Yellow
            Write-Host "    (3) 打开文件资源管理器到“下载”" -ForegroundColor Yellow
            Write-Host "    (4) 打开文件资源管理器到“OneDrive”" -ForegroundColor Yellow
            $ExplSearchInput = Read-Host "    更改文件资源管理器默认打开的位置吗？(n/1/2/3/4)" 
        }
        while ($ExplSearchInput -ne 'n' -and $ExplSearchInput -ne '0' -and $ExplSearchInput -ne '1' -and $ExplSearchInput -ne '2' -and $ExplSearchInput -ne '3' -and $ExplSearchInput -ne '4') 

        # 根據使用者輸入選擇正確的任務欄搜索選項
        switch ($ExplSearchInput) {
            '1' {
                AddParameter 'ExplorerToHome' "将文件资源管理器默认打开的位置更改为“主页”"
            }
            '2' {
                AddParameter 'ExplorerToThisPC' "将文件资源管理器默认打开的位置更改为“此电脑”"
            }
            '3' {
                AddParameter 'ExplorerToDownloads' "将文件资源管理器默认打开的位置更改为“下载”"
            }
            '4' {
                AddParameter 'ExplorerToOneDrive' "将文件资源管理器默认打开的位置更改为“OneDrive”"
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "    显示隐藏的文件、文件夹和驱动器吗？(y/n)" ) -eq 'y') {
            AddParameter 'ShowHiddenFolders' '显示隐藏的文件、文件夹和驱动器'
        }

        Write-Output ""

        if ($( Read-Host -Prompt "    为已知文件类型显示文件扩展名吗？(y/n)" ) -eq 'y') {
            AddParameter 'ShowKnownFileExt' '为已知文件类型显示文件扩展名'
        }

        # 僅適用於 Windows 11 22000 或更高版本的使用者
        if ($WinVersion -ge 22000) {
            Write-Output ""

            if ($( Read-Host -Prompt "    从文件资源管理器侧边栏隐藏“主页”部分吗？(y/n)" ) -eq 'y') {
                AddParameter 'HideHome' '从文件资源管理器侧边栏隐藏“主页”部分'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "    从文件资源管理器侧边栏隐藏“图库”部分吗？(y/n)" ) -eq 'y') {
                AddParameter 'HideGallery' '从文件资源管理器侧边栏隐藏“图库”部分'
            }
        }

        Write-Output ""

        if ($( Read-Host -Prompt "    从文件资源管理器侧边栏隐藏重复的可移动驱动器条目，使其仅显示在“此电脑”下吗？(y/n)" ) -eq 'y') {
            AddParameter 'HideDupliDrive' '从文件资源管理器侧边栏隐藏重复的可移动驱动器条目'
        }

        # 僅適用於 Windows 10 使用者，顯示禁用這些特定資料夾的選項
        if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") {
            Write-Output ""

            if ($( Read-Host -Prompt "您想从文件资源管理器侧边栏隐藏任何文件夹吗？(y/n)" ) -eq 'y') {
                Write-Output ""

                if ($( Read-Host -Prompt "    从文件资源管理器侧边栏隐藏 OneDrive 文件夹吗？(y/n)" ) -eq 'y') {
                    AddParameter 'HideOnedrive' '在文件资源管理器侧边栏中隐藏 OneDrive 文件夹'
                }

                Write-Output ""
                
                if ($( Read-Host -Prompt "    从文件资源管理器侧边栏隐藏 3D 对象文件夹吗？(y/n)" ) -eq 'y') {
                    AddParameter 'Hide3dObjects' "在文件资源管理器中隐藏“此电脑”下的 3D 对象文件夹" 
                }
                
                Write-Output ""

                if ($( Read-Host -Prompt "    从文件资源管理器侧边栏隐藏“音乐”文件夹吗？(y/n)" ) -eq 'y') {
                    AddParameter 'HideMusic' "在文件资源管理器中隐藏“此电脑”下的“音乐”文件夹"
                }
            }
        }
    }

    # 如果傳遞了 Silent 參數則抑制提示
    if (-not $Silent) {
        Write-Output ""
        Write-Output ""
        Write-Output ""
        Write-Output "按 Enter 键确认您的选择并执行脚本，或按 CTRL+C 退出..."
        Read-Host | Out-Null
    }

    PrintHeader '自定义模式'
}



##################################################################################################################
#                                                                                                                #
#                                          指令碼開始                                                            #
#                                                                                                                #
##################################################################################################################



# 檢查是否安裝 winget，如果已安裝，檢查版本是否至少為 v1.4
if ((Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*") -and ([int](((winget -v) -replace 'v','').split('.')[0..1] -join '') -gt 14)) {
    $script:wingetInstalled = $true
}
else {
    $script:wingetInstalled = $false

    # 顯示需要使用者確認的警告，如果傳遞了 Silent 參數則抑制確認
    if (-not $Silent) {
        Write-Warning "Winget 未安装或已过时。这可能会阻止 Win11Debloat 移除某些应用。"
        Write-Output ""
        Write-Output "按任意键继续..."
        $null = [System.Console]::ReadKey()
    }
}

# 取得目前的 Windows 組建版本以與功能進行比較
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

# 檢查機器是否安裝了電池，這用於判斷是否可以使用 DisableModernStandbyNetworking 選項
$script:BatteryInstalled = (Get-WmiObject -Class Win32_Battery).Count -gt 0

$script:Params = $PSBoundParameters
$script:FirstSelection = $true
$SPParams = 'WhatIf', 'Confirm', 'Verbose', 'Silent', 'Sysprep', 'Debug', 'User', 'CreateRestorePoint', 'LogPath'
$SPParamCount = 0

# 計算 Params 中存在多少個 SPParams
# 這稍後用於檢查是否選擇了任何選項
foreach ($Param in $SPParams) {
    if ($script:Params.ContainsKey($Param)) {
        $SPParamCount++
    }
}

# 隱藏應用程式移除的進度列，因為它們會阻擋 Win11Debloat 的輸出
if (-not ($script:Params.ContainsKey("Verbose"))) {
    $ProgressPreference = 'SilentlyContinue'
}
else {
    Write-Host "详细模式已启用"
    Write-Output ""
    Write-Output "按任意键继续..."
    $null = [System.Console]::ReadKey()

    $ProgressPreference = 'Continue'
}

# 如果啟用 Sysprep，請確保滿足 Sysprep 的所有要求
if ($script:Params.ContainsKey("Sysprep")) {
    $defaultUserPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), '\Default\NTUSER.DAT'

    # 如果找不到預設使用者目錄或 NTUSER.DAT 檔案，則結束指令碼
    if (-not (Test-Path "$defaultUserPath")) {
        Write-Host "错误：无法在 Sysprep 模式下启动 Win11Debloat，无法在 '$defaultUserPath' 找到默认用户文件夹" -ForegroundColor Red
        AwaitKeyToExit
    }
    # 如果在 Windows 10 上以 Sysprep 模式執行，則結束指令碼
    if ($WinVersion -lt 22000) {
        Write-Host "错误：Windows 10 不支持 Win11Debloat Sysprep 模式" -ForegroundColor Red
        AwaitKeyToExit
    }
}

# 如果指定了使用者，請確保滿足使用者模式的所有要求
if ($script:Params.ContainsKey("User")) {
    $userPath = $env:USERPROFILE -Replace ('\\' + $env:USERNAME + '$'), "\$($script:Params.Item("User"))\NTUSER.DAT"

    # 如果找不到使用者目錄或 NTUSER.DAT 檔案，則結束指令碼
    if (-not (Test-Path "$userPath")) {
        Write-Host "错误：无法为用户 $($script:Params.Item("User")) 运行 Win11Debloat，无法在 '$userPath' 找到用户数据" -ForegroundColor Red
        AwaitKeyToExit
    }
}

# 如果 SavedSettings 檔案存在且為空，則移除
if ((Test-Path "$PSScriptRoot/SavedSettings") -and ([String]::IsNullOrWhiteSpace((Get-content "$PSScriptRoot/SavedSettings")))) {
    Remove-Item -Path "$PSScriptRoot/SavedSettings" -recurse
}

# 僅在 'RunAppsListGenerator' 參數傳遞給指令碼時執行應用程式選擇表單
if ($RunAppConfigurator -or $RunAppsListGenerator) {
    PrintHeader "自定义应用列表生成器"

    $result = ShowAppSelectionForm

    # 根據應用程式選擇是儲存還是取消，顯示不同的訊息
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "应用选择窗口已关闭，未保存。" -ForegroundColor Red
    }
    else {
        Write-Output "您的应用选择已保存到 'CustomAppsList' 文件，位于："
        Write-Host "$PSScriptRoot" -ForegroundColor Yellow
    }

    AwaitKeyToExit
}

# 根據提供的參數或使用者輸入變更指令碼執行
if ((-not $script:Params.Count) -or $RunDefaults -or $RunWin11Defaults -or $RunSavedSettings -or ($SPParamCount -eq $script:Params.Count)) {
    if ($RunDefaults -or $RunWin11Defaults) {
        $Mode = '1'
    }
    elseif ($RunSavedSettings) {
        if (-not (Test-Path "$PSScriptRoot/SavedSettings")) {
            PrintHeader '自定义模式'
            Write-Host "错误：没有保存的设置，没有更改" -ForegroundColor Red
            AwaitKeyToExit
        }

        $Mode = '4'
    }
    else {
        # 顯示功能表並等待使用者輸入，直到提供有效輸入為止
        Do { 
            $ModeSelectionMessage = "请选择一个选项 (1/2/3/0)" 

            PrintHeader '菜单'

            Write-Output "(1) 默认模式：快速应用推荐的更改"
            Write-Output "(2) 自定义模式：手动选择要进行的更改"
            Write-Output "(3) 应用移除模式：选择并移除应用，而不进行其他更改"

            # 僅在 SavedSettings 檔案存在時顯示此選項
            if (Test-Path "$PSScriptRoot/SavedSettings") {
                Write-Output "(4) 应用上次保存的自定义设置"
                
                $ModeSelectionMessage = "请选择一个选项 (1/2/3/4/0)" 
            }

            Write-Output ""
            Write-Output "(0) 显示更多信息"
            Write-Output ""
            Write-Output ""

            $Mode = Read-Host $ModeSelectionMessage

            if ($Mode -eq '0') {
                # 從檔案中列印資訊畫面
                PrintFromFile "$PSScriptRoot/Assets/Menus/Info" "信息"

                Write-Output "按任意键返回..."
                $null = [System.Console]::ReadKey()
            }
            elseif (($Mode -eq '4') -and -not (Test-Path "$PSScriptRoot/SavedSettings")) {
                $Mode = $null
            }
        }
        while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3' -and $Mode -ne '4') 
    }

    # 根據模式新增執行參數
    switch ($Mode) {
        # 預設模式，確認後載入預設值
        '1' { 
            # 顯示帶有確認的預設設定，除非傳遞了 Silent 參數
            if (-not $Silent) {
                PrintFromFile "$PSScriptRoot/Assets/Menus/DefaultSettings" "默认模式"

                Write-Output "按 Enter 键执行脚本或按 CTRL+C 退出..."
                Read-Host | Out-Null
            }

            $DefaultParameterNames = 'CreateRestorePoint','RemoveApps','DisableTelemetry','DisableBing','DisableLockscreenTips','DisableSuggestions','DisableEdgeAds','ShowKnownFileExt','DisableWidgets','HideChat','DisableCopilot','DisableFastStartup'

            PrintHeader '默认模式'

            # 如果預設參數尚不存在，則新增
            foreach ($ParameterName in $DefaultParameterNames) {
                if (-not $script:Params.ContainsKey($ParameterName)) {
                    $script:Params.Add($ParameterName, $true)
                }
            }

            # 僅適用於 Windows 10 使用者，如果此選項尚不存在，則新增
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -and (-not $script:Params.ContainsKey('Hide3dObjects'))) {
                $script:Params.Add('Hide3dObjects', $Hide3dObjects)
            }

            # 僅適用於 Windows 11 使用者（組建 22000+），如果此選項尚不存在，則新增
            if (($WinVersion -ge 22000) -and $script:BatteryInstalled -and (-not $script:Params.ContainsKey('DisableModernStandbyNetworking'))) {
                $script:Params.Add('DisableModernStandbyNetworking', $true)
            }
        }

        # 自訂模式，根據使用者輸入顯示和新增選項
        '2' { 
            DisplayCustomModeOptions
        }

        # 應用程式移除，根據使用者選擇移除應用程式
        '3' {
            PrintHeader "应用移除"

            $result = ShowAppSelectionForm

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                Write-Output "您已选择 $($script:SelectedApps.Count) 个应用进行移除"
                AddParameter 'RemoveAppsCustom' "移除 $($script:SelectedApps.Count) 个应用："

                # 如果傳遞了 Silent 參數則抑制提示
                if (-not $Silent) {
                    Write-Output ""
                    Write-Output ""
                    Write-Output "按 Enter 键移除选定的应用或按 CTRL+C 退出..."
                    Read-Host | Out-Null
                    PrintHeader "应用移除"
                }
            }
            else {
                Write-Host "已取消选择，没有应用被移除" -ForegroundColor Red
                Write-Output ""
            }
        }

        # 從 "SavedSettings" 檔案中載入自訂選項
        '4' {
            PrintHeader '自定义模式'
            Write-Output "Win11Debloat 将进行以下更改："

            # 從檔案中列印已儲存的設定資訊
            Foreach ($line in (Get-Content -Path "$PSScriptRoot/SavedSettings" )) { 
                # 移除行前後的所有空格
                $line = $line.Trim()
            
                # 檢查行是否包含註解
                if (-not ($line.IndexOf('#') -eq -1)) {
                    $parameterName = $line.Substring(0, $line.IndexOf('#'))

                    # 列印參數描述並將參數新增到 Params 列表
                    if ($parameterName -eq "RemoveAppsCustom") {
                        if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
                            # 應用程式檔案不存在，跳過
                            continue
                        }
                        
                        $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
                        Write-Output "- 移除 $($appsList.Count) 个应用："
                        Write-Host $appsList -ForegroundColor DarkGray
                    }
                    else {
                        Write-Output $line.Substring(($line.IndexOf('#') + 1), ($line.Length - $line.IndexOf('#') - 1))
                    }

                    if (-not $script:Params.ContainsKey($parameterName)) {
                        $script:Params.Add($parameterName, $true)
                    }
                }
            }

            if (-not $Silent) {
                Write-Output ""
                Write-Output ""
                Write-Output "按 Enter 键执行脚本或按 CTRL+C 退出..."
                Read-Host | Out-Null
            }

            PrintHeader '自定义模式'
        }
    }
}
else {
    PrintHeader '自定义模式'
}

# 如果 SPParams 中的金鑰數等於 Params 中的金鑰數，則表示沒有選擇任何修改/變更
# 或使用者沒有新增任何項目，指令碼可以不進行任何變更而退出。
if ($SPParamCount -eq $script:Params.Keys.Count) {
    Write-Output "脚本完成，未进行任何更改。"

    AwaitKeyToExit
}

# 執行所有選擇/提供的參數
switch ($script:Params.Keys) {
    'CreateRestorePoint' {
        CreateSystemRestorePoint
        continue
    }
    'RemoveApps' {
        $appsList = ReadAppslistFromFile "$PSScriptRoot/Appslist.txt" 
        Write-Output "> 正在移除默认选择的 $($appsList.Count) 个应用..."
        RemoveApps $appsList
        continue
    }
    'RemoveAppsCustom' {
        if (-not (Test-Path "$PSScriptRoot/CustomAppsList")) {
            Write-Host "> 错误：无法从文件加载自定义应用列表，没有应用被移除" -ForegroundColor Red
            Write-Output ""
            continue
        }
        
        $appsList = ReadAppslistFromFile "$PSScriptRoot/CustomAppsList"
        Write-Output "> 正在移除 $($appsList.Count) 个应用..."
        RemoveApps $appsList
        continue
    }
    'RemoveCommApps' {
        $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
        Write-Output "> 正在移除邮件、日历和联系人应用..."
        RemoveApps $appsList
        continue
    }
    'RemoveW11Outlook' {
        $appsList = 'Microsoft.OutlookForWindows'
        Write-Output "> 正在移除新的 Windows 版 Outlook 应用..."
        RemoveApps $appsList
        continue
    }
    'RemoveDevApps' {
        $appsList = 'Microsoft.PowerAutomateDesktop', 'Microsoft.RemoteDesktop', 'Windows.DevHome'
        Write-Output "> 正在移除与开发人员相关的应用..."
        RemoveApps $appsList
        continue
    }
    'RemoveGamingApps' {
        $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
        Write-Output "> 正在移除与游戏相关的应用..."
        RemoveApps $appsList
        continue
    }
    'RemoveHPApps' {
        $appsList = 'AD2F1837.HPAIExperienceCenter', 'AD2F1837.HPJumpStarts', 'AD2F1837.HPPCHardwareDiagnosticsWindows', 'AD2F1837.HPPowerManager', 'AD2F1837.HPPrivacySettings', 'AD2F1837.HPSupportAssistant', 'AD2F1837.HPSureShieldAI', 'AD2F1837.HPSystemInformation', 'AD2F1837.HPQuickDrop', 'AD2F1837.HPWorkWell', 'AD2F1837.myHP', 'AD2F1837.HPDesktopSupportUtilities', 'AD2F1837.HPQuickTouch', 'AD2F1837.HPEasyClean', 'AD2F1837.HPConnectedMusic', 'AD2F1837.HPFileViewer', 'AD2F1837.HPRegistration', 'AD2F1837.HPWelcome', 'AD2F1837.HPConnectedPhotopoweredbySnapfish', 'AD2F1837.HPPrinterControl'
        Write-Output "> 正在移除 HP 应用..."
        RemoveApps $appsList
        continue
    }
    "ForceRemoveEdge" {
        ForceRemoveEdge
        continue
    }
    'DisableDVR' {
        RegImport "> 正在禁用 Xbox 游戏/屏幕录像..." "Disable_DVR.reg"
        continue
    }
'DisableDVR' {
        RegImport "> 正在禁用 Xbox 游戏/屏幕录像..." "Disable_DVR.reg"
        continue
    }
    {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
        RegImport "> 正在禁用 Windows 中的提示、技巧、建议和广告..." "Disable_Windows_Suggestions.reg"
        continue
    }
    'DisableEdgeAds' {
        RegImport "> 正在禁用 Microsoft Edge 中的广告和 MSN 新闻摘要..." "Disable_Edge_Ads_And_Suggestions.reg"
        continue
    }
    {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
        RegImport "> 正在禁用锁屏上的提示和技巧..." "Disable_Lockscreen_Tips.reg"
        continue
    }
    'DisableDesktopSpotlight' {
        RegImport "> 正在禁用“Windows 聚焦”桌面背景选项..." "Disable_Desktop_Spotlight.reg"
        continue
    }
    'DisableSettings365Ads' {
        RegImport "> 正在禁用“设置主页”中的 Microsoft 365 广告..." "Disable_Settings_365_Ads.reg"
        continue
    }
    'DisableSettingsHome' {
        RegImport "> 正在禁用“设置主页”..." "Disable_Settings_Home.reg"
        continue
    }
    {$_ -in "DisableBingSearches", "DisableBing"} {
        RegImport "> 正在禁用 Windows 搜索中的 Bing 网页搜索、Bing AI 和 Cortana..." "Disable_Bing_Cortana_In_Search.reg"
        
        # 同時移除 Bing 搜索的應用程式套件
        $appsList = 'Microsoft.BingSearch'
        RemoveApps $appsList
        continue
    }
    'DisableCopilot' {
        RegImport "> 正在禁用 Microsoft Copilot..." "Disable_Copilot.reg"

        # 同時移除 Copilot 的應用程式套件
        $appsList = 'Microsoft.Copilot'
        RemoveApps $appsList
        continue
    }
    'DisableRecall' {
        RegImport "> 正在禁用 Windows Recall 快照..." "Disable_AI_Recall.reg"
        continue
    }
    'DisableEdgeAI' {
        RegImport "> 正在禁用 Microsoft Edge 中的 AI 功能..." "Disable_Edge_AI_Features.reg"
        continue
    }
    'DisablePaintAI' {
        RegImport "> 正在禁用画图中的 AI 功能..." "Disable_Paint_AI_Features.reg"
        continue
    }
    'DisableNotepadAI' {
        RegImport "> 正在禁用记事本中的 AI 功能..." "Disable_Notepad_AI_Features.reg"
        continue
    }
    'RevertContextMenu' {
        RegImport "> 正在恢复旧的 Windows 10 风格的右键菜单..." "Disable_Show_More_Options_Context_Menu.reg"
        continue
    }
    'DisableMouseAcceleration' {
        RegImport "> 正在关闭“增强指针精准度”..." "Disable_Enhance_Pointer_Precision.reg"
        continue
    }
    'DisableStickyKeys' {
        RegImport "> 正在禁用粘滞键键盘快捷键..." "Disable_Sticky_Keys_Shortcut.reg"
        continue
    }
    'DisableFastStartup' {
        RegImport "> 正在禁用快速启动..." "Disable_Fast_Startup.reg"
        continue
    }
    'DisableModernStandbyNetworking' {
        RegImport "> 正在禁用“新式待机”期间的网络连接..." "Disable_Modern_Standby_Networking.reg"
        continue
    }
    'ClearStart' {
        Write-Output "> 正在为用户 $(GetUserName) 移除“开始”菜单中的所有已固定应用..."
        ReplaceStartMenu
        Write-Output ""
        continue
    }
    'ReplaceStart' {
        Write-Output "> 正在为用户 $(GetUserName) 替换“开始”菜单..."
        ReplaceStartMenu $script:Params.Item("ReplaceStart")
        Write-Output ""
        continue
    }
    'ClearStartAllUsers' {
        ReplaceStartMenuForAllUsers
        continue
    }
    'ReplaceStartAllUsers' {
        ReplaceStartMenuForAllUsers $script:Params.Item("ReplaceStartAllUsers")
        continue
    }
    'DisableStartRecommended' {
        RegImport "> 正在禁用“开始”菜单中的“推荐”部分..." "Disable_Start_Recommended.reg"
        continue
    }
    'DisableStartPhoneLink' {
        RegImport "> 正在禁用“开始”菜单中的“手机连接”移动设备集成..." "Disable_Phone_Link_In_Start.reg"
        continue
    }
    'EnableDarkMode' {
        RegImport "> 正在为系统和应用启用深色模式..." "Enable_Dark_Mode.reg"
        continue
    }
    'DisableTransparency' {
        RegImport "> 正在禁用透明效果..." "Disable_Transparency.reg"
        continue
    }
    'DisableAnimations' {
        RegImport "> 正在禁用动画和视觉效果..." "Disable_Animations.reg"
        continue
    }
    'TaskbarAlignLeft' {
        RegImport "> 正在将任务栏按钮左对齐..." "Align_Taskbar_Left.reg"
        continue
    }
    'HideSearchTb' {
        RegImport "> 正在从任务栏隐藏搜索图标..." "Hide_Search_Taskbar.reg"
        continue
    }
    'ShowSearchIconTb' {
        RegImport "> 正在将任务栏搜索更改为仅图标..." "Show_Search_Icon.reg"
        continue
    }
    'ShowSearchLabelTb' {
        RegImport "> 正在将任务栏搜索更改为带标签的图标..." "Show_Search_Icon_And_Label.reg"
        continue
    }
    'ShowSearchBoxTb' {
        RegImport "> 正在将任务栏搜索更改为搜索框..." "Show_Search_Box.reg"
        continue
    }
    'HideTaskview' {
        RegImport "> 正在从任务栏隐藏任务视图按钮..." "Hide_Taskview_Taskbar.reg"
        continue
    }
    {$_ -in "HideWidgets", "DisableWidgets"} {
        RegImport "> 正在禁用小组件服务并从任务栏隐藏小组件图标..." "Disable_Widgets_Taskbar.reg"

        # 同時移除小組件的應用程式套件
        $appsList = 'Microsoft.StartExperiencesApp'
        RemoveApps $appsList
        continue
    }
    {$_ -in "HideChat", "DisableChat"} {
        RegImport "> 正在从任务栏隐藏聊天图标..." "Disable_Chat_Taskbar.reg"
        continue
    }
    'EnableEndTask' {
        RegImport "> 正在在任务栏右键菜单中启用“结束任务”选项..." "Enable_End_Task.reg"
        continue
    }
    'EnableLastActiveClick' {
        RegImport "> 正在在任务栏应用区域中启用“上次活动点击”行为..." "Enable_Last_Active_Click.reg"
        continue
    }
    'ExplorerToHome' {
        RegImport "> 正在将文件资源管理器默认打开位置更改为“主页”..." "Launch_File_Explorer_To_Home.reg"
        continue
    }
    'ExplorerToThisPC' {
        RegImport "> 正在将文件资源管理器默认打开位置更改为“此电脑”..." "Launch_File_Explorer_To_This_PC.reg"
        continue
    }
    'ExplorerToDownloads' {
        RegImport "> 正在将文件资源管理器默认打开位置更改为“下载”..." "Launch_File_Explorer_To_Downloads.reg"
        continue
    }
    'ExplorerToOneDrive' {
        RegImport "> 正在将文件资源管理器默认打开位置更改为“OneDrive”..." "Launch_File_Explorer_To_OneDrive.reg"
        continue
    }
    'ShowHiddenFolders' {
        RegImport "> 正在取消隐藏隐藏的文件、文件夹和驱动器..." "Show_Hidden_Folders.reg"
        continue
    }
    'ShowKnownFileExt' {
        RegImport "> 正在为已知文件类型启用文件扩展名..." "Show_Extensions_For_Known_File_Types.reg"
        continue
    }
    'HideHome' {
        RegImport "> 正在从文件资源管理器导航窗格隐藏“主页”部分..." "Hide_Home_from_Explorer.reg"
        continue
    }
    'HideGallery' {
        RegImport "> 正在从文件资源管理器导航窗格隐藏“图库”部分..." "Hide_Gallery_from_Explorer.reg"
        continue
    }
    'HideDupliDrive' {
        RegImport "> 正在从文件资源管理器导航窗格隐藏重复的可移动驱动器条目..." "Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg"
        continue
    }
    {$_ -in "HideOnedrive", "DisableOnedrive"} {
        RegImport "> 正在从文件资源管理器导航窗格隐藏 OneDrive 文件夹..." "Hide_Onedrive_Folder.reg"
        continue
    }
    {$_ -in "Hide3dObjects", "Disable3dObjects"} {
        RegImport "> 正在从文件资源管理器导航窗格隐藏 3D 对象文件夹..." "Hide_3D_Objects_Folder.reg"
        continue
    }
    {$_ -in "HideMusic", "DisableMusic"} {
        RegImport "> 正在从文件资源管理器导航窗格隐藏音乐文件夹..." "Hide_Music_folder.reg"
        continue
    }
    {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
        RegImport "> 正在在右键菜单中隐藏“包括到库中”..." "Disable_Include_in_library_from_context_menu.reg"
        continue
    }
    {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
        RegImport "> 正在在右键菜单中隐藏“授予访问权限”..." "Disable_Give_access_to_context_menu.reg"
        continue
    }
    {$_ -in "HideShare", "DisableShare"} {
        RegImport "> 正在在右键菜单中隐藏“共享”..." "Disable_Share_from_context_menu.reg"
        continue
    }
}

RestartExplorer

Write-Output ""
Write-Output ""
Write-Output ""
Write-Output "脚本完成！请检查上方是否有任何错误。"

AwaitKeyToExit