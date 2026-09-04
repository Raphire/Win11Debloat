<#
    .SYNOPSIS
        Validates a username for the "apply changes to another user" deployment target.

    .DESCRIPTION
        Rejects an empty name, the current user's own name (that's the "Current User" option
        instead), and a name with no matching local profile, in that order.

    .OUTPUTS
        PSCustomObject with IsValid (bool), UserName (the trimmed input), and Message (a
        translated string describing the validation result, success or failure alike).
#>
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
            Message = Get-Translation -Key 'UsernameValidationEmpty'
        }
    }

    if (Test-UserNameMatch -UserNameA $normalizedUserName -UserNameB $env:USERNAME) {
        return [PSCustomObject]@{
            IsValid = $false
            UserName = $normalizedUserName
            Message = Get-Translation -Key 'UsernameValidationOwnUsername'
        }
    }

    if (-not (Test-UserProfileExists -userName $normalizedUserName)) {
        return [PSCustomObject]@{
            IsValid = $false
            UserName = $normalizedUserName
            Message = Get-Translation -Key 'UsernameValidationNotFound'
        }
    }

    return [PSCustomObject]@{
        IsValid = $true
        UserName = $normalizedUserName
        Message = Get-Translation -Key 'UsernameValidationFound' -FormatArgs @($normalizedUserName)
    }
}