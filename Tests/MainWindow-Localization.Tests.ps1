# Headless component tests: no main/settings XAML, Show/ShowDialog, or message loop.
BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    foreach ($file in @('FileIO/Import-JsonFile', 'FileIO/Import-LanguageFile',
        'GUI/Ui-Preferences', 'GUI/Show-SettingsDialog', 'GUI/Set-WindowThemeResources',
        'GUI/MainWindow-Localization', 'GUI/MainWindow-TweaksBuilder', 'GUI/MainWindow-AppSelection',
        'GUI/MainWindow-Deployment', 'GUI/Show-Bubble', 'Helpers/Get-UserName')) {
        . "$script:RepoRoot/Scripts/$file.ps1"
    }
    $script:LanguagesPath = Join-Path $script:RepoRoot 'Config/Languages'
    $script:FeaturesFilePath = Join-Path $script:RepoRoot 'Config/Features.json'
    $script:Features = @{}
    foreach ($feature in (Import-JsonFile -filePath $script:FeaturesFilePath).Features) { $script:Features[$feature.FeatureId] = $feature }
    $tokens = $null; $parseErrors = $null
    $mainAst = [System.Management.Automation.Language.Parser]::ParseFile("$script:RepoRoot/Scripts/GUI/Show-MainWindow.ps1", [ref]$tokens, [ref]$parseErrors)
    $script:SearchHandlers = @{}
    foreach ($handler in $mainAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
        $node.Member.Value -eq 'Add_TextChanged' -and $node.Expression.VariablePath.UserPath -in @('appSearchBox', 'tweakSearchBox')
    }, $true)) {
        $script:SearchHandlers[$handler.Expression.VariablePath.UserPath] = $handler.Arguments[0].ScriptBlock.GetScriptBlock()
    }

    <#
        .SYNOPSIS
            Creates a minimal window for dynamic tweak localization tests.

        .OUTPUTS
            System.Windows.Window. The test window with its registered column panels.
    #>
    function New-LanguageTestWindow {
        $window = [System.Windows.Window]::new()
        [System.Windows.NameScope]::SetNameScope($window, [System.Windows.NameScope]::new())
        $window.Content = [System.Windows.Controls.StackPanel]::new()
        foreach ($name in @('Column0Panel', 'Column1Panel', 'Column2Panel')) {
            $panel = [System.Windows.Controls.StackPanel]::new()
            $window.RegisterName($name, $panel)
            [void]$window.Content.Children.Add($panel)
        }
        return $window
    }
}

Describe 'Language changes on existing controls' {
    BeforeEach {
        $script:Lang = Import-LanguageFile -LanguageCode 'en-US'
        $script:ModernStandbySupported = $false
    }

    It 'matches fresh and refreshed tweak text on Windows build <Build>' -ForEach @(
        @{ Build = 19045 }
        @{ Build = 26100 }
    ) {
        <#
            .SYNOPSIS
                Serializes current tweak presentation text for comparison.

            .DESCRIPTION
                Captures labels, tooltips, and options to compare freshly created controls
                with controls refreshed after a language change.

            .PARAMETER Window
                The test window containing registered tweak controls and label borders.

            .OUTPUTS
                System.String. The serialized presentation snapshot.
        #>
        function Get-TweakPresentationSnapshot($window) {
            $rows = foreach ($name in ($script:UiControlMappings.Keys | Sort-Object)) {
                $control = $window.FindName($name)
                $label = if ($control -is [System.Windows.Controls.CheckBox]) { $control.Content }
                    else { $window.FindName("${name}_LabelBorder").Child.Text }
                [PSCustomObject]@{
                    Name = $name
                    Label = $label
                    ToolTip = if ($control.ToolTip) { $control.ToolTip.Text } else { $null }
                    Options = @($control.Items | ForEach-Object { $_.Content })
                }
            }
            return ConvertTo-Json -InputObject @($rows) -Depth 4 -Compress
        }

        foreach ($language in @('nl-NL', 'pt-BR')) {
            $script:Lang = Import-LanguageFile -LanguageCode $language
            $fresh = New-LanguageTestWindow
            New-DynamicTweakControls -Window $fresh -WinVersion $Build
            $expected = Get-TweakPresentationSnapshot $fresh

            $script:Lang = Import-LanguageFile -LanguageCode 'en-US'
            $refreshed = New-LanguageTestWindow
            New-DynamicTweakControls -Window $refreshed -WinVersion $Build
            $script:Lang = Import-LanguageFile -LanguageCode $language
            Update-MainWindowTweakLanguage -Window $refreshed
            Get-TweakPresentationSnapshot $refreshed | Should -Be $expected
        }
    }

    It 'updates text, accessibility names and detached menu resources with English fallback' {
        $window = New-LanguageTestWindow
        $button = [System.Windows.Controls.Button]::new()
        $button.SetResourceReference([System.Windows.Controls.ContentControl]::ContentProperty, 'Language_SettingsTitle')
        $button.SetResourceReference([System.Windows.Automation.AutomationProperties]::NameProperty, 'Language_SettingsTitle')
        [void]$window.Content.Children.Add($button)
        $menu = [System.Windows.Controls.ContextMenu]::new()
        $window.RegisterName('MainMenu', $menu)
        $item = [System.Windows.Controls.MenuItem]::new()
        $item.SetResourceReference([System.Windows.Controls.HeaderedItemsControl]::HeaderProperty, 'Language_MenuAbout')
        [void]$menu.Items.Add($item)

        foreach ($language in @('en-US', 'nl-NL', 'pt-BR', 'en-US')) {
            $script:Lang = Import-LanguageFile -LanguageCode $language
            Update-WindowLanguageResources -Window $window
            $button.Content | Should -Be (Get-Translation -Key 'SettingsTitle')
            [System.Windows.Automation.AutomationProperties]::GetName($button) | Should -Be $button.Content
            $item.Header | Should -Be (Get-Translation -Key 'MenuAbout')
        }
        $script:Lang = [PSCustomObject]@{ Chrome = [PSCustomObject]@{ SettingsTitle = 'Custom & <text>' }; Fallback = $script:Lang }
        Update-WindowLanguageResources -Window $window
        $button.Content | Should -Be 'Custom & <text>'
        $item.Header | Should -Be 'About'
    }

    It 'translates generated tweaks without replacing controls, selections or applied-state metadata' {
        $window = New-LanguageTestWindow
        New-DynamicTweakControls -Window $window -WinVersion 26100
        $checkbox = $window.FindName('Feature_DisableTelemetry_Combo')
        $checkbox.IsChecked = $false
        $checkbox | Add-Member -NotePropertyMembers @{ InitialState = $true; SystemState = $true }
        $disabled = $window.FindName('Feature_DisableWidgets_Combo')
        $disabled.IsChecked = $true
        $disabled.IsEnabled = $false
        $disabled | Add-Member -NotePropertyMembers @{ InitialState = $true; SystemState = $true; DisableWhenApplied = $true }
        $group = $window.FindName('Group_SearchIconCombo')
        $group.SelectedIndex = 2
        $group | Add-Member -NotePropertyMembers @{ InitialIndex = 1; SystemIndex = 1 }
        $selectedItem = $group.SelectedItem
        $script:SelectionChanges = 0
        $group.Add_SelectionChanged({ $script:SelectionChanges++ })
        $before = @(Get-PendingTweakActions -Window $window -ShowAppliedTweaksMode $true | ForEach-Object { "$($_.Action):$($_.FeatureId)" } | Sort-Object)

        foreach ($language in @('nl-NL', 'pt-BR', 'en-US')) {
            $script:Lang = Import-LanguageFile -LanguageCode $language
            Update-MainWindowTweakLanguage -Window $window
            [object]::ReferenceEquals($window.FindName('Feature_DisableTelemetry_Combo'), $checkbox) | Should -BeTrue
            $checkbox.Content | Should -Be (Get-Translation -Key 'DisableTelemetry' -Field 'Label' -Section 'Features')
            $checkbox.ToolTip.Text | Should -Be (Get-Translation -Key 'DisableTelemetry' -Field 'ToolTip' -Section 'Features')
            $disabled.IsEnabled | Should -BeFalse
            $disabled.DisableWhenApplied | Should -BeTrue
            $disabled.ToolTip.Text | Should -Be (Get-Translation -Key 'TweaksAlreadyAppliedTooltip')
            [object]::ReferenceEquals($group.SelectedItem, $selectedItem) | Should -BeTrue
            $group.SelectedIndex | Should -Be 2
            $selectedItem.Content | Should -Be (Get-GroupValueTranslation -GroupId 'SearchIcon' -FeatureId $script:UiControlMappings['Group_SearchIconCombo'].Values[1].FeatureIds[0] -FallbackLabel 'fallback')
            @(Get-PendingTweakActions -Window $window -ShowAppliedTweaksMode $true | ForEach-Object { "$($_.Action):$($_.FeatureId)" } | Sort-Object) | Should -Be $before
            $script:FeatureLabelLookup['DisableTelemetry'] | Should -Be $checkbox.Content
            foreach ($category in $script:CategoryLanguageControls) {
                $category.Header.Text | Should -Be (Get-Translation -Key $category.CategoryId -Field 'Label' -Section 'Categories')
            }
        }
        $script:SelectionChanges | Should -Be 0
    }

    It 'updates app display and search metadata while preserving removal IDs and selection' {
        $panel = [System.Windows.Controls.StackPanel]::new()
        $app = [System.Windows.Controls.CheckBox]::new()
        $app.IsChecked = $true
        $app.Tag = 'Microsoft.WindowsCalculator, Other.Id'
        $app | Add-Member -NotePropertyMembers @{
            AppIds = @('Microsoft.WindowsCalculator', 'Other.Id'); AppName = ''; AppDescription = ''
            AppNameText = [System.Windows.Controls.TextBlock]::new()
            AppDescriptionText = [System.Windows.Controls.TextBlock]::new()
        }
        [void]$panel.Children.Add($app)
        $script:JsonPresetCheckboxes = @()
        $script:PreloadedAppData = @('old catalog')

        foreach ($language in @('nl-NL', 'pt-BR', 'en-US')) {
            $script:Lang = Import-LanguageFile -LanguageCode $language
            Update-MainWindowAppLanguage -AppsPanel $panel
            $app.AppNameText.Text | Should -Be (Get-Translation -Key 'Microsoft.WindowsCalculator' -Field 'FriendlyName' -Section 'Apps')
            $app.AppName | Should -Be $app.AppNameText.Text
            $app.AppDescriptionText.ToolTip | Should -Be $app.AppDescription
            $app.AppIds | Should -Be @('Microsoft.WindowsCalculator', 'Other.Id')
            $app.Tag | Should -Be 'Microsoft.WindowsCalculator, Other.Id'
            $app.IsChecked | Should -BeTrue
        }
        $script:PreloadedAppData | Should -BeNullOrEmpty
    }

    It 'refreshes search and deployment text without changing user input or selections' {
        Mock Get-UserName { 'TestUser' }
        Mock Update-AppsPanelSort {}
        Mock Hide-Bubble {}
        $window = New-LanguageTestWindow
        New-DynamicTweakControls -Window $window -WinVersion 26100
        $appsPanel = [System.Windows.Controls.StackPanel]::new()
        $window.RegisterName('AppSelectionPanel', $appsPanel)
        [void]$window.Content.Children.Add($appsPanel)
        $app = [System.Windows.Controls.CheckBox]::new()
        $app.IsChecked = $true
        $app.Tag = 'Microsoft.WindowsCalculator'
        $app | Add-Member -NotePropertyMembers @{
            AppIds = @('Microsoft.WindowsCalculator'); AppName = 'Calculator'; AppDescription = ''
            AppNameText = [System.Windows.Controls.TextBlock]::new()
            AppDescriptionText = [System.Windows.Controls.TextBlock]::new()
        }
        [void]$appsPanel.Children.Add($app)
        foreach ($name in @('UserSelectionDescription', 'UsernameValidationMessage', 'AppSelectionStatus', 'AppRemovalScopeDescription', 'AppSearchPlaceholder', 'TweakSearchPlaceholder')) {
            $window.RegisterName($name, [System.Windows.Controls.TextBlock]::new())
        }
        foreach ($name in @('OtherUsernameTextBox', 'AppSearchBox', 'TweakSearchBox')) {
            $window.RegisterName($name, [System.Windows.Controls.TextBox]::new())
        }
        $userCombo = [System.Windows.Controls.ComboBox]::new()
        foreach ($label in @('Current', 'Other', 'Default')) {
            [void]$userCombo.Items.Add([System.Windows.Controls.ComboBoxItem]::new())
        }
        $userCombo.SelectedIndex = 1
        $window.RegisterName('UserSelectionCombo', $userCombo)
        $window.FindName('OtherUsernameTextBox').Text = 'Alice'
        $scope = [System.Windows.Controls.ComboBox]::new()
        $target = [System.Windows.Controls.ComboBoxItem]::new()
        $target.Name = 'AppRemovalScopeTargetUser'
        [void]$scope.Items.Add($target)
        $scope.SelectedIndex = 0
        $window.RegisterName('AppRemovalScopeCombo', $scope)
        $window.RegisterName('AppRemovalScopeSection', [System.Windows.Controls.Border]::new())
        $tabs = [System.Windows.Controls.TabControl]::new()
        foreach ($label in @('Home', 'Apps', 'Tweaks', 'Deploy')) { [void]$tabs.Items.Add($label) }
        $tabs.SelectedIndex = 2
        $window.RegisterName('MainTabControl', $tabs)
        $appSearchBox = $window.FindName('AppSearchBox')
        $appSearchPlaceholder = $window.FindName('AppSearchPlaceholder')
        $tweakSearchBox = $window.FindName('TweakSearchBox')
        $tweakSearchPlaceholder = $window.FindName('TweakSearchPlaceholder')
        $tweaksScrollViewer = $null
        $appSearchBox.Text = 'rekenmachine'
        $tweakSearchBox.Text = 'telemetrie'
        $appSearchBox.Add_TextChanged($script:SearchHandlers['appSearchBox'])
        $tweakSearchBox.Add_TextChanged($script:SearchHandlers['tweakSearchBox'])
        $script:AppSearchMatches = @(); $script:AppSearchMatchIndex = -1
        $script:JsonPresetCheckboxes = @()
        $script:SortColumn = 'Name'; $script:SortAscending = $true
        $window.Resources['SearchHighlightColor'] = [System.Windows.Media.Brushes]::Yellow
        $window.Resources['SearchHighlightActiveColor'] = [System.Windows.Media.Brushes]::Orange
        $checkbox = $window.FindName('Feature_DisableTelemetry_Combo')
        $checkbox.IsChecked = $true

        $script:Lang = Import-LanguageFile -LanguageCode 'nl-NL'
        Update-MainWindowLanguage -Window $window

        $userCombo.SelectedIndex | Should -Be 1
        $scope.SelectedItem | Should -Be $target
        $window.FindName('OtherUsernameTextBox').Text | Should -Be 'Alice'
        $tabs.SelectedIndex | Should -Be 2
        $appSearchBox.Text | Should -Be 'rekenmachine'
        $tweakSearchBox.Text | Should -Be 'telemetrie'
        $script:AppSearchMatches.Count | Should -Be 1
        [object]::ReferenceEquals($script:AppSearchMatches[0], $app) | Should -BeTrue
        $checkbox.Background | Should -Be ([System.Windows.Media.Brushes]::Yellow)
        $checkbox.IsChecked | Should -BeTrue
        $app.IsChecked | Should -BeTrue
        $window.FindName('AppSelectionStatus').Text | Should -Be (Get-Translation -Key 'AppSelectionStatusSelected' -Count 1 -FormatArgs @(1))
        $window.FindName('UserSelectionDescription').Text | Should -Be (Get-Translation -Key 'DeployUserDescriptionOtherUserNamed' -FormatArgs @('Alice'))
        $window.FindName('AppRemovalScopeDescription').Text | Should -Be (Get-Translation -Key 'AppRemovalScopeDescriptionTargetUser')
        $script:UpdatingLanguage | Should -BeFalse
    }
}

Describe 'Settings update the same window after Save' {
    BeforeEach {
        $script:IsLoadingApps = $false
        $script:UiPreferences = @{ Theme = 'Auto'; Language = 'en-US' }
        $script:Lang = [PSCustomObject]@{ LanguageCode = 'en-US' }
        Mock Set-WindowThemeResources {}
        Mock Update-MainWindowLanguage {}
        $script:WindowClosed = $false
        $script:WindowUnderTest = New-LanguageTestWindow
        $script:WindowUnderTest.Add_Closed({ $script:WindowClosed = $true })
    }

    It 'updates a saved theme without changing language or closing the window' {
        Mock Show-SettingsDialog { $script:UiPreferences.Theme = 'Dark'; return $true }
        Open-MainWindowSettings -Window $script:WindowUnderTest
        Should -Invoke Set-WindowThemeResources -Times 1 -Exactly -ParameterFilter { $usesDarkMode -eq $true }
        Should -Invoke Update-MainWindowLanguage -Times 0 -Exactly
        $script:WindowClosed | Should -BeFalse
    }

    It 'updates a saved language without closing the window' {
        Mock Show-SettingsDialog {
            $script:Lang = [PSCustomObject]@{ LanguageCode = 'nl-NL' }
            $script:UiPreferences.Theme = 'Dark'
            return $true
        }
        Open-MainWindowSettings -Window $script:WindowUnderTest
        Should -Invoke Update-MainWindowLanguage -Times 1 -Exactly -ParameterFilter { [object]::ReferenceEquals($Window, $script:WindowUnderTest) }
        Should -Invoke Set-WindowThemeResources -Times 1 -Exactly -ParameterFilter { $usesDarkMode -eq $true }
        $script:WindowClosed | Should -BeFalse
    }

    It 'does not update presentation when the settings dialog is cancelled' {
        Mock Show-SettingsDialog { $false }
        Open-MainWindowSettings -Window $script:WindowUnderTest
        Should -Invoke Set-WindowThemeResources -Times 0 -Exactly
        Should -Invoke Update-MainWindowLanguage -Times 0 -Exactly
        $script:WindowClosed | Should -BeFalse
    }
}
