BeforeAll {
    function Get-TargetUserForAppRemoval { 'AllUsers' }
    function Get-WingetInstalledApps { param($TimeOut, [switch]$NonBlocking) return ,@() }
    function Test-AppInWingetList { param($appId, $InstalledList) $false }
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList, $TimeoutSeconds) }
    function Get-UserName { 'Alice' }
    function Get-Translation { param($Key, $FormatArgs) if ($FormatArgs) { return "$Key $($FormatArgs -join ' ')" }; return $Key }
    function Invoke-ForceRemoveEdge {}
    function Show-MessageBox { 'No' }
    function Invoke-WithTargetUserHive { param($TargetUserName, $ScriptBlock, $ArgumentObject) }
    function Invoke-RegistryOperation { param($Operation, $RegFilePath) }
    function Resolve-UserProfileContext { param($UserName) $null }

    . (Join-Path $PSScriptRoot '..\Scripts\AppRemoval\Remove-SelectedApps.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\AppRemoval\Invoke-ForceRemoveEdge.ps1')
}

Describe 'Remove-SelectedApps' {
    BeforeEach {
        $script:Params = @{}
        $script:CancelRequested = $false
        $script:ApplySubStepCallback = $null
        $script:WingetInstalled = $true
        $script:WingetDeferredRemovals = @{}
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

    It 'skips immediate inventory verification for a deferred WinGet uninstall' {
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Remove-WinGetApp {
            $script:WingetDeferredRemovals[$app] = 'Alice'
            return $true
        }

        Remove-SelectedApps -appsList @('Winget.App') | Should -BeTrue

        Should -Invoke Get-WingetInstalledApps -Times 0 -Exactly
    }

    It 'skips an already deferred app within a list and across removal calls' {
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Remove-WinGetApp {
            $script:WingetDeferredRemovals[$app] = 'Alice'
            return $true
        }

        Remove-SelectedApps -appsList @('One.App', 'One.App') | Should -BeTrue
        Remove-SelectedApps -appsList @('One.App') | Should -BeTrue

        Should -Invoke Remove-WinGetApp -Times 1 -Exactly -ParameterFilter { $app -eq 'One.App' }
        Should -Invoke Get-WingetInstalledApps -Times 0 -Exactly
        $script:WingetDeferredRemovals['One.App'] | Should -Be 'Alice'
        $script:AppRemovalFailures | Should -Be 0
    }

    It 'continues removing and verifying other apps while preserving deferrals' {
        $script:WingetDeferredRemovals = @{ 'One.App' = 'Alice'; 'Other.App' = 'Bob' }
        Mock Get-AppRemovalMethod { 'WinGet' }

        Remove-SelectedApps -appsList @('One.App', 'New.App') | Should -BeTrue

        Should -Invoke Remove-WinGetApp -Times 1 -Exactly -ParameterFilter { $app -eq 'New.App' }
        Should -Invoke Test-AppInWingetList -Times 1 -Exactly -ParameterFilter { $appId -eq 'New.App' }
        $script:WingetDeferredRemovals['One.App'] | Should -Be 'Alice'
        $script:WingetDeferredRemovals['Other.App'] | Should -Be 'Bob'
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
        Mock Test-AppInWingetList { $true }
        Mock Write-Host {}

        Remove-SelectedApps -appsList @('One.App')

        $script:AppRemovalFailures | Should -Be 1
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -eq 'Unable to uninstall One.App via WinGet' -and $ForegroundColor -eq 'Red' }
    }

    It 'does not count a non-zero WinGet command when the app is absent after verification' {
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Remove-WinGetApp { $false }
        Mock Test-AppInWingetList { $false }

        Remove-SelectedApps -appsList @('One.App') | Should -BeTrue

        $script:AppRemovalFailures | Should -Be 0
    }

    It 'counts a failed WinGet scheduling result for a target user' {
        $script:Params = @{ User = 'Alice' }
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Remove-WinGetApp { $false }
        Mock Test-AppInWingetList { $false }

        Remove-SelectedApps -appsList @('One.App') | Should -BeFalse

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

    It 'resolves WinGet removal for non-ASCII IDs from BOM-less UTF-8 JSON' {
        $appId = 'Test.' + [char]0x00E9 + [char]0x4E2D + [char]0x0416
        $json = @{ Apps = @(@{ AppId = $appId; RemovalMethod = 'WinGet' }) } | ConvertTo-Json -Depth 4
        [System.IO.File]::WriteAllText($script:AppsListFilePath, $json, [System.Text.UTF8Encoding]::new($false))

        Get-AppRemovalMethod -appId $appId | Should -Be 'WinGet'
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
        $script:WingetDeferredRemovals = @{}
        Mock Invoke-NonBlocking { [PSCustomObject]@{ Success = $true; ExitCode = 0; Output = @() } }
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

    It 'defers a user-scope uninstall when WinGet returns the administrator-context error code' {
        $script:Params = @{ AppRemovalTarget = 'CurrentUser' }
        Mock Get-TargetUserForAppRemoval { 'CurrentUser' }
        Mock Invoke-NonBlocking { [PSCustomObject]@{ ExitCode = -1978335107; Output = @('localized WinGet error') } }

        Remove-WinGetApp -app 'One.App' | Should -BeTrue

        Should -Invoke Set-RunOnceWingetTask -Times 1 -Exactly -ParameterFilter {
            $appId -eq 'One.App'
        }
        $script:WingetDeferredRemovals['One.App'] | Should -Be 'Alice'
    }

    It 'reports a timed-out winget uninstall and continues' {
        $script:Params = @{ User = 'Alice' }
        Mock Invoke-NonBlocking { throw 'Operation timed out after 120 seconds' }

        Remove-WinGetApp -app 'One.App' | Should -BeFalse
        Should -Invoke Set-RunOnceWingetTask -Times 1 -Exactly
        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter {
            $Message -like 'WinGet uninstall for One.App did not complete within 120 seconds:*Operation timed out after 120 seconds*'
        }
    }

    It 'returns true and logs WinGet output regardless of exit code' -ForEach @(
        @{ ExitCode = 0; Output = 'Successfully uninstalled One.App' }
        @{ ExitCode = 1; Output = 'Package was not found' }
        @{ ExitCode = -1978335212; Output = 'No installed package found matching input criteria.' }
    ) {
        $script:expectedExitCode = $ExitCode
        $script:expectedOutput = $Output
        Mock Invoke-NonBlocking { [PSCustomObject]@{ ExitCode = $script:expectedExitCode; Output = @($script:expectedOutput) } }
        Mock Write-Verbose {}

        Remove-WinGetApp -app 'One.App' | Should -BeTrue

        Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter { $Message -eq $script:expectedOutput }
        Should -Invoke Write-Verbose -Times 1 -Exactly -ParameterFilter { $Message -eq "WinGet uninstall for One.App returned exit code $script:expectedExitCode." }
    }

    It 'returns the RunOnce scheduling result for a target user' {
        $script:Params = @{ User = 'Alice' }
        Mock Invoke-NonBlocking { [PSCustomObject]@{ ExitCode = 1; Output = @() } }
        Mock Set-RunOnceWingetTask { $false }

        Remove-WinGetApp -app 'One.App' | Should -BeFalse
    }

}

Describe 'Remove-EdgeAutostartValue' {
    BeforeEach {
        Mock Write-Warning {}
    }

    It 'treats a missing value as already cleaned up' {
        Mock Get-ItemProperty { [PSCustomObject]@{} }
        Mock Remove-ItemProperty {}

        Remove-EdgeAutostartValue -Path 'HKCU:\Software\Example' -Name 'Microsoft Edge Update' | Should -BeTrue

        Should -Invoke Remove-ItemProperty -Times 0 -Exactly
    }

    It 'treats a missing registry key as already cleaned up' {
        Mock Get-ItemProperty { throw [System.Management.Automation.ItemNotFoundException]::new('not found') }
        Mock Remove-ItemProperty {}

        Remove-EdgeAutostartValue -Path 'HKCU:\Software\Example' -Name 'Microsoft Edge Update' | Should -BeTrue

        Should -Invoke Remove-ItemProperty -Times 0 -Exactly
    }

    It 'removes an existing value' {
        Mock Get-ItemProperty { [PSCustomObject]@{ 'Microsoft Edge Update' = 'enabled' } }
        Mock Remove-ItemProperty {}

        Remove-EdgeAutostartValue -Path 'HKCU:\Software\Example' -Name 'Microsoft Edge Update' | Should -BeTrue

        Should -Invoke Remove-ItemProperty -Times 1 -Exactly -ParameterFilter { $Path -eq 'HKCU:\Software\Example' -and $Name -eq 'Microsoft Edge Update' }
    }

    It 'returns false when an existing value cannot be removed' {
        Mock Get-ItemProperty { [PSCustomObject]@{ 'Microsoft Edge Update' = 'enabled' } }
        Mock Remove-ItemProperty { throw 'access denied' }

        Remove-EdgeAutostartValue -Path 'HKCU:\Software\Example' -Name 'Microsoft Edge Update' | Should -BeFalse

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match 'access denied' }
    }

    It 'returns false when the registry key cannot be inspected' {
        Mock Get-ItemProperty { throw 'access denied' }

        Remove-EdgeAutostartValue -Path 'HKCU:\Software\Example' -Name 'Microsoft Edge Update' | Should -BeFalse

        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match 'access denied' }
    }
}

Describe 'Remove-AppxApp' {
    BeforeEach {
        $script:WinVersion = 26100
        Mock Invoke-NonBlocking { [PSCustomObject]@{ Success = $true } }
        Mock Write-Host {}
        Mock Write-Warning {}
    }

    It 'passes the wildcard and target user data for <Target>' -ForEach @(
        @{ Target = 'AllUsers' }
        @{ Target = 'CurrentUser' }
        @{ Target = 'Alice' }
    ) {
        Remove-AppxApp -app 'One.App' -targetUser $Target
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter {
            @($ArgumentList).Count -eq 3 -and @($ArgumentList)[0] -eq '*One.App*' -and @($ArgumentList)[1] -eq $Target -and @($ArgumentList)[2] -eq $false
        }
    }

    It 'returns false when package discovery reports a non-terminating error' {
        Mock Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
        Mock Get-AppxPackage { Write-Error 'access denied' }

        Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' 2>$null | Should -BeFalse
    }

    It 'returns false when package removal reports a non-terminating error' {
        Mock Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
        Mock Get-AppxPackage { [PSCustomObject]@{ PackageFullName = 'One.App_1.0' } }
        Mock Remove-AppxPackage { Write-Error 'access denied' }

        Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' 2>$null | Should -BeFalse
    }

    It 'returns false and reports a terminating Appx failure' {
        Mock Invoke-NonBlocking { throw 'access denied' }
        Mock Write-Error {}

        Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' | Should -BeFalse
        Should -Invoke Write-Error -Times 1 -Exactly -ParameterFilter {
            $Message -like '*Unable to remove One.App via Appx*access denied*'
        }
    }

    It 'handles <Operation> error <Code> on build <Build> with success <Expected>' -ForEach @(
        @{ Operation = 'Appx'; Code = '0x80070002'; Build = 19045; Expected = $true }
        @{ Operation = 'Provisioned'; Code = '0x80070002'; Build = 19045; Expected = $true }
        @{ Operation = 'Appx'; Code = '0x80070002'; Build = 22000; Expected = $false }
        @{ Operation = 'Provisioned'; Code = '0x80070002'; Build = 26100; Expected = $false }
        @{ Operation = 'Appx'; Code = '0x80070005'; Build = 19045; Expected = $false }
        @{ Operation = 'Provisioned'; Code = '0x80070005'; Build = 19045; Expected = $false }
        @{ Operation = 'Appx'; Code = '0x80070002'; Build = $null; Expected = $false }
    ) {
        $script:WinVersion = $Build
        Mock Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
        Mock Get-AppxPackage { [PSCustomObject]@{ PackageFullName = 'One.App_1.0' } }
        Mock Get-AppxProvisionedPackage { [PSCustomObject]@{ PackageName = 'One.App_1.0' } }
        Mock Get-AppxPackage {} -ParameterFilter { $ErrorAction -eq 'Stop' }
        Mock Get-AppxProvisionedPackage {} -ParameterFilter { $ErrorAction -eq 'Stop' }
        Mock Remove-AppxPackage {}
        Mock Remove-ProvisionedAppxPackage {}
        if ($Operation -eq 'Appx') {
            Mock Remove-AppxPackage { Write-Error "Deployment failed with HRESULT: $Code" }
        }
        else {
            Mock Remove-ProvisionedAppxPackage { Write-Error "Deployment failed with HRESULT: $Code" }
        }

        $output = @(Remove-AppxApp -app 'One.App' -targetUser 'AllUsers' 2>&1)

        $output[-1] | Should -Be $Expected
        @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should -Be $(if ($Expected) { 0 } else { 1 })
        Should -Invoke Write-Host -Times $(if ($Expected) { 1 } else { 0 }) -Exactly -ParameterFilter {
            $Object -eq 'Windows 10 Appx removal reported error 0x80070002 for One.App_1.0, but the removal succeeded.'
        }
    }

    It 'recognizes a Windows 10 removal HRESULT without relying on English error text' {
        $script:WinVersion = 19045
        Mock Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
        Mock Get-AppxPackage { [PSCustomObject]@{ PackageFullName = 'One.App_1.0' } }
        Mock Get-AppxPackage {} -ParameterFilter { $ErrorAction -eq 'Stop' }
        Mock Remove-AppxPackage { throw [System.Runtime.InteropServices.COMException]::new('Localized message', -2147024894) }

        $output = @(Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' 2>&1)

        $output | Should -HaveCount 1
        $output[0] | Should -BeTrue
    }

    It 'verifies <Operation> removal for <Target> when the query reports <State>' -ForEach @(
        @{ Operation = 'Appx'; Target = 'CurrentUser'; State = 'Absent' }
        @{ Operation = 'Appx'; Target = 'CurrentUser'; State = 'Present' }
        @{ Operation = 'Appx'; Target = 'CurrentUser'; State = 'QueryError' }
        @{ Operation = 'Appx'; Target = 'AllUsers'; State = 'Absent' }
        @{ Operation = 'Appx'; Target = 'AllUsers'; State = 'Present' }
        @{ Operation = 'Appx'; Target = 'AllUsers'; State = 'QueryError' }
        @{ Operation = 'Appx'; Target = 'NamedUser'; State = 'Absent' }
        @{ Operation = 'Appx'; Target = 'NamedUser'; State = 'Present' }
        @{ Operation = 'Appx'; Target = 'NamedUser'; State = 'QueryError' }
        @{ Operation = 'Provisioned'; Target = 'AllUsers'; State = 'Absent' }
        @{ Operation = 'Provisioned'; Target = 'AllUsers'; State = 'Present' }
        @{ Operation = 'Provisioned'; Target = 'AllUsers'; State = 'QueryError' }
    ) {
        $script:WinVersion = 19045
        Mock Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
        Mock Get-AppxPackage {
            if ($Operation -eq 'Appx') { [PSCustomObject]@{ PackageFullName = 'One.App_1.0' } }
        }
        Mock Get-AppxProvisionedPackage {
            if ($Operation -eq 'Provisioned') { [PSCustomObject]@{ PackageName = 'One.App_1.0' } }
        }
        Mock Get-AppxPackage {
            if ($State -eq 'QueryError') { Write-Error 'Verification failed' }
            if ($State -eq 'Present') { [PSCustomObject]@{ PackageFullName = 'One.App_1.0' } }
            [PSCustomObject]@{ PackageFullName = 'One.App_2.0' }
        } -ParameterFilter { $ErrorAction -eq 'Stop' }
        Mock Get-AppxProvisionedPackage {
            if ($State -eq 'QueryError') { Write-Error 'Verification failed' }
            if ($State -eq 'Present') { [PSCustomObject]@{ PackageName = 'One.App_1.0' } }
            [PSCustomObject]@{ PackageName = 'One.App_2.0' }
        } -ParameterFilter { $ErrorAction -eq 'Stop' }
        Mock Remove-AppxPackage { Write-Error 'Deployment failed with HRESULT: 0x80070002' }
        Mock Remove-ProvisionedAppxPackage { Write-Error 'Deployment failed with HRESULT: 0x80070002' }

        $targetUser = $Target
        if ($Target -eq 'NamedUser') {
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $targetUser = $identity.Name
            $expectedSid = $identity.User.Value
        }
        $output = @(Remove-AppxApp -app 'One.App' -targetUser $targetUser 2>&1)

        $output[-1] | Should -Be ($State -eq 'Absent')
        $errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $errors.Count | Should -Be $(if ($State -eq 'Absent') { 0 } else { 1 })
        if ($errors.Count) { $errors[0].ToString() | Should -Match '0x80070002' }
        Should -Invoke Write-Warning -Times $(if ($State -eq 'QueryError') { 1 } else { 0 }) -Exactly
        if ($State -eq 'QueryError') {
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like '*Unable to verify removal of One.App_1.0*Verification failed*'
            }
        }
        Should -Invoke Write-Host -Times $(if ($State -eq 'Absent') { 1 } else { 0 }) -Exactly
        if ($Operation -eq 'Provisioned') {
            Should -Invoke Get-AppxProvisionedPackage -Times 1 -Exactly -ParameterFilter {
                $Online -and $ErrorAction -eq 'Stop'
            }
        }
        else {
            Should -Invoke Get-AppxPackage -Times 1 -Exactly -ParameterFilter {
                $Name -eq '*One.App*' -and $ErrorAction -eq 'Stop' -and -not $ErrorVariable -and
                (($Target -eq 'AllUsers' -and $AllUsers -and -not $User) -or
                 ($Target -eq 'CurrentUser' -and -not $AllUsers -and -not $User) -or
                 ($Target -eq 'NamedUser' -and -not $AllUsers -and $User -eq $expectedSid))
            }
        }
    }

    It 'does not ignore Windows 10 package discovery errors with the same code' {
        $script:WinVersion = 19045
        Mock Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
        Mock Get-AppxPackage { Write-Error 'Discovery failed: 0x80070002' }

        $output = @(Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' 2>&1)

        $output[-1] | Should -BeFalse
        @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) | Should -HaveCount 1
    }

    It 'preserves the error handling in a background runspace on build <Build>' -ForEach @(
        @{ Build = 19045; Expected = $true }
        @{ Build = 26100; Expected = $false }
        @{ Build = 19045; Expected = $false; VerificationFails = $true }
    ) {
        $script:WinVersion = $Build
        Mock Invoke-NonBlocking {
            param($ScriptBlock, $ArgumentList)
            $script:appxWorker = $ScriptBlock.ToString()
            $script:appxWorkerArguments = $ArgumentList
            [PSCustomObject]@{ Success = $true }
        }
        $null = Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser'
        $workerPowerShell = [powershell]::Create()
        try {
            $workerSetup = {
                param($worker, $workerArguments, $verificationFails)
                function Get-AppxPackage {
                    [CmdletBinding()] param($Name)
                    if ($script:packageRemoved -and $verificationFails) { throw 'Verification failed' }
                    if (-not $script:packageRemoved) { [PSCustomObject]@{ PackageFullName = 'One.App_1.0' } }
                }
                function Remove-AppxPackage {
                    [CmdletBinding()] param($Package)
                    $script:packageRemoved = $true
                    Write-Error 'Deployment failed with HRESULT: 0x80070002'
                }
                & ([scriptblock]::Create($worker)) @workerArguments
            }
            $null = $workerPowerShell.AddScript($workerSetup.ToString()).AddArgument($script:appxWorker).AddArgument($script:appxWorkerArguments).AddArgument([bool]$VerificationFails)
            $output = @($workerPowerShell.Invoke())

            $output[-1].Success | Should -Be $Expected
            $workerPowerShell.Streams.Error.Count | Should -Be $(if ($Expected) { 0 } else { 1 })
            @($output[-1].IgnoredRemovalMessages).Count | Should -Be $(if ($Expected) { 1 } else { 0 })
            @($output[-1].VerificationWarnings).Count | Should -Be $(if ($VerificationFails) { 1 } else { 0 })
            if ($VerificationFails) {
                $workerPowerShell.Streams.Error[0].ToString() | Should -Match '0x80070002'
                $script:appxWorkerResult = $output[-1]
                Mock Invoke-NonBlocking { $script:appxWorkerResult }
                Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' | Should -BeFalse
                Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                    $Message -like '*Unable to verify removal of One.App_1.0*Verification failed*'
                }
            }
            if ($Expected) {
                # Replay the actual worker result through the caller, where transcription runs.
                $script:appxWorkerResult = $output[-1]
                Mock Invoke-NonBlocking { $script:appxWorkerResult }
                Remove-AppxApp -app 'One.App' -targetUser 'CurrentUser' | Should -BeTrue
                Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
                    $Object -eq 'Windows 10 Appx removal reported error 0x80070002 for One.App_1.0, but the removal succeeded.'
                }
            }
        }
        finally {
            $workerPowerShell.Dispose()
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

    It 'schedules every resolved target but reports incomplete profile enumeration' {
        Mock Get-RunOnceWingetTargetUserNames {
            [PSCustomObject]@{ UserNames = @('Alice', 'Default'); Success = $false }
        }

        Set-RunOnceWingetTask -appId 'One.App' -Target ([PSCustomObject]@{ AllUsers = $true }) | Should -BeFalse

        Should -Invoke Invoke-WithTargetUserHive -Times 1 -Exactly -ParameterFilter { $TargetUserName -eq 'Alice' }
        Should -Invoke Invoke-WithTargetUserHive -Times 1 -Exactly -ParameterFilter { $TargetUserName -eq 'Default' }
    }

    It 'reports success when all profile targets are scheduled' {
        Mock Get-RunOnceWingetTargetUserNames {
            [PSCustomObject]@{ UserNames = @('Alice', 'Default'); Success = $true }
        }

        Set-RunOnceWingetTask -appId 'One.App' -Target ([PSCustomObject]@{ AllUsers = $true }) | Should -BeTrue

        Should -Invoke Invoke-WithTargetUserHive -Times 2 -Exactly
    }

    It 'continues scheduling other profiles after a hive failure and reports failure' {
        Mock Get-RunOnceWingetTargetUserNames {
            [PSCustomObject]@{ UserNames = @('Alice', 'Default'); Success = $true }
        }
        Mock Invoke-WithTargetUserHive { throw 'hive unavailable' } -ParameterFilter { $TargetUserName -eq 'Alice' }
        Mock Write-Error {}

        Set-RunOnceWingetTask -appId 'One.App' -Target ([PSCustomObject]@{ AllUsers = $true }) | Should -BeFalse

        Should -Invoke Invoke-WithTargetUserHive -Times 1 -Exactly -ParameterFilter { $TargetUserName -eq 'Default' }
    }
}

Describe 'AllUsers deferred WinGet profile enumeration' {
    BeforeEach {
        $script:Params = @{}
        $script:WingetInstalled = $true
        $script:WingetDeferredRemovals = @{}
        $script:AppRemovalFailures = 0
        $script:CancelRequested = $false
        $script:ApplySubStepCallback = $null
        Mock Get-CimInstance {
            @(
                [PSCustomObject]@{ Special = $false; SID = 'S-1-5-18'; LocalPath = 'C:\Users\Resolved' }
                [PSCustomObject]@{ Special = $false; SID = 'S-1-5-21-0-0-0-1001'; LocalPath = 'C:\Users\Unresolved' }
            )
        }
        Mock Test-Path { $true }
        Mock Write-Warning {}
        Mock Write-Host {}
        Mock Get-AppRemovalMethod { 'WinGet' }
        Mock Invoke-NonBlocking { [PSCustomObject]@{ ExitCode = -1978335107; Output = @() } }
        Mock Invoke-WithTargetUserHive {}
        Mock Get-WingetInstalledApps { return ,@() }
        Mock Test-AppInWingetList { $false }
    }

    It 'keeps resolved profiles and Default while returning a SID translation failure' {
        $result = Get-RunOnceWingetTargetUserNames

        $result.Success | Should -BeFalse
        $result.UserNames.Count | Should -Be 2
        $result.UserNames | Should -Contain 'Default'
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*S-1-5-21-0-0-0-1001*will not be scheduled*' }
    }

    It 'returns failure when profile enumeration fails' {
        Mock Get-CimInstance { throw 'enumeration failed' }
        Mock Write-Error {}

        $result = Get-RunOnceWingetTargetUserNames

        $result.Success | Should -BeFalse
        $result.UserNames.Count | Should -Be 0
    }

    It 'reports incomplete all-users removal even if the immediate inventory is empty' {
        Remove-SelectedApps -appsList @('One.App') | Should -BeFalse

        $script:AppRemovalFailures | Should -Be 1
        $script:WingetDeferredRemovals.ContainsKey('One.App') | Should -BeFalse
        Should -Invoke Invoke-WithTargetUserHive -Times 2 -Exactly
        Should -Invoke Invoke-WithTargetUserHive -Times 1 -Exactly -ParameterFilter { $TargetUserName -eq 'Default' }
        Should -Invoke Write-Host -Times 0 -Exactly -ParameterFilter { $Object -like 'WingetAllUsersUninstallDeferred*' }
    }

    It 'reports failure when required fallback scheduling throws during <Stage>' -ForEach @(
        @{ Stage = 'target resolution' }
        @{ Stage = 'profile enumeration' }
        @{ Stage = 'task scheduling' }
    ) {
        $ErrorActionPreference = 'Stop'
        switch ($Stage) {
            'target resolution' { Mock Get-RunOnceWingetTarget { throw 'target unavailable' } }
            'profile enumeration' { Mock Get-CimInstance { throw 'enumeration failed' } }
            'task scheduling' { Mock Set-RunOnceWingetTask { throw 'scheduling failed' } }
        }

        Remove-SelectedApps -appsList @('One.App') | Should -BeFalse

        $script:AppRemovalFailures | Should -Be 1
        $script:WingetDeferredRemovals.ContainsKey('One.App') | Should -BeFalse
        Should -Invoke Get-WingetInstalledApps -Times 1 -Exactly
        Should -Invoke Invoke-WithTargetUserHive -Times 0 -Exactly
    }
}
