<#
    .SYNOPSIS
        Shows the modal theme and language settings dialog.

    .DESCRIPTION
        Lets users choose a theme and language. Changes take effect only after Save;
        closing without saving discards edits. Displays an error if saving fails.

    .PARAMETER Owner
        The window that owns the settings dialog.

    .OUTPUTS
        System.Boolean. $true when changed preferences were saved; $false when closed
        without changes or without saving.
#>
function Show-SettingsDialog {
    param([Parameter(Mandatory)][System.Windows.Window]$Owner)
    $path = Join-Path (Split-Path $script:MainWindowSchema -Parent) 'SettingsWindow.xaml'
    $xaml = ConvertTo-LocalizedXaml -Xaml (Get-Content -LiteralPath $path -Raw)
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try { $dialog = [System.Windows.Markup.XamlReader]::Load($reader) }
    finally { $reader.Close() }
    $dialog.Owner = $Owner
    Set-WindowThemeResources -window $dialog -usesDarkMode (Get-AppUsesDarkMode)
    $dialog.Tag = $false
    $overlay = $Owner.FindName('ModalOverlay')
    $languageCombo = $dialog.FindName('SettingsLanguageCombo')
    $auto = [System.Windows.Controls.ComboBoxItem]::new()
    $auto.Content = Get-Translation -Key 'SettingsLanguageAuto'
    $auto.Tag = 'Auto'
    [void]$languageCombo.Items.Add($auto)
    foreach ($folder in (Get-AvailableLanguageFolders)) {
        $item = [System.Windows.Controls.ComboBoxItem]::new()
        try {
            $culture = [System.Globalization.CultureInfo]::GetCultureInfo($folder.Name)
            $name = $culture.NativeName
            $item.Content = $culture.TextInfo.ToUpper($name.Substring(0, 1)) + $name.Substring(1)
        }
        catch { $item.Content = $folder.Name }
        $item.Tag = $folder.Name
        [void]$languageCombo.Items.Add($item)
    }
    foreach ($item in $languageCombo.Items) {
        if ($item.Tag -eq $script:UiPreferences.Language) { $languageCombo.SelectedItem = $item; break }
    }

    # Event handlers share the pending value without changing saved preferences.
    $pendingTheme = [ref]([string]$script:UiPreferences.Theme)
    $savePreferences = {
        $theme = $pendingTheme.Value
        $language = [string]$languageCombo.SelectedItem.Tag
        if ($theme -eq $script:UiPreferences.Theme -and $language -eq $script:UiPreferences.Language) { $dialog.Close(); return }
        try {
            $lang = if ($language -eq $script:UiPreferences.Language) { $script:Lang } else { Get-UiLanguage -Language $language }
            if (-not $lang) { throw 'Unable to load language.' }
            if ($language -ne 'Auto' -and $lang.LanguageCode -ne $language) { throw 'The selected language could not be loaded.' }
            $preferences = @{ Theme = $theme; Language = $language }
            Save-UiPreferences -Preferences $preferences
            $script:UiPreferences = $preferences
            $script:Lang = $lang
            $dialog.Tag = $true
            $dialog.Close()
        }
        catch {
            $errorText = $dialog.FindName('SettingsErrorText')
            $errorText.Text = Get-Translation -Key 'SettingsSaveError'
            $errorText.Visibility = 'Visible'
            Write-Warning "Unable to update UI preferences: $($_.Exception.Message)"
        }
    }
    foreach ($mode in @('Auto', 'Light', 'Dark')) {
        $button = $dialog.FindName("Theme${mode}Button")
        if ($mode -eq $script:UiPreferences.Theme) { $button.SetResourceReference([System.Windows.FrameworkElement]::StyleProperty, 'PrimaryButtonStyle') }
        $button.Add_Click({
            param($sender, $e)
            $pendingTheme.Value = [string]$sender.Tag
            foreach ($themeMode in @('Auto', 'Light', 'Dark')) {
                $style = if ($themeMode -eq $pendingTheme.Value) { 'PrimaryButtonStyle' } else { 'SecondaryButtonStyle' }
                $dialog.FindName("Theme${themeMode}Button").SetResourceReference([System.Windows.FrameworkElement]::StyleProperty, $style)
            }
        })
    }
    $dialog.FindName('SaveButton').Add_Click($savePreferences)
    $dialog.FindName('TitleBar').Add_MouseLeftButtonDown({ $dialog.DragMove() })
    $dialog.FindName('CloseBtn').Add_Click({ $dialog.Close() })
    try {
        if ($overlay) { $overlay.Visibility = 'Visible' }
        [void]$dialog.ShowDialog()
        return [bool]$dialog.Tag
    }
    finally { if ($overlay) { $overlay.Visibility = 'Collapsed' } }
}
