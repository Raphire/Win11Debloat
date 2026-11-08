<#
    .SYNOPSIS
        Prints, per translated language, which keys are missing or extra compared to en-US.

    .DESCRIPTION
        Informational only: a language that lags behind en-US, or whose catalogs cannot be loaded (it is listed as
        "could not load all catalogs"), never fails the run. It exits 1 only when the script itself breaks, for example
        when the en-US baseline cannot be loaded.
        Writes Markdown to the console and, on GitHub Actions, to the job summary.

    .PARAMETER LanguageCode
        Limits the report to these language folders. Defaults to every folder except en-US.
#>
[CmdletBinding()]
param(
    [string[]]$LanguageCode
)

$ErrorActionPreference = 'Stop'
$scriptsPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'Scripts'
. (Join-Path $scriptsPath 'FileIO\Import-JsonFile.ps1')
. (Join-Path $scriptsPath 'FileIO\Import-LanguageFile.ps1')
. (Join-Path $PSScriptRoot 'Get-LanguageKeyReport.ps1')

$reports = @(Get-LanguageKeyReport -LanguageCode $LanguageCode)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('## Language key report (compared to en-US)')
$lines.Add('')
$lines.Add('| Language | Expected | Missing | Extra |')
$lines.Add('| --- | ---: | ---: | ---: |')
foreach ($report in $reports) {
    if ($report.Loaded) {
        $lines.Add("| $($report.LanguageCode) | $($report.ExpectedCount) | $($report.MissingKeys.Count) | $($report.ExtraKeys.Count) |")
    }
    else {
        $lines.Add("| $($report.LanguageCode) | could not load all catalogs | | |")
    }
}

foreach ($report in ($reports | Where-Object { $_.MissingKeys.Count -or $_.ExtraKeys.Count })) {
    foreach ($kind in 'Missing', 'Extra') {
        $keys = @($report."${kind}Keys")
        if ($keys.Count -eq 0) { continue }
        $lines.Add('')
        $lines.Add("<details><summary>$($report.LanguageCode): $($keys.Count) $($kind.ToLowerInvariant())</summary>")
        $lines.Add('')
        foreach ($key in $keys) { $lines.Add("- ``$key``") }
        $lines.Add('')
        $lines.Add('</details>')
    }
}

$lines | Write-Output
if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $lines -Encoding utf8
}
