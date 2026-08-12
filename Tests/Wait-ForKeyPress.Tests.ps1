Describe 'Wait-ForKeyPress' {
    It 'exits cleanly without prompting when Silent is enabled' {
        $scriptPath = Join-Path $PSScriptRoot '..\Scripts\CLI\Wait-ForKeyPress.ps1'
        $command = "function Stop-Transcript {}; `$global:Silent = `$true; . '$scriptPath'; Wait-ForKeyPress"
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))

        & powershell.exe -NoProfile -EncodedCommand $encodedCommand

        $LASTEXITCODE | Should -Be 0
    }

    It 'uses the requested exit code' {
        $scriptPath = Join-Path $PSScriptRoot '..\Scripts\CLI\Wait-ForKeyPress.ps1'
        $command = "function Stop-Transcript {}; `$global:Silent = `$true; . '$scriptPath'; Wait-ForKeyPress -ExitCode 1"
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))

        & powershell.exe -NoProfile -EncodedCommand $encodedCommand

        $LASTEXITCODE | Should -Be 1
    }
}
