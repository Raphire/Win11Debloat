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
}
