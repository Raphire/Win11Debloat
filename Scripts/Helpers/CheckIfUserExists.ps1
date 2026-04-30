function CheckIfUserExists {
    param (
        [string]$userName
    )

    if ([string]::IsNullOrWhiteSpace($userName)) {
        return $false
    }

    $lookupName = $userName.Trim()

    # Strip DOMAIN\ prefix or @domain suffix to get the local username for character validation.
    $localUserName = $lookupName
    if ($localUserName.Contains('\')) {
        $localUserName = ($localUserName -split '\\')[-1]
    }
    if ($localUserName.Contains('@')) {
        $localUserName = ($localUserName -split '@')[0]
    }

    if ($localUserName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        return $false
    }

    # PowerShell treats [] as wildcard chars in non-literal paths; disallow them explicitly.
    if ($localUserName -match '[\[\]]') {
        return $false
    }

    try {
        $profilePath = ResolveUserProfilePath -UserName $lookupName

        if (-not $profilePath) {
            return $false
        }

        if ($lookupName -ieq 'Default') {
            return $true
        }

        $resolvedSid = ResolveUserSid -UserName $lookupName
        return -not [string]::IsNullOrWhiteSpace($resolvedSid)

    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $lookupName. Please ensure the user exists on this system"
    }

    return $false
}
