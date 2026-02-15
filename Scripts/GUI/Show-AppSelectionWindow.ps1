# Shows application selection window that allows the user to select what apps they want to remove or keep
function Show-AppSelectionWindow {
    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    $usesDarkMode = GetSystemUsesDarkMode
    
    # Show overlay if main window exists
    $overlay = $null
    if ($script:GuiWindow) {
        try {
            $overlay = $script:GuiWindow.FindName('ModalOverlay')
            if ($overlay) {
                $script:GuiWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Visible' })
            }
        }
        catch { }
    }

    # Load XAML from file
    $xaml = Get-Content -Path $script:AppSelectionSchema -Raw
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }
    
    # Set owner to main window if it exists
    if ($script:GuiWindow) {
        try {
            $window.Owner = $script:GuiWindow
        }
        catch { }
    }

    SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode

    $appsPanel = $window.FindName('AppsPanel')
    $checkAllBox = $window.FindName('CheckAllBox')
    $onlyInstalledBox = $window.FindName('OnlyInstalledBox')
    $confirmBtn = $window.FindName('ConfirmBtn')
    $loadingIndicator = $window.FindName('LoadingAppsIndicator')
    $titleBar = $window.FindName('TitleBar')
    
    # Track the last selected checkbox for shift-click range selection
    $script:AppSelectionWindowLastSelectedCheckbox = $null

    # Loads apps into the apps UI
    function LoadApps {
        # Show loading indicator
        $loadingIndicator.Visibility = 'Visible'
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})

        $appsPanel.Children.Clear()
        $listOfApps = ""

        if ($onlyInstalledBox.IsChecked -and ($script:WingetInstalled -eq $true)) {
            # Attempt to get a list of installed apps via WinGet, times out after 10 seconds
            $listOfApps = GetInstalledAppsViaWinget -TimeOut 10
            if (-not $listOfApps) {
                # Show error that the script was unable to get list of apps from WinGet
                Show-ModernMessageBox -Message 'Unable to load list of installed apps via WinGet.' -Title 'Error' -Button 'OK' -Icon 'Error' -Owner $window | Out-Null
                $onlyInstalledBox.IsChecked = $false
            }
        }

        $appsToAdd = LoadAppsDetailsFromJson -OnlyInstalled:$onlyInstalledBox.IsChecked -InstalledList $listOfApps -InitialCheckedFromJson

        # Reset the last selected checkbox when loading a new list
        $script:AppSelectionWindowLastSelectedCheckbox = $null

        # Sort apps alphabetically and add to panel
        $appsToAdd | Sort-Object -Property DisplayName | ForEach-Object {
            $checkbox = New-Object System.Windows.Controls.CheckBox
            $checkbox.Content = $_.DisplayName
            $checkbox.SetValue([System.Windows.Automation.AutomationProperties]::NameProperty, $_.DisplayName)
            $checkbox.Tag = $_.AppId
            $checkbox.IsChecked = $_.IsChecked
            $checkbox.ToolTip = $_.Description
            $checkbox.Style = $window.Resources["AppsPanelCheckBoxStyle"]
            
            # Attach shift-click behavior for range selection
            AttachShiftClickBehavior -checkbox $checkbox -appsPanel $appsPanel -lastSelectedCheckboxRef ([ref]$script:AppSelectionWindowLastSelectedCheckbox)
            
            $appsPanel.Children.Add($checkbox) | Out-Null
        }

        # Hide loading indicator
        $loadingIndicator.Visibility = 'Collapsed'
    }

    # Event handlers
    $titleBar.Add_MouseLeftButtonDown({
        $window.DragMove()
    })

    $checkAllBox.Add_Checked({
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.IsChecked = $true
            }
        }
    })

    $checkAllBox.Add_Unchecked({
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox]) {
                $child.IsChecked = $false
            }
        }
    })

    $onlyInstalledBox.Add_Checked({ LoadApps })
    $onlyInstalledBox.Add_Unchecked({ LoadApps })

    $confirmBtn.Add_Click({
        $selectedApps = @()
        foreach ($child in $appsPanel.Children) {
            if ($child -is [System.Windows.Controls.CheckBox] -and $child.IsChecked) {
                $selectedApps += $child.Tag
            }
        }

        # Close form without saving if no apps were selected
        if ($selectedApps.Count -eq 0) {
            $window.Close()
            return
        }

        if ($selectedApps -contains "Microsoft.WindowsStore" -and -not $Silent) {
            $result = Show-ModernMessageBox -Message 'Are you sure you wish to uninstall the Microsoft Store? This app cannot easily be reinstalled.' -Title 'Are you sure?' -Button 'YesNo' -Icon 'Warning' -Owner $window

            if ($result -eq 'No') {
                return
            }
        }

        SaveCustomAppsListToFile -appsList $selectedApps

        $window.DialogResult = $true
    })

    # Load apps after window is shown (allows UI to render first)
    $window.Add_ContentRendered({ 
        $window.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{ LoadApps })
    })

    # Show the window and return dialog result
    $result = $window.ShowDialog()
    
    # Hide overlay after dialog closes
    if ($overlay) {
        try {
            $script:GuiWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' })
        }
        catch { }
    }
    
    return $result
}
