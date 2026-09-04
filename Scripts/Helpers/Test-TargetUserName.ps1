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