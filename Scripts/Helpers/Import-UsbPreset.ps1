<#
    .SYNOPSIS
        Loads a USB preset and adds its validated settings to the active parameters.

    .DESCRIPTION
        Presets are data-driven so the USB launcher reuses the existing Win11Debloat
        settings, app validation, compatibility checks, backups, and apply pipeline.
#>
function Import-UsbPreset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Normal', 'Aggressive', 'Gaming')]
        [string]$PresetName
    )

    $ErrorActionPreference = 'Stop'
    $presetConfig = Import-JsonFile -filePath $script:UsbPresetsFilePath -expectedVersion '1.0'
    if (-not $presetConfig -or $presetConfig.Version -ne '1.0' -or -not $presetConfig.Presets) {
        throw "Unable to load USB presets from '$script:UsbPresetsFilePath'."
    }

    $preset = $presetConfig.Presets.$PresetName
    if (-not $preset) {
        throw "USB preset '$PresetName' is not defined."
    }

    if ($preset.SettingsFile -ne 'DefaultSettings.json' -or $preset.AppMode -ne 'Default') {
        throw "Invalid base configuration for preset '$PresetName'."
    }
    $baseSettings = Import-JsonFile -filePath $script:DefaultSettingsFilePath -expectedVersion '1.0'
    if (-not $baseSettings -or $baseSettings.Version -ne '1.0' -or -not $baseSettings.Settings) {
        throw 'Unable to load the default settings for this preset.'
    }
    $selectedSettings = @{}
    $currentBuild = [int](Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild)

    foreach ($setting in @($baseSettings.Settings) + @($preset.Settings)) {
        if (-not $setting -or $setting.Value -ne $true) {
            continue
        }

        $feature = $script:Features[[string]$setting.Name]
        if (-not $feature) {
            throw "USB preset '$PresetName' references unknown feature '$($setting.Name)'."
        }

        if ($setting.Name -in @('ForceRemoveEdge', 'DisableBitlockerAutoEncryption', 'RemoveGamingApps', 'RemoveHPApps')) {
            throw "Feature '$($setting.Name)' is not allowed in a preparation preset."
        }
        if (($feature.MinVersion -and $currentBuild -lt $feature.MinVersion) -or
            ($feature.MaxVersion -and $currentBuild -gt $feature.MaxVersion) -or
            ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and -not $script:ModernStandbySupported)) {
            continue
        }

        $selectedSettings[[string]$setting.Name] = $true
    }

    $appsJson = Import-JsonFile -filePath $script:AppsListFilePath
    if (-not $appsJson -or -not $appsJson.Apps) {
        throw "Unable to load applications from '$script:AppsListFilePath'."
    }
    $appIds = @()
    if ([string]$preset.AppMode -eq 'Default') {
        $appIds += @(Import-AppsFromFile -appsFilePath $script:AppsListFilePath)
    }

    if ($preset.AppPresets) {
        if (-not $appsJson -or -not $appsJson.Presets) {
            throw "Unable to load application presets from '$script:AppsListFilePath'."
        }

        foreach ($appPresetName in @($preset.AppPresets)) {
            $appPreset = @($appsJson.Presets | Where-Object { $_.Name -eq $appPresetName }) | Select-Object -First 1
            if (-not $appPreset) {
                throw "USB preset '$PresetName' references unknown application preset '$appPresetName'."
            }

            $appIds += @($appPreset.AppIds)
        }
    }

    $excludedAppIds = @($preset.ExcludeAppIds | ForEach-Object { [string]$_ })
    if ($excludedAppIds.Count -gt 0) {
        $appIds = @($appIds | Where-Object { $excludedAppIds -notcontains [string]$_ })
    }

    if ($PresetName -eq 'Gaming') {
        $appIds = @($appIds | Where-Object { $_ -notmatch '^Microsoft\.(Xbox|Gaming)' })
    }
    $appIds = @($appIds | Sort-Object -Unique)
    $validatedAppIds = @(Get-ValidatedAppList -appsList $appIds)
    if ($validatedAppIds.Count -ne $appIds.Count) {
        throw "Preset '$PresetName' references unsupported application IDs."
    }
    foreach ($settingName in $selectedSettings.Keys) {
        Add-Parameter $settingName $true
    }
    if ($validatedAppIds.Count -gt 0) {
        Add-Parameter 'RemoveApps'
        Add-Parameter 'Apps' ($validatedAppIds -join ',')
    }

    if (-not $script:Params.ContainsKey('CreateRestorePoint')) {
        Add-Parameter 'CreateRestorePoint'
    }

    return $preset
}
