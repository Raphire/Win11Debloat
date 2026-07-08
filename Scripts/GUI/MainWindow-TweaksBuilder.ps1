# MainWindow-TweaksBuilder.ps1
# Dynamic tweaks UI construction from Features.json, tweak state management, selection clear, and search/highlight.

function Build-DynamicTweaks {
    param(
        [System.Windows.Window]$Window,
        [int]$WinVersion
    )

    $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"

    if (-not $featuresJson) {
        throw "Unable to load Features.json file. The GUI cannot continue without feature definitions."
    }

    # Column containers
    $col0 = $Window.FindName('Column0Panel')
    $col1 = $Window.FindName('Column1Panel')
    $col2 = $Window.FindName('Column2Panel')
    $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }

    # Clear all columns for fully dynamic panel creation
    foreach ($col in $columns) {
        if ($col) { $col.Children.Clear() }
    }

    $script:UiControlMappings = @{}
    $script:CategoryCardMap = @{}
    $script:TweaksCompactMode = $null
    $script:TweaksCardsMovedFromCol2 = @()

    function CreateLabeledCombo($parent, $labelText, $comboName, $items) {
        # If only 2 items (No Change + one option), use a checkbox instead
        if ($items.Count -eq 2) {
            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.Content = $labelText
            $checkbox.Name = $comboName
            $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $labelText)
            $checkbox.IsChecked = $false
            $checkbox.Style = $Window.Resources["FeatureCheckboxStyle"]
            $parent.Children.Add($checkbox) | Out-Null

            # Register the checkbox with the window's name scope
            try {
                [System.Windows.NameScope]::SetNameScope($checkbox, [System.Windows.NameScope]::GetNameScope($Window))
                $Window.RegisterName($comboName, $checkbox)
            }
            catch {
                # Name might already be registered, ignore
            }

            return $checkbox
        }

        # Otherwise use a combobox for multiple options
        # Wrap label in a Border for search highlighting
        $lblBorder = New-Object System.Windows.Controls.Border
        $lblBorder.Style = $Window.Resources['LabelBorderStyle']
        $lblBorderName = "$comboName`_LabelBorder"
        $lblBorder.Name = $lblBorderName

        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $labelText
        $lbl.Style = $Window.Resources['LabelStyle']
        $labelName = "$comboName`_Label"
        $lbl.Name = $labelName

        $lblBorder.Child = $lbl
        $parent.Children.Add($lblBorder) | Out-Null

        # Register the label border with the window's name scope
        try {
            [System.Windows.NameScope]::SetNameScope($lblBorder, [System.Windows.NameScope]::GetNameScope($Window))
            $Window.RegisterName($lblBorderName, $lblBorder)
        }
        catch {
            # Name might already be registered, ignore
        }

        $combo = New-Object System.Windows.Controls.ComboBox
        $combo.Name = $comboName
        $combo.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $labelText)
        foreach ($item in $items) { $comboItem = New-Object System.Windows.Controls.ComboBoxItem; $comboItem.Content = $item; $combo.Items.Add($comboItem) | Out-Null }
        $combo.SelectedIndex = 0
        $parent.Children.Add($combo) | Out-Null

        # Register the combo box with the window's name scope
        try {
            [System.Windows.NameScope]::SetNameScope($combo, [System.Windows.NameScope]::GetNameScope($Window))
            $Window.RegisterName($comboName, $combo)
        }
        catch {
            # Name might already be registered, ignore
        }

        return $combo
    }

    function GetWikiUrlForCategory($category) {
        if (-not $category) { return 'https://github.com/Raphire/Win11Debloat/wiki/Features' }

        $slug = $category.ToLowerInvariant()
        $slug = $slug -replace '&', ''
        $slug = $slug -replace '[^a-z0-9\s-]', ''
        $slug = $slug -replace '\s', '-'

        return "https://github.com/Raphire/Win11Debloat/wiki/Features#$slug"
    }

    function GetOrCreateCategoryCard($categoryObj) {
        $categoryName = $categoryObj.Name
        $categoryIcon = $categoryObj.Icon

        if ($script:CategoryCardMap.ContainsKey($categoryName)) { return $script:CategoryCardMap[$categoryName] }

        # Create a new card Border + StackPanel and add to shortest column
        $target = $columns | Sort-Object @{Expression = { $_.Children.Count }; Ascending = $true }, @{Expression = { $columns.IndexOf($_) }; Ascending = $true } | Select-Object -First 1

        $border = New-Object System.Windows.Controls.Border
        $border.Style = $Window.Resources['CategoryCardBorderStyle']
        $border.Tag = 'DynamicCategory'

        $panel = New-Object System.Windows.Controls.StackPanel
        $safe = ($categoryName -replace '[^a-zA-Z0-9_]', '_')
        $panel.Name = "Category_{0}_Panel" -f $safe

        $headerRow = New-Object System.Windows.Controls.StackPanel
        $headerRow.Orientation = 'Horizontal'

        # Add category icon
        $icon = New-Object System.Windows.Controls.TextBlock
        # Convert HTML entity to character (e.g., &#xE72E; -> actual character)
        if ($categoryIcon -match '&#x([0-9A-Fa-f]+);') {
            $hexValue = [Convert]::ToInt32($matches[1], 16)
            if ($WinVersion -lt 22000 -and $hexValue -eq 0xE794) {
                $hexValue = 0xE734
            }
            $icon.Text = [char]$hexValue
        }
        $icon.Style = $Window.Resources['CategoryHeaderIcon']
        $headerRow.Children.Add($icon) | Out-Null

        $header = New-Object System.Windows.Controls.TextBlock
        $header.Text = $categoryName
        $header.Style = $Window.Resources['CategoryHeaderTextBlock']
        $headerRow.Children.Add($header) | Out-Null

        $helpIcon = New-Object System.Windows.Controls.TextBlock
        $helpIcon.Text = '(?)'
        $helpIcon.Style = $Window.Resources['CategoryHelpLinkTextStyle']

        $helpBtn = New-Object System.Windows.Controls.Button
        $helpBtn.Content = $helpIcon
        $helpBtn.ToolTip = "Open the wiki for more info on '$categoryName' tweaks"
        $helpBtn.Tag = (GetWikiUrlForCategory -category $categoryName)
        $helpBtn.Style = $Window.Resources['CategoryHelpLinkButtonStyle']
        $helpBtn.Add_Click({
                param($button, $e)
                if ($button.Tag) { Start-Process $button.Tag }
            })
        $headerRow.Children.Add($helpBtn) | Out-Null

        $panel.Children.Add($headerRow) | Out-Null

        $border.Child = $panel
        $target.Children.Add($border) | Out-Null

        $script:CategoryCardMap[$categoryName] = $panel
        return $panel
    }

    # Determine categories present (from lists and features)
    $categoriesPresent = @{}
    if ($featuresJson.UiGroups) {
        foreach ($g in $featuresJson.UiGroups) { if ($g.Category) { $categoriesPresent[$g.Category] = $true } }
    }
    foreach ($f in $featuresJson.Features) { if ($f.Category) { $categoriesPresent[$f.Category] = $true } }

    # Create cards in the order defined in Features.json Categories (if present)
    $orderedCategories = @()
    if ($featuresJson.Categories) {
        foreach ($c in $featuresJson.Categories) {
            $categoryName = if ($c -is [string]) { $c } else { $c.Name }
            if ($categoriesPresent.ContainsKey($categoryName)) {
                # Store the full category object (or create one with default icon for string categories)
                $categoryObj = if ($c -is [string]) { @{Name = $c; Icon = '&#xE712;' } } else { $c }
                $orderedCategories += $categoryObj
            }
        }
    }
    else {
        # For backward compatibility, create category objects from keys
        foreach ($catName in $categoriesPresent.Keys) {
            $orderedCategories += @{Name = $catName; Icon = '&#xE712;' }
        }
    }

    # Build a FeatureId -> feature lookup for version filtering in groups
    $featureMap = @{}
    foreach ($f in $featuresJson.Features) {
        $featureMap[$f.FeatureId] = $f
    }

    foreach ($categoryObj in $orderedCategories) {
        $categoryName = $categoryObj.Name

        # Card is created lazily on the first rendered item
        $panel = $null

        # Collect groups and features for this category, then sort by priority
        $categoryItems = @()

        # Add any groups for this category
        if ($featuresJson.UiGroups) {
            $groupIndex = 0
            foreach ($group in $featuresJson.UiGroups) {
                if ($group.Category -ne $categoryName) { $groupIndex++; continue }
                $categoryItems += [PSCustomObject]@{
                    Type          = 'group'
                    Data          = $group
                    Priority      = if ($null -ne $group.Priority) { $group.Priority } else { [int]::MaxValue }
                    OriginalIndex = $groupIndex
                }
                $groupIndex++
            }
        }

        # Add individual features for this category
        $featureIndex = 0
        foreach ($feature in $featuresJson.Features) {
            if ($feature.Category -ne $categoryName) { $featureIndex++; continue }

            # Check version and feature compatibility using Features.json
            if (($feature.MinVersion -and $WinVersion -lt $feature.MinVersion) -or ($feature.MaxVersion -and $WinVersion -gt $feature.MaxVersion) -or ($feature.FeatureId -eq 'DisableModernStandbyNetworking' -and (-not $script:ModernStandbySupported))) {
                $featureIndex++; continue
            }

            # Skip if feature part of a group
            $inGroup = $false
            if ($featuresJson.UiGroups) {
                foreach ($g in $featuresJson.UiGroups) { foreach ($val in $g.Values) { if ($val.FeatureIds -contains $feature.FeatureId) { $inGroup = $true; break } }; if ($inGroup) { break } }
            }
            if ($inGroup) { $featureIndex++; continue }

            $categoryItems += [PSCustomObject]@{
                Type          = 'feature'
                Data          = $feature
                Priority      = if ($null -ne $feature.Priority) { $feature.Priority } else { [int]::MaxValue }
                OriginalIndex = $featureIndex
            }
            $featureIndex++
        }

        # Sort by priority first, then by original index for items with same/no priority
        $sortedItems = $categoryItems | Sort-Object -Property Priority, OriginalIndex

        # Render sorted items
        foreach ($item in $sortedItems) {
            if ($item.Type -eq 'group') {
                $group = $item.Data
                # Filter values by Windows version compatibility of their referenced features
                $filteredValues = @($group.Values | Where-Object {
                    $allCompatible = $true
                    foreach ($fid in $_.FeatureIds) {
                        if ($featureMap.ContainsKey($fid)) {
                            $f = $featureMap[$fid]
                            if (($f.MinVersion -and $WinVersion -lt $f.MinVersion) -or ($f.MaxVersion -and $WinVersion -gt $f.MaxVersion)) {
                                $allCompatible = $false
                                break
                            }
                        }
                    }
                    $allCompatible
                })
                # Skip the group entirely if all values are incompatible with this Windows version
                if ($filteredValues.Count -eq 0) { continue }

                # When only 1 value remains, render as the underlying feature directly
                if ($filteredValues.Count -eq 1) {
                    $featureIds = $filteredValues[0].FeatureIds

                    if (-not $featureIds -or $featureIds.Count -eq 0) { continue }
                    
                    $soleFid = $featureIds[0]

                    if ($featureMap.ContainsKey($soleFid)) {
                        $soleFeature = $featureMap[$soleFid]
                        $opt = 'Apply'
                        if ($soleFeature.FeatureId -match '^Disable') { $opt = 'Disable' } elseif ($soleFeature.FeatureId -match '^Enable') { $opt = 'Enable' }
                        $items = @('No Change', $opt)
                        $comboName = ("Feature_{0}_Combo" -f $soleFeature.FeatureId) -replace '[^a-zA-Z0-9_]', ''
                        if (-not $panel) { $panel = GetOrCreateCategoryCard -categoryObj $categoryObj }
                        $combo = CreateLabeledCombo -parent $panel -labelText $soleFeature.Label -comboName $comboName -items $items
                        # attach tooltip from Features.json if present
                        if ($soleFeature.ToolTip -or $soleFeature.DisableWhenApplied -eq $true) {
                            $tooltipText = $soleFeature.ToolTip
                            if ($soleFeature.DisableWhenApplied -eq $true) {
                                $tooltipText = "This tweak is already applied and cannot be undone automatically. Visit the Win11Debloat wiki for instructions on how to manually revert this change."
                            }
                            $tipBlock = New-Object System.Windows.Controls.TextBlock
                            $tipBlock.Text = $tooltipText
                            $tipBlock.TextWrapping = 'Wrap'
                            $tipBlock.MaxWidth = 420
                            $combo.ToolTip = $tipBlock
                            [System.Windows.Controls.ToolTipService]::SetShowOnDisabled($combo, $true)
                            $lblBorderObj = $null
                            try { $lblBorderObj = $Window.FindName("$comboName`_LabelBorder") } catch {}
                            if ($lblBorderObj) { $lblBorderObj.ToolTip = $tipBlock }
                        }
                        $script:UiControlMappings[$comboName] = @{ Type = 'feature'; FeatureId = $soleFeature.FeatureId; Label = $soleFeature.Label; Category = $categoryName }
                    }
                    continue
                }

                $items = @('No Change') + ($filteredValues | ForEach-Object { $_.Label })
                $comboName = 'Group_{0}Combo' -f $group.GroupId
                if (-not $panel) { $panel = GetOrCreateCategoryCard -categoryObj $categoryObj }
                $combo = CreateLabeledCombo -parent $panel -labelText $group.Label -comboName $comboName -items $items
                # attach tooltip from UiGroups if present
                if ($group.ToolTip) {
                    $tipBlock = New-Object System.Windows.Controls.TextBlock
                    $tipBlock.Text = $group.ToolTip
                    $tipBlock.TextWrapping = 'Wrap'
                    $tipBlock.MaxWidth = 420
                    $combo.ToolTip = $tipBlock
                    $lblBorderObj = $null
                    try { $lblBorderObj = $Window.FindName("$comboName`_LabelBorder") } catch {}
                    if ($lblBorderObj) { $lblBorderObj.ToolTip = $tipBlock }
                }
                $script:UiControlMappings[$comboName] = @{ Type = 'group'; Values = $filteredValues; Label = $group.Label; Category = $categoryName }
            }
            elseif ($item.Type -eq 'feature') {
                $feature = $item.Data
                $opt = 'Apply'
                if ($feature.FeatureId -match '^Disable') { $opt = 'Disable' } elseif ($feature.FeatureId -match '^Enable') { $opt = 'Enable' }
                $items = @('No Change', $opt)
                $comboName = ("Feature_{0}_Combo" -f $feature.FeatureId) -replace '[^a-zA-Z0-9_]', ''
                if (-not $panel) { $panel = GetOrCreateCategoryCard -categoryObj $categoryObj }
                $combo = CreateLabeledCombo -parent $panel -labelText $feature.Label -comboName $comboName -items $items
                # attach tooltip from Features.json if present, and include the disabled-state reason
                if ($feature.ToolTip -or $feature.DisableWhenApplied -eq $true) {
                    $tooltipText = $feature.ToolTip
                    if ($feature.DisableWhenApplied -eq $true) {
                        $tooltipText = "This tweak is already applied and cannot be undone automatically. Visit the Win11Debloat wiki for instructions on how to manually revert this change."
                    }

                    $tipBlock = New-Object System.Windows.Controls.TextBlock
                    $tipBlock.Text = $tooltipText
                    $tipBlock.TextWrapping = 'Wrap'
                    $tipBlock.MaxWidth = 420
                    $combo.ToolTip = $tipBlock
                    [System.Windows.Controls.ToolTipService]::SetShowOnDisabled($combo, $true)
                    $lblBorderObj = $null
                    try { $lblBorderObj = $Window.FindName("$comboName`_LabelBorder") } catch {}
                    if ($lblBorderObj) { $lblBorderObj.ToolTip = $tipBlock }
                }
                $script:UiControlMappings[$comboName] = @{ Type = 'feature'; FeatureId = $feature.FeatureId; Label = $feature.Label; Category = $categoryName }
            }
        }
    }

    # Build a feature-label lookup so GenerateOverview can resolve feature IDs without reloading JSON
    $script:FeatureLabelLookup = @{}
    $script:UndoFeatureLabelLookup = @{}
    foreach ($f in $featuresJson.Features) {
        $script:FeatureLabelLookup[$f.FeatureId] = $f.Label
        $script:UndoFeatureLabelLookup[$f.FeatureId] = $f.UndoLabel
    }
}

function Update-CurrentTweakSystemState {
    param(
        [System.Windows.Window]$Window,
        [bool]$ApplyToUi
    )

    if (-not $script:UiControlMappings) { return }
    if (-not $script:Features) { return }

    $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"
    if (-not $featuresJson) { return }

    $groupMap = @{}
    if ($featuresJson.UiGroups) {
        foreach ($g in $featuresJson.UiGroups) {
            $groupMap[$g.GroupId] = $g
        }
    }

    foreach ($controlName in $script:UiControlMappings.Keys) {
        $control = $Window.FindName($controlName)
        if (-not $control) { continue }
        $mapping = $script:UiControlMappings[$controlName]

        if ($control -is [System.Windows.Controls.CheckBox] -and $mapping.Type -eq 'feature') {
            $applied = $false
            try { $applied = [bool](Test-FeatureApplied -FeatureId $mapping.FeatureId) } catch {}
            $featureObj = $script:Features[$mapping.FeatureId]
            $disableWhenApplied = $featureObj -and $featureObj.DisableWhenApplied -eq $true
            Add-Member -InputObject $control -MemberType NoteProperty -Name 'SystemState' -Value $applied -Force
            Add-Member -InputObject $control -MemberType NoteProperty -Name 'DisableWhenApplied' -Value $disableWhenApplied -Force

            if ($ApplyToUi) {
                $control.IsChecked = $applied
                $control.IsEnabled = -not ($applied -and $disableWhenApplied)
                Add-Member -InputObject $control -MemberType NoteProperty -Name 'InitialState' -Value $applied -Force
            }
        }
        elseif ($control -is [System.Windows.Controls.ComboBox] -and $mapping.Type -eq 'group') {
            $groupId = $null
            if ($controlName -match '^Group_(.+)Combo$') { $groupId = $matches[1] }
            $activeIndex = 0
            if ($groupId -and $groupMap.ContainsKey($groupId)) {
                try { $activeIndex = Get-CurrentGroupActiveIndex -Group $groupMap[$groupId] } catch {}
            }
            Add-Member -InputObject $control -MemberType NoteProperty -Name 'SystemIndex' -Value $activeIndex -Force

            if ($ApplyToUi) {
                $control.SelectedIndex = $activeIndex
                Add-Member -InputObject $control -MemberType NoteProperty -Name 'InitialIndex' -Value $activeIndex -Force
            }
        }
    }
}

function Load-CurrentTweakStateIntoUI {
    param([System.Windows.Window]$Window)

    Update-CurrentTweakSystemState -Window $Window -ApplyToUi:$true
}

function Reset-TweaksToSystemState {
    param(
        [System.Windows.Window]$Window,
        [bool]$LoadSystemState
    )

    if (-not $script:UiControlMappings) { return }

    foreach ($controlName in $script:UiControlMappings.Keys) {
        $control = $Window.FindName($controlName)
        if (-not $control) { continue }

        if ($control -is [System.Windows.Controls.CheckBox]) {
            if ($LoadSystemState) {
                # Set checkbox to the currently applied state from registry
                $applied = if ($null -ne $control.PSObject.Properties['SystemState']) { [bool]$control.SystemState } else { $false }
                $disableWhenApplied = $null -ne $control.PSObject.Properties['DisableWhenApplied'] -and [bool]$control.DisableWhenApplied
                $control.IsChecked = $applied
                $control.IsEnabled = -not ($applied -and $disableWhenApplied)
                Add-Member -InputObject $control -MemberType NoteProperty -Name 'InitialState' -Value $applied -Force
            }
            else {
                # Clear the checkbox
                $control.IsChecked = $false
                $control.IsEnabled = $true
                Add-Member -InputObject $control -MemberType NoteProperty -Name 'InitialState' -Value $false -Force
            }
        }
        elseif ($control -is [System.Windows.Controls.ComboBox]) {
            if ($LoadSystemState) {
                # Set combobox to the currently applied state from registry
                $idx = if ($null -ne $control.PSObject.Properties['SystemIndex']) { [int]$control.SystemIndex } else { 0 }
                $control.SelectedIndex = $idx
                Add-Member -InputObject $control -MemberType NoteProperty -Name 'InitialIndex' -Value $idx -Force
            }
            else {
                # Reset to first item (No Change)
                $control.SelectedIndex = 0
                Add-Member -InputObject $control -MemberType NoteProperty -Name 'InitialIndex' -Value 0 -Force
            }
        }
    }
}

function Update-TweaksResponsiveColumns {
    param([System.Windows.Window]$Window)

    $tweaksGrid = $Window.FindName('TweaksGrid')
    $col0 = $Window.FindName('Column0Panel')
    $col1 = $Window.FindName('Column1Panel')
    $col2 = $Window.FindName('Column2Panel')

    if (-not $tweaksGrid -or -not $col0 -or -not $col1 -or -not $col2) { return }
    if ($tweaksGrid.ColumnDefinitions.Count -lt 3) { return }
    if ($null -eq $script:TweaksCardsMovedFromCol2) { $script:TweaksCardsMovedFromCol2 = @() }

    $useTwoColumns = $Window.ActualWidth -lt 1200
    if ($script:TweaksCompactMode -eq $useTwoColumns) { return }
    $script:TweaksCompactMode = $useTwoColumns

    if ($useTwoColumns) {
        $tweaksGrid.ColumnDefinitions[0].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $tweaksGrid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
        $tweaksGrid.ColumnDefinitions[2].Width = [System.Windows.GridLength]::new(0)
        $col2.Visibility = 'Collapsed'

        # Move third-column cards once when entering compact mode.
        $cardsToMove = @($col2.Children) | Where-Object { $_ -is [System.Windows.UIElement] }
        $script:TweaksCardsMovedFromCol2 = @($cardsToMove)
        $col2.Children.Clear()
        $targetColumns = @($col0, $col1)
        foreach ($card in $cardsToMove) {
            $target = $targetColumns |
                Sort-Object @{Expression = { $_.Children.Count }; Ascending = $true }, @{Expression = { $targetColumns.IndexOf($_) }; Ascending = $true } |
                Select-Object -First 1
            $target.Children.Add($card) | Out-Null
        }
        return
    }

    $tweaksGrid.ColumnDefinitions[0].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $tweaksGrid.ColumnDefinitions[1].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $tweaksGrid.ColumnDefinitions[2].Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    $col2.Visibility = 'Visible'

    foreach ($card in (@($script:TweaksCardsMovedFromCol2) | Where-Object { $_ -is [System.Windows.UIElement] })) {
        if ($col0.Children.Contains($card)) {
            $col0.Children.Remove($card) | Out-Null
        }
        elseif ($col1.Children.Contains($card)) {
            $col1.Children.Remove($card) | Out-Null
        }
        $col2.Children.Add($card) | Out-Null
    }
    $script:TweaksCardsMovedFromCol2 = @()
}

function Clear-TweakSelections {
    param([System.Windows.Window]$Window)

    if (-not $script:UiControlMappings) { return }

    foreach ($controlName in $script:UiControlMappings.Keys) {
        $control = $Window.FindName($controlName)
        if ($control -is [System.Windows.Controls.CheckBox]) {
            $control.IsChecked = $false
            $control.IsEnabled = $true
        }
        elseif ($control -is [System.Windows.Controls.ComboBox]) {
            $control.SelectedIndex = 0
        }
    }
}

function Clear-TweakHighlights {
    param([System.Windows.Window]$Window)

    $col0 = $Window.FindName('Column0Panel')
    $col1 = $Window.FindName('Column1Panel')
    $col2 = $Window.FindName('Column2Panel')
    $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }
    foreach ($column in $columns) {
        foreach ($card in $column.Children) {
            if ($card -is [System.Windows.Controls.Border] -and $card.Child -is [System.Windows.Controls.StackPanel]) {
                foreach ($control in $card.Child.Children) {
                    if ($control -is [System.Windows.Controls.CheckBox] -or
                        ($control -is [System.Windows.Controls.Border] -and $control.Name -like '*_LabelBorder')) {
                        $control.Background = [System.Windows.Media.Brushes]::Transparent
                    }
                }
            }
        }
    }
}

function Test-ComboBoxContainsMatch {
    param ([System.Windows.Controls.ComboBox]$ComboBox, [string]$SearchText)

    foreach ($item in $ComboBox.Items) {
        $itemText = if ($item -is [System.Windows.Controls.ComboBoxItem]) { $item.Content.ToString().ToLower() } else { $item.ToString().ToLower() }
        if ($itemText.Contains($SearchText)) { return $true }
    }
    return $false
}
