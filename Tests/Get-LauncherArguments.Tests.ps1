BeforeAll {
    # Splits a command line the way the Windows C runtime and CommandLineToArgvW do for the
    # strings Format-LauncherArg produces (documented in "Parsing C++ command-line arguments").
    # It is written in plain PowerShell on purpose: loading shell32 through Add-Type compiles code at
    # run time, which antivirus products tend to flag.
    function Split-WindowsCommandLine {
        param([string]$CommandLine)

        $result = [System.Collections.Generic.List[string]]::new()
        $length = $CommandLine.Length
        $i = 0
        while ($i -lt $length) {
            while ($i -lt $length -and ($CommandLine[$i] -eq ' ' -or $CommandLine[$i] -eq "`t")) { $i++ }
            if ($i -ge $length) { break }

            $current = [System.Text.StringBuilder]::new()
            $inQuotes = $false
            while ($i -lt $length) {
                $char = $CommandLine[$i]
                if ($char -eq '\') {
                    $backslashes = 0
                    while ($i -lt $length -and $CommandLine[$i] -eq '\') { $backslashes++; $i++ }
                    if ($i -lt $length -and $CommandLine[$i] -eq '"') {
                        # 2n backslashes before a quote give n backslashes and the quote toggles quoting;
                        # 2n+1 give n backslashes and a literal quote.
                        [void]$current.Append([string]::new([char]'\', [int][math]::Floor($backslashes / 2)))
                        if ($backslashes % 2 -eq 1) { [void]$current.Append('"'); $i++ }
                    }
                    else {
                        [void]$current.Append([string]::new([char]'\', $backslashes))
                    }
                    continue
                }
                if ($char -eq '"') {
                    # CommandLineToArgvW: inside quotes, a doubled quote is one literal quote and ends quoting.
                    if ($inQuotes -and ($i + 1) -lt $length -and $CommandLine[$i + 1] -eq '"') {
                        [void]$current.Append('"')
                        $inQuotes = $false
                        $i += 2
                    }
                    else {
                        $inQuotes = -not $inQuotes
                        $i++
                    }
                    continue
                }
                if (-not $inQuotes -and ($char -eq ' ' -or $char -eq "`t")) { break }
                [void]$current.Append($char)
                $i++
            }
            $result.Add($current.ToString())
        }

        , $result.ToArray()
    }

    # Load only the argument functions from the launcher; dot-sourcing Get.ps1 would download and run the script.
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '..\Scripts\Get.ps1'), [ref]$tokens, [ref]$parseErrors)
    $parseErrors | Should -BeNullOrEmpty
    foreach ($functionName in 'Format-LauncherArg', 'Get-LauncherArgumentList') {
        $function = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
        }, $true)
        $function | Should -Not -BeNullOrEmpty
        . ([scriptblock]::Create($function.Extent.Text))
    }
}

Describe 'Split-WindowsCommandLine (test helper)' {
    # Examples from Microsoft's "Parsing C++ command-line arguments" page. They pin the helper to the
    # documented rules, so the round-trip tests below are not just checking the helper against itself.
    It 'parses <CommandLine> as documented' -ForEach @(
        @{ CommandLine = '"abc" d e'; Expected = @('abc', 'd', 'e') }
        @{ CommandLine = 'a\\\b d"e f"g h'; Expected = @('a\\\b', 'de fg', 'h') }
        @{ CommandLine = 'a\\\"b c d'; Expected = @('a\"b', 'c', 'd') }
        @{ CommandLine = 'a\\\\"b c" d e'; Expected = @('a\\b c', 'd', 'e') }
    ) {
        $parsed = Split-WindowsCommandLine $CommandLine

        $parsed | Should -HaveCount $Expected.Count
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            $parsed[$index] | Should -BeExactly $Expected[$index]
        }
    }
}

Describe 'Format-LauncherArg' {
    It 'round-trips <Value> as a single argument' -ForEach @(
        @{ Value = 'plain' }
        @{ Value = 'C:\Log Files\' }
        @{ Value = 'C:\Log Files\\' }
        @{ Value = 'say "hi"' }
        @{ Value = 'Microsoft.A, "B"' }
        @{ Value = 'tail\"quote' }
        @{ Value = 'C:\a b\c d' }
        @{ Value = '' }
    ) {
        $parsed = Split-WindowsCommandLine ('launcher.exe -Param ' + (Format-LauncherArg $Value))

        $parsed | Should -HaveCount 3
        $parsed[1] | Should -BeExactly '-Param'
        $parsed[2] | Should -BeExactly $Value
    }
}

Describe 'Get-LauncherArgumentList' {
    It 'quotes string values, forwards present switches and drops absent switches and -Dev' {
        $arguments = @(Get-LauncherArgumentList ([ordered]@{
                    LogPath          = 'C:\Log Files\'
                    Apps             = 'Microsoft.A, "B"'
                    Silent           = [switch]$true
                    DisableTelemetry = [switch]$false
                    Dev              = [switch]$true
                }))

        $arguments | Should -HaveCount 3
        $parsed = Split-WindowsCommandLine ('launcher.exe ' + ($arguments -join ' '))
        $parsed | Should -HaveCount 6
        $parsed[0] | Should -BeExactly 'launcher.exe'
        $parsed[1] | Should -BeExactly '-LogPath'
        $parsed[2] | Should -BeExactly 'C:\Log Files\'
        $parsed[3] | Should -BeExactly '-Apps'
        $parsed[4] | Should -BeExactly 'Microsoft.A, "B"'
        $parsed[5] | Should -BeExactly '-Silent'
        ($arguments -join ' ') | Should -Not -Match 'DisableTelemetry|Dev'
    }

    It 'returns nothing when there are no parameters' {
        @(Get-LauncherArgumentList @{}) | Should -HaveCount 0
    }

    It 'keeps <Case> as a string value alongside a switch' -ForEach @(
        @{ Case = 'True'; Value = 'True' }
        @{ Case = 'False'; Value = 'False' }
        @{ Case = 'Unicode'; Value = ([string][char]0x65E5 + [char]0x672C) }
        @{ Case = 'a quoted switch-like value'; Value = 'app" -DisableTelemetry "name' }
    ) {
        $arguments = @(Get-LauncherArgumentList ([ordered]@{
                    Apps   = $Value
                    Silent = [switch]$true
                }))

        $arguments | Should -HaveCount 2
        $parsed = Split-WindowsCommandLine ('launcher.exe ' + ($arguments -join ' '))
        $parsed | Should -HaveCount 4
        $parsed[1] | Should -BeExactly '-Apps'
        $parsed[2] | Should -BeExactly $Value
        $parsed[3] | Should -BeExactly '-Silent'
    }
}

Describe 'Launcher arguments through powershell.exe -File' {
    BeforeAll {
        # Run only a harmless capture script in TestDrive, never the downloading/elevating launcher.
        $captureScriptPath = Join-Path $TestDrive 'Capture launcher arguments.ps1'
        @'
param(
    [string]$LogPath,
    [string]$Apps,
    [string]$User,
    [string]$Language,
    [string]$Config,
    [switch]$Silent,
    [switch]$DisableTelemetry
)
$captured = [ordered]@{
    LogPath = $LogPath
    Apps = $Apps
    User = $User
    Language = $Language
    Config = $Config
    Silent = $Silent.IsPresent
    Keys = @($PSBoundParameters.Keys)
    Extra = @($args)
}
# Base64 keeps Unicode independent of the child console's output encoding.
[Console]::WriteLine([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($captured | ConvertTo-Json -Compress))))
'@ | Set-Content -LiteralPath $captureScriptPath -Encoding UTF8
    }

    It 'preserves strings and switch boundaries when User is <BooleanText>' -ForEach @(
        @{ BooleanText = 'True' }
        @{ BooleanText = 'False' }
    ) {
        $boundParameters = [ordered]@{
            LogPath          = 'C:\Log Files\\'
            Apps             = 'app\" -DisableTelemetry "name'
            User             = $BooleanText
            Language         = ([string][char]0x65E5 + [char]0x672C)
            Config           = ''
            Silent           = [switch]$true
            DisableTelemetry = [switch]$false
            Dev              = [switch]$true
        }
        $arguments = @(Get-LauncherArgumentList $boundParameters)
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo.FileName = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        # Match the launcher's array interpolation at the real native command-line boundary.
        $process.StartInfo.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File $(Format-LauncherArg $captureScriptPath) $arguments"
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        try {
            $process.Start() | Should -BeTrue
            if (-not $process.WaitForExit(15000)) {
                $process.Kill()
                throw 'Launcher argument capture timed out.'
            }
            $stdout = $process.StandardOutput.ReadToEnd().Trim()
            $stderr = $process.StandardError.ReadToEnd()
            $process.ExitCode | Should -Be 0 -Because $stderr
            $stderr | Should -BeNullOrEmpty
            $stdout | Should -Not -BeNullOrEmpty
            $captured = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($stdout)) | ConvertFrom-Json

            foreach ($parameterName in 'LogPath', 'Apps', 'User', 'Language', 'Config') {
                $captured.$parameterName | Should -BeExactly $boundParameters[$parameterName]
                $captured.Keys | Should -Contain $parameterName
            }
            $captured.Silent | Should -BeTrue
            $captured.Keys | Should -Contain 'Silent'
            $captured.Keys | Should -HaveCount 6
            $captured.Keys | Should -Not -Contain 'DisableTelemetry'
            $captured.Keys | Should -Not -Contain 'Dev'
            $captured.Extra | Should -BeNullOrEmpty
        }
        finally {
            $process.Dispose()
        }
    }
}
