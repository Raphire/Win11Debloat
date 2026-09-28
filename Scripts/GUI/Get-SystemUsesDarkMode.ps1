<#
    .SYNOPSIS
        Returns whether Windows apps are configured to use dark mode.

    .OUTPUTS
        System.Boolean. $false when the personalization setting cannot be read.
#>
function Get-SystemUsesDarkMode {
    try {
        $personalizeKey = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

        if ($null -eq $personalizeKey) {
            Write-Host "警告：无法获取个性化设置。" -ForegroundColor Yellow
            return $false
        }

        return $personalizeKey.AppsUseLightTheme -eq 0
    }
    catch {
        return $false
    }
}
