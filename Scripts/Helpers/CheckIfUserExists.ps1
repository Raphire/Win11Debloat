function CheckIfUserExists {
    param (
        [string]$userName
    )

    if ([string]::IsNullOrWhiteSpace($userName)) {
        return $false
    }

    $lookupName = $userName.Trim()

    # Validate special characters against the local username segment (user in DOMAIN\user or user@domain).
    $localUserName = GetLocalUserNameSegment -UserName $lookupName

    if ($localUserName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        return $false
    }

    # PowerShell treats [] as wildcard chars in non-literal paths; disallow them explicitly.
    if ($localUserName -match '[\[\]]') {
        return $false
    }

    try {
        $userContext = ResolveUserProfileContext -UserName $lookupName
        if (-not $userContext -or [string]::IsNullOrWhiteSpace($userContext.ProfilePath)) {
            return $false
        }

        if ($lookupName -ieq 'Default') {
            return $true
        }

        return -not [string]::IsNullOrWhiteSpace($userContext.UserSid)

    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $lookupName. Please ensure the user exists on this system"
    }

    return $false
}
