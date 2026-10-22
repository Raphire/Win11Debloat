BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $buildScript = Join-Path $repositoryRoot 'Scripts/Build-Release.ps1'
    $releasePath = Join-Path $TestDrive 'release'
    $version = '2026.10.22-r2'
    $originalScript = [IO.File]::ReadAllBytes((Join-Path $repositoryRoot 'Win11Debloat.ps1'))
    Push-Location $TestDrive
    try { & $buildScript -SourcePath $repositoryRoot -Version $version -OutputDirectory 'release' }
    finally { Pop-Location }
    $unpackedPath = Join-Path $TestDrive 'unpacked'
    Expand-Archive -LiteralPath (Join-Path $releasePath 'Win11Debloat.zip') -DestinationPath $unpackedPath
    $packagePath = Join-Path $unpackedPath "Win11Debloat-$version"
}

Describe 'Release packaging' {
    It 'stamps only the packaged version and preserves runtime resources' {
        [IO.File]::ReadAllText((Join-Path $packagePath 'Win11Debloat.ps1')) | Should -Match '\$script:Version = "2026\.10\.22-r2"'
        [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $repositoryRoot 'Win11Debloat.ps1'))) |
            Should -BeExactly ([Convert]::ToBase64String($originalScript))
        foreach ($directory in 'Assets', 'Config', 'Regfiles', 'Schemas') {
            foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot $directory) -File -Recurse) {
                $relativePath = $file.FullName.Substring($repositoryRoot.Length + 1)
                if ($relativePath -eq 'Config\LastUsedSettings.json') { continue }
                $packagedFile = Join-Path $packagePath $relativePath
                Test-Path -LiteralPath $packagedFile | Should -BeTrue -Because $relativePath
                (Get-FileHash -LiteralPath $packagedFile).Hash | Should -Be (Get-FileHash -LiteralPath $file.FullName).Hash
            }
        }
    }

    It 'excludes development files and existing user data' {
        foreach ($path in 'Tests', '.github', '.git', '.gitignore', 'Logs', 'Backups', 'Scripts/Run-Tests.ps1', 'Scripts/Build-Release.ps1', 'LastUsedSettings.json', 'Config/LastUsedSettings.json') {
            Test-Path -LiteralPath (Join-Path $packagePath $path) | Should -BeFalse
        }
    }

    It 'hashes the final ZIP and publishes the matching launcher' {
        $hash = (Get-FileHash -LiteralPath (Join-Path $releasePath 'Win11Debloat.zip')).Hash.ToLowerInvariant()
        [IO.File]::ReadAllText((Join-Path $releasePath 'SHA256SUMS')) | Should -BeExactly "$hash  Win11Debloat.zip`n"
        (Get-FileHash -LiteralPath (Join-Path $releasePath 'Get.ps1')).Hash |
            Should -Be (Get-FileHash -LiteralPath (Join-Path $packagePath 'Scripts/Get.ps1')).Hash
    }

    It 'includes new files automatically and prunes exclusions and nested output' {
        $source = Join-Path $TestDrive 'source-fixture'
        foreach ($directory in 'NewRuntime', 'Scripts', 'Tests', '.git', '.github', 'Logs', 'Backups', 'Config') {
            New-Item -ItemType Directory -Path (Join-Path $source $directory) -Force | Out-Null
        }
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'Win11Debloat.ps1') -Destination $source
        Copy-Item -LiteralPath (Join-Path $repositoryRoot 'Scripts/Get.ps1') -Destination (Join-Path $source 'Scripts/Get.ps1')
        foreach ($path in 'extra.txt', 'NewRuntime/data.txt', 'Scripts/NewHelper.ps1', 'Tests/test.txt', '.git/config', '.github/workflow.yml', '.gitignore', 'Logs/log.txt', 'Backups/backup.json', 'Scripts/Build-Release.ps1', 'Scripts/Run-Tests.ps1', 'LastUsedSettings.json', 'Config/LastUsedSettings.json') {
            Set-Content -LiteralPath (Join-Path $source $path) -Value 'fixture'
        }
        $output = Join-Path $source 'output'
        & $buildScript -SourcePath $source -Version $version -OutputDirectory $output
        $extracted = Join-Path $TestDrive 'fixture-extracted'
        Expand-Archive -LiteralPath (Join-Path $output 'Win11Debloat.zip') -DestinationPath $extracted
        $root = Join-Path $extracted "Win11Debloat-$version"
        foreach ($path in 'extra.txt', 'NewRuntime/data.txt', 'Scripts/NewHelper.ps1', 'Scripts/Get.ps1') {
            Test-Path -LiteralPath (Join-Path $root $path) | Should -BeTrue
        }
        foreach ($path in 'Tests', '.git', '.github', '.gitignore', 'Logs', 'Backups', 'Scripts/Build-Release.ps1', 'Scripts/Run-Tests.ps1', 'LastUsedSettings.json', 'Config/LastUsedSettings.json', 'output') {
            Test-Path -LiteralPath (Join-Path $root $path) | Should -BeFalse
        }
    }

    It 'rejects invalid version input and refuses to overwrite output' {
        { & $buildScript -Version '../2026' -OutputDirectory (Join-Path $TestDrive 'invalid') } | Should -Throw
        { & $buildScript -Version '2026.02.30' -OutputDirectory (Join-Path $TestDrive 'invalid-date') } | Should -Throw
        foreach ($invalidVersion in '2026.02.30-r2', '2026.10.22-r0', '2026.10.22-r', '2026.10.22-r2-extra') {
            { & $buildScript -Version $invalidVersion -OutputDirectory (Join-Path $TestDrive 'invalid-revision') } | Should -Throw
        }
        { & $buildScript -Version $version -OutputDirectory $releasePath } | Should -Throw '*Output already exists*'
    }
}

Describe 'Packaged archive through the launcher' {
    It 'verifies and really extracts the release to the expected launch path' {
        $originalTemp = $env:TEMP
        $launcherTemp = Join-Path $TestDrive 'launcher'
        New-Item -ItemType Directory -Path $launcherTemp | Out-Null
        $env:TEMP = $launcherTemp
        $archiveBytes = [IO.File]::ReadAllBytes((Join-Path $releasePath 'Win11Debloat.zip'))
        $sumsText = [IO.File]::ReadAllText((Join-Path $releasePath 'SHA256SUMS'))
        Mock Clear-Host {}
        Mock Read-Host { throw 'Unexpected launcher prompt.' }
        Mock Start-Process { throw 'Reached launch with real extraction.' }
        Mock Invoke-RestMethod {
            if ([string]$Uri -match 'releases/latest$') {
                return [pscustomobject]@{
                    assets = @(
                        [pscustomobject]@{ name = 'Win11Debloat.zip'; browser_download_url = 'https://example.invalid/Win11Debloat.zip' }
                        [pscustomobject]@{ name = 'SHA256SUMS'; browser_download_url = 'https://example.invalid/SHA256SUMS' }
                    )
                }
            }
            if ([string]$Uri -match 'SHA256SUMS$') { [IO.File]::WriteAllText($OutFile, $sumsText) }
            else { [IO.File]::WriteAllBytes($OutFile, $archiveBytes) }
        }
        try {
            # Stop at the launcher's catch, before its final cleanup; no child process is created.
            $ErrorActionPreference = 'Stop'
            { & (Join-Path $releasePath 'Get.ps1') -CLI } | Should -Throw '*Reached launch with real extraction*'
            $mainScript = Join-Path $launcherTemp 'Win11Debloat/Win11Debloat.ps1'
            Test-Path -LiteralPath $mainScript | Should -BeTrue
            [IO.File]::ReadAllText($mainScript) | Should -Match '\$script:Version = "2026\.10\.22-r2"'
            Test-Path -LiteralPath (Join-Path $launcherTemp 'Win11Debloat/Schemas/MainWindow.xaml') | Should -BeTrue
            Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { $ArgumentList -like '*Win11Debloat.ps1*' }
        }
        finally { $env:TEMP = $originalTemp }
    }
}
