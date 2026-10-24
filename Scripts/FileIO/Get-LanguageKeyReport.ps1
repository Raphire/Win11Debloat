<#
    .SYNOPSIS
        Lists the keys each translated language is missing or carries extra, compared to en-US.

    .DESCRIPTION
        Plural-aware: a plural family in en-US (for example AppSelectionStatusSelected_one and _other) is expected in
        each language as one key per category that language's Get-PluralCategory rule can return, so ja-JP is not
        reported missing its _one keys and pt-BR is not reported for having _many. A shipped _other key is always allowed. Requires Import-LanguageFile.ps1.
        Reports only; it never changes a language folder.

    .PARAMETER LanguagesPath
        The directory containing language folders. Defaults to Config/Languages.

    .PARAMETER LanguageCode
        Limits the report to these language folders. Defaults to every folder except en-US.

    .OUTPUTS
        PSCustomObject per language: LanguageCode, Loaded, ExpectedCount, MissingKeys, ExtraKeys.
#>
function Get-LanguageKeyReport {
    param(
        [string]$LanguagesPath = (Join-Path $PSScriptRoot '..\..\Config\Languages'),
        [string[]]$LanguageCode
    )

    $baseline = Import-LanguageContent -LanguageFolder 'en-US' -LanguagesPath $LanguagesPath
    if (-not $baseline) {
        throw "Unable to load the en-US baseline from '$LanguagesPath'."
    }

    $pluralPattern = '^([^.]+)_(zero|one|two|few|many|other)$'
    $plainKeys = @()
    $pluralBases = @()
    foreach ($key in (Get-LanguageKeyPaths -Lang $baseline)) {
        if ($key -match $pluralPattern) { $pluralBases += $Matches[1] } else { $plainKeys += $key }
    }
    $pluralBases = @($pluralBases | Sort-Object -Unique)

    # Counts that reach every category of the shipped rules, including the whole-million 'many' of Portuguese.
    $sampleCounts = @(0..1000) + @(1000000, 1000001, 2000000)

    if (-not $LanguageCode) {
        $LanguageCode = @(Get-ChildItem -LiteralPath $LanguagesPath -Directory | Where-Object Name -ne 'en-US' |
            Sort-Object Name | Select-Object -ExpandProperty Name)
    }

    foreach ($code in $LanguageCode) {
        $content = Import-LanguageContent -LanguageFolder $code -LanguagesPath $LanguagesPath
        if (-not $content) {
            [PSCustomObject]@{ LanguageCode = $code; Loaded = $false; ExpectedCount = 0; MissingKeys = @(); ExtraKeys = @() }
            continue
        }

        $categories = @($sampleCounts | ForEach-Object { Get-PluralCategory -LanguageCode $code -Count $_ } | Sort-Object -Unique)
        $expected = [System.Collections.Generic.HashSet[string]]::new([string[]]@(
            $plainKeys + @($pluralBases | ForEach-Object { $base = $_; $categories | ForEach-Object { "${base}_$_" } })
        ))
        # CLDR gives every language an 'other' category (fractions), so shipping it is allowed even when the rule never returns it.
        $allowed = [System.Collections.Generic.HashSet[string]]::new($expected)
        foreach ($base in $pluralBases) { [void]$allowed.Add("${base}_other") }
        $actual = [System.Collections.Generic.HashSet[string]]::new([string[]](Get-LanguageKeyPaths -Lang $content))

        [PSCustomObject]@{
            LanguageCode  = $code
            Loaded        = $true
            ExpectedCount = $expected.Count
            MissingKeys   = @($expected | Where-Object { -not $actual.Contains($_) } | Sort-Object)
            ExtraKeys     = @($actual | Where-Object { -not $allowed.Contains($_) } | Sort-Object)
        }
    }
}
