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
    $cancelBtn = $window.FindName('CancelBtn')
    $selectFileBtn = $window.FindName('SelectFileBtn')
    $restoreBtn = $window.FindName('RestoreBtn')
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

    if (-not $cancelBtn -or -not $selectFileBtn -or -not $restoreBtn) {
        throw 'Restore dialog failed to initialize action buttons.'
    }

    $titleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
    $window.Tag = New-RestoreDialogState
    $cancelBtn.IsCancel = $true
    $selectFileBtn.IsDefault = $true

    if ($introInfoPanel) { $introInfoPanel.Visibility = 'Visible' }
    if ($overviewPanel) { $overviewPanel.Visibility = 'Collapsed' }
    $restoreBtn.Visibility = 'Collapsed'

    if ($nonRevertibleWikiLink) {
        $nonRevertibleWikiLink.Add_MouseLeftButtonUp({
            try {
                Start-Process 'https://github.com/Raphire/Win11Debloat/wiki/Reverting-Changes' | Out-Null
            }
            catch { }
        })
    }

    $cancelBtn.Add_Click({
        $window.Tag = New-RestoreDialogState
        $window.DialogResult = $false
        $window.Close()
    })

    $restoreBtn.Add_Click({
        if (-not $window.Tag.Backup) {
            return
        }

        $window.Tag.Result = 'Restore'
        $window.DialogResult = $true
        $window.Close()
    })

    $selectFileBtn.Add_Click({
        $openDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openDialog.Title = 'Select registry backup file'
        $openDialog.Filter = 'Registry backup (*.json)|*.json|All files (*.*)|*.*'
        $openDialog.DefaultExt = '.json'
        $openDialog.InitialDirectory = $script:RegistryBackupsPath

        if ($openDialog.ShowDialog($window) -eq $true) {
            Write-Host "Backup file selected: $($openDialog.FileName)"
            try {
                $selectedBackup = Load-RegistryBackupFromFile -FilePath $openDialog.FileName
            }
            catch {
                Write-Error "Failed to load registry backup from file '$($openDialog.FileName)': $($_.Exception.Message)"
                Show-MessageBox -Owner $window -Message 'The selected file is not a valid registry backup.' -Title 'Invalid Backup' -Button 'OK' -Icon 'Error' | Out-Null
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
                Write-Warning 'Backup rejected: no revertible changes available.'
                Show-MessageBox -Owner $window -Message 'The selected backup does not contain any changes that can be automatically reverted.' -Title 'Invalid Backup' -Button 'OK' -Icon 'Error' | Out-Null
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
                if ($hasNonRevertibleItems) {
                    $nonRevertiblePanel.Visibility = 'Visible'
                }
                else {
                    $nonRevertiblePanel.Visibility = 'Collapsed'
                }
            }
            if ($nonRevertibleSeparator) {
                if ($hasNonRevertibleItems) {
                    $nonRevertibleSeparator.Visibility = 'Visible'
                }
                else {
                    $nonRevertibleSeparator.Visibility = 'Collapsed'
                }
            }
            if ($introInfoPanel) { $introInfoPanel.Visibility = 'Collapsed' }
            if ($overviewPanel) { $overviewPanel.Visibility = 'Visible' }

            $window.Tag = New-RestoreDialogState -Result 'Preview' -SelectedFile $openDialog.FileName -Backup $selectedBackup
            $restoreBtn.Visibility = 'Visible'
            $restoreBtn.IsDefault = $true
            $selectFileBtn.IsDefault = $false
            $selectFileBtn.Visibility = 'Collapsed'
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
