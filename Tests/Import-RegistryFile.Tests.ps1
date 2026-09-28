BeforeAll {
    function Get-RegistryFilePathForFeature { param($RegistryKey) $RegistryKey }
    function Invoke-RegistryOperationsFromRegFile { param($RegFilePath) }
    function Invoke-WithTargetUserHive { param($TargetUserName, $ScriptBlock, $ArgumentObject, [switch]$PassHiveContext) }
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) }
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Import-RegistryFile.ps1')
}

Describe 'Import-RegistryFile' {
    BeforeEach {
        $script:Params = @{}
        $script:regPath = Join-Path $TestDrive 'feature.reg'
        '' | Set-Content -LiteralPath $script:regPath
        Mock Get-RegistryFilePathForFeature { $script:regPath }
        Mock Invoke-RegistryOperationsFromRegFile { $true }
        Mock Invoke-WithTargetUserHive {}
        Mock Invoke-NonBlocking { [PSCustomObject]@{ Output = @(); ExitCode = 0; Error = $null } }
        Mock Write-Host {}
        Mock Write-Warning {}
    }

    It 'returns false when the registry file is missing' {
        Mock Get-RegistryFilePathForFeature { Join-Path $TestDrive 'missing.reg' }

        Import-RegistryFile -message 'Apply' -path 'missing.reg' | Should -BeFalse
        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'returns false when registry file resolution throws' {
        Mock Get-RegistryFilePathForFeature { throw 'path resolution failed' }

        Import-RegistryFile -message 'Apply' -path 'feature.reg' | Should -BeFalse
        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'uses the PowerShell writer only in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }
        Import-RegistryFile -message 'Apply' -path 'feature.reg' | Should -BeTrue
        Should -Invoke Invoke-RegistryOperationsFromRegFile -Times 1 -Exactly -ParameterFilter { $RegFilePath -eq $script:regPath }
        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'uses the PowerShell writer for an already-loaded target-user hive' {
        $script:Params = @{ User = 'Alice' }
        Mock Invoke-WithTargetUserHive {
            param($TargetUserName, $ScriptBlock, $ArgumentObject, $PassHiveContext)
            & $ScriptBlock $ArgumentObject ([PSCustomObject]@{ WasAlreadyLoaded = $true })
        }

        Import-RegistryFile -message 'Apply' -path 'feature.reg' | Should -BeTrue

        Should -Invoke Invoke-WithTargetUserHive -Times 1 -Exactly -ParameterFilter { $TargetUserName -eq 'Alice' -and $PassHiveContext }
        Should -Invoke Invoke-RegistryOperationsFromRegFile -Times 1 -Exactly
        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'falls back to the PowerShell writer when reg import fails' {
        Mock Invoke-NonBlocking { [PSCustomObject]@{ Output = @('denied'); ExitCode = 5; Error = 'access denied' } }

        Import-RegistryFile -message 'Apply' -path 'feature.reg' | Should -BeTrue

        Should -Invoke Invoke-RegistryOperationsFromRegFile -Times 1 -Exactly
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "reg import failed*" }
    }

    It 'returns false when the fallback cannot apply every registry operation' {
        Mock Invoke-NonBlocking { [PSCustomObject]@{ Output = @('denied'); ExitCode = 5; Error = 'access denied' } }
        Mock Invoke-RegistryOperationsFromRegFile { $false }

        Import-RegistryFile -message 'Apply' -path 'feature.reg' | Should -BeFalse
    }

    It 'does not invoke the fallback after a successful reg import' {
        Import-RegistryFile -message 'Apply' -path 'feature.reg' | Should -BeTrue
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly
        Should -Invoke Invoke-RegistryOperationsFromRegFile -Times 0 -Exactly
    }
}
