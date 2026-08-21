BeforeAll {
    $script:RepoRoot = Join-Path $PSScriptRoot '..'
    $script:FeaturesPath = Join-Path $script:RepoRoot 'Config\Features.json'
    $script:Win11DebloatPath = Join-Path $script:RepoRoot 'Win11Debloat.ps1'
    $script:GetScriptPath = Join-Path $script:RepoRoot 'Scripts\Get.ps1'
    $script:RegfilesPath = Join-Path $script:RepoRoot 'Regfiles'
    $script:Features = @((Get-Content -LiteralPath $script:FeaturesPath -Raw | ConvertFrom-Json).Features)
    $script:LauncherOnlyParameters = @('Dev', 'Verbose', 'WhatIf')

    function Get-ScriptParameterNames {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty

        @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    }
}

Describe 'FeatureId parameter contracts' {
    It 'declares every FeatureId as a parameter on Win11Debloat.ps1' {
        $parameterNames = Get-ScriptParameterNames -Path $script:Win11DebloatPath
        $missing = @($script:Features.FeatureId | Where-Object { $parameterNames -notcontains $_ })

        $missing | Should -HaveCount 0 -Because ($missing -join ', ')
    }

    It 'declares every FeatureId as a parameter on Scripts/Get.ps1' {
        $parameterNames = Get-ScriptParameterNames -Path $script:GetScriptPath
        $missing = @($script:Features.FeatureId | Where-Object { $parameterNames -notcontains $_ })

        $missing | Should -HaveCount 0 -Because ($missing -join ', ')
    }

    It 'keeps Scripts/Get.ps1 aligned with Win11Debloat.ps1 plus launcher-only switches' {
        $win11DebloatParameters = Get-ScriptParameterNames -Path $script:Win11DebloatPath
        $getParameters = Get-ScriptParameterNames -Path $script:GetScriptPath
        $missingFromGet = @($win11DebloatParameters | Where-Object { $getParameters -notcontains $_ })
        $missingLauncherOnly = @(
            $script:LauncherOnlyParameters |
                Where-Object { $getParameters -notcontains $_ }
        )
        $unexpectedOnGet = @(
            $getParameters |
                Where-Object { $win11DebloatParameters -notcontains $_ -and $script:LauncherOnlyParameters -notcontains $_ }
        )

        $missingFromGet | Should -HaveCount 0 -Because ($missingFromGet -join ', ')
        $missingLauncherOnly | Should -HaveCount 0 -Because ($missingLauncherOnly -join ', ')
        $unexpectedOnGet | Should -HaveCount 0 -Because ($unexpectedOnGet -join ', ')
    }

    It 'keeps every RegistryKey file in Regfiles and Regfiles/Sysprep' {
        $missing = @(
            foreach ($feature in $script:Features) {
                if ([string]::IsNullOrWhiteSpace($feature.RegistryKey)) { continue }

                $applyPath = Join-Path $script:RegfilesPath $feature.RegistryKey
                $sysprepPath = Join-Path (Join-Path $script:RegfilesPath 'Sysprep') $feature.RegistryKey
                if (-not (Test-Path -LiteralPath $applyPath -PathType Leaf)) {
                    "$($feature.FeatureId) missing Regfiles\$($feature.RegistryKey)"
                }
                if (-not (Test-Path -LiteralPath $sysprepPath -PathType Leaf)) {
                    "$($feature.FeatureId) missing Regfiles\Sysprep\$($feature.RegistryKey)"
                }
            }
        )

        $missing | Should -HaveCount 0 -Because ($missing -join '; ')
    }

    It 'keeps every RegistryUndoKey file in Regfiles/Undo or Regfiles' {
        $missing = @(
            foreach ($feature in $script:Features) {
                if ([string]::IsNullOrWhiteSpace($feature.RegistryUndoKey)) { continue }

                $undoPath = Join-Path (Join-Path $script:RegfilesPath 'Undo') $feature.RegistryUndoKey
                $rootPath = Join-Path $script:RegfilesPath $feature.RegistryUndoKey
                if (-not ((Test-Path -LiteralPath $undoPath -PathType Leaf) -or (Test-Path -LiteralPath $rootPath -PathType Leaf))) {
                    "$($feature.FeatureId) missing undo file $($feature.RegistryUndoKey)"
                }
            }
        )

        $missing | Should -HaveCount 0 -Because ($missing -join '; ')
    }
}
