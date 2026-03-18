function Show-MainWindow {
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms | Out-Null

    # Get current Windows build version
    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

    $usesDarkMode = GetSystemUsesDarkMode

    # Load XAML from file
    $xaml = Get-Content -Path $script:MainWindowSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode

    # Get named elements
    $titleBar = $window.FindName('TitleBar')
    $kofiBtn = $window.FindName('KofiBtn')
    $menuBtn = $window.FindName('MenuBtn')
    $closeBtn = $window.FindName('CloseBtn')
    $menuDocumentation = $window.FindName('MenuDocumentation')
    $menuReportBug = $window.FindName('MenuReportBug')
    $menuLogs = $window.FindName('MenuLogs')
    $menuAbout = $window.FindName('MenuAbout')

    # Title bar event handlers
    $titleBar.Add_MouseLeftButtonDown({
        if ($_.OriginalSource -is [System.Windows.Controls.Grid] -or $_.OriginalSource -is [System.Windows.Controls.Border] -or $_.OriginalSource -is [System.Windows.Controls.TextBlock]) {
            $window.DragMove()
        }
    })
    
    $kofiBtn.Add_Click({
        Start-Process "https://ko-fi.com/raphire"
    })
    
    $menuBtn.Add_Click({
        $menuBtn.ContextMenu.PlacementTarget = $menuBtn
        $menuBtn.ContextMenu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
        $menuBtn.ContextMenu.IsOpen = $true
    })

    $menuDocumentation.Add_Click({
        Start-Process "https://github.com/Raphire/Win11Debloat/wiki"
    })

    $menuReportBug.Add_Click({
        Start-Process "https://github.com/Raphire/Win11Debloat/issues"
    })

    $menuLogs.Add_Click({
        $logsFolder = Join-Path $PSScriptRoot "../../Logs"
        if (Test-Path $logsFolder) {
            Start-Process "explorer.exe" -ArgumentList $logsFolder
        }
        else {
            Show-MessageBox -Message "No logs folder found at: $logsFolder" -Title "Logs" -Button 'OK' -Icon 'Information'
        }
    })

    $menuAbout.Add_Click({
        Show-AboutDialog -Owner $window
    })

    $closeBtn.Add_Click({
        $window.Close()
    })

    # Ensure closing the main window stops all execution
    $window.Add_Closing({
        $script:CancelRequested = $true
    })

    # Implement window resize functionality
    $resizeLeft = $window.FindName('ResizeLeft')
    $resizeRight = $window.FindName('ResizeRight')
    $resizeTop = $window.FindName('ResizeTop')
    $resizeBottom = $window.FindName('ResizeBottom')
    $resizeTopLeft = $window.FindName('ResizeTopLeft')
    $resizeTopRight = $window.FindName('ResizeTopRight')
    $resizeBottomLeft = $window.FindName('ResizeBottomLeft')
    $resizeBottomRight = $window.FindName('ResizeBottomRight')

    $script:resizing = $false
    $script:resizeEdges = $null
    $script:resizeStart = $null
    $script:windowStart = $null
    $script:resizeElement = $null

    $resizeHandler = {
        param($sender, $e)
        
        $script:resizing = $true
        $script:resizeElement = $sender
        $script:resizeStart = [System.Windows.Forms.Cursor]::Position
        $script:windowStart = @{
            Left = $window.Left
            Top = $window.Top
            Width = $window.ActualWidth
            Height = $window.ActualHeight
        }
        
        # Parse direction tag into edge flags for cleaner resize logic
        $direction = $sender.Tag
        $script:resizeEdges = @{
            Left = $direction -match 'Left'
            Right = $direction -match 'Right'
            Top = $direction -match 'Top'
            Bottom = $direction -match 'Bottom'
        }
        
        $sender.CaptureMouse()
        $e.Handled = $true
    }

    $moveHandler = {
        param($sender, $e)
        if (-not $script:resizing) { return }
        
        $current = [System.Windows.Forms.Cursor]::Position
        $deltaX = $current.X - $script:resizeStart.X
        $deltaY = $current.Y - $script:resizeStart.Y

        # Handle horizontal resize
        if ($script:resizeEdges.Left) {
            $newWidth = [Math]::Max($window.MinWidth, $script:windowStart.Width - $deltaX)
            if ($newWidth -ne $window.Width) {
                $window.Left = $script:windowStart.Left + ($script:windowStart.Width - $newWidth)
                $window.Width = $newWidth
            }
        }
        elseif ($script:resizeEdges.Right) {
            $window.Width = [Math]::Max($window.MinWidth, $script:windowStart.Width + $deltaX)
        }

        # Handle vertical resize
        if ($script:resizeEdges.Top) {
            $newHeight = [Math]::Max($window.MinHeight, $script:windowStart.Height - $deltaY)
            if ($newHeight -ne $window.Height) {
                $window.Top = $script:windowStart.Top + ($script:windowStart.Height - $newHeight)
                $window.Height = $newHeight
            }
        }
        elseif ($script:resizeEdges.Bottom) {
            $window.Height = [Math]::Max($window.MinHeight, $script:windowStart.Height + $deltaY)
        }
        
        $e.Handled = $true
    }

    $releaseHandler = {
        param($sender, $e)
        if ($script:resizing -and $script:resizeElement) {
            $script:resizing = $false
            $script:resizeEdges = $null
            $script:resizeElement.ReleaseMouseCapture()
            $script:resizeElement = $null
            $e.Handled = $true
        }
    }

    # Set tags and add event handlers for resize borders
    $resizeLeft.Tag = 'Left'
    $resizeLeft.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeLeft.Add_MouseMove($moveHandler)
    $resizeLeft.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeRight.Tag = 'Right'
    $resizeRight.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeRight.Add_MouseMove($moveHandler)
    $resizeRight.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeTop.Tag = 'Top'
    $resizeTop.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeTop.Add_MouseMove($moveHandler)
    $resizeTop.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeBottom.Tag = 'Bottom'
    $resizeBottom.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeBottom.Add_MouseMove($moveHandler)
    $resizeBottom.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeTopLeft.Tag = 'TopLeft'
    $resizeTopLeft.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeTopLeft.Add_MouseMove($moveHandler)
    $resizeTopLeft.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeTopRight.Tag = 'TopRight'
    $resizeTopRight.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeTopRight.Add_MouseMove($moveHandler)
    $resizeTopRight.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeBottomLeft.Tag = 'BottomLeft'
    $resizeBottomLeft.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeBottomLeft.Add_MouseMove($moveHandler)
    $resizeBottomLeft.Add_MouseLeftButtonUp($releaseHandler)
    
    $resizeBottomRight.Tag = 'BottomRight'
    $resizeBottomRight.Add_PreviewMouseLeftButtonDown($resizeHandler)
    $resizeBottomRight.Add_MouseMove($moveHandler)
    $resizeBottomRight.Add_MouseLeftButtonUp($releaseHandler)

    # Integrated App Selection UI
    $appsPanel = $window.FindName('AppSelectionPanel')
    $onlyInstalledAppsBox = $window.FindName('OnlyInstalledAppsBox')
    $loadingAppsIndicator = $window.FindName('LoadingAppsIndicator')
    $appSelectionStatus = $window.FindName('AppSelectionStatus')
    $headerNameBtn = $window.FindName('HeaderNameBtn')
    $headerDescriptionBtn = $window.FindName('HeaderDescriptionBtn')
    $headerAppIdBtn = $window.FindName('HeaderAppIdBtn')
    $sortArrowName = $window.FindName('SortArrowName')
    $sortArrowDescription = $window.FindName('SortArrowDescription')
    $sortArrowAppId = $window.FindName('SortArrowAppId')
    $presetsBtn = $window.FindName('PresetsBtn')
    $presetsPopup = $window.FindName('PresetsPopup')
    $presetDefaultApps = $window.FindName('PresetDefaultApps')
    $presetLastUsed = $window.FindName('PresetLastUsed')
    $jsonPresetsPanel = $window.FindName('JsonPresetsPanel')
    $presetsArrow = $window.FindName('PresetsArrow')
    $clearAppSelectionBtn = $window.FindName('ClearAppSelectionBtn')

    # Load JSON-defined presets and build dynamic preset checkboxes
    $script:JsonPresetCheckboxes = @()
    foreach ($preset in (LoadAppPresetsFromJson)) {
        $checkbox = New-Object System.Windows.Controls.CheckBox
        $checkbox.Content = $preset.Name
        $checkbox.IsThreeState = $true
        $checkbox.Style = $window.Resources['PresetCheckBoxStyle']
        $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $preset.Name)
        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'PresetAppIds' -Value $preset.AppIds
        $jsonPresetsPanel.Children.Add($checkbox) | Out-Null
        $script:JsonPresetCheckboxes += $checkbox

        $checkbox.Add_Click({
            if ($script:UpdatingPresets) { return }
            $check = ($this.IsChecked -eq $true)
            if ($this.IsChecked -eq $null) { $this.IsChecked = $false; $check = $false }
            $presetIds = $this.PresetAppIds
            ApplyPresetToApps -MatchFilter { param($c) $presetIds -contains $c.Tag }.GetNewClosure() -Check $check
        })
    }
    
    # Track the last selected checkbox for shift-click range selection
    $script:MainWindowLastSelectedCheckbox = $null
    
    # Guard flag: true while a load is in progress; prevents concurrent loads
    $script:IsLoadingApps = $false
    # Flag set when Default Mode is clicked before apps have finished loading
    $script:PendingDefaultMode = $false
    # Holds apps data preloaded before ShowDialog() so the first load skips the background job
    $script:PreloadedAppData = $null
    
    # Set script-level variable for GUI window reference
    $script:GuiWindow = $window

    # Guard flag to prevent preset handlers from firing when we update their state programmatically
    $script:UpdatingPresets = $false

    # Sort state for the app table
    $script:SortColumn = 'Name'
    $script:SortAscending = $true

    function UpdateSortArrows {
        $ease = New-Object System.Windows.Media.Animation.CubicEase
        $ease.EasingMode = 'EaseOut'
        $arrows = @{
            'Name'        = $sortArrowName
            'Description' = $sortArrowDescription
            'AppId'       = $sortArrowAppId
        }
        foreach ($col in $arrows.Keys) {
            $tb = $arrows[$col]
            # Active column: full opacity, rotate to indicate direction (0 = up/asc, 180 = down/desc)
            # Inactive columns: dim, reset to 0
            if ($col -eq $script:SortColumn) {
                $targetAngle = if ($script:SortAscending) { 0 } else { 180 }
                $tb.Opacity = 1.0
            } else {
                $targetAngle = 0
                $tb.Opacity = 0.3
            }
            $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
            $anim.To = $targetAngle
            $anim.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(200))
            $anim.EasingFunction = $ease
            $tb.RenderTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $anim)
        }
    }

    # Rebuilds $script:AppSearchMatches by scanning appsPanel children in their current order,
    # collecting any that are still highlighted. Preserves the active match across reorderings.
    function RebuildAppSearchIndex {
        param($activeMatch = $null)
        $newMatches = @()
        $newActiveIndex = -1
        $i = 0
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.Background -ne [System.Windows.Media.Brushes]::Transparent) {
                $newMatches += $child
                if ($null -ne $activeMatch -and [System.Object]::ReferenceEquals($child, $activeMatch)) {
                    $newActiveIndex = $i
                }
                $i++
            }
        }
        $script:AppSearchMatches = $newMatches
        $script:AppSearchMatchIndex = if ($newActiveIndex -ge 0) { $newActiveIndex } elseif ($newMatches.Count -gt 0) { 0 } else { -1 }
    }

    function SortApps {
        $children = @($appsPanel.Children)
        $key = switch ($script:SortColumn) {
            'Name'        { { $_.AppName } }
            'Description' { { $_.AppDescription } }
            'AppId'       { { $_.Tag } }
        }
        $sorted = $children | Sort-Object $key -Descending:(-not $script:SortAscending)
        $appsPanel.Children.Clear()
        foreach ($checkbox in $sorted) {
            $appsPanel.Children.Add($checkbox) | Out-Null
        }
        UpdateSortArrows

        # Rebuild search match list in new sorted order so keyboard navigation stays correct
        if ($script:AppSearchMatches.Count -gt 0) {
            $activeMatch = if ($script:AppSearchMatchIndex -ge 0 -and $script:AppSearchMatchIndex -lt $script:AppSearchMatches.Count) {
                $script:AppSearchMatches[$script:AppSearchMatchIndex]
            } else { $null }
            RebuildAppSearchIndex -activeMatch $activeMatch
        }
    }

    function SetSortColumn($column) {
        if ($script:SortColumn -eq $column) {
            $script:SortAscending = -not $script:SortAscending
        } else {
            $script:SortColumn = $column
            $script:SortAscending = $true
        }
        SortApps
    }

    function UpdateAppSelectionStatus {
        $selectedCount = 0
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedCount++
            }
        }
        $appSelectionStatus.Text = "$selectedCount app(s) selected for removal"
    }

    # Applies a preset by checking/unchecking apps that match the given filter
    # When -Exclusive is set, all apps are unchecked first so only matching apps end up selected
    function ApplyPresetToApps {
        param ( 
            [scriptblock]$MatchFilter,
            [bool]$Check,
            [switch]$Exclusive
        )
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                if ($Exclusive) {
                    $child.IsChecked = (& $MatchFilter $child)
                } elseif (& $MatchFilter $child) {
                    $child.IsChecked = $Check
                }
            }
        }
        UpdatePresetStates
    }

    # Update preset checkboxes to reflect checked/indeterminate/unchecked state
    function UpdatePresetStates {
        $script:UpdatingPresets = $true
        try {
            # Build a set of currently checked app tags for fast lookup
            $checkedTags = @{}
            foreach ($child in $appsPanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                    $checkedTags[$child.Tag] = $true
                }
            }

            # Helper: count matching and checked apps, set checkbox state
            function SetPresetState($checkbox, [scriptblock]$MatchFilter) {
                $total = 0; $checked = 0
                foreach ($child in $appsPanel.Children) {
                    if ($child -is [System.Windows.Controls.CheckBox]) {
                        if (& $MatchFilter $child) {
                            $total++
                            if ($checkedTags.ContainsKey($child.Tag)) { $checked++ }
                        }
                    }
                }
                if ($total -eq 0) {
                    $checkbox.IsChecked = $false
                    $checkbox.IsEnabled = $false
                } else {
                    $checkbox.IsEnabled = $true
                    if ($checked -eq 0) {
                        $checkbox.IsChecked = $false
                    } elseif ($checked -eq $total) {
                        $checkbox.IsChecked = $true
                    } else {
                        $checkbox.IsChecked = [System.Nullable[bool]]$null
                    }
                }
            }

            SetPresetState $presetDefaultApps { param($c) $c.SelectedByDefault -eq $true }
            foreach ($jsonCb in $script:JsonPresetCheckboxes) {
                $localIds = $jsonCb.PresetAppIds
                SetPresetState $jsonCb { param($c) $localIds -contains $c.Tag }.GetNewClosure()
            }

            # Last used preset: only update if it's visible (has saved apps)
            if ($presetLastUsed.Visibility -ne 'Collapsed' -and $script:SavedAppIds) {
                SetPresetState $presetLastUsed { param($c) $script:SavedAppIds -contains $c.Tag }
            }
        }
        finally {
            $script:UpdatingPresets = $false
        }
    }

    # Dynamically builds Tweaks UI from Features.json
    function BuildDynamicTweaks {
        $featuresJson = LoadJsonFile -filePath $script:FeaturesFilePath -expectedVersion "1.0"

        if (-not $featuresJson) {
            Show-MessageBox -Message "Unable to load Features.json file!" -Title "Error" -Button 'OK' -Icon 'Error' | Out-Null
            Exit
        }

        # Column containers
        $col0 = $window.FindName('Column0Panel')
        $col1 = $window.FindName('Column1Panel')
        $col2 = $window.FindName('Column2Panel')
        $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }

        # Clear all columns for fully dynamic panel creation
        foreach ($col in $columns) {
            if ($col) { $col.Children.Clear() }
        }

        $script:UiControlMappings = @{}
        $script:CategoryCardMap = @{}

        function CreateLabeledCombo($parent, $labelText, $comboName, $items) {
            # If only 2 items (No Change + one option), use a checkbox instead
            if ($items.Count -eq 2) {
                $checkbox = New-Object System.Windows.Controls.CheckBox
                $checkbox.Content = $labelText
                $checkbox.Name = $comboName
                $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $labelText)
                $checkbox.IsChecked = $false
                $checkbox.Style = $window.Resources["FeatureCheckboxStyle"]
                $parent.Children.Add($checkbox) | Out-Null
                
                # Register the checkbox with the window's name scope
                try {
                    [System.Windows.NameScope]::SetNameScope($checkbox, [System.Windows.NameScope]::GetNameScope($window))
                    $window.RegisterName($comboName, $checkbox)
                }
                catch {
                    # Name might already be registered, ignore
                }
                
                return $checkbox
            }
            
            # Otherwise use a combobox for multiple options
            # Wrap label in a Border for search highlighting
            $lblBorder = New-Object System.Windows.Controls.Border
            $lblBorder.Style = $window.Resources['LabelBorderStyle']
            $lblBorderName = "$comboName`_LabelBorder"
            $lblBorder.Name = $lblBorderName
            
            $lbl = New-Object System.Windows.Controls.TextBlock
            $lbl.Text = $labelText
            $lbl.Style = $window.Resources['LabelStyle']
            $labelName = "$comboName`_Label"
            $lbl.Name = $labelName
            
            $lblBorder.Child = $lbl
            $parent.Children.Add($lblBorder) | Out-Null
            
            # Register the label border with the window's name scope
            try {
                [System.Windows.NameScope]::SetNameScope($lblBorder, [System.Windows.NameScope]::GetNameScope($window))
                $window.RegisterName($lblBorderName, $lblBorder)
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
                [System.Windows.NameScope]::SetNameScope($combo, [System.Windows.NameScope]::GetNameScope($window))
                $window.RegisterName($comboName, $combo)
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
            $target = $columns | Sort-Object @{Expression={$_.Children.Count}; Ascending=$true}, @{Expression={$columns.IndexOf($_)}; Ascending=$true} | Select-Object -First 1

            $border = New-Object System.Windows.Controls.Border
            $border.Style = $window.Resources['CategoryCardBorderStyle']
            $border.Tag = 'DynamicCategory'

            $panel = New-Object System.Windows.Controls.StackPanel
            $safe = ($categoryName -replace '[^a-zA-Z0-9_]','_')
            $panel.Name = "Category_{0}_Panel" -f $safe

            $headerRow = New-Object System.Windows.Controls.StackPanel
            $headerRow.Orientation = 'Horizontal'

            # Add category icon
            $icon = New-Object System.Windows.Controls.TextBlock
            # Convert HTML entity to character (e.g., &#xE72E; -> actual character)
            if ($categoryIcon -match '&#x([0-9A-Fa-f]+);') {
                $hexValue = [Convert]::ToInt32($matches[1], 16)
                $icon.Text = [char]$hexValue
            }
            $icon.Style = $window.Resources['CategoryHeaderIcon']
            $headerRow.Children.Add($icon) | Out-Null

            $header = New-Object System.Windows.Controls.TextBlock
            $header.Text = $categoryName
            $header.Style = $window.Resources['CategoryHeaderTextBlock']
            $headerRow.Children.Add($header) | Out-Null

            $helpIcon = New-Object System.Windows.Controls.TextBlock
            $helpIcon.Text = '(?)'
            $helpIcon.Style = $window.Resources['CategoryHelpLinkTextStyle']

            $helpBtn = New-Object System.Windows.Controls.Button
            $helpBtn.Content = $helpIcon
            $helpBtn.ToolTip = "Open wiki for more info on '$categoryName' tweaks"
            $helpBtn.Tag = (GetWikiUrlForCategory -category $categoryName)
            $helpBtn.Style = $window.Resources['CategoryHelpLinkButtonStyle']
            $helpBtn.Add_Click({
                param($sender, $e)
                if ($sender.Tag) { Start-Process $sender.Tag }
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
                    $categoryObj = if ($c -is [string]) { @{Name = $c; Icon = '&#xE712;'} } else { $c }
                    $orderedCategories += $categoryObj
                }
            }
        } else {
            # For backward compatibility, create category objects from keys
            foreach ($catName in $categoriesPresent.Keys) {
                $orderedCategories += @{Name = $catName; Icon = '&#xE712;'}
            }
        }

        foreach ($categoryObj in $orderedCategories) {
            $categoryName = $categoryObj.Name
            
            # Create/get card for this category
            $panel = GetOrCreateCategoryCard -categoryObj $categoryObj
            if (-not $panel) { continue }

            # Collect groups and features for this category, then sort by priority
            $categoryItems = @()

            # Add any groups for this category
            if ($featuresJson.UiGroups) {
                $groupIndex = 0
                foreach ($group in $featuresJson.UiGroups) {
                    if ($group.Category -ne $categoryName) { $groupIndex++; continue }
                    $categoryItems += [PSCustomObject]@{
                        Type = 'group'
                        Data = $group
                        Priority = if ($null -ne $group.Priority) { $group.Priority } else { [int]::MaxValue }
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
                    Type = 'feature'
                    Data = $feature
                    Priority = if ($null -ne $feature.Priority) { $feature.Priority } else { [int]::MaxValue }
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
                    $items = @('No Change') + ($group.Values | ForEach-Object { $_.Label })
                    $comboName = 'Group_{0}Combo' -f $group.GroupId
                    $combo = CreateLabeledCombo -parent $panel -labelText $group.Label -comboName $comboName -items $items
                    # attach tooltip from UiGroups if present
                    if ($group.ToolTip) {
                        $tipBlock = New-Object System.Windows.Controls.TextBlock
                        $tipBlock.Text = $group.ToolTip
                        $tipBlock.TextWrapping = 'Wrap'
                        $tipBlock.MaxWidth = 420
                        $combo.ToolTip = $tipBlock
                        $lblBorderObj = $null
                        try { $lblBorderObj = $window.FindName("$comboName`_LabelBorder") } catch {}
                        if ($lblBorderObj) { $lblBorderObj.ToolTip = $tipBlock }
                    }
                    $script:UiControlMappings[$comboName] = @{ Type='group'; Values = $group.Values; Label = $group.Label }
                }
                elseif ($item.Type -eq 'feature') {
                    $feature = $item.Data
                    $opt = 'Apply'
                    if ($feature.FeatureId -match '^Disable') { $opt = 'Disable' } elseif ($feature.FeatureId -match '^Enable') { $opt = 'Enable' }
                    $items = @('No Change', $opt)
                    $comboName = ("Feature_{0}_Combo" -f $feature.FeatureId) -replace '[^a-zA-Z0-9_]',''
                    $combo = CreateLabeledCombo -parent $panel -labelText ($feature.Action + ' ' + $feature.Label) -comboName $comboName -items $items
                    # attach tooltip from Features.json if present
                    if ($feature.ToolTip) {
                        $tipBlock = New-Object System.Windows.Controls.TextBlock
                        $tipBlock.Text = $feature.ToolTip
                        $tipBlock.TextWrapping = 'Wrap'
                        $tipBlock.MaxWidth = 420
                        $combo.ToolTip = $tipBlock
                        $lblBorderObj = $null
                        try { $lblBorderObj = $window.FindName("$comboName`_LabelBorder") } catch {}
                        if ($lblBorderObj) { $lblBorderObj.ToolTip = $tipBlock }
                    }
                    $script:UiControlMappings[$comboName] = @{ Type='feature'; FeatureId = $feature.FeatureId; Action = $feature.Action; Label = $feature.Label }
                }
            }
        }

        # Build a feature-label lookup so GenerateOverview can resolve feature IDs without reloading JSON
        $script:FeatureLabelLookup = @{}
        foreach ($f in $featuresJson.Features) {
            $script:FeatureLabelLookup[$f.FeatureId] = $f.Action + ' ' + $f.Label
        }
    }

    # Helper function to load apps and populate the app list panel
    function script:LoadAppsWithList($listOfApps) {
        $script:MainWindowLastSelectedCheckbox = $null

        $loaderScriptPath = $script:LoadAppsDetailsScriptPath
        $appsFilePath  = $script:AppsListFilePath
        $onlyInstalled = [bool]$onlyInstalledAppsBox.IsChecked

        # Use preloaded data if available; otherwise load in background job
        if (-not $onlyInstalled -and $script:PreloadedAppData) {
            $rawAppData = $script:PreloadedAppData
            $script:PreloadedAppData = $null
        } else {
            # Load apps details in a background job to keep the UI responsive
            $rawAppData = Invoke-NonBlocking -ScriptBlock {
                param($loaderScript, $appsListFilePath, $installedList, $onlyInstalled)
                $script:AppsListFilePath = $appsListFilePath
                . $loaderScript
                LoadAppsDetailsFromJson -OnlyInstalled:$onlyInstalled -InstalledList $installedList -InitialCheckedFromJson:$false
            } -ArgumentList $loaderScriptPath, $appsFilePath, $listOfApps, $onlyInstalled
        }

        $appsToAdd = @($rawAppData | Where-Object { $_ -and ($_.AppId -or $_.FriendlyName) } | Sort-Object -Property FriendlyName)

        $loadingAppsIndicator.Visibility = 'Collapsed'

        if ($appsToAdd.Count -eq 0) {
            $window.FindName('DeploymentApplyBtn').IsEnabled = $true
            return
        }

        $brushSafe    = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#4CAF50')
        $brushUnsafe  = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#F44336')
        $brushDefault = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FFC107')
        $brushSafe.Freeze(); $brushUnsafe.Freeze(); $brushDefault.Freeze()

        # Create WPF controls; pump the Dispatcher every batch so the spinner keeps animating.
        $batchSize = 20
        for ($i = 0; $i -lt $appsToAdd.Count; $i++) {
            $app = $appsToAdd[$i]

            $checkbox = New-Object System.Windows.Controls.CheckBox
            $automationName = if ($app.FriendlyName) { $app.FriendlyName } elseif ($app.AppId) { $app.AppId } else { $null }
            if ($automationName) { $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $automationName) }
            $checkbox.Tag       = $app.AppId
            $checkbox.IsChecked = $app.IsChecked
            $checkbox.Style     = $window.Resources['AppsPanelCheckBoxStyle']

            # Build table row: Recommendation dot | Name | Description | App ID
            $row = New-Object System.Windows.Controls.Grid
            $row.Style = $window.Resources['AppTableRowStyle']
            $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = $window.Resources['AppTableDotColWidth']
            $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = $window.Resources['AppTableNameColWidth']
            $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = $window.Resources['AppTableDescColWidth']
            $c3 = New-Object System.Windows.Controls.ColumnDefinition; $c3.Width = $window.Resources['AppTableIdColWidth']
            $row.ColumnDefinitions.Add($c0); $row.ColumnDefinitions.Add($c1)
            $row.ColumnDefinitions.Add($c2); $row.ColumnDefinitions.Add($c3)

            $dot = New-Object System.Windows.Shapes.Ellipse
            $dot.Style = $window.Resources['AppRecommendationDotStyle']
            $dot.Fill  = switch ($app.Recommendation) { 'safe' { $brushSafe } 'unsafe' { $brushUnsafe } default { $brushDefault } }
            $dot.ToolTip = switch ($app.Recommendation) {
                'safe'   { '[Recommended] Safe to remove for most users' }
                'unsafe' { '[Not Recommended] Only remove if you know what you are doing' }
                default  { "[Optional] Remove if you don't need this app" }
            }
            [System.Windows.Controls.Grid]::SetColumn($dot, 0)

            $tbName = New-Object System.Windows.Controls.TextBlock
            $tbName.Text  = $app.FriendlyName
            $tbName.Style = $window.Resources['AppNameTextStyle']
            [System.Windows.Controls.Grid]::SetColumn($tbName, 1)

            $tbDesc = New-Object System.Windows.Controls.TextBlock
            $tbDesc.Text    = $app.Description
            $tbDesc.Style   = $window.Resources['AppDescTextStyle']
            $tbDesc.ToolTip = $app.Description
            [System.Windows.Controls.Grid]::SetColumn($tbDesc, 2)

            $tbId = New-Object System.Windows.Controls.TextBlock
            $tbId.Text    = $app.AppId
            $tbId.Style   = $window.Resources['AppIdTextStyle']
            $tbId.ToolTip = $app.AppId
            [System.Windows.Controls.Grid]::SetColumn($tbId, 3)

            $row.Children.Add($dot)    | Out-Null
            $row.Children.Add($tbName) | Out-Null
            $row.Children.Add($tbDesc) | Out-Null
            $row.Children.Add($tbId)   | Out-Null
            $checkbox.Content = $row

            Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'AppName'          -Value $app.FriendlyName
            Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'AppDescription'   -Value $app.Description
            Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'SelectedByDefault' -Value $app.SelectedByDefault

            $checkbox.Add_Checked({ UpdateAppSelectionStatus })
            $checkbox.Add_Unchecked({ UpdateAppSelectionStatus })
            AttachShiftClickBehavior -checkbox $checkbox -appsPanel $appsPanel `
                -lastSelectedCheckboxRef ([ref]$script:MainWindowLastSelectedCheckbox) `
                -updateStatusCallback { UpdateAppSelectionStatus }

            $appsPanel.Children.Add($checkbox) | Out-Null

            if (($i + 1) % $batchSize -eq 0) { DoEvents }
        }

        SortApps

        # If Default Mode was clicked while apps were still loading, apply defaults now
        if ($script:PendingDefaultMode) {
            $script:PendingDefaultMode = $false
            ApplyPresetToApps -MatchFilter { param($c) $c.SelectedByDefault -eq $true } -Exclusive
        }
        
        UpdateAppSelectionStatus

        # Re-enable Apply button now that the full, correctly-checked app list is ready
        $window.FindName('DeploymentApplyBtn').IsEnabled = $true
    }

    # Loads apps into the UI
    function LoadAppsIntoMainUI {
        # Prevent concurrent loads
        if ($script:IsLoadingApps) { return }
        $script:IsLoadingApps = $true

        # Show loading indicator and clear existing apps
        $loadingAppsIndicator.Visibility = 'Visible'
        $appsPanel.Children.Clear()

        # Disable Apply button while apps are loading so it can't be clicked with a partial list
        $window.FindName('DeploymentApplyBtn').IsEnabled = $false

        # Update navigation buttons to disable Next/Previous
        UpdateNavigationButtons

        # Force a render so the loading indicator is visible, then schedule the
        # actual loading at Background priority so this call returns immediately.
        # This is critical when called from Add_Loaded: the window must finish
        # its initialization before we start a nested message pump via DoEvents.
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [action]{})
        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{
            try {
                $listOfApps = ""

                if ($onlyInstalledAppsBox.IsChecked -and ($script:WingetInstalled -eq $true)) {
                    $listOfApps = GetInstalledAppsViaWinget -TimeOut 10 -NonBlocking

                    if ($null -eq $listOfApps) {
                        Show-MessageBox -Message 'Unable to load list of installed apps via WinGet.' -Title 'Error' -Button 'OK' -Icon 'Error' | Out-Null
                        $onlyInstalledAppsBox.IsChecked = $false
                    }
                }

                LoadAppsWithList $listOfApps
            }
            finally {
                $script:IsLoadingApps = $false
            }
        }) | Out-Null
    }

    # Event handlers for app selection
    $onlyInstalledAppsBox.Add_Checked({
        LoadAppsIntoMainUI
    })
    $onlyInstalledAppsBox.Add_Unchecked({
        LoadAppsIntoMainUI
    })

    # Animate arrow when popup opens/closes, and lazily update preset states
    $presetsPopup.Add_Opened({
        UpdatePresetStates
        $animation = New-Object System.Windows.Media.Animation.DoubleAnimation
        $animation.To = 180
        $animation.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(200))
        $animation.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase
        $animation.EasingFunction.EasingMode = 'EaseOut'
        $presetsArrow.RenderTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $animation)
    })
    $presetsPopup.Add_Closed({
        $animation = New-Object System.Windows.Media.Animation.DoubleAnimation
        $animation.To = 0
        $animation.Duration = [System.Windows.Duration]::new([System.TimeSpan]::FromMilliseconds(200))
        $animation.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase
        $animation.EasingFunction.EasingMode = 'EaseOut'
        $presetsArrow.RenderTransform.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $animation)
        $presetsBtn.IsChecked = $false
    })

    # Close popup when clicking anywhere outside the popup or the presets button.
    $window.Add_PreviewMouseDown({
        if (-not $presetsPopup.IsOpen) { return }
        if ($presetsPopup.Child -ne $null -and $presetsPopup.Child.IsMouseOver) { return }
        $src = $_.OriginalSource -as [System.Windows.DependencyObject]
        if ($src -ne $null) {
            $inBtn = $presetsBtn.IsAncestorOf($src) -or [System.Object]::ReferenceEquals($presetsBtn, $src)
            if (-not $inBtn) { $presetsPopup.IsOpen = $false }
        }
    })

    # Close the preset menu when the main window loses focus (e.g., user switches to another app).
    $window.Add_Deactivated({
        if ($presetsPopup.IsOpen) { $presetsPopup.IsOpen = $false }
    })

    # Toggle popup on button click
    $presetsBtn.Add_Click({
        $presetsPopup.IsOpen = -not $presetsPopup.IsOpen
        $presetsBtn.IsChecked = $presetsPopup.IsOpen
    })

    # Preset: Default selection
    $presetDefaultApps.Add_Click({
        if ($script:UpdatingPresets) { return }
        $check = ($this.IsChecked -eq $true)
        if ($this.IsChecked -eq $null) { $this.IsChecked = $false; $check = $false }
        ApplyPresetToApps -MatchFilter { param($c) $c.SelectedByDefault -eq $true } -Check $check
    })

    # Clear selection button + reset all preset checkboxes
    $clearAppSelectionBtn.Add_Click({
        ApplyPresetToApps -MatchFilter { param($c) $true } -Check $false
    })

    # Column header sort handlers
    $headerNameBtn.Add_MouseLeftButtonUp({ SetSortColumn 'Name' })
    $headerDescriptionBtn.Add_MouseLeftButtonUp({ SetSortColumn 'Description' })
    $headerAppIdBtn.Add_MouseLeftButtonUp({ SetSortColumn 'AppId' })

    # Helper function to scroll to an item if it's not visible, centering it in the viewport
    function ScrollToItemIfNotVisible {
        param (
            [System.Windows.Controls.ScrollViewer]$scrollViewer,
            [System.Windows.UIElement]$item,
            [System.Windows.UIElement]$container
        )
        
        if (-not $scrollViewer -or -not $item -or -not $container) { return }
        
        try {
            $itemPosition = $item.TransformToAncestor($container).Transform([System.Windows.Point]::new(0, 0)).Y
            $viewportHeight = $scrollViewer.ViewportHeight
            $itemHeight = $item.ActualHeight
            $currentOffset = $scrollViewer.VerticalOffset
            
            # Check if the item is currently visible in the viewport
            $itemTop = $itemPosition - $currentOffset
            $itemBottom = $itemTop + $itemHeight
            
            $isVisible = ($itemTop -ge 0) -and ($itemBottom -le $viewportHeight)
            
            # Only scroll if the item is not visible
            if (-not $isVisible) {
                # Center the item in the viewport
                $targetOffset = $itemPosition - ($viewportHeight / 2) + ($itemHeight / 2)
                $scrollViewer.ScrollToVerticalOffset([Math]::Max(0, $targetOffset))
            }
        }
        catch {
            # Fallback to simple bring into view
            $item.BringIntoView()
        }
    }
    
    # Helper function to find the parent ScrollViewer of an element
    function FindParentScrollViewer {
        param ([System.Windows.UIElement]$element)
        
        $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($element)
        while ($null -ne $parent) {
            if ($parent -is [System.Windows.Controls.ScrollViewer]) {
                return $parent
            }
            $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
        }
        return $null
    }

    # App Search Box functionality
    $appSearchBox = $window.FindName('AppSearchBox')
    $appSearchPlaceholder = $window.FindName('AppSearchPlaceholder')
    
    # Track current search matches and active index for Enter-key navigation
    $script:AppSearchMatches = @()
    $script:AppSearchMatchIndex = -1
    
    $appSearchBox.Add_TextChanged({
        $searchText = $appSearchBox.Text.ToLower().Trim()
        
        # Show/hide placeholder
        $appSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($appSearchBox.Text)) { 'Visible' } else { 'Collapsed' }
        
        # Clear all highlights first
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.Background = [System.Windows.Media.Brushes]::Transparent
            }
        }
        
        $script:AppSearchMatches = @()
        $script:AppSearchMatchIndex = -1
        
        if ([string]::IsNullOrWhiteSpace($searchText)) { return }
        
        # Find and highlight all matching apps
        $highlightBrush = $window.Resources["SearchHighlightColor"]
        $activeHighlightBrush = $window.Resources["SearchHighlightActiveColor"]
        
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.Visibility -eq 'Visible') {
                $appName = if ($child.AppName) { $child.AppName } else { '' }
                $appId = if ($child.Tag) { $child.Tag.ToString() } else { '' }
                $appDesc = if ($child.AppDescription) { $child.AppDescription } else { '' }
                if ($appName.ToLower().Contains($searchText) -or $appId.ToLower().Contains($searchText) -or $appDesc.ToLower().Contains($searchText)) {
                    $child.Background = $highlightBrush
                    $script:AppSearchMatches += $child
                }
            }
        }
        
        # Scroll to first match and mark it as active
        if ($script:AppSearchMatches.Count -gt 0) {
            $script:AppSearchMatchIndex = 0
            $script:AppSearchMatches[0].Background = $activeHighlightBrush
            $scrollViewer = FindParentScrollViewer -element $appsPanel
            if ($scrollViewer) {
                ScrollToItemIfNotVisible -scrollViewer $scrollViewer -item $script:AppSearchMatches[0] -container $appsPanel
            }
        }
    })
    
    $appSearchBox.Add_KeyDown({
        param($sender, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter -and $script:AppSearchMatches.Count -gt 0) {
            # Reset background of current active match
            $script:AppSearchMatches[$script:AppSearchMatchIndex].Background = $window.Resources["SearchHighlightColor"]
            # Advance to next match (wrapping)
            $script:AppSearchMatchIndex = ($script:AppSearchMatchIndex + 1) % $script:AppSearchMatches.Count
            # Highlight new active match
            $script:AppSearchMatches[$script:AppSearchMatchIndex].Background = $window.Resources["SearchHighlightActiveColor"]
            $scrollViewer = FindParentScrollViewer -element $appsPanel
            if ($scrollViewer) {
                ScrollToItemIfNotVisible -scrollViewer $scrollViewer -item $script:AppSearchMatches[$script:AppSearchMatchIndex] -container $appsPanel
            }
            $e.Handled = $true
        }
    })

    # Tweak Search Box functionality
    $tweakSearchBox = $window.FindName('TweakSearchBox')
    $tweakSearchPlaceholder = $window.FindName('TweakSearchPlaceholder')
    $tweakSearchBorder = $window.FindName('TweakSearchBorder')
    $tweaksScrollViewer = $window.FindName('TweaksScrollViewer')
    $tweaksGrid = $window.FindName('TweaksGrid')
    $col0 = $window.FindName('Column0Panel')
    $col1 = $window.FindName('Column1Panel')
    $col2 = $window.FindName('Column2Panel')
    
    # Monitor scrollbar visibility and adjust searchbar margin
    $tweaksScrollViewer.Add_ScrollChanged({
        if ($tweaksScrollViewer.ScrollableHeight -gt 0) {
            # The 17px accounts for the scrollbar width + some padding
            $tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0, 0, 17, 0)
        } else {
            $tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0)
        }
    })
    
    # Helper function to clear all tweak highlights
    function ClearTweakHighlights {
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
    
    # Helper function to check if a ComboBox contains matching items
    function ComboBoxContainsMatch {
        param ([System.Windows.Controls.ComboBox]$comboBox, [string]$searchText)
        
        foreach ($item in $comboBox.Items) {
            $itemText = if ($item -is [System.Windows.Controls.ComboBoxItem]) { $item.Content.ToString().ToLower() } else { $item.ToString().ToLower() }
            if ($itemText.Contains($searchText)) { return $true }
        }
        return $false
    }
    
    $tweakSearchBox.Add_TextChanged({
        $searchText = $tweakSearchBox.Text.ToLower().Trim()
        
        # Show/hide placeholder
        $tweakSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($tweakSearchBox.Text)) { 'Visible' } else { 'Collapsed' }
        
        # Clear all highlights
        ClearTweakHighlights
        
        if ([string]::IsNullOrWhiteSpace($searchText)) { return }
        
        # Find and highlight all matching tweaks
        $firstMatch = $null
        $highlightBrush = $window.Resources["SearchHighlightColor"]
        $columns = @($col0, $col1, $col2) | Where-Object { $_ -ne $null }
        
        foreach ($column in $columns) {
            foreach ($card in $column.Children) {
                if ($card -is [System.Windows.Controls.Border] -and $card.Child -is [System.Windows.Controls.StackPanel]) {
                    $controlsList = @($card.Child.Children)
                    for ($i = 0; $i -lt $controlsList.Count; $i++) {
                        $control = $controlsList[$i]
                        $matchFound = $false
                        $controlToHighlight = $null
                        
                        if ($control -is [System.Windows.Controls.CheckBox]) {
                            if ($control.Content.ToString().ToLower().Contains($searchText)) {
                                $matchFound = $true
                                $controlToHighlight = $control
                            }
                        }
                        elseif ($control -is [System.Windows.Controls.Border] -and $control.Name -like '*_LabelBorder') {
                            $labelText = if ($control.Child) { $control.Child.Text.ToLower() } else { "" }
                            $comboBox = if ($i + 1 -lt $controlsList.Count -and $controlsList[$i + 1] -is [System.Windows.Controls.ComboBox]) { $controlsList[$i + 1] } else { $null }
                            
                            # Check label text or combo box items
                            if ($labelText.Contains($searchText) -or ($comboBox -and (ComboBoxContainsMatch -comboBox $comboBox -searchText $searchText))) {
                                $matchFound = $true
                                $controlToHighlight = $control
                            }
                        }
                        
                        if ($matchFound -and $controlToHighlight) {
                            $controlToHighlight.Background = $highlightBrush
                            if ($null -eq $firstMatch) { $firstMatch = $controlToHighlight }
                        }
                    }
                }
            }
        }
        
        # Scroll to first match if not visible
        if ($firstMatch -and $tweaksScrollViewer) {
            ScrollToItemIfNotVisible -scrollViewer $tweaksScrollViewer -item $firstMatch -container $tweaksGrid
        }
    })

    # Add Ctrl+F keyboard shortcut to focus search box on current tab
    $window.Add_KeyDown({
        param($sender, $e)
        
        # Check if Ctrl+F was pressed
        if ($e.Key -eq [System.Windows.Input.Key]::F -and 
            ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
            
            $currentTab = $tabControl.SelectedItem
            
            # Focus AppSearchBox if on App Removal tab
            if ($currentTab.Header -eq "App Removal" -and $appSearchBox) {
                $appSearchBox.Focus()
                $e.Handled = $true
            }
            # Focus TweakSearchBox if on Tweaks tab
            elseif ($currentTab.Header -eq "Tweaks" -and $tweakSearchBox) {
                $tweakSearchBox.Focus()
                $e.Handled = $true
            }
        }
    })

    # Wizard Navigation
    $tabControl = $window.FindName('MainTabControl')
    $previousBtn = $window.FindName('PreviousBtn')
    $nextBtn = $window.FindName('NextBtn')
    $userSelectionCombo = $window.FindName('UserSelectionCombo')
    $userSelectionDescription = $window.FindName('UserSelectionDescription')
    $otherUserPanel = $window.FindName('OtherUserPanel')
    $otherUsernameTextBox = $window.FindName('OtherUsernameTextBox')
    $usernameTextBoxPlaceholder = $window.FindName('UsernameTextBoxPlaceholder')
    $usernameValidationMessage = $window.FindName('UsernameValidationMessage')
    $appRemovalScopeCombo = $window.FindName('AppRemovalScopeCombo')
    $appRemovalScopeDescription = $window.FindName('AppRemovalScopeDescription')
    $appRemovalScopeSection = $window.FindName('AppRemovalScopeSection')
    $appRemovalScopeCurrentUser = $window.FindName('AppRemovalScopeCurrentUser')
    $appRemovalScopeTargetUser = $window.FindName('AppRemovalScopeTargetUser')

    # Navigation button handlers
    function UpdateNavigationButtons {
        $currentIndex = $tabControl.SelectedIndex
        $totalTabs = $tabControl.Items.Count
        
        $homeIndex = 0
        $overviewIndex = $totalTabs - 1

        # Navigation button visibility
        if ($currentIndex -eq $homeIndex) {
            $nextBtn.Visibility = 'Collapsed'
            $previousBtn.Visibility = 'Collapsed'
        } elseif ($currentIndex -eq $overviewIndex) {
            $nextBtn.Visibility = 'Collapsed'
            $previousBtn.Visibility = 'Visible'
        } else {
            $nextBtn.Visibility = 'Visible'
            $previousBtn.Visibility = 'Visible'
        }
        
        # Update progress indicators
        # Tab indices: 0=Home, 1=App Removal, 2=Tweaks, 3=Deployment Settings
        $progressIndicator1 = $window.FindName('ProgressIndicator1') # App Removal
        $progressIndicator2 = $window.FindName('ProgressIndicator2') # Tweaks
        $progressIndicator3 = $window.FindName('ProgressIndicator3') # Deployment Settings
        $bottomNavGrid = $window.FindName('BottomNavGrid')
        
        # Hide bottom navigation on home page
        if ($currentIndex -eq 0) {
            $bottomNavGrid.Visibility = 'Collapsed'
        } else {
            $bottomNavGrid.Visibility = 'Visible'
        }
        
        # Update indicator colors based on current tab
        # Indicator 1 (App Removal) - tab index 1
        if ($currentIndex -ge 1) {
            $progressIndicator1.Fill = $window.Resources['ProgressActiveColor']
        } else {
            $progressIndicator1.Fill = $window.Resources['ProgressInactiveColor']
        }
        
        # Indicator 2 (Tweaks) - tab index 2
        if ($currentIndex -ge 2) {
            $progressIndicator2.Fill = $window.Resources['ProgressActiveColor']
        } else {
            $progressIndicator2.Fill = $window.Resources['ProgressInactiveColor']
        }
        
        # Indicator 3 (Deployment Settings) - tab index 3
        if ($currentIndex -ge 3) {
            $progressIndicator3.Fill = $window.Resources['ProgressActiveColor']
        } else {
            $progressIndicator3.Fill = $window.Resources['ProgressInactiveColor']
        }
    }

    # Update user selection description and show/hide other user panel
    $userSelectionCombo.Add_SelectionChanged({
        switch ($userSelectionCombo.SelectedIndex) {
            0 { 
                $userSelectionDescription.Text = "Changes will be applied to the currently logged-in user profile."
                $otherUserPanel.Visibility = 'Collapsed'
                $usernameValidationMessage.Text = ""
                # Show "Current user only" option, hide "Target user only" option
                $appRemovalScopeCurrentUser.Visibility = 'Visible'
                $appRemovalScopeTargetUser.Visibility = 'Collapsed'
                # Enable app removal scope selection for current user
                $appRemovalScopeCombo.IsEnabled = $true
                $appRemovalScopeCombo.SelectedIndex = 0
            }
            1 { 
                $userSelectionDescription.Text = "Changes will be applied to a different user profile on this system."
                $otherUserPanel.Visibility = 'Visible'
                $usernameValidationMessage.Text = ""
                # Hide "Current user only" option, show "Target user only" option
                $appRemovalScopeCurrentUser.Visibility = 'Collapsed'
                $appRemovalScopeTargetUser.Visibility = 'Visible'
                # Enable app removal scope selection for other user
                $appRemovalScopeCombo.IsEnabled = $true
                $appRemovalScopeCombo.SelectedIndex = 0
            }
            2 { 
                $userSelectionDescription.Text = "Changes will be applied to the default user template, affecting all new users created after this point. Useful for Sysprep deployment."
                $otherUserPanel.Visibility = 'Collapsed'
                $usernameValidationMessage.Text = ""
                # Hide other user options since they don't apply to default user template
                $appRemovalScopeCurrentUser.Visibility = 'Collapsed'
                $appRemovalScopeTargetUser.Visibility = 'Collapsed'
                # Lock app removal scope to "All users" when applying to sysprep
                $appRemovalScopeCombo.IsEnabled = $false
                $appRemovalScopeCombo.SelectedIndex = 0
            }
        }
    })

    # Helper function to update app removal scope description
    function UpdateAppRemovalScopeDescription {
        $selectedItem = $appRemovalScopeCombo.SelectedItem
        if ($selectedItem) {
            switch ($selectedItem.Content) {
                "All users" { 
                    $appRemovalScopeDescription.Text = "Apps will be removed for all users and from the Windows image to prevent reinstallation for new users."
                }
                "Current user only" { 
                    $appRemovalScopeDescription.Text = "Apps will only be removed for the current user. Other users and new users will not be affected."
                }
                "Target user only" { 
                    $appRemovalScopeDescription.Text = "Apps will only be removed for the specified target user. Other users and new users will not be affected."
                }
            }
        }
    }

    # Update app removal scope description
    $appRemovalScopeCombo.Add_SelectionChanged({
        UpdateAppRemovalScopeDescription
    })

    $otherUsernameTextBox.Add_TextChanged({
        # Show/hide placeholder
        if ([string]::IsNullOrWhiteSpace($otherUsernameTextBox.Text)) {
            $usernameTextBoxPlaceholder.Visibility = 'Visible'
        } else {
            $usernameTextBoxPlaceholder.Visibility = 'Collapsed'
        }
        
        ValidateOtherUsername
    })

    function ValidateOtherUsername {
        # Only validate if "Other User" is selected
        if ($userSelectionCombo.SelectedIndex -ne 1) {
            return $true
        }

        $username = $otherUsernameTextBox.Text.Trim()

        $errorBrush   = $window.Resources['ValidationErrorColor']
        $successBrush = $window.Resources['ValidationSuccessColor']

        if ($username.Length -eq 0) {
            $usernameValidationMessage.Text = "Please enter a username"
            $usernameValidationMessage.Foreground = $errorBrush
            return $false
        }
        
        if ($username -eq $env:USERNAME) {
            $usernameValidationMessage.Text = "Cannot enter your own username, use 'Current User' option instead"
            $usernameValidationMessage.Foreground = $errorBrush
            return $false
        }
        
        $userExists = CheckIfUserExists -Username $username

        if ($userExists) {
            if (TestIfUserIsLoggedIn -Username $username) {
                $usernameValidationMessage.Text = "User '$username' is currently logged in. Please sign out that user first."
                $usernameValidationMessage.Foreground = $errorBrush
                return $false
            }

            $usernameValidationMessage.Text = "User found: $username"
            $usernameValidationMessage.Foreground = $successBrush
            return $true
        }

        $usernameValidationMessage.Text = "User not found, please enter a valid username"
        $usernameValidationMessage.Foreground = $errorBrush
        return $false
    }

    function GenerateOverview {
        $changesList = @()
        
        # Collect selected apps
        $selectedAppsCount = 0
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedAppsCount++
            }
        }
        if ($selectedAppsCount -gt 0) {
            $changesList += "Remove $selectedAppsCount application(s)"
        }
        
        # Update app removal scope section based on whether apps are selected
        if ($selectedAppsCount -gt 0) {
            # Enable app removal scope selection (unless locked by sysprep mode)
            if ($userSelectionCombo.SelectedIndex -ne 2) {
                $appRemovalScopeCombo.IsEnabled = $true
            }
            $appRemovalScopeSection.Opacity = 1.0
            UpdateAppRemovalScopeDescription
        }
        else {
            # Disable app removal scope selection when no apps selected
            $appRemovalScopeCombo.IsEnabled = $false
            $appRemovalScopeSection.Opacity = 0.5
            $appRemovalScopeDescription.Text = "No apps selected for removal."
        }
        
        # Collect all ComboBox/CheckBox selections from dynamically created controls
        if ($script:UiControlMappings) {
            foreach ($mappingKey in $script:UiControlMappings.Keys) {
                $control = $window.FindName($mappingKey)
                $isSelected = $false
                
                # Check if it's a checkbox or combobox
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    $isSelected = $control.IsChecked -eq $true
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $isSelected = $control.SelectedIndex -gt 0
                }
                
                if ($control -and $isSelected) {
                    $mapping = $script:UiControlMappings[$mappingKey]
                    if ($mapping.Type -eq 'group') {
                        # For combobox: SelectedIndex 0 = No Change, so subtract 1 to index into Values
                        $selectedValue = $mapping.Values[$control.SelectedIndex - 1]
                        foreach ($fid in $selectedValue.FeatureIds) {
                            $label = $script:FeatureLabelLookup[$fid]
                            if ($label) { $changesList += $label }
                        }
                    }
                    elseif ($mapping.Type -eq 'feature') {
                        $label = $script:FeatureLabelLookup[$mapping.FeatureId]
                        if (-not $label) { $label = $mapping.Action + ' ' + $mapping.Label }
                        $changesList += $label
                    }
                }
            }
        }
        
        return $changesList
    }

    function ShowChangesOverview {
        $changesList = GenerateOverview

        if ($changesList.Count -eq 0) {
            Show-MessageBox -Message 'No changes have been selected.' -Title 'Selected Changes' -Button 'OK' -Icon 'Information'
            return
        }

        $message = ($changesList | ForEach-Object { "$([char]0x2022) $_" }) -join "`n"
        Show-MessageBox -Message $message -Title 'Selected Changes' -Button 'OK' -Icon 'None' -Width 600
    }

    $previousBtn.Add_Click({
        Hide-Bubble -Immediate
        if ($tabControl.SelectedIndex -gt 0) {
            $tabControl.SelectedIndex--
            UpdateNavigationButtons
        }
    })

    $nextBtn.Add_Click({
        if ($tabControl.SelectedIndex -lt ($tabControl.Items.Count - 1)) {
            $tabControl.SelectedIndex++
            UpdateNavigationButtons
        }
    })

    # Handle Home Start button
    $homeStartBtn = $window.FindName('HomeStartBtn')
    $homeStartBtn.Add_Click({
        # Navigate to first tab after home (App Removal)
        $tabControl.SelectedIndex = 1
        UpdateNavigationButtons
    })

    # Handle Home Default Mode button - apply defaults and navigate directly to overview
    $homeDefaultModeBtn = $window.FindName('HomeDefaultModeBtn')
    $homeDefaultModeBtn.Add_Click({
        # Load and apply default settings
        $defaultsJson = LoadJsonFile -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"
        if ($defaultsJson) {
            ApplySettingsToUiControls -window $window -settingsJson $defaultsJson -uiControlMappings $script:UiControlMappings
        }

        # Deselect all apps, then select default apps (defer if apps are still loading in the background)
        if ($script:IsLoadingApps) {
            $script:PendingDefaultMode = $true
        } else {
            ApplyPresetToApps -MatchFilter { param($c) $c.SelectedByDefault -eq $true } -Exclusive
        }

        # Navigate directly to the Deployment Settings tab
        $tabControl.SelectedIndex = 3
        UpdateNavigationButtons

        # Show contextual hint bubble for the Review Changes link
        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Loaded, [action]{
            Show-Bubble -TargetControl $reviewChangesBtn -Message 'View the selected changes here'
        }) | Out-Null
    })

    # Handle Review Changes link button
    $reviewChangesBtn = $window.FindName('ReviewChangesBtn')
    $reviewChangesBtn.Add_Click({
        Hide-Bubble
        ShowChangesOverview
    })

    # Handle Apply Changes button - validates and immediately starts applying changes
    $deploymentApplyBtn = $window.FindName('DeploymentApplyBtn')
    $deploymentApplyBtn.Add_Click({
        if (-not (ValidateOtherUsername)) {
            $validationMessage = if (-not [string]::IsNullOrWhiteSpace($usernameValidationMessage.Text)) {
                $usernameValidationMessage.Text
            }
            else {
                "Please enter a valid username."
            }
            Show-MessageBox -Message $validationMessage -Title "Invalid Username" -Button 'OK' -Icon 'Warning' | Out-Null
            return
        }

        Hide-Bubble -Immediate

        # App Removal - collect selected apps from integrated UI
        $selectedApps = @()
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedApps += $child.Tag
            }
        }
        
        if ($selectedApps.Count -gt 0) {
            # Check if Microsoft Store is selected
            if ($selectedApps -contains "Microsoft.WindowsStore") {
                $result = Show-MessageBox -Message 'Are you sure you wish to uninstall the Microsoft Store? This app cannot easily be reinstalled.' -Title 'Are you sure?' -Button 'YesNo' -Icon 'Warning'

                if ($result -eq 'No') {
                    return
                }
            }
            
            AddParameter 'RemoveApps'
            AddParameter 'Apps' ($selectedApps -join ',')
            
            # Add app removal target parameter based on selection
            $selectedScopeItem = $appRemovalScopeCombo.SelectedItem
            if ($selectedScopeItem) {
                switch ($selectedScopeItem.Content) {
                    "All users" { 
                        AddParameter 'AppRemovalTarget' 'AllUsers'
                    }
                    "Current user only" { 
                        AddParameter 'AppRemovalTarget' 'CurrentUser'
                    }
                    "Target user only" { 
                        # Use the target username from Other User panel
                        AddParameter 'AppRemovalTarget' ($otherUsernameTextBox.Text.Trim())
                    }
                }
            }
        }

        # Apply dynamic tweaks selections
        if ($script:UiControlMappings) {
            foreach ($mappingKey in $script:UiControlMappings.Keys) {
                $control = $window.FindName($mappingKey)
                $isSelected = $false
                $selectedIndex = 0
                
                # Check if it's a checkbox or combobox
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    $isSelected = $control.IsChecked -eq $true
                    $selectedIndex = if ($isSelected) { 1 } else { 0 }
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $isSelected = $control.SelectedIndex -gt 0
                    $selectedIndex = $control.SelectedIndex
                }
                
                if ($control -and $isSelected) {
                    $mapping = $script:UiControlMappings[$mappingKey]
                    if ($mapping.Type -eq 'group') {
                        if ($selectedIndex -gt 0 -and $selectedIndex -le $mapping.Values.Count) {
                            $selectedValue = $mapping.Values[$selectedIndex - 1]
                            foreach ($fid in $selectedValue.FeatureIds) { 
                                AddParameter $fid
                            }
                        }
                    }
                    elseif ($mapping.Type -eq 'feature') {
                        AddParameter $mapping.FeatureId
                    }
                }
            }
        }

        $controlParamsCount = 0
        foreach ($Param in $script:ControlParams) {
            if ($script:Params.ContainsKey($Param)) {
                $controlParamsCount++
            }
        }

        # Check if any changes were selected
        $totalChanges = $script:Params.Count - $controlParamsCount

        # Apps parameter does not count as a change itself
        if ($script:Params.ContainsKey('Apps')) {
            $totalChanges = $totalChanges - 1
        }

        if ($totalChanges -eq 0) {
            Show-MessageBox -Message 'No changes have been selected, please select at least one option to proceed.' -Title 'No Changes Selected' -Button 'OK' -Icon 'Information'
            return
        }

        # Check RestorePointCheckBox
        $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
        if ($restorePointCheckBox -and $restorePointCheckBox.IsChecked) {
            AddParameter 'CreateRestorePoint'
        }
        
        # Store selected user mode
        switch ($userSelectionCombo.SelectedIndex) {
            0 { 
                Write-Host "Selected user mode: current user ($(GetUserName))"
            }
            1 { 
                Write-Host "Selected user mode: $($otherUsernameTextBox.Text.Trim())"
                AddParameter User ($otherUsernameTextBox.Text.Trim()) 
            }
            2 {
                Write-Host "Selected user mode: default user profile (Sysprep)"
                AddParameter Sysprep
            }
        }

        SaveSettings

        # Check if user wants to restart explorer
        $restartExplorerCheckBox = $window.FindName('RestartExplorerCheckBox')
        $shouldRestartExplorer = $restartExplorerCheckBox -and $restartExplorerCheckBox.IsChecked

        # Show the apply changes window
        Show-ApplyModal -Owner $window -RestartExplorer $shouldRestartExplorer

        # Close the main window after the apply dialog closes
        $window.Close()
    })

    # Initialize UI elements on window load
    $window.Add_Loaded({
        BuildDynamicTweaks

        LoadAppsIntoMainUI

        # Update Current User label with username
        if ($userSelectionCombo -and $userSelectionCombo.Items.Count -gt 0) {
            $currentUserItem = $userSelectionCombo.Items[0]
            if ($currentUserItem -is [System.Windows.Controls.ComboBoxItem]) {
                $currentUserItem.Content = "Current User ($(GetUserName))"
            }
        }

        # Disable Restart Explorer option if NoRestartExplorer parameter is set
        $restartExplorerCheckBox = $window.FindName('RestartExplorerCheckBox')
        if ($restartExplorerCheckBox -and $script:Params.ContainsKey("NoRestartExplorer")) {
            $restartExplorerCheckBox.IsChecked = $false
            $restartExplorerCheckBox.IsEnabled = $false
        }

        # Force Apply Changes To setting if Sysprep or User parameters are set
        if ($script:Params.ContainsKey("Sysprep")) {
            $userSelectionCombo.SelectedIndex = 2
            $userSelectionCombo.IsEnabled = $false
        }
        elseif ($script:Params.ContainsKey("User")) {
            $userSelectionCombo.SelectedIndex = 1
            $userSelectionCombo.IsEnabled = $false
            $otherUsernameTextBox.Text = $script:Params.Item("User")
            $otherUsernameTextBox.IsEnabled = $false
        }

        UpdateNavigationButtons
    })

    # Add event handler for tab changes
    $tabControl.Add_SelectionChanged({
        # Regenerate overview when switching to Overview tab
        if ($tabControl.SelectedIndex -eq ($tabControl.Items.Count - 2)) {
            GenerateOverview
        }
        UpdateNavigationButtons
    })

    # Handle Load Defaults button
    $loadDefaultsBtn = $window.FindName('LoadDefaultsBtn')
    $loadDefaultsBtn.Add_Click({
        $defaultsJson = LoadJsonFile -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"

        if (-not $defaultsJson) {
            Show-MessageBox -Message "Failed to load default settings file" -Title "Error" -Button 'OK' -Icon 'Error'
            return
        }
        
        ApplySettingsToUiControls -window $window -settingsJson $defaultsJson -uiControlMappings $script:UiControlMappings
    })

    # Handle Load Last Used settings and Load Last Used apps
    $loadLastUsedBtn = $window.FindName('LoadLastUsedBtn')

    $lastUsedSettingsJson = LoadJsonFile -filePath $script:SavedSettingsFilePath -expectedVersion "1.0" -optionalFile

    $hasSettings = $false
    $appsSetting = $null
    if ($lastUsedSettingsJson -and $lastUsedSettingsJson.Settings) {
        foreach ($s in $lastUsedSettingsJson.Settings) {
            # Only count as hasSettings if a setting other than RemoveApps/Apps is present and true
            if ($s.Value -eq $true -and $s.Name -ne 'RemoveApps' -and $s.Name -ne 'Apps') { $hasSettings = $true }
            if ($s.Name -eq 'Apps' -and $s.Value) { $appsSetting = $s.Value }
        }
    }

    # Show option to load last used settings if they exist
    if ($hasSettings) {
        $loadLastUsedBtn.Add_Click({
            try {
                ApplySettingsToUiControls -window $window -settingsJson $lastUsedSettingsJson -uiControlMappings $script:UiControlMappings
            }
            catch {
                Show-MessageBox -Message "Failed to load last used settings: $_" -Title "Error" -Button 'OK' -Icon 'Error'
            }
        })
    }
    else {
        $loadLastUsedBtn.Visibility = 'Collapsed'
    }

    # Preset: Last used selection (wired to PresetLastUsed checkbox)
    if ($appsSetting -and $appsSetting.ToString().Trim().Length -gt 0) {
        # Parse and store saved app IDs for UpdatePresetStates
        $script:SavedAppIds = @()
        if ($appsSetting -is [string]) { $script:SavedAppIds = $appsSetting.Split(',') }
        elseif ($appsSetting -is [array]) { $script:SavedAppIds = $appsSetting }
        $script:SavedAppIds = $script:SavedAppIds | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

        $presetLastUsed.Add_Click({
            if ($script:UpdatingPresets) { return }
            $check = ($this.IsChecked -eq $true)
            if ($this.IsChecked -eq $null) { $this.IsChecked = $false; $check = $false }
            ApplyPresetToApps -MatchFilter { param($c) $script:SavedAppIds -contains $c.Tag } -Check $check
        })
    }
    else {
        $script:SavedAppIds = $null
        $presetLastUsed.Visibility = 'Collapsed'
    }

    # Clear All Tweaks button
    $clearAllTweaksBtn = $window.FindName('ClearAllTweaksBtn')
    $clearAllTweaksBtn.Add_Click({
        # Reset all ComboBoxes to index 0 (No Change) and uncheck all CheckBoxes
        if ($script:UiControlMappings) {
            foreach ($comboName in $script:UiControlMappings.Keys) {
                $control = $window.FindName($comboName)
                if ($control -is [System.Windows.Controls.CheckBox]) {
                    $control.IsChecked = $false
                }
                elseif ($control -is [System.Windows.Controls.ComboBox]) {
                    $control.SelectedIndex = 0
                }
            }
        }
    })

    # Preload app data to speed up loading when user navigates to App Removal tab
    try {
        $script:PreloadedAppData = LoadAppsDetailsFromJson -OnlyInstalled:$false -InstalledList '' -InitialCheckedFromJson:$false
    }
    catch {
        Write-Warning "Failed to preload apps list: $_"
    }

    # Show the window
    return $window.ShowDialog()
}
