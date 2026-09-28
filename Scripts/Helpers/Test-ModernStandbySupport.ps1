# Check if this machine supports S0 Modern Standby power state. Returns true if S0 Modern Standby is supported, false otherwise.
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
        Write-Host "错误：powercfg 命令执行失败，无法检查是否支持 S0 现代待机。" -ForegroundColor Red
        Write-Host ""
        Write-Host "按任意键继续……"
        $null = [System.Console]::ReadKey()
        return $true
    }

    return $false
}
