function Show-RevertSettingsModal {
    param (
        [Parameter(Mandatory=$false)]
        [System.Windows.Window]$Owner = $null,
        [Parameter(Mandatory=$true)]
        $LastUsedSettings
    )

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    $usesDarkMode = GetSystemUsesDarkMode

    # Determine owner window
    $ownerWindow = if ($Owner) { $Owner } else { $script:GuiWindow }

    # Show overlay if owner window exists
    $overlay = $null
    $overlayWasAlreadyVisible = $false
    if ($ownerWindow) {
        try {
            $overlay = $ownerWindow.FindName('ModalOverlay')
            if ($overlay) {
                $overlayWasAlreadyVisible = ($overlay.Visibility -eq 'Visible')
                if (-not $overlayWasAlreadyVisible) {
                    $ownerWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Visible' })
                }
            }
        }
        catch { }
    }

    # Load XAML from file
    $xaml = Get-Content -Path $script:RevertSettingsWindowSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $revertWindow = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    if ($ownerWindow) {
        try {
            $revertWindow.Owner = $ownerWindow
        }
        catch { }
    }

    SetWindowThemeResources -window $revertWindow -usesDarkMode $usesDarkMode

    $itemsPanel = $revertWindow.FindName('RevertItemsPanel')
    $countText = $revertWindow.FindName('RevertSelectionCount')
    $selectAllBtn = $revertWindow.FindName('RevertSelectAllBtn')
    $clearBtn = $revertWindow.FindName('RevertClearBtn')
    $applyBtn = $revertWindow.FindName('RevertApplyBtn')
    $cancelBtn = $revertWindow.FindName('RevertCancelBtn')
    $restartExplorerCheckbox = $revertWindow.FindName('RevertRestartExplorerCheckBox')

    $entryCheckboxes = @()
    $featureCheckboxStyle = $null
    if ($ownerWindow) {
        try {
            $featureCheckboxStyle = $ownerWindow.FindResource('FeatureCheckboxStyle')
        }
        catch { }
    }

    if ($restartExplorerCheckbox -and $featureCheckboxStyle) {
        $restartExplorerCheckbox.Style = $featureCheckboxStyle
    }

    foreach ($setting in $LastUsedSettings.Settings) {
        if ($setting.Value -ne $true) { continue }
        if ($setting.Name -eq 'Apps' -or $setting.Name -eq 'RemoveApps' -or $setting.Name -eq 'CreateRestorePoint') { continue }

        $feature = $null
        if ($script:Features.ContainsKey($setting.Name)) {
            $feature = $script:Features[$setting.Name]
        }
        $undoFeature = GetUndoFeatureForParam -paramKey $setting.Name

        $label = $setting.Name
        if ($feature -and $feature.Label) {
            if ($feature.Action) {
                $label = "$($feature.Action) $($feature.Label)"
            }
            else {
                $label = $feature.Label
            }
        }

        $undoLabel = if ($undoFeature -and $undoFeature.Label) {
            "$($undoFeature.UndoAction) $($undoFeature.Label)"
        } else {
            'No revert action available'
        }

        $canUndo = ($undoFeature -ne $null)

        $itemBorder = New-Object System.Windows.Controls.Border
        $itemBorder.Style = $revertWindow.FindResource('RevertItemBorderStyle')

        $row = New-Object System.Windows.Controls.StackPanel
        $row.Style = $revertWindow.FindResource('RevertItemRowStyle')

        $checkbox = New-Object System.Windows.Controls.CheckBox
        $checkbox.Content = $label
        $checkbox.Tag = $setting.Name
        if ($featureCheckboxStyle) {
            $checkbox.Style = $featureCheckboxStyle
        }
        else {
            $checkbox.Foreground = $revertWindow.FindResource('FgColor')
        }
        $checkbox.Margin = [System.Windows.Thickness]::new(0, 0, 0, 3)
        $checkbox.IsEnabled = $canUndo

        $undoText = New-Object System.Windows.Controls.TextBlock
        $undoText.Text = if ($canUndo) { "Revert to: $undoLabel" } else { 'Revert not supported for this setting' }
        $undoText.Style = $revertWindow.FindResource('RevertItemUndoTextStyle')
        $undoText.Opacity = if ($canUndo) { 0.75 } else { 0.4 }

        $row.Children.Add($checkbox) | Out-Null
        $row.Children.Add($undoText) | Out-Null
        $itemBorder.Child = $row

        $itemsPanel.Children.Add($itemBorder) | Out-Null
        $entryCheckboxes += $checkbox
    }

    # Remove the divider from the last entry for cleaner list termination.
    if ($itemsPanel.Children.Count -gt 0) {
        $lastItem = $itemsPanel.Children[$itemsPanel.Children.Count - 1]
        if ($lastItem -is [System.Windows.Controls.Border]) {
            $lastItem.BorderThickness = [System.Windows.Thickness]::new(0)
        }
    }

    if ($entryCheckboxes.Count -eq 0) {
        $emptyText = New-Object System.Windows.Controls.TextBlock
        $emptyText.Text = 'No previously applied tweaks can be reverted'
        $emptyText.Style = $revertWindow.FindResource('RevertEmptyTextStyle')
        $itemsPanel.Children.Add($emptyText) | Out-Null
        $selectAllBtn.IsEnabled = $false
        $clearBtn.IsEnabled = $false
    }

    $updateState = {
        $selectedCount = 0
        foreach ($cb in $entryCheckboxes) {
            if ($cb.IsEnabled -and $cb.IsChecked -eq $true) {
                $selectedCount++
            }
        }

        $countText.Text = "$selectedCount settings selected"
        $applyBtn.IsEnabled = ($selectedCount -gt 0)
    }

    foreach ($cb in $entryCheckboxes) {
        $cb.Add_Checked($updateState)
        $cb.Add_Unchecked($updateState)
    }

    $selectAllBtn.Add_Click({
        foreach ($cb in $entryCheckboxes) {
            if ($cb.IsEnabled) {
                $cb.IsChecked = $true
            }
        }
    })

    $clearBtn.Add_Click({
        foreach ($cb in $entryCheckboxes) {
            if ($cb.IsEnabled) {
                $cb.IsChecked = $false
            }
        }
    })

    $cancelHandler = {
        $revertWindow.Tag = [PSCustomObject]@{
            SelectedFeatureIds = @()
            RestartExplorer = ($restartExplorerCheckbox -and $restartExplorerCheckbox.IsChecked -eq $true)
        }
        $revertWindow.Close()
    }

    $cancelBtn.Add_Click($cancelHandler)

    $applyBtn.Add_Click({
        $selected = @()
        foreach ($cb in $entryCheckboxes) {
            if ($cb.IsEnabled -and $cb.IsChecked -eq $true -and $cb.Tag) {
                $selected += $cb.Tag
            }
        }

        $revertWindow.Tag = [PSCustomObject]@{
            SelectedFeatureIds = $selected
            RestartExplorer = ($restartExplorerCheckbox -and $restartExplorerCheckbox.IsChecked -eq $true)
        }
        $revertWindow.Close()
    })

    & $updateState

    $revertWindow.ShowDialog() | Out-Null

    if ($overlay -and -not $overlayWasAlreadyVisible) {
        try {
            $ownerWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' })
        }
        catch { }
    }

    if ($revertWindow.Tag) {
        return $revertWindow.Tag
    }

    return [PSCustomObject]@{
        SelectedFeatureIds = @()
        RestartExplorer = $false
    }
}
