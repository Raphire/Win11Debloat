BeforeAll {
    Add-Type -AssemblyName PresentationFramework
    . (Join-Path $PSScriptRoot '..\Scripts\Helpers\Import-ConfigToParams.ps1')
    . (Join-Path $PSScriptRoot '..\Scripts\GUI\Show-ImportExportConfigWindow.ps1')

    # Returns the key, followed by the format arguments, so tests can see which options a description lists.
    function Get-Translation {
        param($Key, $FormatArgs)
        if ($FormatArgs) { return "$Key $($FormatArgs -join '|')" }
        return $Key
    }

    function New-DeploymentTestControls {
        $window = New-Object System.Windows.Window
        [System.Windows.NameScope]::SetNameScope($window, [System.Windows.NameScope]::new())

        $controls = @{ Window = $window }
        # Start from the opposite of what the tests expect to be written, so a control that was left alone shows up.
        foreach ($entry in @(
                @{ Name = 'RestorePointCheckBox'; Initial = $true }
                @{ Name = 'RegistryBackupCheckBox'; Initial = $false }
                @{ Name = 'RestartExplorerCheckBox'; Initial = $true }
            )) {
            $checkBox = New-Object System.Windows.Controls.CheckBox
            $checkBox.IsChecked = $entry.Initial
            $window.RegisterName($entry.Name, $checkBox)
            $controls[$entry.Name] = $checkBox
        }

        $combo = New-Object System.Windows.Controls.ComboBox
        'Current User', 'Other User', 'Windows Default User (Sysprep)' | ForEach-Object {
            $combo.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = $_ })) | Out-Null
        }
        $combo.SelectedIndex = 0
        $controls['UserCombo'] = $combo
        $controls['OtherUserBox'] = New-Object System.Windows.Controls.TextBox

        return $controls
    }

    function Invoke-ImportedDeploymentSettings {
        param($Controls, [hashtable]$Values)

        $settings = @($Values.GetEnumerator() | ForEach-Object { [PSCustomObject]@{ Name = $_.Key; Value = $_.Value } })
        Set-ImportedDeploymentSettings -Owner $Controls.Window -UserSelectionCombo $Controls.UserCombo `
            -OtherUsernameTextBox $Controls.OtherUserBox -DeploymentSettings $settings
    }
}

Describe 'Set-ImportedDeploymentSettings' {
    BeforeEach {
        $warnings = [System.Collections.Generic.List[string]]::new()
        Mock Write-Warning { $warnings.Add([string]$Message) }
    }

    It 'checks the boxes for real booleans' {
        $controls = New-DeploymentTestControls
        $controls.RestorePointCheckBox.IsChecked = $false
        $controls.RegistryBackupCheckBox.IsChecked = $true
        $controls.RestartExplorerCheckBox.IsChecked = $false

        Invoke-ImportedDeploymentSettings -Controls $controls -Values @{ CreateRestorePoint = $true; SkipRegistryBackup = $false; RestartExplorer = $true }

        $controls.RestorePointCheckBox.IsChecked | Should -BeTrue
        $controls.RegistryBackupCheckBox.IsChecked | Should -BeTrue
        $controls.RestartExplorerCheckBox.IsChecked | Should -BeTrue
    }

    It 'reads the text false as false, not as true' {
        $controls = New-DeploymentTestControls

        Invoke-ImportedDeploymentSettings -Controls $controls -Values @{ CreateRestorePoint = 'false'; SkipRegistryBackup = 'false'; RestartExplorer = 'False' }

        $controls.RestorePointCheckBox.IsChecked | Should -BeFalse
        $controls.RegistryBackupCheckBox.IsChecked | Should -BeTrue
        $controls.RestartExplorerCheckBox.IsChecked | Should -BeFalse
    }

    It 'reads the text true as true' {
        $controls = New-DeploymentTestControls
        $controls.RestorePointCheckBox.IsChecked = $false
        $controls.RegistryBackupCheckBox.IsChecked = $true
        $controls.RestartExplorerCheckBox.IsChecked = $false

        Invoke-ImportedDeploymentSettings -Controls $controls -Values @{ CreateRestorePoint = 'true'; SkipRegistryBackup = 'true'; RestartExplorer = 'TRUE' }

        $controls.RestorePointCheckBox.IsChecked | Should -BeTrue
        $controls.RegistryBackupCheckBox.IsChecked | Should -BeFalse
        $controls.RestartExplorerCheckBox.IsChecked | Should -BeTrue
    }

    It 'leaves a box alone when the value is not a boolean (<Text>)' -ForEach @(
        @{ Text = 'the text yes'; Value = 'yes' }
        @{ Text = 'the text 0'; Value = '0' }
        @{ Text = 'the number 2'; Value = 2 }
    ) {
        $controls = New-DeploymentTestControls

        Invoke-ImportedDeploymentSettings -Controls $controls -Values @{ CreateRestorePoint = $Value; SkipRegistryBackup = $Value; RestartExplorer = $Value }

        $controls.RestorePointCheckBox.IsChecked | Should -BeTrue
        $controls.RegistryBackupCheckBox.IsChecked | Should -BeFalse
        $controls.RestartExplorerCheckBox.IsChecked | Should -BeTrue
        $warnings | Should -HaveCount 3
        foreach ($name in 'CreateRestorePoint', 'SkipRegistryBackup', 'RestartExplorer') {
            $warnings | Where-Object { $_ -like "*'$name'*expected true or false, found '$Value'*" } | Should -HaveCount 1
        }
    }

    It 'leaves a box alone when its setting is missing' {
        $controls = New-DeploymentTestControls

        Invoke-ImportedDeploymentSettings -Controls $controls -Values @{ UserSelectionIndex = 1 }

        $controls.UserCombo.SelectedIndex | Should -Be 1
        $controls.RestorePointCheckBox.IsChecked | Should -BeTrue
        $controls.RegistryBackupCheckBox.IsChecked | Should -BeFalse
        $controls.RestartExplorerCheckBox.IsChecked | Should -BeTrue
        $warnings | Should -HaveCount 0
    }
}

Describe 'Get-DeploymentCategoryDetailString' {
    BeforeEach {
        $warnings = [System.Collections.Generic.List[string]]::new()
        Mock Write-Warning { $warnings.Add([string]$Message) }
    }

    It 'lists the options a config really turns on when values are written as text' {
        $settings = @(
            [PSCustomObject]@{ Name = 'CreateRestorePoint'; Value = 'false' }
            [PSCustomObject]@{ Name = 'SkipRegistryBackup'; Value = 'false' }
            [PSCustomObject]@{ Name = 'RestartExplorer'; Value = 'false' }
        )

        $text = Get-DeploymentCategoryDetailString -DeploymentSettings $settings

        $text | Should -Match 'ImportExportOptionRegistryBackup'
        $text | Should -Not -Match 'ImportExportOptionRestorePoint'
        $text | Should -Not -Match 'ImportExportOptionRestartExplorer'
    }

    It 'lists every option for real booleans and the text true' -ForEach @(
        @{ Create = $true; Skip = $false; Restart = $true }
        @{ Create = 'true'; Skip = 'false'; Restart = 'True' }
    ) {
        $settings = @(
            [PSCustomObject]@{ Name = 'CreateRestorePoint'; Value = $Create }
            [PSCustomObject]@{ Name = 'SkipRegistryBackup'; Value = $Skip }
            [PSCustomObject]@{ Name = 'RestartExplorer'; Value = $Restart }
        )

        $text = Get-DeploymentCategoryDetailString -DeploymentSettings $settings

        $text | Should -Match 'ImportExportOptionRestorePoint'
        $text | Should -Match 'ImportExportOptionRegistryBackup'
        $text | Should -Match 'ImportExportOptionRestartExplorer'
    }

    It 'leaves out the registry backup when it is skipped, including when written as text' -ForEach @(
        @{ Skip = $true }
        @{ Skip = 'true' }
    ) {
        $settings = @([PSCustomObject]@{ Name = 'SkipRegistryBackup'; Value = $Skip })

        Get-DeploymentCategoryDetailString -DeploymentSettings $settings | Should -Not -Match 'ImportExportOptionRegistryBackup'
    }
    It 'does not list the registry backup for an unsupported SkipRegistryBackup value, and does not warn' {
        $settings = @([PSCustomObject]@{ Name = 'SkipRegistryBackup'; Value = 'yes' })

        Get-DeploymentCategoryDetailString -DeploymentSettings $settings | Should -Not -Match 'ImportExportOptionRegistryBackup'
        $warnings | Should -HaveCount 0
    }

    It 'lists the registry backup when SkipRegistryBackup is missing' {
        $settings = @([PSCustomObject]@{ Name = 'RestartExplorer'; Value = $true })

        Get-DeploymentCategoryDetailString -DeploymentSettings $settings | Should -Match 'ImportExportOptionRegistryBackup'
    }
}
