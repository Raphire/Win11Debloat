function New-RegistrySettingsBackup {
    param(
        [string[]]$ActionableKeys
    )

    $ActionableKeys = @($ActionableKeys)
    $selectedFeatures = Get-SelectedFeatures -ActionableKeys $ActionableKeys
    if (@($selectedFeatures | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.RegistryKey) }).Count -eq 0) {
        return $null
    }

    $timestamp = Get-Date
    $backupDirectory = $script:RegistryBackupsPath
    if (-not (Test-Path $backupDirectory)) {
        New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    }

    $backupFileName = 'Win11Debloat-RegistryBackup-{0}.json' -f $timestamp.ToString('yyyyMMdd_HHmmss')
    $backupFilePath = Join-Path $backupDirectory $backupFileName

    $backupConfig = Get-RegistryBackupPayload -SelectedFeatures $selectedFeatures -CreatedAt $timestamp
    if (-not (SaveToFile -Config $backupConfig -FilePath $backupFilePath -MaxDepth 25)) {
        throw "Failed to save registry backup to '$backupFilePath'"
    }

    Write-Host "Backup successfully created: $backupFilePath"
    Write-Host ""

    return $backupFilePath
}

function Get-SelectedFeatures {
    param(
        [string[]]$ActionableKeys
    )

    $selectedFeatures = New-Object System.Collections.Generic.List[object]
    $selectedFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($paramKey in $ActionableKeys) {
        if (-not $script:Features.ContainsKey($paramKey)) { continue }

        $feature = $script:Features[$paramKey]
        if (-not $feature) { continue }

        $featureId = Get-FeatureId -Feature $feature

        if ($selectedFeatureIds.Add($featureId)) {
            $selectedFeatures.Add($feature)
        }
    }

    return @($selectedFeatures.ToArray())
}

function Get-RegistryBackupPayload {
    param(
        [Parameter(Mandatory)]
        [object[]]$SelectedFeatures,
        [Parameter(Mandatory)]
        [datetime]$CreatedAt
    )

    $selectedFeatureIds = New-Object System.Collections.Generic.List[string]
    $seenSelectedFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($feature in $SelectedFeatures) {
        $featureId = Get-FeatureId -Feature $feature

        if ($seenSelectedFeatureIds.Add($featureId)) {
            $selectedFeatureIds.Add($featureId)
        }
    }

    $selectedRegistryFeatures = Get-RegistryBackedFeatures -Features $SelectedFeatures
    $capturePlans = Get-RegistryBackupCapturePlans -SelectedRegistryFeatures $SelectedRegistryFeatures
    $registryKeys = @(Get-RegistrySnapshotsForBackup -CapturePlans $capturePlans)

    return @{
        Version = '1.0'
        BackupType = 'RegistryState'
        CreatedAt = $CreatedAt.ToString('o')
        CreatedBy = 'Win11Debloat'
        Target = (Get-RegistryBackupTargetDescription)
        ComputerName = $env:COMPUTERNAME
        SelectedFeatures = @($selectedFeatureIds)
        RegistryKeys = @($registryKeys)
    }
}
