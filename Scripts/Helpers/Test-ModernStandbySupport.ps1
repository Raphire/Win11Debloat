. (Join-Path $PSScriptRoot '../FileIO/获取控制台翻译.ps1')

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
        Write-Host (Get-ConsoleTranslation -Text 'Error: Unable to check for S0 Modern Standby support, powercfg command failed') -ForegroundColor Red
        Write-Host ""
        Write-Host (Get-ConsoleTranslation -Text 'Press any key to continue...')
        $null = [System.Console]::ReadKey()
        return $true
    }

    return $false
}
