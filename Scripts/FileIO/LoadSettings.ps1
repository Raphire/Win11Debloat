# Loads settings from a JSON file and adds them to script params
function LoadSettings {
    param (
        [string]$filePath,
        [string]$expectedVersion = "1.0"
    )
    
    $settingsJson = LoadJsonFile -filePath $filePath -expectedVersion $expectedVersion
    
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

        # Check version and feature compatibility using Features.json
        if (($feature.MinVersion -and $WinVersion -lt $feature.MinVersion) -or ($feature.MaxVersion -and $WinVersion -gt $feature.MaxVersion) -or ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and (-not $script:ModernStandbySupported))) {
           continue
        }
        
        AddParameter $setting.Name $setting.Value
    }
}
