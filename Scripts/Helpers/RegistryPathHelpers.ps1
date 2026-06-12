function Split-RegistryPath {
    param(
        [Parameter(Mandatory)]
        [string]$path
    )

    $normalizedPath = [string]$path
    if ([string]::IsNullOrWhiteSpace($normalizedPath)) {
        return $null
    }

    $normalizedPath = $normalizedPath.Trim().Replace('/', '\')
    if ([string]::IsNullOrWhiteSpace($normalizedPath)) {
        return $null
    }

    if ($normalizedPath -notmatch '^(?<hive>HKEY_[^\\]+)(?:\\(?<subKey>.*))?$') {
        return $null
    }

    $hiveName = [string]$matches.hive

    $normalizedSubKey = if ($null -ne $matches.subKey) {
        ([string]$matches.subKey).Trim('\\')
    }
    else {
        $null
    }

    if ($hiveName.Equals('HKEY_USERS', [System.StringComparison]::OrdinalIgnoreCase) -and
        -not [string]::IsNullOrWhiteSpace($normalizedSubKey) -and
        -not [string]::IsNullOrWhiteSpace([string]$script:RegistryTargetHiveMountName)) {
        if ($normalizedSubKey -match '^(?<mount>[^\\]+)(?:\\(?<rest>.*))?$') {
            $mountName = [string]$matches.mount
            if ($mountName.Equals('Default', [System.StringComparison]::OrdinalIgnoreCase)) {
                $remainingSubKey = if ($matches.rest) { [string]$matches.rest } else { '' }
                $targetMountName = [string]$script:RegistryTargetHiveMountName
                if ([string]::IsNullOrWhiteSpace($remainingSubKey)) {
                    $normalizedSubKey = $targetMountName
                }
                else {
                    $normalizedSubKey = "$targetMountName\$remainingSubKey"
                }
            }
        }
    }

    return [PSCustomObject]@{
        Hive = $hiveName
        SubKey = $normalizedSubKey
    }
}

function Get-RegistryRootKey {
    param(
        [Parameter(Mandatory)]
        [string]$hiveName
    )

    switch ($hiveName.ToUpperInvariant()) {
        'HKEY_CURRENT_USER' { return [Microsoft.Win32.Registry]::CurrentUser }
        'HKEY_LOCAL_MACHINE' { return [Microsoft.Win32.Registry]::LocalMachine }
        'HKEY_CLASSES_ROOT' { return [Microsoft.Win32.Registry]::ClassesRoot }
        'HKEY_USERS' { return [Microsoft.Win32.Registry]::Users }
        'HKEY_CURRENT_CONFIG' { return [Microsoft.Win32.Registry]::CurrentConfig }
        default { return $null }
    }
}

function Get-RegistryFilePathForFeature {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryKey,
        [switch]$UseSysprepRegFiles
    )

    $useSysprepLayout = $UseSysprepRegFiles -or $script:Params.ContainsKey('Sysprep') -or $script:Params.ContainsKey('User')
    if ($useSysprepLayout) {
        return Join-Path (Join-Path $script:RegfilesPath 'Sysprep') $RegistryKey
    }

    return Join-Path $script:RegfilesPath $RegistryKey
}

function Get-GpoOverrideWarning {
    param(
        [string]$KeyPath,
        [string]$ValueName
    )

    if ([string]::IsNullOrWhiteSpace($ValueName)) {
        return $null
    }

    # Common GPO policy registry roots in PowerShell provider syntax
    $gpoPaths = @(
        "Registry::HKEY_LOCAL_MACHINE\Software\Policies",
        "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies",
        "Registry::HKEY_CURRENT_USER\Software\Policies",
        "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies"
    )

    $parts = Split-RegistryPath -path $KeyPath
    if (-not $parts) {
        return $null
    }

    $subKey = $parts.SubKey
    if ([string]::IsNullOrWhiteSpace($subKey)) {
        return $null
    }

    # Normalize subkey path by stripping leading Software\
    $cleanSubKey = $subKey -replace '^Software\\', ''

    foreach ($gpoRoot in $gpoPaths) {
        # Build candidate paths mapping common structures
        $candidatePaths = @(
            "$gpoRoot\$cleanSubKey",
            "$gpoRoot\" + ($cleanSubKey -replace '^Microsoft\\Windows\\CurrentVersion\\', ''),
            "$gpoRoot\" + ($cleanSubKey -replace '^Microsoft\\', '')
        )

        foreach ($p in $candidatePaths) {
            if (Test-Path -LiteralPath $p) {
                try {
                    $val = Get-ItemPropertyValue -LiteralPath $p -Name $ValueName -ErrorAction SilentlyContinue
                    if ($null -ne $val) {
                        return "Group Policy (GPO) override detected at '$p' for value '$ValueName' (Value: $val). This policy may override your debloat changes."
                    }
                }
                catch {}
            }
        }
    }

    return $null
}

