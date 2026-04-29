function CheckIfUserExists {
    param (
        [string]$userName
    )

    if ([string]::IsNullOrWhiteSpace($userName)) {
        return $false
    }

    $candidateUserName = $userName.Trim()

    $pathProbeName = $candidateUserName
    if ($pathProbeName.Contains('\\')) {
        $pathProbeName = ($pathProbeName -split '\\')[-1]
    }
    if ($pathProbeName.Contains('@')) {
        $pathProbeName = ($pathProbeName -split '@')[0]
    }

    if ($pathProbeName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        return $false
    }

    # PowerShell treats [] as wildcard chars in non-literal paths; disallow them explicitly.
    if ($pathProbeName -match '[\[\]]') {
        return $false
    }

    try {
        $profilePath = ResolveUserProfilePath -UserName $candidateUserName

        if (-not $profilePath) {
            return $false
        }

        if ($candidateUserName -ieq 'Default') {
            return $true
        }

        $resolvedSid = ResolveUserSid -UserName $candidateUserName
        return -not [string]::IsNullOrWhiteSpace($resolvedSid)

    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $candidateUserName. Please ensure the user exists on this system"
    }

    return $false
}
