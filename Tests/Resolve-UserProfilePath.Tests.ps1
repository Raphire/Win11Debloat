BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Resolve-UserProfilePath.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Test-UserProfileExists.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Get-UserDirectory.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Test-ModernStandbySupport.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Invoke-RestartExplorer.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\Threading\Invoke-DoEvents.ps1')

    function powercfg { $script:PowerCfgOutput }
    function Wait-ForKeyPress {}
    function Get-RebootFeatureLabels { @() }
}

Describe 'Test-UserProfileExists' {
    BeforeEach {
        Mock Resolve-UserProfileContext {
            [PSCustomObject]@{ ProfilePath = 'C:\Users\Alice'; UserSid = 'S-1-5-21-1000' }
        }
        Mock Wait-ForKeyPress {}
        Mock Write-Error {}
    }

    It 'rejects blank and path-unsafe user names before resolving a profile' {
        Test-UserProfileExists -userName '' | Should -BeFalse
        Test-UserProfileExists -userName 'Alice[1]' | Should -BeFalse
        Should -Invoke Resolve-UserProfileContext -Times 0 -Exactly
    }

    It 'accepts a resolved ordinary user and the Default profile without a SID' {
        Test-UserProfileExists -userName ' Alice ' | Should -BeTrue
        Mock Resolve-UserProfileContext { [PSCustomObject]@{ ProfilePath = 'C:\Users\Default'; UserSid = $null } }
        Test-UserProfileExists -userName 'Default' | Should -BeTrue
    }

    It 'returns a resolved profile path and optionally appends a file name' {
        Mock Test-Path { $true }

        Get-UserDirectory -userName 'Alice' | Should -Be 'C:\Users\Alice'
        Get-UserDirectory -userName 'Alice' -fileName 'AppData\Local' | Should -Be 'C:\Users\Alice\AppData\Local'
    }
}

Describe 'Test-ModernStandbySupport' {
    BeforeEach {
        $script:Params = @{}
        Mock Write-Host {}
    }

    It 'detects S0 Modern Standby from powercfg output' {
        $script:PowerCfgOutput = @('The following sleep states are available on this system:', '    Standby (S0 Low Power Idle) Network Connected')

        Test-ModernStandbySupport | Should -BeTrue
    }

    It 'does not restart Explorer for WhatIf or an explicit skip' {
        Mock Stop-Process {}
        $script:Params = @{ WhatIf = $true }
        Invoke-RestartExplorer
        $script:Params = @{ NoRestartExplorer = $true }
        Invoke-RestartExplorer

        Should -Invoke Stop-Process -Times 0 -Exactly
    }

    It 'restarts Explorer when allowed and reports reboot-required features' {
        Mock Stop-Process {}
        Mock Get-RebootFeatureLabels { @('Disable telemetry') }

        Invoke-RestartExplorer

        Should -Invoke Stop-Process -Times 1 -Exactly -ParameterFilter { $processName -eq 'Explorer' -and $Force }
        Should -Invoke Get-RebootFeatureLabels -Times 1 -Exactly
    }
}

Describe 'Resolve-UserSid' {
    BeforeEach {
        $script:ResolvedUserSidCache = @{}
        $script:MachineDomainJoinStateKnown = $null
        $script:MachineIsDomainJoined = $false
        $script:MachineNetBiosDomain = ''
    }

    It 'builds domain-aware candidate forms and compares profile folder leaves' {
        Mock Get-ProfileFolderDomainSuffix { 'CONTOSO' }

        Get-UserNameMatchCandidates -Value 'CONTOSO\Alice' | Should -Be @('CONTOSO\Alice', 'Alice', 'Alice.CONTOSO')
        Test-UserNameMatchesProfileLeaf -UserName 'CONTOSO\Alice' -ProfileLeaf 'Alice.CONTOSO' | Should -BeTrue
    }

    It 'prefers the NetBIOS domain source and falls back to the DNS label' {
        Mock Get-CimInstance { [PSCustomObject]@{ DomainName = 'CONTOSO'; DomainControllerName = '\\dc01.contoso.com' } }
        Resolve-NetBiosDomainName -RawDomain 'contoso.com' | Should -Be 'CONTOSO'

        Mock Get-CimInstance { throw 'CIM unavailable' }
        Resolve-NetBiosDomainName -RawDomain 'contoso.com' | Should -Be 'contoso'
    }

    It 'stores and retrieves resolved SIDs through normalized cache keys' {
        Set-ResolvedUserSidCache -Candidates @('Alice', 'CONTOSO\Alice') -Sid 'S-1-5-21-1000'

        Get-CachedResolvedUserSid -Candidates @('contoso\alice') | Should -Be 'S-1-5-21-1000'
    }

    It 'returns a local-user SID before falling back to CIM' {
        Mock Get-Command { [PSCustomObject]@{ Name = 'Get-LocalUser' } } -ParameterFilter { $Name -eq 'Get-LocalUser' }
        Mock Get-LocalUser { [PSCustomObject]@{ SID = [PSCustomObject]@{ Value = 'S-1-5-21-1000' } } }
        Mock Get-CimInstance { throw 'CIM should not be queried' }

        Try-ResolveSidByLocalLookup -Candidates @('Alice') | Should -Be 'S-1-5-21-1000'
        Should -Invoke Get-CimInstance -Times 0 -Exactly
    }

    It 'recovers a workgroup SID from a matching ProfileList folder' {
        Mock Test-MachineIsDomainJoined { $false }
        Mock Get-ChildItem { [PSCustomObject]@{ PSPath = 'Registry::ProfileList\S-1-5-21-1000'; PSChildName = 'S-1-5-21-1000' } }
        Mock Get-ItemPropertyValue { 'C:\Users\Alice' }

        Try-ResolveSidFromProfileList -Candidates @('Alice') | Should -Be 'S-1-5-21-1000'
    }

    It 'constructs user contexts and resolves a workgroup SID through NTAccount' {
        $context = New-ResolvedUserContext -UserName 'Alice' -UserSid 'S-1-5-21-1000' -ProfilePath 'C:\Users\Alice'
        $context.UserName | Should -Be 'Alice'
        $context.UserSid | Should -Be 'S-1-5-21-1000'

        Mock Get-CachedResolvedUserSid { $null }
        Mock Test-MachineIsDomainJoined { $false }
        Mock Try-ResolveSidByNtAccount { 'S-1-5-21-1000' }
        Mock Set-ResolvedUserSidCache {}

        Resolve-UserSid -UserName 'Alice' | Should -Be 'S-1-5-21-1000'
        Should -Invoke Try-ResolveSidByNtAccount -Times 1 -Exactly -ParameterFilter { $UserName -eq 'Alice' }
    }

    It 'does not qualify blank names or process UI events without a GUI window' {
        Get-QualifiedProcessIdentityName -Candidate '' | Should -BeNullOrEmpty
        $script:GuiWindow = $null
        { Invoke-DoEvents } | Should -Not -Throw
    }
}
