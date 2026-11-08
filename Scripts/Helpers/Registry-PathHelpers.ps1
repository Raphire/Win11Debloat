<#
    .SYNOPSIS
        Normalizes a rooted registry path and returns its hive and subkey components.
#>
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

<#
    .SYNOPSIS
        Returns the .NET registry root key for a supported registry hive name.
#>
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

<#
    .SYNOPSIS
        Deletes a registry subkey tree and ignores a key that has already disappeared.
#>
function Remove-RegistrySubKeyTreeIfExists {
    param(
        [Parameter(Mandatory)]
        $RootKey,
        [Parameter(Mandatory)]
        [string]$SubKeyPath
    )

    try {
        $RootKey.DeleteSubKeyTree($SubKeyPath, $false)
    }
    catch {
        $failure = $_.Exception
        while ($failure.InnerException) {
            $failure = $failure.InnerException
        }
        if ($failure -is [System.ArgumentException]) {
            # The key can disappear between snapshot inspection and deletion.
            return
        }

        throw
    }
}

<#
    .SYNOPSIS
        Calls Windows' empty-only registry deletion API.
#>
function Invoke-RegistryEmptyKeyDeletion {
    param($RootKey, [string]$SubKeyPath)

    if (-not ('Win11Debloat.RegistryEmptyKey' -as [type])) {
        Add-Type -Namespace Win11Debloat -Name RegistryEmptyKey -MemberDefinition @'
        [System.Runtime.InteropServices.DllImport("shlwapi.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, ExactSpelling = true)]
        public static extern int SHDeleteEmptyKeyW(Microsoft.Win32.SafeHandles.SafeRegistryHandle hkey, string subKey);
'@
    }
    return [Win11Debloat.RegistryEmptyKey]::SHDeleteEmptyKeyW($RootKey.Handle, $SubKeyPath)
}

<#
    .SYNOPSIS
        Removes an empty key, retaining keys containing values or subkeys.
#>
function Remove-RegistryEmptyKeyIfExists {
    param(
        [Parameter(Mandatory)]$RootKey,
        [Parameter(Mandatory)][string]$SubKeyPath
    )

    $status = Invoke-RegistryEmptyKeyDeletion -RootKey $RootKey -SubKeyPath $SubKeyPath
    # Success, file not found, and path not found all satisfy cleanup.
    if ($status -in @(0, 2, 3)) { return }

    # A concurrent writer may have populated the key after the restore's initial check.
    $key = $RootKey.OpenSubKey($SubKeyPath, $false)
    if ($null -eq $key) { return }
    try {
        if (@($key.GetValueNames()).Count -gt 0 -or @($key.GetSubKeyNames()).Count -gt 0) { return }
    }
    finally {
        $key.Close()
    }

    throw (New-Object System.ComponentModel.Win32Exception -ArgumentList ([int]$status))
}

<#
    .SYNOPSIS
        Returns a feature's registry-file path, using the Sysprep layout when targeting another profile.
#>
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

