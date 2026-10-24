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

Describe 'Launcher archive verification flow' {
    # Runs the real Get.ps1 with every download, prompt and process start mocked, so the verification gate itself is
    # exercised (the helper tests above would still pass if the launcher stopped calling them). Nothing reaches the network:
    # the release data uses .invalid URLs and TEMP points to TestDrive.
    BeforeAll {
        $getScriptPath = Join-Path $PSScriptRoot '..\Scripts\Get.ps1'
        $archiveUrl = 'https://example.invalid/download/Win11Debloat.zip'
        $checksumsUrl = 'https://example.invalid/download/SHA256SUMS'
        $zipballUrl = 'https://example.invalid/zipball'
    }

    BeforeEach {
        $originalTemp = $env:TEMP
        $env:TEMP = $TestDrive
        $archivePath = Join-Path $TestDrive 'win11debloat.zip'

        # Mock bodies read this table, so a test changes it instead of re-creating variables.
        $state = @{
            Release   = [pscustomobject]@{
                zipball_url = $zipballUrl
                assets      = @(
                    [pscustomobject]@{ name = 'Win11Debloat.zip'; browser_download_url = $archiveUrl }
                    [pscustomobject]@{ name = 'SHA256SUMS'; browser_download_url = $checksumsUrl }
                )
            }
            SumsText  = ''
            ArchiveBytes = [System.Text.Encoding]::ASCII.GetBytes('abc')
        }

        Mock Clear-Host {}
        Mock Read-Host {}
        Mock Start-Process { throw 'The launcher must not start the script in these tests.' }
        Mock Expand-Archive { throw 'reached extraction' }
        Mock Invoke-RestMethod {
            switch -Regex ([string]$Uri) {
                'releases/latest$' { return $state.Release }
                'SHA256SUMS$' { [System.IO.File]::WriteAllText($OutFile, $state.SumsText) }
                default { [System.IO.File]::WriteAllBytes($OutFile, $state.ArchiveBytes) }
            }
        }
    }

    AfterEach {
        $env:TEMP = $originalTemp
    }

    It 'exits without unpacking and deletes the archive when its hash does not match' {
        $state.SumsText = "$('f' * 64)  Win11Debloat.zip"
        $global:LASTEXITCODE = 0
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null

        $global:LASTEXITCODE | Should -Be 1
        Test-Path -LiteralPath $archivePath | Should -BeFalse
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq $archiveUrl }
        Should -Invoke Expand-Archive -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'exits without falling back when SHA256SUMS does not list the archive' {
        $state.SumsText = "$('a' * 64)  Get.ps1"
        $global:LASTEXITCODE = 0
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null

        $global:LASTEXITCODE | Should -Be 1
        Test-Path -LiteralPath $archivePath | Should -BeFalse
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq $checksumsUrl }
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Uri -eq $archiveUrl -or $Uri -eq $zipballUrl }
        Should -Invoke Expand-Archive -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'goes on to unpack the archive when its hash matches' {
        $state.SumsText = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  Win11Debloat.zip'
        $ErrorActionPreference = 'Continue'

        { & $getScriptPath *> $null } | Should -Throw '*reached extraction*'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq $archiveUrl }
        Should -Invoke Expand-Archive -Times 1 -Exactly
    }

    It 'downloads the generated source archive when the release has no checksum asset' {
        $state.Release.assets = @($state.Release.assets | Where-Object { $_.name -ne 'SHA256SUMS' })
        $ErrorActionPreference = 'Continue'

        { & $getScriptPath *> $null } | Should -Throw '*reached extraction*'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq $zipballUrl }
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Uri -eq $checksumsUrl -or $Uri -eq $archiveUrl }
        Should -Invoke Expand-Archive -Times 1 -Exactly
    }

    It 'downloads the generated source archive when the release has no archive asset' {
        $state.Release.assets = @($state.Release.assets | Where-Object { $_.name -ne 'Win11Debloat.zip' })
        $ErrorActionPreference = 'Continue'

        { & $getScriptPath *> $null } | Should -Throw '*reached extraction*'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq $zipballUrl }
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Uri -eq $checksumsUrl -or $Uri -eq $archiveUrl }
        Should -Invoke Expand-Archive -Times 1 -Exactly
    }
}
