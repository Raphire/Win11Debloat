BeforeAll {
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) }
    function New-WingetTestJob { Microsoft.PowerShell.Core\Start-Job -ScriptBlock {} }

    . (Join-Path $PSScriptRoot '..\Scripts\AppRemoval\Get-WingetInstalledApps.ps1')
}

Describe 'Get-WingetInstalledApps' {
    BeforeEach {
        $script:WingetInstalled = $true
        $script:WingetTestJob = $null
        Mock Remove-Job {}
    }

    AfterEach {
        if ($null -ne $script:WingetTestJob) {
            Microsoft.PowerShell.Core\Remove-Job -Job $script:WingetTestJob -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns null without starting a job when winget is unavailable' {
        $script:WingetInstalled = $false
        Mock Start-Job { throw 'Winget should not be started.' }

        Get-WingetInstalledApps | Should -BeNullOrEmpty

        Should -Invoke Start-Job -Times 0 -Exactly
    }

    It 'delegates to the non-blocking runner when requested' {
        Mock Invoke-NonBlocking { @([PSCustomObject]@{ Name = 'App'; Id = 'Contoso.App' }) }

        $result = @(Get-WingetInstalledApps -NonBlocking)

        $result | Should -HaveCount 1
        $result[0].Id | Should -Be 'Contoso.App'
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly
    }

    It 'returns an empty collection when winget output has no table separator' {
        $script:WingetTestJob = New-WingetTestJob
        Mock Start-Job { $script:WingetTestJob }
        Mock Wait-Job { $script:WingetTestJob }
        Mock Receive-Job { @('Name  Id', 'No parseable table') }

        @(Get-WingetInstalledApps) | Should -BeNullOrEmpty
        Should -Invoke Remove-Job -Times 1 -Exactly -ParameterFilter { -not $Force }
    }

    It 'parses valid rows and skips malformed rows' {
        $script:WingetTestJob = New-WingetTestJob
        Mock Start-Job { $script:WingetTestJob }
        Mock Wait-Job { $script:WingetTestJob }
        Mock Receive-Job {
            @(
                'Name                              Id                              Version'
                '-----------------------------------------------------------------------'
                'Contoso App                       Contoso.App                     1.0'
                'malformed-row'
                'Fabrikam Tools                    Fabrikam.Tools                  2.0'
            )
        }

        $result = @(Get-WingetInstalledApps)

        $result | Should -HaveCount 2
        $result.Id | Should -Be @('Contoso.App', 'Fabrikam.Tools')
    }

    It 'parses localized headers and long Unicode display names' {
        $script:WingetTestJob = New-WingetTestJob
        Mock Start-Job { $script:WingetTestJob }
        Mock Wait-Job { $script:WingetTestJob }
        Mock Receive-Job {
            @(
                'Naam                              Id                              Versie'
                '-----------------------------------------------------------------------'
                'Contoso hulpmiddel voor gegevens    Contoso.DataTools                2026.07'
                'Fabrikam Café                      Fabrikam.Cafe                   1.0'
            )
        }

        $result = @(Get-WingetInstalledApps)

        $result | Should -HaveCount 2
        $result[0].Name | Should -Be 'Contoso hulpmiddel voor gegevens'
        $result.Id | Should -Be @('Contoso.DataTools', 'Fabrikam.Cafe')
    }

    It 'returns null and force-removes the job when winget times out' {
        $script:WingetTestJob = New-WingetTestJob
        Mock Start-Job { $script:WingetTestJob }
        Mock Wait-Job { $null }

        Get-WingetInstalledApps | Should -BeNullOrEmpty

        Should -Invoke Remove-Job -Times 1 -Exactly -ParameterFilter { $Force }
    }
}
