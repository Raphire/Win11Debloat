<#
    .SYNOPSIS
        Returns preset names and application IDs from Apps.json, or an empty array when unavailable.
#>
function Import-AppPresetsFromJson {
    try {
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Warning "Failed to read Apps.json: $_"
        return @()
    }

    if (-not $jsonContent.Presets) {
        return @()
    }

    return @($jsonContent.Presets | ForEach-Object {
        [PSCustomObject]@{
            Name   = $_.Name
            AppIds = @($_.AppIds)
        }
    })
}
