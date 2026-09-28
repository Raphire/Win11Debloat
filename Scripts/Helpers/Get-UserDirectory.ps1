. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        解析用户配置文件目录或其中的指定文件路径。
    .DESCRIPTION
        用户名为星号时，在首个存在的用户目录根路径下生成通配路径。
        其他用户名通过配置文件上下文解析。解析异常或无法找到目录时报告错误，
        并调用 Wait-ForKeyPress 以退出码 1 结束脚本。
    .PARAMETER userName
        目标用户名，星号表示用户目录通配路径。
    .PARAMETER fileName
        可选的相对文件路径；留空时返回用户目录。
    .PARAMETER exitIfPathNotFound
        默认为真；设为假且用户目录存在时，允许返回尚不存在的文件路径，
        不会抑制用户目录解析失败时的退出。
    .OUTPUTS
        System.String。解析后的目录、文件路径或包含星号的路径。
#>
function Get-UserDirectory {
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

        $userContext = Resolve-UserProfileContext -UserName $userName
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
        Write-Error (Get-ConsoleTranslation -Text 'Something went wrong when trying to find the user directory path for user {0}. Please ensure the user exists on this system' -FormatArgs @($userName))
        Wait-ForKeyPress -ExitCode 1
    }

    Write-Error (Get-ConsoleTranslation -Text 'Unable to find user directory path for user {0}' -FormatArgs @($userName))
    Wait-ForKeyPress -ExitCode 1
}
