<#
    .SYNOPSIS
        Populates dynamic language resources for a window and its detached menus.

    .DESCRIPTION
        Keeps text bound to language resources in sync with the active language, including
        menus and popups that use separate resources.

    .PARAMETER Window
        The window whose language resources are updated, along with its menus and popups.
#>
function Update-WindowLanguageResources {
    param([System.Windows.Window]$Window)

    $keys = @(foreach ($language in (Get-LanguageFallbackChain -Lang $script:Lang)) {
        $language.Chrome.PSObject.Properties.Name
    }) | Sort-Object -Unique
    # Popups and context menus can have a separate resource lookup tree.
    $targets = @($Window, $Window.FindName('MainMenu'), $Window.FindName('PresetsPopup'), $Window.FindName('TweaksPresetsPopup')) | Where-Object { $null -ne $_ }
    foreach ($key in $keys) {
        $text = Get-Translation -Key $key -Section 'Chrome'
        foreach ($target in $targets) { $target.Resources["Language_$key"] = $text }
    }
}

<#
    .SYNOPSIS
        Refreshes localized text on existing main window tweak controls.

    .DESCRIPTION
        Updates tweak text and accessibility labels for the active language while preserving
        existing controls and selections.

    .PARAMETER Window
        The main window containing the registered dynamic tweak controls.
#>
function Update-MainWindowTweakLanguage {
    param([System.Windows.Window]$Window)

    foreach ($category in $script:CategoryLanguageControls) {
        $label = Get-Translation -Key $category.CategoryId -Field 'Label' -Section 'Categories'
        $category.Header.Text = $label
        $category.HelpButton.ToolTip = Get-Translation -Key 'TweaksCategoryHelpTooltip' -FormatArgs @($label)
    }
    foreach ($name in $script:UiControlMappings.Keys) {
        $mapping = $script:UiControlMappings[$name]
        $control = $Window.FindName($name)
        if (-not $control) { continue }
        $text = Get-TweakControlText -Mapping $mapping
        if ($mapping.Type -eq 'group') {
            # Update item contents, keeping item identity and SelectedIndex unchanged.
            for ($i = 0; $i -lt $text.Options.Count; $i++) {
                $control.Items[$i].Content = $text.Options[$i]
            }
        }
        $control.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $text.Label)
        if ($control -is [System.Windows.Controls.CheckBox]) { $control.Content = $text.Label }
        else { $Window.FindName("${name}_LabelBorder").Child.Text = $text.Label }
        # Label borders share this tooltip TextBlock with their combobox.
        if ($control.ToolTip -is [System.Windows.Controls.TextBlock]) { $control.ToolTip.Text = $text.ToolTip }
    }
    Update-FeatureLabelLookup
}

<#
    .SYNOPSIS
        Refreshes localized app text and preset tooltips.

    .DESCRIPTION
        Updates app details, accessibility labels, and preset tooltips for the active language
        while preserving app selections.

    .PARAMETER AppsPanel
        The panel containing the app selection controls.
#>
function Update-MainWindowAppLanguage {
    param([System.Windows.Controls.Panel]$AppsPanel)

    foreach ($app in $AppsPanel.Children) {
        if ($app -isnot [System.Windows.Controls.CheckBox]) { continue }
        $primaryAppId = @($app.AppIds)[0]
        $app.AppName = Get-Translation -Key $primaryAppId -Field 'FriendlyName' -Section 'Apps'
        $app.AppDescription = Get-Translation -Key $primaryAppId -Field 'Description' -Section 'Apps'
        $app.AppNameText.Text = $app.AppName
        $app.AppDescriptionText.Text = $app.AppDescription
        $app.AppDescriptionText.ToolTip = $app.AppDescription
        $app.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $app.AppName)
    }
    foreach ($preset in $script:JsonPresetCheckboxes) {
        $preset.ToolTip = Get-Translation -Key 'AppPresetSelectTooltip' -FormatArgs @($preset.Content)
    }
    # A future installed-only toggle must not consume a catalog in the old language.
    $script:PreloadedAppData = $null
}

<#
    .SYNOPSIS
        Applies the current language to an existing main window.

    .DESCRIPTION
        Updates the interface and search results for the active language while preserving
        user selections and app scroll position.

    .PARAMETER Window
        The initialized main window to refresh.
#>
function Update-MainWindowLanguage {
    param([System.Windows.Window]$Window)

    $appsPanel = $Window.FindName('AppSelectionPanel')
    $appsScroll = Find-ParentScrollViewer -Element $appsPanel
    $appOffset = if ($appsScroll) { $appsScroll.VerticalOffset } else { 0 }
    $activeMatch = if ($script:AppSearchMatchIndex -ge 0 -and $script:AppSearchMatchIndex -lt $script:AppSearchMatches.Count) {
        $script:AppSearchMatches[$script:AppSearchMatchIndex]
    }

    Update-WindowLanguageResources -Window $Window
    Update-MainWindowTweakLanguage -Window $Window
    Update-MainWindowAppLanguage -AppsPanel $appsPanel

    $userCombo = $Window.FindName('UserSelectionCombo')
    $userCombo.Items[0].Content = Get-Translation -Key 'HomeCurrentUserWithName' -FormatArgs @(Get-UserName)
    Update-UserSelectionDescription -Window $Window -UserSelectionCombo $userCombo -OtherUsernameTextBox $Window.FindName('OtherUsernameTextBox') -UserSelectionDescription $Window.FindName('UserSelectionDescription')
    Update-AppSelectionStatus -AppsPanel $appsPanel -AppSelectionStatus $Window.FindName('AppSelectionStatus') -AppRemovalScopeCombo $Window.FindName('AppRemovalScopeCombo') -AppRemovalScopeSection $Window.FindName('AppRemovalScopeSection') -AppRemovalScopeDescription $Window.FindName('AppRemovalScopeDescription') -UserSelectionCombo $userCombo
    $validationMessage = $Window.FindName('UsernameValidationMessage')
    if ($validationMessage.Text) {
        Test-OtherUsername -Window $Window -UserSelectionCombo $userCombo -OtherUsernameTextBox $Window.FindName('OtherUsernameTextBox') -UsernameValidationMessage $validationMessage -AppRemovalScopeCombo $Window.FindName('AppRemovalScopeCombo') | Out-Null
    }

    Update-AppsPanelSort -AppsPanel $appsPanel -SortArrowName $Window.FindName('SortArrowName') -SortArrowDescription $Window.FindName('SortArrowDescription') -SortArrowAppId $Window.FindName('SortArrowAppId')
    # Rerun matching against the translated labels without moving the user's viewport.
    $script:UpdatingLanguage = $true
    try {
        foreach ($name in @('AppSearchBox', 'TweakSearchBox')) {
            $Window.FindName($name).RaiseEvent([System.Windows.Controls.TextChangedEventArgs]::new([System.Windows.Controls.TextBox]::TextChangedEvent, [System.Windows.Controls.UndoAction]::None))
        }
    }
    finally { $script:UpdatingLanguage = $false }
    $activeIndex = [array]::IndexOf($script:AppSearchMatches, $activeMatch)
    if ($activeIndex -ge 0) {
        $script:AppSearchMatches[0].SetResourceReference([System.Windows.Controls.Control]::BackgroundProperty, 'SearchHighlightColor')
        $activeMatch.SetResourceReference([System.Windows.Controls.Control]::BackgroundProperty, 'SearchHighlightActiveColor')
        $script:AppSearchMatchIndex = $activeIndex
    }
    if ($appsScroll) { $appsScroll.ScrollToVerticalOffset($appOffset) }
    Hide-Bubble -Immediate
}
