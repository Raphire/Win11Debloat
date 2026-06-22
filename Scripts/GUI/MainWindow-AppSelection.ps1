# MainWindow-AppSelection.ps1
# App-selection panel functions: tri-state helpers, sorting, search/highlight, app loading, preset management, and removal scope.

function Add-TriStateClickBehavior {
    param([System.Windows.Controls.CheckBox]$CheckBox)

    if (-not $CheckBox -or -not $CheckBox.IsThreeState) { return }

    if (-not $CheckBox.PSObject.Properties['WasIndeterminateBeforeClick']) {
        Add-Member -InputObject $CheckBox -MemberType NoteProperty -Name 'WasIndeterminateBeforeClick' -Value $false
    }

    $CheckBox.Add_PreviewMouseLeftButtonDown({
        $this.WasIndeterminateBeforeClick = ($this.IsChecked -eq [System.Nullable[bool]]$null)
    })
}

function ConvertTo-NormalizedCheckboxState {
    param([System.Windows.Controls.CheckBox]$CheckBox)

    if ($CheckBox.PSObject.Properties['WasIndeterminateBeforeClick'] -and $CheckBox.WasIndeterminateBeforeClick) {
        # WPF toggles null -> false before Click handlers fire; restore desired mixed -> checked behavior.
        $CheckBox.WasIndeterminateBeforeClick = $false
        $CheckBox.IsChecked = $true
        return $true
    }

    return ($CheckBox.IsChecked -eq $true)
}

function Set-TriStatePresetCheckBoxState {
    param(
        [System.Windows.Controls.CheckBox]$CheckBox,
        [int]$Total,
        [int]$Selected
    )

    if (-not $CheckBox) { return }

    if ($Total -eq 0) {
        $CheckBox.IsEnabled = $false
        $CheckBox.IsChecked = $false
        return
    }

    $CheckBox.IsEnabled = $true
    if ($Selected -eq 0) {
        $CheckBox.IsChecked = $false
    }
    elseif ($Selected -eq $Total) {
        $CheckBox.IsChecked = $true
    }
    else {
        $CheckBox.IsChecked = [System.Nullable[bool]]$null
    }
}

function Update-SortArrows {
    param(
        [System.Windows.Controls.TextBlock]$SortArrowName,
        [System.Windows.Controls.TextBlock]$SortArrowDescription,
        [System.Windows.Controls.TextBlock]$SortArrowAppId
    )

    $ease = New-Object System.Windows.Media.Animation.CubicEase
    $ease.EasingMode = 'EaseOut'
    $arrows = @{
        'Name'        = $SortArrowName
        'Description' = $SortArrowDescription
        'AppId'       = $SortArrowAppId
    }
    foreach ($col in $arrows.Keys) {
        $tb = $arrows[$col]
        # Active column: full opacity, rotate to indicate direction (0 = up/asc, 180 = down/desc)
        # Inactive columns: dim, reset to 0
        if ($col -eq $script:SortColumn) {
            $targetAngle = if ($script:SortAscending) { 0 } else { 180 }
            $tb.Opacity = 1.0
        }
        else {
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

function Update-AppsPanelRebuildSearchIndex {
    param(
        [System.Windows.Controls.Panel]$AppsPanel,
        $ActiveMatch = $null
    )

    $newMatches = @()
    $newActiveIndex = -1
    $i = 0
    foreach ($child in $AppsPanel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.Background -ne [System.Windows.Media.Brushes]::Transparent) {
            $newMatches += $child
            if ($null -ne $ActiveMatch -and [System.Object]::ReferenceEquals($child, $ActiveMatch)) {
                $newActiveIndex = $i
            }
            $i++
        }
    }
    $script:AppSearchMatches = $newMatches
    $script:AppSearchMatchIndex = if ($newActiveIndex -ge 0) { $newActiveIndex } elseif ($newMatches.Count -gt 0) { 0 } else { -1 }
}

function Update-AppsPanelSort {
    param(
        [System.Windows.Controls.Panel]$AppsPanel,
        [System.Windows.Controls.TextBlock]$SortArrowName,
        [System.Windows.Controls.TextBlock]$SortArrowDescription,
        [System.Windows.Controls.TextBlock]$SortArrowAppId
    )

    $children = @($AppsPanel.Children)
    $key = switch ($script:SortColumn) {
        'Name'        { { $_.AppName } }
        'Description' { { $_.AppDescription } }
        'AppId'       { { $_.AppIdDisplay } }
    }
    $sorted = $children | Sort-Object $key -Descending:(-not $script:SortAscending)
    $AppsPanel.Children.Clear()
    foreach ($checkbox in $sorted) {
        $AppsPanel.Children.Add($checkbox) | Out-Null
    }
    Update-SortArrows -SortArrowName $SortArrowName -SortArrowDescription $SortArrowDescription -SortArrowAppId $SortArrowAppId

    # Rebuild search match list in new sorted order so keyboard navigation stays correct
    if ($script:AppSearchMatches.Count -gt 0) {
        $activeMatch = if ($script:AppSearchMatchIndex -ge 0 -and $script:AppSearchMatchIndex -lt $script:AppSearchMatches.Count) {
            $script:AppSearchMatches[$script:AppSearchMatchIndex]
        }
        else { $null }
        Update-AppsPanelRebuildSearchIndex -AppsPanel $AppsPanel -ActiveMatch $activeMatch
    }
}

function Update-AppSelectionStatus {
    param(
        [System.Windows.Controls.Panel]$AppsPanel,
        [System.Windows.Controls.TextBlock]$AppSelectionStatus,
        [System.Windows.Controls.ComboBox]$AppRemovalScopeCombo,
        [System.Windows.Controls.Border]$AppRemovalScopeSection,
        [System.Windows.Controls.TextBlock]$AppRemovalScopeDescription,
        [System.Windows.Controls.ComboBox]$UserSelectionCombo
    )

    $selectedCount = 0
    foreach ($child in $AppsPanel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
            $selectedCount++
        }
    }
    $AppSelectionStatus.Text = "$selectedCount app(s) selected for removal"

    if ($AppRemovalScopeCombo -and $AppRemovalScopeSection -and $AppRemovalScopeDescription) {
        if ($selectedCount -gt 0) {
            $AppRemovalScopeSection.Visibility = 'Visible'
            if ($UserSelectionCombo.SelectedIndex -ne 2) {
                $AppRemovalScopeCombo.IsEnabled = $true
            }
            Update-AppRemovalScopeDescription -AppRemovalScopeCombo $AppRemovalScopeCombo -AppRemovalScopeDescription $AppRemovalScopeDescription
        }
        else {
            $AppRemovalScopeSection.Visibility = 'Collapsed'
        }
    }
}

function Update-AppRemovalScopeDescription {
    param(
        [System.Windows.Controls.ComboBox]$AppRemovalScopeCombo,
        [System.Windows.Controls.TextBlock]$AppRemovalScopeDescription
    )

    $selectedItem = $AppRemovalScopeCombo.SelectedItem
    if ($selectedItem) {
        switch ($selectedItem.Content) {
            "All users" {
                $AppRemovalScopeDescription.Text = "Apps will be removed for all users and from the Windows image to prevent reinstallation for new users."
            }
            "Current user only" {
                $AppRemovalScopeDescription.Text = "Apps will only be removed for the current user."
            }
            "Target user only" {
                $AppRemovalScopeDescription.Text = "Apps will only be removed for the specified target user."
            }
        }
    }
}

function Invoke-AppPreset {
    param(
        [System.Windows.Controls.Panel]$AppsPanel,
        [scriptblock]$MatchFilter,
        [bool]$Check,
        [switch]$Exclusive
    )

    foreach ($child in $AppsPanel.Children) {
        if ($child -is [System.Windows.Controls.CheckBox]) {
            if ($Exclusive) {
                $child.IsChecked = (& $MatchFilter $child)
            }
            elseif (& $MatchFilter $child) {
                $child.IsChecked = $Check
            }
        }
    }
    Update-AppPresetStates -AppsPanel $AppsPanel
}

function Update-AppPresetStates {
    param([System.Windows.Controls.Panel]$AppsPanel)

    $script:UpdatingPresets = $true
    try {
        # Helper: count matching and checked apps, set checkbox state
        function SetPresetState($CheckBox, [scriptblock]$MatchFilter) {
            $total = 0; $checked = 0
            foreach ($child in $AppsPanel.Children) {
                if ($child -is [System.Windows.Controls.CheckBox]) {
                    if (& $MatchFilter $child) {
                        $total++
                        if ($child.IsChecked) { $checked++ }
                    }
                }
            }
            Set-TriStatePresetCheckBoxState -CheckBox $CheckBox -Total $total -Selected $checked
        }

        # Find preset checkboxes via window
        $window = $script:MainWindow
        $presetDefaultApps = $window.FindName('PresetDefaultApps')
        $presetLastUsed = $window.FindName('PresetLastUsed')

        SetPresetState $presetDefaultApps { param($c) $c.SelectedByDefault -eq $true }
        foreach ($jsonCb in $script:JsonPresetCheckboxes) {
            $localIds = $jsonCb.PresetAppIds
            SetPresetState $jsonCb { param($c) (@($c.AppIds) | Where-Object { $localIds -contains $_ }).Count -gt 0 }.GetNewClosure()
        }

        # Last used preset: only update if it's visible (has saved apps)
        if ($presetLastUsed.Visibility -ne 'Collapsed' -and $script:SavedAppIds) {
            SetPresetState $presetLastUsed { param($c) (@($c.AppIds) | Where-Object { $script:SavedAppIds -contains $_ }).Count -gt 0 }
        }
    }
    finally {
        $script:UpdatingPresets = $false
    }
}

function Scroll-ToItemIfNotVisible {
    param (
        [System.Windows.Controls.ScrollViewer]$ScrollViewer,
        [System.Windows.UIElement]$Item,
        [System.Windows.UIElement]$Container
    )

    if (-not $ScrollViewer -or -not $Item -or -not $Container) { return }

    try {
        $itemPosition = $Item.TransformToAncestor($Container).Transform([System.Windows.Point]::new(0, 0)).Y
        $viewportHeight = $ScrollViewer.ViewportHeight
        $itemHeight = $Item.ActualHeight
        $currentOffset = $ScrollViewer.VerticalOffset

        # Check if the item is currently visible in the viewport
        $itemTop = $itemPosition - $currentOffset
        $itemBottom = $itemTop + $itemHeight

        $isVisible = ($itemTop -ge 0) -and ($itemBottom -le $viewportHeight)

        # Only scroll if the item is not visible
        if (-not $isVisible) {
            # Center the item in the viewport
            $targetOffset = $itemPosition - ($viewportHeight / 2) + ($itemHeight / 2)
            $ScrollViewer.ScrollToVerticalOffset([Math]::Max(0, $targetOffset))
        }
    }
    catch {
        # Fallback to simple bring into view
        $Item.BringIntoView()
    }
}

function Find-ParentScrollViewer {
    param ([System.Windows.UIElement]$Element)

    $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($Element)
    while ($null -ne $parent) {
        if ($parent -is [System.Windows.Controls.ScrollViewer]) {
            return $parent
        }
        $parent = [System.Windows.Media.VisualTreeHelper]::GetParent($parent)
    }
    return $null
}

function Load-AppsWithList {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.Panel]$AppsPanel,
        [System.Windows.Controls.CheckBox]$OnlyInstalledAppsBox,
        [System.Windows.Controls.Border]$LoadingAppsIndicator,
        [System.Windows.Controls.MenuItem]$ImportConfigBtn,
        [object[]]$ListOfApps
    )

    $script:MainWindowLastSelectedCheckbox = $null

    $loaderScriptPath = $script:LoadAppsDetailsScriptPath
    $helperScriptPath = $script:TestAppInWingetListScriptPath
    $appsFilePath = $script:AppsListFilePath
    $onlyInstalled = [bool]$OnlyInstalledAppsBox.IsChecked

    # Use preloaded data if available; otherwise load in background job
    if (-not $onlyInstalled -and $script:PreloadedAppData) {
        $rawAppData = $script:PreloadedAppData
        $script:PreloadedAppData = $null
    }
    else {
        # Load apps details in a background job to keep the UI responsive.
        # The helper is dot-sourced inside the job because the runspace
        # does not inherit the parent scope's dot-sourced functions.
        $rawAppData = Invoke-NonBlocking -ScriptBlock {
            param($loaderScript, $helperScript, $appsListFilePath, $installedList, $onlyInstalled)
            $script:AppsListFilePath = $appsListFilePath
            . $helperScript
            . $loaderScript
            LoadAppsDetailsFromJson -OnlyInstalled:$onlyInstalled -InstalledList $installedList -InitialCheckedFromJson:$false
        } -ArgumentList $loaderScriptPath, $helperScriptPath, $appsFilePath, $ListOfApps, $onlyInstalled
    }

    $appsToAdd = @($rawAppData | Where-Object { $_ -and ($_.AppId -or $_.FriendlyName) } | Sort-Object -Property FriendlyName)

    $LoadingAppsIndicator.Visibility = 'Collapsed'

    if ($appsToAdd.Count -eq 0) {
        $OnlyInstalledAppsBox.IsHitTestVisible = $true
        $Window.FindName('DeploymentApplyBtn').IsEnabled = $true
        if ($ImportConfigBtn) {
            $ImportConfigBtn.IsEnabled = $true
        }
        return
    }

    $brushSafe    = $Window.Resources['AppRecommendationSafeColor']
    $brushDefault = $Window.Resources['AppRecommendationOptionalColor']
    $brushUnsafe  = $Window.Resources['AppRecommendationUnsafeColor']

    # Create WPF controls; pump the Dispatcher every batch so the spinner keeps animating.
    $batchSize = 20
    for ($i = 0; $i -lt $appsToAdd.Count; $i++) {
        $app = $appsToAdd[$i]

        $checkbox = New-Object System.Windows.Controls.CheckBox
        $automationName = if ($app.FriendlyName) { $app.FriendlyName } elseif ($app.AppIdDisplay) { $app.AppIdDisplay } else { $null }
        if ($automationName) { $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $automationName) }
        $checkbox.Tag = $app.AppIdDisplay
        $checkbox.IsChecked = $app.IsChecked
        $checkbox.Style = $Window.Resources['AppsPanelCheckBoxStyle']

        # Build table row: Recommendation dot | Name | Description | App ID
        $row = New-Object System.Windows.Controls.Grid
        $row.Style = $Window.Resources['AppTableRowStyle']
        $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = $Window.Resources['AppTableDotColWidth']
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = $Window.Resources['AppTableNameColWidth']
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = $Window.Resources['AppTableDescColWidth']
        $c3 = New-Object System.Windows.Controls.ColumnDefinition; $c3.Width = $Window.Resources['AppTableIdColWidth']
        $row.ColumnDefinitions.Add($c0); $row.ColumnDefinitions.Add($c1)
        $row.ColumnDefinitions.Add($c2); $row.ColumnDefinitions.Add($c3)

        $dot = New-Object System.Windows.Shapes.Ellipse
        $dot.Style = $Window.Resources['AppRecommendationDotStyle']
        $dot.Fill = switch ($app.Recommendation) { 'safe' { $brushSafe } 'unsafe' { $brushUnsafe } default { $brushDefault } }
        $dot.ToolTip = switch ($app.Recommendation) {
            'safe'   { '[Recommended] Safe to remove for most users' }
            'unsafe' { '[Not Recommended] Only remove if you know what you are doing' }
            default  { "[Optional] Can be safely removed if you don't need this app" }
        }
        [System.Windows.Controls.Grid]::SetColumn($dot, 0)

        $tbName = New-Object System.Windows.Controls.TextBlock
        $tbName.Text = $app.FriendlyName
        $tbName.Style = $Window.Resources['AppNameTextStyle']
        [System.Windows.Controls.Grid]::SetColumn($tbName, 1)

        $tbDesc = New-Object System.Windows.Controls.TextBlock
        $tbDesc.Text = $app.Description
        $tbDesc.Style = $Window.Resources['AppDescTextStyle']
        $tbDesc.ToolTip = $app.Description
        [System.Windows.Controls.Grid]::SetColumn($tbDesc, 2)

        $tbId = New-Object System.Windows.Controls.TextBlock
        $tbId.Text = $app.AppIdDisplay
        $tbId.Style = $Window.Resources["AppIdTextStyle"]
        $tbId.ToolTip = $app.AppIdDisplay
        [System.Windows.Controls.Grid]::SetColumn($tbId, 3)

        $row.Children.Add($dot) | Out-Null
        $row.Children.Add($tbName) | Out-Null
        $row.Children.Add($tbDesc) | Out-Null
        $row.Children.Add($tbId) | Out-Null
        $checkbox.Content = $row

        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'AppName' -Value $app.FriendlyName
        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'AppDescription' -Value $app.Description
        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'SelectedByDefault' -Value $app.SelectedByDefault
        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'AppIds' -Value @($app.AppId)
        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'AppIdDisplay' -Value $app.AppIdDisplay

        $checkbox.Add_Checked({
            $w = $script:MainWindow
            Update-AppSelectionStatus -AppsPanel $w.FindName('AppSelectionPanel') `
                -AppSelectionStatus $w.FindName('AppSelectionStatus') `
                -AppRemovalScopeCombo $w.FindName('AppRemovalScopeCombo') `
                -AppRemovalScopeSection $w.FindName('AppRemovalScopeSection') `
                -AppRemovalScopeDescription $w.FindName('AppRemovalScopeDescription') `
                -UserSelectionCombo $w.FindName('UserSelectionCombo')
        })
        $checkbox.Add_Unchecked({
            $w = $script:MainWindow
            Update-AppSelectionStatus -AppsPanel $w.FindName('AppSelectionPanel') `
                -AppSelectionStatus $w.FindName('AppSelectionStatus') `
                -AppRemovalScopeCombo $w.FindName('AppRemovalScopeCombo') `
                -AppRemovalScopeSection $w.FindName('AppRemovalScopeSection') `
                -AppRemovalScopeDescription $w.FindName('AppRemovalScopeDescription') `
                -UserSelectionCombo $w.FindName('UserSelectionCombo')
        })
        AttachShiftClickBehavior -checkbox $checkbox -appsPanel $AppsPanel `
            -lastSelectedCheckboxRef ([ref]$script:MainWindowLastSelectedCheckbox) `
            -updateStatusCallback {
                $w = $script:MainWindow
                Update-AppSelectionStatus -AppsPanel $w.FindName('AppSelectionPanel') `
                    -AppSelectionStatus $w.FindName('AppSelectionStatus') `
                    -AppRemovalScopeCombo $w.FindName('AppRemovalScopeCombo') `
                    -AppRemovalScopeSection $w.FindName('AppRemovalScopeSection') `
                    -AppRemovalScopeDescription $w.FindName('AppRemovalScopeDescription') `
                    -UserSelectionCombo $w.FindName('UserSelectionCombo')
            }

        $AppsPanel.Children.Add($checkbox) | Out-Null

        if (($i + 1) % $batchSize -eq 0) { DoEvents }
    }

    $sortArrowName = $Window.FindName('SortArrowName')
    $sortArrowDescription = $Window.FindName('SortArrowDescription')
    $sortArrowAppId = $Window.FindName('SortArrowAppId')
    Update-AppsPanelSort -AppsPanel $AppsPanel -SortArrowName $sortArrowName -SortArrowDescription $sortArrowDescription -SortArrowAppId $sortArrowAppId

    # If Default Mode was clicked while apps were still loading, apply defaults now
    if ($script:PendingDefaultMode) {
        $script:PendingDefaultMode = $false
        Invoke-AppPreset -AppsPanel $AppsPanel -MatchFilter { param($c) $c.SelectedByDefault -eq $true } -Exclusive
    }

    $appSelectionStatusText = $Window.FindName('AppSelectionStatus')
    $appRemovalScopeCombo = $Window.FindName('AppRemovalScopeCombo')
    $appRemovalScopeSection = $Window.FindName('AppRemovalScopeSection')
    $appRemovalScopeDescription = $Window.FindName('AppRemovalScopeDescription')
    $userSelectionCombo = $Window.FindName('UserSelectionCombo')
    Update-AppSelectionStatus -AppsPanel $AppsPanel -AppSelectionStatus $appSelectionStatusText `
        -AppRemovalScopeCombo $appRemovalScopeCombo -AppRemovalScopeSection $appRemovalScopeSection `
        -AppRemovalScopeDescription $appRemovalScopeDescription -UserSelectionCombo $userSelectionCombo

    # Re-enable controls now that the full, correctly-checked app list is ready
    $OnlyInstalledAppsBox.IsHitTestVisible = $true
    $Window.FindName('DeploymentApplyBtn').IsEnabled = $true
    if ($ImportConfigBtn) {
        $ImportConfigBtn.IsEnabled = $true
    }
}

function Load-AppsIntoMainUI {
    param(
        [System.Windows.Window]$Window,
        [System.Windows.Controls.Panel]$AppsPanel,
        [System.Windows.Controls.CheckBox]$OnlyInstalledAppsBox,
        [System.Windows.Controls.Border]$LoadingAppsIndicator,
        [System.Windows.Controls.MenuItem]$ImportConfigBtn
    )

    # Prevent concurrent loads
    if ($script:IsLoadingApps) { return }
    $script:IsLoadingApps = $true

    if ($ImportConfigBtn) {
        $ImportConfigBtn.IsEnabled = $false
    }

    # Show loading indicator and clear existing apps
    $LoadingAppsIndicator.Visibility = 'Visible'
    $AppsPanel.Children.Clear()

    # Disable controls while apps are loading so they can't be interacted with mid-load
    $Window.FindName('DeploymentApplyBtn').IsEnabled = $false
    $OnlyInstalledAppsBox.IsHitTestVisible = $false

    # Update navigation buttons to disable Next/Previous
    Update-NavigationButtons -Window $Window -TabControl $Window.FindName('MainTabControl')

    # Force a render so the loading indicator is visible, then schedule the
    # actual loading at Background priority so this call returns immediately.
    # This is critical when called from Add_Loaded: the window must finish
    # its initialization before we start a nested message pump via DoEvents.
    $Window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Render, [action] {})
    $Window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [action] {
            try {
                $listOfApps = $null

                if ($OnlyInstalledAppsBox.IsChecked -and ($script:WingetInstalled -eq $true)) {
                    Write-Host "Retrieving installed apps via winget..."
                    $listOfApps = GetInstalledAppsViaWinget -TimeOut 20 -NonBlocking

                    if ($null -eq $listOfApps) {
                        Write-Warning "WinGet returned no data (command timed out or failed)"
                        Show-MessageBox -Message 'Unable to load list of installed apps via WinGet.' -Title 'Error' -Button 'OK' -Icon 'Error' | Out-Null
                        $OnlyInstalledAppsBox.IsChecked = $false
                    }
                }

                Load-AppsWithList -Window $Window -AppsPanel $AppsPanel -OnlyInstalledAppsBox $OnlyInstalledAppsBox `
                    -LoadingAppsIndicator $LoadingAppsIndicator -ImportConfigBtn $ImportConfigBtn -ListOfApps $listOfApps
            }
            catch {
                Write-Warning "Failed to load apps list: $($_.Exception.Message)"
                $LoadingAppsIndicator.Visibility = 'Collapsed'
                $OnlyInstalledAppsBox.IsHitTestVisible = $true
                $Window.FindName('DeploymentApplyBtn').IsEnabled = $true
                if ($ImportConfigBtn) { $ImportConfigBtn.IsEnabled = $true }
            }
            finally {
                $script:IsLoadingApps = $false
            }
        }) | Out-Null
}
