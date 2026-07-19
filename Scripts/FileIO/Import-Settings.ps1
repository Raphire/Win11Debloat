<#
    .SYNOPSIS
        Imports enabled, compatible feature settings from a JSON file into the active parameters.
#>
function Import-Settings {
    param (
        [string]$filePath,
        [string]$expectedVersion = "1.0"
    )
    
    $settingsJson = Import-JsonFile -filePath $filePath -expectedVersion $expectedVersion
    
    if (-not $settingsJson -or -not $settingsJson.Settings) {
        throw "Failed to load settings from $(Split-Path $filePath -Leaf)"
    }

    # Get current Windows build version
    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
    
    foreach ($setting in $settingsJson.Settings) {
        if ($setting.Value -eq $false) {
            continue
        }

        $feature = $script:Features[$setting.Name]

        # Skip unknown settings that aren't defined in Features.json
        if (-not $feature) { continue }

        # Check version and feature compatibility using Features.json
        if (($feature.MinVersion -and $WinVersion -lt $feature.MinVersion) -or ($feature.MaxVersion -and $WinVersion -gt $feature.MaxVersion) -or ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and (-not $script:ModernStandbySupported))) {
           continue
        }
        
        Add-Parameter $setting.Name $setting.Value
    }
}
