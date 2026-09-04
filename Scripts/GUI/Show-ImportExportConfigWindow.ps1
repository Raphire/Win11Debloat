<#
    .SYNOPSIS
        Maps an internal import/export category ID ('Applications', 'System Tweaks',
        'Deployment Settings') to its Chrome.json translation key.

    .DESCRIPTION
        The category strings stay as the stable internal IDs used for -contains checks and
        hashtable lookups throughout this file; only the label shown to the user is translated.
#>
function Get-ImportExportCategoryLabelKey {
    param(
        [Parameter(Mandatory)]
        [string]$Category
    )

    switch ($Category) {
        'Applications' { return 'ImportExportCategoryApplications' }
        'System Tweaks' { return 'ImportExportCategorySystemTweaks' }
        'Deployment Settings' { return 'ImportExportCategoryDeploymentSettings' }
        default { return $Category }
    }
}

<#
    .SYNOPSIS
        Shows a modal category-selection dialog for importing or exporting configuration.
#>
function Show-ImportExportConfigWindow {
    param (
        [System.Windows.Window]$Owner,
        [bool]$UsesDarkMode,
        [string]$Title,
        [string]$Prompt,
        [string[]]$Categories = @('Applications', 'System Tweaks', 'Deployment Settings'),
        [string[]]$DisabledCategories = @(),
        [hashtable]$CategoryDetails = @(),
        [string]$ActionLabel = (Get-Translation -Key 'MessageBoxOk')
    )

    # Show overlay on owner window
    $overlay = $null
    $overlayWasAlreadyVisible = $false
    try {
        $overlay = $Owner.FindName('ModalOverlay')
        if ($overlay) {
            $overlayWasAlreadyVisible = ($overlay.Visibility -eq 'Visible')
            if (-not $overlayWasAlreadyVisible) {
                $Owner.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Visible' })
            }
        }
    } 
    catch { }

    # Load XAML from schema file
    $schemaPath = $script:ImportExportConfigSchema

    if (-not $schemaPath -or -not (Test-Path $schemaPath)) {
        Show-MessageBox -Message (Get-Translation -Key 'ImportExportSchemaMissingMessage') -Title (Get-Translation -Key 'ErrorTitle') -Button 'OK' -Icon 'Error' -Owner $Owner | Out-Null
        if ($overlay -and -not $overlayWasAlreadyVisible) {
            try { $Owner.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' }) } catch { }
        }
        return $null
    }

    $xaml = Get-Content -Path $schemaPath -Raw
    $xaml = ConvertTo-LocalizedXaml -Xaml $xaml
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $dlg = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    $dlg.Owner = $Owner
    Set-WindowThemeResources -window $dlg -usesDarkMode $UsesDarkMode

    # Copy the CheckBox default style from the main window so checkboxes get the themed template
    try {
        $mainCheckBoxStyle = $Owner.FindResource([type][System.Windows.Controls.CheckBox])
        if ($mainCheckBoxStyle) {
            $dlg.Resources.Add([type][System.Windows.Controls.CheckBox], $mainCheckBoxStyle)
        }
    }
    catch { }

    # Populate named elements
    $dlg.Title = $Title
    $dlg.FindName('TitleText').Text = $Title
    $dlg.FindName('PromptText').Text = $Prompt

    $titleBar = $dlg.FindName('TitleBar')
    $titleBar.Add_MouseLeftButtonDown({ $dlg.DragMove() })

    # Add a themed checkbox per category
    $checkboxPanel = $dlg.FindName('CheckboxPanel')
    $checkboxes = @{}
    foreach ($cat in $Categories) {
        # Create a container for the checkbox and details
        $container = New-Object System.Windows.Controls.StackPanel
        $container.Orientation = [System.Windows.Controls.Orientation]::Vertical
        $container.Margin = [System.Windows.Thickness]::new(0,0,0,12)

        # Create checkbox
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = Get-Translation -Key (Get-ImportExportCategoryLabelKey -Category $cat)
        $cb.IsChecked = $true
        $cb.Margin = [System.Windows.Thickness]::new(0,0,0,4)
        $cb.FontSize = 14
        $cb.FontWeight = [System.Windows.FontWeights]::Medium
        $cb.Foreground = $dlg.FindResource("AppFgColor")
        if ($DisabledCategories -contains $cat) {
            $cb.IsChecked = $false
            $cb.IsEnabled = $false
            $cb.Opacity = 0.65
            $cb.ToolTip = Get-Translation -Key 'ImportExportCategoryDisabledTooltip'
        }
        
        $container.Children.Add($cb) | Out-Null
        
        # Add details if available
        if ($CategoryDetails -and $CategoryDetails[$cat]) {
            $detailsText = New-Object System.Windows.Controls.TextBlock
            $detailsText.Text = $CategoryDetails[$cat]
            $detailsText.FontSize = 12
            $detailsText.Foreground = $dlg.FindResource("AppFgColor")
            $detailsText.Margin = [System.Windows.Thickness]::new(32,0,0,0)
            $detailsText.Opacity = if ($DisabledCategories -contains $cat) { 0.45 } else { 0.75 }
            $detailsText.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $container.Children.Add($detailsText) | Out-Null
        }
        
        $checkboxPanel.Children.Add($container) | Out-Null
        $checkboxes[$cat] = $cb
    }

    $okBtn = $dlg.FindName('OkButton')
    $cancelBtn = $dlg.FindName('CancelButton')
    $okBtn.Content = $ActionLabel
    $okBtn.Add_Click({ $dlg.Tag = 'OK'; $dlg.Close() })
    $cancelBtn.Add_Click({ $dlg.Tag = 'Cancel'; $dlg.Close() })

    # Handle Escape key
    $dlg.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq 'Escape') { $dlg.Tag = 'Cancel'; $dlg.Close() }
    })

    try {
        $dlg.ShowDialog() | Out-Null
    }
    finally {
        # Hide overlay
        if ($overlay -and -not $overlayWasAlreadyVisible) {
            try { $Owner.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' }) } catch { }
        }
    }

    if ($dlg.Tag -ne 'OK') { return $null }

    $selected = @()
    foreach ($cat in $Categories) {
        if ($checkboxes[$cat].IsEnabled -and $checkboxes[$cat].IsChecked) { $selected += $cat }
    }
    if ($selected.Count -eq 0) { return $null }
    return $selected
}

function Get-SelectedApplications {
    param (
        [System.Windows.Controls.Panel]$AppsPanel
    )

    $selectedApps = @()
    foreach ($child in $AppsPanel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
            $selectedApps += $child.Tag
        }
    }

    return $selectedApps
}

function Get-SelectedTweakSettings {
    param (
        [System.Windows.Window]$Owner,
        [hashtable]$UiControlMappings
    )

    $tweakSettings = @()
    if (-not $UiControlMappings) {
        return $tweakSettings
    }

    foreach ($mappingKey in $UiControlMappings.Keys) {
        $control = $Owner.FindName($mappingKey)
        if (-not $control) { continue }

        $mapping = $UiControlMappings[$mappingKey]
        if ($control -is [System.Windows.Controls.CheckBox] -and $control.IsChecked) {
            if ($mapping.Type -eq 'feature') {
                $tweakSettings += @{ Name = $mapping.FeatureId; Value = $true }
            }
        }
        elseif ($control -is [System.Windows.Controls.ComboBox] -and $control.SelectedIndex -gt 0) {
            if ($mapping.Type -eq 'group') {
                $selectedValue = $mapping.Values[$control.SelectedIndex - 1]
                foreach ($fid in $selectedValue.FeatureIds) {
                    $tweakSettings += @{ Name = $fid; Value = $true }
                }
            }
            elseif ($mapping.Type -eq 'feature') {
                $tweakSettings += @{ Name = $mapping.FeatureId; Value = $true }
            }
        }
    }

    return $tweakSettings
}

function Get-DeploymentSettings {
    param (
        [System.Windows.Window]$Owner,
        [System.Windows.Controls.ComboBox]$UserSelectionCombo,
        [System.Windows.Controls.TextBox]$OtherUsernameTextBox
    )

    $deploySettings = @(
        @{ Name = 'UserSelectionIndex'; Value = $UserSelectionCombo.SelectedIndex }
    )

    if ($UserSelectionCombo.SelectedIndex -eq 1) {
        $deploySettings += @{ Name = 'OtherUsername'; Value = $OtherUsernameTextBox.Text.Trim() }
    }

    $appRemovalScopeCombo = $Owner.FindName('AppRemovalScopeCombo')
    if ($appRemovalScopeCombo) {
        $deploySettings += @{ Name = 'AppRemovalScopeIndex'; Value = $appRemovalScopeCombo.SelectedIndex }
    }

    $restorePointCheckBox = $Owner.FindName('RestorePointCheckBox')
    if ($restorePointCheckBox) {
        $deploySettings += @{ Name = 'CreateRestorePoint'; Value = [bool]$restorePointCheckBox.IsChecked }
    }

    $registryBackupCheckBox = $Owner.FindName('RegistryBackupCheckBox')
    if ($registryBackupCheckBox) {
        $deploySettings += @{ Name = 'SkipRegistryBackup'; Value = -not [bool]$registryBackupCheckBox.IsChecked }
    }

    $restartExplorerCheckBox = $Owner.FindName('RestartExplorerCheckBox')
    if ($restartExplorerCheckBox) {
        $deploySettings += @{ Name = 'RestartExplorer'; Value = [bool]$restartExplorerCheckBox.IsChecked }
    }

    return $deploySettings
}

function Get-AvailableImportExportCategories {
    param (
        $Config
    )

    $availableCategories = @()
    if ($Config.Apps) { $availableCategories += 'Applications' }
    if ($Config.Tweaks) { $availableCategories += 'System Tweaks' }
    if ($Config.Deployment) { $availableCategories += 'Deployment Settings' }

    return $availableCategories
}

<#
    .SYNOPSIS
        Summarizes a deployment settings array into the short description shown under the
        "Deployment Settings" checkbox in the import/export category picker.
#>
function Get-DeploymentCategoryDetailString {
    param (
        [array]$DeploymentSettings
    )

    $lookup = @{}
    foreach ($setting in @($DeploymentSettings)) {
        if ($setting -and $setting.Name) {
            $lookup[$setting.Name] = $setting.Value
        }
    }

    $line1 = @()

    if ($lookup.ContainsKey('UserSelectionIndex')) {
        switch ([int]$lookup['UserSelectionIndex']) {
            0 { $line1 += Get-Translation -Key 'ImportExportDeployUserCurrentUser' }
            1 { $line1 += Get-Translation -Key 'ImportExportDeployUserOther' -FormatArgs @($(if ($lookup['OtherUsername']) { $lookup['OtherUsername'] } else { Get-Translation -Key 'ImportExportDeployUserOtherFallback' })) }
            2 { $line1 += Get-Translation -Key 'ImportExportDeployUserSysprep' }
        }
    }

    if ($lookup.ContainsKey('AppRemovalScopeIndex')) {
        switch ([int]$lookup['AppRemovalScopeIndex']) {
            0 { $line1 += Get-Translation -Key 'ImportExportAppRemovalAllUsers' }
            1 { $line1 += Get-Translation -Key 'ImportExportAppRemovalCurrentUser' }
            2 { $line1 += Get-Translation -Key 'ImportExportAppRemovalOther' -FormatArgs @($(if ($lookup['OtherUsername']) { $lookup['OtherUsername'] } else { Get-Translation -Key 'ImportExportDeployUserOtherFallback' })) }
        }
    }

    $options = @()
    if ($lookup.ContainsKey('CreateRestorePoint') -and [bool]$lookup['CreateRestorePoint']) { $options += Get-Translation -Key 'ImportExportOptionRestorePoint' }
    if (-not ($lookup.ContainsKey('SkipRegistryBackup') -and [bool]$lookup['SkipRegistryBackup'])) { $options += Get-Translation -Key 'ImportExportOptionRegistryBackup' }
    if ($lookup.ContainsKey('RestartExplorer')    -and [bool]$lookup['RestartExplorer'])    { $options += Get-Translation -Key 'ImportExportOptionRestartExplorer' }

    $lines = @()
    if ($line1.Count -gt 0)   { $lines += $line1 -join ', ' }
    if ($options.Count -gt 0) { $lines += Get-Translation -Key 'ImportExportOptionsPrefix' -FormatArgs @($options -join ', ') }

    if ($lines.Count -gt 0) { return $lines -join "`n" }
    return Get-Translation -Key 'ImportExportDefaultDeploymentSettings'
}

<#
    .SYNOPSIS
        Builds the per-category description text shown under each checkbox in the
        import/export category picker.
#>
function Build-CategoryDetails {
    param (
        [int]$AppCount = 0,
        [int]$TweakCount = 0,
        [array]$DeploymentSettings
    )

    $details = @{}

    if ($AppCount -gt 0) {
        $details['Applications'] = Get-Translation -Key 'ImportExportAppsSelected' -Count $AppCount -FormatArgs @($AppCount)
    }
    else {
        $details['Applications'] = Get-Translation -Key 'ImportExportNoAppsSelected'
    }

    if ($TweakCount -gt 0) {
        $details['System Tweaks'] = Get-Translation -Key 'ImportExportTweaksSelected' -Count $TweakCount -FormatArgs @($TweakCount)
    }
    else {
        $details['System Tweaks'] = Get-Translation -Key 'ImportExportNoTweaksSelected'
    }

    if ($DeploymentSettings) {
        $details['Deployment Settings'] = Get-DeploymentCategoryDetailString -DeploymentSettings $DeploymentSettings
    }

    return $details
}

<#
    .SYNOPSIS
        Applies imported application selections to the application checkboxes.
#>
function Set-ImportedApplications {
    param (
        [System.Windows.Controls.Panel]$AppsPanel,
        [string[]]$AppIds
    )

    foreach ($child in $AppsPanel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox]) {
            $child.IsChecked = ($AppIds -contains $child.Tag)
        }
    }
}

<#
    .SYNOPSIS
        Applies imported tweak settings to their mapped UI controls.
#>
function Set-ImportedTweakSettings {
    param (
        [System.Windows.Window]$Owner,
        [hashtable]$UiControlMappings,
        [array]$TweakSettings
    )

    $settingsJson = [PSCustomObject]@{ Settings = @($TweakSettings) }
    Apply-SettingsToUiControls -window $Owner -settingsJson $settingsJson -uiControlMappings $UiControlMappings
}

<#
    .SYNOPSIS
        Applies imported deployment settings to the deployment controls.
#>
function Set-ImportedDeploymentSettings {
    param (
        [System.Windows.Window]$Owner,
        [System.Windows.Controls.ComboBox]$UserSelectionCombo,
        [System.Windows.Controls.TextBox]$OtherUsernameTextBox,
        [array]$DeploymentSettings
    )

    $lookup = @{}
    foreach ($setting in $DeploymentSettings) {
        $lookup[$setting.Name] = $setting.Value
    }

    if ($lookup.ContainsKey('UserSelectionIndex')) {
        $UserSelectionCombo.SelectedIndex = [int]$lookup['UserSelectionIndex']
    }
    if ($lookup.ContainsKey('OtherUsername') -and $UserSelectionCombo.SelectedIndex -eq 1) {
        $OtherUsernameTextBox.Text = $lookup['OtherUsername']
    }

    $appRemovalScopeCombo = $Owner.FindName('AppRemovalScopeCombo')
    if ($lookup.ContainsKey('AppRemovalScopeIndex') -and $appRemovalScopeCombo) {
        $appRemovalScopeCombo.SelectedIndex = [int]$lookup['AppRemovalScopeIndex']
    }

    $restorePointCheckBox = $Owner.FindName('RestorePointCheckBox')
    if ($lookup.ContainsKey('CreateRestorePoint') -and $restorePointCheckBox) {
        $restorePointCheckBox.IsChecked = [bool]$lookup['CreateRestorePoint']
    }

    $registryBackupCheckBox = $Owner.FindName('RegistryBackupCheckBox')
    if ($registryBackupCheckBox) {
        if ($lookup.ContainsKey('SkipRegistryBackup')) {
            $registryBackupCheckBox.IsChecked = -not [bool]$lookup['SkipRegistryBackup']
        }
    }

    $restartExplorerCheckBox = $Owner.FindName('RestartExplorerCheckBox')
    if ($lookup.ContainsKey('RestartExplorer') -and $restartExplorerCheckBox) {
        $restartExplorerCheckBox.IsChecked = [bool]$lookup['RestartExplorer']
    }
}

<#
    .SYNOPSIS
        Exports selected application, tweak, and deployment settings to a configuration file.
#>
function Export-Configuration {
    param (
        [System.Windows.Window]$Owner,
        [bool]$UsesDarkMode,
        [System.Windows.Controls.Panel]$AppsPanel,
        [hashtable]$UiControlMappings,
        [System.Windows.Controls.ComboBox]$UserSelectionCombo,
        [System.Windows.Controls.TextBox]$OtherUsernameTextBox
    )

    # Precompute exportable data so empty categories can be disabled in the picker.
    $selectedApps = Get-SelectedApplications -AppsPanel $AppsPanel
    $tweakSettings = Get-SelectedTweakSettings -Owner $Owner -UiControlMappings $UiControlMappings

    $disabledCategories = @()
    if ($selectedApps.Count -eq 0) { $disabledCategories += 'Applications' }
    if ($tweakSettings.Count -eq 0) { $disabledCategories += 'System Tweaks' }

    $deploymentSettings = Get-DeploymentSettings -Owner $Owner -UserSelectionCombo $UserSelectionCombo -OtherUsernameTextBox $OtherUsernameTextBox
    $categoryDetails = Build-CategoryDetails -AppCount $selectedApps.Count -TweakCount $tweakSettings.Count -DeploymentSettings $deploymentSettings

    $categories = Show-ImportExportConfigWindow -Owner $Owner -UsesDarkMode $UsesDarkMode -Title (Get-Translation -Key 'ImportExportExportTitle') -Prompt (Get-Translation -Key 'ImportExportExportPrompt') -DisabledCategories $disabledCategories -CategoryDetails $categoryDetails -ActionLabel (Get-Translation -Key 'ImportExportExportActionLabel')
    if (-not $categories) {
        Write-Host 'Export canceled.'
        return
    }

    $config = @{ Version = '1.0' }

    if ($categories -contains 'Applications') {
        $config['Apps'] = @($selectedApps)
    }
    if ($categories -contains 'System Tweaks') {
        $config['Tweaks'] = @($tweakSettings)
    }
    if ($categories -contains 'Deployment Settings') {
        $config['Deployment'] = @($deploymentSettings)
    }

    # Show native save-file dialog
    $saveDialog = New-Object Microsoft.Win32.SaveFileDialog
    $saveDialog.Title = Get-Translation -Key 'ImportExportSelectExportFileDialogTitle'
    $saveDialog.Filter = 'JSON files (*.json)|*.json|All files (*.*)|*.*'
    $saveDialog.DefaultExt = '.json'
    $saveDialog.FileName = "Win11Debloat-Config-$(Get-Date -Format 'yyyyMMdd').json"

    if ($saveDialog.ShowDialog($Owner) -ne $true) {
        Write-Host 'Export save dialog canceled.'
        return
    }

    Write-Host "Exporting configuration to '$($saveDialog.FileName)'... (Categories: $($categories -join ', '))"

    if ($script:Params.ContainsKey("WhatIf")) {
        Write-Host "[WhatIf] Export configuration to '$($saveDialog.FileName)'" -ForegroundColor Cyan
        Show-MessageBox -Message (Get-Translation -Key 'ImportExportWhatIfExportMessage') -Title (Get-Translation -Key 'ImportExportExportTitle') -Button 'OK' -Icon 'Information' | Out-Null
        return
    }

    if (Save-ToFile -Config $config -FilePath $saveDialog.FileName) {
        Write-Host "Configuration exported successfully: $($saveDialog.FileName)"
        Show-MessageBox -Message (Get-Translation -Key 'ImportExportExportSuccessMessage') -Title (Get-Translation -Key 'ImportExportExportTitle') -Button 'OK' -Icon 'Information' | Out-Null
    }
    else {
        Write-Error "Failed to export configuration to '$($saveDialog.FileName)'"
        Show-MessageBox -Message (Get-Translation -Key 'ImportExportExportFailedMessage') -Title (Get-Translation -Key 'ErrorTitle') -Button 'OK' -Icon 'Error' | Out-Null
    }
}

<#
    .SYNOPSIS
        Imports selected application, tweak, and deployment settings from a configuration file.
#>
function Import-Configuration {
    param (
        [System.Windows.Window]$Owner,
        [bool]$UsesDarkMode,
        [System.Windows.Controls.Panel]$AppsPanel,
        [hashtable]$UiControlMappings,
        [System.Windows.Controls.ComboBox]$UserSelectionCombo,
        [System.Windows.Controls.TextBox]$OtherUsernameTextBox,
        [scriptblock]$OnAppsImported,
        [scriptblock]$OnImportCompleted
    )

    # Show native open-file dialog
    $openDialog = New-Object Microsoft.Win32.OpenFileDialog
    $openDialog.Title = Get-Translation -Key 'ImportExportSelectImportFileDialogTitle'
    $openDialog.Filter = 'JSON files (*.json)|*.json|All files (*.*)|*.*'
    $openDialog.DefaultExt = '.json'

    if ($openDialog.ShowDialog($Owner) -ne $true) {
        Write-Host 'Import file dialog canceled.'
        return
    }

    Write-Host "Importing configuration from '$($openDialog.FileName)'..."

    $config = Import-JsonFile -filePath $openDialog.FileName -expectedVersion '1.0'
    if (-not $config) {
        Write-Error "Failed to read configuration file '$($openDialog.FileName)'"
        Show-MessageBox -Message (Get-Translation -Key 'ImportExportReadFailedMessage') -Title (Get-Translation -Key 'ImportExportInvalidConfigTitle') -Button 'OK' -Icon 'Error' | Out-Null
        return
    }

    $consistencyError = Test-ConfigConsistency -Config $config
    if ($consistencyError) {
        Write-Error "Invalid configuration file '$($openDialog.FileName)': $consistencyError"
        Show-MessageBox -Message (Get-Translation -Key 'ImportExportInvalidConfigMessage' -FormatArgs @($consistencyError)) -Title (Get-Translation -Key 'ImportExportInvalidConfigTitle') -Button 'OK' -Icon 'Error' | Out-Null
        return
    }

    $availableCategories = Get-AvailableImportExportCategories -Config $config

    Write-Host "Available categories in config: $($availableCategories -join ', ')"

    $appCount = @($config.Apps | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) }).Count
    $tweakCount = @($config.Tweaks | Where-Object { $_ -and $_.Name -and $_.Value -eq $true }).Count
    $categoryDetails = Build-CategoryDetails -AppCount $appCount -TweakCount $tweakCount -DeploymentSettings @($config.Deployment)

    $categories = Show-ImportExportConfigWindow -Owner $Owner -UsesDarkMode $UsesDarkMode -Title (Get-Translation -Key 'ImportExportImportTitle') -Prompt (Get-Translation -Key 'ImportExportImportPrompt') -Categories $availableCategories -CategoryDetails $categoryDetails -ActionLabel (Get-Translation -Key 'ImportExportImportActionLabel')
    if (-not $categories) {
        Write-Host 'Import canceled.'
        return
    }

    if ($categories -contains 'Applications' -and $config.Apps) {
        $appIds = @(
            $config.Apps | 
            Where-Object { $_ -is [string] } | 
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        Write-Host "Importing $($appIds.Count) app selection(s)."
        Set-ImportedApplications -AppsPanel $AppsPanel -AppIds $appIds
        
        if ($OnAppsImported) { 
            & $OnAppsImported
        }
    }
    if ($categories -contains 'System Tweaks' -and $config.Tweaks) {
        $tweakCount = @($config.Tweaks).Count
        Write-Host "Importing $tweakCount tweak(s)."
        Set-ImportedTweakSettings -Owner $Owner -UiControlMappings $UiControlMappings -TweakSettings @($config.Tweaks)
    }
    if ($categories -contains 'Deployment Settings' -and $config.Deployment) {
        Write-Host 'Importing deployment settings.'
        Set-ImportedDeploymentSettings -Owner $Owner -UserSelectionCombo $UserSelectionCombo -OtherUsernameTextBox $OtherUsernameTextBox -DeploymentSettings @($config.Deployment)
    }

    Write-Host 'Configuration imported successfully.'
    Show-MessageBox -Message (Get-Translation -Key 'ImportExportImportSuccessMessage') -Title (Get-Translation -Key 'ImportExportImportTitle') -Button 'OK' -Icon 'Information' | Out-Null

    if ($OnImportCompleted) {
        & $OnImportCompleted $categories
    }
}
