Describe 'Standalone restore initialization' -Skip:($env:OS -ne 'Windows_NT') {
    It 'binds the restore window in a fresh Windows PowerShell process' {
        $mainPath = Join-Path $PSScriptRoot '..\Win11Debloat.ps1'
        $tokens = $null
        $parseErrors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($mainPath, [ref]$tokens, [ref]$parseErrors)
        $restoreBranch = $ast.Find({ param($node)
            $node -is [Management.Automation.Language.IfStatementAst] -and $node.Clauses[0].Item1.Extent.Text -eq '$RestoreBackup'
        }, $true)
        $probePath = Join-Path $TestDrive 'restore-initialization.ps1'
        $probe = @'
$ErrorActionPreference = 'Stop'
if ('System.Windows.Window' -as [type]) { throw 'WPF was unexpectedly preloaded' }
function Show-RestoreBackupWindow {
    param([System.Windows.Window]$Owner)
    return @{ Cancelled = $true; Failed = $false }
}
function Wait-ForKeyPress {
    param([int]$ExitCode)
    if ($ExitCode -ne 3) { throw "Unexpected exit code: $ExitCode" }
}
$RestoreBackup = $true
'@
        ($probe + "`r`n" + $restoreBranch.Extent.Text) | Set-Content -LiteralPath $probePath -Encoding UTF8
        $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $output = & $powerShellPath -NoProfile -STA -ExecutionPolicy Bypass -File $probePath 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}

Describe 'Restore window completion status' -Skip:($env:OS -ne 'Windows_NT') {
    BeforeAll {
        Add-Type -AssemblyName PresentationFramework
        function Show-RestoreBackupDialog { param($Owner) }
        function Restore-RegistryBackupState { param($Backup) }
        function Restore-StartMenu { param($BackupFilePath) }
        function Restore-StartMenuForAllUsers { param($BackupFilePath) }
        function Show-MessageBox { param($Title, $Message, $Icon) }
        function Get-Translation { param($Key, $FormatArgs) $Key }
        . (Join-Path $PSScriptRoot '..\Scripts\GUI\Show-RestoreBackupWindow.ps1')
    }

    BeforeEach {
        $script:Params = @{}
        Mock Write-Host {}
        Mock Write-Error {}
        Mock Show-MessageBox {}
        Mock Show-RestoreBackupDialog { @{ Result = 'RestoreRegistry'; Backup = @{ Target = 'CurrentUser' } } }
        Mock Restore-RegistryBackupState { @{ Result = $true } }
    }

    It 'distinguishes a cancelled dialog from a successful restore' {
        Mock Show-RestoreBackupDialog { @{ Result = 'Cancel' } }
        $result = Show-RestoreBackupWindow
        $result.Cancelled | Should -BeTrue
        $result.Failed | Should -BeFalse
        $result.RestoredRegistry | Should -BeFalse
        Should -Invoke Restore-RegistryBackupState -Times 0 -Exactly
    }

    It 'reports a successful registry restore' {
        $result = Show-RestoreBackupWindow
        $result.RestoredRegistry | Should -BeTrue
        $result.Cancelled | Should -BeFalse
        $result.Failed | Should -BeFalse
    }

    It 'does not report a failed registry operation as success' {
        Mock Restore-RegistryBackupState { @{ Result = $false } }
        $result = Show-RestoreBackupWindow
        $result.RestoredRegistry | Should -BeFalse
        $result.Failed | Should -BeTrue
    }

    It 'reports thrown restore errors as failures' {
        Mock Restore-RegistryBackupState { throw 'Registry import failed' }
        $result = Show-RestoreBackupWindow
        $result.Failed | Should -BeTrue
        $result.Cancelled | Should -BeFalse
    }

    It 'reports a partially restored all-users Start menu as a failure' {
        Mock Show-RestoreBackupDialog { @{ Result = 'Restore-StartMenu'; StartMenuScope = 'AllUsers'; UseManualBackupFile = $false } }
        Mock Restore-StartMenuForAllUsers {
            @([PSCustomObject]@{ Result = $true; Message = 'Restored Alice' }, [PSCustomObject]@{ Result = $false; Message = 'Failed Bob' })
        }
        $result = Show-RestoreBackupWindow
        $result.RestoredStartMenu | Should -BeTrue
        $result.Failed | Should -BeTrue
    }
}
