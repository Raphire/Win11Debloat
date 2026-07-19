BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\MainWindow-AppSelection.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\MainWindow-Deployment.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\MainWindow-Navigation.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\MainWindow-TweaksBuilder.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\Set-WindowThemeResources.ps1')

    function New-TestWindow {
        $window = New-Object System.Windows.Window
        [System.Windows.NameScope]::SetNameScope($window, [System.Windows.NameScope]::new())
        $window.Resources['ProgressActiveColor'] = [System.Windows.Media.Brushes]::Green
        $window.Resources['ProgressInactiveColor'] = [System.Windows.Media.Brushes]::Gray
        return $window
    }
}

Describe 'ConvertTo-NormalizedCheckboxState' {
    It 'normalizes indeterminate tri-state checkboxes to checked' {
        $checkBox = New-Object System.Windows.Controls.CheckBox
        $checkBox.IsThreeState = $true
        $checkBox.IsChecked = $null
        Add-Member -InputObject $checkBox -MemberType NoteProperty -Name 'WasIndeterminateBeforeClick' -Value $true

        ConvertTo-NormalizedCheckboxState -CheckBox $checkBox | Should -BeTrue
        $checkBox.IsChecked | Should -BeTrue
        $checkBox.WasIndeterminateBeforeClick | Should -BeFalse
    }

    It 'sets tri-state preset checkboxes for empty, partial, and complete selections' {
        $checkBox = New-Object System.Windows.Controls.CheckBox
        $checkBox.IsThreeState = $true

        Set-TriStatePresetCheckBoxState -CheckBox $checkBox -Total 0 -Selected 0
        $checkBox.IsEnabled | Should -BeFalse
        Set-TriStatePresetCheckBoxState -CheckBox $checkBox -Total 3 -Selected 1
        $checkBox.IsChecked.HasValue | Should -BeFalse
        Set-TriStatePresetCheckBoxState -CheckBox $checkBox -Total 3 -Selected 3
        $checkBox.IsChecked | Should -BeTrue
    }

    It 'rebuilds highlighted-search indexes and sorts app controls' {
        $panel = New-Object System.Windows.Controls.StackPanel
        $first = New-Object System.Windows.Controls.CheckBox
        $first.Content = 'Zeta'
        $first | Add-Member NoteProperty AppName 'Zeta'
        $first | Add-Member NoteProperty AppDescription 'Last'
        $first | Add-Member NoteProperty AppIdDisplay 'Zeta.App'
        $first.Background = [System.Windows.Media.Brushes]::Yellow
        $second = New-Object System.Windows.Controls.CheckBox
        $second.Content = 'Alpha'
        $second | Add-Member NoteProperty AppName 'Alpha'
        $second | Add-Member NoteProperty AppDescription 'First'
        $second | Add-Member NoteProperty AppIdDisplay 'Alpha.App'
        $second.Background = [System.Windows.Media.Brushes]::Yellow
        $null = $panel.Children.Add($first)
        $null = $panel.Children.Add($second)
        $script:AppSearchMatches = @()
        $script:AppSearchMatchIndex = -1
        $script:SortColumn = 'Name'
        $script:SortAscending = $true
        $nameArrow = New-Object System.Windows.Controls.TextBlock
        $descriptionArrow = New-Object System.Windows.Controls.TextBlock
        $appIdArrow = New-Object System.Windows.Controls.TextBlock
        $nameArrow.RenderTransform = New-Object System.Windows.Media.RotateTransform
        $descriptionArrow.RenderTransform = New-Object System.Windows.Media.RotateTransform
        $appIdArrow.RenderTransform = New-Object System.Windows.Media.RotateTransform

        Update-AppsPanelRebuildSearchIndex -AppsPanel $panel -ActiveMatch $second
        Update-AppsPanelSort -AppsPanel $panel -SortArrowName $nameArrow -SortArrowDescription $descriptionArrow -SortArrowAppId $appIdArrow

        $panel.Children[0].AppName | Should -Be 'Alpha'
        $script:AppSearchMatches.Count | Should -Be 2
        $script:AppSearchMatches[$script:AppSearchMatchIndex] | Should -Be $second
        $nameArrow.Opacity | Should -Be 1
    }

    It 'finds matching combo-box content case-insensitively' {
        $comboBox = New-Object System.Windows.Controls.ComboBox
        $null = $comboBox.Items.Add('Disable telemetry')
        $null = $comboBox.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = 'Enable widgets' }))

        Test-ComboBoxContainsMatch -ComboBox $comboBox -SearchText 'telemetry' | Should -BeTrue
        Test-ComboBoxContainsMatch -ComboBox $comboBox -SearchText 'missing' | Should -BeFalse
    }
}

Describe 'Get-PendingTweakActions' {
    BeforeEach {
        $script:FeatureLabelLookup = @{ DisableTelemetry = 'Disable telemetry'; EnableWidgets = 'Enable widgets' }
        $script:UndoFeatureLabelLookup = @{ DisableTelemetry = 'Enable telemetry' }
    }

    It 'builds pending apply and undo actions from mapped checkbox state' {
        $window = New-TestWindow
        $applyCheckBox = New-Object System.Windows.Controls.CheckBox
        $applyCheckBox.IsChecked = $true
        $applyCheckBox | Add-Member NoteProperty InitialState $false
        $undoCheckBox = New-Object System.Windows.Controls.CheckBox
        $undoCheckBox.IsChecked = $false
        $undoCheckBox | Add-Member NoteProperty InitialState $true
        $window.RegisterName('ApplyTelemetry', $applyCheckBox)
        $window.RegisterName('UndoTelemetry', $undoCheckBox)
        $script:UiControlMappings = @{
            ApplyTelemetry = [PSCustomObject]@{ Type = 'feature'; FeatureId = 'DisableTelemetry' }
            UndoTelemetry = [PSCustomObject]@{ Type = 'feature'; FeatureId = 'DisableTelemetry' }
        }

        $actions = @(Get-PendingTweakActions -Window $window -ShowAppliedTweaksMode:$false | Sort-Object Action)

        $actions.Action | Should -Be @('Apply', 'Undo')
        $actions.Label | Should -Be @('Disable telemetry', 'Enable telemetry')
    }

    It 'builds a category preset map for visible mapped controls' {
        $window = New-TestWindow
        $checkBox = New-Object System.Windows.Controls.CheckBox
        $checkBox.Visibility = 'Visible'
        $window.RegisterName('DisableTelemetryCheckBox', $checkBox)
        $script:UiControlMappings = @{ DisableTelemetryCheckBox = [PSCustomObject]@{ Category = 'Privacy'; Type = 'feature'; FeatureId = 'DisableTelemetry' } }

        $map = Get-CategoryTweakPresetMap -Window $window -Category 'Privacy'

        $map['DisableTelemetryCheckBox'].ControlType | Should -Be 'CheckBox'
        $map['DisableTelemetryCheckBox'].DesiredValue | Should -BeTrue
    }

    It 'updates navigation visibility and progress indicators for an interior tab' {
        $window = New-TestWindow
        $tabControl = New-Object System.Windows.Controls.TabControl
        0..3 | ForEach-Object { $null = $tabControl.Items.Add((New-Object System.Windows.Controls.TabItem)) }
        $tabControl.SelectedIndex = 2
        foreach ($name in @('PreviousBtn', 'NextBtn', 'BottomNavGrid')) { $window.RegisterName($name, (New-Object System.Windows.Controls.Border)) }
        foreach ($name in @('ProgressIndicator1', 'ProgressIndicator2', 'ProgressIndicator3')) { $window.RegisterName($name, (New-Object System.Windows.Shapes.Rectangle)) }

        Update-NavigationButtons -Window $window -TabControl $tabControl

        $window.FindName('PreviousBtn').Visibility | Should -Be 'Visible'
        $window.FindName('NextBtn').Visibility | Should -Be 'Visible'
        $window.FindName('ProgressIndicator1').Fill | Should -Be $window.Resources['ProgressActiveColor']
        $window.FindName('ProgressIndicator3').Fill | Should -Be $window.Resources['ProgressInactiveColor']
    }
}

Describe 'Set-WindowThemeResources' {
    It 'populates themed resources and selects the Windows 11 icon font' {
        $window = New-TestWindow
        $script:SharedStylesSchema = $null
        Mock Get-ItemPropertyValue { 22631 }

        Set-WindowThemeResources -window $window -usesDarkMode:$true

        $window.Resources['AppBgColor'] | Should -Not -BeNullOrEmpty
        $window.Resources['AppIconFontFamily'].Source | Should -Be 'Segoe Fluent Icons'
    }
}
