# Checks if the system is set to use dark mode for apps
function GetSystemUsesDarkMode {
    try {
        $personalizeKey = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

        if ($null -eq $personalizeKey) {
            Write-Host "WARNING: Unable to retrieve personalization settings." -ForegroundColor Yellow
            return $false
        }

        return $personalizeKey.AppsUseLightTheme -eq 0
    }
    catch {
        return $false
    }
}
