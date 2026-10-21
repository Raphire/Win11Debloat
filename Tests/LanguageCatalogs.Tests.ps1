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
    $appConfig = Import-JsonFile -filePath (Join-Path $PSScriptRoot '..\Config\Apps.json')

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

    function Assert-EnglishText {
        param([string]$Key)

        # Inspect the English catalog directly: translation fallback can hide missing keys.
        $baselineValues.ContainsKey($Key) | Should -BeTrue -Because "en-US/$Key must exist"
        $baselineValues[$Key] | Should -BeOfType ([string]) -Because "en-US/$Key must be text"
        [string]::IsNullOrWhiteSpace($baselineValues[$Key]) |
            Should -BeFalse -Because "en-US/$Key must not be blank"
    }
}

Describe 'English catalog coverage for shipped definitions' {
    It 'has a label and apply text for every feature, including CLI-only features' {
        foreach ($feature in $featureConfig.Features) {
            foreach ($field in 'Label', 'ApplyText') {
                Assert-EnglishText -Key "Features.Features.$($feature.FeatureId).$field"
            }
        }
    }

    It 'has undo labels and apply text for every registry or custom undo operation' {
        # These operations implement undo in Invoke-FeatureUndo without a RegistryUndoKey.
        $customUndoIds = @('DisableStoreSearchSuggestions', 'EnableWindowsSandbox', 'EnableWindowsSubsystemForLinux')
        foreach ($feature in $featureConfig.Features) {
            if ($feature.RegistryUndoKey -or $feature.FeatureId -in $customUndoIds) {
                foreach ($field in 'UndoLabel', 'ApplyUndoText') {
                    Assert-EnglishText -Key "Features.Features.$($feature.FeatureId).$field"
                }
            }
        }
    }

    It 'has a tooltip for every feature displayed outside a UI group' {
        $groupedFeatureIds = @($featureConfig.UiGroups | ForEach-Object {
            $_.Values | ForEach-Object { $_.FeatureIds }
        })
        foreach ($feature in $featureConfig.Features) {
            if ($feature.Category -and $feature.FeatureId -notin $groupedFeatureIds) {
                Assert-EnglishText -Key "Features.Features.$($feature.FeatureId).ToolTip"
            }
        }
    }

    It 'has a label, tooltip, and every option label for each UI group' {
        foreach ($group in $featureConfig.UiGroups) {
            foreach ($field in 'Label', 'ToolTip') {
                Assert-EnglishText -Key "Features.UiGroups.$($group.GroupId).$field"
            }
            foreach ($option in $group.Values) {
                Assert-EnglishText -Key "Features.UiGroups.$($group.GroupId).Values.$($option.FeatureIds[0])"
            }
        }
    }

    It 'has a label for every feature category' {
        foreach ($category in $featureConfig.Categories) {
            Assert-EnglishText -Key "Categories.$($category.CategoryId).Label"
        }
    }

    It 'has a friendly name and description for every app using its primary ID' {
        foreach ($app in $appConfig.Apps) {
            # Array entries are aliases of the first ID, as in Import-AppDetailsFromJson.
            $primaryAppId = @($app.AppId)[0]
            foreach ($field in 'FriendlyName', 'Description') {
                Assert-EnglishText -Key "Apps.$primaryAppId.$field"
            }
        }
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
