. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        Imports valid application, tweak, and deployment selections from a configuration JSON file into active parameters.
#>
function Import-ConfigToParams {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,
        [int]$CurrentBuild,
        [string]$ExpectedVersion = '1.0'
    )

    $resolvedConfigPath = $null
    try {
        $resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop).Path
    }
    catch {
        throw (Get-ConsoleTranslation -Text 'Unable to find config file at path: {0}' -FormatArgs @($ConfigPath))
    }

    if (-not (Test-Path -LiteralPath $resolvedConfigPath -PathType Leaf)) {
        throw (Get-ConsoleTranslation -Text 'Provided config path is not a file: {0}' -FormatArgs @($resolvedConfigPath))
    }

    if ([System.IO.Path]::GetExtension($resolvedConfigPath) -ne '.json') {
        throw (Get-ConsoleTranslation -Text 'Provided config file must be a .json file: {0}' -FormatArgs @($resolvedConfigPath))
    }

    $configJson = Import-JsonFile -filePath $resolvedConfigPath -expectedVersion $ExpectedVersion
    if ($null -eq $configJson) {
        throw (Get-ConsoleTranslation -Text 'Failed to read config file: {0}' -FormatArgs @($resolvedConfigPath))
    }

    $consistencyError = Test-ConfigConsistency -Config $configJson
    if ($consistencyError) {
        throw (Get-ConsoleTranslation -Text 'Invalid config file ''{0}'': {1}' -FormatArgs @($resolvedConfigPath, $consistencyError))
    }

    $importedItems = 0

    if ($configJson.Apps) {
        $appIds = @(
            $configJson.Apps | 
            Where-Object { $_ -is [string] } | 
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        
        if ($appIds.Count -gt 0) {
            Add-Parameter 'RemoveApps'
            Add-Parameter 'Apps' ($appIds -join ',')
            $importedItems++
        }
    }

    if ($configJson.Tweaks) {
        foreach ($setting in @($configJson.Tweaks)) {
            if (-not $setting -or -not $setting.Name -or $setting.Value -ne $true) {
                continue
            }

            $feature = $script:Features[$setting.Name]
            if (-not $feature) {
                continue
            }

            if (($feature.MinVersion -and $CurrentBuild -lt $feature.MinVersion) -or ($feature.MaxVersion -and $CurrentBuild -gt $feature.MaxVersion) -or ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and (-not $script:ModernStandbySupported))) {
                continue
            }

            Add-Parameter $setting.Name $true
            $importedItems++
        }
    }

    if ($configJson.Deployment) {
        $deploymentLookup = @{}
        foreach ($setting in @($configJson.Deployment)) {
            if ($setting -and $setting.Name) {
                $deploymentLookup[$setting.Name] = $setting.Value
            }
        }

        if ($deploymentLookup.ContainsKey('CreateRestorePoint') -and [bool]$deploymentLookup['CreateRestorePoint']) {
            Add-Parameter 'CreateRestorePoint'
            $importedItems++
        }

        if ($deploymentLookup.ContainsKey('SkipRegistryBackup') -and [bool]$deploymentLookup['SkipRegistryBackup']) {
            Add-Parameter 'SkipRegistryBackup'
            $importedItems++
        }

        if ($deploymentLookup.ContainsKey('RestartExplorer') -and -not [bool]$deploymentLookup['RestartExplorer']) {
            Add-Parameter 'SkipExplorerRestart'
            $importedItems++
        }

        if ($deploymentLookup.ContainsKey('UserSelectionIndex')) {
            switch ([int]$deploymentLookup['UserSelectionIndex']) {
                1 {
                    $otherUserName = if ($deploymentLookup.ContainsKey('OtherUsername')) { "$($deploymentLookup['OtherUsername'])".Trim() } else { '' }
                    if (-not [string]::IsNullOrWhiteSpace($otherUserName)) {
                        Add-Parameter 'User' $otherUserName
                        $importedItems++
                    }
                }
                2 {
                    Add-Parameter 'Sysprep'
                    $importedItems++
                }
            }
        }

        if ($deploymentLookup.ContainsKey('AppRemovalScopeIndex') -and $script:Params.ContainsKey('RemoveApps')) {
            switch ([int]$deploymentLookup['AppRemovalScopeIndex']) {
                0 {
                    Add-Parameter 'AppRemovalTarget' 'AllUsers'
                    $importedItems++
                }
                1 {
                    Add-Parameter 'AppRemovalTarget' 'CurrentUser'
                    $importedItems++
                }
                2 {
                    $targetUser = if ($deploymentLookup.ContainsKey('OtherUsername')) { "$($deploymentLookup['OtherUsername'])".Trim() } else { '' }
                    if (-not [string]::IsNullOrWhiteSpace($targetUser)) {
                        Add-Parameter 'AppRemovalTarget' $targetUser
                        $importedItems++
                    }
                }
            }
        }
    }

    if ($importedItems -eq 0) {
        throw (Get-ConsoleTranslation -Text 'The config file contains no importable data: {0}' -FormatArgs @($resolvedConfigPath))
    }

    return $resolvedConfigPath
}
