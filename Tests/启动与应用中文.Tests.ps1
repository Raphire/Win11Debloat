BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    . "$script:RepoRoot/Scripts/FileIO/Import-JsonFile.ps1"
    . "$script:RepoRoot/Scripts/FileIO/Import-LanguageFile.ps1"
    . "$script:RepoRoot/Scripts/FileIO/Import-AppDetailsFromJson.ps1"
    . "$script:RepoRoot/Scripts/FileIO/Import-AppPresetsFromJson.ps1"
    . "$script:RepoRoot/Scripts/Threading/Invoke-NonBlocking.ps1"
    function Invoke-DoEvents {}
    $script:LanguagesPath = "$script:RepoRoot/Config/Languages"
    $script:AppsListFilePath = "$script:RepoRoot/Config/Apps.json"
    $script:LoadAppsDetailsScriptPath = "$script:RepoRoot/Scripts/FileIO/Import-AppDetailsFromJson.ps1"
    $script:ImportLanguageFileScriptPath = "$script:RepoRoot/Scripts/FileIO/Import-LanguageFile.ps1"
    $script:TestAppInWingetListScriptPath = "$script:RepoRoot/Scripts/AppRemoval/Test-AppInWingetList.ps1"
    $script:Lang = Import-LanguageFile -LanguageCode 'zh-CN'
}

Describe '本地中文版完整性' {
    It '实际执行启动窗口中的四条输出并得到中文' {
        $tokens=$null; $errors=$null
        $ast=[System.Management.Automation.Language.Parser]::ParseFile("$script:RepoRoot/Win11Debloat.ps1",[ref]$tokens,[ref]$errors)
        $errors | Should -BeNullOrEmpty
        foreach($message in @('正在启动 Win11Debloat','请保持此窗口打开','WinGet 未安装或版本过旧','按任意键仍然继续')) {
            $commands=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -in @('Write-Host','Write-Warning','Write-Output') -and $n.Extent.Text.Contains($message)},$true))
            $commands.Count | Should -Be 1
            $output=& ([scriptblock]::Create($commands[0].Extent.Text)) *>&1 | Out-String
            $output | Should -Match ([regex]::Escape($message))
        }
    }

    It '141 个应用的说明全部含中文，应用标识与目录保持一致' {
        $apps=@(Import-AppDetailsFromJson)
        $apps.Count | Should -Be 141
        foreach($app in $apps) {
            $app.Description | Should -Match '[\u4e00-\u9fff]'
            $app.FriendlyName | Should -Match '[\u4e00-\u9fff]'
        }
        $catalog=Import-JsonFile -filePath $script:AppsListFilePath
        @($apps.AppId | Sort-Object) | Should -Be @($catalog.Apps.AppId | Sort-Object)
    }

    It '后台加载也保留中文名称和说明' {
        $script:GuiWindow=$null
        $apps=@(Invoke-AppDetailsFromJsonAsync)
        $apps.Count | Should -Be 141
        ($apps | Where-Object { $_.AppId -contains 'Microsoft.WindowsCalculator' }).FriendlyName | Should -Be '计算器'
        ($apps | Where-Object { $_.AppId -contains 'Clipchamp.Clipchamp' }).Description | Should -Be '微软出品的视频编辑器'
    }

    It '应用预设显示中文并保留原应用编号' {
        $presets=@(Import-AppPresetsFromJson)
        $presets[0].Name | Should -Be 'Xbox 游戏应用'
        $presets[1].Name | Should -Be '厂商预装软件（戴尔、惠普、联想、LG）'
        $presets[0].AppIds | Should -Contain 'Microsoft.GamingApp'
    }

    It '四个语言文件的键完全对应英文基线' {
        $coverage=Test-LanguageKeyCoverage -LanguageCode 'zh-CN'
        $coverage.MissingKeys | Should -BeNullOrEmpty
        $coverage.ExtraKeys | Should -BeNullOrEmpty
    }
}
