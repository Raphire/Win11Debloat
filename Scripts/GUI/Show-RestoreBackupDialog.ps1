function Show-RestoreBackupDialog {
    param(
        [Parameter(Mandatory = $false)]
        [System.Windows.Window]$Owner = $null
    )

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    $usesDarkMode = GetSystemUsesDarkMode
    $ownerWindow = if ($Owner) { $Owner } else { $script:GuiWindow }

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

    $schemaPath = $script:RestoreBackupWindowSchema
    if (-not $schemaPath -or -not (Test-Path $schemaPath)) {
        throw 'Restore backup window schema file could not be found.'
    }

    $xaml = Get-Content -Path $schemaPath -Raw

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        $reader.Close()
    }

    if ($ownerWindow) {
        try {
            $window.Owner = $ownerWindow
        }
        catch { }
    }

    try {
        SetWindowThemeResources -window $window -usesDarkMode $usesDarkMode
    }
    catch { }

    $titleBar = $window.FindName('TitleBar')
    $titleText = $window.FindName('TitleText')
    $closeBtn = $window.FindName('CloseBtn')
    $backBtn = $window.FindName('BackBtn')
    $primaryActionBtn = $window.FindName('PrimaryActionBtn')
    $chooseRegistryBtn = $window.FindName('ChooseRegistryBtn')
    $chooseStartMenuBtn = $window.FindName('ChooseStartMenuBtn')
    $selectTypePanel = $window.FindName('SelectTypePanel')
    $registryPanel = $window.FindName('RegistryPanel')
    $startMenuPanel = $window.FindName('StartMenuPanel')
    $startMenuScopeCombo = $window.FindName('StartMenuScopeCombo')
    $wizardStatusText = $window.FindName('WizardStatusText')
    $introInfoPanel = $window.FindName('IntroInfoPanel')
    $overviewPanel = $window.FindName('OverviewPanel')
    $backupFileText = $window.FindName('BackupFileText')
    $backupCreatedText = $window.FindName('BackupCreatedText')
    $backupTargetText = $window.FindName('BackupTargetText')
    $featuresItemsControl = $window.FindName('FeaturesItemsControl')
    $nonRevertibleSeparator = $window.FindName('NonRevertibleSeparator')
    $nonRevertiblePanel = $window.FindName('NonRevertiblePanel')
    $nonRevertibleFeaturesItemsControl = $window.FindName('NonRevertibleFeaturesItemsControl')
    $nonRevertibleWikiLink = $window.FindName('NonRevertibleWikiLink')

    if (-not $closeBtn -or -not $backBtn -or -not $primaryActionBtn -or -not $chooseRegistryBtn -or -not $chooseStartMenuBtn) {
        throw 'Restore dialog failed to initialize action buttons.'
    }

    $titleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
    $window.Tag = New-RestoreDialogState
    $chooseRegistryBtn.IsDefault = $true

    $state = @{ WizardStep = 'SelectType'; SelectedRegistryBackup = $null }

    if ($overviewPanel) { $overviewPanel.Visibility = 'Collapsed' }
    if ($wizardStatusText) { $wizardStatusText.Visibility = 'Collapsed'; $wizardStatusText.Text = '' }

    $setWizardStep = {
        param([string]$step)

        $state.WizardStep = $step

        if ($wizardStatusText) {
            $wizardStatusText.Visibility = 'Collapsed'
            $wizardStatusText.Text = ''
        }

        switch ($step) {
            'SelectType' {
                if ($titleText) { $titleText.Text = 'Restore Backup' }
                if ($selectTypePanel) { $selectTypePanel.Visibility = 'Visible' }
                if ($registryPanel) { $registryPanel.Visibility = 'Collapsed' }
                if ($startMenuPanel) { $startMenuPanel.Visibility = 'Collapsed' }
                $backBtn.Visibility = 'Visible'
                $backBtn.Content = 'Cancel'
                $primaryActionBtn.Visibility = 'Collapsed'
                $chooseRegistryBtn.IsDefault = $true
                $primaryActionBtn.IsDefault = $false
            }
            'Registry' {
                if ($titleText) { $titleText.Text = 'Restore Registry Backup' }
                if ($selectTypePanel) { $selectTypePanel.Visibility = 'Collapsed' }
                if ($registryPanel) { $registryPanel.Visibility = 'Visible' }
                if ($startMenuPanel) { $startMenuPanel.Visibility = 'Collapsed' }
                if ($introInfoPanel) { $introInfoPanel.Visibility = 'Visible' }
                if ($overviewPanel) { $overviewPanel.Visibility = 'Collapsed' }
                $backBtn.Visibility = 'Visible'
                $backBtn.Content = 'Back'
                $primaryActionBtn.Visibility = 'Visible'
                $primaryActionBtn.Content = 'Select backup file'
                $primaryActionBtn.IsDefault = $true
                $chooseRegistryBtn.IsDefault = $false
            }
            'StartMenu' {
                if ($titleText) { $titleText.Text = 'Restore Start Menu Backup' }
                if ($selectTypePanel) { $selectTypePanel.Visibility = 'Collapsed' }
                if ($registryPanel) { $registryPanel.Visibility = 'Collapsed' }
                if ($startMenuPanel) { $startMenuPanel.Visibility = 'Visible' }
                $backBtn.Visibility = 'Visible'
                $backBtn.Content = 'Back'
                $primaryActionBtn.Visibility = 'Visible'
                $primaryActionBtn.Content = 'Restore backup'
                $primaryActionBtn.IsDefault = $true
                $chooseRegistryBtn.IsDefault = $false
            }
        }
    }

    if ($nonRevertibleWikiLink) {
        $nonRevertibleWikiLink.Add_MouseLeftButtonUp({
            try {
                Start-Process 'https://github.com/Raphire/Win11Debloat/wiki/Reverting-Changes' | Out-Null
            }
            catch { }
        })
    }

    $closeBtn.Add_Click({
        $window.Tag = New-RestoreDialogState
        $window.DialogResult = $false
        $window.Close()
    })

    $chooseRegistryBtn.Add_Click({ & $setWizardStep 'Registry' })
    $chooseStartMenuBtn.Add_Click({ & $setWizardStep 'StartMenu' })

    $backBtn.Add_Click({
        if ($state.WizardStep -eq 'SelectType') {
            $window.Tag = New-RestoreDialogState
            $window.DialogResult = $false
            $window.Close()
            return
        }

        & $setWizardStep 'SelectType'
    })

    $primaryActionBtn.Add_Click({
        if ($state.WizardStep -eq 'Registry') {
            if (-not $state.SelectedRegistryBackup) {
                $openDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openDialog.Title = 'Select registry backup file'
                $openDialog.Filter = 'Registry backup (*.json)|*.json|All files (*.*)|*.*'
                $openDialog.DefaultExt = '.json'
                $openDialog.InitialDirectory = $script:RegistryBackupsPath

                if ($openDialog.ShowDialog($window) -ne $true) {
                    return
                }

                Write-Host "Backup file selected: $($openDialog.FileName)"
                try {
                    $selectedBackup = Load-RegistryBackupFromFile -FilePath $openDialog.FileName
                }
                catch {
                    Write-Error "Failed to load registry backup from file '$($openDialog.FileName)': $($_.Exception.Message)"
                    if ($wizardStatusText) {
                        $wizardStatusText.Text = 'The selected file is not a valid registry backup.'
                        $wizardStatusText.Visibility = 'Visible'
                    }
                    return
                }

                $createdText = if ([string]::IsNullOrWhiteSpace($selectedBackup.CreatedAt)) {
                    'Unknown'
                }
                else {
                    try {
                        [DateTime]::Parse($selectedBackup.CreatedAt).ToString('yyyy-MM-dd HH:mm')
                    }
                    catch {
                        $selectedBackup.CreatedAt
                    }
                }

                $selectedFeatureIds = Get-SelectedFeatureIdsFromBackup -SelectedBackup $selectedBackup
                $featureLists = Get-RestoreBackupFeatureLists -SelectedFeatureIds $selectedFeatureIds -Features $script:Features
                $revertibleFeaturesList = @($featureLists.Revertible)
                $nonRevertibleFeaturesList = @($featureLists.NonRevertible)
                Write-Host "Backup overview prepared. Revertible=$($revertibleFeaturesList.Count), NonRevertible=$($nonRevertibleFeaturesList.Count)"

                if ($revertibleFeaturesList.Count -eq 0) {
                    if ($wizardStatusText) {
                        $wizardStatusText.Text = 'The selected backup does not contain any changes that can be automatically reverted.'
                        $wizardStatusText.Visibility = 'Visible'
                    }
                    return
                }

                $backupFileText.Text = Split-Path $openDialog.FileName -Leaf
                $backupCreatedText.Text = $createdText
                $backupTargetText.Text = [string]$selectedBackup.Target
                $featuresItemsControl.ItemsSource = $revertibleFeaturesList
                if ($nonRevertibleFeaturesItemsControl) {
                    $nonRevertibleFeaturesItemsControl.ItemsSource = $nonRevertibleFeaturesList
                }

                $hasNonRevertibleItems = ($nonRevertibleFeaturesList.Count -gt 0)
                if ($nonRevertiblePanel) {
                    if ($hasNonRevertibleItems) { $nonRevertiblePanel.Visibility = 'Visible' } else { $nonRevertiblePanel.Visibility = 'Collapsed' }
                }
                if ($nonRevertibleSeparator) {
                    if ($hasNonRevertibleItems) { $nonRevertibleSeparator.Visibility = 'Visible' } else { $nonRevertibleSeparator.Visibility = 'Collapsed' }
                }
                if ($introInfoPanel) { $introInfoPanel.Visibility = 'Collapsed' }
                if ($overviewPanel) { $overviewPanel.Visibility = 'Visible' }

                $state.SelectedRegistryBackup = $selectedBackup
                $primaryActionBtn.Content = 'Restore from backup'
                return
            }

            $window.Tag = @{
                Result = 'RestoreRegistry'
                Backup = $state.SelectedRegistryBackup
            }
            $window.DialogResult = $true
            $window.Close()
            return
        }

        if ($state.WizardStep -eq 'StartMenu') {
            $scope = 'CurrentUser'
            if ($startMenuScopeCombo -and $startMenuScopeCombo.SelectedItem) {
                $selectedComboItem = $startMenuScopeCombo.SelectedItem
                if ($selectedComboItem.Tag -eq 'AllUsers') {
                    $scope = 'AllUsers'
                }
            }
            $window.Tag = @{
                Result = 'RestoreStartMenu'
                StartMenuScope = $scope
            }
            $window.DialogResult = $true
            $window.Close()
        }
    })

    $window.Add_KeyDown({
        param($source, $e)
        if ($e.Key -eq 'Escape') {
            $window.Tag = New-RestoreDialogState
            $window.DialogResult = $false
            $window.Close()
        }
    })

    & $setWizardStep 'SelectType'

    try {
        $null = $window.ShowDialog()
    }
    catch {
        $innerMessage = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { 'None' }
        throw "Failed to show restore backup dialog. Error: $($_.Exception.Message) Inner: $innerMessage"
    }
    finally {
        if ($overlay -and -not $overlayWasAlreadyVisible) {
            try {
                $ownerWindow.Dispatcher.Invoke([action]{ $overlay.Visibility = 'Collapsed' })
            }
            catch { }
        }
    }

    return $window.Tag
}
