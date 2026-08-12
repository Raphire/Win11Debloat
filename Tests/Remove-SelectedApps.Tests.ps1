BeforeAll {
    function Get-TargetUserForAppRemoval { 'AllUsers' }
    function Get-WingetInstalledApps { param($TimeOut, [switch]$NonBlocking) return ,@() }
    function Test-AppInWingetList { param($appId, $InstalledList) $false }
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList, $TimeoutSeconds) }
    function Get-UserName { 'Alice' }
    function Invoke-ForceRemoveEdge {}
    function Show-MessageBox { 'No' }
    function Invoke-WithTargetUserHive { param($TargetUserName, $ScriptBlock, $ArgumentObject) }
    function Invoke-RegistryOperation { param($Operation, $RegFilePath) }
    function Resolve-UserProfileContext { param($UserName) $null }

    . (Join-Path $PSScriptRoot '..\Scripts\AppRemoval\Remove-SelectedApps.ps1')
}

Describe 'Remove-SelectedApps' {
    BeforeEach {
        $script:Params = @{}
        $script:CancelRequested = $false
        $script:ApplySubStepCallback = $null
        $script:WingetInstalled = $true
        $script:AppRemovalFailures = 0
        $script:AppRemovalVerificationUnavailable = $false
        Mock Get-TargetUserForAppRemoval { 'AllUsers' }
        Mock Get-AppRemovalMethod { 'Appx' }
        Mock Remove-WinGetApp { $true }
        Mock Remove-AppxApp { $true }
        Mock Test-AppInWingetList { $false }
        Mock Get-WingetInstalledApps { return ,@() }
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

    It 'verifies WinGet removals against the fetched Winget list' {
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Get-WingetInstalledApps { return ,@([PSCustomObject]@{ Id = 'Other.App' }) }
        Remove-SelectedApps -appsList @('Winget.App')
        Should -Invoke Test-AppInWingetList -Times 1 -Exactly -ParameterFilter { $appId -eq 'Winget.App' -and $InstalledList[0].Id -eq 'Other.App' }
    }

    It 'stops before the first removal when cancellation is requested' {
        $script:CancelRequested = $true
        Remove-SelectedApps -appsList @('One.App')
        Should -Invoke Remove-WinGetApp -Times 0 -Exactly
        Should -Invoke Remove-AppxApp -Times 0 -Exactly
    }

    It 'counts failed Appx removals and reports them' {
        Mock Remove-AppxApp { $false }

        Remove-SelectedApps -appsList @('One.App')

        $script:AppRemovalFailures | Should -Be 1
    }

    It 'counts a failed WinGet removal' {
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Remove-WinGetApp { $false }

        Remove-SelectedApps -appsList @('One.App')

        $script:AppRemovalFailures | Should -Be 1
    }

    It 'counts a WinGet removal that remains installed after a successful command' {
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Test-AppInWingetList { $true }

        Remove-SelectedApps -appsList @('One.App')

        $script:AppRemovalFailures | Should -Be 1
    }

    It 'records an unavailable WinGet inventory as an unverified removal' {
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Get-WingetInstalledApps { $null }

        Remove-SelectedApps -appsList @('One.App')

        $script:AppRemovalVerificationUnavailable | Should -BeTrue
        Should -Invoke Test-AppInWingetList -Times 0 -Exactly
    }

    It 'prompts for forced Edge removal at most once after failed winget removals' {
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Test-AppInWingetList { $true }
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
        Mock Invoke-NonBlocking { $true }
        Mock Set-RunOnceWingetTask { $true }
        Mock Get-UserName { 'Alice' }
        Mock Write-Host {}
        Mock Write-Error {}
    }

    It 'reports unavailable winget without invoking or scheduling removal' {
        $script:WingetInstalled = $false
        Remove-WinGetApp -app 'One.App' | Should -BeFalse
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

    It 'limits a foreground winget uninstall to two minutes' {
        Remove-WinGetApp -app 'One.App'
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter {
            $ArgumentList -eq 'One.App' -and $TimeoutSeconds -eq 120
        }
    }

    It 'passes a specified foreground winget uninstall timeout' {
        Remove-WinGetApp -app 'One.App' -TimeoutSeconds 30
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter {
            $ArgumentList -eq 'One.App' -and $TimeoutSeconds -eq 30
        }
    }

    It 'reports a timed-out winget uninstall and continues' {
        $script:Params = @{ User = 'Alice' }
        Mock Invoke-NonBlocking { throw 'Operation timed out after 120 seconds' }

        { Remove-WinGetApp -app 'One.App' } | Should -Not -Throw
        Should -Invoke Set-RunOnceWingetTask -Times 1 -Exactly
        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter {
            $Message -like '*did not complete within 120 seconds*'
        }
    }

}

Describe 'Remove-AppxApp' {
    BeforeEach { Mock Invoke-NonBlocking { [PSCustomObject]@{ Success = $true } } }

    It 'passes the wildcard and target user data for <Target>' -ForEach @(
        @{ Target = 'AllUsers' }
        @{ Target = 'CurrentUser' }
        @{ Target = 'Alice' }
    ) {
        Remove-AppxApp -app 'One.App' -targetUser $Target
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter {
            @($ArgumentList).Count -eq 2 -and @($ArgumentList)[0] -eq '*One.App*' -and @($ArgumentList)[1] -eq $Target
        }
    }

    It 'returns false when package discovery reports a non-terminating error' {
        Mock Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
        Mock Get-AppxPackage { Write-Error 'access denied' }

        Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' | Should -BeFalse
    }

    It 'returns false when package removal reports a non-terminating error' {
        Mock Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
        Mock Get-AppxPackage { [PSCustomObject]@{ PackageFullName = 'One.App_1.0' } }
        Mock Remove-AppxPackage { Write-Error 'access denied' }

        Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' | Should -BeFalse
    }

    It 'returns false and reports a terminating Appx failure' {
        Mock Invoke-NonBlocking { throw 'access denied' }
        Mock Write-Error {}

        Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' | Should -BeFalse
        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter {
            $Message -like '*Unable to remove One.App via Appx*access denied*'
        }
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
