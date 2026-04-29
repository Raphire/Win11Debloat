function NormalizeUserLookupValue {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    # Remove zero-width characters and normalize whitespace for robust comparisons.
    $normalized = $Value -replace '[\u200B-\u200D\uFEFF]', ''
    $normalized = $normalized.Trim() -replace '\s+', ' '
    return $normalized
}

function ResolveUserSid {
    param(
        [Parameter(Mandatory)]
        [string]$UserName
    )

    $candidateUserName = NormalizeUserLookupValue -Value $UserName
    if ([string]::IsNullOrWhiteSpace($candidateUserName)) {
        return $null
    }

    $nameCandidates = @($candidateUserName)
    if ($candidateUserName.Contains('\')) {
        $nameCandidates += (NormalizeUserLookupValue -Value (($candidateUserName -split '\\')[-1]))
    }
    if ($candidateUserName.Contains('@')) {
        $nameCandidates += (NormalizeUserLookupValue -Value (($candidateUserName -split '@')[0]))
    }
    $nameCandidates = $nameCandidates | ForEach-Object { NormalizeUserLookupValue -Value $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    if (Get-Command -Name Get-LocalUser -ErrorAction SilentlyContinue) {
        try {
            $localUsers = @(Get-LocalUser)
            foreach ($candidate in $nameCandidates) {
                $matchingLocalUser = $localUsers | Where-Object {
                    ((NormalizeUserLookupValue -Value $_.Name) -eq $candidate) -or
                    ((NormalizeUserLookupValue -Value $_.FullName) -eq $candidate)
                } | Select-Object -First 1

                if ($matchingLocalUser -and $matchingLocalUser.SID) {
                    return $matchingLocalUser.SID.Value
                }
            }
        }
        catch {
            # Fallback handled below.
        }
    }

    try {
        $matchingAccounts = @(Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount=True" -ErrorAction Stop)
        foreach ($candidate in $nameCandidates) {
            $matchingAccount = $matchingAccounts | Where-Object {
                ((NormalizeUserLookupValue -Value $_.Name) -eq $candidate) -or
                ((NormalizeUserLookupValue -Value $_.FullName) -eq $candidate) -or
                ((NormalizeUserLookupValue -Value $_.Caption) -eq (NormalizeUserLookupValue -Value "$env:COMPUTERNAME\$candidate"))
            } | Select-Object -First 1

            if ($matchingAccount -and $matchingAccount.SID) {
                return $matchingAccount.SID
            }
        }
    }
    catch {
        # Fallback handled below.
    }

    return $null
}

function ResolveUserProfilePath {
    param(
        [Parameter(Mandatory)]
        [string]$UserName
    )

    if ([string]::IsNullOrWhiteSpace($UserName)) {
        return $null
    }

    $candidateUserName = NormalizeUserLookupValue -Value $UserName
    $rootPaths = @(
        (Join-Path $env:SystemDrive 'Users')
        (Split-Path -Path $env:USERPROFILE -Parent)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    if ($candidateUserName -ieq 'Default') {
        foreach ($rootPath in $rootPaths) {
            if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
                continue
            }

            $defaultProfilePath = Join-Path $rootPath 'Default'
            if (Test-Path -LiteralPath $defaultProfilePath -PathType Container) {
                return $defaultProfilePath
            }
        }

        return $null
    }

    $userSid = ResolveUserSid -UserName $candidateUserName

    if ($userSid) {
        $sidRegistryPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$userSid"
        try {
            if (Test-Path -LiteralPath $sidRegistryPath) {
                $registryImagePath = Get-ItemPropertyValue -LiteralPath $sidRegistryPath -Name 'ProfileImagePath' -ErrorAction Stop
                if (-not [string]::IsNullOrWhiteSpace($registryImagePath)) {
                    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($registryImagePath)
                    if (Test-Path -LiteralPath $expandedPath -PathType Container) {
                        return $expandedPath
                    }
                }
            }
        }
        catch {
            # Try Win32_UserProfile fallback.
        }

        try {
            $matchingProfiles = @(Get-CimInstance -ClassName Win32_UserProfile -Filter "SID='$userSid'" -ErrorAction Stop)
            $resolvedProfile = $matchingProfiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LocalPath) } | Select-Object -First 1
            if ($resolvedProfile -and (Test-Path -LiteralPath $resolvedProfile.LocalPath -PathType Container)) {
                return $resolvedProfile.LocalPath
            }
        }
        catch {
            # Fall through to legacy path probing.
        }
    }

    foreach ($rootPath in $rootPaths) {
        if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
            continue
        }

        $candidateUserPath = Join-Path $rootPath $candidateUserName
        if (Test-Path -LiteralPath $candidateUserPath -PathType Container) {
            return $candidateUserPath
        }
    }

    return $null
}