BeforeAll {
    function Wait-ForKeyPress {}
    function Test-AppInWingetList { param($appId, $InstalledList) $false }

    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-JsonFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Add-Parameter.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Save-ToFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-Settings.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Save-Settings.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-AppsFromFile.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-AppDetailsFromJson.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Import-AppPresetsFromJson.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\FileIO\Get-ValidatedAppList.ps1')
    $script:JsonFixturePath = Join-Path $PSScriptRoot 'TestData\JsonFileLoading'
}

Describe 'Import-Settings' {
    BeforeEach {
        $script:Params = @{}
        $script:ModernStandbySupported = $false
        $script:Features = @{
            Supported = [PSCustomObject]@{ FeatureId = 'Supported'; MinVersion = 22000; MaxVersion = 30000 }
            TooNew = [PSCustomObject]@{ FeatureId = 'TooNew'; MinVersion = 99999; MaxVersion = $null }
            DisableModernStandbyNetworking = [PSCustomObject]@{ FeatureId = 'DisableModernStandbyNetworking'; MinVersion = $null; MaxVersion = $null }
        }
        Mock Get-ItemPropertyValue { 22631 }
        Mock Add-Parameter {}
        Mock Write-Error {}
    }

    It 'loads enabled, known, compatible settings and skips all other entries' {
        Import-Settings -filePath (Join-Path $script:JsonFixturePath 'DefaultSettings.Valid.json')

        Should -Invoke Add-Parameter -Times 1 -Exactly -ParameterFilter { $parameterName -eq 'Supported' -and $value -eq 'configured' }
    }

    It 'throws when <Case>' -ForEach @(
        @{ Case = 'the last-used settings JSON is invalid'; FileName = 'LastUsedSettings.Invalid.json'; WriteErrorCalls = 1 }
        @{ Case = 'the default settings file has no Settings property'; FileName = 'DefaultSettings.MissingSettings.json'; WriteErrorCalls = 0 }
    ) {
        $path = Join-Path $script:JsonFixturePath $FileName

        {
            & {
                $ErrorActionPreference = 'Continue'
                Import-Settings -filePath $path
            }
        } | Should -Throw "Failed to load settings from $FileName"
        Should -Invoke Add-Parameter -Times 0 -Exactly
        Should -Invoke Write-Error -Times $WriteErrorCalls -Exactly
    }
}

Describe 'Save-Settings' {
    BeforeEach {
        $script:SavedSettingsFilePath = Join-Path $TestDrive 'LastUsedSettings.json'
        $script:ControlParams = @('Silent', 'WhatIf')
        $script:Features = @{ Feature = [PSCustomObject]@{ FeatureId = 'Feature' } }
        Mock Save-ToFile { $true }
        Mock Write-Host {}
        Mock Write-Output {}
    }

    It 'saves only feature parameters and excludes control or unknown parameters' {
        $script:Params = @{ Feature = 'configured'; Silent = $true; Unknown = 42 }

        Save-Settings

        Should -Invoke Save-ToFile -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $script:SavedSettingsFilePath -and
            @($Config.Settings).Count -eq 1 -and
            $Config.Settings[0].Name -eq 'Feature' -and
            $Config.Settings[0].Value -eq 'configured'
        }
    }

    It 'does not persist in WhatIf mode' {
        $script:Params = @{ Feature = $true; WhatIf = $true }

        Save-Settings

        Should -Invoke Save-ToFile -Times 0 -Exactly
    }

    It 'reports a persistence failure without throwing' {
        $script:Params = @{ Feature = $true }
        Mock Save-ToFile { $false }

        { Save-Settings } | Should -Not -Throw
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like 'Error:*' }
    }
}

Describe 'Import-AppsFromFile' {
    It 'returns selected IDs, trims whitespace, and supports scalar and array AppId values' {
        $path = Join-Path $TestDrive 'apps.json'
        '{"Apps":[{"AppId":" One.App ","SelectedByDefault":true},{"AppId":["Two.App","  "],"SelectedByDefault":true},{"AppId":"Ignored.App","SelectedByDefault":false}]}' |
            Set-Content -LiteralPath $path -Encoding UTF8

        @(Import-AppsFromFile -appsFilePath $path) | Should -Be @('One.App', 'Two.App')
    }

    It 'returns an empty collection for a missing file' {
        @(Import-AppsFromFile -appsFilePath (Join-Path $TestDrive 'missing.json')) | Should -HaveCount 0
    }

    It 'reports invalid JSON and invokes the CLI acknowledgement hook' {
        $path = Join-Path $TestDrive 'invalid-apps.json'
        'not json' | Set-Content -LiteralPath $path
        Mock Write-Error {}
        Mock Wait-ForKeyPress {}

        @(Import-AppsFromFile -appsFilePath $path) | Should -HaveCount 0
        Should -Invoke Write-Error -Times 1 -Exactly
        Should -Invoke Wait-ForKeyPress -Times 1 -Exactly
    }
}

Describe 'Get-ValidatedAppList' {
    It 'normalizes wildcard selections and skips unsupported applications' {
        Mock Import-AppDetailsFromJson { @([PSCustomObject]@{ AppId = @('One.App', 'Two.App') }) }
        Mock Write-Host {}

        @(Get-ValidatedAppList -appsList @('*One.App*', ' Missing.App ')) | Should -Be @('One.App')
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -like "*Missing.App*" }
    }
}

Describe 'Import-AppDetailsFromJson' {
    BeforeEach {
        $script:AppsListFilePath = Join-Path $TestDrive 'Apps.json'
        '{"Apps":[{"AppId":["One.App","Alias.App"],"FriendlyName":"One","SelectedByDefault":true,"RemovalMethod":"WinGet"},{"AppId":"Two.App","SelectedByDefault":false},{"AppId":"  ","SelectedByDefault":true}],"Presets":[{"Name":"Minimal","AppIds":["One.App"]}]}' |
            Set-Content -LiteralPath $script:AppsListFilePath -Encoding UTF8
    }

    It 'projects app metadata, defaults removal method, and honors initial checked state' {
        $apps = @(Import-AppDetailsFromJson -InitialCheckedFromJson)

        $apps | Should -HaveCount 2
        $apps[0].DisplayName | Should -Be 'One (One.App, Alias.App)'
        $apps[0].IsChecked | Should -BeTrue
        $apps[0].RemovalMethod | Should -Be 'WinGet'
        $apps[1].FriendlyName | Should -Be 'Two.App'
        $apps[1].RemovalMethod | Should -Be 'Appx'
        $apps[1].AppId -is [array] | Should -BeTrue
        @($apps[1].AppId) | Should -HaveCount 1
    }

    It 'skips missing, blank, and non-string app IDs without failing the complete catalog' {
        '{"Apps":[{"AppId":null},{"FriendlyName":"Missing"},{"AppId":42},{"AppId":[" Valid.App ",null,{},""]}]}' |
            Set-Content -LiteralPath $script:AppsListFilePath -Encoding UTF8

        $apps = @(Import-AppDetailsFromJson)

        $apps | Should -HaveCount 1
        $apps[0].AppId -is [array] | Should -BeTrue
        $apps[0].AppId | Should -Be @('Valid.App')
    }

    It 'filters to installed apps using Appx and winget detection' {
        Mock Get-AppxPackage { param($Name) if ($Name -eq 'Two.App') { [PSCustomObject]@{ Name = $Name } } }
        Mock Test-AppInWingetList { $false }

        $apps = @(Import-AppDetailsFromJson -OnlyInstalled -InstalledList @())

        $apps | Should -HaveCount 1
        $apps[0].AppId | Should -Be 'Two.App'
    }

    It 'loads presets and preserves their ID arrays' {
        $presets = @(Import-AppPresetsFromJson)

        $presets | Should -HaveCount 1
        $presets[0].Name | Should -Be 'Minimal'
        $presets[0].AppIds -is [array] | Should -BeTrue
        $presets[0].AppIds | Should -Be 'One.App'
    }

    It 'returns empty collections and reports malformed JSON' {
        'not json' | Set-Content -LiteralPath $script:AppsListFilePath
        Mock Write-Error {}
        Mock Write-Warning {}

        @(Import-AppDetailsFromJson) | Should -HaveCount 0
        @(Import-AppPresetsFromJson) | Should -HaveCount 0
        Should -Invoke Write-Error -Times 1 -Exactly
        Should -Invoke Write-Warning -Times 1 -Exactly
    }
}
