. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        Returns preset names and application IDs from Apps.json, or an empty array when unavailable.
#>
function Import-AppPresetsFromJson {
    try {
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Warning (Get-ConsoleTranslation -Text 'Failed to read Apps.json: {0}' -FormatArgs @($_))
        return @()
    }

    if (-not $jsonContent.Presets) {
        return @()
    }

    return @($jsonContent.Presets | ForEach-Object {
        [PSCustomObject]@{
            Name   = Get-ConsoleTranslation -Text $_.Name
            AppIds = @($_.AppIds)
        }
    })
}
