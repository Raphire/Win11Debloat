function ResolveUserSid {
    param(
        [Parameter(Mandatory)]
        [string]$UserName
    )

    $candidateUserName = $UserName.Trim()
    if ([string]::IsNullOrWhiteSpace($candidateUserName)) {
        return $null
    }

    try {
        $escapedUserName = $candidateUserName.Replace("'", "''")
        $matchingAccounts = @(Get-CimInstance -ClassName Win32_UserAccount -Filter "Name='$escapedUserName'" -ErrorAction Stop)
        if ($matchingAccounts.Count -gt 0) {
            $localAccount = $matchingAccounts | Where-Object { $_.LocalAccount -eq $true } | Select-Object -First 1
            if ($localAccount) {
                return $localAccount.SID
            }

            return $matchingAccounts[0].SID
        }
    }
    catch {
        # Fallback handled below.
    }

    if (Get-Command -Name Get-LocalUser -ErrorAction SilentlyContinue) {
        try {
            $localUser = Get-LocalUser -Name $candidateUserName -ErrorAction Stop
            if ($localUser -and $localUser.SID) {
                return $localUser.SID.Value
            }
        }
        catch {
            # No local account match.
        }
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

    $candidateUserName = $UserName.Trim()
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
        $profileListPath = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$userSid"
        try {
            if (Test-Path -LiteralPath $profileListPath) {
                $profileImagePath = (Get-ItemProperty -LiteralPath $profileListPath -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
                if (-not [string]::IsNullOrWhiteSpace($profileImagePath)) {
                    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($profileImagePath)
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
            $profile = $matchingProfiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LocalPath) } | Select-Object -First 1
            if ($profile -and (Test-Path -LiteralPath $profile.LocalPath -PathType Container)) {
                return $profile.LocalPath
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