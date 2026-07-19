BeforeAll {
    function Get-TargetUserForAppRemoval { 'AllUsers' }
    function Get-WingetInstalledApps { param($TimeOut, [switch]$NonBlocking) @() }
    function Test-AppInWingetList { param($appId, $InstalledList) $false }
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) }
    function Get-UserName { 'Alice' }
    function Invoke-ForceRemoveEdge {}
    function Show-MessageBox { 'No' }
    function Invoke-WithTargetUserHive { param($TargetUserName, $ScriptBlock, $ArgumentObject) }
    function Invoke-RegistryOperation { param($Operation, $RegFilePath) }

    . (Join-Path $PSScriptRoot '..\Scripts\AppRemoval\Remove-SelectedApps.ps1')
}

Describe 'Remove-SelectedApps' {
    BeforeEach {
        $script:Params = @{}
        $script:CancelRequested = $false
        $script:ApplySubStepCallback = $null
        $script:WingetInstalled = $true
        Mock Get-TargetUserForAppRemoval { 'AllUsers' }
        Mock Get-AppRemovalMethod { 'Appx' }
        Mock Remove-WinGetApp {}
        Mock Remove-AppxApp {}
        Mock Test-AppStillInstalled { $false }
        Mock Get-WingetInstalledApps { @() }
        Mock Request-EdgeForceRemove {}
        Mock Write-Host {}
    }

    It 'honors WhatIf without invoking either removal backend' {
        $script:Params = @{ WhatIf = $true }
        Remove-SelectedApps -appsList @('One.App', 'Two.App')
        Should -Invoke Remove-WinGetApp -Times 0 -Exactly
        Should -Invoke Remove-AppxApp -Times 0 -Exactly
        Should -Invoke Write-Host -Times 2 -Exactly -ParameterFilter { $Object -like '*WhatIf*Remove App*' }
    }

    It 'dispatches each app to its configured backend and target scope' {
        Mock Get-AppRemovalMethod { param($appId) if ($appId -eq 'Winget.App') { 'WinGet' } else { 'Appx' } }
        Remove-SelectedApps -appsList @('Winget.App', 'Appx.App')
        Should -Invoke Remove-WinGetApp -Times 1 -Exactly -ParameterFilter { $app -eq 'Winget.App' }
        Should -Invoke Remove-AppxApp -Times 1 -Exactly -ParameterFilter { $app -eq 'Appx.App' -and $targetUser -eq 'AllUsers' }
    }

    It 'stops before the first removal when cancellation is requested' {
        $script:CancelRequested = $true
        Remove-SelectedApps -appsList @('One.App')
        Should -Invoke Remove-WinGetApp -Times 0 -Exactly
        Should -Invoke Remove-AppxApp -Times 0 -Exactly
    }

    It 'prompts for forced Edge removal at most once after failed winget removals' {
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Test-AppStillInstalled { $true }
        Remove-SelectedApps -appsList @('Microsoft.Edge', 'XPFFTQ037JWMHS')
        Should -Invoke Request-EdgeForceRemove -Times 1 -Exactly
    }
}

Describe 'Get-AppRemovalMethod' {
    BeforeEach {
        $script:AppRemovalMethodCache = $null
        $script:AppsListFilePath = Join-Path $TestDrive 'Apps.json'
    }

    It 'caches aliases and skips malformed IDs' {
        '{"Apps":[{"AppId":[" One.App ","Alias.App"],"RemovalMethod":"WinGet"},{"AppId":null},{"AppId":42},{"AppId":"Two.App"}]}' |
            Set-Content -LiteralPath $script:AppsListFilePath -Encoding UTF8

        Get-AppRemovalMethod -appId 'One.App' | Should -Be 'WinGet'
        Get-AppRemovalMethod -appId 'Alias.App' | Should -Be 'WinGet'
        Get-AppRemovalMethod -appId 'Two.App' | Should -Be 'Appx'
        Get-AppRemovalMethod -appId 'Unknown.App' | Should -Be 'Appx'
    }

    It 'warns and defaults to Appx when the catalog is malformed' {
        'not json' | Set-Content -LiteralPath $script:AppsListFilePath
        Mock Write-Warning {}
        Get-AppRemovalMethod -appId 'Unknown.App' | Should -Be 'Appx'
        Should -Invoke Write-Warning -Times 1 -Exactly
    }
}

Describe 'Remove-WinGetApp' {
    BeforeEach {
        $script:Params = @{}
        $script:WingetInstalled = $true
        Mock Invoke-NonBlocking {}
        Mock Set-RunOnceWingetTask {}
        Mock Get-UserName { 'Alice' }
        Mock Write-Host {}
    }

    It 'reports unavailable winget without invoking or scheduling removal' {
        $script:WingetInstalled = $false
        Remove-WinGetApp -app 'One.App'
        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
        Should -Invoke Set-RunOnceWingetTask -Times 0 -Exactly
    }

    It 'schedules removal only for explicit user or Sysprep targets' -ForEach @(
        @{ Params = @{}; Scheduled = 0 }
        @{ Params = @{ User = 'Alice' }; Scheduled = 1 }
        @{ Params = @{ Sysprep = $true }; Scheduled = 1 }
    ) {
        $script:Params = $Params
        Remove-WinGetApp -app 'One.App'
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter { $ArgumentList -eq 'One.App' }
        Should -Invoke Set-RunOnceWingetTask -Times $Scheduled -Exactly -ParameterFilter { $appId -eq 'One.App' }
    }
}

Describe 'Remove-AppxApp' {
    BeforeEach { Mock Invoke-NonBlocking {} }

    It 'passes the wildcard and target user data for <Target>' -ForEach @(
        @{ Target = 'AllUsers'; ExpectedArguments = 1 }
        @{ Target = 'CurrentUser'; ExpectedArguments = 1 }
        @{ Target = 'Alice'; ExpectedArguments = 2 }
    ) {
        Remove-AppxApp -app 'One.App' -targetUser $Target
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter {
            @($ArgumentList).Count -eq $ExpectedArguments -and @($ArgumentList)[0] -eq '*One.App*' -and
            ($ExpectedArguments -eq 1 -or @($ArgumentList)[1] -eq 'Alice')
        }
    }
}

Describe 'Test-AppStillInstalled' {
    BeforeEach {
        $script:WingetInstalled = $true
        Mock Get-AppxPackage { $null }
        Mock Test-AppInWingetList { $false }
        Mock Get-WingetInstalledApps { @() }
        Mock Write-Warning {}
    }

    It 'prefers all-user Appx detection and avoids winget lookup' {
        Mock Get-AppxPackage { [PSCustomObject]@{ Name = 'One.App' } }
        Test-AppStillInstalled -appId 'One.App' | Should -BeTrue
        Should -Invoke Get-AppxPackage -Times 1 -Exactly -ParameterFilter { $AllUsers }
        Should -Invoke Get-WingetInstalledApps -Times 0 -Exactly
    }

    It 'uses a supplied winget list without launching a live query' {
        Mock Test-AppInWingetList { $true }
        Test-AppStillInstalled -appId 'One.App' -InstalledList @([PSCustomObject]@{ Id = 'One.App' }) | Should -BeTrue
        Should -Invoke Get-WingetInstalledApps -Times 0 -Exactly
    }

    It 'warns when a non-Appx app cannot be verified without winget' {
        $script:WingetInstalled = $false
        Test-AppStillInstalled -appId 'One.App' | Should -BeFalse
        Should -Invoke Write-Warning -Times 1 -Exactly
    }
}

Describe 'Set-RunOnceWingetTask' {
    BeforeEach {
        $script:Params = @{ User = 'Alice' }
        Mock Invoke-WithTargetUserHive {
            param($TargetUserName, $ScriptBlock, $ArgumentObject)
            & $ScriptBlock $ArgumentObject
        }
        $script:runOnceOperation = $null
        Mock Invoke-RegistryOperation {
            param($Operation)
            $script:runOnceOperation = $Operation
        }
    }

    It 'encodes shell metacharacters and writes a safe RunOnce operation' {
        Set-RunOnceWingetTask -appId "Vendor.App&'Test"
        Should -Invoke Invoke-WithTargetUserHive -Times 1 -Exactly -ParameterFilter { $TargetUserName -eq 'Alice' }
        Should -Invoke Invoke-RegistryOperation -Times 1 -Exactly -ParameterFilter {
            $Operation.ValueName -eq "Uninstall_Vendor.App&'Test" -and
            $RegFilePath -eq '<dynamic>'
        }

        $script:runOnceOperation.ValueData | Should -Match '^powershell\.exe -NoProfile -EncodedCommand [A-Za-z0-9+/=]+$'
        $encodedCommand = $script:runOnceOperation.ValueData -replace '^powershell\.exe -NoProfile -EncodedCommand ', ''
        $decodedCommand = [System.Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encodedCommand))
        $decodedCommand | Should -Be "winget uninstall --accept-source-agreements --disable-interactivity --id 'Vendor.App&''Test'"
    }
}
