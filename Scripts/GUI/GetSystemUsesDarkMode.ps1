# Checks if the system is set to use dark mode for apps
function GetSystemUsesDarkMode {
    try {
        return (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme').AppsUseLightTheme -eq 0
    }
    catch {
        return $false
    }
}
