BeforeAll {
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $gitExecutable = (Get-Command git -CommandType Application | Select-Object -First 1).Source
    $workflow = Get-Content -LiteralPath (Join-Path $repositoryRoot '.github/workflows/release.yml') -Raw
    $workflowBlocks = @([regex]::Matches($workflow, '(?m)^        run: \|\r?\n(?<body>(?:          [^\r\n]*(?:\r?\n|$))+)') | ForEach-Object {
        [scriptblock]::Create(($_.Groups['body'].Value -replace '(?m)^          ', ''))
    })
}

Describe 'Release workflow version validation' {
    BeforeEach {
        $locationPushed = $false
        $originalTag = $env:RELEASE_TAG
        $checkoutPath = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $checkoutPath -Force | Out-Null
        $scriptPath = Join-Path $checkoutPath 'Win11Debloat.ps1'
        $originalSource = '$script:Version = "2026.08.24"'
        [IO.File]::WriteAllText($scriptPath, $originalSource)
        # Version validation needs no repository or external authentication.
        function git {}
        function gh {}
        Mock git { $global:LASTEXITCODE = 0 }
        Mock gh { $global:LASTEXITCODE = 0 }
        Push-Location $checkoutPath
        $locationPushed = $true
    }

    AfterEach {
        if ($locationPushed) { Pop-Location }
        $env:RELEASE_TAG = $originalTag
    }

    It 'rejects invalid release version <InvalidVersion> before changing the source or calling external tools' -ForEach @(
        @{ InvalidVersion = '2026.02.30-r2' }
        @{ InvalidVersion = '2026.10.23-r0' }
        @{ InvalidVersion = '2026.10.23-r' }
        @{ InvalidVersion = '2026.10.23-r2-extra' }
    ) {
        $env:RELEASE_TAG = $InvalidVersion
        { & $workflowBlocks[0] } | Should -Throw
        [IO.File]::ReadAllText($scriptPath) | Should -BeExactly $originalSource
        Should -Invoke git -Times 0 -Exactly
        Should -Invoke gh -Times 0 -Exactly
    }

    It 'accepts a single-digit revision and updates the source version' {
        $env:RELEASE_TAG = '2026.10.23-r2'
        & $workflowBlocks[0]
        [IO.File]::ReadAllText($scriptPath) | Should -BeExactly '$script:Version = "2026.10.23-r2"'
    }
}

Describe 'Release workflow version commit' {
    BeforeEach {
        $locationPushed = $false
        $originalTag = $env:RELEASE_TAG
        $originalSummary = $env:GITHUB_STEP_SUMMARY
        $originalToken = $env:GH_TOKEN
        $testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $checkoutPath = Join-Path $testRoot 'checkout'
        $remotePath = Join-Path $testRoot 'origin.git'
        New-Item -ItemType Directory -Path (Join-Path $checkoutPath 'Scripts') -Force | Out-Null
        git init --bare --quiet $remotePath
        git init --quiet --initial-branch master $checkoutPath
        git -C $checkoutPath config user.name 'Release test'
        git -C $checkoutPath config user.email 'release-test@example.invalid'
        git -C $checkoutPath config commit.gpgsign false
        git -C $checkoutPath config tag.gpgsign false
        git -C $checkoutPath config core.autocrlf false
        [IO.File]::WriteAllText((Join-Path $checkoutPath 'Win11Debloat.ps1'), '$script:Version = "2026.08.24"')
        foreach ($name in 'Build-Release.ps1', 'Get.ps1') {
            Copy-Item -LiteralPath (Join-Path $repositoryRoot "Scripts/$name") -Destination (Join-Path $checkoutPath "Scripts/$name")
        }
        [IO.File]::WriteAllText((Join-Path $checkoutPath 'Scripts/Run-Tests.ps1'), @'
param([switch]$Bootstrap)
$text = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../Win11Debloat.ps1'))
if ($text -notmatch [regex]::Escape($env:RELEASE_TAG)) { throw 'Tests did not see the updated version.' }
'@)
        git -C $checkoutPath add .
        git -C $checkoutPath commit --quiet -m initial
        git -C $checkoutPath remote add origin $remotePath
        git -C $checkoutPath push --quiet origin master
        if ($LASTEXITCODE -ne 0) { throw 'Unable to prepare isolated Git fixture.' }
        $initialCommit = git -C $checkoutPath rev-parse HEAD
        $env:RELEASE_TAG = '2026.10.23'
        $env:GITHUB_STEP_SUMMARY = Join-Path $testRoot 'summary.txt'
        $env:GH_TOKEN = 'release-workflow-test-token'
        $script:uploadedFiles = @()
        $script:gitAuthenticationConfigured = $false

        function git {
            if ($args[0] -eq 'ls-remote' -and -not $script:gitAuthenticationConfigured) {
                throw 'Git authentication must be configured before querying remote tags.'
            }
            & $gitExecutable @args
            $global:LASTEXITCODE = $LASTEXITCODE
        }

        # Real local Git commits/pushes; all GitHub operations stay inside this fixture.
        function gh {
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'auth' -and $args[1] -eq 'setup-git') {
                $script:gitAuthenticationConfigured = $true
                return
            }
            if ($args[1] -eq 'create') { return }
            if ($args[1] -eq 'view') { return '{"isDraft":true}' }
            if ($args[1] -eq 'upload') {
                $script:uploadedFiles = @($args | Select-Object -Skip 3)
                foreach ($file in $script:uploadedFiles) {
                    if (-not (Test-Path -LiteralPath $file)) { throw "Missing upload: $file" }
                }
                return
            }
            throw 'Unexpected GitHub CLI operation.'
        }
        function curl.exe {
            $headerIndex = [array]::IndexOf($args, '--header')
            if ($headerIndex -lt 0 -or $args[$headerIndex + 1] -cne "Authorization: Bearer $env:GH_TOKEN") {
                throw 'The source download must authenticate with GH_TOKEN.'
            }
            $outputIndex = [array]::IndexOf($args, '--output') + 1
            $commit = ($args[-1] -split '/')[-1]
            git archive --format=zip --prefix=tagged-source/ -o $args[$outputIndex] $commit
            if ($LASTEXITCODE -ne 0) { throw 'Unable to prepare mock source download.' }
        }
        Push-Location $checkoutPath
        $locationPushed = $true
    }

    AfterEach {
        if ($locationPushed) { Pop-Location }
        $env:RELEASE_TAG = $originalTag
        $env:GITHUB_STEP_SUMMARY = $originalSummary
        $env:GH_TOKEN = $originalToken
    }

    It 'commits and packages release version <ReleaseVersion> from the same tagged commit' -ForEach @(
        @{ ReleaseVersion = '2026.10.23' }
        @{ ReleaseVersion = '2026.10.23-r10' }
    ) {
        $env:RELEASE_TAG = $ReleaseVersion
        foreach ($block in $workflowBlocks) { & $block }
        $releaseCommit = git rev-parse HEAD
        $releaseCommit | Should -Not -Be $initialCommit
        (git --git-dir $remotePath rev-parse refs/heads/master) | Should -Be $releaseCommit
        (git --git-dir $remotePath rev-parse "refs/tags/$env:RELEASE_TAG") | Should -Be $releaseCommit
        $versionPattern = '\$script:Version = "' + [regex]::Escape($ReleaseVersion) + '"'
        (git show HEAD:Win11Debloat.ps1) | Should -Match $versionPattern
        $script:uploadedFiles | Should -HaveCount 3
        $summaryBytes = [IO.File]::ReadAllBytes($env:GITHUB_STEP_SUMMARY)
        $summaryBytes[0] | Should -Be ([byte][char]'P')
        $summaryBytes | Should -Not -Contain 0
        $unpacked = Join-Path $testRoot 'unpacked'
        Expand-Archive -LiteralPath release-assets/Win11Debloat.zip -DestinationPath $unpacked
        [IO.File]::ReadAllText((Join-Path $unpacked "Win11Debloat-$ReleaseVersion/Win11Debloat.ps1")) |
            Should -Match $versionPattern
    }

    It 'does not commit or push a release when tests fail' {
        [IO.File]::WriteAllText((Join-Path $checkoutPath 'Scripts/Run-Tests.ps1'), 'exit 1')
        { foreach ($block in $workflowBlocks) { & $block } } | Should -Throw '*Release tests failed*'
        (git --git-dir $remotePath rev-parse refs/heads/master) | Should -Be $initialCommit
        (git ls-remote --tags origin "refs/tags/$env:RELEASE_TAG") | Should -BeNullOrEmpty
    }

    It 'clears a stale native exit code before running successful tests' {
        & $workflowBlocks[0]
        $global:LASTEXITCODE = 7
        { & $workflowBlocks[1] } | Should -Not -Throw
        $LASTEXITCODE | Should -Be 0
    }

    It 'rejects an existing tag before modifying the source version' {
        git tag $env:RELEASE_TAG
        git push --quiet origin "refs/tags/$env:RELEASE_TAG"
        { & $workflowBlocks[0] } | Should -Throw '*tag already exists*'
        [IO.File]::ReadAllText((Join-Path $checkoutPath 'Win11Debloat.ps1')) | Should -Match '2026\.08\.24'
    }
}
