# Returns the directory path of the specified user, exits script if user path can't be found
function GetUserDirectory {
    param (
        $userName,
        $fileName = "",
        $exitIfPathNotFound = $true
    )

    try {
        if ($userName -eq "*") {
            $rootPaths = @(
                (Join-Path $env:SystemDrive 'Users')
                (Split-Path -Path $env:USERPROFILE -Parent)
            ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

            foreach ($rootPath in $rootPaths) {
                if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) {
                    continue
                }

                $wildcardPath = if ([string]::IsNullOrWhiteSpace($fileName)) {
                    Join-Path $rootPath '*'
                }
                else {
                    Join-Path (Join-Path $rootPath '*') $fileName
                }

                return $wildcardPath
            }
        }

        $userContext = ResolveUserProfileContext -UserName $userName
        $resolvedUserDirectory = if ($userContext) { $userContext.ProfilePath } else { $null }
        if ($resolvedUserDirectory) {
            $userPath = if ([string]::IsNullOrWhiteSpace($fileName)) {
                $resolvedUserDirectory
            }
            else {
                Join-Path $resolvedUserDirectory $fileName
            }

            if ((Test-Path -LiteralPath $userPath) -or ((Test-Path -LiteralPath $resolvedUserDirectory -PathType Container) -and (-not $exitIfPathNotFound))) {
                return $userPath
            }
        }
    }
    catch {
        Write-Error "Something went wrong when trying to find the user directory path for user $userName. Please ensure the user exists on this system"
        AwaitKeyToExit
    }

    Write-Error "Unable to find user directory path for user $userName"
    AwaitKeyToExit
}
