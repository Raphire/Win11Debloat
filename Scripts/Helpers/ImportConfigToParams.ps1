function ImportConfigToParams {
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
        throw "Unable to find config file at path: $ConfigPath"
    }

    if (-not (Test-Path -LiteralPath $resolvedConfigPath -PathType Leaf)) {
        throw "Provided config path is not a file: $resolvedConfigPath"
    }

    if ([System.IO.Path]::GetExtension($resolvedConfigPath) -ne '.json') {
        throw "Provided config file must be a .json file: $resolvedConfigPath"
    }

    $configJson = LoadJsonFile -filePath $resolvedConfigPath -expectedVersion $ExpectedVersion
    if ($null -eq $configJson) {
        throw "Failed to read config file: $resolvedConfigPath"
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
            AddParameter 'RemoveApps'
            AddParameter 'Apps' ($appIds -join ',')
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

            AddParameter $setting.Name $true
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
            AddParameter 'CreateRestorePoint'
            $importedItems++
        }

        if ($deploymentLookup.ContainsKey('RestartExplorer') -and -not [bool]$deploymentLookup['RestartExplorer']) {
            AddParameter 'NoRestartExplorer'
            $importedItems++
        }

        if ($deploymentLookup.ContainsKey('UserSelectionIndex')) {
            switch ([int]$deploymentLookup['UserSelectionIndex']) {
                1 {
                    $otherUserName = if ($deploymentLookup.ContainsKey('OtherUsername')) { "$($deploymentLookup['OtherUsername'])".Trim() } else { '' }
                    if (-not [string]::IsNullOrWhiteSpace($otherUserName)) {
                        AddParameter 'User' $otherUserName
                        $importedItems++
                    }
                }
                2 {
                    AddParameter 'Sysprep'
                    $importedItems++
                }
            }
        }

        if ($deploymentLookup.ContainsKey('AppRemovalScopeIndex') -and $script:Params.ContainsKey('RemoveApps')) {
            switch ([int]$deploymentLookup['AppRemovalScopeIndex']) {
                0 {
                    AddParameter 'AppRemovalTarget' 'AllUsers'
                    $importedItems++
                }
                1 {
                    AddParameter 'AppRemovalTarget' 'CurrentUser'
                    $importedItems++
                }
                2 {
                    $targetUser = if ($deploymentLookup.ContainsKey('OtherUsername')) { "$($deploymentLookup['OtherUsername'])".Trim() } else { '' }
                    if (-not [string]::IsNullOrWhiteSpace($targetUser)) {
                        AddParameter 'AppRemovalTarget' $targetUser
                        $importedItems++
                    }
                }
            }
        }
    }

    if ($importedItems -eq 0) {
        throw "The config file contains no importable data: $resolvedConfigPath"
    }

    return $resolvedConfigPath
}
