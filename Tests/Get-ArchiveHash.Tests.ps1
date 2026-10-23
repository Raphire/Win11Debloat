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
            UnpackPaths = [System.Collections.Generic.List[string]]::new()
            ArchiveBytes = [System.Text.Encoding]::ASCII.GetBytes('abc')
        }

        Mock Clear-Host {}
        Mock Read-Host {}
        Mock Start-Process { throw 'The launcher must not start the script in these tests.' }
        Mock Expand-Archive { $state.UnpackPaths.Add([string]$DestinationPath); throw 'reached extraction' }
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
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'win11debloat-*.zip') | Should -HaveCount 0
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
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'win11debloat-*.zip') | Should -HaveCount 0
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq $checksumsUrl }
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Uri -eq $archiveUrl -or $Uri -eq $zipballUrl }
        Should -Invoke Expand-Archive -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'goes on to unpack the archive when its hash matches' {
        $state.SumsText = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  Win11Debloat.zip'
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq $archiveUrl }
        Should -Invoke Expand-Archive -Times 1 -Exactly
    }

    It 'downloads the generated source archive when the release has no checksum asset' {
        $state.Release.assets = @($state.Release.assets | Where-Object { $_.name -ne 'SHA256SUMS' })
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter { $Uri -eq $zipballUrl }
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Uri -eq $checksumsUrl -or $Uri -eq $archiveUrl }
        Should -Invoke Expand-Archive -Times 1 -Exactly
    }
}

Describe 'Launcher work folder' {
    # Same setup as the verification flow above: the real Get.ps1, everything outside it mocked, TEMP in TestDrive.
    BeforeAll {
        $getScriptPath = Join-Path $PSScriptRoot '..\Scripts\Get.ps1'
        $zipballUrl = 'https://example.invalid/zipball'
    }

    BeforeEach {
        $originalTemp = $env:TEMP
        $env:TEMP = $TestDrive

        $state = @{
            UnpackPaths = [System.Collections.Generic.List[string]]::new()
            Unpacked    = $true
        }

        Mock Clear-Host {}
        Mock Read-Host {}
        Mock Start-Process {
            $process = [pscustomobject]@{ ExitCode = 0 }
            $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { }
            return $process
        }
        Mock Invoke-RestMethod {
            switch -Regex ([string]$Uri) {
                'releases/latest$' { return [pscustomobject]@{ zipball_url = $zipballUrl; assets = @() } }
                default { [System.IO.File]::WriteAllBytes($OutFile, [byte[]](1, 2, 3)) }
            }
        }
        # Unpacks like a GitHub source archive: one top-level folder that holds the script
        Mock Expand-Archive {
            $state.UnpackPaths.Add([string]$DestinationPath)
            $top = Join-Path $DestinationPath 'Raphire-Win11Debloat-0123abc'
            New-Item -ItemType Directory -Path $top -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $top 'Win11Debloat.ps1') -Value '# stand-in'
        }
    }

    AfterEach {
        $env:TEMP = $originalTemp
    }

    It 'unpacks into a new folder with a random name in TEMP and runs the script from there' {
        $global:LASTEXITCODE = 0
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null

        $state.UnpackPaths | Should -HaveCount 1
        $state.UnpackPaths[0] | Should -Match '^.+\\Win11Debloat-[0-9a-f]{32}$'
        Split-Path -Parent $state.UnpackPaths[0] | Should -Be $TestDrive
        $expectedScript = Join-Path $state.UnpackPaths[0] 'Win11Debloat.ps1'
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { ($ArgumentList -join ' ').Contains($expectedScript) }
    }

    It 'uses a different folder for every run' {
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null
        & $getScriptPath *> $null

        $state.UnpackPaths | Should -HaveCount 2
        $state.UnpackPaths[0] | Should -Not -Be $state.UnpackPaths[1]
    }

    It 'removes the whole folder and the archive when it is done' {
        $global:LASTEXITCODE = 0
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null

        $global:LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath $state.UnpackPaths[0] | Should -BeFalse
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'win11debloat-*.zip') | Should -HaveCount 0
    }

    It 'leaves a Win11Debloat folder from an earlier version alone' {
        $legacyBackups = Join-Path $TestDrive 'Win11Debloat\Backups'
        New-Item -ItemType Directory -Path $legacyBackups -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $legacyBackups 'old-backup.json') -Value '{}'
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null

        Test-Path -LiteralPath (Join-Path $legacyBackups 'old-backup.json') | Should -BeTrue
    }
}

Describe 'Launcher when unpacking fails' {
    BeforeAll {
        $getScriptPath = Join-Path $PSScriptRoot '..\Scripts\Get.ps1'
    }

    BeforeEach {
        $originalTemp = $env:TEMP
        $env:TEMP = $TestDrive

        Mock Clear-Host {}
        Mock Read-Host {}
        Mock Start-Process { throw 'The launcher must not start the script in these tests.' }
        Mock Invoke-RestMethod {
            switch -Regex ([string]$Uri) {
                'releases/latest$' { return [pscustomobject]@{ zipball_url = 'https://example.invalid/zipball'; assets = @() } }
                default { [System.IO.File]::WriteAllBytes($OutFile, [byte[]](1, 2, 3)) }
            }
        }
        # Leaves a partly unpacked folder behind, then fails like a damaged archive or a blocked file would
        Mock Expand-Archive {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $DestinationPath 'partial.txt') -Value 'partial'
            throw 'The archive is damaged.'
        }
    }

    AfterEach {
        $env:TEMP = $originalTemp
    }

    It 'removes the archive and the partly unpacked folder and exits with 1 when <Case>' -ForEach @(
        @{ Case = 'errors are non-terminating'; Preference = 'Continue' }
        @{ Case = 'the caller stops on errors'; Preference = 'Stop' }
    ) {
        $global:LASTEXITCODE = 0
        $ErrorActionPreference = $Preference

        & $getScriptPath *> $null

        $global:LASTEXITCODE | Should -Be 1
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'win11debloat-*.zip') | Should -HaveCount 0
        @(Get-ChildItem -LiteralPath $TestDrive -Directory -Filter 'Win11Debloat-*') | Should -HaveCount 0
        Should -Invoke Start-Process -Times 0 -Exactly
    }
}

Describe 'Launcher when the download fails' {
    BeforeAll {
        $getScriptPath = Join-Path $PSScriptRoot '..\Scripts\Get.ps1'
        $archiveUrl = 'https://example.invalid/download/Win11Debloat.zip'
        $checksumsUrl = 'https://example.invalid/download/SHA256SUMS'
    }

    BeforeEach {
        $originalTemp = $env:TEMP
        $env:TEMP = $TestDrive
        $state = @{ FailOn = '' }

        Mock Clear-Host {}
        Mock Read-Host {}
        Mock Start-Process { throw 'The launcher must not start the script in these tests.' }
        Mock Expand-Archive { throw 'The launcher must not unpack in these tests.' }
        # Writes a partial file and then fails, like a transfer that breaks halfway
        Mock Invoke-RestMethod {
            switch -Regex ([string]$Uri) {
                'releases/latest$' {
                    return [pscustomobject]@{
                        zipball_url = 'https://example.invalid/zipball'
                        assets      = @(
                            [pscustomobject]@{ name = 'Win11Debloat.zip'; browser_download_url = $archiveUrl }
                            [pscustomobject]@{ name = 'SHA256SUMS'; browser_download_url = $checksumsUrl }
                        )
                    }
                }
                default {
                    [System.IO.File]::WriteAllBytes($OutFile, [byte[]](1, 2, 3))
                    if ([string]$Uri -like "*$($state.FailOn)") { throw 'The connection was closed.' }
                    if ([string]$Uri -like '*SHA256SUMS') { [System.IO.File]::WriteAllText($OutFile, ('a' * 64) + '  Win11Debloat.zip') }
                }
            }
        }
    }

    AfterEach {
        $env:TEMP = $originalTemp
    }

    It 'removes the files of this run and exits with 1 when the <Case> download fails' -ForEach @(
        @{ Case = 'archive'; FailOn = 'Win11Debloat.zip' }
        @{ Case = 'checksum'; FailOn = 'SHA256SUMS' }
    ) {
        $state.FailOn = $FailOn
        $global:LASTEXITCODE = 0
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null

        $global:LASTEXITCODE | Should -Be 1
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'win11debloat-*') | Should -HaveCount 0
        Should -Invoke Expand-Archive -Times 0 -Exactly
    }
}

Describe 'Launcher with a real archive' {
    # Real Compress-Archive/Expand-Archive and file moves; only the elevated start is mocked, because the
    # elevation prompt cannot be answered in a test. The mock records what the launcher left for the script.
    BeforeAll {
        $getScriptPath = Join-Path $PSScriptRoot '..\Scripts\Get.ps1'
        $fixtureRoot = Join-Path $TestDrive 'fixture'
        $top = Join-Path $fixtureRoot 'Raphire-Win11Debloat-0123abc'
        New-Item -ItemType Directory -Path (Join-Path $top 'Config') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $top 'Win11Debloat.ps1') -Value '# stand-in'
        Set-Content -LiteralPath (Join-Path $top 'Config\Apps.json') -Value '{}'
        $fixtureZip = Join-Path $TestDrive 'fixture.zip'
        Compress-Archive -Path $top -DestinationPath $fixtureZip
    }

    BeforeEach {
        $originalTemp = $env:TEMP
        $env:TEMP = Join-Path $TestDrive 'temp'
        New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
        $state = @{ Launched = $false; ScriptExists = $false; NestedConfigExists = $false; ScriptPath = '' }

        Mock Clear-Host {}
        Mock Read-Host {}
        Mock Invoke-RestMethod {
            switch -Regex ([string]$Uri) {
                'releases/latest$' { return [pscustomobject]@{ zipball_url = 'https://example.invalid/zipball'; assets = @() } }
                default { Copy-Item -LiteralPath $fixtureZip -Destination $OutFile }
            }
        }
        Mock Start-Process {
            $state.Launched = $true
            if (($ArgumentList -join ' ') -match '-File "([^"]+)"') {
                $state.ScriptPath = $Matches[1]
                $state.ScriptExists = Test-Path -LiteralPath $Matches[1]
                $state.NestedConfigExists = Test-Path -LiteralPath (Join-Path (Split-Path -Parent $Matches[1]) 'Config\Apps.json')
            }
            $process = [pscustomobject]@{ ExitCode = 0 }
            $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { }
            return $process
        }
    }

    AfterEach {
        $env:TEMP = $originalTemp
    }

    It 'unpacks for real, starts the script from the unpacked folder and removes everything afterwards' {
        $global:LASTEXITCODE = 0
        $ErrorActionPreference = 'Continue'

        & $getScriptPath *> $null

        $state.Launched | Should -BeTrue
        $state.ScriptPath | Should -Match 'Win11Debloat-[0-9a-f]{32}\\Win11Debloat\.ps1$'
        $state.ScriptExists | Should -BeTrue
        $state.NestedConfigExists | Should -BeTrue
        $global:LASTEXITCODE | Should -Be 0
        @(Get-ChildItem -LiteralPath $env:TEMP -Force) | Should -HaveCount 0
    }
}

Describe 'Launcher when the script cannot be started' {
    BeforeAll {
        $getScriptPath = Join-Path $PSScriptRoot '..\Scripts\Get.ps1'
    }

    BeforeEach {
        $originalTemp = $env:TEMP
        $env:TEMP = $TestDrive

        Mock Clear-Host {}
        Mock Read-Host {}
        Mock Invoke-RestMethod {
            switch -Regex ([string]$Uri) {
                'releases/latest$' { return [pscustomobject]@{ zipball_url = 'https://example.invalid/zipball'; assets = @() } }
                default { [System.IO.File]::WriteAllBytes($OutFile, [byte[]](1, 2, 3)) }
            }
        }
        Mock Expand-Archive {
            $top = Join-Path $DestinationPath 'Raphire-Win11Debloat-0123abc'
            New-Item -ItemType Directory -Path $top -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $top 'Win11Debloat.ps1') -Value '# stand-in'
        }
        # The elevation prompt was declined
        Mock Start-Process { throw 'The operation was canceled by the user.' }
    }

    AfterEach {
        $env:TEMP = $originalTemp
    }

    It 'removes the folder and exits with 1 when <Case>' -ForEach @(
        @{ Case = 'errors are non-terminating'; Preference = 'Continue' }
        @{ Case = 'the caller stops on errors'; Preference = 'Stop' }
    ) {
        $global:LASTEXITCODE = 0
        $ErrorActionPreference = $Preference

        & $getScriptPath *> $null

        $global:LASTEXITCODE | Should -Be 1
        @(Get-ChildItem -LiteralPath $TestDrive -Directory -Filter 'Win11Debloat-*') | Should -HaveCount 0
        @(Get-ChildItem -LiteralPath $TestDrive -Filter 'win11debloat-*.zip') | Should -HaveCount 0
    }
}
