BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Get-LanguageKeyReport.ps1')

    # Writes a language folder from plain hashtables, so each test states exactly which keys a language ships.
    function New-LanguageFolder {
        param([string]$Root, [string]$Code, [hashtable]$Chrome, [hashtable]$Features = @{ TweakA = @{ Label = 'A' } })

        $folder = Join-Path $Root $Code
        New-Item -ItemType Directory -Path $folder | Out-Null
        $files = @{
            Chrome     = $Chrome
            Features   = @{ Features = $Features; UiGroups = @{ GroupA = @{ Label = 'G'; Values = @{ ValueA = 'V' } } } }
            Categories = @{ CategoryA = @{ Label = 'C' } }
            Apps       = @{ 'App.A' = @{ FriendlyName = 'App' } }
        }
        foreach ($name in $files.Keys) {
            $files[$name] | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $folder "$name.json") -Encoding UTF8
        }
    }

    $script:EnglishChrome = @{ Title = 'Title'; Selected_one = '{0} item'; Selected_other = '{0} items' }
}

Describe 'Get-LanguageKeyReport' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root | Out-Null
        New-LanguageFolder -Root $root -Code 'en-US' -Chrome $script:EnglishChrome
    }

    It 'reports nothing for a language that has every key' {
        New-LanguageFolder -Root $root -Code 'de-DE' -Chrome $script:EnglishChrome

        $report = Get-LanguageKeyReport -LanguagesPath $root

        $report.LanguageCode | Should -Be 'de-DE'
        $report.MissingKeys | Should -BeNullOrEmpty
        $report.ExtraKeys | Should -BeNullOrEmpty
    }

    It 'lists missing and extra keys, including nested catalog fields' {
        New-LanguageFolder -Root $root -Code 'de-DE' -Chrome @{ Selected_one = 'x'; Selected_other = 'x'; Old = 'x' } `
            -Features @{ TweakB = @{ Label = 'B' } }

        $report = Get-LanguageKeyReport -LanguagesPath $root

        $report.MissingKeys | Should -Be @('Features.TweakA.Label', 'Title')
        $report.ExtraKeys | Should -Be @('Features.TweakB.Label', 'Old')
    }

    It 'expects no _one keys for a language whose rule only returns other' {
        New-LanguageFolder -Root $root -Code 'ja-JP' -Chrome @{ Title = 'x'; Selected_other = 'x' }

        $report = Get-LanguageKeyReport -LanguagesPath $root

        $report.MissingKeys | Should -BeNullOrEmpty
        $report.ExtraKeys | Should -BeNullOrEmpty
    }

    It 'flags a _one key that a language whose rule only returns other never uses' {
        New-LanguageFolder -Root $root -Code 'zh-CN' -Chrome $script:EnglishChrome

        (Get-LanguageKeyReport -LanguagesPath $root).ExtraKeys | Should -Be @('Selected_one')
    }

    It 'expects a _many key where the language rule returns many' {
        New-LanguageFolder -Root $root -Code 'pt-BR' -Chrome $script:EnglishChrome

        (Get-LanguageKeyReport -LanguagesPath $root).MissingKeys | Should -Be @('Selected_many')
    }

    It 'does not report a shipped _other key as extra when the rule never returns other' {
        New-LanguageFolder -Root $root -Code 'ru-RU' -Chrome @{ Title = 'x'; Selected_one = 'x'; Selected_few = 'x'; Selected_many = 'x'; Selected_other = 'x' }

        $report = Get-LanguageKeyReport -LanguagesPath $root

        $report.MissingKeys | Should -BeNullOrEmpty
        $report.ExtraKeys | Should -BeNullOrEmpty
    }

    It 'marks a folder with a missing catalog as not loaded' {
        New-LanguageFolder -Root $root -Code 'de-DE' -Chrome $script:EnglishChrome
        Remove-Item -LiteralPath (Join-Path $root 'de-DE\Apps.json')
        Mock Import-JsonFile -ParameterFilter { $filePath -like '*de-DE*Apps.json' } { $null }

        $report = Get-LanguageKeyReport -LanguagesPath $root

        $report.Loaded | Should -BeFalse
    }

    It 'limits the report to the requested languages' {
        New-LanguageFolder -Root $root -Code 'de-DE' -Chrome $script:EnglishChrome
        New-LanguageFolder -Root $root -Code 'fr-FR' -Chrome $script:EnglishChrome

        @(Get-LanguageKeyReport -LanguagesPath $root -LanguageCode 'fr-FR').LanguageCode | Should -Be @('fr-FR')
    }
}

Describe 'Shipped languages' {
    It 'all load for the report' {
        $reports = @(Get-LanguageKeyReport -LanguagesPath (Join-Path $PSScriptRoot '..\Config\Languages'))

        $reports | Should -Not -BeNullOrEmpty
        foreach ($report in $reports) {
            $report.Loaded | Should -BeTrue -Because "$($report.LanguageCode) must load"
        }
    }
}
