<#
    .SYNOPSIS
        Displays the Restore Backup wizard dialog.

    .DESCRIPTION
        Presents a modal wizard that lets the user choose and restore either a
        registry backup or a Start Menu pinned-apps backup. Returns the user's 
        selection via $window.Tag.

    .PARAMETER Owner
        Optional parent WPF Window used to host this modal dialog. Defaults to the
        shared $script:GuiWindow when not supplied.

    .OUTPUTS
        Hashtable
        Returns a Hashtable describing the user's choice. Possible shapes:
          RestoreRegistry  - @{ Result='RestoreRegistry'; Backup=<normalizedBackup> }
          Restore-StartMenu - @{ Result='Restore-StartMenu'; StartMenuScope=<scope>;
                               UseManualBackupFile=<bool>; BackupFilePath=<path|string> }
          Cancelled        - @{ Result='Cancelled' } (from New-RestoreDialogState)
#>
function Show-RestoreBackupDialog {
    param(
        [System.Windows.Window]$Owner = $null
    )

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null

    $usesDarkMode = Get-SystemUsesDarkMode
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

    # Everything from here through ShowDialog() sits inside one outer try/finally. The overlay
    # was already made visible above, and nothing hides it again until ShowDialog() returns, so
    # a failure anywhere in schema loading, control wiring, or event registration would otherwise
    # leave the owner window permanently dimmed.
    try {
        $schemaPath = $script:RestoreBackupWindowSchema
        if (-not $schemaPath -or -not (Test-Path $schemaPath)) {
            throw 'Restore backup window schema file could not be found.'
        }

        $xaml = Get-Content -Path $schemaPath -Raw
        $xaml = ConvertTo-LocalizedXaml -Xaml $xaml

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
            Set-WindowThemeResources -window $window -usesDarkMode $usesDarkMode
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
        $reappliedSeparator = $window.FindName('ReappliedSeparator')
        $reappliedPanel = $window.FindName('ReappliedPanel')
        $reappliedFeaturesItemsControl = $window.FindName('ReappliedFeaturesItemsControl')
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
            $summaryScopeText = if ($isAllUsersScope) { Get-Translation -Key 'RestoreStartMenuSummaryScopeAllUsers' } else { Get-Translation -Key 'RestoreStartMenuSummaryScopeCurrentUser' }

            return [PSCustomObject]@{
                Scope = $scopeValue
                Target = $scopeValue
                SummaryText = $summaryScopeText
            }
        }

        $showStartMenuIntroState = {
            $backupFileText.Text = Get-Translation -Key 'RestoreFileNotSelected'
            $backupCreatedText.Text = Get-Translation -Key 'RestoreCreatedUnavailable'
            $overviewSummaryText.Visibility = 'Collapsed'
            $overviewPanel.Visibility = 'Collapsed'
            $startMenuIntroPanel.Visibility = 'Visible'
            $restoreModeTabs.SelectedIndex = 2
        }

        $showStartMenuOverviewState = {
            param([string]$BackupFilePath)

            $scopeInfo = & $getStartMenuScopeInfo
            $backupTargetText.Text = Get-FriendlyRegistryBackupTarget -Target $scopeInfo.Target
            $overviewSummaryText.Text = Get-Translation -Key 'RestoreStartMenuSummary' -FormatArgs @($scopeInfo.SummaryText)
            $backupFileText.Text = Split-Path -Path $BackupFilePath -Leaf

            $createdText = Get-Translation -Key 'RestoreCreatedUnknown'
            try {
                $createdText = (Get-Item -LiteralPath $BackupFilePath -ErrorAction Stop).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
            }
            catch { }
            $backupCreatedText.Text = $createdText

            $overviewFeaturesSection.Visibility = 'Collapsed'
            $overviewSummaryText.Visibility = 'Visible'
            $reappliedSeparator.Visibility = 'Collapsed'
            $reappliedPanel.Visibility = 'Collapsed'
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
                $primaryActionBtn.Content = Get-Translation -Key 'RestorePrimaryActionRestoreBackup'
            }
            else {
                $primaryActionBtn.Content = Get-Translation -Key 'RestorePrimaryActionSelectBackupFile'
            }
        }

        $refreshStartMenuUi = {
            & $updateStartMenuOverviewPanel
            & $updateStartMenuPrimaryActionText
        }

        $enterSelectTypeStep = {
            $titleText.Text = Get-Translation -Key 'RestoreWindowTitle'
            $restoreModeTabs.SelectedIndex = 0
            $backBtn.Visibility = 'Visible'
            $backBtn.Content = Get-Translation -Key 'RestoreBackBtnCancel'
            $primaryActionBtn.Visibility = 'Collapsed'
            $chooseRegistryBtn.IsDefault = $true
            $primaryActionBtn.IsDefault = $false
        }

        $enterRegistryStep = {
            $titleText.Text = Get-Translation -Key 'RestoreRegistryStepTitle'
            $restoreModeTabs.SelectedIndex = 1
            $introInfoPanel.Visibility = 'Visible'
            $overviewPanel.Visibility = 'Collapsed'
            $overviewFeaturesSection.Visibility = 'Visible'
            $overviewSummaryText.Visibility = 'Collapsed'
            $backBtn.Visibility = 'Visible'
            $backBtn.Content = Get-Translation -Key 'RestoreBackBtnBack'
            $primaryActionBtn.Visibility = 'Visible'
            $primaryActionBtn.Content = Get-Translation -Key 'RestorePrimaryActionSelectBackupFile'
            $primaryActionBtn.IsDefault = $true
            $chooseRegistryBtn.IsDefault = $false
        }

        $enterStartMenuStep = {
            $titleText.Text = Get-Translation -Key 'RestoreStartMenuStepTitle'
            $restoreModeTabs.SelectedIndex = 2
            $backBtn.Visibility = 'Visible'
            $backBtn.Content = Get-Translation -Key 'RestoreBackBtnBack'
            $primaryActionBtn.Visibility = 'Visible'
            $primaryActionBtn.IsDefault = $true
            $chooseRegistryBtn.IsDefault = $false

            # Show intro panel so user can configure scope & auto-detect
            $startMenuAutoBackupCheck.IsChecked = $true
            $state.SelectedStartMenuBackupFilePath = $null
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
                Get-Translation -Key 'RestoreCreatedUnknown'
            }
            else {
                try {
                    [DateTime]::Parse($SelectedBackup.CreatedAt).ToString('yyyy-MM-dd HH:mm')
                }
                catch {
                    $SelectedBackup.CreatedAt
                }
            }

            $selectedForwardFeatureIds = @(Get-SelectedForwardFeatureIdsFromBackup -SelectedBackup $SelectedBackup)
            $selectedUndoFeatureIds = @(Get-SelectedUndoFeatureIdsFromBackup -SelectedBackup $SelectedBackup)

            $seenForwardFeatureIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($featureId in $selectedForwardFeatureIds) {
                [void]$seenForwardFeatureIds.Add([string]$featureId)
            }

            $filteredUndoFeatureIds = New-Object System.Collections.Generic.List[string]
            foreach ($featureId in $selectedUndoFeatureIds) {
                if ($seenForwardFeatureIds.Contains([string]$featureId)) {
                    continue
                }

                $filteredUndoFeatureIds.Add([string]$featureId)
            }

            $forwardFeatureLists = Get-RestoreBackupFeatureLists -SelectedFeatureIds $selectedForwardFeatureIds -Features $script:Features
            $undoFeatureLists = Get-RestoreBackupFeatureLists -SelectedFeatureIds @($filteredUndoFeatureIds.ToArray()) -Features $script:Features
            $combinedFeatureLists = Get-RestoreBackupFeatureLists -SelectedFeatureIds (Get-SelectedFeatureIdsFromBackup -SelectedBackup $SelectedBackup) -Features $script:Features

            $revertibleFeaturesList = @($forwardFeatureLists.Revertible)
            $reappliedFeaturesList = @($undoFeatureLists.Revertible)
            $nonRevertibleFeaturesList = @($combinedFeatureLists.NonRevertible)
            Write-Host "Backup overview prepared. Reverted=$($revertibleFeaturesList.Count), ReApplied=$($reappliedFeaturesList.Count), NonRevertible=$($nonRevertibleFeaturesList.Count)"

            if ($revertibleFeaturesList.Count -eq 0 -and $reappliedFeaturesList.Count -eq 0) {
                throw (Get-Translation -Key 'RestoreNoRestorableChangesError')
            }

            $backupFileText.Text = Split-Path $SelectedBackupFilePath -Leaf
            $backupCreatedText.Text = $createdText
            $backupTargetText.Text = Get-FriendlyRegistryBackupTarget -Target ([string]$SelectedBackup.Target)
            $featuresItemsControl.ItemsSource = $revertibleFeaturesList
            $overviewFeaturesSection.Visibility = if ($revertibleFeaturesList.Count -gt 0) { 'Visible' } else { 'Collapsed' }
            $reappliedFeaturesItemsControl.ItemsSource = $reappliedFeaturesList
            if ($reappliedFeaturesList.Count -gt 0) { $reappliedPanel.Visibility = 'Visible' } else { $reappliedPanel.Visibility = 'Collapsed' }
            if ($revertibleFeaturesList.Count -gt 0 -and $reappliedFeaturesList.Count -gt 0) { $reappliedSeparator.Visibility = 'Visible' } else { $reappliedSeparator.Visibility = 'Collapsed' }
            $overviewSummaryText.Visibility = 'Collapsed'
            $nonRevertibleFeaturesItemsControl.ItemsSource = $nonRevertibleFeaturesList

            $hasNonRevertibleItems = ($nonRevertibleFeaturesList.Count -gt 0)
            if ($hasNonRevertibleItems) { $nonRevertiblePanel.Visibility = 'Visible' } else { $nonRevertiblePanel.Visibility = 'Collapsed' }
            if ($hasNonRevertibleItems -and ($revertibleFeaturesList.Count -gt 0 -or $reappliedFeaturesList.Count -gt 0)) { $nonRevertibleSeparator.Visibility = 'Visible' } else { $nonRevertibleSeparator.Visibility = 'Collapsed' }
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
            $openDialog.Title = Get-Translation -Key 'RestoreSelectRegistryFileDialogTitle'
            $openDialog.Filter = 'Registry backup (*.json)|*.json'
            $openDialog.DefaultExt = '.json'
            $openDialog.InitialDirectory = $script:RegistryBackupsPath

            if ($openDialog.ShowDialog($window) -ne $true) {
                return
            }

            Write-Host "Backup file selected: $($openDialog.FileName)"

            try {
                $selectedBackup = Import-RegistryBackup -FilePath $openDialog.FileName

                if (-not (& $showRegistryOverview -SelectedBackup $selectedBackup -SelectedBackupFilePath $openDialog.FileName)) {
                    return
                }
            }
            catch {
                Show-MessageBox -Owner $window -Title (Get-Translation -Key 'RestoreInvalidBackupTitle') -Message (Get-Translation -Key 'RestoreInvalidBackupMessage' -FormatArgs @($_.Exception.Message)) -Button 'OK' -Icon 'Error' | Out-Null
                return
            }

            $state.SelectedRegistryBackup = $selectedBackup
            $primaryActionBtn.Content = Get-Translation -Key 'RestorePrimaryActionRestoreFromBackup'
        }

        $handleStartMenuPrimaryAction = {
            $scope = (& $getStartMenuScopeInfo).Scope
            $useManualBackupFile = -not ($startMenuAutoBackupCheck.IsChecked -eq $true)

            if ($useManualBackupFile -and [string]::IsNullOrWhiteSpace($state.SelectedStartMenuBackupFilePath)) {
                $openDialog = New-Object Microsoft.Win32.OpenFileDialog
                $openDialog.Title = Get-Translation -Key 'RestoreSelectStartMenuFileDialogTitle'
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

            if (-not $useManualBackupFile) {
                $scopeInfo = & $getStartMenuScopeInfo
                $autoBackupPath = Get-StartMenuBackupPath -Scope $scopeInfo.Scope
                if ($null -eq $autoBackupPath) {
                    $scopeText = $scopeInfo.SummaryText
                    Show-MessageBox -Owner $window -Title (Get-Translation -Key 'RestoreNoBackupFoundTitle') -Message (Get-Translation -Key 'RestoreNoBackupFoundMessage' -FormatArgs @($scopeText)) -Button 'OK' -Icon 'Warning' | Out-Null
                    return
                }
                $state.SelectedStartMenuBackupFilePath = if ($scopeInfo.Scope -eq 'CurrentUser') { $autoBackupPath } else { $null }
            }

            $window.Tag = @{
                Result = 'Restore-StartMenu'
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
            $state.SelectedStartMenuBackupFilePath = $null
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
