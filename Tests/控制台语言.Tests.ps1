BeforeAll {
    $script:RepoRoot=Split-Path $PSScriptRoot -Parent
    . "$script:RepoRoot/Scripts/FileIO/获取控制台翻译.ps1"
}
Describe '控制台语言回退与格式参数' {
    It '中文启动提示在界面语言加载之前可用' {
        Get-ConsoleTranslation -Text '             Win11Debloat is launching...' -LanguageCode 'zh-CN' | Should -Be '             正在启动 Win11Debloat……'
    }
    It '英文输出保留原文' {
        Get-ConsoleTranslation -Text 'Removing {0}' -FormatArgs @('Test.App') -LanguageCode 'en-US' | Should -Be 'Removing Test.App'
    }
    It '缺失语言时回退英文' {
        Get-ConsoleTranslation -Text 'Removing {0}' -FormatArgs @('Test.App') -LanguageCode 'xx-XX' | Should -Be 'Removing Test.App'
    }
    It '中文动态参数保持正确' {
        Get-ConsoleTranslation -Text 'Removing {0}' -FormatArgs @('Test.App') -LanguageCode 'zh-CN' | Should -Be '正在移除 Test.App'
    }
}

Describe '控制台资源与后台会话' {
    It '中英文键及所有占位符完全一致，资源可由 Windows PowerShell 读取' {
        $en = Get-Content "$script:RepoRoot/Config/Languages/en-US/Console.json" -Raw -Encoding UTF8 | ConvertFrom-Json
        $zh = Get-Content "$script:RepoRoot/Config/Languages/zh-CN/Console.json" -Raw -Encoding UTF8 | ConvertFrom-Json
        @($en.PSObject.Properties.Name | Sort-Object) | Should -Be @($zh.PSObject.Properties.Name | Sort-Object)
        foreach ($property in $en.PSObject.Properties) {
            $key=$property.Name
            @([regex]::Matches($key, '\{\d+\}').Value | Sort-Object) | Should -Be @([regex]::Matches($zh.$key, '\{\d+\}').Value | Sort-Object)
        }
    }
    It '后台会话保持语言和数组参数' {
        . "$script:RepoRoot/Scripts/Threading/Invoke-NonBlocking.ps1"
        $script:ConsoleLanguageCode='zh-CN'
        $script:GuiWindow=$null
        $result=Invoke-NonBlocking -TimeoutSeconds 10 -ScriptBlock { param($apps,$suffix) Get-ConsoleTranslation -Text 'Removing {0}' -FormatArgs @(($apps -join ',')+$suffix) } -ArgumentList @(@('A','B'),'!')
        $result | Should -Be '正在移除 A,B!'
        $script:ConsoleLanguageCode=$null
    }
    It '缺失的翻译键保持原文' {
        Get-ConsoleTranslation -Text 'Future message {0}' -FormatArgs @('X') -LanguageCode 'zh-CN' | Should -Be 'Future message X'
    }
}
