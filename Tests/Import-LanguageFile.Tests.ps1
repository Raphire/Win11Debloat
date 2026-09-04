BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    $script:LanguagesPath = Join-Path $PSScriptRoot 'TestData\LanguageLoading'
}

Describe 'Resolve-LanguageFolder' {
    It 'resolves <Case>' -ForEach @(
        @{ Case = 'an exact match'; LanguageCode = 'en-US'; Expected = 'en-US' }
        @{ Case = 'a second exact match'; LanguageCode = 'es-ES'; Expected = 'es-ES' }
        @{ Case = 'a language-prefix match when no exact folder exists'; LanguageCode = 'es-AR'; Expected = 'es-ES' }
        @{ Case = 'an unrelated locale to the en-US fallback'; LanguageCode = 'fr-FR'; Expected = 'en-US' }
    ) {
        Resolve-LanguageFolder -LanguageCode $LanguageCode | Should -Be $Expected
    }
}

Describe 'Import-LanguageFile' {
    It 'loads all three JSON files for the resolved language' {
        $lang = Import-LanguageFile -LanguageCode 'en-US'

        $lang.LanguageCode | Should -Be 'en-US'
        $lang.Chrome.TitleBarClose | Should -Be 'Close'
        $lang.Features.DisableTelemetry.Label | Should -Be 'Disable telemetry'
        $lang.Categories.PrivacySuggestedContent.Label | Should -Be 'Privacy & Suggested Content'
    }

    It 'attaches an en-US Fallback when a non-en-US language is loaded' {
        $lang = Import-LanguageFile -LanguageCode 'es-ES'

        $lang.LanguageCode | Should -Be 'es-ES'
        $lang.Fallback.LanguageCode | Should -Be 'en-US'
    }

    It 'does not attach a Fallback when en-US itself is loaded' {
        $lang = Import-LanguageFile -LanguageCode 'en-US'

        $lang.PSObject.Properties['Fallback'] | Should -BeNullOrEmpty
    }

    It 'falls back to en-US without warning when the requested language has no folder at all' {
        # Resolve-LanguageFolder already resolves a nonexistent language straight to 'en-US',
        # so there's no real fallback to warn about here, unlike the broken-folder case below.
        Mock Write-Warning {}

        $lang = Import-LanguageFile -LanguageCode 'fr-FR'

        $lang.LanguageCode | Should -Be 'en-US'
        Should -Invoke Write-Warning -Times 0 -Exactly
    }

    It 'warns and falls back to en-US when the requested language folder exists but fails to load' {
        Mock Write-Warning {}
        Mock Write-Error {}

        $languagesPath = Join-Path $TestDrive 'WithWorkingFallback'
        $brokenFolder = Join-Path $languagesPath 'xx-XX'
        New-Item -ItemType Directory -Path $brokenFolder | Out-Null
        'not valid json' | Out-File (Join-Path $brokenFolder 'Chrome.json')

        $enUsFolder = Join-Path $languagesPath 'en-US'
        Copy-Item -Path (Join-Path $PSScriptRoot 'TestData\LanguageLoading\en-US') -Destination $enUsFolder -Recurse

        $lang = Import-LanguageFile -LanguageCode 'xx-XX' -LanguagesPath $languagesPath

        $lang.LanguageCode | Should -Be 'en-US'
        Should -Invoke Write-Warning -ParameterFilter { $Message -match "Failed to load language 'xx-XX'" } -Times 1 -Exactly
        # The broken xx-XX folder is still expected to report load errors; the fallback en-US load itself must not.
        Should -Invoke Write-Error -ParameterFilter { $Message -match 'Unable to load the en-US language files' } -Times 0
    }

    It 'returns null and reports an error when the requested language fails and en-US is unavailable too' {
        Mock Write-Warning {}
        Mock Write-Error {}

        $languagesPath = Join-Path $TestDrive 'WithoutFallback'
        $brokenFolder = Join-Path $languagesPath 'xx-XX'
        New-Item -ItemType Directory -Path $brokenFolder | Out-Null
        'not valid json' | Out-File (Join-Path $brokenFolder 'Chrome.json')

        $lang = Import-LanguageFile -LanguageCode 'xx-XX' -LanguagesPath $languagesPath

        $lang | Should -BeNullOrEmpty
        Should -Invoke Write-Warning -ParameterFilter { $Message -match "Failed to load language 'xx-XX'" } -Times 1 -Exactly
    }

    It 'reports an error and returns null when en-US itself cannot be loaded' {
        Mock Write-Error {}

        $lang = Import-LanguageFile -LanguageCode 'en-US' -LanguagesPath $TestDrive

        $lang | Should -BeNullOrEmpty
        Should -Invoke Write-Error -ParameterFilter { $Message -match 'Unable to load the en-US language files' } -Times 1 -Exactly
    }
}

Describe 'Get-PluralCategory' {
    It 'returns <Expected> for a count of <Count>' -ForEach @(
        @{ Count = 0; Expected = 'other' }
        @{ Count = 1; Expected = 'one' }
        @{ Count = 2; Expected = 'other' }
        @{ Count = 5; Expected = 'other' }
    ) {
        Get-PluralCategory -LanguageCode 'en-US' -Count $Count | Should -Be $Expected
    }
}

Describe 'Get-Translation' {
    BeforeAll {
        $script:EnLang = Import-LanguageFile -LanguageCode 'en-US'
        $script:EsLang = Import-LanguageFile -LanguageCode 'es-ES'
    }

    It 'looks up a flat Chrome key' {
        Get-Translation -Key 'TitleBarClose' -Lang $script:EnLang | Should -Be 'Close'
    }

    It 'looks up a Field on a Features entry' {
        Get-Translation -Key 'DisableTelemetry' -Field 'Label' -Lang $script:EnLang | Should -Be 'Disable telemetry'
        Get-Translation -Key 'DisableTelemetry' -Field 'ToolTip' -Lang $script:EnLang | Should -Be 'Disables telemetry collection.'
    }

    It 'looks up a Field on a Categories entry' {
        Get-Translation -Key 'PrivacySuggestedContent' -Field 'Label' -Lang $script:EnLang | Should -Be 'Privacy & Suggested Content'
    }

    It 'looks up a Field on a UiGroups entry' {
        Get-Translation -Key 'SearchIcon' -Field 'Label' -Lang $script:EnLang | Should -Be 'Taskbar search style'
    }

    It 'resolves the correct section for a key that exists as both a FeatureId and a GroupId' {
        # ClearStart is a real collision in Config/Features.json: a FeatureId ("remove for this
        # user only") and a GroupId (the combo heading above it) that share the same string.
        # Mirrored in the TestData fixture above so this test doesn't depend on production content.
        Get-Translation -Key 'ClearStart' -Field 'Label' -Section 'Features' -Lang $script:EnLang | Should -Be 'Remove for the selected user'
        Get-Translation -Key 'ClearStart' -Field 'Label' -Section 'UiGroups' -Lang $script:EnLang | Should -Be 'Remove pinned apps from the start menu'
        Get-Translation -Key 'ClearStart' -Field 'ToolTip' -Section 'UiGroups' -Lang $script:EnLang | Should -Be 'This setting allows you to quickly remove all pinned apps from the start menu.'
    }

    It 'returns the key itself when no language has it' {
        Get-Translation -Key 'NoSuchKeyAnywhere' -Lang $script:EnLang | Should -Be 'NoSuchKeyAnywhere'
    }

    It 'returns the key itself when the field is missing on an entry that exists' {
        Get-Translation -Key 'DisableTelemetry' -Field 'UndoLabel' -Lang $script:EnLang | Should -Be 'DisableTelemetry'
    }

    It 'falls back to en-US for a key missing from the active language' {
        Get-Translation -Key 'TitleBarOptions' -Lang $script:EsLang | Should -Be 'Options'
    }

    It 'prefers the active language over the fallback when both have the key' {
        Get-Translation -Key 'TitleBarClose' -Lang $script:EsLang | Should -Be 'Cerrar'
    }

    It 'resolves a plural-suffixed key by count, falling back to the bare key' {
        Get-Translation -Key 'AppsSelectedCount' -Count 1 -Lang $script:EnLang | Should -Be '{0} app selected'
        Get-Translation -Key 'AppsSelectedCount' -Count 5 -Lang $script:EnLang | Should -Be '{0} apps selected'
    }

    It 'substitutes FormatArgs into the resolved string' {
        Get-Translation -Key 'AppsSelectedCount' -Count 1 -FormatArgs @(1) -Lang $script:EnLang | Should -Be '1 app selected'
        Get-Translation -Key 'AppsSelectedCount' -Count 5 -FormatArgs @(5) -Lang $script:EnLang | Should -Be '5 apps selected'
    }

    It 'substitutes a zero FormatArgs value instead of treating the array as falsy' {
        Get-Translation -Key 'AppsSelectedCount' -Count 0 -FormatArgs @(0) -Lang $script:EnLang | Should -Be '0 apps selected'
    }

    It 'returns the unformatted string instead of throwing when FormatArgs is empty' {
        Get-Translation -Key 'AppsSelectedCount' -Count 1 -FormatArgs @() -Lang $script:EnLang | Should -Be '{0} app selected'
    }

    It 'warns and returns the unformatted string instead of throwing on a placeholder/argument count mismatch' {
        Mock Write-Warning {}

        $result = Get-Translation -Key 'TooManyPlaceholders' -FormatArgs @('only one arg') -Lang $script:EnLang

        $result | Should -Be 'Value is {0} and {1}'
        Should -Invoke Write-Warning -ParameterFilter { $Message -match 'TooManyPlaceholders' } -Times 1 -Exactly
    }
}

Describe 'Test-LanguageKeyCoverage' {
    It 'reports no missing or extra keys when a language is compared against itself' {
        $coverage = Test-LanguageKeyCoverage -LanguageCode 'en-US'

        $coverage.MissingKeys | Should -BeNullOrEmpty
        $coverage.ExtraKeys | Should -BeNullOrEmpty
    }

    It 'flags every key missing from a partially translated language' {
        $coverage = Test-LanguageKeyCoverage -LanguageCode 'es-ES'

        $coverage.MissingKeys | Should -Contain 'TitleBarOptions'
        $coverage.MissingKeys | Should -Contain 'AppsSelectedCount_one'
        $coverage.MissingKeys | Should -Contain 'AppsSelectedCount_other'
        $coverage.MissingKeys | Should -Contain 'Features.DisableTelemetry.Label'
        $coverage.MissingKeys | Should -Contain 'Features.DisableTelemetry.ToolTip'
        $coverage.MissingKeys | Should -Contain 'UiGroups.SearchIcon.Label'
        $coverage.MissingKeys | Should -Contain 'Categories.PrivacySuggestedContent.Label'
        $coverage.ExtraKeys | Should -BeNullOrEmpty
    }

    It 'does not flag a key the target language already has' {
        $coverage = Test-LanguageKeyCoverage -LanguageCode 'es-ES'

        $coverage.MissingKeys | Should -Not -Contain 'TitleBarClose'
    }

    It 'resolves a regional variant to its language-prefix match instead of erroring' {
        $coverage = Test-LanguageKeyCoverage -LanguageCode 'es-AR'

        $coverage.ResolvedLanguageCode | Should -Be 'es-ES'
        $coverage.MissingKeys | Should -Contain 'TitleBarOptions'
    }
}

Describe 'ConvertTo-LocalizedXaml' {
    BeforeAll {
        $script:EnLang = Import-LanguageFile -LanguageCode 'en-US'
        $script:EsLang = Import-LanguageFile -LanguageCode 'es-ES'
    }

    It 'substitutes every marker and XML-escapes the resolved value' {
        $xaml = '<Button Content="%LANG:TitleBarClose%"/>'

        ConvertTo-LocalizedXaml -Xaml $xaml -Lang $script:EnLang | Should -Be '<Button Content="Close"/>'
    }

    It 'does not let one substituted value be re-matched by a later marker' {
        $xaml = '<a Text="%LANG:TitleBarOptions%"/><b Text="%LANG:TitleBarClose%"/>'

        ConvertTo-LocalizedXaml -Xaml $xaml -Lang $script:EnLang | Should -Be '<a Text="Options"/><b Text="Close"/>'
    }

    It 'throws when a marker key does not exist in any language' {
        $xaml = '<Button Content="%LANG:NoSuchKeyAnywhere%"/>'

        { ConvertTo-LocalizedXaml -Xaml $xaml -Lang $script:EnLang } | Should -Throw '*NoSuchKeyAnywhere*'
    }

    It 'falls back to en-US instead of throwing for a key missing from a partially translated language' {
        $xaml = '<Button Content="%LANG:TitleBarOptions%"/>'

        ConvertTo-LocalizedXaml -Xaml $xaml -Lang $script:EsLang | Should -Be '<Button Content="Options"/>'
    }

    It 'throws rather than stringifying a Features/UiGroups/Categories entry used by mistake' {
        $xaml = '<TextBlock Text="%LANG:DisableTelemetry%"/>'

        { ConvertTo-LocalizedXaml -Xaml $xaml -Lang $script:EnLang } | Should -Throw '*DisableTelemetry*'
    }
}
