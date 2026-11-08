BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    . "$script:RepoRoot/Scripts/GUI/Ui-Preferences.ps1"
    . "$script:RepoRoot/Scripts/GUI/Get-SystemUsesDarkMode.ps1"
    . "$script:RepoRoot/Scripts/FileIO/Import-JsonFile.ps1"
    . "$script:RepoRoot/Scripts/FileIO/Import-LanguageFile.ps1"
    $script:LanguagesPath = Join-Path $script:RepoRoot 'Config/Languages'
}

Describe 'CLI language routing' {
    BeforeAll {
        function Show-CliMenuOptions { '0' }
        function Show-MainWindow {}
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            "$script:RepoRoot/Win11Debloat.ps1", [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty
        # Execute only language initialization and mode routing, avoiding Windows startup/mutations.
        $initialization = $ast.EndBlock.Statements | Where-Object {
            $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $_.Left.Extent.Text -in @('$script:UiPreferences', '$script:Lang')
        }
        $script:LanguageStartup = [scriptblock]::Create(($initialization.Extent.Text -join "`n"))
        $routing = $ast.EndBlock.Statements | Where-Object {
            $_ -is [System.Management.Automation.Language.IfStatementAst] -and
            $_.Extent.Text -match '\$result = Show-MainWindow'
        }
        $script:LanguageRouting = [scriptblock]::Create($routing.Extent.Text)
    }

    BeforeEach {
        $script:UiPreferencesFilePath = "$TestDrive/preferences.json"
        Save-UiPreferences -Preferences @{ Theme = 'Dark'; Language = 'nl-NL' }
        $script:Params = @{ CLI = $true }
        $controlParamsCount = 1
        $launchInCLI = $true
        $CLI = $true
        $Silent = $true
        $Language = 'pt-BR'
        $RunDefaults = $false
        $RunDefaultsLite = $false
        $RunSavedSettings = $false
        $Config = $null
        $script:MenuLanguage = $null
        $script:GuiLanguage = $null
        Mock Show-CliMenuOptions { $script:MenuLanguage = $script:Lang.LanguageCode; '0' }
        Mock Show-MainWindow { throw 'Simulated GUI startup failure' }
        Mock Write-Warning {}
    }

    It 'uses English in CLI despite saved and explicit GUI languages' {
        & $script:LanguageStartup
        & $script:LanguageRouting

        $script:MenuLanguage | Should -Be 'en-US'
        $script:UiPreferences.Theme | Should -Be 'Dark'
        (Get-UiPreferences).Language | Should -Be 'nl-NL'
        Should -Invoke Show-MainWindow -Times 0 -Exactly
    }

    It 'restores English before falling back from the selected GUI language to CLI' {
        $launchInCLI = $false
        $CLI = $false
        Mock Show-MainWindow {
            $script:GuiLanguage = $script:Lang.LanguageCode
            throw 'Simulated GUI startup failure'
        }
        & $script:LanguageStartup
        & $script:LanguageRouting

        Should -Invoke Show-MainWindow -Times 1 -Exactly
        $script:GuiLanguage | Should -Be 'pt-BR'
        $script:MenuLanguage | Should -Be 'en-US'
        (Get-UiPreferences).Language | Should -Be 'nl-NL'
    }
}

Describe 'UI preference initialization' {
    BeforeEach {
        $script:UiPreferencesFilePath = "$TestDrive/preferences.json"
        Save-UiPreferences -Preferences @{ Theme = 'Dark'; Language = 'nl-NL' }
    }

    It 'loads the saved language and theme' {
        Initialize-UiPreferences
        $script:UiPreferences.Theme | Should -Be 'Dark'
        $script:UiPreferences.Language | Should -Be 'nl-NL'
        $script:Lang.LanguageCode | Should -Be 'nl-NL'
    }

    It 'honors an explicit language without persisting the override' {
        Initialize-UiPreferences -Language 'pt-BR'
        $script:UiPreferences.Language | Should -Be 'pt-BR'
        $script:Lang.LanguageCode | Should -Be 'pt-BR'
        (Get-UiPreferences).Language | Should -Be 'nl-NL'
    }

    It 'keeps Auto as a preference while resolving the system language' {
        Initialize-UiPreferences -Language 'Auto'
        $script:UiPreferences.Language | Should -Be 'Auto'
        $script:Lang.LanguageCode | Should -Be (Import-LanguageFile).LanguageCode
    }

    It 'normalizes <Language> to the resolved folder' -ForEach @(
        @{ Language = 'nl-BE'; Expected = 'nl-NL' }
        @{ Language = 'zz-ZZ'; Expected = 'en-US' }
    ) {
        Initialize-UiPreferences -Language $Language
        $script:UiPreferences.Language | Should -Be $Expected
        $script:Lang.LanguageCode | Should -Be $Expected
    }

    It 'leaves language failure handling to the caller' {
        Mock Get-UiLanguage { $null }
        Initialize-UiPreferences
        $script:Lang | Should -BeNullOrEmpty
    }
}

Describe 'UI preference persistence and theme resolution' {
    It 'defaults to system settings when no preferences exist' {
        $result = Get-UiPreferences -Path "$TestDrive/missing.json"
        $result.Theme | Should -Be 'Auto'
        $result.Language | Should -Be 'Auto'
    }
    It 'round trips explicit preferences' {
        Save-UiPreferences -Preferences @{Theme='Dark'; Language='pt-BR'} -Path "$TestDrive/preferences.json"
        $result = Get-UiPreferences -Path "$TestDrive/preferences.json"
        $result.Theme | Should -Be 'Dark'
        $result.Language | Should -Be 'pt-BR'
    }
    It 'ignores unsupported preferences' {
        '{"Theme":"Unknown","Language":"../other"}' | Set-Content "$TestDrive/invalid.json"
        $result = Get-UiPreferences -Path "$TestDrive/invalid.json"
        $result.Theme | Should -Be 'Auto'
        $result.Language | Should -Be 'Auto'
    }
    It 'keeps the previous settings when writing fails' {
        Save-UiPreferences -Preferences @{Theme='Light'; Language='en-US'} -Path "$TestDrive/safe.json"
        Mock Set-Content { throw 'Disk full' }
        { Save-UiPreferences -Preferences @{Theme='Dark'; Language='pt-BR'} -Path "$TestDrive/safe.json" } | Should -Throw
        (Get-UiPreferences -Path "$TestDrive/safe.json").Theme | Should -Be 'Light'
    }
    It 'honors explicit themes and resolves Auto from Windows' {
        Mock Get-SystemUsesDarkMode { $true }
        $script:UiPreferences = @{Theme='Light'}
        Get-AppUsesDarkMode | Should -BeFalse
        $script:UiPreferences.Theme = 'Dark'
        Get-AppUsesDarkMode | Should -BeTrue
        $script:UiPreferences.Theme = 'Auto'
        Get-AppUsesDarkMode | Should -BeTrue
        Should -Invoke Get-SystemUsesDarkMode -Times 1 -Exactly
    }
}
