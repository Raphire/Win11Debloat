function Split-RegistryPath {
    param(
        [Parameter(Mandatory)]
        [string]$path
    )

    if ($path -notmatch '^(?<hive>HKEY_[^\\]+)(?:\\(?<subKey>.*))?$') {
        return $null
    }

    return [PSCustomObject]@{
        Hive = $matches.hive
        SubKey = $matches.subKey
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
