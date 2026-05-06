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
    $restoreModeTabs = $window.FindName('RestoreModeTabs')
    $startMenuIntroPanel = $window.FindName('StartMenuIntroPanel')
    $startMenuScopeCombo = $window.FindName('StartMenuScopeCombo')
    $startMenuAutoBackupCheck = $window.FindName('StartMenuAutoBackupCheck')
    $introInfoPanel = $window.FindName('IntroInfoPanel')
    $overviewPanel = $window.FindName('OverviewPanel')
    $overviewFeaturesSection = $window.FindName('OverviewFeaturesSection')
    $overviewSummaryText = $window.FindName('OverviewSummaryText')
    $backupFileText = $window.FindName('BackupFileText')
    $backupCreatedText = $window.FindName('BackupCreatedText')
    $backupTargetText = $window.FindName('BackupTargetText')
    $featuresItemsControl = $window.FindName('FeaturesItemsControl')
    $nonRevertibleSeparator = $window.FindName('NonRevertibleSeparator')
    $nonRevertiblePanel = $window.FindName('NonRevertiblePanel')
    $nonRevertibleFeaturesItemsControl = $window.FindName('NonRevertibleFeaturesItemsControl')
    $nonRevertibleWikiLink = $window.FindName('NonRevertibleWikiLink')

    $titleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
    $window.Tag = New-RestoreDialogState
    $chooseRegistryBtn.IsDefault = $true

    $state = @{ WizardStep = 'SelectType'; SelectedRegistryBackup = $null; SelectedStartMenuBackupFilePath = $null }

    $getStartMenuScopeInfo = {
        $isAllUsersScope = ($startMenuScopeCombo.SelectedItem.Tag -eq 'AllUsers')
        $scopeValue = if ($isAllUsersScope) { 'AllUsers' } else { 'CurrentUser' }
        $summaryScopeText = if ($isAllUsersScope) { 'all users' } else { 'the current user' }

        return [PSCustomObject]@{
            Scope = $scopeValue
            Target = $scopeValue
            SummaryText = $summaryScopeText
        }
    }

    $showStartMenuIntroState = {
        $backupFileText.Text = 'Not selected'
        $backupCreatedText.Text = 'N/A'
        $overviewSummaryText.Visibility = 'Collapsed'
        $overviewPanel.Visibility = 'Collapsed'
        $startMenuIntroPanel.Visibility = 'Visible'
        $restoreModeTabs.SelectedIndex = 2
    }

    $showStartMenuOverviewState = {
        param([string]$BackupFilePath)

        $scopeInfo = & $getStartMenuScopeInfo
        $backupTargetText.Text = GetFriendlyRegistryBackupTarget -Target $scopeInfo.Target
        $overviewSummaryText.Text = "This will replace the current Start Menu pinned apps layout for $($scopeInfo.SummaryText) with the selected backup."
        $backupFileText.Text = Split-Path -Path $BackupFilePath -Leaf

        $createdText = 'Unknown'
        try {
            $createdText = (Get-Item -LiteralPath $BackupFilePath -ErrorAction Stop).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        }
        catch { }
        $backupCreatedText.Text = $createdText

        $overviewFeaturesSection.Visibility = 'Collapsed'
        $overviewSummaryText.Visibility = 'Visible'
        $nonRevertibleSeparator.Visibility = 'Collapsed'
        $nonRevertiblePanel.Visibility = 'Collapsed'
        $introInfoPanel.Visibility = 'Collapsed'
        $overviewPanel.Visibility = 'Visible'
        $restoreModeTabs.SelectedIndex = 1
    }

    $updateStartMenuOverviewPanel = {
        if ($state.WizardStep -ne 'StartMenu') {
            return
        }

        if ([string]::IsNullOrWhiteSpace($state.SelectedStartMenuBackupFilePath)) {
            & $showStartMenuIntroState
            return
        }

        & $showStartMenuOverviewState $state.SelectedStartMenuBackupFilePath
    }

    $updateStartMenuPrimaryActionText = {
        if ($state.WizardStep -ne 'StartMenu') {
            return
        }

        $isAutoBackupEnabled = ($startMenuAutoBackupCheck.IsChecked -eq $true)
        $hasSelectedManualFile = -not [string]::IsNullOrWhiteSpace($state.SelectedStartMenuBackupFilePath)
        if ($isAutoBackupEnabled -or $hasSelectedManualFile) {
            $primaryActionBtn.Content = 'Restore backup'
        }
        else {
            $primaryActionBtn.Content = 'Select backup file'
        }
    }

    $refreshStartMenuUi = {
        & $updateStartMenuOverviewPanel
        & $updateStartMenuPrimaryActionText
    }

    $enterSelectTypeStep = {
        $titleText.Text = 'Restore Backup'
        $restoreModeTabs.SelectedIndex = 0
        $backBtn.Visibility = 'Visible'
        $backBtn.Content = 'Cancel'
        $primaryActionBtn.Visibility = 'Collapsed'
        $chooseRegistryBtn.IsDefault = $true
        $primaryActionBtn.IsDefault = $false
    }

    $enterRegistryStep = {
        $titleText.Text = 'Restore Registry Backup'
        $restoreModeTabs.SelectedIndex = 1
        $introInfoPanel.Visibility = 'Visible'
        $overviewPanel.Visibility = 'Collapsed'
        $overviewFeaturesSection.Visibility = 'Visible'
        $overviewSummaryText.Visibility = 'Collapsed'
        $backBtn.Visibility = 'Visible'
        $backBtn.Content = 'Back'
        $primaryActionBtn.Visibility = 'Visible'
        $primaryActionBtn.Content = 'Select backup file'
        $primaryActionBtn.IsDefault = $true
        $chooseRegistryBtn.IsDefault = $false
    }

    $enterStartMenuStep = {
        $titleText.Text = 'Restore Start Menu Backup'
        $restoreModeTabs.SelectedIndex = 2
        $backBtn.Visibility = 'Visible'
        $backBtn.Content = 'Back'
        $primaryActionBtn.Visibility = 'Visible'
        $primaryActionBtn.IsDefault = $true
        $chooseRegistryBtn.IsDefault = $false
        & $refreshStartMenuUi
    }

    $showRegistryOverview = {
        param(
            [Parameter(Mandatory = $true)]
            $SelectedBackup,
            [Parameter(Mandatory = $true)]
            [string]$SelectedBackupFilePath
        )

        $createdText = if ([string]::IsNullOrWhiteSpace($SelectedBackup.CreatedAt)) {
            'Unknown'
        }
        else {
            try {
                [DateTime]::Parse($SelectedBackup.CreatedAt).ToString('yyyy-MM-dd HH:mm')
            }
            catch {
                $SelectedBackup.CreatedAt
            }
        }

        $selectedFeatureIds = Get-SelectedFeatureIdsFromBackup -SelectedBackup $SelectedBackup
        $featureLists = Get-RestoreBackupFeatureLists -SelectedFeatureIds $selectedFeatureIds -Features $script:Features
        $revertibleFeaturesList = @($featureLists.Revertible)
        $nonRevertibleFeaturesList = @($featureLists.NonRevertible)
        Write-Host "Backup overview prepared. Revertible=$($revertibleFeaturesList.Count), NonRevertible=$($nonRevertibleFeaturesList.Count)"

        if ($revertibleFeaturesList.Count -eq 0) {
            throw 'The selected backup does not contain any changes that can be restored.'
        }

        $backupFileText.Text = Split-Path $SelectedBackupFilePath -Leaf
        $backupCreatedText.Text = $createdText
        $backupTargetText.Text = GetFriendlyRegistryBackupTarget -Target ([string]$SelectedBackup.Target)
        $featuresItemsControl.ItemsSource = $revertibleFeaturesList
        $overviewFeaturesSection.Visibility = 'Visible'
        $overviewSummaryText.Visibility = 'Collapsed'
        $nonRevertibleFeaturesItemsControl.ItemsSource = $nonRevertibleFeaturesList

        $hasNonRevertibleItems = ($nonRevertibleFeaturesList.Count -gt 0)
        if ($hasNonRevertibleItems) { $nonRevertiblePanel.Visibility = 'Visible' } else { $nonRevertiblePanel.Visibility = 'Collapsed' }
        if ($hasNonRevertibleItems) { $nonRevertibleSeparator.Visibility = 'Visible' } else { $nonRevertibleSeparator.Visibility = 'Collapsed' }
        $introInfoPanel.Visibility = 'Collapsed'
        $overviewPanel.Visibility = 'Visible'

        return $true
    }

    $handleRegistryPrimaryAction = {
        if ($state.SelectedRegistryBackup) {
            $window.Tag = @{
                Result = 'RestoreRegistry'
                Backup = $state.SelectedRegistryBackup
            }
            $window.DialogResult = $true
            $window.Close()
            return
        }

        $openDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openDialog.Title = 'Select Registry Backup File'
        $openDialog.Filter = 'Registry backup (*.json)|*.json|All files (*.*)|*.*'
        $openDialog.DefaultExt = '.json'
        $openDialog.InitialDirectory = $script:RegistryBackupsPath

        if ($openDialog.ShowDialog($window) -ne $true) {
            return
        }

        Write-Host "Backup file selected: $($openDialog.FileName)"
        $selectedBackup = Load-RegistryBackupFromFile -FilePath $openDialog.FileName

        if (-not (& $showRegistryOverview -SelectedBackup $selectedBackup -SelectedBackupFilePath $openDialog.FileName)) {
            return
        }

        $state.SelectedRegistryBackup = $selectedBackup
        $primaryActionBtn.Content = 'Restore from backup'
    }

    $handleStartMenuPrimaryAction = {
        $scope = (& $getStartMenuScopeInfo).Scope
        $useManualBackupFile = -not ($startMenuAutoBackupCheck.IsChecked -eq $true)

        if ($useManualBackupFile -and [string]::IsNullOrWhiteSpace($state.SelectedStartMenuBackupFilePath)) {
            $openDialog = New-Object Microsoft.Win32.OpenFileDialog
            $openDialog.Title = 'Select Start Menu Backup File'
            $openDialog.Filter = 'Start Menu backup (*.bak)|*.bak'
            $openDialog.InitialDirectory = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
            $openDialog.DefaultExt = '.bak'

            if ($openDialog.ShowDialog($window) -ne $true) {
                return
            }

            $state.SelectedStartMenuBackupFilePath = $openDialog.FileName
            Write-Host "Selected Start Menu backup file: $($state.SelectedStartMenuBackupFilePath)"
            & $refreshStartMenuUi
            return
        }

        $window.Tag = @{
            Result = 'RestoreStartMenu'
            StartMenuScope = $scope
            UseManualBackupFile = $useManualBackupFile
            BackupFilePath = $state.SelectedStartMenuBackupFilePath
        }
        $window.DialogResult = $true
        $window.Close()
    }

    $setWizardStep = {
        param([string]$step)

        $state.WizardStep = $step

        switch ($step) {
            'SelectType' { & $enterSelectTypeStep }
            'Registry' { & $enterRegistryStep }
            'StartMenu' { & $enterStartMenuStep }
        }
    }

    $startMenuAutoBackupCheck.Add_Checked({
        $state.SelectedStartMenuBackupFilePath = $null
        & $refreshStartMenuUi
    })
    $startMenuAutoBackupCheck.Add_Unchecked({
        & $refreshStartMenuUi
    })

    $startMenuScopeCombo.Add_SelectionChanged({
        & $refreshStartMenuUi
    })

    $nonRevertibleWikiLink.Add_MouseLeftButtonUp({
        try {
            Start-Process 'https://github.com/Raphire/Win11Debloat/wiki/Reverting-Changes' | Out-Null
        }
        catch { }
    })

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

        if ($state.WizardStep -eq 'Registry') {
            $state.SelectedRegistryBackup = $null
        }

        if ($state.WizardStep -eq 'StartMenu') {
            $state.SelectedStartMenuBackupFilePath = $null
            $startMenuAutoBackupCheck.IsChecked = $true
        }

        & $setWizardStep 'SelectType'
    })

    $primaryActionBtn.Add_Click({
        switch ($state.WizardStep) {
            'Registry' { & $handleRegistryPrimaryAction }
            'StartMenu' { & $handleStartMenuPrimaryAction }
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
