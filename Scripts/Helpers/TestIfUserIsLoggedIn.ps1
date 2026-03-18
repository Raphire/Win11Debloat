function TestIfUserIsLoggedIn {
    param(
        [Parameter(Mandatory)]
        [string]$Username
    )

    try {
        $quserOutput = @(& quser 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $quserOutput) {
            return $false
        }

        foreach ($line in ($quserOutput | Select-Object -Skip 1)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            # Remove current-session marker and split columns.
            $normalizedLine = $line.TrimStart('>', ' ')
            $parts = $normalizedLine -split '\s+'
            if ($parts.Count -eq 0) { continue }

            $sessionUser = $parts[0]
            if ([string]::IsNullOrWhiteSpace($sessionUser)) { continue }

            # Normalize possible DOMAIN\user or user@domain formats.
            if ($sessionUser.Contains('\')) {
                $sessionUser = ($sessionUser -split '\\')[-1]
            }
            if ($sessionUser.Contains('@')) {
                $sessionUser = ($sessionUser -split '@')[0]
            }

            if ($sessionUser.Equals($Username, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }
    catch {
        return $false
    }

    return $false
}
