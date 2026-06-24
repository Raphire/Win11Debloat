function Show-MainWindow {
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms | Out-Null

    $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
    $usesDarkMode = GetSystemUsesDarkMode

    # ---- Load XAML ----
    $xaml = Get-Content -Path $script:MainWindowSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode

    $mainBorder = $window.FindName('MainBorder')
    $titleBarBackground = $window.FindName('TitleBarBackground')
    $kofiBtn = $window.FindName('KofiBtn')
    $menuBtn = $window.FindName('MenuBtn')
    $closeBtn = $window.FindName('CloseBtn')
    $menuDocumentation = $window.FindName('MenuDocumentation')
    $menuReportBug = $window.FindName('MenuReportBug')
    $menuLogs = $window.FindName('MenuLogs')
    $menuAbout = $window.FindName('MenuAbout')
    $importConfigBtn = $window.FindName('ImportConfigBtn')
    $exportConfigBtn = $window.FindName('ExportConfigBtn')
    $restoreBackupBtn = $window.FindName('RestoreBackupBtn')
    $homeContentPanel = $window.FindName('HomeContentPanel')
    $contentGrid = $window.FindName('ContentGrid')
    $maxContentWidth = 1600.0

    $windowStateNormal = [System.Windows.WindowState]::Normal
    $windowStateMaximized = [System.Windows.WindowState]::Maximized
    $normalWindowShadow = $mainBorder.Effect
    $initialNormalMaxWidth = 1400.0

    $script:MainWindow = $window
    $script:GuiWindow = $window

    # ---- Handle unhandled exceptions on the dispatcher thread ----
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Add_UnhandledException({
        param($sender, $e)
        Write-Warning "Unhandled exception in GUI: $($e.Exception.Message)"
        Write-Warning "Stack trace: $($e.Exception.StackTrace)"
        $e.Handled = $true
    })

    # ---- Window chrome helpers ----
    $updateWindowChrome = { Update-MainWindowChrome -Window $window -MainBorder $mainBorder -TitleBarBackground $titleBarBackground -NormalWindowShadow $normalWindowShadow }
    $applyInitialWindowSize = { Set-MainWindowInitialSize -Window $window -InitialNormalMaxWidth $initialNormalMaxWidth }
    $updateContentMargin = { Update-MainWindowContentMargin -Window $window -ContentGrid $contentGrid -MaxContentWidth $maxContentWidth }
    $updateHomeContentPosition = { Update-MainWindowHomeContentPosition -Window $window -HomeContentPanel $homeContentPanel }

    # ---- Window chrome event wiring ----
    $window.Add_SourceInitialized({
        & $applyInitialWindowSize
        & $updateWindowChrome
    })

    $window.Add_SizeChanged({
        & $updateContentMargin
        & $updateHomeContentPosition
        Update-TweaksResponsiveColumns -Window $window
    })

    $window.Add_StateChanged({ & $updateWindowChrome })

    $window.Add_LocationChanged({
        if ($script:BubblePopup -and $script:BubblePopup.IsOpen) {
            $script:BubblePopup.HorizontalOffset += 1
            $script:BubblePopup.HorizontalOffset -= 1
        }
    })

    # ---- Menu/button event wiring ----
    $kofiBtn.Add_Click({ Start-Process "https://ko-fi.com/raphire" })

    $menuBtn.Add_Click({
        $menuBtn.ContextMenu.PlacementTarget = $menuBtn
        $menuBtn.ContextMenu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Bottom
        $menuBtn.ContextMenu.IsOpen = $true
    })

    $menuDocumentation.Add_Click({ Start-Process "https://github.com/Raphire/Win11Debloat/wiki" })
    $menuReportBug.Add_Click({ Start-Process "https://github.com/Raphire/Win11Debloat/issues" })

    $menuLogs.Add_Click({
        $logsFolder = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'Logs'
        if (Test-Path $logsFolder) {
            Start-Process "explorer.exe" -ArgumentList $logsFolder
        }
        else {
            Show-MessageBox -Message "No logs folder found at: $logsFolder" -Title "Logs" -Button 'OK' -Icon 'Information'
        }
    })

    $menuAbout.Add_Click({ Show-AboutDialog -Owner $window })

    $closeBtn.Add_Click({ $window.Close() })
    $window.Add_Closing({ $script:CancelRequested = $true })

    # ---- App Selection panel elements ----
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
    $tweaksPresetsBtn = $window.FindName('TweaksPresetsBtn')
    $tweaksPresetsPopup = $window.FindName('TweaksPresetsPopup')
    $presetDefaultTweaksBtn = $window.FindName('PresetDefaultTweaksBtn')
    $presetLastUsedTweaksBtn = $window.FindName('PresetLastUsedTweaksBtn')
    $presetPrivacyTweaksBtn = $window.FindName('PresetPrivacyTweaksBtn')
    $presetAITweaksBtn = $window.FindName('PresetAITweaksBtn')
    $tweaksPresetsArrow = $window.FindName('TweaksPresetsArrow')

    # ---- Navigation elements ----
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

    # ---- Tweak search elements ----
    $tweakSearchBox = $window.FindName('TweakSearchBox')
    $tweakSearchPlaceholder = $window.FindName('TweakSearchPlaceholder')
    $tweakSearchBorder = $window.FindName('TweakSearchBorder')
    $tweaksScrollViewer = $window.FindName('TweaksScrollViewer')
    $tweaksGrid = $window.FindName('TweaksGrid')
    $ShowCurrentlyAppliedTweaksCheckBox = $window.FindName('ShowCurrentlyAppliedTweaksCheckBox')
    $clearAllTweaksBtn = $window.FindName('ClearAllTweaksBtn')

    # ---- Deployment elements ----
    $reviewChangesBtn = $window.FindName('ReviewChangesBtn')
    $deploymentApplyBtn = $window.FindName('DeploymentApplyBtn')
    $homeStartBtn = $window.FindName('HomeStartBtn')
    $homeDefaultModeBtn = $window.FindName('HomeDefaultModeBtn')

    # ---- Wire export/import ----
    $exportConfigBtn.Add_Click({
        try {
            Export-Configuration -Owner $window -UsesDarkMode $usesDarkMode -AppsPanel $appsPanel -UiControlMappings $script:UiControlMappings -UserSelectionCombo $userSelectionCombo -OtherUsernameTextBox $otherUsernameTextBox
        }
        catch {
            Write-Warning "Export configuration failed: $($_.Exception.Message)"
            Show-MessageBox -Owner $window -Message "Unable to open export configuration dialog: $($_.Exception.Message)" -Title 'Export Configuration Failed' -Button 'OK' -Icon 'Error' | Out-Null
        }
    })

    $importConfigBtn.Add_Click({
        try {
            Import-Configuration -Owner $window -UsesDarkMode $usesDarkMode -AppsPanel $appsPanel -UiControlMappings $script:UiControlMappings -UserSelectionCombo $userSelectionCombo -OtherUsernameTextBox $otherUsernameTextBox -OnAppsImported { Update-AppSelectionStatus -AppsPanel $appsPanel -AppSelectionStatus $appSelectionStatus -AppRemovalScopeCombo $appRemovalScopeCombo -AppRemovalScopeSection $appRemovalScopeSection -AppRemovalScopeDescription $appRemovalScopeDescription -UserSelectionCombo $userSelectionCombo; Update-AppPresetStates -AppsPanel $appsPanel } -OnImportCompleted {
                $tabControl.SelectedIndex = 3
                Update-NavigationButtons -Window $window -TabControl $tabControl
                $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Loaded, [action]{
                    Show-Bubble -TargetControl $reviewChangesBtn -Message 'View the selected changes here'
                }) | Out-Null
            }
        }
        catch {
            Write-Warning "Import configuration failed: $($_.Exception.Message)"
            Show-MessageBox -Owner $window -Message "Unable to open import configuration dialog: $($_.Exception.Message)" -Title 'Import Configuration Failed' -Button 'OK' -Icon 'Error' | Out-Null
        }
    })

    # ---- Restore backup ----
    if ($restoreBackupBtn) {
        $restoreBackupBtn.Add_Click({
            try {
                $restoreResult = Show-RestoreBackupWindow -Owner $window
                if ($restoreResult -and $restoreResult.RestoredRegistry -eq $true) {
                    Update-CurrentTweakSystemState -Window $window -ApplyToUi:$false

                    if ($ShowCurrentlyAppliedTweaksCheckBox -and $ShowCurrentlyAppliedTweaksCheckBox.IsChecked -eq $true) {
                        Reset-TweaksToSystemState -Window $window -LoadSystemState $true
                        Update-TweakPresetStates -Window $window
                    }
                }
            }
            catch {
                Write-Warning "Restore backup action failed: $($_.Exception.Message)"
                Show-MessageBox -Owner $window -Message "Unable to open restore backup dialog: $($_.Exception.Message)" -Title 'Restore Backup Failed' -Button 'OK' -Icon 'Error' | Out-Null
            }
        })
    }

    # ---- Script-level state initialization ----
    $script:MainWindowLastSelectedCheckbox = $null
    $script:IsLoadingApps = $false
    $script:PendingDefaultMode = $false
    $script:PreloadedAppData = $null
    $script:UpdatingPresets = $false
    $script:UpdatingTweakPresets = $false
    $script:SortColumn = 'Name'
    $script:SortAscending = $true
    $script:AppSearchMatches = @()
    $script:AppSearchMatchIndex = -1
    $script:JsonPresetCheckboxes = @()

    if ($importConfigBtn) { $importConfigBtn.IsEnabled = $false }

    # ---- Build JSON-defined app presets ----
    foreach ($preset in (LoadAppPresetsFromJson)) {
        $checkbox = New-Object System.Windows.Controls.CheckBox
        $checkbox.Content = $preset.Name
        $checkbox.IsThreeState = $true
        $checkbox.Style = $window.Resources['PresetCheckBoxStyle']
        $checkbox.ToolTip = "Select $($preset.Name)"
        $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $preset.Name)
        Add-TriStateClickBehavior -CheckBox $checkbox
        Add-Member -InputObject $checkbox -MemberType NoteProperty -Name 'PresetAppIds' -Value $preset.AppIds
        $jsonPresetsPanel.Children.Add($checkbox) | Out-Null
        $script:JsonPresetCheckboxes += $checkbox

        $checkbox.Add_Click({
            if ($script:UpdatingPresets) { return }
            $presetIds = $this.PresetAppIds
            $check = ConvertTo-NormalizedCheckboxState -CheckBox $this
            Invoke-AppPreset -AppsPanel $appsPanel -MatchFilter { param($c) (@($c.AppIds) | Where-Object { $presetIds -contains $_ }).Count -gt 0 }.GetNewClosure() -Check $check
        })
    }

    # ---- App sort helpers ----
    $updateSortArrows = {
        Update-SortArrows `
            -SortArrowName $sortArrowName -SortArrowDescription $sortArrowDescription -SortArrowAppId $sortArrowAppId
    }

    $rebuildAppSearchIndex = {
        param($activeMatch = $null)
        Update-AppsPanelRebuildSearchIndex -AppsPanel $appsPanel -ActiveMatch $activeMatch
    }

    $sortApps = {
        Update-AppsPanelSort -AppsPanel $appsPanel `
            -SortArrowName $sortArrowName -SortArrowDescription $sortArrowDescription -SortArrowAppId $sortArrowAppId
        if ($script:AppSearchMatches.Count -gt 0) {
            $activeMatch = if ($script:AppSearchMatchIndex -ge 0 -and $script:AppSearchMatchIndex -lt $script:AppSearchMatches.Count) {
                $script:AppSearchMatches[$script:AppSearchMatchIndex]
            } else { $null }
            & $rebuildAppSearchIndex -activeMatch $activeMatch
        }
    }

    $setSortColumn = {
        param($column)
        if ($script:SortColumn -eq $column) {
            $script:SortAscending = -not $script:SortAscending
        }
        else {
            $script:SortColumn = $column
            $script:SortAscending = $true
        }
        & $sortApps
    }

    # ---- Tri-state preset wiring for app presets ----
    foreach ($presetCheckBox in @($presetDefaultApps, $presetLastUsed)) {
        Add-TriStateClickBehavior -CheckBox $presetCheckBox
    }

    # ---- Preset: Default selection ----
    $presetDefaultApps.Add_Click({
        if ($script:UpdatingPresets) { return }
        $check = ConvertTo-NormalizedCheckboxState -CheckBox $this
        Invoke-AppPreset -AppsPanel $appsPanel -MatchFilter { param($c) $c.SelectedByDefault -eq $true } -Check $check
    })

    # ---- Clear selection button ----
    $clearAppSelectionBtn.Add_Click({
        Invoke-AppPreset -AppsPanel $appsPanel -MatchFilter { param($c) $true } -Check $false
    })

    # ---- Column header sort handlers ----
    $headerNameBtn.Add_MouseLeftButtonUp({ & $setSortColumn 'Name' })
    $headerDescriptionBtn.Add_MouseLeftButtonUp({ & $setSortColumn 'Description' })
    $headerAppIdBtn.Add_MouseLeftButtonUp({ & $setSortColumn 'AppId' })

    # ---- Load apps ----
    $appLoadStatusCallback = { Update-AppSelectionStatus -AppsPanel $appsPanel -AppSelectionStatus $appSelectionStatus -AppRemovalScopeCombo $appRemovalScopeCombo -AppRemovalScopeSection $appRemovalScopeSection -AppRemovalScopeDescription $appRemovalScopeDescription -UserSelectionCombo $userSelectionCombo }
    $onlyInstalledAppsBox.Add_Checked({ Load-AppsIntoMainUI -Window $window -AppsPanel $appsPanel -OnlyInstalledAppsBox $onlyInstalledAppsBox -LoadingAppsIndicator $loadingAppsIndicator -ImportConfigBtn $importConfigBtn })
    $onlyInstalledAppsBox.Add_Unchecked({ Load-AppsIntoMainUI -Window $window -AppsPanel $appsPanel -OnlyInstalledAppsBox $onlyInstalledAppsBox -LoadingAppsIndicator $loadingAppsIndicator -ImportConfigBtn $importConfigBtn })

    # ---- App presets popup ----
    $presetsPopup.Add_Opened({
        Update-AppPresetStates -AppsPanel $appsPanel
        Start-DropdownArrowAnimation -Arrow $presetsArrow -Angle 180
    })
    $presetsPopup.Add_Closed({
        Start-DropdownArrowAnimation -Arrow $presetsArrow -Angle 0
        $presetsBtn.IsChecked = $false
    })

    $tweaksPresetsPopup.Add_Opened({
        Update-TweakPresetStates -Window $window
        Start-DropdownArrowAnimation -Arrow $tweaksPresetsArrow -Angle 180
    })
    $tweaksPresetsPopup.Add_Closed({
        Start-DropdownArrowAnimation -Arrow $tweaksPresetsArrow -Angle 0
        $tweaksPresetsBtn.IsChecked = $false
    })

    # ---- Popup dismiss on outside click ----
    $window.Add_PreviewMouseDown({
        $isAppPopupOpen = $presetsPopup.IsOpen
        $isTweaksPopupOpen = $tweaksPresetsPopup.IsOpen
        if (-not $isAppPopupOpen -and -not $isTweaksPopupOpen) { return }

        if ($isAppPopupOpen -and $null -ne $presetsPopup.Child -and $presetsPopup.Child.IsMouseOver) { return }
        if ($isTweaksPopupOpen -and $null -ne $tweaksPresetsPopup.Child -and $tweaksPresetsPopup.Child.IsMouseOver) { return }

        $src = $_.OriginalSource -as [System.Windows.DependencyObject]
        if ($null -ne $src) {
            $inAppBtn = $presetsBtn.IsAncestorOf($src) -or [System.Object]::ReferenceEquals($presetsBtn, $src)
            $inTweaksBtn = $tweaksPresetsBtn.IsAncestorOf($src) -or [System.Object]::ReferenceEquals($tweaksPresetsBtn, $src)

            if ($isAppPopupOpen -and -not $inAppBtn) { $presetsPopup.IsOpen = $false }
            if ($isTweaksPopupOpen -and -not $inTweaksBtn) { $tweaksPresetsPopup.IsOpen = $false }
        }
    })

    $window.Add_Deactivated({
        if ($presetsPopup.IsOpen) { $presetsPopup.IsOpen = $false }
        if ($tweaksPresetsPopup.IsOpen) { $tweaksPresetsPopup.IsOpen = $false }
    })

    # ---- Toggle popup on button click ----
    $presetsBtn.Add_Click({
        $presetsPopup.IsOpen = -not $presetsPopup.IsOpen
        $presetsBtn.IsChecked = $presetsPopup.IsOpen
    })

    $tweaksPresetsBtn.Add_Click({
        $tweaksPresetsPopup.IsOpen = -not $tweaksPresetsPopup.IsOpen
        $tweaksPresetsBtn.IsChecked = $tweaksPresetsPopup.IsOpen
    })

    # ---- App Search Box ----
    $appSearchBox = $window.FindName('AppSearchBox')
    $appSearchPlaceholder = $window.FindName('AppSearchPlaceholder')

    $appSearchBox.Add_TextChanged({
        $searchText = $appSearchBox.Text.ToLower().Trim()
        $appSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($appSearchBox.Text)) { 'Visible' } else { 'Collapsed' }

        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.Background = [System.Windows.Media.Brushes]::Transparent
            }
        }

        $script:AppSearchMatches = @()
        $script:AppSearchMatchIndex = -1

        if ([string]::IsNullOrWhiteSpace($searchText)) { return }

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

        if ($script:AppSearchMatches.Count -gt 0) {
            $script:AppSearchMatchIndex = 0
            $script:AppSearchMatches[0].Background = $activeHighlightBrush
            $scrollViewer = Find-ParentScrollViewer -Element $appsPanel
            if ($scrollViewer) {
                Scroll-ToItemIfNotVisible -ScrollViewer $scrollViewer -Item $script:AppSearchMatches[0] -Container $appsPanel
            }
        }
    })

    $appSearchBox.Add_KeyDown({
        param($sourceControl, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter -and $script:AppSearchMatches.Count -gt 0) {
            $script:AppSearchMatches[$script:AppSearchMatchIndex].Background = $window.Resources["SearchHighlightColor"]
            $script:AppSearchMatchIndex = ($script:AppSearchMatchIndex + 1) % $script:AppSearchMatches.Count
            $script:AppSearchMatches[$script:AppSearchMatchIndex].Background = $window.Resources["SearchHighlightActiveColor"]
            $scrollViewer = Find-ParentScrollViewer -Element $appsPanel
            if ($scrollViewer) {
                Scroll-ToItemIfNotVisible -ScrollViewer $scrollViewer -Item $script:AppSearchMatches[$script:AppSearchMatchIndex] -Container $appsPanel
            }
            $e.Handled = $true
        }
    })

    # ---- Tweak Search Box ----
    $tweaksScrollViewer.Add_ScrollChanged({
        if ($tweaksScrollViewer.ScrollableHeight -gt 0) {
            $tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0, 0, 17, 0)
        }
        else {
            $tweakSearchBorder.Margin = [System.Windows.Thickness]::new(0)
        }
    })

    $tweakSearchBox.Add_TextChanged({
        $searchText = $tweakSearchBox.Text.ToLower().Trim()
        $tweakSearchPlaceholder.Visibility = if ([string]::IsNullOrWhiteSpace($tweakSearchBox.Text)) { 'Visible' } else { 'Collapsed' }

        Clear-TweakHighlights -Window $window

        if ([string]::IsNullOrWhiteSpace($searchText)) { return }

        $firstMatch = $null
        $highlightBrush = $window.Resources["SearchHighlightColor"]
        $col0 = $window.FindName('Column0Panel')
        $col1 = $window.FindName('Column1Panel')
        $col2 = $window.FindName('Column2Panel')
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

                            if ($labelText.Contains($searchText) -or ($comboBox -and (Test-ComboBoxContainsMatch -ComboBox $comboBox -SearchText $searchText))) {
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

        if ($firstMatch -and $tweaksScrollViewer) {
            Scroll-ToItemIfNotVisible -ScrollViewer $tweaksScrollViewer -Item $firstMatch -Container $tweaksGrid
        }
    })

    # ---- Show currently applied tweaks checkbox ----
    if ($ShowCurrentlyAppliedTweaksCheckBox) {
        $ShowCurrentlyAppliedTweaksCheckBox.Add_Checked({
            Reset-TweaksToSystemState -Window $window -LoadSystemState $true
            Update-AppliedTweaksUserModeState -ShowCurrentlyAppliedTweaksCheckBox $ShowCurrentlyAppliedTweaksCheckBox -UserSelectionCombo $userSelectionCombo
        })
        $ShowCurrentlyAppliedTweaksCheckBox.Add_Unchecked({
            Reset-TweaksToSystemState -Window $window -LoadSystemState $false
            Update-AppliedTweaksUserModeState -ShowCurrentlyAppliedTweaksCheckBox $ShowCurrentlyAppliedTweaksCheckBox -UserSelectionCombo $userSelectionCombo
        })
    }

    # ---- Ctrl+F keyboard shortcut ----
    $window.Add_KeyDown({
        param($sourceControl, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::F -and
            ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) {
            $currentTab = $tabControl.SelectedItem
            if ($currentTab.Header -eq "App Removal" -and $appSearchBox) {
                $appSearchBox.Focus()
                $e.Handled = $true
            }
            elseif ($currentTab.Header -eq "Tweaks" -and $tweakSearchBox) {
                $tweakSearchBox.Focus()
                $e.Handled = $true
            }
        }
    })

    # ---- Navigation button handlers ----
    function Invoke-NavigationUpdate {
        Update-NavigationButtons -Window $window -TabControl $tabControl
    }

    $previousBtn.Add_Click({
        Hide-Bubble -Immediate
        if ($tabControl.SelectedIndex -gt 0) {
            $tabControl.SelectedIndex--
            Invoke-NavigationUpdate
        }
    })

    $nextBtn.Add_Click({
        if ($tabControl.SelectedIndex -lt ($tabControl.Items.Count - 1)) {
            $tabControl.SelectedIndex++
            Invoke-NavigationUpdate
        }
    })

    # ---- User selection combo ----
    $userSelectionCombo.Add_SelectionChanged({
        Update-UserSelectionDescription -Window $window -UserSelectionCombo $userSelectionCombo -OtherUsernameTextBox $otherUsernameTextBox -UserSelectionDescription $userSelectionDescription

        switch ($userSelectionCombo.SelectedIndex) {
            0 {
                $otherUserPanel.Visibility = 'Collapsed'
                $usernameValidationMessage.Text = ""
                $appRemovalScopeCurrentUser.Visibility = 'Visible'
                $appRemovalScopeTargetUser.Visibility = 'Collapsed'
                $appRemovalScopeCombo.SelectedIndex = 0
                if ($ShowCurrentlyAppliedTweaksCheckBox -and $ShowCurrentlyAppliedTweaksCheckBox.IsChecked -ne $true) {
                    $ShowCurrentlyAppliedTweaksCheckBox.IsChecked = $true
                }
            }
            1 {
                $otherUserPanel.Visibility = 'Visible'
                $usernameValidationMessage.Text = ""
                $appRemovalScopeCurrentUser.Visibility = 'Collapsed'
                $appRemovalScopeTargetUser.Visibility = 'Visible'
                $appRemovalScopeCombo.SelectedIndex = 0
                if ($ShowCurrentlyAppliedTweaksCheckBox -and $ShowCurrentlyAppliedTweaksCheckBox.IsChecked -eq $true) {
                    $ShowCurrentlyAppliedTweaksCheckBox.IsChecked = $false
                }
            }
            2 {
                $otherUserPanel.Visibility = 'Collapsed'
                $usernameValidationMessage.Text = ""
                $appRemovalScopeCurrentUser.Visibility = 'Collapsed'
                $appRemovalScopeTargetUser.Visibility = 'Collapsed'
                $appRemovalScopeCombo.SelectedIndex = 0
                if ($ShowCurrentlyAppliedTweaksCheckBox -and $ShowCurrentlyAppliedTweaksCheckBox.IsChecked -eq $true) {
                    $ShowCurrentlyAppliedTweaksCheckBox.IsChecked = $false
                }
            }
        }

        Update-AppSelectionStatus -AppsPanel $appsPanel -AppSelectionStatus $appSelectionStatus -AppRemovalScopeCombo $appRemovalScopeCombo -AppRemovalScopeSection $appRemovalScopeSection -AppRemovalScopeDescription $appRemovalScopeDescription -UserSelectionCombo $userSelectionCombo
        Update-AppliedTweaksUserModeState -ShowCurrentlyAppliedTweaksCheckBox $ShowCurrentlyAppliedTweaksCheckBox -UserSelectionCombo $userSelectionCombo
    })

    # ---- App removal scope combo ----
    $appRemovalScopeCombo.Add_SelectionChanged({
        Update-AppRemovalScopeDescription -AppRemovalScopeCombo $appRemovalScopeCombo -AppRemovalScopeDescription $appRemovalScopeDescription
    })

    # ---- Other username text box ----
    $otherUsernameTextBox.Add_TextChanged({
        if ([string]::IsNullOrWhiteSpace($otherUsernameTextBox.Text)) {
            $usernameTextBoxPlaceholder.Visibility = 'Visible'
        }
        else {
            $usernameTextBoxPlaceholder.Visibility = 'Collapsed'
        }
        Update-UserSelectionDescription -Window $window -UserSelectionCombo $userSelectionCombo -OtherUsernameTextBox $otherUsernameTextBox -UserSelectionDescription $userSelectionDescription
        Test-OtherUsername -Window $window -UserSelectionCombo $userSelectionCombo -OtherUsernameTextBox $otherUsernameTextBox -UsernameValidationMessage $usernameValidationMessage | Out-Null
    })

    # ---- Validate target user helper ----
    $ensureValidTargetUserOrWarn = {
        if (-not (Test-OtherUsername -Window $window -UserSelectionCombo $userSelectionCombo -OtherUsernameTextBox $otherUsernameTextBox -UsernameValidationMessage $usernameValidationMessage)) {
            $validationMessage = if (-not [string]::IsNullOrWhiteSpace($usernameValidationMessage.Text)) {
                $usernameValidationMessage.Text
            }
            else {
                "Please enter a valid username."
            }
            Show-MessageBox -Message $validationMessage -Title "Invalid Username" -Button 'OK' -Icon 'Warning' | Out-Null
            return $false
        }
        return $true
    }

    # ---- Home Start button ----
    $homeStartBtn.Add_Click({
        if (-not (& $ensureValidTargetUserOrWarn)) { return }
        $tabControl.SelectedIndex = 1
        Invoke-NavigationUpdate
    })

    # ---- Home Default Mode button ----
    $homeDefaultModeBtn.Add_Click({
        if (-not (& $ensureValidTargetUserOrWarn)) { return }

        if ($ShowCurrentlyAppliedTweaksCheckBox) {
            $ShowCurrentlyAppliedTweaksCheckBox.IsChecked = $false
        }

        $defaultsJson = LoadJsonFile -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"
        if ($defaultsJson) {
            ApplySettingsToUiControls -window $window -settingsJson $defaultsJson -uiControlMappings $script:UiControlMappings
        }

        if ($script:IsLoadingApps) {
            $script:PendingDefaultMode = $true
        }
        else {
            Invoke-AppPreset -AppsPanel $appsPanel -MatchFilter { param($c) $c.SelectedByDefault -eq $true } -Exclusive
        }

        $tabControl.SelectedIndex = 3
        Invoke-NavigationUpdate

        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Loaded, [action]{
            Show-Bubble -TargetControl $reviewChangesBtn -Message 'View the selected changes here'
        }) | Out-Null
    })

    # ---- Review Changes link ----
    $reviewChangesBtn.Add_Click({
        Hide-Bubble
        Invoke-ShowChangesOverview -Window $window -AppsPanel $appsPanel -ShowCurrentlyAppliedTweaksCheckBox $ShowCurrentlyAppliedTweaksCheckBox
    })

    # ---- Apply Changes button ----
    $deploymentApplyBtn.Add_Click({
        if (-not (& $ensureValidTargetUserOrWarn)) { return }

        Hide-Bubble -Immediate

        $showAppliedTweaksMode = ($ShowCurrentlyAppliedTweaksCheckBox -and $ShowCurrentlyAppliedTweaksCheckBox.IsChecked -eq $true)
        $selectedForwardFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

        # App Removal - collect selected apps
        $selectedApps = @()
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedApps += @($child.AppIds)
            }
        }
        $selectedApps = @($selectedApps | Where-Object { $_ } | Select-Object -Unique)
        $hasAppSelection = ($selectedApps.Count -gt 0)

        if ($selectedApps.Count -gt 0) {
            if (-not (ConfirmUnsafeAppRemoval -SelectedApps $selectedApps -Owner $window)) { return }

            AddParameter 'RemoveApps'
            AddParameter 'Apps' ($selectedApps -join ',')

            $selectedScopeItem = $appRemovalScopeCombo.SelectedItem
            if ($selectedScopeItem) {
                switch ($selectedScopeItem.Content) {
                    "All users" { AddParameter 'AppRemovalTarget' 'AllUsers' }
                    "Current user only" { AddParameter 'AppRemovalTarget' 'CurrentUser' }
                    "Target user only" { AddParameter 'AppRemovalTarget' ($otherUsernameTextBox.Text.Trim()) }
                }
            }
        }

        # Apply dynamic tweaks
        foreach ($tweakAction in @(Get-PendingTweakActions -Window $window -ShowAppliedTweaksMode:$showAppliedTweaksMode)) {
            if ($tweakAction.Action -eq 'Apply') {
                AddParameter $tweakAction.FeatureId
                $null = $selectedForwardFeatureIds.Add([string]$tweakAction.FeatureId)
                continue
            }
            $script:UndoParams[[string]$tweakAction.FeatureId] = $true
        }

        if (-not $hasAppSelection -and $selectedForwardFeatureIds.Count -eq 0 -and $script:UndoParams.Count -eq 0) {
            Show-MessageBox -Message 'No changes have been selected, please select at least one option to proceed.' -Title 'No Changes Selected' -Button 'OK' -Icon 'Information'
            return
        }

        $restorePointCheckBox = $window.FindName('RestorePointCheckBox')
        if ($restorePointCheckBox -and $restorePointCheckBox.IsChecked) {
            AddParameter 'CreateRestorePoint'
        }

        switch ($userSelectionCombo.SelectedIndex) {
            0 { Write-Host "Selected user mode: current user ($(GetUserName))" }
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

        $restartExplorerCheckBox = $window.FindName('RestartExplorerCheckBox')
        $shouldRestartExplorer = $restartExplorerCheckBox -and $restartExplorerCheckBox.IsChecked

        Show-ApplyModal -Owner $window -RestartExplorer $shouldRestartExplorer
        $window.Close()
    })

    # ---- Tweaks presets tri-state ----
    foreach ($presetCheckBox in @($presetDefaultTweaksBtn, $presetLastUsedTweaksBtn, $presetPrivacyTweaksBtn, $presetAITweaksBtn)) {
        Add-TriStateClickBehavior -CheckBox $presetCheckBox
    }

    # ---- Clear All Tweaks ----
    $clearAllTweaksBtn.Add_Click({
        if ($ShowCurrentlyAppliedTweaksCheckBox -and $ShowCurrentlyAppliedTweaksCheckBox.IsChecked -eq $true) {
            $ShowCurrentlyAppliedTweaksCheckBox.IsChecked = $false
        }
        Clear-TweakSelections -Window $window
        Update-TweakPresetStates -Window $window
    })

    # ---- Window Load event ----
    $window.Add_Loaded({
        try {
            & $updateHomeContentPosition
            Build-DynamicTweaks -Window $window -WinVersion $WinVersion
            Load-CurrentTweakStateIntoUI -Window $window
            Update-TweaksResponsiveColumns -Window $window

            $lastUsedSettingsJson = LoadJsonFile -filePath $script:SavedSettingsFilePath -expectedVersion "1.0" -optionalFile
            $defaultsJson = LoadJsonFile -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"

            $script:SavedAppIds = Get-SavedAppIdsFromSettingsJson -SettingsJson $lastUsedSettingsJson

            Initialize-TweakPresetSources -Window $window -DefaultSettingsJson $defaultsJson -LastUsedSettingsJson $lastUsedSettingsJson
            Register-TweakPresetControlStateHandlers -Window $window
            Update-TweakPresetStates -Window $window

            Load-AppsIntoMainUI -Window $window -AppsPanel $appsPanel -OnlyInstalledAppsBox $onlyInstalledAppsBox -LoadingAppsIndicator $loadingAppsIndicator -ImportConfigBtn $importConfigBtn

            # Update Current User label
            if ($userSelectionCombo -and $userSelectionCombo.Items.Count -gt 0) {
                $currentUserItem = $userSelectionCombo.Items[0]
                if ($currentUserItem -is [System.Windows.Controls.ComboBoxItem]) {
                    $currentUserItem.Content = "Current User ($(GetUserName))"
                }
            }

            # When running as SYSTEM, the "Current User" option is not meaningful.
            # Hide it from the dropdown and default to "Other User".
            $isSystem = ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18')
            if ($isSystem -and $userSelectionCombo.Items.Count -gt 0) {
                $currentUserItem = $userSelectionCombo.Items[0]
                if ($currentUserItem -is [System.Windows.Controls.ComboBoxItem]) {
                    $currentUserItem.Visibility = 'Collapsed'
                    $currentUserItem.IsEnabled = $false
                }
                $userSelectionCombo.SelectedIndex = 1
            }

            $restartExplorerCheckBox = $window.FindName('RestartExplorerCheckBox')
            if ($restartExplorerCheckBox -and $script:Params.ContainsKey("NoRestartExplorer")) {
                $restartExplorerCheckBox.IsChecked = $false
                $restartExplorerCheckBox.IsEnabled = $false
            }

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

            Update-UserSelectionDescription -Window $window -UserSelectionCombo $userSelectionCombo -OtherUsernameTextBox $otherUsernameTextBox -UserSelectionDescription $userSelectionDescription
            Update-AppliedTweaksUserModeState -ShowCurrentlyAppliedTweaksCheckBox $ShowCurrentlyAppliedTweaksCheckBox -UserSelectionCombo $userSelectionCombo
            Invoke-NavigationUpdate
        }
        catch {
            Write-Warning "Error during GUI initialization: $($_.Exception.Message)"
            Write-Warning "Stack trace: $($_.Exception.StackTrace)"
            Show-MessageBox -Message "An error occurred during initialization: $($_.Exception.Message)" -Title "Initialization Error" -Button 'OK' -Icon 'Error' | Out-Null
        }
    })

    # ---- Tab change event ----
    $tabControl.Add_SelectionChanged({
        if ($tabControl.SelectedIndex -eq ($tabControl.Items.Count - 2)) {
            New-Overview -Window $window -AppsPanel $appsPanel -ShowCurrentlyAppliedTweaksCheckBox $ShowCurrentlyAppliedTweaksCheckBox | Out-Null
        }
        Invoke-NavigationUpdate
    })

    # ---- Tweak presets wiring ----
    $lastUsedSettingsJson = LoadJsonFile -filePath $script:SavedSettingsFilePath -expectedVersion "1.0" -optionalFile
    $defaultsJson = LoadJsonFile -filePath $script:DefaultSettingsFilePath -expectedVersion "1.0"
    $script:DefaultTweakPresetMap = @{}
    $script:LastUsedTweakPresetMap = @{}
    $script:PrivacyTweakPresetMap = @{}
    $script:AITweakPresetMap = @{}
    $script:SavedAppIds = Get-SavedAppIdsFromSettingsJson -SettingsJson $lastUsedSettingsJson

    if ($presetDefaultTweaksBtn) {
        $presetDefaultTweaksBtn.Add_Click({
            if ($script:UpdatingTweakPresets) { return }
            $check = ConvertTo-NormalizedCheckboxState -CheckBox $this
            Invoke-ApplyTweakPresetMap -PresetMap $script:DefaultTweakPresetMap -Check $check
        })
    }

    if ($presetLastUsedTweaksBtn) {
        $presetLastUsedTweaksBtn.Add_Click({
            if ($script:UpdatingTweakPresets) { return }
            $check = ConvertTo-NormalizedCheckboxState -CheckBox $this
            Invoke-ApplyTweakPresetMap -PresetMap $script:LastUsedTweakPresetMap -Check $check
        })
    }

    if ($presetPrivacyTweaksBtn) {
        $presetPrivacyTweaksBtn.Add_Click({
            if ($script:UpdatingTweakPresets) { return }
            $check = ConvertTo-NormalizedCheckboxState -CheckBox $this
            Invoke-ApplyTweakPresetMap -PresetMap $script:PrivacyTweakPresetMap -Check $check
        })
    }

    if ($presetAITweaksBtn) {
        $presetAITweaksBtn.Add_Click({
            if ($script:UpdatingTweakPresets) { return }
            $check = ConvertTo-NormalizedCheckboxState -CheckBox $this
            Invoke-ApplyTweakPresetMap -PresetMap $script:AITweakPresetMap -Check $check
        })
    }

    # Hide Last used tweak preset by default
    if ($presetLastUsedTweaksBtn) {
        $presetLastUsedTweaksBtn.Visibility = 'Collapsed'
    }

    # ---- Preset: Last used selection (apps) ----
    if ($script:SavedAppIds) {
        $presetLastUsed.Add_Click({
            if ($script:UpdatingPresets) { return }
            $check = ConvertTo-NormalizedCheckboxState -CheckBox $this
            Invoke-AppPreset -AppsPanel $appsPanel -MatchFilter { param($c) (@($c.AppIds) | Where-Object { $script:SavedAppIds -contains $_ }).Count -gt 0 } -Check $check
        })
    }
    else {
        $script:SavedAppIds = $null
        $presetLastUsed.Visibility = 'Collapsed'
    }

    # ---- Preload app data ----
    try {
        $script:PreloadedAppData = LoadAppsDetailsFromJson -OnlyInstalled:$false -InstalledList $null -InitialCheckedFromJson:$false
    }
    catch {
        Write-Warning "Failed to preload apps list: $_"
    }

    # ---- Show window ----
    $frame = [System.Windows.Threading.DispatcherFrame]::new()
    $window.Add_Closed({
        $frame.Continue = $false
    })

    $window.Show() | Out-Null

    # If WhatIf mode is enabled, notify the user that no changes will be made
    if ($script:Params.ContainsKey("WhatIf")) {
        $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Loaded, [action]{
            Show-MessageBox -Message "WhatIf mode is enabled. The script will not make any changes to your system in this mode.`n`nYou can observe the actions that would be taken by the script in the console output." -Title 'WhatIf Mode' -Button 'OK' -Icon 'Information' -Owner $window
        }) | Out-Null
    }

    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
    return $null
}
