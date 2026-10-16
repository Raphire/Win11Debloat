BeforeDiscovery {
    # Test data for -ForEach is built while Pester discovers the tests, before BeforeAll runs.
    $abcHash = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    $otherHash = 'f' * 64
}

BeforeAll {
    # Load only the checksum functions from the launcher; dot-sourcing Get.ps1 would download and run the script.
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '..\Scripts\Get.ps1'), [ref]$tokens, [ref]$parseErrors)
    $parseErrors | Should -BeNullOrEmpty
    foreach ($functionName in 'Get-ExpectedFileHash', 'Test-FileHashMatch') {
        $function = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $functionName
        }, $true)
        $function | Should -Not -BeNullOrEmpty
        . ([scriptblock]::Create($function.Extent.Text))
    }

    # SHA-256 of the three ASCII bytes "abc" (FIPS 180-2 test vector).
    $script:AbcHash = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    $script:OtherHash = 'f' * 64
}

Describe 'Get-ExpectedFileHash' {
    It 'reads a hash written by sha256sum in <Case>' -ForEach @(
        @{ Case = 'text mode'; Line = "$($abcHash)  Win11Debloat.zip" }
        @{ Case = 'binary mode'; Line = "$($abcHash) *Win11Debloat.zip" }
        @{ Case = 'single space'; Line = "$($abcHash) Win11Debloat.zip" }
        @{ Case = 'upper case digits'; Line = "$($abcHash.ToUpperInvariant())  Win11Debloat.zip" }
    ) {
        Get-ExpectedFileHash $Line 'Win11Debloat.zip' | Should -BeExactly $script:AbcHash
    }

    It 'picks the requested file out of several lines with CRLF or LF endings' -ForEach @(
        @{ Newline = "`r`n" }
        @{ Newline = "`n" }
    ) {
        $text = "$($script:OtherHash)  Get.ps1$Newline$($script:AbcHash)  Win11Debloat.zip$Newline"

        Get-ExpectedFileHash $text 'Win11Debloat.zip' | Should -BeExactly $script:AbcHash
        Get-ExpectedFileHash $text 'Get.ps1' | Should -BeExactly $script:OtherHash
    }

    It 'returns nothing for <Case>' -ForEach @(
        @{ Case = 'a file that is not listed'; Text = "$($abcHash)  Get.ps1" }
        @{ Case = 'a name that only ends with the requested one'; Text = "$($abcHash)  old-Win11Debloat.zip" }
        @{ Case = 'a name that differs in case'; Text = "$($abcHash)  win11debloat.zip" }
        @{ Case = 'a hash that is too short'; Text = "$('a' * 63)  Win11Debloat.zip" }
        @{ Case = 'a hash with non-hex digits'; Text = "$('g' * 64)  Win11Debloat.zip" }
        @{ Case = 'empty text'; Text = '' }
    ) {
        Get-ExpectedFileHash $Text 'Win11Debloat.zip' | Should -BeNullOrEmpty
    }
}

Describe 'Test-FileHashMatch' {
    BeforeAll {
        $script:AbcFile = Join-Path $TestDrive 'abc [1].bin'
        [System.IO.File]::WriteAllBytes($script:AbcFile, [System.Text.Encoding]::ASCII.GetBytes('abc'))
    }

    It 'accepts the matching hash in lower and upper case' {
        Test-FileHashMatch $script:AbcFile $script:AbcHash | Should -BeTrue
        Test-FileHashMatch $script:AbcFile $script:AbcHash.ToUpperInvariant() | Should -BeTrue
    }

    It 'rejects a different hash' {
        Test-FileHashMatch $script:AbcFile $script:OtherHash | Should -BeFalse
    }

    It 'rejects a file whose content changed' {
        $changedFile = Join-Path $TestDrive 'changed.bin'
        [System.IO.File]::WriteAllBytes($changedFile, [System.Text.Encoding]::ASCII.GetBytes('abd'))

        Test-FileHashMatch $changedFile $script:AbcHash | Should -BeFalse
    }
}
