BeforeAll {
    $wingetListScriptPath = Join-Path $PSScriptRoot '..\Scripts\AppRemoval\Test-AppInWingetList.ps1'
    . $wingetListScriptPath
}

Describe 'Test-AppInWingetList' {
    BeforeAll {
        $installedApps = @(
            [PSCustomObject]@{ Id = 'Microsoft.Copilot' }
            [PSCustomObject]@{ Id = 'Microsoft.EdgeDev' }
            [PSCustomObject]@{ Id = 'Contoso.Music-Player' }
        )
    }

    It 'matches an exact winget ID' {
        Test-AppInWingetList -appId 'Microsoft.Copilot' -InstalledList $installedApps | Should -BeTrue
    }

    It '<Case>' -ForEach @(
        @{ Case = 'matches a delimited substring'; AppId = 'Music'; Expected = $true }
        @{ Case = 'does not match an alphanumeric continuation'; AppId = 'Microsoft.Edge'; Expected = $false }
    ) {
        Test-AppInWingetList -appId $AppId -InstalledList $installedApps | Should -Be $Expected
    }

    It 'returns false for <Case>' -ForEach @(
        @{ Case = 'an empty installed-app list'; AppId = 'Microsoft.Copilot'; InstalledList = @() }
        @{ Case = 'an app that is not installed'; AppId = 'Missing.App'; InstalledList = $null }
    ) {
        $list = if ($null -eq $InstalledList) { $installedApps } else { $InstalledList }
        Test-AppInWingetList -appId $AppId -InstalledList $list | Should -BeFalse
    }
}
