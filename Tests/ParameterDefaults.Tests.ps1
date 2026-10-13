BeforeAll {
    # A default value is converted to the parameter's type when the parameter is not supplied. An empty array
    # cannot be converted to a hashtable, so a [hashtable] parameter with an array default fails at the call that
    # leaves it out and can sit unnoticed in a rarely used path. (The reverse is fine: PowerShell converts a
    # hashtable default to a one-element array for [string[]], [object[]] and [array].)
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

                $isHashtable = $parameter.StaticType -eq [hashtable]
                $defaultExpression = $default
                while ($defaultExpression -is [System.Management.Automation.Language.ParenExpressionAst]) {
                    $defaultExpression = $defaultExpression.Pipeline.GetPureExpression()
                }
                $defaultIsArray = $defaultExpression -is [System.Management.Automation.Language.ArrayExpressionAst] -or
                    $defaultExpression -is [System.Management.Automation.Language.ArrayLiteralAst]

                if ($isHashtable -and $defaultIsArray) {
                    '{0}:{1} {2} = {3}' -f (Split-Path $file -Leaf), $parameter.Extent.StartLineNumber, $parameter.Name.Extent.Text, $default.Extent.Text
                }
            }
        }
    }
}

Describe 'Parameter default values' {
    It 'does not give a hashtable parameter an array default' {
        $root = Join-Path $PSScriptRoot '..'
        $files = @(Get-ChildItem -LiteralPath (Join-Path $root 'Scripts') -Filter '*.ps1' -File -Recurse | ForEach-Object { $_.FullName })
        $files += (Join-Path $root 'Win11Debloat.ps1')

        $violations = @(Get-MismatchedParameterDefaults -Path $files)

        $violations | Should -HaveCount 0 -Because ($violations -join '; ')
    }

    It 'detects a mismatched default' {
        $sample = Join-Path $TestDrive 'sample.ps1'
        Set-Content -LiteralPath $sample -Value 'function Test-Sample { param([hashtable]$A = @(), [hashtable]$B = @{}, [string[]]$C = @(), [string[]]$D = @{}, [hashtable]$E = (1, 2)) }'

        $violations = @(Get-MismatchedParameterDefaults -Path @($sample))

        $violations | Should -HaveCount 2
        $violations | Should -Contain 'sample.ps1:1 $A = @()'
        $violations | Should -Contain 'sample.ps1:1 $E = (1, 2)'
    }
}
