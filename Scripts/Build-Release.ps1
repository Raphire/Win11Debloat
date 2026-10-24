<#
    .SYNOPSIS
        Builds versioned runtime release assets.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{4}\.\d{2}\.\d{2}(?:-r[1-9]\d*)?$')]
    [string]$Version,
    [Parameter(Mandatory)]
    [string]$OutputDirectory,
    [string]$SourcePath = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$null = [datetime]::ParseExact($Version.Substring(0, 10), 'yyyy.MM.dd', [cultureinfo]::InvariantCulture)
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
foreach ($name in 'Win11Debloat.zip', 'SHA256SUMS', 'Get.ps1') {
    if (Test-Path -LiteralPath (Join-Path $outputPath $name)) {
        throw "Output already exists: $name. Use a fresh output directory."
    }
}

$workPath = Join-Path $outputPath ('staging-' + [guid]::NewGuid().ToString('N'))
$packageName = "Win11Debloat-$Version"
$packagePath = Join-Path $workPath $packageName
$archivePath = Join-Path $outputPath 'Win11Debloat.zip'
$excludedPaths = @(
    '.git', '.github', '.gitignore', 'Tests', 'Logs', 'Backups',
    'Scripts/Build-Release.ps1', 'Scripts/Run-Tests.ps1',
    'LastUsedSettings.json', 'Config/LastUsedSettings.json'
)

# Prune excluded directories before descending, including output staged inside the source tree.
function Copy-ReleaseDirectory([string]$Path, [string]$RelativePath = '') {
    foreach ($item in Get-ChildItem -LiteralPath $Path -Force) {
        $relativeItemPath = ($RelativePath + '/' + $item.Name).TrimStart('/')
        if ($relativeItemPath -in $excludedPaths -or $item.FullName -in @($outputPath, $workPath)) { continue }
        $destination = Join-Path $packagePath $relativeItemPath
        if ($item.PSIsContainer) {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            Copy-ReleaseDirectory $item.FullName $relativeItemPath
        }
        else {
            Copy-Item -LiteralPath $item.FullName -Destination $destination
        }
    }
}

try {
    New-Item -ItemType Directory -Path $packagePath -Force | Out-Null
    Copy-ReleaseDirectory $SourcePath
    $scriptPath = Join-Path $packagePath 'Win11Debloat.ps1'
    $text = [IO.File]::ReadAllText($scriptPath)
    $versionPattern = '(?m)^\$script:Version = "[^"\r\n]+"\r?$'
    if ([regex]::Matches($text, $versionPattern).Count -ne 1) {
        throw 'Expected exactly one script version assignment.'
    }
    $text = [regex]::Replace($text, $versionPattern, ('$script:Version = "' + $Version + '"'))
    [IO.File]::WriteAllText($scriptPath, $text, [Text.UTF8Encoding]::new($true))

    Compress-Archive -LiteralPath $packagePath -DestinationPath $archivePath
    $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $outputPath 'SHA256SUMS'), "$hash  Win11Debloat.zip`n", [Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath (Join-Path $packagePath 'Scripts/Get.ps1') -Destination (Join-Path $outputPath 'Get.ps1')
}
finally {
    # Only remove this invocation's generated staging directory inside the output directory.
    $resolvedWorkPath = [IO.Path]::GetFullPath($workPath)
    if ($resolvedWorkPath.StartsWith($outputPath.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedWorkPath)) {
        Remove-Item -LiteralPath $resolvedWorkPath -Recurse -Force
    }
}
