<#
    .SYNOPSIS
        Reads saved UI theme and language preferences.

    .DESCRIPTION
        Uses Auto when no valid saved theme or language preference is available.
        UI preferences are separate from exported debloat configurations.

    .PARAMETER Path
        The preferences JSON file. Defaults to $script:UiPreferencesFilePath.

    .OUTPUTS
        System.Collections.Hashtable. Theme and Language preference values.
#>
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

<#
    .SYNOPSIS
        Saves UI preferences to a JSON file.

    .PARAMETER Preferences
        The Theme and Language preferences to save.

    .PARAMETER Path
        The destination JSON file. Defaults to $script:UiPreferencesFilePath.
#>
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

<#
    .SYNOPSIS
        Resolves the application's effective dark mode setting.

    .DESCRIPTION
        Uses the selected Light or Dark theme, or follows the Windows app theme in Auto mode.

    .OUTPUTS
        System.Boolean. Whether the application should use dark mode.
#>
function Get-AppUsesDarkMode {
    switch ($script:UiPreferences.Theme) {
        'Light' { return $false }
        'Dark' { return $true }
        default { return (Get-SystemUsesDarkMode) }
    }
}

<#
    .SYNOPSIS
        Loads the language selected by a UI preference.

    .DESCRIPTION
        Auto follows the current UI culture. Resolves the requested language to an available
        translation, falling back to English when needed.

    .PARAMETER Language
        Auto to use the current UI culture, or a language code such as nl-NL.

    .OUTPUTS
        PSCustomObject. The loaded language content, or $null when loading fails.
#>
function Get-UiLanguage {
    param([string]$Language)
    if ($Language -eq 'Auto') { return (Import-LanguageFile) }
    return (Import-LanguageFile -LanguageCode $Language)
}

<#
    .SYNOPSIS
        Initializes UI preferences and the active language.

    .DESCRIPTION
        Loads saved preferences and resolves the startup language, allowing an explicit
        language choice to override the saved preference.

    .PARAMETER Language
        An optional language preference override, including Auto. When omitted or empty,
        uses the saved language preference.
#>
function Initialize-UiPreferences {
    param([string]$Language)

    $script:UiPreferences = Get-UiPreferences
    if ($Language) { $script:UiPreferences.Language = $Language }
    $script:Lang = Get-UiLanguage -Language $script:UiPreferences.Language
    if ($script:Lang -and $script:UiPreferences.Language -ne 'Auto') {
        $script:UiPreferences.Language = $script:Lang.LanguageCode
    }
}

<#
    .SYNOPSIS
        Refreshes window themes when the application follows the Windows theme.

    .DESCRIPTION
        Keeps the window and its owned dialogs in sync with the Windows app theme when
        Auto is selected.

    .PARAMETER Window
        The window to check, along with its owned windows.
#>
function Update-AutoThemeResources {
    param([System.Windows.Window]$Window)
    if ($script:UiPreferences.Theme -ne 'Auto') { return }
    $dark = Get-SystemUsesDarkMode
    if ($Window.Resources['AppUsesDarkMode'] -ne $dark) {
        Set-WindowThemeResources -window $Window -usesDarkMode $dark
    }
    foreach ($owned in $Window.OwnedWindows) { Update-AutoThemeResources -Window $owned }
}

<#
    .SYNOPSIS
        Opens settings and applies saved presentation changes to the main window.

    .PARAMETER Window
        The main window that owns the settings dialog and receives saved changes.
#>
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
