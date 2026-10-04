# UI preferences are separate from exported debloat configurations.
function Get-UiPreferences {
    param([string]$Path = $script:UiPreferencesFilePath)
    $preferences = @{ Theme = 'Auto'; Language = 'Auto' }
    if (Test-Path -LiteralPath $Path) {
        try {
            $saved = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($saved.Theme -in @('Auto', 'Light', 'Dark')) { $preferences.Theme = $saved.Theme }
            if ($saved.Language -eq 'Auto' -or $saved.Language -match '^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})+$') {
                $preferences.Language = $saved.Language
            }
        }
        catch { Write-Warning "Unable to read UI preferences: $($_.Exception.Message)" }
    }
    return $preferences
}

function Save-UiPreferences {
    param(
        [Parameter(Mandatory)]$Preferences,
        [string]$Path = $script:UiPreferencesFilePath
    )
    $directory = Split-Path -Parent $Path
    [void][System.IO.Directory]::CreateDirectory($directory)
    $temporaryPath = "$Path.tmp"
    try {
        $Preferences | ConvertTo-Json | Set-Content -LiteralPath $temporaryPath -Encoding UTF8 -ErrorAction Stop
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
    }
}

function Get-AppUsesDarkMode {
    switch ($script:UiPreferences.Theme) {
        'Light' { return $false }
        'Dark' { return $true }
        default { return (Get-SystemUsesDarkMode) }
    }
}

function Get-UiLanguage {
    param([string]$Language)
    if ($Language -eq 'Auto') { return (Import-LanguageFile) }
    return (Import-LanguageFile -LanguageCode $Language)
}

function Initialize-UiPreferences {
    param([string]$Language)

    $script:UiPreferences = Get-UiPreferences
    if ($Language) { $script:UiPreferences.Language = $Language }
    $script:Lang = Get-UiLanguage -Language $script:UiPreferences.Language
    if ($script:Lang -and $script:UiPreferences.Language -ne 'Auto') {
        $script:UiPreferences.Language = $script:Lang.LanguageCode
    }
}

function Update-AutoThemeResources {
    param([System.Windows.Window]$Window)
    if ($script:UiPreferences.Theme -ne 'Auto') { return }
    $dark = Get-SystemUsesDarkMode
    if ($Window.Resources['AppUsesDarkMode'] -ne $dark) {
        Set-WindowThemeResources -window $Window -usesDarkMode $dark
    }
    foreach ($owned in $Window.OwnedWindows) { Update-AutoThemeResources -Window $owned }
}

function Open-MainWindowSettings {
    param([System.Windows.Window]$Window)
    if ($script:IsLoadingApps) { return }
    $previousLanguageCode = $script:Lang.LanguageCode
    if (Show-SettingsDialog -Owner $Window) {
        Set-WindowThemeResources -window $Window -usesDarkMode (Get-AppUsesDarkMode)
        if ($script:Lang.LanguageCode -ne $previousLanguageCode) {
            Update-MainWindowLanguage -Window $Window
        }
    }
}
