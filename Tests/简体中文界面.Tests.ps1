BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    $script:LanguagesPath = Join-Path $PSScriptRoot '..\Config\Languages'
}

Describe '简体中文界面语言' {
    It '可发现并加载四份中文资源' {
        @(Get-AvailableLanguageFolders | Select-Object -ExpandProperty Name) | Should -Contain 'zh-CN'
        $lang = Import-LanguageFile -LanguageCode 'zh-CN'
        $lang.LanguageCode | Should -Be 'zh-CN'
        $lang.Chrome.SettingsTitle | Should -Be '设置'
        $lang.Apps.'Microsoft.WindowsCalculator'.FriendlyName | Should -Be '计算器'
        $lang.Fallback.LanguageCode | Should -Be 'en-US'
    }

    It '与当前英文资源的键完全对应' {
        $coverage = Test-LanguageKeyCoverage -LanguageCode 'zh-CN'
        $coverage.ResolvedLanguageCode | Should -Be 'zh-CN'
        $coverage.MissingKeys | Should -BeNullOrEmpty
        $coverage.ExtraKeys | Should -BeNullOrEmpty
    }

    It '界面中的功能均能显示名称而非内部编号' {
        $config = Import-JsonFile -filePath (Join-Path $PSScriptRoot '..\Config\Features.json')
        $lang = Import-LanguageFile -LanguageCode 'zh-CN'
        foreach ($feature in @($config.Features | Where-Object { $_.Category })) {
            Get-Translation -Key $feature.FeatureId -Field 'Label' -Section 'Features' -Lang $lang |
                Should -Not -Be $feature.FeatureId
        }
    }

    It '中文数量 <_> 使用 other 且能格式化显示' -ForEach @(0, 1, 2, 100) {
        $Count = $_
        Get-PluralCategory -LanguageCode 'zh-CN' -Count $Count | Should -Be 'other'
        $lang = Import-LanguageFile -LanguageCode 'zh-CN'
        Get-Translation -Key 'ImportExportAppsSelected' -Count $Count -FormatArgs @($Count) -Lang $lang |
            Should -Be "已选择 $Count 个应用"
    }

    It '缺少中文键时仍回退英文且未知键原样返回' {
        $lang = [PSCustomObject]@{
            LanguageCode = 'zh-CN'
            Chrome = [PSCustomObject]@{}
            Fallback = Import-LanguageFile -LanguageCode 'en-US'
        }
        Get-Translation -Key 'MessageBoxCancel' -Lang $lang | Should -Be 'Cancel'
        Get-Translation -Key 'MissingTranslationKey' -Lang $lang | Should -Be 'MissingTranslationKey'
        Get-PluralCategory -LanguageCode 'en-US' -Count 1 | Should -Be 'one'
    }

    It '所有界面格式占位符与英文一致' {
        function Assert-TranslationValues($en, $zh) {
            foreach ($property in $en.PSObject.Properties) {
                $value = $zh.($property.Name)
                if ($property.Value -is [string]) {
                    $value | Should -Not -BeNullOrEmpty
                    $pattern = '\{\d+(?:,[^{}]+)?(?::[^{}]+)?\}'
                    ([string]::Join(',', @([regex]::Matches($value, $pattern).Value | Sort-Object))) |
                        Should -Be ([string]::Join(',', @([regex]::Matches($property.Value, $pattern).Value | Sort-Object)))
                }
                else { Assert-TranslationValues $property.Value $value }
            }
        }
        foreach ($catalog in (Get-LanguageCatalogNames)) {
            $en = Get-Content (Join-Path $script:LanguagesPath "en-US/$catalog.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            $zh = Get-Content (Join-Path $script:LanguagesPath "zh-CN/$catalog.json") -Raw -Encoding UTF8 | ConvertFrom-Json
            Assert-TranslationValues $en $zh
        }
    }
}
