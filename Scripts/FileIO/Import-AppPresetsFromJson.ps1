<#
    .SYNOPSIS
        Returns preset names and application IDs from Apps.json, or an empty array when unavailable.
#>
function Import-AppPresetsFromJson {
    try {
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Warning "读取 Apps.json 失败：$_"
        return @()
    }

    if (-not $jsonContent.Presets) {
        return @()
    }

    return @($jsonContent.Presets | ForEach-Object {
        [PSCustomObject]@{
            Name   = switch ($_.Name) {
                'Xbox gaming apps' { 'Xbox 游戏应用' }
                'OEM software (Dell, HP, Lenovo, LG)' { '厂商预装软件（戴尔、惠普、联想、LG）' }
                default { $_ }
            }
            AppIds = @($_.AppIds)
        }
    })
}
