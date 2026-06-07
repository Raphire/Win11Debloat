function Test-TargetUserName {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$UserName
    )

    $normalizedUserName = if ($null -ne $UserName) { $UserName.Trim() } else { '' }

    if ([string]::IsNullOrWhiteSpace($normalizedUserName)) {
        return [PSCustomObject]@{
            IsValid = $false
            UserName = $normalizedUserName
            Message = 'Please enter a username'
        }
    }

    if ($normalizedUserName -eq $env:USERNAME) {
        return [PSCustomObject]@{
            IsValid = $false
            UserName = $normalizedUserName
            Message = "Cannot enter your own username, use 'Current User' option instead"
        }
    }

    if (-not (CheckIfUserExists -userName $normalizedUserName)) {
        return [PSCustomObject]@{
            IsValid = $false
            UserName = $normalizedUserName
            Message = 'User not found, please enter a valid username'
        }
    }

    if (TestIfUserIsLoggedIn -Username $normalizedUserName) {
        return [PSCustomObject]@{
            IsValid = $false
            UserName = $normalizedUserName
            Message = "User '$normalizedUserName' is currently logged in. Please sign out that user first."
        }
    }

    return [PSCustomObject]@{
        IsValid = $true
        UserName = $normalizedUserName
        Message = "User found: $normalizedUserName"
    }
}