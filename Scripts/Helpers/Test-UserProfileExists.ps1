function Test-UserProfileExists {
    param (
        [string]$userName
    )

    if ([string]::IsNullOrWhiteSpace($userName)) {
        return $false
    }

    $lookupName = $userName.Trim()

    # Validate special characters against the local username segment (user in DOMAIN\user or user@domain).
    $localUserName = Get-LocalUserNameSegment -UserName $lookupName

    if ($localUserName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        return $false
    }

    # PowerShell treats [] as wildcard chars in non-literal paths; disallow them explicitly.
    if ($localUserName -match '[\[\]]') {
        return $false
    }

    try {
        $userContext = Resolve-UserProfileContext -UserName $lookupName
        if (-not $userContext -or [string]::IsNullOrWhiteSpace($userContext.ProfilePath)) {
            return $false
        }

        if ($lookupName -ieq 'Default') {
            return $true
        }

        return -not [string]::IsNullOrWhiteSpace($userContext.UserSid)

    }
    catch {
        Write-Error "查找用户 $lookupName 的目录时发生错误，请确认该用户存在于此系统中。"
    }

    return $false
}
