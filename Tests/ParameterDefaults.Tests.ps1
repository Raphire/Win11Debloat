BeforeAll {
    # A default value is converted to the parameter's type when the parameter is not supplied. A hashtable
    # parameter with an array default (or an array parameter with a hashtable default) only fails at that call,
    # so it can sit unnoticed in a rarely used path.
    function Get-MismatchedParameterDefaults {
        param([string[]]$Path)

        foreach ($file in $Path) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors)
            $parseErrors | Should -BeNullOrEmpty

            foreach ($parameter in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.ParameterAst] }, $true)) {
                $default = $parameter.DefaultValue
                if ($null -eq $default) { continue }

                $type = $parameter.StaticType
                $isHashtable = $type -eq [hashtable]
                $isArray = $type.IsArray -or $type -eq [array]
                $defaultIsArray = $default -is [System.Management.Automation.Language.ArrayExpressionAst]
                $defaultIsHashtable = $default -is [System.Management.Automation.Language.HashtableAst]

                if (($isHashtable -and $defaultIsArray) -or ($isArray -and $defaultIsHashtable)) {
                    '{0}:{1} {2} = {3}' -f (Split-Path $file -Leaf), $parameter.Extent.StartLineNumber, $parameter.Name.Extent.Text, $default.Extent.Text
                }
            }
        }
    }
}

Describe 'Parameter default values' {
    It 'does not give a hashtable parameter an array default or an array parameter a hashtable default' {
        $root = Join-Path $PSScriptRoot '..'
        $files = @(Get-ChildItem -LiteralPath (Join-Path $root 'Scripts') -Filter '*.ps1' -File -Recurse | ForEach-Object { $_.FullName })
        $files += (Join-Path $root 'Win11Debloat.ps1')

        $violations = @(Get-MismatchedParameterDefaults -Path $files)

        $violations | Should -HaveCount 0 -Because ($violations -join '; ')
    }

    It 'detects a mismatched default' {
        $sample = Join-Path $TestDrive 'sample.ps1'
        Set-Content -LiteralPath $sample -Value 'function Test-Sample { param([hashtable]$A = @(), [string[]]$B = @{}, [hashtable]$C = @{}, [string[]]$D = @()) }'

        $violations = @(Get-MismatchedParameterDefaults -Path @($sample))

        $violations | Should -HaveCount 2
    }
}
