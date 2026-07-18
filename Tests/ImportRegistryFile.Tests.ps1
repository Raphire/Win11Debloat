BeforeAll {
    function Get-RegistryFilePathForFeature { param($RegistryKey) $RegistryKey }
    function Invoke-RegistryOperationsFromRegFile { param($RegFilePath) }
    function Invoke-WithTargetUserHive { param($TargetUserName, $ScriptBlock, $ArgumentObject, [switch]$PassHiveContext) }
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList) }
    . (Join-Path $PSScriptRoot '..\Scripts\Features\ImportRegistryFile.ps1')
}

Describe 'ImportRegistryFile' {
    BeforeEach {
        $script:Params = @{}
        $script:RegistryImportFailures = 0
        $script:regPath = Join-Path $TestDrive 'feature.reg'
        '' | Set-Content -LiteralPath $script:regPath
        Mock Get-RegistryFilePathForFeature { $script:regPath }
        Mock Invoke-RegistryOperationsFromRegFile {}
        Mock Invoke-WithTargetUserHive {}
        Mock Invoke-NonBlocking { [PSCustomObject]@{ Output = @(); ExitCode = 0; Error = $null } }
        Mock Write-Host {}
        Mock Write-Warning {}
    }

    It 'throws and increments the failure count when the registry file is missing' {
        Mock Get-RegistryFilePathForFeature { Join-Path $TestDrive 'missing.reg' }
        { ImportRegistryFile -message 'Apply' -path 'missing.reg' } | Should -Throw 'Unable to find registry file:*'
        $script:RegistryImportFailures | Should -Be 1
        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'uses the PowerShell writer only in WhatIf mode' {
        $script:Params = @{ WhatIf = $true }
        ImportRegistryFile -message 'Apply' -path 'feature.reg'
        Should -Invoke Invoke-RegistryOperationsFromRegFile -Times 1 -Exactly -ParameterFilter { $RegFilePath -eq $script:regPath }
        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'uses the PowerShell writer for an already-loaded target-user hive' {
        $script:Params = @{ User = 'Alice' }
        Mock Invoke-WithTargetUserHive {
            param($TargetUserName, $ScriptBlock, $ArgumentObject, $PassHiveContext)
            & $ScriptBlock $ArgumentObject ([PSCustomObject]@{ WasAlreadyLoaded = $true })
        }

        ImportRegistryFile -message 'Apply' -path 'feature.reg'

        Should -Invoke Invoke-WithTargetUserHive -Times 1 -Exactly -ParameterFilter { $TargetUserName -eq 'Alice' -and $PassHiveContext }
        Should -Invoke Invoke-RegistryOperationsFromRegFile -Times 1 -Exactly
        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
    }

    It 'falls back to the PowerShell writer when reg import fails' {
        Mock Invoke-NonBlocking { [PSCustomObject]@{ Output = @('denied'); ExitCode = 5; Error = 'access denied' } }

        ImportRegistryFile -message 'Apply' -path 'feature.reg'

        Should -Invoke Invoke-RegistryOperationsFromRegFile -Times 1 -Exactly
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like "reg import failed*" }
        $script:RegistryImportFailures | Should -Be 0
    }

    It 'does not invoke the fallback after a successful reg import' {
        ImportRegistryFile -message 'Apply' -path 'feature.reg'
        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly
        Should -Invoke Invoke-RegistryOperationsFromRegFile -Times 0 -Exactly
        $script:RegistryImportFailures | Should -Be 0
    }
}
