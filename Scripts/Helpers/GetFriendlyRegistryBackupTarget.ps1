function GetFriendlyRegistryBackupTarget {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
        return 'Unknown'
    }

    if ($Target -eq 'DefaultUserProfile') {
        return 'Default user profile'
    }

    if ($Target -eq 'CurrentUser') {
        return 'Current user'
    }

    if ($Target -eq 'AllUsers') {
        return 'All users'
    }

    if ($Target -like 'CurrentUser:*') {
        $userName = $Target.Substring(12)
        if ([string]::IsNullOrWhiteSpace($userName)) {
            return 'Current user'
        }

        return "Current user ($userName)"
    }

    if ($Target -like 'User:*') {
        $userName = $Target.Substring(5)
        if ([string]::IsNullOrWhiteSpace($userName)) {
            return 'User'
        }

        return "User ($userName)"
    }

    return $Target
}