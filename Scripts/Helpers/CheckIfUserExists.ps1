function CheckIfUserExists {
    param (
        [string]$userName
    )

    if ([string]::IsNullOrWhiteSpace($userName)) {
        return $false
    }

    $candidateUserName = $userName.Trim()

    if ($candidateUserName.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        return $false
    }

    # PowerShell treats [] as wildcard chars in non-literal paths; disallow them explicitly.
    if ($candidateUserName -match '[\[\]]') {
        return $false
    }

    try {
        # Try to find users directory via 2 methods to account for any custom user profile locations
        $rootPaths = @(
            (Join-Path $env:SystemDrive 'Users')
            (Split-Path -Path $env:USERPROFILE -Parent)
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

        $profileDirectoryExists = $false
        foreach ($rootPath in $rootPaths) {
            if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
                continue
            }

            $candidateUserPath = Join-Path $rootPath $candidateUserName
            if (Test-Path -LiteralPath $candidateUserPath -PathType Container) {
                $profileDirectoryExists = $true
                break
            }
        }

        if (-not $profileDirectoryExists) {
            return $false
        }

        $accountExists = $false

        try {
            $escapedUserName = $candidateUserName.Replace("'", "''")
            $matchingAccounts = @(Get-CimInstance -ClassName Win32_UserAccount -Filter "Name='$escapedUserName'" -ErrorAction Stop)
            $accountExists = ($matchingAccounts.Count -gt 0)
        }
        catch {
            # Fall back to local account lookup if CIM is unavailable.
            if (Get-Command -Name Get-LocalUser -ErrorAction SilentlyContinue) {
                try {
                    $null = Get-LocalUser -Name $candidateUserName -ErrorAction Stop
                    $accountExists = $true
                }
                catch {
                    $accountExists = $false
                }
            }
        }

        return $accountExists

    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $candidateUserName. Please ensure the user exists on this system"
    }

    return $false
}
