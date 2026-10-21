BeforeAll {
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Windows-BuildHelpers.ps1')
}

Describe 'Get-CurrentWindowsBuild' {
    It 'returns the build number as a number' {
        Mock Get-ItemPropertyValue { '26100' }

        Get-CurrentWindowsBuild | Should -Be 26100
        Get-CurrentWindowsBuild | Should -BeOfType [int]
    }

    It 'returns nothing when the value is not a number' {
        Mock Get-ItemPropertyValue { 'unknown' }

        Get-CurrentWindowsBuild | Should -BeNullOrEmpty
    }

    It 'returns nothing instead of failing when reading the registry throws' {
        Mock Get-ItemPropertyValue { throw 'Property CurrentBuild does not exist' }

        { Get-CurrentWindowsBuild } | Should -Not -Throw
        Get-CurrentWindowsBuild | Should -BeNullOrEmpty
    }

    It 'asks for a terminating error so that a missing value is caught' {
        Mock Get-ItemPropertyValue { '19045' }

        Get-CurrentWindowsBuild | Out-Null

        Should -Invoke Get-ItemPropertyValue -Times 1 -Exactly -ParameterFilter { $ErrorAction -eq 'Stop' }
    }
}

Describe 'Test-FeatureSupportedOnBuild' {
    It 'returns <Expected> for MinVersion <Min>, MaxVersion <Max> on build <Build>' -ForEach @(
        @{ Min = 22621; Max = $null; Build = 19045; Expected = $false }
        @{ Min = 22621; Max = $null; Build = 22620; Expected = $false }
        @{ Min = 22621; Max = $null; Build = 22621; Expected = $true }
        @{ Min = 22621; Max = $null; Build = 26100; Expected = $true }
        @{ Min = $null; Max = 21999; Build = 19045; Expected = $true }
        @{ Min = $null; Max = 21999; Build = 21999; Expected = $true }
        @{ Min = $null; Max = 21999; Build = 22000; Expected = $false }
        @{ Min = 22000; Max = 22631; Build = 22631; Expected = $true }
        @{ Min = 22000; Max = 22631; Build = 26100; Expected = $false }
        @{ Min = $null; Max = $null; Build = 10240; Expected = $true }
    ) {
        $feature = [PSCustomObject]@{ MinVersion = $Min; MaxVersion = $Max }

        Test-FeatureSupportedOnBuild -Feature $feature -Build $Build | Should -Be $Expected
    }

    It 'does not limit a feature when the build is not known' {
        $feature = [PSCustomObject]@{ MinVersion = 22621; MaxVersion = $null }

        Test-FeatureSupportedOnBuild -Feature $feature -Build $null | Should -BeTrue
    }

    It 'does not limit an unknown feature' {
        Test-FeatureSupportedOnBuild -Feature $null -Build 19045 | Should -BeTrue
    }

    It 'compares build numbers as numbers when the build is a string' {
        $feature = [PSCustomObject]@{ MinVersion = 22621; MaxVersion = $null }

        Test-FeatureSupportedOnBuild -Feature $feature -Build '9600' | Should -BeFalse
    }
}
