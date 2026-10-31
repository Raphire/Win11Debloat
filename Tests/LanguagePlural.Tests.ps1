<#
    Plural handling has two halves that can drift apart:

      * Get-PluralCategory decides which CLDR category a count belongs to.
      * The catalogs decide which plural variants actually exist for a language.

    Get-Translation resolves a count by trying "$Key_$category" and then the bare $Key --
    it does not fall back to "_other". So when a rule returns a category a pack has no keys
    for, both lookups miss in that language and in en-US, and the UI prints the raw key name.

    The first block pins the rules that are explicitly implemented; the second block guards
    every shipped pack against the failure mode above. A language whose rule is added later
    only needs a row here, not a new test.
#>

BeforeDiscovery {
    $languageCodes = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..\Config\Languages') -Directory |
        Sort-Object Name | ForEach-Object { $_.Name })
}

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    $script:LanguagesPath = Join-Path $PSScriptRoot '..\Config\Languages'
}

Describe 'Get-PluralCategory rules' {
    It 'returns <Expected> for <LanguageCode> at a count of <Count>' -ForEach @(
        # English: singular only at exactly 1.
        @{ LanguageCode = 'en-US'; Count = 0; Expected = 'other' }
        @{ LanguageCode = 'en-US'; Count = 1; Expected = 'one' }
        @{ LanguageCode = 'en-US'; Count = 2; Expected = 'other' }

        # Portuguese: 'one' for 0 and 1, 'many' for whole multiples of a million.
        @{ LanguageCode = 'pt-BR'; Count = 0; Expected = 'one' }
        @{ LanguageCode = 'pt-BR'; Count = 1; Expected = 'one' }
        @{ LanguageCode = 'pt-BR'; Count = 2; Expected = 'other' }
        @{ LanguageCode = 'pt-BR'; Count = 999999; Expected = 'other' }
        @{ LanguageCode = 'pt-BR'; Count = 1000000; Expected = 'many' }
        @{ LanguageCode = 'pt-BR'; Count = 1000001; Expected = 'other' }
        @{ LanguageCode = 'pt-BR'; Count = 2000000; Expected = 'many' }

        # Japanese and Chinese have no grammatical plural, so every count is 'other'.
        @{ LanguageCode = 'ja-JP'; Count = 0; Expected = 'other' }
        @{ LanguageCode = 'ja-JP'; Count = 1; Expected = 'other' }
        @{ LanguageCode = 'ja-JP'; Count = 5; Expected = 'other' }
        @{ LanguageCode = 'zh-CN'; Count = 0; Expected = 'other' }
        @{ LanguageCode = 'zh-CN'; Count = 1; Expected = 'other' }
        @{ LanguageCode = 'zh-CN'; Count = 5; Expected = 'other' }

        # French: 'one' for 0 and 1, 'other' otherwise. 'many' is deliberately not
        # returned for whole millions, because the French catalogs ship no '_many'
        # keys and a category with no key prints the raw key name.
        @{ LanguageCode = 'fr-FR'; Count = 0; Expected = 'one' }
        @{ LanguageCode = 'fr-FR'; Count = 1; Expected = 'one' }
        @{ LanguageCode = 'fr-FR'; Count = 2; Expected = 'other' }
        @{ LanguageCode = 'fr-FR'; Count = 100; Expected = 'other' }
        @{ LanguageCode = 'fr-FR'; Count = 1000000; Expected = 'other' }

        # Korean: no grammatical plural, so every count is 'other'.
        @{ LanguageCode = 'ko-KR'; Count = 0; Expected = 'other' }
        @{ LanguageCode = 'ko-KR'; Count = 1; Expected = 'other' }
        @{ LanguageCode = 'ko-KR'; Count = 2; Expected = 'other' }
        @{ LanguageCode = 'ko-KR'; Count = 5; Expected = 'other' }
        @{ LanguageCode = 'ko-KR'; Count = 11; Expected = 'other' }
        @{ LanguageCode = 'ko-KR'; Count = 100; Expected = 'other' }
        @{ LanguageCode = 'ko-KR'; Count = 1000000; Expected = 'other' }

        # Russian: 'one' for 1/21/31 but not 11, 'few' for 2-4/22-24 but not 12-14,
        # 'many' for everything else including 0.
        @{ LanguageCode = 'ru-RU'; Count = 0; Expected = 'many' }
        @{ LanguageCode = 'ru-RU'; Count = 1; Expected = 'one' }
        @{ LanguageCode = 'ru-RU'; Count = 2; Expected = 'few' }
        @{ LanguageCode = 'ru-RU'; Count = 4; Expected = 'few' }
        @{ LanguageCode = 'ru-RU'; Count = 5; Expected = 'many' }
        @{ LanguageCode = 'ru-RU'; Count = 11; Expected = 'many' }
        @{ LanguageCode = 'ru-RU'; Count = 12; Expected = 'many' }
        @{ LanguageCode = 'ru-RU'; Count = 21; Expected = 'one' }
        @{ LanguageCode = 'ru-RU'; Count = 22; Expected = 'few' }
        @{ LanguageCode = 'ru-RU'; Count = 111; Expected = 'many' }
    ) {
        Get-PluralCategory -LanguageCode $LanguageCode -Count $Count | Should -Be $Expected
    }
}

Describe 'Shipped plurals' {
    It 'renders <LanguageCode> text rather than the raw key at every count' -ForEach @(
        foreach ($code in $languageCodes) { @{ LanguageCode = $code } }
    ) {
        $lang = Import-LanguageFile -LanguageCode $LanguageCode -LanguagesPath $script:LanguagesPath
        $lang | Should -Not -BeNullOrEmpty -Because "$LanguageCode has to load before its plurals can be checked"
        # Import-LanguageFile silently falls back to en-US when a pack fails to load, and that
        # fallback passes the non-null assertion above, so without this the text checks below
        # would exercise en-US and report the wrong language's plurals.
        $lang.LanguageCode | Should -Be $LanguageCode -Because 'a fallback to en-US would test the wrong pack'

        # 1000000 is not redundant with 1000: pt-BR returns 'many' only for whole millions.
        foreach ($count in @(0, 1, 2, 4, 5, 11, 21, 100, 1000, 1000000, 1000001)) {
            $category = Get-PluralCategory -LanguageCode $LanguageCode -Count $count
            $text = Get-Translation -Key 'AppSelectionStatusSelected' -Section 'Chrome' -Lang $lang -Count $count -FormatArgs @($count)

            $text | Should -Not -BeNullOrEmpty -Because "$LanguageCode/$count must resolve to text"
            $text | Should -Not -Be 'AppSelectionStatusSelected' -Because (
                "$LanguageCode returns the '$category' category at $count; if the pack has no " +
                "'_$category' key the lookup falls through to the bare key and prints its name")
        }
    }
}
