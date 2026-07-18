BeforeAll {
    function Get-UserName { 'Alice' }
    function Generate-AppsList { @() }
    function Add-Parameter { param($Name, $Value) }
    function Save-Settings {}
    function Import-Settings { param($filePath, $expectedVersion) }
    function Wait-ForKeyPress {}
    function Show-AppSelectionWindow { $false }

    . (Join-Path $PSScriptRoot '..\Scripts\CLI\Write-CliHeader.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\CLI\Write-PendingChanges.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\CLI\Show-CliAppRemoval.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\CLI\Show-CliDefaultModeAppRemovalOptions.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\CLI\Show-CliDefaultModeOptions.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\CLI\Show-CliLastUsedSettings.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\CLI\Show-CliMenuOptions.ps1')
}

Describe 'Show-CliMenuOptions' {
    BeforeEach {
        $script:Params = @{}
        $script:ControlParams = @('WhatIf', 'Silent')
        $script:Features = @{ DisableTelemetry = [PSCustomObject]@{ Label = 'Disable telemetry' }; CreateRestorePoint = [PSCustomObject]@{ Label = 'Create restore point' } }
        $script:SelectedApps = @('One.App', 'Two.App')
        $script:SavedSettingsFilePath = 'C:\Settings\LastUsedSettings.json'
        $script:DefaultSettingsFilePath = 'C:\Settings\DefaultSettings.json'
        $script:InputQueue = @()
        $script:InputIndex = 0
        $script:Silent = $false
        $script:RunDefaults = $false
        $script:RunDefaultsLite = $false
        Mock Clear-Host {}
        Mock Write-Host {}
        Mock Write-Output {}
        Mock Read-Host { $script:InputQueue[$script:InputIndex++] }
        Mock Get-UserName { 'Alice' }
        Mock Generate-AppsList { @('One.App', 'Two.App') }
        Mock Add-Parameter {}
        Mock Save-Settings {}
        Mock Import-Settings {}
        Mock Show-AppSelectionWindow { $true }
        Mock Test-Path { $true }
    }

    It 'prints user or Sysprep context in the CLI header' {
        $script:Params = @{}
        Write-CliHeader -title 'Menu'
        $script:Params = @{ Sysprep = $true }
        Write-CliHeader -title 'Menu'

        Should -Invoke Write-Host -Times 6 -Exactly
        Should -Invoke Get-UserName -Times 1 -Exactly
    }

    It 'summarizes selected features and app removal before confirmation' {
        $script:Params = @{ DisableTelemetry = $true; RemoveApps = $true; Apps = 'Default' }
        $script:ControlParams = @('WhatIf', 'Silent', 'Apps')
        $script:InputQueue = @('')

        Write-PendingChanges

        Should -Invoke Generate-AppsList -Times 1 -Exactly
        Should -Invoke Read-Host -Times 1 -Exactly
        Should -Invoke Write-Output -Times 2 -ParameterFilter { $InputObject -like '- *' }
    }

    It 'returns the saved-settings menu option only when the file is available' {
        $script:InputQueue = @('3')

        Show-CliMenuOptions | Should -Be '3'
        Should -Invoke Test-Path -Times 2 -Exactly
    }

    It 're-prompts after a cancelled manual app selection and accepts no removal' {
        Mock Show-AppSelectionWindow { $false }
        $script:InputQueue = @('2', 'n')

        Show-CliDefaultModeAppRemovalOptions | Should -Be 'n'
        Should -Invoke Show-AppSelectionWindow -Times 1 -Exactly
        Should -Invoke Read-Host -Times 2 -Exactly
    }

    It 'records selected app removal and skips confirmation in silent mode' {
        $script:Silent = $true

        Show-CliAppRemoval

        Should -Invoke Add-Parameter -Times 1 -Exactly -ParameterFilter { $Name -eq 'RemoveApps' }
        Should -Invoke Add-Parameter -Times 1 -Exactly -ParameterFilter { $Name -eq 'Apps' -and $Value -eq 'One.App,Two.App' }
        Should -Invoke Save-Settings -Times 1 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'loads saved settings without prompting in silent mode' {
        $script:Silent = $true

        Show-CliLastUsedSettings

        Should -Invoke Import-Settings -Times 1 -Exactly -ParameterFilter { $filePath -eq $script:SavedSettingsFilePath -and $expectedVersion -eq '1.0' }
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'applies default app-removal parameters for the RunDefaults switch' {
        $script:RunDefaults = $true
        $script:Silent = $true

        Show-CliDefaultModeOptions

        Should -Invoke Add-Parameter -Times 1 -Exactly -ParameterFilter { $Name -eq 'RemoveApps' }
        Should -Invoke Add-Parameter -Times 1 -Exactly -ParameterFilter { $Name -eq 'Apps' -and $Value -eq 'Default' }
        Should -Invoke Import-Settings -Times 1 -Exactly
    }
}
