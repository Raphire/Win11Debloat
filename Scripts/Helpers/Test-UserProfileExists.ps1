. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        校验用户名并检查能否解析到本机用户配置文件。
    .DESCRIPTION
        空用户名、非法文件名字符或方括号返回假。解析结果必须包含配置文件路径，
        普通用户还必须有 SID；Default 配置文件不要求 SID。异常时报告错误并返回假。
    .PARAMETER userName
        待查询的用户名，支持本地名称、域用户名称或用户主体名称。
    .OUTPUTS
        System.Boolean。是否解析到满足上述条件的配置文件上下文。
#>
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
        Write-Error (Get-ConsoleTranslation -Text 'Something went wrong when trying to find the user directory path for user {0}. Please ensure the user exists on this system' -FormatArgs @($lookupName))
    }

    return $false
}
