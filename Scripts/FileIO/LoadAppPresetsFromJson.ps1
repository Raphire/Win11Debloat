# Read Apps.json and return the list of preset objects (Name + AppIds).
# Returns an empty array if the file cannot be read or contains no presets.
function LoadAppPresetsFromJson {
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
