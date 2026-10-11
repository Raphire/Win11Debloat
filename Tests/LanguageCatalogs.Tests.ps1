BeforeDiscovery {
    # Inspect every folder, including incomplete ones that language discovery would exclude.
    $languageCases = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..\Config\Languages') -Directory |
        Sort-Object Name | ForEach-Object {
            @{ LanguageCode = $_.Name }
        })
}

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-LanguageFile.ps1')
    $script:LanguagesPath = Join-Path $PSScriptRoot '..\Config\Languages'
    $featureConfig = Import-JsonFile -filePath (Join-Path $PSScriptRoot '..\Config\Features.json')

    function Add-CatalogValues {
        param($Catalog, [string]$Prefix, [hashtable]$Values)

        foreach ($property in $Catalog.PSObject.Properties) {
            $path = "$Prefix.$($property.Name)"
            if ($property.Value -is [PSCustomObject]) {
                Add-CatalogValues -Catalog $property.Value -Prefix $path -Values $Values
            }
            else {
                $Values[$path] = $property.Value
            }
        }
    }

    $baselineValues = @{}
    foreach ($catalog in (Get-LanguageCatalogNames)) {
        $content = Get-Content -LiteralPath (Join-Path $script:LanguagesPath "en-US/$catalog.json") -Raw -Encoding UTF8 |
            ConvertFrom-Json -ErrorAction Stop
        Add-CatalogValues -Catalog $content -Prefix $catalog -Values $baselineValues
    }
}

Describe 'Shipped language catalogs: <LanguageCode>' -ForEach $languageCases {
    BeforeAll {
        $lang = Import-LanguageFile -LanguageCode $LanguageCode -LanguagesPath $script:LanguagesPath
        $catalogs = @{}
        $translationValues = @{}
        foreach ($catalog in (Get-LanguageCatalogNames)) {
            $catalogs[$catalog] = Get-Content -LiteralPath (Join-Path $script:LanguagesPath "$LanguageCode/$catalog.json") -Raw -Encoding UTF8 |
                ConvertFrom-Json -ErrorAction Stop
            Add-CatalogValues -Catalog $catalogs[$catalog] -Prefix $catalog -Values $translationValues
        }
    }

    It 'is discoverable and loads all required catalogs without falling back' {
        @(Get-AvailableLanguageFolders -LanguagesPath $script:LanguagesPath | Select-Object -ExpandProperty Name) |
            Should -Contain $LanguageCode
        $lang.LanguageCode | Should -Be $LanguageCode
        foreach ($section in @('Chrome', 'Features', 'UiGroups', 'Categories', 'Apps')) {
            $lang.$section | Should -Not -BeNullOrEmpty -Because "$LanguageCode must load $section"
        }
        if ($LanguageCode -ne 'en-US') {
            $lang.Fallback.LanguageCode | Should -Be 'en-US'
        }
    }

    It 'has nonempty translations with the same format placeholders as English' {
        $pattern = '\{\d+(?:,[^{}]+)?(?::[^{}]+)?\}'
        foreach ($key in ($translationValues.Keys | Sort-Object)) {
            $value = $translationValues[$key]
            $value | Should -BeOfType ([string]) -Because "$LanguageCode/$key must be text"
            [string]::IsNullOrWhiteSpace($value) | Should -BeFalse -Because "$LanguageCode/$key must not be blank"
            $referenceKey = $key
            if (-not $baselineValues.ContainsKey($key) -and $key -match '^(Chrome\..+)_(zero|one|two|few|many|other)$') {
                $referenceKey = "$($Matches[1])_other"
            }
            $baselineValues.ContainsKey($referenceKey) | Should -BeTrue -Because "$LanguageCode/$key needs an English reference"
            $expected = @([regex]::Matches($baselineValues[$referenceKey], $pattern).Value | Sort-Object)
            $actual = @([regex]::Matches($value, $pattern).Value | Sort-Object)
            ($actual -join ',') | Should -Be ($expected -join ',') -Because "$LanguageCode/$key must preserve placeholders"
        }
    }

    It 'preserves UTF-8 UI and app names when loading the catalogs' {
        $lang.Chrome.SettingsTitle | Should -BeExactly $catalogs.Chrome.SettingsTitle
        $lang.Apps.'Microsoft.WindowsCalculator'.FriendlyName |
            Should -BeExactly $catalogs.Apps.'Microsoft.WindowsCalculator'.FriendlyName
    }

    It 'displays translated labels instead of internal IDs for all UI features' {
        foreach ($feature in @($featureConfig.Features | Where-Object { $_.Category })) {
            $label = Get-Translation -Key $feature.FeatureId -Field 'Label' -Section 'Features' -Lang $lang
            $label | Should -Not -BeNullOrEmpty -Because "$LanguageCode/$($feature.FeatureId) needs a label"
            $label | Should -Not -Be $feature.FeatureId
        }
    }
}
