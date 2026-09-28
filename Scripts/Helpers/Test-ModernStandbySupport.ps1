. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

<#
    .SYNOPSIS
        根据 powercfg /a 的输出判断是否支持 S0 现代待机。
    .DESCRIPTION
        在输出的首个冒号分区中找到 S0 条目时返回真，否则返回假。
        命令调用或解析抛出异常时显示错误、等待按键并返回真，以允许继续运行。
    .OUTPUTS
        System.Boolean。支持时为真；捕获到异常后的继续路径也返回真。
#>
function Test-ModernStandbySupport {
    $count = 0

    try {
        switch -Regex (powercfg /a) {
            ':' {
                $count += 1
            }

            '(.*S0.{1,}\))' {
                if ($count -eq 1) {
                    return $true
                }
            }
        }
    }
    catch {
        Write-Host (Get-ConsoleTranslation -Text 'Error: Unable to check for S0 Modern Standby support, powercfg command failed') -ForegroundColor Red
        Write-Host ""
        Write-Host (Get-ConsoleTranslation -Text 'Press any key to continue...')
        $null = [System.Console]::ReadKey()
        return $true
    }

    return $false
}
