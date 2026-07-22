BeforeAll {
    function Invoke-NonBlocking { param($ScriptBlock, $ArgumentList, $TimeoutSeconds) }
    function Show-MessageBox { param($Message, $Title, $Button, $Icon) }
    function Enable-ComputerRestore { param($Drive) }
    function Get-ComputerRestorePoint {}
    function Checkpoint-Computer { param($Description, $RestorePointType) }
    . (Join-Path $PSScriptRoot '..\Scripts\Features\Invoke-SystemRestorePoint.ps1')
}

Describe 'Invoke-SystemRestorePoint' {
    BeforeEach {
        $script:GuiWindow = $null
        $script:CancelRequested = $false
        $script:Silent = $false
        Mock Get-ItemProperty { [PSCustomObject]@{ RPSessionInterval = 1 } }
        Mock Invoke-NonBlocking { [PSCustomObject]@{ Success = $true; Message = 'System restore point created successfully' } }
        Mock Read-Host { 'y' }
        Mock Show-MessageBox { 'Yes' }
        Mock Write-Host {}
    }

    It 'creates a restore point when System Restore is already enabled' {
        Invoke-SystemRestorePoint

        Should -Invoke Invoke-NonBlocking -Times 1 -Exactly -ParameterFilter { $TimeoutSeconds -eq 90 }
        Should -Invoke Read-Host -Times 0 -Exactly
        $script:CancelRequested | Should -BeFalse
    }

    It 'is loaded by the main entry point' {
        $entryPoint = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Win11Debloat.ps1') -Raw
        $expectedImport = [regex]::Escape('Scripts/Features/Invoke-SystemRestorePoint.ps1')

        $entryPoint | Should -Match $expectedImport
        Get-Command Invoke-SystemRestorePoint | Should -Not -BeNullOrEmpty
    }

    It 'enables disabled System Restore before creating the point in silent mode' {
        $script:Silent = $true
        Mock Get-ItemProperty { [PSCustomObject]@{ RPSessionInterval = 0 } }
        $script:nonBlockingCalls = 0
        Mock Invoke-NonBlocking {
            $script:nonBlockingCalls++
            if ($script:nonBlockingCalls -eq 1) { return $null }
            return [PSCustomObject]@{ Success = $true; Message = 'System restore point created successfully' }
        }

        Invoke-SystemRestorePoint

        Should -Invoke Invoke-NonBlocking -Times 2 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
    }

    It 'enables System Restore only for the Windows system drive' {
        $script:Silent = $true
        $script:nonBlockingCalls = 0
        Mock Get-ItemProperty { [PSCustomObject]@{ RPSessionInterval = 0 } }
        Mock Invoke-NonBlocking {
            param($ScriptBlock)
            $script:nonBlockingCalls++
            if ($script:nonBlockingCalls -eq 1) {
                $script:enableRestoreBlock = $ScriptBlock
                return $null
            }
            return [PSCustomObject]@{ Success = $true; Message = 'System restore point created successfully' }
        }
        Mock Enable-ComputerRestore {}

        Invoke-SystemRestorePoint
        & $script:enableRestoreBlock

        Should -Invoke Enable-ComputerRestore -Times 1 -Exactly -ParameterFilter { $Drive -eq $env:SystemDrive }
    }

    It 'creates only a MODIFY_SETTINGS restore point with the project description' {
        $script:restorePointBlock = $null
        Mock Invoke-NonBlocking {
            param($ScriptBlock)
            $script:restorePointBlock = $ScriptBlock
            return [PSCustomObject]@{ Success = $true; Message = 'System restore point created successfully' }
        }
        Mock Get-ComputerRestorePoint { @() }
        Mock Checkpoint-Computer {}

        Invoke-SystemRestorePoint
        & $script:restorePointBlock

        Should -Invoke Checkpoint-Computer -Times 1 -Exactly -ParameterFilter {
            $Description -eq 'Restore point created by Win11Debloat' -and $RestorePointType -eq 'MODIFY_SETTINGS'
        }
    }

    It 'cancels when an interactive user declines enabling disabled System Restore' {
        Mock Get-ItemProperty { [PSCustomObject]@{ RPSessionInterval = 0 } }
        Mock Read-Host { 'n' }

        Invoke-SystemRestorePoint

        Should -Invoke Invoke-NonBlocking -Times 0 -Exactly
        $script:CancelRequested | Should -BeTrue
    }

    It 'cancels when restore point creation fails and the CLI user declines continuation' {
        Mock Invoke-NonBlocking { [PSCustomObject]@{ Success = $false; Message = 'creation failed' } }
        Mock Read-Host { 'n' }

        Invoke-SystemRestorePoint

        $script:CancelRequested | Should -BeTrue
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter { $Object -eq 'creation failed' }
    }

    It 'offers the CLI continuation choice when enabling System Restore fails' {
        Mock Get-ItemProperty { [PSCustomObject]@{ RPSessionInterval = 0 } }
        Mock Invoke-NonBlocking { throw 'enable failed' }
        Mock Read-Host { 'n' }

        Invoke-SystemRestorePoint

        $script:CancelRequested | Should -BeTrue
    }

    It 'continues after a GUI failure only when the dialog confirms it' {
        $script:GuiWindow = [PSCustomObject]@{}
        Mock Invoke-NonBlocking { $null }
        Mock Show-MessageBox { 'No' }

        Invoke-SystemRestorePoint

        $script:CancelRequested | Should -BeTrue
        Should -Invoke Show-MessageBox -Times 1 -Exactly
    }
}
