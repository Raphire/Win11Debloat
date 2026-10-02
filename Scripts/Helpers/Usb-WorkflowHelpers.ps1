function Get-UsbWorkflowSelection {
    param([string]$Choice)

    switch ($Choice) {
        '1' { return @{ Preset = 'Normal' } }
        '2' { return @{ Preset = 'Aggressive' } }
        '3' { return @{ Preset = 'Gaming' } }
        '4' { return @{} }
        '5' { return @{ SetWallpaper = $true } }
        '6' { return @{ RestoreBackup = $true } }
        '7' { return @{ RestoreWallpaper = $true } }
        '0' { return @{ Exit = $true } }
        default { return $null }
    }
}

function Get-UsbWallpaperChoices {
    param([string]$Directory)

    $choices = @([PSCustomObject]@{ Name = 'Czarna tapeta'; Path = 'Black' })
    $choices += @(Get-ChildItem -LiteralPath $Directory -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.jpg', '.jpeg', '.png', '.bmp') } |
        Sort-Object Name |
        ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Path = $_.FullName } })
    return $choices
}

function ConvertTo-UsbProcessArgument {
    param([AllowEmptyString()][string]$Value)

    $escaped = $Value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Get-UsbWorkflowExitCode {
    if ($script:CancelRequested -or -not $script:UsbApplyStarted) { return 3 }
    if ($script:ApplyModalInErrorState -or $script:FeatureFailures -gt 0 -or
        $script:AppRemovalFailures -gt 0 -or $script:RegistryImportFailures -gt 0) { return 1 }
    if ($script:AppRemovalVerificationUnavailable) { return 2 }
    return 0
}
