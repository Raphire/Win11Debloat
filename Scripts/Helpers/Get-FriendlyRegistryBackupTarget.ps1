<#
    .SYNOPSIS
        Converts a registry-backup target identifier into a user-friendly label.
#>
function Get-FriendlyRegistryBackupTarget {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
        return Get-Translation -Key 'RestoreTargetUnknown'
    }

    if ($Target -eq 'DefaultUserProfile') {
        return Get-Translation -Key 'RestoreTargetDefaultUserProfile'
    }

    if ($Target -eq 'CurrentUser') {
        return Get-Translation -Key 'RestoreTargetCurrentUser'
    }

    if ($Target -eq 'AllUsers') {
        return Get-Translation -Key 'RestoreTargetAllUsers'
    }

    if ($Target -like 'CurrentUser:*') {
        $userName = $Target.Substring(12)
        if ([string]::IsNullOrWhiteSpace($userName)) {
            return Get-Translation -Key 'RestoreTargetCurrentUser'
        }

        return Get-Translation -Key 'RestoreTargetCurrentUserNamed' -FormatArgs @($userName)
    }

    if ($Target -like 'User:*') {
        $userName = $Target.Substring(5)
        if ([string]::IsNullOrWhiteSpace($userName)) {
            return Get-Translation -Key 'RestoreTargetUser'
        }

        return Get-Translation -Key 'RestoreTargetUserNamed' -FormatArgs @($userName)
    }

    return $Target
}
