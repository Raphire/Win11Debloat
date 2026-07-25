BeforeAll {
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) }
    function Enable-WindowsOptionalFeature {
        param([switch]$Online, $FeatureName, [switch]$All, [switch]$NoRestart)
        [void]$global:OptionalFeatureCalls.Add([PSCustomObject]@{ Action = 'Enable'; Online = $Online; FeatureName = $FeatureName; All = $All; NoRestart = $NoRestart })
    }
    function Disable-WindowsOptionalFeature {
        param([switch]$Online, $FeatureName, [switch]$NoRestart)
        [void]$global:OptionalFeatureCalls.Add([PSCustomObject]@{ Action = 'Disable'; Online = $Online; FeatureName = $FeatureName; All = $false; NoRestart = $NoRestart })
    }
    function Get-WindowsOptionalFeature {
        param([switch]$Online, $FeatureName, $ErrorAction)
        [void]$global:OptionalFeatureQueryCalls.Add([PSCustomObject]@{ Online = $Online; FeatureName = $FeatureName; ErrorAction = $ErrorAction })
        if ($global:OptionalFeatureQueryThrows) {
            throw 'feature service unavailable'
        }
        return [PSCustomObject]@{ State = $global:OptionalFeatureQueryState }
    }

    . (Join-Path $PSScriptRoot '..\Scripts\Features\Windows-OptionalFeatures.ps1')
}

Describe 'Enable-WindowsFeature' {
    BeforeEach {
        $script:Params = @{}
        Mock Invoke-NonBlocking { @() }
        Mock Write-Host {}
    }

    It 'schedules the requested feature with the non-blocking runner' {
        Enable-WindowsFeature -FeatureName 'Feature.One'

        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter { $ArgumentList -eq 'Feature.One' }
    }

    It 'calls Enable-WindowsOptionalFeature with the expected arguments' {
        $global:OptionalFeatureCalls = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-NonBlocking {
            param($ScriptBlock, $ArgumentList)
            $script:optionalFeatureBlock = $ScriptBlock
            $script:optionalFeatureArguments = $ArgumentList
        }
        Enable-WindowsFeature -FeatureName 'Feature.One'
        & $script:optionalFeatureBlock $script:optionalFeatureArguments

        $global:OptionalFeatureCalls | Should -HaveCount 1
        $global:OptionalFeatureCalls[0].Action | Should -Be 'Enable'
        $global:OptionalFeatureCalls[0].Online | Should -BeTrue
        $global:OptionalFeatureCalls[0].FeatureName | Should -Be 'Feature.One'
        $global:OptionalFeatureCalls[0].All | Should -BeTrue
        $global:OptionalFeatureCalls[0].NoRestart | Should -BeTrue
    }

    It 'does not schedule changes in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }

        Enable-WindowsFeature -FeatureName 'Feature.One'

        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'surfaces an optional-feature enable failure from the scheduled script block' {
        Mock Invoke-NonBlocking {
            param($ScriptBlock, $ArgumentList)
            $script:optionalFeatureBlock = $ScriptBlock
            $script:optionalFeatureArguments = $ArgumentList
        }
        Mock Enable-WindowsOptionalFeature { throw 'feature servicing failed' }

        Enable-WindowsFeature -FeatureName 'Feature.One'

        { & $script:optionalFeatureBlock $script:optionalFeatureArguments } | Should -Throw 'feature servicing failed'
    }
}

Describe 'Disable-WindowsFeature' {
    BeforeEach {
        $script:Params = @{}
        Mock Invoke-NonBlocking { @() }
        Mock Write-Host {}
    }

    It 'schedules the requested feature with the non-blocking runner' {
        Disable-WindowsFeature -FeatureName 'Feature.One'

        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter { $ArgumentList -eq 'Feature.One' }
    }

    It 'calls Disable-WindowsOptionalFeature with the expected arguments' {
        $global:OptionalFeatureCalls = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-NonBlocking {
            param($ScriptBlock, $ArgumentList)
            $script:optionalFeatureBlock = $ScriptBlock
            $script:optionalFeatureArguments = $ArgumentList
        }
        Disable-WindowsFeature -FeatureName 'Feature.One'
        & $script:optionalFeatureBlock $script:optionalFeatureArguments

        $global:OptionalFeatureCalls | Should -HaveCount 1
        $global:OptionalFeatureCalls[0].Action | Should -Be 'Disable'
        $global:OptionalFeatureCalls[0].Online | Should -BeTrue
        $global:OptionalFeatureCalls[0].FeatureName | Should -Be 'Feature.One'
        $global:OptionalFeatureCalls[0].All | Should -BeFalse
        $global:OptionalFeatureCalls[0].NoRestart | Should -BeTrue
    }

    It 'does not schedule changes in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }

        Disable-WindowsFeature -FeatureName 'Feature.One'

        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'surfaces an optional-feature disable failure from the scheduled script block' {
        Mock Invoke-NonBlocking {
            param($ScriptBlock, $ArgumentList)
            $script:optionalFeatureBlock = $ScriptBlock
            $script:optionalFeatureArguments = $ArgumentList
        }
        Mock Disable-WindowsOptionalFeature { throw 'feature servicing failed' }

        Disable-WindowsFeature -FeatureName 'Feature.One'

        { & $script:optionalFeatureBlock $script:optionalFeatureArguments } | Should -Throw 'feature servicing failed'
    }
}

Describe 'Test-WindowsOptionalFeatureEnabled' {
    BeforeEach {
        $global:OptionalFeatureQueryCalls = [System.Collections.Generic.List[object]]::new()
        $global:OptionalFeatureQueryThrows = $false
        $global:OptionalFeatureQueryState = 'Disabled'
    }

    It 'returns true for an enabled optional feature' {
        $global:OptionalFeatureQueryState = 'Enabled'

        Test-WindowsOptionalFeatureEnabled -FeatureName 'Feature.One' | Should -BeTrue

        $global:OptionalFeatureQueryCalls | Should -HaveCount 1
        $global:OptionalFeatureQueryCalls[0].Online | Should -BeTrue
        $global:OptionalFeatureQueryCalls[0].FeatureName | Should -Be 'Feature.One'
        $global:OptionalFeatureQueryCalls[0].ErrorAction | Should -Be 'Stop'
    }

    It 'returns false for a non-enabled optional feature' {
        Test-WindowsOptionalFeatureEnabled -FeatureName 'Feature.One' | Should -BeFalse
    }

    It 'returns false when the optional-feature query fails' {
        $global:OptionalFeatureQueryThrows = $true

        Test-WindowsOptionalFeatureEnabled -FeatureName 'Feature.One' | Should -BeFalse
    }
}
