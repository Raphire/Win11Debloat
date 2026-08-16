BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    function Test-TargetUserName { param($UserName) }
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\MainWindow-AppSelection.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\MainWindow-Deployment.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\Get-SystemUsesDarkMode.ps1')

    function New-TestWindow {
        $window = New-Object System.Windows.Window
        $window.Resources['ValidationErrorColor'] = [System.Windows.Media.Brushes]::Red
        $window.Resources['ValidationSuccessColor'] = [System.Windows.Media.Brushes]::Green
        return $window
    }

    function New-UserSelectionCombo {
        param([int]$SelectedIndex = 0)

        $combo = New-Object System.Windows.Controls.ComboBox
        'Current User', 'Other User', 'Windows Default User (Sysprep)' | ForEach-Object {
            $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = $_ })) | Out-Null
        }
        $combo.SelectedIndex = $SelectedIndex
        return $combo
    }

    function New-AppRemovalScopeCombo {
        param([string]$SelectedItemName)

        $combo = New-Object System.Windows.Controls.ComboBox
        if ($SelectedItemName) {
            $item = New-Object System.Windows.Controls.ComboBoxItem
            $item.Name = $SelectedItemName
            $combo.Items.Add($item) | Out-Null
            $combo.SelectedItem = $item
        }
        return $combo
    }
}

Describe 'Get-UndoFeatureLabel' {
    BeforeEach {
        $script:UndoFeatureLabelLookup = @{ DisableTelemetry = 'Enable telemetry' }
        $script:FeatureLabelLookup = @{ DisableTelemetry = 'Disable telemetry'; DisableWidgets = 'Disable widgets' }
    }

    It 'prefers undo labels and falls back to feature labels' {
        Get-UndoFeatureLabel -FeatureId 'DisableTelemetry' | Should -Be 'Enable telemetry'
        Get-UndoFeatureLabel -FeatureId 'DisableWidgets' | Should -Be 'Disable widgets'
    }

    It 'reads selected app IDs from string or array settings and removes blanks' {
        $stringSettings = [PSCustomObject]@{ Settings = @([PSCustomObject]@{ Name = 'Apps'; Value = ' One.App, ,Two.App ' }) }
        $arraySettings = [PSCustomObject]@{ Settings = @([PSCustomObject]@{ Name = 'Apps'; Value = @(' One.App ', '', 'Two.App') }) }

        Get-SavedAppIdsFromSettingsJson -SettingsJson $stringSettings | Should -Be @('One.App', 'Two.App')
        Get-SavedAppIdsFromSettingsJson -SettingsJson $arraySettings | Should -Be @('One.App', 'Two.App')
        Get-SavedAppIdsFromSettingsJson -SettingsJson ([PSCustomObject]@{ Settings = @() }) | Should -BeNullOrEmpty
    }

    It 'returns the AppsUseLightTheme registry preference and fails closed' {
        Mock Get-ItemProperty { [PSCustomObject]@{ AppsUseLightTheme = 0 } }
        Get-SystemUsesDarkMode | Should -BeTrue

        Mock Get-ItemProperty { throw 'Registry unavailable' }
        Get-SystemUsesDarkMode | Should -BeFalse
    }
}

Describe 'Test-OtherUsername' {
    It 'skips validation when neither the deployment target nor the app-removal scope needs a username' {
        Mock Test-TargetUserName { [PSCustomObject]@{ IsValid = $false; Message = 'unused' } }
        $window = New-TestWindow
        $userCombo = New-UserSelectionCombo -SelectedIndex 0
        $usernameBox = New-Object System.Windows.Controls.TextBox
        $message = New-Object System.Windows.Controls.TextBlock
        $scopeCombo = New-AppRemovalScopeCombo -SelectedItemName 'AppRemovalScopeAllUsers'

        Test-OtherUsername -Window $window -UserSelectionCombo $userCombo -OtherUsernameTextBox $usernameBox -UsernameValidationMessage $message -AppRemovalScopeCombo $scopeCombo | Should -BeTrue
        Should -Invoke Test-TargetUserName -Times 0 -Exactly
    }

    It 'validates when the deployment target is Other User' {
        Mock Test-TargetUserName { [PSCustomObject]@{ IsValid = $false; Message = 'Please enter a username' } }
        $window = New-TestWindow
        $userCombo = New-UserSelectionCombo -SelectedIndex 1
        $usernameBox = New-Object System.Windows.Controls.TextBox
        $usernameBox.Text = ''
        $message = New-Object System.Windows.Controls.TextBlock

        Test-OtherUsername -Window $window -UserSelectionCombo $userCombo -OtherUsernameTextBox $usernameBox -UsernameValidationMessage $message | Should -BeFalse
    }

    It 'validates when the app-removal scope is Target user only, even if the deployment target is not Other User' {
        $window = New-TestWindow
        $userCombo = New-UserSelectionCombo -SelectedIndex 0
        $usernameBox = New-Object System.Windows.Controls.TextBox
        $usernameBox.Text = '  '
        $message = New-Object System.Windows.Controls.TextBlock
        $scopeCombo = New-AppRemovalScopeCombo -SelectedItemName 'AppRemovalScopeTargetUser'

        Mock Test-TargetUserName { [PSCustomObject]@{ IsValid = $false; Message = 'Please enter a username' } }
        Test-OtherUsername -Window $window -UserSelectionCombo $userCombo -OtherUsernameTextBox $usernameBox -UsernameValidationMessage $message -AppRemovalScopeCombo $scopeCombo | Should -BeFalse

        $usernameBox.Text = 'jdoe'
        Mock Test-TargetUserName { [PSCustomObject]@{ IsValid = $true; Message = 'User found: jdoe' } }
        Test-OtherUsername -Window $window -UserSelectionCombo $userCombo -OtherUsernameTextBox $usernameBox -UsernameValidationMessage $message -AppRemovalScopeCombo $scopeCombo | Should -BeTrue
    }
}
