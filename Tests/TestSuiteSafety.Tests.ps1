Describe 'Test suite safety convention' {
    It 'does not directly execute high-impact Windows mutation commands' {
        $protectedCommands = @(
            'Add-AppxPackage'
            'Add-AppxProvisionedPackage'
            'Add-WindowsCapability'
            'Checkpoint-Computer'
            'Clear-ItemProperty'
            'Disable-ComputerRestore'
            'Disable-ScheduledTask'
            'Disable-WindowsOptionalFeature'
            'Enable-ComputerRestore'
            'Enable-ScheduledTask'
            'Enable-WindowsOptionalFeature'
            'Install-Package'
            'Invoke-Expression'
            'iex'
            'New-ItemProperty'
            'New-PSDrive'
            'Register-ScheduledTask'
            'Remove-AppxPackage'
            'Remove-AppxProvisionedPackage'
            'Remove-ItemProperty'
            'Remove-WindowsCapability'
            'Restart-Service'
            'Set-Acl'
            'Set-ExecutionPolicy'
            'Set-ItemProperty'
            'Set-MpPreference'
            'Set-Service'
            'Set-WinUserLanguageList'
            'Start-Service'
            'Start-Process'
            'Stop-Service'
            'Stop-Process'
            'Uninstall-Package'
            'Unregister-ScheduledTask'
            'bcdedit'
            'bcdedit.exe'
            'dism'
            'dism.exe'
            'fsutil'
            'fsutil.exe'
            'takeown'
            'icacls'
            'reg'
            'reg.exe'
            'schtasks'
            'schtasks.exe'
            'sc.exe'
            'wevtutil'
            'wevtutil.exe'
        )

        $violations = foreach ($testFile in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' -File) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($testFile.FullName, [ref]$tokens, [ref]$parseErrors)
            $parseErrors | Should -BeNullOrEmpty

            foreach ($command in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                $commandName = $command.GetCommandName()
                if ($commandName -and $protectedCommands -contains $commandName) {
                    "$($testFile.Name): $commandName"
                }
            }
        }

        $violations | Should -BeNullOrEmpty
    }

    It 'does not use literal system paths with direct filesystem mutation commands' {
        $fileMutationCommands = @('Clear-Content', 'Copy-Item', 'Move-Item', 'New-Item', 'Remove-Item', 'Set-Content', 'Set-Item')
        $violations = foreach ($testFile in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' -File) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($testFile.FullName, [ref]$tokens, [ref]$parseErrors)

            foreach ($command in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                if ($fileMutationCommands -notcontains $command.GetCommandName()) { continue }

                foreach ($element in $command.CommandElements) {
                    if ($element -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { continue }
                    if ($element.Value -match '^(?:[A-Za-z]:\\|\\\\|(?:HKCU|HKLM|HKU|HKCR):)') {
                        "$($testFile.Name): $($command.GetCommandName()) $($element.Value)"
                    }
                }
            }
        }

        $violations | Should -BeNullOrEmpty
    }
}
